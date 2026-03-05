// SPDX-License-Identifier: GPL-2.0
/*
 * KanelOS Universal Hardware Abstraction Layer — Core
 * Copyright (C) 2026 KanelOS Team
 *
 * Este módulo implementa a detecção automática de hardware e o
 * carregamento inteligente de drivers para o KanelOS.
 *
 * Suporte de hardware baseado em dados reais de compatibilidade
 * do kernel Linux 6.12 LTS e documentação dos fabricantes.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/pci.h>
#include <linux/dmi.h>
#include <linux/cpu.h>
#include <linux/cpufreq.h>
#include <linux/platform_device.h>
#include <linux/acpi.h>
#include "kanel-hal.h"

MODULE_AUTHOR("KanelOS Team <dev@kanelos.org>");
MODULE_DESCRIPTION("KanelOS Universal Hardware Abstraction Layer");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("0.1.0");

/* =========================================================================
 * Tabela de IDs PCI para detecção de GPU
 * Baseada na tabela oficial do kernel Linux 6.12
 * ========================================================================= */

/* AMD GPUs — RDNA2 (RX 6000) e RDNA3 (RX 7000) */
static const struct pci_device_id kanel_amd_gpu_ids[] = {
	/* RDNA2 — Navi 21 (RX 6800/6900) */
	{ PCI_DEVICE(0x1002, 0x73BF) },  /* RX 6900 XT */
	{ PCI_DEVICE(0x1002, 0x73A5) },  /* RX 6950 XT */
	{ PCI_DEVICE(0x1002, 0x73A3) },  /* RX 6800 XT */
	/* RDNA2 — Navi 22 (RX 6700) */
	{ PCI_DEVICE(0x1002, 0x73DF) },  /* RX 6700 XT */
	/* RDNA2 — Navi 23 (RX 6600) */
	{ PCI_DEVICE(0x1002, 0x73FF) },  /* RX 6600 XT */
	/* RDNA3 — Navi 31 (RX 7900) */
	{ PCI_DEVICE(0x1002, 0x744C) },  /* RX 7900 XTX */
	{ PCI_DEVICE(0x1002, 0x7448) },  /* RX 7900 XT */
	/* RDNA3 — Navi 32 (RX 7800/7700) */
	{ PCI_DEVICE(0x1002, 0x747E) },  /* RX 7800 XT */
	/* RDNA3 — Navi 33 (RX 7600) */
	{ PCI_DEVICE(0x1002, 0x7480) },  /* RX 7600 */
	{ 0 }
};

/* Intel Arc GPUs — Alchemist (Arc A-series) */
static const struct pci_device_id kanel_intel_arc_ids[] = {
	{ PCI_DEVICE(0x8086, 0x56A0) },  /* Arc A770 */
	{ PCI_DEVICE(0x8086, 0x56A1) },  /* Arc A750 */
	{ PCI_DEVICE(0x8086, 0x56A5) },  /* Arc A380 */
	{ PCI_DEVICE(0x8086, 0x56A6) },  /* Arc A310 */
	{ PCI_DEVICE(0x8086, 0x5690) },  /* Arc A730M */
	{ PCI_DEVICE(0x8086, 0x5691) },  /* Arc A550M */
	{ 0 }
};

/* =========================================================================
 * Detecção de CPU
 * ========================================================================= */

/**
 * kanel_hal_detect_cpu - Detectar e classificar a CPU
 * @info: estrutura de informações a preencher
 *
 * Detecta o tipo de CPU e configura os parâmetros de otimização
 * adequados (governor, EPP, C-states, etc.)
 */
int kanel_hal_detect_cpu(struct kanel_hw_info *info)
{
	struct cpuinfo_x86 *c = &boot_cpu_data;
	const char *cpu_name = boot_cpu_data.x86_model_id;

	pr_info("kanel-hal: Detectando CPU: %s\n", cpu_name);

	/* Intel Core 12th Gen+ (Alder Lake, Raptor Lake, Meteor Lake) */
	if (c->x86_vendor == X86_VENDOR_INTEL) {
		if (c->x86_model >= 0x97) { /* Alder Lake+ */
			info->type = KANEL_HW_CPU_INTEL_CORE_12GEN_PLUS;
			strscpy(info->vendor, "Intel", sizeof(info->vendor));
			strscpy(info->driver, "intel_pstate", sizeof(info->driver));
			info->capabilities |= KANEL_CAP_POWER_MANAGEMENT;

			/* Meteor Lake tem NPU integrado */
			if (c->x86_model >= 0xAA) {
				info->capabilities |= KANEL_CAP_NPU;
				pr_info("kanel-hal: Intel NPU detectado (Meteor Lake)\n");
			}

			pr_info("kanel-hal: Intel Core 12th Gen+ detectado\n");
			pr_info("kanel-hal: Driver: intel_pstate com EPP\n");
		}
	}

	/* AMD Ryzen 5000+ (Zen 3, Zen 4, Zen 5) */
	else if (c->x86_vendor == X86_VENDOR_AMD) {
		if (c->x86_family >= 0x19) { /* Zen 3+ */
			info->type = KANEL_HW_CPU_AMD_RYZEN_5000_PLUS;
			strscpy(info->vendor, "AMD", sizeof(info->vendor));
			strscpy(info->driver, "amd_pstate", sizeof(info->driver));
			info->capabilities |= KANEL_CAP_POWER_MANAGEMENT;

			/* Ryzen AI tem NPU XDNA integrado */
			if (strstr(cpu_name, "Ryzen AI") ||
			    strstr(cpu_name, "8040") ||
			    strstr(cpu_name, "8050") ||
			    strstr(cpu_name, "9000")) {
				info->type = KANEL_HW_CPU_AMD_RYZEN_AI;
				info->capabilities |= KANEL_CAP_NPU;
				pr_info("kanel-hal: AMD Ryzen AI NPU detectado (XDNA)\n");
			}

			pr_info("kanel-hal: AMD Ryzen 5000+ detectado\n");
			pr_info("kanel-hal: Driver: amd_pstate com EPP (modo ativo)\n");
		}
	}

	/* ARM64 */
	else {
		info->type = KANEL_HW_CPU_ARM64_QUALCOMM;
		strscpy(info->vendor, "ARM", sizeof(info->vendor));
		strscpy(info->driver, "cppc_cpufreq", sizeof(info->driver));
	}

	info->driver_loaded = true;
	return 0;
}

/* =========================================================================
 * Detecção de GPU
 * ========================================================================= */

/**
 * kanel_hal_detect_gpu - Detectar GPU e configurar driver adequado
 * @info: estrutura de informações a preencher
 */
int kanel_hal_detect_gpu(struct kanel_hw_info *info)
{
	struct pci_dev *pdev = NULL;

	/* Procurar AMD GPU */
	for_each_pci_dev(pdev) {
		if (pdev->vendor == 0x1002) { /* AMD */
			/* RDNA3 (RX 7000) */
			if (pdev->device >= 0x7440 && pdev->device <= 0x74FF) {
				info->type = KANEL_HW_GPU_AMD_RDNA3;
				strscpy(info->vendor, "AMD", sizeof(info->vendor));
				strscpy(info->model, "Radeon RX 7000 (RDNA3)",
					sizeof(info->model));
				strscpy(info->driver, "amdgpu", sizeof(info->driver));
				info->capabilities |= KANEL_CAP_HARDWARE_ACCEL;
				pr_info("kanel-hal: AMD RDNA3 GPU detectada\n");
				goto gpu_found;
			}
			/* RDNA2 (RX 6000) */
			if (pdev->device >= 0x73A0 && pdev->device <= 0x73FF) {
				info->type = KANEL_HW_GPU_AMD_RDNA2;
				strscpy(info->vendor, "AMD", sizeof(info->vendor));
				strscpy(info->model, "Radeon RX 6000 (RDNA2)",
					sizeof(info->model));
				strscpy(info->driver, "amdgpu", sizeof(info->driver));
				info->capabilities |= KANEL_CAP_HARDWARE_ACCEL;
				pr_info("kanel-hal: AMD RDNA2 GPU detectada\n");
				goto gpu_found;
			}
		}

		/* Intel Arc */
		if (pdev->vendor == 0x8086 &&
		    pdev->device >= 0x5690 && pdev->device <= 0x56FF) {
			info->type = KANEL_HW_GPU_INTEL_ARC;
			strscpy(info->vendor, "Intel", sizeof(info->vendor));
			strscpy(info->model, "Intel Arc", sizeof(info->model));
			strscpy(info->driver, "xe", sizeof(info->driver));
			strscpy(info->driver_fallback, "i915",
				sizeof(info->driver_fallback));
			info->capabilities |= KANEL_CAP_HARDWARE_ACCEL;
			pr_info("kanel-hal: Intel Arc GPU detectada\n");
			goto gpu_found;
		}

		/* NVIDIA */
		if (pdev->vendor == 0x10DE) {
			info->type = KANEL_HW_GPU_NVIDIA_RTX;
			strscpy(info->vendor, "NVIDIA", sizeof(info->vendor));
			strscpy(info->model, "NVIDIA GPU", sizeof(info->model));
			/* Preferir nouveau com GSP firmware (open-source) */
			strscpy(info->driver, "nouveau", sizeof(info->driver));
			strscpy(info->driver_fallback, "nvidia",
				sizeof(info->driver_fallback));
			info->capabilities |= KANEL_CAP_HARDWARE_ACCEL;
			pr_info("kanel-hal: NVIDIA GPU detectada (usando nouveau+GSP)\n");
			goto gpu_found;
		}
	}

	pr_info("kanel-hal: Nenhuma GPU dedicada detectada, usando iGPU\n");
	return 0;

gpu_found:
	info->driver_loaded = true;
	return 0;
}

/* =========================================================================
 * Inicialização do HAL
 * ========================================================================= */

static int __init kanel_hal_init(void)
{
	struct kanel_hw_info cpu_info = {0};
	struct kanel_hw_info gpu_info = {0};

	pr_info("kanel-hal: KanelOS Hardware Abstraction Layer v0.1.0\n");
	pr_info("kanel-hal: Iniciando detecção de hardware...\n");

	/* Detectar CPU */
	if (kanel_hal_detect_cpu(&cpu_info) == 0) {
		pr_info("kanel-hal: CPU: %s (%s)\n",
			cpu_info.vendor, cpu_info.driver);
	}

	/* Detectar GPU */
	if (kanel_hal_detect_gpu(&gpu_info) == 0) {
		pr_info("kanel-hal: GPU: %s %s (%s)\n",
			gpu_info.vendor, gpu_info.model, gpu_info.driver);
	}

	pr_info("kanel-hal: Detecção de hardware concluída\n");
	return 0;
}

static void __exit kanel_hal_exit(void)
{
	pr_info("kanel-hal: HAL descarregado\n");
}

module_init(kanel_hal_init);
module_exit(kanel_hal_exit);
