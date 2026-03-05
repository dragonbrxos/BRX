#!/bin/bash
# =============================================================================
# KanelOS — Suite de Benchmarks
# =============================================================================
# Executa benchmarks de performance para comparar o KanelOS com o kernel
# vanilla e outras distribuições.
#
# Métricas coletadas:
#   - Latência de scheduler (cyclictest)
#   - Throughput de I/O (fio)
#   - Performance de rede (iperf3)
#   - Uso de memória (stream)
#   - Latência de compilação (kernel build time)
# =============================================================================

set -euo pipefail

PROFILE="${1:-desktop}"
OUTPUT_DIR="output/benchmarks/$(date +%Y%m%d-%H%M%S)-${PROFILE}"
KERNEL_VERSION=$(uname -r)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "${OUTPUT_DIR}"

log() { echo -e "${BLUE}[BENCH]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}   $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }

# =============================================================================
# Informações do sistema
# =============================================================================
collect_sysinfo() {
	log "Coletando informações do sistema..."

	{
		echo "# KanelOS Benchmark Report"
		echo "# Data: $(date)"
		echo "# Kernel: ${KERNEL_VERSION}"
		echo "# Perfil: ${PROFILE}"
		echo ""
		echo "## CPU"
		lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket|MHz|Cache"
		echo ""
		echo "## Memória"
		free -h
		echo ""
		echo "## Storage"
		lsblk -d -o NAME,SIZE,ROTA,SCHED,MODEL
		echo ""
		echo "## Kernel Parameters"
		echo "swappiness: $(cat /proc/sys/vm/swappiness)"
		echo "vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure)"
		echo "tcp_congestion_control: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
		echo "scheduler: $(cat /sys/block/*/queue/scheduler 2>/dev/null | head -1 || echo 'N/A')"
	} > "${OUTPUT_DIR}/sysinfo.txt"

	ok "Informações do sistema coletadas"
}

# =============================================================================
# Benchmark 1: Latência de Scheduler (cyclictest)
# =============================================================================
bench_scheduler_latency() {
	log "Benchmark: Latência de Scheduler..."

	if ! command -v cyclictest &>/dev/null; then
		warn "cyclictest não encontrado. Instale: apt-get install rt-tests"
		return
	fi

	# Executar cyclictest por 30 segundos
	cyclictest \
		--mlockall \
		--smp \
		--priority=80 \
		--interval=200 \
		--distance=0 \
		--duration=30 \
		--histogram=400 \
		--histfile="${OUTPUT_DIR}/cyclictest-histogram.dat" \
		> "${OUTPUT_DIR}/cyclictest-results.txt" 2>&1

	# Extrair métricas principais
	local avg_latency max_latency
	avg_latency=$(grep "Avg:" "${OUTPUT_DIR}/cyclictest-results.txt" | \
		awk '{sum+=$NF; count++} END {print sum/count}' 2>/dev/null || echo "N/A")
	max_latency=$(grep "Max:" "${OUTPUT_DIR}/cyclictest-results.txt" | \
		awk '{if($NF>max) max=$NF} END {print max}' 2>/dev/null || echo "N/A")

	echo "scheduler_latency_avg_us=${avg_latency}" >> "${OUTPUT_DIR}/metrics.txt"
	echo "scheduler_latency_max_us=${max_latency}" >> "${OUTPUT_DIR}/metrics.txt"

	ok "Latência média: ${avg_latency}μs | Máxima: ${max_latency}μs"
}

# =============================================================================
# Benchmark 2: Throughput de I/O (fio)
# =============================================================================
bench_io_throughput() {
	log "Benchmark: Throughput de I/O (fio)..."

	if ! command -v fio &>/dev/null; then
		warn "fio não encontrado. Instale: apt-get install fio"
		return
	fi

	local test_file="/tmp/kanelos-fio-test"
	local results_file="${OUTPUT_DIR}/fio-results.txt"

	# Teste 1: Leitura sequencial (mede throughput de leitura)
	log "  Leitura sequencial..."
	fio --name=seq-read \
		--filename="${test_file}" \
		--rw=read \
		--bs=1M \
		--size=4G \
		--numjobs=1 \
		--iodepth=32 \
		--ioengine=io_uring \
		--direct=1 \
		--runtime=30 \
		--time_based \
		--output-format=json \
		--output="${OUTPUT_DIR}/fio-seq-read.json" 2>/dev/null

	# Teste 2: Leitura aleatória 4K (mede IOPS)
	log "  Leitura aleatória 4K..."
	fio --name=rand-read-4k \
		--filename="${test_file}" \
		--rw=randread \
		--bs=4k \
		--size=4G \
		--numjobs=4 \
		--iodepth=32 \
		--ioengine=io_uring \
		--direct=1 \
		--runtime=30 \
		--time_based \
		--output-format=json \
		--output="${OUTPUT_DIR}/fio-rand-read-4k.json" 2>/dev/null

	# Teste 3: Escrita aleatória 4K
	log "  Escrita aleatória 4K..."
	fio --name=rand-write-4k \
		--filename="${test_file}" \
		--rw=randwrite \
		--bs=4k \
		--size=4G \
		--numjobs=4 \
		--iodepth=32 \
		--ioengine=io_uring \
		--direct=1 \
		--runtime=30 \
		--time_based \
		--output-format=json \
		--output="${OUTPUT_DIR}/fio-rand-write-4k.json" 2>/dev/null

	rm -f "${test_file}"

	# Extrair métricas
	if command -v python3 &>/dev/null; then
		python3 - <<'EOF'
import json, sys, os

output_dir = sys.argv[1] if len(sys.argv) > 1 else "."
metrics = {}

for test in ["seq-read", "rand-read-4k", "rand-write-4k"]:
    fname = f"{output_dir}/fio-{test}.json"
    if os.path.exists(fname):
        with open(fname) as f:
            data = json.load(f)
        job = data["jobs"][0]
        if "read" in test or test == "seq-read":
            bw = job["read"]["bw"] / 1024  # MB/s
            iops = job["read"]["iops"]
            lat = job["read"]["lat_ns"]["mean"] / 1000  # μs
        else:
            bw = job["write"]["bw"] / 1024
            iops = job["write"]["iops"]
            lat = job["write"]["lat_ns"]["mean"] / 1000
        print(f"  {test}: {bw:.1f} MB/s | {iops:.0f} IOPS | {lat:.1f}μs latência")
EOF
		"${OUTPUT_DIR}"
	fi

	ok "Benchmarks de I/O concluídos"
}

# =============================================================================
# Benchmark 3: Memória (STREAM)
# =============================================================================
bench_memory() {
	log "Benchmark: Memória (STREAM)..."

	if ! command -v stream &>/dev/null; then
		warn "STREAM não encontrado. Compilando..."
		# Compilar STREAM se não disponível
		cat > /tmp/stream.c << 'STREAM_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define N 10000000
double a[N], b[N], c[N];
int main() {
    struct timespec t1, t2;
    double scalar = 3.0;
    for (int i=0; i<N; i++) { a[i]=1.0; b[i]=2.0; c[i]=0.0; }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    for (int i=0; i<N; i++) c[i] = a[i] + b[i];
    clock_gettime(CLOCK_MONOTONIC, &t2);
    double dt = (t2.tv_sec-t1.tv_sec) + (t2.tv_nsec-t1.tv_nsec)*1e-9;
    double bw = 3.0*8*N/dt/1e9;
    printf("STREAM Add: %.2f GB/s\n", bw);
    return 0;
}
STREAM_EOF
		gcc -O3 -march=native -o /tmp/stream /tmp/stream.c 2>/dev/null || {
			warn "Falha ao compilar STREAM"
			return
		}
	fi

	/tmp/stream 2>/dev/null | tee "${OUTPUT_DIR}/stream-results.txt"
	ok "Benchmark de memória concluído"
}

# =============================================================================
# Benchmark 4: Tempo de compilação do kernel
# =============================================================================
bench_compile_time() {
	log "Benchmark: Tempo de compilação (kernel defconfig)..."

	if [ ! -d "/tmp/linux-bench" ]; then
		warn "Kernel source não disponível para benchmark de compilação"
		return
	fi

	local start_time end_time elapsed
	start_time=$(date +%s)

	make -C /tmp/linux-bench defconfig -j"$(nproc)" &>/dev/null
	make -C /tmp/linux-bench -j"$(nproc)" 2>/dev/null | tail -1

	end_time=$(date +%s)
	elapsed=$((end_time - start_time))

	echo "compile_time_seconds=${elapsed}" >> "${OUTPUT_DIR}/metrics.txt"
	ok "Tempo de compilação: ${elapsed}s"
}

# =============================================================================
# Gerar relatório
# =============================================================================
generate_report() {
	log "Gerando relatório de benchmarks..."

	{
		echo "# KanelOS Benchmark Report"
		echo ""
		echo "**Data:** $(date)"
		echo "**Kernel:** ${KERNEL_VERSION}"
		echo "**Perfil:** ${PROFILE}"
		echo ""
		echo "## Resultados"
		echo ""
		if [ -f "${OUTPUT_DIR}/metrics.txt" ]; then
			cat "${OUTPUT_DIR}/metrics.txt"
		fi
		echo ""
		echo "## Informações do Sistema"
		echo ""
		if [ -f "${OUTPUT_DIR}/sysinfo.txt" ]; then
			cat "${OUTPUT_DIR}/sysinfo.txt"
		fi
	} > "${OUTPUT_DIR}/report.md"

	ok "Relatório gerado: ${OUTPUT_DIR}/report.md"
}

# =============================================================================
# Main
# =============================================================================
main() {
	echo -e "${CYAN}"
	echo "╔══════════════════════════════════════════════════════╗"
	echo "║         KanelOS Benchmark Suite v0.1.0              ║"
	echo "╚══════════════════════════════════════════════════════╝"
	echo -e "${NC}"

	log "Iniciando benchmarks (perfil: ${PROFILE})..."
	log "Resultados em: ${OUTPUT_DIR}/"
	echo ""

	collect_sysinfo
	bench_scheduler_latency
	bench_io_throughput
	bench_memory
	generate_report

	echo ""
	echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
	echo -e "${GREEN}║         Benchmarks concluídos!                      ║${NC}"
	echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
	echo ""
	echo "Resultados: ${OUTPUT_DIR}/"
}

main "$@"
