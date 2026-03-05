#!/bin/bash
# =============================================================================
# DragonBRX OS — Partitioning Automator
# =============================================================================
# Detecta discos e auxilia no particionamento (incluindo Dual Boot e Btrfs).
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-PART]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}      $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}    $*"; }

log "Iniciando detecção de discos..."

# 1. Listar discos disponíveis
DISKS=$(lsblk -dn -o NAME,SIZE,MODEL | grep -vE "loop|zram|sr")
log "Discos encontrados: \n${DISKS}"

# 2. Seleção de disco
echo -e "${YELLOW}Digite o nome do disco de destino (ex: sda, nvme0n1):${NC} "
read DISK_NAME
DISK_PATH="/dev/${DISK_NAME}"

if [ ! -b "$DISK_PATH" ]; then
    err "Disco ${DISK_PATH} não encontrado."
    exit 1
fi

# 3. Opções de particionamento
echo -e "${YELLOW}Selecione a opção de particionamento:${NC} "
echo "1. Apagar disco inteiro e instalar DragonBRX OS (Btrfs)"
echo "2. Instalar ao lado de um sistema operacional existente (Dual Boot)"
echo "3. Particionamento manual (requer gparted ou fdisk)"
read PART_OPTION

case "$PART_OPTION" in
    1)
        log "Limpando disco ${DISK_PATH}..."
        wipefs -a "$DISK_PATH"
        
        log "Criando tabela de partição GPT..."
        parted -s "$DISK_PATH" mklabel gpt
        
        log "Criando partição EFI (512MB)..."
        parted -s "$DISK_PATH" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK_PATH" set 1 esp on
        
        log "Criando partição raiz (Btrfs)..."
        parted -s "$DISK_PATH" mkpart primary btrfs 513MiB 100%
        
        log "Formatando partições..."
        mkfs.vfat -F32 "${DISK_PATH}1"
        mkfs.btrfs -f -L "DRAGONBRX_ROOT" "${DISK_PATH}2"
        
        ok "Disco particionado com sucesso para o DragonBRX OS."
        ;;
    2)
        warn "Dual Boot automático requer o Calamares. Redirecionando para o instalador gráfico..."
        calamares
        ;;
    3)
        log "Abrindo GParted para particionamento manual..."
        gparted "$DISK_PATH"
        ;;
    *)
        err "Opção inválida."
        exit 1
        ;;
esac

ok "Processo de particionamento concluído."
