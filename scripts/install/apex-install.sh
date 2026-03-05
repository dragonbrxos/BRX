#!/bin/bash
# =============================================================================
# DragonBRX OS — Apex Installer (apex-install.sh)
# =============================================================================
# Este script é executado pelo Calamares no ambiente chroot do sistema de destino.
# Ele clona o repositório DragonBRX OS, compila o kernel, instala o Apex Core,
# o KDE Plasma e as ferramentas padrão.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m

log() { echo -e "${BLUE}[APEX-INSTALL]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}           $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}         $*"; }
err() { echo -e "${RED}[ERROR]${NC}        $*"; }

# Variáveis de ambiente passadas pelo Calamares
TARGET_ROOT="${CALAMARES_TARGET_ROOT}"
USERNAME="${CALAMARES_USERNAME}"
PASSWORD="${CALAMARES_PASSWORD}"
HOSTNAME="${CALAMARES_HOSTNAME}"
PROFILE="${CALAMARES_PROFILE:-desktop}"

if [ -z "$TARGET_ROOT" ]; then
    err "Variável TARGET_ROOT não definida. Este script deve ser executado pelo Calamares."
    exit 1
fi

log "Iniciando instalação do DragonBRX OS no ${TARGET_ROOT}..."

# 1. Clonar o repositório DragonBRX OS
log "Clonando repositório DragonBRX OS..."
GIT_REPO="https://github.com/dragonbrxos/BRX.git"
GIT_DIR="${TARGET_ROOT}/opt/dragonbrx"
mkdir -p "${GIT_DIR}"
git clone "${GIT_REPO}" "${GIT_DIR}" || err "Falha ao clonar o repositório."
ok "Repositório clonado com sucesso."

# 2. Instalar dependências de build no sistema de destino
log "Instalando dependências de build no sistema de destino..."
chroot "${TARGET_ROOT}" /opt/dragonbrx/scripts/install/build-deps.sh || err "Falha ao instalar dependências."
ok "Dependências de build instaladas."

# 3. Compilar e instalar o BRX Kernel
log "Compilando e instalando o BRX Kernel (perfil: ${PROFILE})..."
chroot "${TARGET_ROOT}" bash -c "cd /opt/dragonbrx && make kernel PROFILE=${PROFILE} -j$(nproc) && make install PROFILE=${PROFILE}" || err "Falha ao compilar/instalar o kernel."
ok "BRX Kernel compilado e instalado."

# 4. Instalar o Apex Core (pacotes base)
log "Instalando Apex Core (pacotes base)..."
# Exemplo: instalar pacotes essenciais via brx-pkg (que usará distrobox/apt)
chroot "${TARGET_ROOT}" /opt/dragonbrx/scripts/pkg/brx-pkg.sh install systemd networkmanager grub firefox konsole dolphin plasma-desktop sddm || err "Falha ao instalar Apex Core."
ok "Apex Core e KDE Plasma instalados."

# 5. Configurar o sistema
log "Configurando o sistema..."
chroot "${TARGET_ROOT}" bash -c "
    # Criar usuário
    useradd -m -G wheel,users,audio,video,storage,power -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${PASSWORD}" | chpasswd

    # Configurar hostname
    echo "${HOSTNAME}" > /etc/hostname

    # Habilitar serviços
    systemctl enable NetworkManager
    systemctl enable sddm

    # Aplicar configurações sysctl e udev do BRX
    /opt/dragonbrx/scripts/install/install-sysctl.sh
    /opt/dragonbrx/scripts/install/install-udev.sh

    # Configurar Firefox e Terminal
    /opt/dragonbrx/scripts/install/configure-firefox.sh
    /opt/dragonbrx/scripts/install/configure-terminal.sh

    # Configurar GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=DragonBRX
    grub-mkconfig -o /boot/grub/grub.cfg
"
ok "Sistema configurado."

log "Instalação do DragonBRX OS concluída! Reinicie o sistema."
