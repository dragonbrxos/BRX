#!/bin/bash
# =============================================================================
# DragonBRX OS — Instalação de Regras Udev Otimizadas
# =============================================================================
# Este script aplica as regras udev otimizadas do DragonBRX OS.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-UDEV]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}           $*"; }

log "Aplicando regras udev otimizadas do DragonBRX OS..."

# Copiar as regras udev
cp /opt/dragonbrx/udev/rules.d/*.rules /etc/udev/rules.d/

# Recarregar as regras udev
udevadm control --reload-rules
udevadm trigger

ok "Regras udev aplicadas com sucesso."
