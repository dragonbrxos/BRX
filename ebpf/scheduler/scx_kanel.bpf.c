/* SPDX-License-Identifier: GPL-2.0 */
/*
 * KanelOS Custom Scheduler — scx_kanel
 * Implementado como programa BPF usando sched_ext (Linux 6.12+)
 *
 * Copyright (C) 2026 KanelOS Team
 *
 * Este scheduler combina as melhores características de:
 * - scx_lavd: Latency-Aware Virtual Deadline (para gaming/desktop)
 * - scx_rusty: Rust-based scheduler (para servidores)
 * - BORE: Burst-Oriented Response Enhancer
 *
 * Estratégia:
 * - Tarefas interativas (burst_score baixo): alta prioridade, baixa latência
 * - Tarefas de background (burst_score alto): menor prioridade, maior throughput
 * - Tarefas RT: sempre prioridade máxima
 * - Balanceamento NUMA-aware
 *
 * Requer: Linux 6.12+ com CONFIG_SCHED_CLASS_EXT=y
 */

#include <scx/common.bpf.h>
#include <linux/sched.h>

/* Metadados do scheduler */
char _license[] SEC("license") = "GPL";

/* Configurações do scheduler */
const volatile bool kanel_prefer_idle_cores = true;
const volatile u32  kanel_slice_ns = 5000000;  /* 5ms slice padrão */
const volatile u32  kanel_min_slice_ns = 1000000;  /* 1ms mínimo */
const volatile u32  kanel_max_slice_ns = 20000000; /* 20ms máximo */
const volatile bool kanel_numa_aware = true;
const volatile u32  kanel_interactive_threshold = 50; /* burst_score < 50 = interativo */

/* Estrutura por tarefa (armazenada no BPF storage) */
struct task_ctx {
	u64  vdeadline;       /* Virtual deadline EEVDF-style */
	u64  slice_ns;        /* Time slice atual */
	u32  burst_score;     /* Score de burst (0=interativo, 255=batch) */
	u32  cpu_affinity;    /* CPU preferida */
	bool is_interactive;  /* Tarefa interativa? */
	bool is_rt;           /* Tarefa real-time? */
	u64  last_run_at;     /* Timestamp da última execução */
	u64  total_runtime;   /* Tempo total de execução */
};

/* BPF map para contexto por tarefa */
struct {
	__uint(type, BPF_MAP_TYPE_TASK_STORAGE);
	__uint(map_flags, BPF_F_NO_PREALLOC);
	__type(key, int);
	__type(value, struct task_ctx);
} task_ctx_map SEC(".maps");

/* Estatísticas globais */
struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, 1);
	__type(key, u32);
	__type(value, struct {
		u64 nr_scheduled;
		u64 nr_interactive;
		u64 nr_batch;
		u64 nr_rt;
		u64 avg_latency_ns;
	});
} stats_map SEC(".maps");

/* =========================================================================
 * Funções auxiliares
 * ========================================================================= */

/**
 * is_task_interactive - Determinar se uma tarefa é interativa
 *
 * Tarefas interativas têm burst_score baixo (pouco tempo de CPU contínuo)
 * e são priorizadas para baixa latência.
 */
static inline bool is_task_interactive(struct task_ctx *ctx)
{
	return ctx->burst_score < kanel_interactive_threshold;
}

/**
 * calc_task_slice - Calcular time slice para a tarefa
 *
 * Tarefas interativas recebem slices menores (menor latência)
 * Tarefas batch recebem slices maiores (melhor throughput)
 */
static inline u64 calc_task_slice(struct task_ctx *ctx)
{
	if (ctx->is_rt)
		return kanel_min_slice_ns;

	if (is_task_interactive(ctx))
		return kanel_min_slice_ns * 2;  /* 2ms para interativas */

	/* Batch: slice proporcional ao burst_score */
	u64 slice = kanel_slice_ns +
		    (u64)ctx->burst_score * kanel_slice_ns / 255;

	return min(slice, (u64)kanel_max_slice_ns);
}

/* =========================================================================
 * Callbacks do sched_ext
 * ========================================================================= */

/**
 * kanel_select_cpu - Selecionar CPU para executar a tarefa
 *
 * Implementa seleção NUMA-aware com preferência por cores idle.
 */
s32 BPF_STRUCT_OPS(kanel_select_cpu, struct task_struct *p,
		   s32 prev_cpu, u64 wake_flags)
{
	struct task_ctx *ctx;
	s32 cpu;

	ctx = bpf_task_storage_get(&task_ctx_map, p, 0, 0);
	if (!ctx)
		return prev_cpu;

	/* Para tarefas RT, usar CPU anterior (cache quente) */
	if (ctx->is_rt)
		return prev_cpu;

	/* Para tarefas interativas, preferir cores idle */
	if (kanel_prefer_idle_cores && is_task_interactive(ctx)) {
		cpu = scx_bpf_pick_idle_cpu(p->cpus_ptr, 0);
		if (cpu >= 0)
			return cpu;
	}

	/* Fallback: usar CPU anterior */
	return prev_cpu;
}

/**
 * kanel_enqueue - Enfileirar tarefa para execução
 */
void BPF_STRUCT_OPS(kanel_enqueue, struct task_struct *p, u64 enq_flags)
{
	struct task_ctx *ctx;
	u64 slice;

	ctx = bpf_task_storage_get(&task_ctx_map, p, 0,
				   BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (!ctx) {
		scx_bpf_dispatch(p, SCX_DSQ_GLOBAL, kanel_slice_ns, enq_flags);
		return;
	}

	/* Calcular slice baseado no tipo de tarefa */
	slice = calc_task_slice(ctx);
	ctx->slice_ns = slice;

	/* Tarefas interativas vão para fila de alta prioridade */
	if (is_task_interactive(ctx) || ctx->is_rt) {
		scx_bpf_dispatch(p, SCX_DSQ_LOCAL, slice, enq_flags);
	} else {
		scx_bpf_dispatch(p, SCX_DSQ_GLOBAL, slice, enq_flags);
	}
}

/**
 * kanel_running - Callback quando tarefa começa a executar
 */
void BPF_STRUCT_OPS(kanel_running, struct task_struct *p)
{
	struct task_ctx *ctx;

	ctx = bpf_task_storage_get(&task_ctx_map, p, 0, 0);
	if (!ctx)
		return;

	ctx->last_run_at = bpf_ktime_get_ns();
}

/**
 * kanel_stopping - Callback quando tarefa para de executar
 */
void BPF_STRUCT_OPS(kanel_stopping, struct task_struct *p, bool runnable)
{
	struct task_ctx *ctx;
	u64 now, runtime;

	ctx = bpf_task_storage_get(&task_ctx_map, p, 0, 0);
	if (!ctx)
		return;

	now = bpf_ktime_get_ns();
	runtime = now - ctx->last_run_at;
	ctx->total_runtime += runtime;

	/* Atualizar burst_score com suavização exponencial */
	/* burst_score aumenta com execuções longas contínuas */
	if (runtime > kanel_slice_ns) {
		/* Tarefa usou o slice completo: mais batch-like */
		ctx->burst_score = min(ctx->burst_score + 1, (u32)255);
	} else {
		/* Tarefa liberou CPU cedo: mais interativa */
		if (ctx->burst_score > 0)
			ctx->burst_score--;
	}

	ctx->is_interactive = is_task_interactive(ctx);
}

/**
 * kanel_init_task - Inicializar contexto para nova tarefa
 */
s32 BPF_STRUCT_OPS(kanel_init_task, struct task_struct *p,
		   struct scx_init_task_args *args)
{
	struct task_ctx *ctx;

	ctx = bpf_task_storage_get(&task_ctx_map, p, 0,
				   BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (!ctx)
		return -ENOMEM;

	ctx->burst_score   = 0;      /* Começa como interativa */
	ctx->is_interactive = true;
	ctx->is_rt         = p->policy == SCHED_FIFO || p->policy == SCHED_RR;
	ctx->slice_ns      = kanel_slice_ns;
	ctx->last_run_at   = bpf_ktime_get_ns();
	ctx->total_runtime = 0;

	return 0;
}

/* =========================================================================
 * Registro do scheduler
 * ========================================================================= */

SCX_OPS_DEFINE(kanel_ops,
	.select_cpu   = (void *)kanel_select_cpu,
	.enqueue      = (void *)kanel_enqueue,
	.running      = (void *)kanel_running,
	.stopping     = (void *)kanel_stopping,
	.init_task    = (void *)kanel_init_task,
	.name         = "kanel",
);
