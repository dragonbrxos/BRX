/* SPDX-License-Identifier: GPL-2.0 */
/*
 * KanelOS Universal Hardware Abstraction Layer — Header Público
 * Copyright (C) 2026 KanelOS Team
 */

#ifndef _KANEL_HAL_H
#define _KANEL_HAL_H

#include <linux/types.h>
#include <linux/device.h>
#include <linux/pci.h>

#define KANEL_HAL_VERSION "0.1.0"

/**
 * enum kanel_hw_type - Tipos de hardware suportados pelo KanelOS HAL
 *
 * Baseado na matriz de compatibilidade do kernel Linux 6.12 LTS
 * e documentação oficial dos fabricantes.
 */
enum kanel_hw_type {
	/* CPUs x86_64 */
	KANEL_HW_CPU_INTEL_CORE_12GEN_PLUS,  /* Alder Lake, Raptor Lake, Meteor Lake */
	KANEL_HW_CPU_AMD_RYZEN_5000_PLUS,    /* Zen 3, Zen 4, Zen 5 */
	KANEL_HW_CPU_AMD_RYZEN_AI,           /* Ryzen AI com NPU XDNA */
	KANEL_HW_CPU_INTEL_METEOR_LAKE,      /* Com NPU integrado */
	/* CPUs ARM64 */
	KANEL_HW_CPU_ARM64_QUALCOMM,         /* Snapdragon X Elite, etc. */
	KANEL_HW_CPU_ARM64_MEDIATEK,         /* Dimensity, etc. */
	KANEL_HW_CPU_ARM64_APPLE,            /* M1-M4 via Asahi Linux */
	KANEL_HW_CPU_ARM64_AMPERE,           /* Ampere Altra (servidores) */
	/* CPUs RISC-V */
	KANEL_HW_CPU_RISCV_SIFIVE,
	KANEL_HW_CPU_RISCV_STARFIVE,
	/* GPUs */
	KANEL_HW_GPU_AMD_RDNA2,              /* RX 6000 — amdgpu */
	KANEL_HW_GPU_AMD_RDNA3,              /* RX 7000 — amdgpu */
	KANEL_HW_GPU_AMD_RDNA4,              /* RX 9000 — amdgpu */
	KANEL_HW_GPU_INTEL_ARC_ALCHEMIST,   /* Arc A-series — xe/i915 */
	KANEL_HW_GPU_INTEL_ARC_BATTLEMAGE,  /* Arc B-series — xe */
	KANEL_HW_GPU_NVIDIA_RTX_20_40,      /* RTX 20-40 — nouveau+GSP */
	KANEL_HW_GPU_INTEL_IGPU_12GEN,      /* iGPU Intel 12th Gen+ — i915 */
	KANEL_HW_GPU_AMD_APU,               /* APU AMD — amdgpu */
	/* NPUs (Neural Processing Units) */
	KANEL_HW_NPU_AMD_XDNA,              /* Ryzen AI — amdxdna */
	KANEL_HW_NPU_INTEL,                 /* Meteor Lake+ — intel-npu */
	KANEL_HW_NPU_QUALCOMM,              /* Hexagon NPU */
	/* Storage */
	KANEL_HW_STORAGE_NVME_PCIE3,
	KANEL_HW_STORAGE_NVME_PCIE4,
	KANEL_HW_STORAGE_NVME_PCIE5,
	KANEL_HW_STORAGE_SATA_SSD,
	KANEL_HW_STORAGE_SATA_HDD,
	/* Rede */
	KANEL_HW_NET_WIFI6,                  /* 802.11ax */
	KANEL_HW_NET_WIFI6E,                 /* 802.11ax 6GHz */
	KANEL_HW_NET_WIFI7,                  /* 802.11be */
	KANEL_HW_NET_ETH_1GBE,
	KANEL_HW_NET_ETH_2_5GBE,
	KANEL_HW_NET_ETH_10GBE,
	KANEL_HW_NET_ETH_25GBE,
	KANEL_HW_NET_ETH_100GBE,
	KANEL_HW_UNKNOWN,
};

/**
 * struct kanel_hw_info - Informações de hardware detectado
 */
struct kanel_hw_info {
	enum kanel_hw_type  type;
	char                vendor[64];
	char                model[128];
	char                driver[64];
	char                driver_fallback[64];
	bool                driver_loaded;
	bool                fallback_active;
	u32                 capabilities;
	/* Informações adicionais */
	u32                 pci_vendor_id;
	u32                 pci_device_id;
	char                firmware_version[32];
};

/* Capacidades de hardware (bitmask) */
#define KANEL_CAP_POWER_MANAGEMENT   BIT(0)   /* P-states, C-states */
#define KANEL_CAP_HARDWARE_ACCEL     BIT(1)   /* Aceleração de hardware */
#define KANEL_CAP_SR_IOV             BIT(2)   /* Single Root I/O Virtualization */
#define KANEL_CAP_IOMMU              BIT(3)   /* IOMMU/VT-d/AMD-Vi */
#define KANEL_CAP_NPU                BIT(4)   /* Neural Processing Unit */
#define KANEL_CAP_RDMA               BIT(5)   /* Remote Direct Memory Access */
#define KANEL_CAP_NVME_IOPOLL        BIT(6)   /* NVMe polling mode */
#define KANEL_CAP_XDP                BIT(7)   /* eXpress Data Path */
#define KANEL_CAP_THUNDERBOLT        BIT(8)   /* Thunderbolt 3/4/USB4 */
#define KANEL_CAP_PCIE5              BIT(9)   /* PCIe 5.0 */
#define KANEL_CAP_DDR5               BIT(10)  /* DDR5 */
#define KANEL_CAP_CXL                BIT(11)  /* Compute Express Link */

/* API pública do HAL */
int  kanel_hal_init(void);
void kanel_hal_exit(void);
int  kanel_hal_detect_cpu(struct kanel_hw_info *info);
int  kanel_hal_detect_gpu(struct kanel_hw_info *info);
int  kanel_hal_detect_npu(struct kanel_hw_info *info);
int  kanel_hal_detect_storage(struct kanel_hw_info *info);
int  kanel_hal_detect_network(struct kanel_hw_info *info);
int  kanel_hal_apply_optimizations(struct kanel_hw_info *info);
const char *kanel_hal_hw_type_name(enum kanel_hw_type type);

#endif /* _KANEL_HAL_H */
