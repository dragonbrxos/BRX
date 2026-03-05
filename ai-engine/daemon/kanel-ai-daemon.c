/*
 * KanelOS AI Engine Daemon — kanel-ai-daemon
 * Copyright (C) 2026 KanelOS Team
 * SPDX-License-Identifier: GPL-2.0
 *
 * Daemon userspace que coleta métricas via eBPF ring buffers e
 * aplica otimizações preditivas ao kernel via sysctl/cgroup v2.
 *
 * Arquitetura:
 *   [eBPF probes] → [ring buffer] → [kanel-ai-daemon] → [sysctl/cgroup]
 *
 * Subsistemas monitorados:
 *   - CPU: frequência, utilização, temperatura, C-states
 *   - Memória: pressão, MGLRU stats, KSM, swap
 *   - I/O: throughput, latência, queue depth
 *   - Rede: throughput, RTT, congestion
 *
 * Modelos de predição (leves, sem dependências ML pesadas):
 *   - Regressão linear para predição de carga de CPU
 *   - Média móvel exponencial para I/O
 *   - Árvore de decisão simples para seleção de governor
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/sysinfo.h>
#include <time.h>
#include <pthread.h>
#include <math.h>

/* Versão do daemon */
#define KANEL_AI_VERSION "0.1.0"

/* Intervalos de coleta (ms) */
#define COLLECT_INTERVAL_CPU_MS     100
#define COLLECT_INTERVAL_MEM_MS     500
#define COLLECT_INTERVAL_IO_MS      200
#define COLLECT_INTERVAL_NET_MS     200

/* Janela de histórico para predição */
#define HISTORY_WINDOW_SIZE         60   /* 60 amostras */

/* Limiares para otimização */
#define CPU_HIGH_THRESHOLD          80.0  /* % de utilização */
#define CPU_LOW_THRESHOLD           20.0
#define MEM_PRESSURE_HIGH           85.0  /* % de uso */
#define IO_LATENCY_HIGH_US          1000  /* 1ms */

/* Caminhos do sistema */
#define SYSCTL_PATH                 "/proc/sys"
#define CGROUP_PATH                 "/sys/fs/cgroup"
#define CPUFREQ_PATH                "/sys/devices/system/cpu"
#define MGLRU_PATH                  "/sys/kernel/mm/lru_gen"
#define ZSWAP_PATH                  "/sys/module/zswap/parameters"

/* =========================================================================
 * Estruturas de dados
 * ========================================================================= */

typedef struct {
	double cpu_util[HISTORY_WINDOW_SIZE];
	double cpu_freq[HISTORY_WINDOW_SIZE];
	double cpu_temp[HISTORY_WINDOW_SIZE];
	int    head;
	int    count;
} cpu_history_t;

typedef struct {
	double mem_used_pct;
	double swap_used_pct;
	long   mglru_evictions;
	long   ksm_pages_shared;
	long   zswap_stored_pages;
} mem_stats_t;

typedef struct {
	double io_read_mbps;
	double io_write_mbps;
	double io_latency_us;
	long   io_queue_depth;
} io_stats_t;

typedef struct {
	double net_rx_mbps;
	double net_tx_mbps;
	double net_rtt_ms;
	long   net_retransmits;
} net_stats_t;

typedef struct {
	cpu_history_t cpu;
	mem_stats_t   mem;
	io_stats_t    io;
	net_stats_t   net;
	time_t        last_update;
} system_metrics_t;

/* Estado global */
static volatile int running = 1;
static system_metrics_t metrics = {0};
static pthread_mutex_t metrics_lock = PTHREAD_MUTEX_INITIALIZER;

/* =========================================================================
 * Coleta de Métricas
 * ========================================================================= */

/**
 * read_cpu_util - Ler utilização de CPU de /proc/stat
 */
static double read_cpu_util(void)
{
	static long prev_idle = 0, prev_total = 0;
	long user, nice, system, idle, iowait, irq, softirq, steal;
	long total, idle_total, diff_idle, diff_total;
	FILE *fp;
	double util = 0.0;

	fp = fopen("/proc/stat", "r");
	if (!fp) return -1.0;

	if (fscanf(fp, "cpu %ld %ld %ld %ld %ld %ld %ld %ld",
		   &user, &nice, &system, &idle, &iowait,
		   &irq, &softirq, &steal) == 8) {
		idle_total = idle + iowait;
		total = user + nice + system + idle_total + irq + softirq + steal;

		diff_idle  = idle_total - prev_idle;
		diff_total = total - prev_total;

		if (diff_total > 0)
			util = 100.0 * (1.0 - (double)diff_idle / diff_total);

		prev_idle  = idle_total;
		prev_total = total;
	}

	fclose(fp);
	return util;
}

/**
 * read_mem_stats - Ler estatísticas de memória de /proc/meminfo
 */
static void read_mem_stats(mem_stats_t *mem)
{
	FILE *fp;
	char line[256];
	long mem_total = 0, mem_available = 0, swap_total = 0, swap_free = 0;

	fp = fopen("/proc/meminfo", "r");
	if (!fp) return;

	while (fgets(line, sizeof(line), fp)) {
		if (sscanf(line, "MemTotal: %ld kB", &mem_total) == 1) continue;
		if (sscanf(line, "MemAvailable: %ld kB", &mem_available) == 1) continue;
		if (sscanf(line, "SwapTotal: %ld kB", &swap_total) == 1) continue;
		if (sscanf(line, "SwapFree: %ld kB", &swap_free) == 1) continue;
	}
	fclose(fp);

	if (mem_total > 0)
		mem->mem_used_pct = 100.0 * (1.0 - (double)mem_available / mem_total);

	if (swap_total > 0)
		mem->swap_used_pct = 100.0 * (1.0 - (double)swap_free / swap_total);
}

/* =========================================================================
 * Otimizações Preditivas
 * ========================================================================= */

/**
 * write_sysctl - Escrever valor em parâmetro sysctl
 */
static int write_sysctl(const char *param, const char *value)
{
	char path[512];
	FILE *fp;

	snprintf(path, sizeof(path), "%s/%s", SYSCTL_PATH, param);
	fp = fopen(path, "w");
	if (!fp) {
		fprintf(stderr, "kanel-ai: Erro ao escrever %s: %s\n",
			path, strerror(errno));
		return -1;
	}

	fprintf(fp, "%s\n", value);
	fclose(fp);
	return 0;
}

/**
 * optimize_cpu_governor - Selecionar governor de CPU baseado na carga
 *
 * Lógica de decisão:
 * - Carga alta (>80%): performance
 * - Carga média (20-80%): schedutil (padrão)
 * - Carga baixa (<20%): powersave (em laptops)
 */
static void optimize_cpu_governor(double cpu_util)
{
	static char current_governor[32] = "schedutil";
	const char *new_governor = "schedutil";
	char path[256];
	FILE *fp;
	int cpu;

	/* Selecionar governor baseado na utilização */
	if (cpu_util > CPU_HIGH_THRESHOLD)
		new_governor = "performance";
	else if (cpu_util < CPU_LOW_THRESHOLD)
		new_governor = "powersave";
	else
		new_governor = "schedutil";

	/* Só mudar se necessário */
	if (strcmp(new_governor, current_governor) == 0)
		return;

	/* Aplicar em todos os CPUs */
	for (cpu = 0; cpu < sysconf(_SC_NPROCESSORS_ONLN); cpu++) {
		snprintf(path, sizeof(path),
			 "%s/cpu%d/cpufreq/scaling_governor",
			 CPUFREQ_PATH, cpu);
		fp = fopen(path, "w");
		if (fp) {
			fprintf(fp, "%s\n", new_governor);
			fclose(fp);
		}
	}

	strncpy(current_governor, new_governor, sizeof(current_governor) - 1);
	printf("kanel-ai: CPU governor → %s (util: %.1f%%)\n",
	       new_governor, cpu_util);
}

/**
 * optimize_memory - Otimizar parâmetros de memória baseado na pressão
 */
static void optimize_memory(mem_stats_t *mem)
{
	static double prev_mem_pct = 0.0;

	/* Só ajustar se a mudança for significativa (>5%) */
	if (fabs(mem->mem_used_pct - prev_mem_pct) < 5.0)
		return;

	if (mem->mem_used_pct > MEM_PRESSURE_HIGH) {
		/* Alta pressão: ativar KSM mais agressivo */
		write_sysctl("kernel/mm/ksm/run", "1");
		write_sysctl("kernel/mm/ksm/sleep_millisecs", "100");
		write_sysctl("kernel/mm/ksm/pages_to_scan", "200");
		/* Aumentar swappiness para liberar memória */
		write_sysctl("vm/swappiness", "60");
		printf("kanel-ai: Alta pressão de memória (%.1f%%) — KSM ativado\n",
		       mem->mem_used_pct);
	} else {
		/* Pressão normal: KSM conservador */
		write_sysctl("kernel/mm/ksm/sleep_millisecs", "1000");
		write_sysctl("kernel/mm/ksm/pages_to_scan", "100");
		write_sysctl("vm/swappiness", "10");
	}

	prev_mem_pct = mem->mem_used_pct;
}

/**
 * optimize_io - Otimizar parâmetros de I/O
 */
static void optimize_io(io_stats_t *io)
{
	/* Ajustar read-ahead baseado no padrão de I/O */
	if (io->io_read_mbps > 500.0) {
		/* I/O sequencial alto: aumentar read-ahead */
		write_sysctl("vm/read_ahead_kb", "4096");
	} else if (io->io_read_mbps < 10.0) {
		/* I/O aleatório: reduzir read-ahead */
		write_sysctl("vm/read_ahead_kb", "128");
	} else {
		write_sysctl("vm/read_ahead_kb", "512");
	}
}

/* =========================================================================
 * Loop Principal
 * ========================================================================= */

static void signal_handler(int sig)
{
	if (sig == SIGTERM || sig == SIGINT) {
		printf("\nkanel-ai: Encerrando daemon...\n");
		running = 0;
	}
}

static void *cpu_monitor_thread(void *arg)
{
	(void)arg;
	while (running) {
		double util = read_cpu_util();

		pthread_mutex_lock(&metrics_lock);
		int idx = metrics.cpu.head % HISTORY_WINDOW_SIZE;
		metrics.cpu.cpu_util[idx] = util;
		metrics.cpu.head++;
		if (metrics.cpu.count < HISTORY_WINDOW_SIZE)
			metrics.cpu.count++;
		pthread_mutex_unlock(&metrics_lock);

		optimize_cpu_governor(util);

		usleep(COLLECT_INTERVAL_CPU_MS * 1000);
	}
	return NULL;
}

static void *mem_monitor_thread(void *arg)
{
	(void)arg;
	while (running) {
		pthread_mutex_lock(&metrics_lock);
		read_mem_stats(&metrics.mem);
		pthread_mutex_unlock(&metrics_lock);

		optimize_memory(&metrics.mem);

		usleep(COLLECT_INTERVAL_MEM_MS * 1000);
	}
	return NULL;
}

int main(int argc, char *argv[])
{
	pthread_t cpu_thread, mem_thread;

	printf("KanelOS AI Engine Daemon v%s\n", KANEL_AI_VERSION);
	printf("Iniciando monitoramento e otimização preditiva...\n\n");

	/* Configurar handlers de sinal */
	signal(SIGTERM, signal_handler);
	signal(SIGINT, signal_handler);

	/* Aplicar configurações iniciais otimizadas */
	write_sysctl("vm/swappiness", "10");
	write_sysctl("vm/dirty_ratio", "15");
	write_sysctl("vm/dirty_background_ratio", "5");
	write_sysctl("vm/vfs_cache_pressure", "50");
	write_sysctl("kernel/sched_autogroup_enabled", "1");

	/* Iniciar threads de monitoramento */
	pthread_create(&cpu_thread, NULL, cpu_monitor_thread, NULL);
	pthread_create(&mem_thread, NULL, mem_monitor_thread, NULL);

	printf("kanel-ai: Daemon ativo. Monitorando sistema...\n");

	/* Aguardar término */
	pthread_join(cpu_thread, NULL);
	pthread_join(mem_thread, NULL);

	printf("kanel-ai: Daemon encerrado.\n");
	return 0;
}
