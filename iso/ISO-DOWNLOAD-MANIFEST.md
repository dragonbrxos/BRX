# DragonBRX OS — ISO v0.4.0 Híbrida (MBR + GPT)

Esta ISO foi projetada para ser gravada em pendrives usando o **Rufus**, oferecendo compatibilidade total com computadores antigos (**BIOS/MBR**) e modernos (**UEFI/GPT**).

## 1. Especificações da ISO
- **Nome:** `dragonbrx-2026.03.05-desktop-x86_64.iso`
- **Formato:** ISO Híbrida (Isolinux + GRUB)
- **Base:** Apex Core (Linux 6.12 LTS)
- **Interface:** KDE Plasma 6 (Wayland)
- **Instalador:** Apex Installer (Calamares)

## 2. Como Gravar no Pendrive (Rufus)
Ao usar o Rufus para criar seu pendrive bootável do DragonBRX OS:

| Opção | Valor Recomendado |
|---|---|
| **Dispositivo** | Selecione seu Pendrive (Mínimo 8GB) |
| **Seleção de Boot** | `dragonbrx-desktop.iso` |
| **Esquema de Partição** | **MBR** (Para BIOS antigo) ou **GPT** (Para UEFI novo) |
| **Sistema de Destino** | **BIOS ou UEFI** |
| **Sistema de Arquivos** | FAT32 (Padrão) |

> **Dica:** O Rufus detectará automaticamente a ISO como Híbrida. Se perguntar sobre o modo de gravação, escolha **"Gravar em modo Imagem ISO"**.

## 3. Link de Download (Geração Dinâmica)
Devido ao tamanho da ISO (aprox. 2.4GB), ela é gerada sob demanda. Você pode baixar a estrutura completa do repositório e gerar a ISO em 1 clique:

```bash
# 1. Clone o repositório
git clone https://github.com/dragonbrxos/BRX.git
cd BRX

# 2. Gere a ISO (Requer Arch Linux ou Docker)
make iso PROFILE=desktop
```

---

## 4. Checksum de Verificação (SHA256)
Sempre verifique a integridade da sua ISO antes de gravar:
`sha256sum dragonbrx-desktop.iso`
*(O valor do hash será gerado ao final do build no diretório `output/`)*
