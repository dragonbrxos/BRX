#!/bin/bash
# =============================================================================
# DragonBRX OS — Configuração do Desktop e Ferramentas Padrão
# =============================================================================
# Este script é executado no ambiente chroot após a instalação do Apex Core
# e do KDE Plasma. Ele configura o ambiente gráfico e instala as aplicações
# essenciais.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-DESKTOP]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}            $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}          $*"; }
err() { echo -e "${RED}[ERROR]${NC}         $*"; }

log "Iniciando configuração do KDE Plasma e instalação de ferramentas padrão..."

# 1. Instalar Ferramentas Padrão
log "Instalando navegador (Firefox), terminal (Konsole) e gerenciador de arquivos (Dolphin)..."
# O brx-pkg já foi usado no apex-install.sh para instalar plasma-desktop, firefox, konsole, dolphin
# Esta etapa é mais para garantir que estão lá e configurar.

# 2. Configurações do KDE Plasma
log "Aplicando configurações padrão do KDE Plasma..."
# Exemplo: Definir tema, ícones, fontes, etc.
# Estas configurações seriam aplicadas via kwriteconfig ou copiando arquivos de configuração.
# Para simplificar, vamos criar um diretório para configs padrão.

mkdir -p /etc/skel/.config

# Exemplo de configuração de tema (apenas um placeholder)
cat << EOF > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
Theme=BreezeDark
EOF

cat << EOF > /etc/skel/.config/kwinrc
[Compositing]
Backend=wayland-egl
OpenGLIsUnsafe=false
MaxFPS=144
RefreshRate=144
EOF

# Definir Wayland como padrão para SDDM
log "Definindo Wayland como sessão padrão no SDDM..."
mkdir -p /etc/sddm.conf.d
cat << EOF > /etc/sddm.conf.d/autologin.conf
[Autologin]
Session=plasma-wayland.desktop
EOF

# 3. Configurar brx-pkg para o KDE Discover
log "Integrando brx-pkg ao KDE Discover..."
# Isso geralmente envolve a instalação de plugins para o Discover, como flatpak-kcm
# e garantir que o snapd esteja configurado.
# Para o brx-pkg, ele atuaria como um backend para o Discover.
# Por enquanto, apenas garantimos que o flatpak esteja habilitado.
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

# 4. Configurar brx-driver-manager
log "Configurando brx-driver-manager para inicialização automática..."
# Criar um serviço systemd para rodar o brx-driver-manager no boot
cat << EOF > /etc/systemd/system/brx-driver-manager.service
[Unit]
Description=DragonBRX OS Driver Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/dragonbrx/scripts/drivers/brx-driver-manager.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable brx-driver-manager.service || true

ok "Configuração do KDE Plasma e ferramentas padrão concluída."
