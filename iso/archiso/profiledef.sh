#!/usr/bin/env bash
# profiledef.sh

# Base do sistema
arch=
iso_name="dragonbrx"
iso_label="DRAGONBRX_$(date +%Y%m%d)"
iso_publisher="DragonBRX OS <https://dragonbrx.org>"
iso_application="DragonBRX Live/Install Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=("iso")
bootmodes=("bios.syslinux.mbr" "bios.syslinux.eltorito" "uefi-ia32.grub.esp" "uefi-x64.grub.esp" "uefi-ia32.grub.eltorito" "uefi-x64.grub.eltorito")
arch_x86_64_packages=(
    # Base do sistema
    base base-devel linux-firmware networkmanager git curl wget reflector
    # Ferramentas de disco
    parted fdisk e2fsprogs btrfs-progs dosfstools ntfs-3g
    # KDE Plasma
    plasma-desktop sddm konsole dolphin firefox
    # Calamares e dependências
    calamares calamares-settings-brx
    # Suporte a Wayland
    xorg-xwayland plasma-wayland-session
    # Drivers gráficos (mesa)
    mesa vulkan-radeon vulkan-intel
    # Utilitários
    sudo nano vim
)

arch_x86_64_packages_efi=("grub" "efibootmgr")

script_path="$(readlink -f ${0%/*})"

# Copiar scripts de instalação para o airootfs
copy_scripts() {
    mkdir -p "${airootfs}/opt/dragonbrx/scripts/install"
    cp -r "${script_path}/../../scripts/install/apex-install.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/configure-desktop.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/build-deps.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/install-sysctl.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/install-udev.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/brx-network-setup.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/brx-partition-setup.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/configure-firefox.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/install/configure-terminal.sh" "${airootfs}/opt/dragonbrx/scripts/install/"
    cp -r "${script_path}/../../scripts/drivers/brx-driver-manager.sh" "${airootfs}/opt/dragonbrx/scripts/drivers/"
    cp -r "${script_path}/../../scripts/pkg/brx-pkg.sh" "${airootfs}/opt/dragonbrx/scripts/pkg/"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/apex-install.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/configure-desktop.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/build-deps.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/install-sysctl.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/install-udev.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/brx-network-setup.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/brx-partition-setup.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/configure-firefox.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/install/configure-terminal.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/drivers/brx-driver-manager.sh"
    chmod +x "${airootfs}/opt/dragonbrx/scripts/pkg/brx-pkg.sh"
}

# Configurar autostart do Calamares
configure_calamares_autostart() {
    mkdir -p "${airootfs}/etc/skel/.config/autostart"
    cat << EOF > "${airootfs}/etc/skel/.config/autostart/calamares.desktop"
[Desktop Entry]
Type=Application
Name=Calamares Installer
Exec=calamares
Icon=calamares
Terminal=false
StartupNotify=false
EOF
}

# Configurar Calamares (exemplo mínimo)
configure_calamares() {
    mkdir -p "${airootfs}/usr/share/calamares/settings"
    cat << EOF > "${airootfs}/usr/share/calamares/settings/brx.conf"
--- # Calamares configuration for DragonBRX OS

branding: "DragonBRX"

welcome:
    - module: welcome
      options:
          welcome: "Bem-vindo ao DragonBRX OS!"

locale:
    - module: locale

keyboard:
    - module: keyboard

partition:
    - module: partition
      options:
          defaultFileSystem: "btrfs"
          defaultMountPoint: "/"
          enableLuks: true
          enableSwap: true

users:
    - module: users

summary:
    - module: summary

install:
    - module: shellprocess
      options:
          script: "/opt/dragonbrx/scripts/install/apex-install.sh"
          timeout: 3600 # 1 hour timeout for installation

bootloader:
    - module: bootloader

finish:
    - module: finished

EOF
}

# Hook para copiar scripts e configurar Calamares
build_hook() {
    copy_scripts
    configure_calamares_autostart
    configure_calamares
}

# Executar hook durante a construção da ISO
build_hook
