#!/bin/bash
# =============================================================================
# KanelOS — Script de Compilação do Kernel
# =============================================================================
# Uso: ./build-kernel.sh [PROFILE] [ARCH] [JOBS]
#
# Exemplos:
#   ./build-kernel.sh desktop x86_64 $(nproc)
#   ./build-kernel.sh server x86_64 8
#   ./build-kernel.sh rt arm64 4
# =============================================================================

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parâmetros
PROFILE="${1:-desktop}"
ARCH="${2:-$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/')}"
JOBS="${3:-$(nproc)}"

# Versão do kernel base
KERNEL_VERSION="6.12.22"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
KERNEL_SRC="${BUILD_DIR}/linux-${KERNEL_VERSION}"
KERNEL_BUILD="${BUILD_DIR}/kernel-${PROFILE}-${ARCH}"
PATCHES_DIR="${PROJECT_DIR}/kernel/patches"
CONFIGS_DIR="${PROJECT_DIR}/kernel/configs"

# Verificar se estamos usando LLVM
USE_LLVM="${USE_LLVM:-0}"

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# =============================================================================
# Verificar dependências
# =============================================================================
check_deps() {
	log_info "Verificando dependências..."

	local deps=(gcc make bc flex bison libssl-dev libelf-dev git wget pahole dwarves libzstd-dev)

	if [ "${USE_LLVM}" = "1" ]; then
		deps+=(clang llvm lld)
	fi

	local missing=()
	for dep in "${deps[@]}"; do
		if ! dpkg -l "${dep}" &>/dev/null 2>&1 && ! command -v "${dep}" &>/dev/null; then
			missing+=("${dep}")
		fi
	done

	if [ ${#missing[@]} -gt 0 ]; then
		log_warn "Dependências faltando: ${missing[*]}"
		log_info "Instalando dependências..."
		sudo apt-get install -y "${missing[@]}" || \
			log_error "Falha ao instalar dependências"
	fi

	log_ok "Dependências verificadas"
}

# =============================================================================
# Baixar kernel
# =============================================================================
download_kernel() {
	log_info "Verificando kernel Linux ${KERNEL_VERSION}..."
	mkdir -p "${BUILD_DIR}"

	if [ ! -f "${BUILD_DIR}/linux-${KERNEL_VERSION}.tar.xz" ]; then
		log_info "Baixando Linux ${KERNEL_VERSION}..."
		wget -q --show-progress \
			-O "${BUILD_DIR}/linux-${KERNEL_VERSION}.tar.xz" \
			"${KERNEL_URL}" || log_error "Falha ao baixar kernel"
		log_ok "Kernel baixado"
	else
		log_info "Kernel já baixado, pulando..."
	fi

	if [ ! -d "${KERNEL_SRC}" ]; then
		log_info "Extraindo kernel..."
		tar -xf "${BUILD_DIR}/linux-${KERNEL_VERSION}.tar.xz" \
			-C "${BUILD_DIR}/" || log_error "Falha ao extrair kernel"
		log_ok "Kernel extraído em ${KERNEL_SRC}"
	fi

	# Inicializar repositório git no source tree (necessário para git am)
	if [ ! -d "${KERNEL_SRC}/.git" ]; then
		log_info "Inicializando repositório git no source tree..."
		git -C "${KERNEL_SRC}" init -q
		git -C "${KERNEL_SRC}" add -A
		git -C "${KERNEL_SRC}" commit -q -m "Linux ${KERNEL_VERSION} vanilla" \
			--author="Linux Kernel <torvalds@linux-foundation.org>"
		log_ok "Repositório git inicializado"
	fi
}

# =============================================================================
# Aplicar patches
# =============================================================================
apply_patches() {
	log_info "Aplicando patches KanelOS..."

	if [ ! -d "${PATCHES_DIR}" ]; then
		log_warn "Diretório de patches não encontrado: ${PATCHES_DIR}"
		return 0
	fi

	local patch_count=0
	local failed_count=0

	for patch in "${PATCHES_DIR}"/[0-9]*.patch; do
		[ -f "${patch}" ] || continue
		local patch_name
		patch_name="$(basename "${patch}")"

		log_info "  Aplicando: ${patch_name}"

		# Usar git am para patches no formato mbox (From HASH Mon Sep 17...)
		# Usar patch -p1 como fallback para patches no formato diff puro
		if head -1 "${patch}" | grep -q "^From [0-9a-f]\{40\} Mon Sep 17"; then
			# Formato mbox git - usar git am
			if git -C "${KERNEL_SRC}" am --3way --ignore-whitespace \
				"${patch}" 2>/dev/null; then
				((patch_count++))
				log_ok "  Aplicado (git am): ${patch_name}"
			else
				git -C "${KERNEL_SRC}" am --abort 2>/dev/null || true
				log_warn "  Falha (git am): ${patch_name} — tentando patch -p1..."
				if patch -d "${KERNEL_SRC}" -p1 --forward --silent < "${patch}" 2>/dev/null; then
					((patch_count++))
					log_ok "  Aplicado (patch): ${patch_name}"
				else
					log_warn "  Patch já aplicado ou conflito: ${patch_name}"
				fi
			fi
		else
			# Formato diff puro - usar patch -p1
			if patch -d "${KERNEL_SRC}" -p1 --forward --dry-run \
				--silent < "${patch}" 2>/dev/null; then
				patch -d "${KERNEL_SRC}" -p1 --forward \
					--silent < "${patch}" || {
					log_warn "  Falha ao aplicar: ${patch_name}"
					((failed_count++))
					continue
				}
				((patch_count++))
				log_ok "  Aplicado: ${patch_name}"
			else
				log_warn "  Patch já aplicado ou conflito: ${patch_name}"
			fi
		fi
	done

	log_ok "Patches: ${patch_count} aplicados, ${failed_count} falhas"
}

# =============================================================================
# Configurar kernel
# =============================================================================
configure_kernel() {
	log_info "Configurando kernel (perfil: ${PROFILE}, arch: ${ARCH})..."

	local config_file="${CONFIGS_DIR}/kanel-${PROFILE}.config"

	if [ ! -f "${config_file}" ]; then
		log_error "Configuração não encontrada: ${config_file}"
	fi

	# CORREÇÃO: copiar .config para KERNEL_BUILD (output dir), NÃO para KERNEL_SRC
	# Copiar para KERNEL_SRC causa "source tree is not clean" ao usar O= separado
	mkdir -p "${KERNEL_BUILD}"
	cp "${config_file}" "${KERNEL_BUILD}/.config"

	# Atualizar configuração para o kernel atual
	# O olddefconfig usa KERNEL_BUILD/.config automaticamente com O=
	make -C "${KERNEL_SRC}" O="${KERNEL_BUILD}" \
		ARCH="${ARCH}" \
		olddefconfig 2>&1 | grep -v "^$" || true

	log_ok "Kernel configurado"
}

# =============================================================================
# Compilar kernel
# =============================================================================
build_kernel() {
	log_info "Compilando kernel Linux ${KERNEL_VERSION}..."
	log_info "  Perfil: ${PROFILE} | Arch: ${ARCH} | Jobs: ${JOBS}"

	local make_args=(
		-C "${KERNEL_SRC}"
		O="${KERNEL_BUILD}"
		ARCH="${ARCH}"
		-j"${JOBS}"
	)

	if [ "${USE_LLVM}" = "1" ]; then
		make_args+=(LLVM=1 LLVM_IAS=1)
		log_info "  Compilador: LLVM/Clang"
	else
		log_info "  Compilador: GCC"
	fi

	# Compilar kernel, módulos e DTBs (ARM)
	make "${make_args[@]}" all

	log_ok "Kernel compilado com sucesso!"

	# Mostrar informações do kernel compilado
	local kernel_image
	case "${ARCH}" in
		x86_64) kernel_image="${KERNEL_BUILD}/arch/x86/boot/bzImage" ;;
		arm64)  kernel_image="${KERNEL_BUILD}/arch/arm64/boot/Image.gz" ;;
		riscv)  kernel_image="${KERNEL_BUILD}/arch/riscv/boot/Image.gz" ;;
	esac

	if [ -f "${kernel_image}" ]; then
		local size
		size=$(du -sh "${kernel_image}" | cut -f1)
		log_ok "  Imagem: ${kernel_image} (${size})"
	fi
}

# =============================================================================
# Instalar módulos
# =============================================================================
install_modules() {
	local install_dir="${1:-${BUILD_DIR}/modules-${PROFILE}}"
	log_info "Instalando módulos em ${install_dir}..."

	mkdir -p "${install_dir}"
	make -C "${KERNEL_SRC}" O="${KERNEL_BUILD}" \
		ARCH="${ARCH}" \
		INSTALL_MOD_PATH="${install_dir}" \
		modules_install

	log_ok "Módulos instalados"
}

# =============================================================================
# Gerar pacote Debian
# =============================================================================
build_deb_package() {
	log_info "Gerando pacote Debian..."

	make -C "${KERNEL_SRC}" O="${KERNEL_BUILD}" \
		ARCH="${ARCH}" \
		-j"${JOBS}" \
		bindeb-pkg \
		KDEB_PKGVERSION="kanelos-${PROFILE}"

	log_ok "Pacote Debian gerado em ${BUILD_DIR}/"
}

# =============================================================================
# Main
# =============================================================================
main() {
	echo -e "${CYAN}"
	echo "╔══════════════════════════════════════════════════════╗"
	echo "║         KanelOS Kernel Build System v0.1.0          ║"
	echo "╚══════════════════════════════════════════════════════╝"
	echo -e "${NC}"

	log_info "Perfil: ${PROFILE} | Arch: ${ARCH} | Jobs: ${JOBS}"
	echo ""

	check_deps
	download_kernel
	apply_patches
	configure_kernel
	build_kernel

	echo ""
	echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
	echo -e "${GREEN}║         Compilação concluída com sucesso!            ║${NC}"
	echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
	echo ""
	log_info "Próximos passos:"
	echo "  1. make initramfs PROFILE=${PROFILE}"
	echo "  2. make iso PROFILE=${PROFILE}"
	echo "  3. sudo make install (para instalar no sistema atual)"
}

main "$@"
