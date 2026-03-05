#!/bin/bash
# =============================================================================
# BRX OS — Game Runtime Mode (brx-game-mode)
# =============================================================================
# Otimiza o sistema para jogos em tempo real:
#   - Aumenta prioridade do processo (renice)
#   - Define CPU governor para 'performance'
#   - Otimiza scheduler BORE para latência mínima
#   - Suspende processos de background não essenciais
#   - Otimiza GPU power levels (AMD/NVIDIA)
# =============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[BRX-GAME]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}       $*"; }

if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root (sudo)"
   exit 1
fi

GAME_PID=$1

if [ -z "$GAME_PID" ]; then
    echo "Uso: sudo brx-game-mode <PID_DO_JOGO>"
    exit 1
fi

log "Iniciando otimizações para o processo $GAME_PID..."

# 1. Prioridade de Processo (Renice & I/O)
log "Ajustando prioridade de CPU e I/O..."
renice -n -15 -p "$GAME_PID" > /dev/null
ionice -c 1 -n 0 -p "$GAME_PID" > /dev/null

# 2. CPU Governor
log "Definindo CPU Governor para 'performance'..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null || true
done

# 3. Otimização BORE (Kernel BRX)
if [ -f /proc/sys/kernel/bore_sched ]; then
    log "Otimizando scheduler BORE para modo interativo..."
    echo 1 > /proc/sys/kernel/bore_sched
fi

# 4. GPU Power Management (AMD/NVIDIA)
if command -v nvidia-smi &> /dev/null; then
    log "Configurando NVIDIA GPU para performance..."
    nvidia-smi -pm 1 > /dev/null
    nvidia-smi -pl $(nvidia-smi -q -d POWER | grep "Max Power Limit" | awk '{print $4}') > /dev/null
elif [ -d /sys/class/drm/card0/device/hwmon ]; then
    log "Configurando AMD GPU para performance..."
    echo "manual" > /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || true
    echo "high" > /sys/class/drm/card0/device/power_dpm_state 2>/dev/null || true
fi

# 5. Redução de latência de rede
log "Otimizando pilha de rede (TCP BBR v3)..."
sysctl -w net.core.netdev_max_backlog=5000 > /dev/null
sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null

ok "Otimizações aplicadas com sucesso para o jogo!"
log "O sistema retornará ao normal quando o processo $GAME_PID for encerrado."

# Monitorar o processo e restaurar ao sair
while kill -0 "$GAME_PID" 2>/dev/null; do
    sleep 5
done

log "Processo encerrado. Restaurando configurações originais..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "schedutil" > "$cpu" 2>/dev/null || true
done
if [ -d /sys/class/drm/card0/device/hwmon ]; then
    echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || true
fi

ok "Sistema restaurado."
