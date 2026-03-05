#!/bin/bash
# =============================================================================
# BRX OS — Gerenciador de Pacotes Universal (brx-pkg)
# =============================================================================
# Wrapper inteligente que unifica o gerenciamento de pacotes:
#   - Nativos (apt/pacman/dnf via distrobox)
#   - Universais (Flatpak)
#   - Portáteis (AppImage)
#   - Containers (Snap)
# =============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[BRX-PKG]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}      $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}    $*"; }
err() { echo -e "${RED}[ERROR]${NC}   $*"; }

show_help() {
    echo "BRX OS Package Manager Wrapper (brx-pkg)"
    echo ""
    echo "Uso: brx-pkg [AÇÃO] [PACOTE]"
    echo ""
    echo "Ações:"
    echo "  install   Instalar um pacote (tenta Flatpak -> Distrobox -> Snap)"
    echo "  remove    Remover um pacote"
    echo "  search    Procurar por um pacote"
    echo "  update    Atualizar todos os sistemas de pacotes"
    echo "  run       Rodar um AppImage"
    echo ""
    echo "Exemplos:"
    echo "  brx-pkg install discord"
    echo "  brx-pkg install steam"
    echo "  brx-pkg search vscode"
}

# 1. Instalar Pacote
install_pkg() {
    local PKG=$1
    log "Procurando '$PKG' em fontes universais (Flatpak)..."
    if flatpak install flathub "$PKG" -y 2>/dev/null; then
        ok "'$PKG' instalado via Flatpak."
        return 0
    fi

    log "'$PKG' não encontrado no Flatpak. Tentando via Distrobox (Base Debian)..."
    if command -v distrobox &> /dev/null; then
        distrobox enter brx-base -- sudo apt install "$PKG" -y 2>/dev/null && {
            ok "'$PKG' instalado via Distrobox (Debian)."
            return 0
        }
    fi

    log "Tentando via Snap..."
    if snap install "$PKG" 2>/dev/null; then
        ok "'$PKG' instalado via Snap."
        return 0
    fi

    err "Não foi possível encontrar '$PKG' em nenhuma fonte suportada."
    return 1
}

# 2. Atualizar Sistemas
update_all() {
    log "Atualizando Flatpaks..."
    flatpak update -y
    
    if command -v distrobox &> /dev/null; then
        log "Atualizando base Distrobox..."
        distrobox enter brx-base -- sudo apt update && sudo apt upgrade -y
    fi
    
    log "Atualizando Snaps..."
    snap refresh
    
    ok "Todos os sistemas de pacotes atualizados."
}

# Main
case "$1" in
    install)
        [ -z "$2" ] && show_help || install_pkg "$2"
        ;;
    update)
        update_all
        ;;
    search)
        log "Pesquisando no Flatpak..."
        flatpak search "$2"
        ;;
    help|*)
        show_help
        ;;
esac
