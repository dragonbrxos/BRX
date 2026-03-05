#!/bin/bash
# =============================================================================
# KanelOS — Instalador de Dependências de Build
# =============================================================================
# Suporta: Ubuntu/Debian, Fedora/RHEL, Arch Linux, openSUSE
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar root
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}Execute como root: sudo $0${NC}"
	exit 1
fi

# Detectar distribuição
detect_distro() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		echo "${ID}"
	else
		echo "unknown"
	fi
}

DISTRO=$(detect_distro)
echo -e "${BLUE}Distribuição detectada: ${DISTRO}${NC}"

# =============================================================================
# Ubuntu / Debian
# =============================================================================
install_debian() {
	echo -e "${GREEN}Instalando dependências para Ubuntu/Debian...${NC}"

	apt-get update -qq

	# Ferramentas de compilação do kernel
	apt-get install -y \
		build-essential \
		libncurses-dev \
		bison \
		flex \
		libssl-dev \
		libelf-dev \
		bc \
		git \
		fakeroot \
		cpio \
		kmod \
		xz-utils \
		wget \
		curl \
		dwarves \
		zstd \
		pahole

	# Ferramentas para LLVM/Clang (opcional, melhor performance)
	apt-get install -y \
		clang \
		llvm \
		lld \
		llvm-dev \
		libclang-dev || true

	# Ferramentas para eBPF
	apt-get install -y \
		libbpf-dev \
		bpftool \
		linux-headers-generic || true

	# Ferramentas para Rust no kernel
	apt-get install -y \
		rustc \
		cargo \
		bindgen || true

	# Ferramentas de ISO e boot
	apt-get install -y \
		squashfs-tools \
		xorriso \
		isolinux \
		syslinux-efi \
		grub-pc-bin \
		grub-efi-amd64-bin \
		mtools

	# Ferramentas de teste e QEMU
	apt-get install -y \
		qemu-system-x86 \
		qemu-system-arm \
		qemu-utils \
		gdb \
		strace \
		ltrace \
		perf-tools-unstable || apt-get install -y linux-perf || true

	# Ferramentas de desenvolvimento
	apt-get install -y \
		python3 \
		python3-pip \
		python3-venv \
		htop \
		tmux \
		vim \
		nano \
		jq

	# Python packages para documentação
	pip3 install --quiet \
		mkdocs \
		mkdocs-material \
		black \
		flake8 \
		pytest || true

	echo -e "${GREEN}✓ Dependências Ubuntu/Debian instaladas${NC}"
}

# =============================================================================
# Fedora / RHEL / CentOS
# =============================================================================
install_fedora() {
	echo -e "${GREEN}Instalando dependências para Fedora/RHEL...${NC}"

	dnf groupinstall -y "Development Tools"
	dnf install -y \
		ncurses-devel \
		bison \
		flex \
		openssl-devel \
		elfutils-libelf-devel \
		bc \
		git \
		fakeroot \
		cpio \
		kmod \
		xz \
		wget \
		curl \
		dwarves \
		zstd \
		clang \
		llvm \
		lld \
		libbpf-devel \
		bpftool \
		squashfs-tools \
		xorriso \
		syslinux \
		grub2-tools \
		qemu-system-x86 \
		gdb \
		strace \
		python3 \
		python3-pip \
		htop \
		tmux \
		vim

	echo -e "${GREEN}✓ Dependências Fedora/RHEL instaladas${NC}"
}

# =============================================================================
# Arch Linux
# =============================================================================
install_arch() {
	echo -e "${GREEN}Instalando dependências para Arch Linux...${NC}"

	pacman -Syu --noconfirm
	pacman -S --noconfirm \
		base-devel \
		ncurses \
		bison \
		flex \
		openssl \
		libelf \
		bc \
		git \
		fakeroot \
		cpio \
		kmod \
		xz \
		wget \
		curl \
		dwarves \
		zstd \
		clang \
		llvm \
		lld \
		libbpf \
		bpf \
		squashfs-tools \
		libisoburn \
		syslinux \
		grub \
		qemu-full \
		gdb \
		strace \
		python \
		python-pip \
		htop \
		tmux \
		vim \
		rust

	echo -e "${GREEN}✓ Dependências Arch Linux instaladas${NC}"
}

# =============================================================================
# openSUSE
# =============================================================================
install_opensuse() {
	echo -e "${GREEN}Instalando dependências para openSUSE...${NC}"

	zypper install -y \
		-t pattern devel_basis \
		ncurses-devel \
		bison \
		flex \
		libopenssl-devel \
		libelf-devel \
		bc \
		git \
		fakeroot \
		cpio \
		kmod \
		xz \
		wget \
		curl \
		dwarves \
		zstd \
		clang \
		llvm \
		lld \
		libbpf-devel \
		squashfs \
		xorriso \
		syslinux \
		grub2 \
		qemu-x86 \
		gdb \
		strace \
		python3 \
		python3-pip \
		htop \
		tmux \
		vim

	echo -e "${GREEN}✓ Dependências openSUSE instaladas${NC}"
}

# =============================================================================
# Main
# =============================================================================
main() {
	echo -e "${BLUE}"
	echo "╔══════════════════════════════════════════════════════╗"
	echo "║     KanelOS — Instalador de Dependências de Build   ║"
	echo "╚══════════════════════════════════════════════════════╝"
	echo -e "${NC}"

	case "${DISTRO}" in
		ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
			install_debian
			;;
		fedora|rhel|centos|rocky|almalinux|ol)
			install_fedora
			;;
		arch|manjaro|endeavouros|garuda|artix)
			install_arch
			;;
		opensuse*|sles)
			install_opensuse
			;;
		*)
			echo -e "${YELLOW}Distribuição não reconhecida: ${DISTRO}${NC}"
			echo "Instale manualmente:"
			echo "  gcc, make, bc, flex, bison"
			echo "  libncurses-dev, libssl-dev, libelf-dev"
			echo "  git, wget, cpio, kmod, xz-utils"
			echo "  clang, llvm, lld (opcional, para LLVM build)"
			echo "  libbpf-dev, bpftool (para eBPF)"
			exit 1
			;;
	esac

	echo ""
	echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
	echo -e "${GREEN}║     Dependências instaladas com sucesso!             ║${NC}"
	echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
	echo ""
	echo "Agora você pode compilar o KanelOS:"
	echo "  make kernel PROFILE=desktop"
	echo "  make iso PROFILE=desktop"
}

main "$@"
