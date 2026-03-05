# =============================================================================
# KanelOS — Makefile Principal
# Base: Linux 6.12 LTS
# Arquiteturas: x86_64, ARM64, RISC-V
# =============================================================================

# Versão do KanelOS
KANELOS_VERSION     := 0.1.0
KANELOS_CODENAME    := Cinnamon

# Versão do kernel base (Linux 6.12 LTS — suporte até Dez/2028)
KERNEL_VERSION      := 6.12.22
KERNEL_MAJOR        := 6
KERNEL_MINOR        := 12
KERNEL_URL          := https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(KERNEL_VERSION).tar.xz
KERNEL_SHA256_URL   := https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(KERNEL_VERSION).tar.sign

# Detectar arquitetura automaticamente
ARCH                ?= $(shell uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/;s/riscv64/riscv/')
CROSS_COMPILE       ?=

# Perfil de build (desktop | server | rt | laptop | minimal)
PROFILE             ?= desktop

# Diretórios
BUILD_DIR           := build
KERNEL_SRC          := $(BUILD_DIR)/linux-$(KERNEL_VERSION)
KERNEL_BUILD        := $(BUILD_DIR)/kernel-$(PROFILE)
OUTPUT_DIR          := output
PATCHES_DIR         := kernel/patches
CONFIGS_DIR         := kernel/configs
TOOLS_DIR           := tools

# Compilador
CC                  ?= gcc
CLANG               ?= clang
LLVM                ?= 0  # Definir como 1 para compilar com LLVM/Clang

# Flags de compilação
MAKEFLAGS           += --no-print-directory
JOBS                ?= $(shell nproc)

# Cores para output
RED                 := \033[0;31m
GREEN               := \033[0;32m
YELLOW              := \033[1;33m
BLUE                := \033[0;34m
CYAN                := \033[0;36m
NC                  := \033[0m

# =============================================================================
# Targets Principais
# =============================================================================

.PHONY: all kernel initramfs iso tools docs clean distclean help
.PHONY: download-kernel apply-patches configure-kernel
.PHONY: config-desktop config-server config-rt config-laptop
.PHONY: test benchmark install

## all: Compilar tudo (kernel + initramfs + tools)
all: kernel initramfs tools iso
	@echo -e "$(GREEN)✓ KanelOS $(KANELOS_VERSION) compilado com sucesso!$(NC)"
	@echo -e "$(CYAN)  Perfil: $(PROFILE) | Kernel: $(KERNEL_VERSION) | Arch: $(ARCH)$(NC)"

## kernel: Baixar, patchear e compilar o kernel
kernel: download-kernel apply-patches configure-kernel build-kernel

## download-kernel: Baixar o kernel base Linux 6.12 LTS
download-kernel:
	@echo -e "$(BLUE)→ Baixando Linux $(KERNEL_VERSION)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(BUILD_DIR)/linux-$(KERNEL_VERSION).tar.xz" ]; then \
		wget -q --show-progress -O $(BUILD_DIR)/linux-$(KERNEL_VERSION).tar.xz $(KERNEL_URL); \
	else \
		echo -e "$(YELLOW)  Arquivo já existe, pulando download.$(NC)"; \
	fi
	@if [ ! -d "$(KERNEL_SRC)" ]; then \
		echo -e "$(BLUE)→ Extraindo kernel...$(NC)"; \
		tar -xf $(BUILD_DIR)/linux-$(KERNEL_VERSION).tar.xz -C $(BUILD_DIR)/; \
	fi
	@echo -e "$(GREEN)✓ Kernel base pronto em $(KERNEL_SRC)$(NC)"

## apply-patches: Aplicar todos os patches do KanelOS
apply-patches: download-kernel
	@echo -e "$(BLUE)→ Aplicando patches KanelOS...$(NC)"
	@for patch in $(PATCHES_DIR)/0*.patch; do \
		if [ -f "$$patch" ]; then \
			echo -e "  $(CYAN)Aplicando: $$(basename $$patch)$(NC)"; \
			if head -1 "$$patch" | grep -q "^From [0-9a-f]\{40\} Mon Sep 17"; then \
				git -C $(KERNEL_SRC) am --3way --ignore-whitespace "$$patch" 2>/dev/null || \
				(git -C $(KERNEL_SRC) am --abort 2>/dev/null; \
				 patch -d $(KERNEL_SRC) -p1 --forward --silent < "$$patch" || \
				 echo -e "  $(YELLOW)  Patch já aplicado ou conflito: $$(basename $$patch)$(NC)"); \
			else \
				patch -d $(KERNEL_SRC) -p1 --forward --silent < "$$patch" || \
				echo -e "  $(YELLOW)  Patch já aplicado ou conflito: $$(basename $$patch)$(NC)"; \
			fi; \
		fi; \
	done
	@echo -e "$(GREEN)✓ Patches aplicados$(NC)"

## configure-kernel: Configurar o kernel com o perfil selecionado
configure-kernel: apply-patches
	@echo -e "$(BLUE)→ Configurando kernel (perfil: $(PROFILE))...$(NC)"
	@mkdir -p $(KERNEL_BUILD)
	@if [ -f "$(CONFIGS_DIR)/kanel-$(PROFILE).config" ]; then \
		# CORREÇÃO: copiar .config para KERNEL_BUILD (output dir), nao KERNEL_SRC \
		# Copiar para KERNEL_SRC causa "source tree is not clean" com O= separado \
		cp $(CONFIGS_DIR)/kanel-$(PROFILE).config $(KERNEL_BUILD)/.config; \
		$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) olddefconfig; \
	else \
		echo -e "$(RED)✗ Configuração não encontrada: $(CONFIGS_DIR)/kanel-$(PROFILE).config$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✓ Kernel configurado para perfil: $(PROFILE)$(NC)"

## build-kernel: Compilar o kernel configurado
build-kernel: configure-kernel
	@echo -e "$(BLUE)→ Compilando kernel Linux $(KERNEL_VERSION) ($(JOBS) threads)...$(NC)"
	@if [ "$(LLVM)" = "1" ]; then \
		$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) LLVM=1 -j$(JOBS); \
	else \
		$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) CC=$(CC) -j$(JOBS); \
	fi
	@echo -e "$(GREEN)✓ Kernel compilado$(NC)"

## initramfs: Construir o initramfs com hooks do KanelOS
initramfs:
	@echo -e "$(BLUE)→ Construindo initramfs...$(NC)"
	@bash initramfs/build/build-initramfs.sh $(PROFILE)
	@echo -e "$(GREEN)✓ Initramfs pronto$(NC)"

## iso: Gerar imagem ISO bootável do DragonBRX OS
iso: kernel initramfs
	@echo -e "$(BLUE)→ Gerando ISO para perfil: $(PROFILE)...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	@cd iso/archiso && sudo mkarchiso -v -o $(abspath $(OUTPUT_DIR)) $(PROFILE)
	@echo -e "$(GREEN)✓ ISO gerada em $(OUTPUT_DIR)/dragonbrx-$(KANELOS_VERSION)-$(PROFILE)-$(ARCH).iso$(NC)"

## tools: Compilar ferramentas do KanelOS
tools:
	@echo -e "$(BLUE)→ Compilando ferramentas KanelOS...$(NC)"
	@$(MAKE) -C $(TOOLS_DIR)/kanel-config
	@$(MAKE) -C $(TOOLS_DIR)/kanel-tune
	@$(MAKE) -C $(TOOLS_DIR)/kanel-monitor
	@$(MAKE) -C $(TOOLS_DIR)/kanel-update
	@echo -e "$(GREEN)✓ Ferramentas compiladas$(NC)"

## ebpf: Compilar programas eBPF
ebpf:
	@echo -e "$(BLUE)→ Compilando programas eBPF...$(NC)"
	@for dir in ebpf/*/; do \
		if [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir"; \
		fi; \
	done
	@echo -e "$(GREEN)✓ Programas eBPF compilados$(NC)"

## rust-drivers: Compilar drivers em Rust
rust-drivers:
	@echo -e "$(BLUE)→ Compilando drivers Rust...$(NC)"
	@cd rust && cargo build --release
	@echo -e "$(GREEN)✓ Drivers Rust compilados$(NC)"

# =============================================================================
# Configurações por Perfil
# =============================================================================

## config-desktop: Configurar para uso desktop/gaming
config-desktop:
	@$(MAKE) configure-kernel PROFILE=desktop
	@echo -e "$(GREEN)✓ Configurado para Desktop (EEVDF+BORE, PREEMPT, HZ=1000)$(NC)"

## config-server: Configurar para servidor
config-server:
	@$(MAKE) configure-kernel PROFILE=server
	@echo -e "$(GREEN)✓ Configurado para Servidor (EEVDF, PREEMPT_NONE, HZ=250)$(NC)"

## config-rt: Configurar para real-time
config-rt:
	@$(MAKE) configure-kernel PROFILE=rt
	@echo -e "$(GREEN)✓ Configurado para Real-Time (PREEMPT_RT, HZ=1000)$(NC)"

## config-laptop: Configurar para laptop (economia de energia)
config-laptop:
	@$(MAKE) configure-kernel PROFILE=laptop
	@echo -e "$(GREEN)✓ Configurado para Laptop (amd_pstate/intel_pstate EPP)$(NC)"

# =============================================================================
# Testes e Benchmarks
# =============================================================================

## test: Executar suite de testes
test:
	@echo -e "$(BLUE)→ Executando testes...$(NC)"
	@bash tests/run-tests.sh
	@echo -e "$(GREEN)✓ Testes concluídos$(NC)"

## benchmark: Executar benchmarks de performance
benchmark:
	@echo -e "$(BLUE)→ Executando benchmarks...$(NC)"
	@bash tests/performance/run-benchmarks.sh
	@echo -e "$(GREEN)✓ Benchmarks concluídos. Resultados em $(OUTPUT_DIR)/benchmarks/$(NC)"

## test-hardware: Testar compatibilidade de hardware
test-hardware:
	@echo -e "$(BLUE)→ Testando compatibilidade de hardware...$(NC)"
	@bash tests/hardware/detect-hardware.sh
	@echo -e "$(GREEN)✓ Relatório de hardware gerado$(NC)"

# =============================================================================
# Instalação
# =============================================================================

## install: Instalar o kernel compilado no sistema atual
install:
	@echo -e "$(YELLOW)⚠ Instalando KanelOS no sistema atual...$(NC)"
	@sudo $(MAKE) -C $(KERNEL_BUILD) modules_install
	@sudo cp $(KERNEL_BUILD)/arch/$(ARCH)/boot/bzImage /boot/vmlinuz-kanelos-$(KERNEL_VERSION)
	@sudo cp $(KERNEL_BUILD)/.config /boot/config-kanelos-$(KERNEL_VERSION)
	@sudo update-grub 2>/dev/null || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
	@echo -e "$(GREEN)✓ KanelOS instalado. Reinicie para usar.$(NC)"

## install-sysctl: Aplicar configurações sysctl otimizadas
install-sysctl:
	@echo -e "$(BLUE)→ Aplicando configurações sysctl...$(NC)"
	@sudo cp sysctl/kanel-performance.conf /etc/sysctl.d/99-kanelos.conf
	@sudo sysctl --system
	@echo -e "$(GREEN)✓ Configurações sysctl aplicadas$(NC)"

## install-udev: Instalar regras udev do KanelOS
install-udev:
	@echo -e "$(BLUE)→ Instalando regras udev...$(NC)"
	@sudo cp udev/rules.d/*.rules /etc/udev/rules.d/
	@sudo udevadm control --reload-rules
	@echo -e "$(GREEN)✓ Regras udev instaladas$(NC)"

# =============================================================================
# Documentação
# =============================================================================

## docs: Gerar documentação HTML
docs:
	@echo -e "$(BLUE)→ Gerando documentação...$(NC)"
	@mkdocs build --config-file docs/mkdocs.yml
	@echo -e "$(GREEN)✓ Documentação gerada em site/$(NC)"

## docs-serve: Servir documentação localmente
docs-serve:
	@mkdocs serve --config-file docs/mkdocs.yml

# =============================================================================
# Limpeza
# =============================================================================

## clean: Limpar artefatos de build
clean:
	@echo -e "$(BLUE)→ Limpando build...$(NC)"
	@rm -rf $(BUILD_DIR)/kernel-*
	@rm -rf $(OUTPUT_DIR)
	@rm -rf iso/archiso/out
	@echo -e "$(GREEN)✓ Build limpo$(NC)"

## distclean: Limpeza completa (incluindo kernel baixado)
distclean: clean
	@echo -e "$(BLUE)→ Limpeza completa...$(NC)"
	@rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)✓ Limpeza completa$(NC)"

# =============================================================================
# Informações
# =============================================================================

## info: Mostrar informações de build
info:
	@echo -e "$(CYAN)KanelOS Build Information$(NC)"
	@echo -e "  Versão:         $(KANELOS_VERSION) ($(KANELOS_CODENAME))"
	@echo -e "  Kernel Base:    Linux $(KERNEL_VERSION) LTS"
	@echo -e "  Arquitetura:    $(ARCH)"
	@echo -e "  Perfil:         $(PROFILE)"
	@echo -e "  Compilador:     $(CC) (LLVM=$(LLVM))"
	@echo -e "  Threads:        $(JOBS)"
	@echo -e "  Build Dir:      $(BUILD_DIR)"

## help: Mostrar esta ajuda
help:
	@echo -e "$(CYAN)KanelOS $(KANELOS_VERSION) — Makefile$(NC)"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | \
		awk -F': ' '{printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(YELLOW)Variáveis configuráveis:$(NC)"
	@echo -e "  PROFILE=desktop|server|rt|laptop  (padrão: desktop)"
	@echo -e "  ARCH=x86_64|arm64|riscv           (padrão: detectado)"
	@echo -e "  LLVM=0|1                           (padrão: 0, usar GCC)"
	@echo -e "  JOBS=N                             (padrão: nproc)"
	@echo ""
	@echo -e "$(YELLOW)Exemplos:$(NC)"
	@echo -e "  make kernel PROFILE=desktop"
	@echo -e "  make iso PROFILE=server LLVM=1"
	@echo -e "  make config-rt"
	@echo -e "  make benchmark"
