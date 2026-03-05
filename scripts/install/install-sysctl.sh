#!/bin/bash
# =============================================================================
# DragonBRX OS — Instalação de Configurações Sysctl Otimizadas
# =============================================================================
# Este script aplica as configurações sysctl otimizadas do DragonBRX OS.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-SYSCTL]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}           $*"; }

log "Aplicando configurações sysctl otimizadas do DragonBRX OS..."

# Copiar o arquivo de configuração sysctl
cp /opt/dragonbrx/sysctl/kanel-performance.conf /etc/sysctl.d/99-dragonbrx.conf

# Carregar as novas configurações
sysctl --system

ok "Configurações sysctl aplicadas com sucesso."
