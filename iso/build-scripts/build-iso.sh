#!/bin/bash
# =============================================================================
# DragonBRX OS — ISO Build Script
# =============================================================================
# Este script automatiza a criação da ISO do DragonBRX OS usando Archiso.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-ISO]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}      $*"; }
err() { echo -e "${RED}[ERROR]${NC}   $*"; }

PROFILE="${1:-desktop}"
VERSION=$(date +%Y.%m.%d)
ARCH=$(uname -m)
OUTPUT_DIR="../../output"

log "Iniciando construção da ISO DragonBRX OS v${VERSION}..."

# 1. Verificar dependências
if ! command -v mkarchiso &> /dev/null; then
    err "mkarchiso não encontrado. Instale o pacote 'archiso'."
    exit 1
fi

# 2. Preparar diretório de saída
mkdir -p "${OUTPUT_DIR}"

# 3. Limpar builds anteriores
log "Limpando builds anteriores..."
sudo rm -rf work/

# 4. Construir a ISO
log "Executando mkarchiso para o perfil ${PROFILE}..."
# O profiledef.sh e outros arquivos já estão em ../archiso/
cd ../archiso
sudo mkarchiso -v -w ./work -o "${OUTPUT_DIR}" .

# 5. Renomear ISO final
ISO_FILE="${OUTPUT_DIR}/dragonbrx-${VERSION}-${PROFILE}-${ARCH}.iso"
ok "ISO construída com sucesso: ${ISO_FILE}"

# 6. Gerar checksum (SHA256)
log "Gerando checksum SHA256..."
sha256sum "${ISO_FILE}" > "${ISO_FILE}.sha256"
ok "Checksum gerado."
