// SPDX-License-Identifier: GPL-2.0
//! KanelOS HAL — Módulo Rust para Detecção de Hardware
//!
//! Este módulo implementa parte do HAL em Rust, aproveitando o suporte
//! nativo a Rust no kernel Linux 6.12+.
//!
//! Vantagens do Rust no kernel:
//! - Segurança de memória garantida em tempo de compilação
//! - Eliminação de use-after-free, buffer overflow, data races
//! - Abstrações de alto nível sem overhead de runtime
//!
//! Copyright (C) 2026 KanelOS Team

use kernel::prelude::*;
use kernel::pci;
use kernel::device::Device;

module! {
    type: KanelHalRust,
    name: "kanel_hal_rust",
    author: "KanelOS Team",
    description: "KanelOS HAL — Rust module for hardware detection",
    license: "GPL v2",
}

/// Identificadores PCI de GPUs suportadas
/// Baseado na tabela oficial do kernel Linux 6.12
const AMD_VENDOR_ID: u32 = 0x1002;
const INTEL_VENDOR_ID: u32 = 0x8086;
const NVIDIA_VENDOR_ID: u32 = 0x10DE;

/// Tipo de GPU detectada
#[derive(Debug, Clone, Copy, PartialEq)]
enum GpuType {
    AmdRdna2,    // RX 6000 series
    AmdRdna3,    // RX 7000 series
    AmdRdna4,    // RX 9000 series
    IntelArc,    // Arc A/B series
    NvidiaRtx,   // RTX 20-40 series
    IntelIgpu,   // Intel iGPU (i915)
    AmdApu,      // AMD APU (amdgpu integrado)
    Unknown,
}

/// Informações de GPU detectada
struct GpuInfo {
    gpu_type: GpuType,
    vendor_id: u32,
    device_id: u32,
    driver: &'static str,
    driver_fallback: Option<&'static str>,
}

impl GpuInfo {
    /// Detectar tipo de GPU a partir dos IDs PCI
    fn from_pci_ids(vendor_id: u32, device_id: u32) -> Self {
        let (gpu_type, driver, fallback) = match vendor_id {
            AMD_VENDOR_ID => {
                match device_id {
                    // RDNA4 (RX 9000) — lançado 2025
                    0x7600..=0x76FF => (GpuType::AmdRdna4, "amdgpu", None),
                    // RDNA3 (RX 7000)
                    0x7440..=0x74FF => (GpuType::AmdRdna3, "amdgpu", None),
                    // RDNA2 (RX 6000)
                    0x73A0..=0x73FF => (GpuType::AmdRdna2, "amdgpu", None),
                    // APU AMD (Ryzen com gráficos integrados)
                    0x1681 | 0x164C | 0x1636 => (GpuType::AmdApu, "amdgpu", None),
                    _ => (GpuType::Unknown, "amdgpu", None),
                }
            }
            INTEL_VENDOR_ID => {
                match device_id {
                    // Intel Arc Battlemage (B-series, 2024)
                    0x5700..=0x57FF => (GpuType::IntelArc, "xe", None),
                    // Intel Arc Alchemist (A-series)
                    0x5690..=0x56FF => (GpuType::IntelArc, "xe", Some("i915")),
                    // Intel iGPU (Alder Lake, Raptor Lake, Meteor Lake)
                    0x4600..=0x46FF | 0xA700..=0xA7FF => {
                        (GpuType::IntelIgpu, "i915", None)
                    }
                    _ => (GpuType::Unknown, "i915", None),
                }
            }
            NVIDIA_VENDOR_ID => {
                // Usar nouveau com GSP firmware (open-source)
                // GSP firmware disponível para RTX 20-40 series
                (GpuType::NvidiaRtx, "nouveau", Some("nvidia"))
            }
            _ => (GpuType::Unknown, "vesa", None),
        };

        Self {
            gpu_type,
            vendor_id,
            device_id,
            driver,
            driver_fallback: fallback,
        }
    }

    /// Verificar se a GPU tem suporte a aceleração de hardware
    fn has_hardware_accel(&self) -> bool {
        !matches!(self.gpu_type, GpuType::Unknown)
    }

    /// Obter nome legível do tipo de GPU
    fn type_name(&self) -> &'static str {
        match self.gpu_type {
            GpuType::AmdRdna4  => "AMD Radeon RX 9000 (RDNA4)",
            GpuType::AmdRdna3  => "AMD Radeon RX 7000 (RDNA3)",
            GpuType::AmdRdna2  => "AMD Radeon RX 6000 (RDNA2)",
            GpuType::AmdApu    => "AMD APU (gráficos integrados)",
            GpuType::IntelArc  => "Intel Arc",
            GpuType::IntelIgpu => "Intel iGPU",
            GpuType::NvidiaRtx => "NVIDIA RTX (nouveau + GSP)",
            GpuType::Unknown   => "GPU desconhecida",
        }
    }
}

/// Estrutura principal do módulo
struct KanelHalRust;

impl kernel::Module for KanelHalRust {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("KanelOS HAL Rust module v0.1.0\n");
        pr_info!("Detectando hardware via PCI...\n");

        // Detectar GPUs via PCI
        // Nota: Em produção, usar pci::Device::find_by_id()
        // Esta é uma implementação de demonstração
        let gpu = GpuInfo::from_pci_ids(AMD_VENDOR_ID, 0x744C);

        pr_info!("GPU detectada: {}\n", gpu.type_name());
        pr_info!("Driver: {}\n", gpu.driver);

        if let Some(fallback) = gpu.driver_fallback {
            pr_info!("Driver fallback: {}\n", fallback);
        }

        if gpu.has_hardware_accel() {
            pr_info!("Aceleração de hardware: disponível\n");
        }

        Ok(KanelHalRust)
    }
}

impl Drop for KanelHalRust {
    fn drop(&mut self) {
        pr_info!("KanelOS HAL Rust module descarregado\n");
    }
}

/// Testes unitários do módulo Rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_amd_rdna3_detection() {
        let gpu = GpuInfo::from_pci_ids(0x1002, 0x744C); // RX 7900 XTX
        assert_eq!(gpu.gpu_type, GpuType::AmdRdna3);
        assert_eq!(gpu.driver, "amdgpu");
        assert!(gpu.has_hardware_accel());
    }

    #[test]
    fn test_intel_arc_detection() {
        let gpu = GpuInfo::from_pci_ids(0x8086, 0x56A0); // Arc A770
        assert_eq!(gpu.gpu_type, GpuType::IntelArc);
        assert_eq!(gpu.driver, "xe");
        assert_eq!(gpu.driver_fallback, Some("i915"));
    }

    #[test]
    fn test_nvidia_detection() {
        let gpu = GpuInfo::from_pci_ids(0x10DE, 0x2684); // RTX 4090
        assert_eq!(gpu.gpu_type, GpuType::NvidiaRtx);
        assert_eq!(gpu.driver, "nouveau");
    }

    #[test]
    fn test_unknown_vendor() {
        let gpu = GpuInfo::from_pci_ids(0xFFFF, 0x0000);
        assert_eq!(gpu.gpu_type, GpuType::Unknown);
        assert!(!gpu.has_hardware_accel());
    }
}
