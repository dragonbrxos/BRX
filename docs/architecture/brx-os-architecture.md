# BRX — Arquitetura Completa do Sistema Operacional

**Versão do Documento:** 0.2.0  
**Data:** Março de 2026  
**Base do Kernel:** Linux 6.12 LTS

---

## 1. Visão Geral do BRX

O **BRX** é uma nova geração de distribuição Linux projetada para oferecer desempenho extremo, compatibilidade universal de hardware e software, e uma experiência de usuário otimizada para jogos e desenvolvimento. Diferente de distribuições tradicionais, o BRX foca em resolver limitações históricas como a fragmentação de drivers, a complexidade de instalação e a compatibilidade de aplicativos, buscando um equilíbrio entre a flexibilidade do Arch Linux e a facilidade de uso de sistemas mais amigáveis [1].

O sistema é construído sobre uma base modular e open source, capaz de rodar eficientemente em hardware antigo, intermediário ou moderno, incluindo notebooks e desktops. A arquitetura do BRX é dividida em três camadas principais: o Kernel Otimizado (BRX Kernel), a Base do Sistema e a Interface Gráfica.

## 2. Arquitetura do Sistema

```
BRX - Arquitetura em Camadas:

┌─────────────────────────────────────────────────────────────────┐
│  Camada 3: Interface Gráfica (KDE Plasma + Wayland)             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  KDE Plasma: Personalização, desempenho, interface moderna │   │
│  │  Wayland: Display server de baixa latência, HDR/VRR       │   │
│  │  Vulkan: API gráfica principal para jogos                 │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  Camada 2: Base do Sistema (Gerenciamento Universal)            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  brx-pkg: Gerenciador de pacotes universal (deb, rpm, flatpak, snap, AppImage) │   │
│  │  brx-driver-manager: Banco universal de drivers (open/prop, firmware) │   │
│  │  brx-game-mode: Otimização de performance para jogos      │   │
│  │  Waydroid: Compatibilidade com aplicativos Android        │   │
│  │  Wine/Proton: Compatibilidade com aplicativos Windows     │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  Camada 1: Kernel Otimizado (BRX Kernel - KanelOS v0.1.0)       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Linux 6.12 LTS: PREEMPT_RT, EEVDF+BORE, sched_ext        │   │
│  │  Kanel-HAL: Detecção automática de hardware (C/Rust)      │   │
│  │  Kanel-AI Engine: Otimização preditiva via eBPF           │   │
│  │  io_uring: I/O de alta performance (IOPOLL, zero-copy)    │   │
│  │  MGLRU + Zswap/Zstd: Gerenciamento de memória avançado    │   │
│  │  TCP BBR v3 + XDP: Pilha de rede otimizada                │   │
│  │  IPE + BPF LSM: Segurança em múltiplas camadas            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Kernel Otimizado (BRX Kernel)

O coração do BRX é o **KanelOS v0.1.0**, um kernel Linux 6.12 LTS altamente otimizado, desenvolvido com foco em baixa latência, escalonamento eficiente de CPU, gerenciamento de memória e suporte amplo a drivers. As decisões de design são baseadas em benchmarks reais e tecnologias de ponta [2].

### 3.1 Scheduler

O BRX Kernel utiliza uma abordagem de scheduler em três camadas para garantir responsividade e throughput ideais [3]:

- **PREEMPT_RT (mainline)**: Para perfis de tempo real, garantindo latência determinística. O Linux 6.12 LTS é a primeira versão a incluir o PREEMPT_RT no mainline, eliminando a necessidade de patches externos [4].
- **EEVDF + BORE**: O EEVDF (Earliest Eligible Virtual Deadline First) é o scheduler padrão, complementado pelo patch BORE (Burst-Oriented Response Enhancer). O BORE prioriza tarefas interativas (jogos, UI) ao penalizar tarefas de background que consomem CPU continuamente, resultando em latências médias de ~3.2 μs e picos de ~10 μs, uma melhoria de 4.6x e 3.7x respectivamente em relação ao kernel vanilla [2].
- **sched_ext (BPF scheduler)**: Permite a implementação de schedulers personalizados como programas eBPF, carregados dinamicamente. O BRX utiliza o `scx_kanel` para seleção NUMA-aware de CPU e priorização dinâmica de tarefas [5].

### 3.2 Gerenciamento de Memória

O BRX implementa otimizações avançadas para o gerenciamento de memória, visando reduzir o uso e a latência [2]:

- **MGLRU (Multi-Generational LRU)**: Organiza páginas em múltiplas gerações para identificar com precisão páginas "frias" a serem evictadas, resultando em 20-40% menos page faults em workloads mistos [6].
- **Zswap com Zstd**: Comprime páginas swap em RAM antes de escrevê-las no disco, utilizando o algoritmo Zstd para uma compressão de ~3:1 com alta velocidade. Isso permite manter mais dados em RAM comprimida, reduzindo a dependência do swap em disco [2].
- **KSM (Kernel Same-page Merging)**: Habilitado e configurado para desktops, otimiza a deduplicação de páginas idênticas.

### 3.3 Subsistema de I/O

O BRX maximiza o uso do `io_uring` para I/O de alta performance [2]:

- **IOPOLL**: Polling ativo para NVMe PCIe 4.0/5.0, eliminando interrupções e alcançando ~546k IOPS com latência de ~0.08ms [2].
- **Zero-copy operations**: Buffers registrados evitam cópias desnecessárias entre kernel e userspace.
- **Multishot Receives**: Uma única syscall para múltiplas operações de rede, reduzindo o overhead em 60-80% [2].

### 3.4 Pilha de Rede

- **TCP BBR v3**: Algoritmo de controle de congestionamento padrão, oferecendo 2-25% mais throughput e 30-50% menos latência em redes congestionadas [2].
- **XDP/eBPF Networking**: Processamento de pacotes no nível mais baixo possível para máxima performance [2].

### 3.5 Segurança

O BRX implementa um modelo de segurança em múltiplas camadas [2]:

- **IPE (Integrity Policy Enforcement)**: Novo LSM no Linux 6.12 que restringe a execução a binários verificados, garantindo um boot seguro [7].
- **BPF LSM**: Permite políticas de segurança dinâmicas via programas eBPF.
- **Kernel Hardening**: Inclui KASLR, Shadow Stack (Intel CET), CFI (Clang) e KPTI.

### 3.6 Suporte a Rust no Kernel

O Linux 6.12 inclui suporte estável a drivers escritos em Rust, aproveitado pelo BRX para desenvolver drivers com segurança de memória garantida em tempo de compilação [2].

### 3.7 Kanel-HAL: Abstração de Hardware Universal

O Kanel-HAL detecta automaticamente o hardware e configura drivers e parâmetros otimizados. A matriz de suporte abrange CPUs (Intel Core 12th+, AMD Ryzen 5000+, ARM64, RISC-V), GPUs (AMD RDNA2/3/4, Intel Arc, NVIDIA via nouveau+GSP), NPUs (AMD XDNA, Intel NPU), NVMe PCIe 3/4/5, WiFi 6/6E/7 e Ethernet 1-100GbE [2].

### 3.8 Kanel-AI Engine: Otimização Preditiva

Um subsistema de otimização preditiva que usa eBPF para coletar métricas com overhead mínimo (< 1%) e um daemon userspace leve para ajustar parâmetros do kernel (CPU governor, KSM, I/O read-ahead, buffers de rede) em tempo real. Espera-se melhorias de até 30% na latência de aplicações e 15% na economia de energia [2].

## 4. Base do Sistema

A Base do Sistema BRX visa reduzir a fragmentação e aumentar a compatibilidade de aplicativos.

### 4.1 Gerenciamento de Pacotes Universal (brx-pkg)

O BRX implementará um gerenciador de pacotes universal (`brx-pkg`) que atua como um wrapper para diferentes formatos e tecnologias [8]:

| Formato | Tecnologia | Uso Principal |
|---|---|---|
| **Nativos** (.deb, .rpm) | `distrobox` | Aplicações de linha de comando, bibliotecas |
| **Universais** (Flatpak) | `flatpak` | Aplicações desktop com sandboxing |
| **Portáteis** (AppImage) | `appimaged` | Aplicações standalone, portabilidade |
| **Containers** (Snap) | `snapd` | Aplicações empacotadas, serviços |

O `brx-pkg` permitirá aos usuários instalar software de diferentes ecossistemas Linux de forma transparente, resolvendo o problema da fragmentação de pacotes.

### 4.2 Gerenciamento de Drivers Avançado (brx-driver-manager)

Para resolver os desafios de drivers no Linux, o BRX incluirá um sistema avançado de drivers [1]:

- **Detecção Automática**: Durante a instalação e o boot, o sistema detectará CPU, GPU, placa de rede, Wi-Fi, Bluetooth e armazenamento.
- **Banco Universal de Drivers**: Um repositório centralizado de drivers open source, proprietários, firmware e microcode. O `brx-driver-manager` gerenciará o download e a instalação automática.
- **Compatibilidade de Drivers**: Mecanismos para garantir que os drivers continuem funcionando após atualizações do kernel, incluindo recompilação automática de módulos (via DKMS), fallback de drivers e rollback de atualizações.

### 4.3 Compatibilidade com Aplicativos Windows (Wine/Proton)

O BRX terá suporte nativo para rodar aplicativos Windows usando camadas de tradução [1]:

- **Proton**: Baseado no Wine, desenvolvido pela Valve para o Steam Deck, traduz chamadas DirectX para Vulkan. O BRX integrará o Proton e o VKD3D-Proton para jogos, permitindo desempenho próximo ao nativo [9].
- **Wine**: Para aplicações Windows não-jogos.

### 4.4 Compatibilidade com Aplicativos Android (Waydroid)

O sistema permitirá rodar aplicativos Android usando **Waydroid** [1]. Isso requer suporte a módulos de kernel específicos (`binder` e `ashmem`), que serão garantidos no BRX Kernel [10].

## 5. Interface Gráfica

O ambiente gráfico padrão do BRX será o **KDE Plasma**, com foco em desempenho, personalização e uma interface moderna [1].

### 5.1 Display Server: Wayland

O BRX priorizará o **Wayland** como display server padrão. O Wayland oferece menor latência, melhor suporte para múltiplos monitores (incluindo HDR e VRR) e maior segurança em comparação com o X11. O KDE Plasma 6.4+ já demonstra que o Wayland supera ou se iguala ao X11 em performance de jogos [11] [12]. O BRX garantirá uma stack Wayland otimizada com os drivers gráficos mais recentes.

### 5.2 API Gráfica: Vulkan

A principal API gráfica será o **Vulkan**, devido ao seu baixo overhead e acesso mais direto à GPU, o que é crucial para jogos de alto desempenho no Linux [13]. O OpenGL continuará sendo suportado para aplicações legadas.

## 6. Otimização de Performance para Jogos

O BRX implementará otimizações avançadas de desempenho para jogos [1]:

### 6.1 Game Runtime Mode (brx-game-mode)

Quando um jogo for executado, o `brx-game-mode` ativará automaticamente as seguintes otimizações:

- **Aumento de Prioridade**: Eleva a prioridade do processo do jogo.
- **Redução de Processos em Segundo Plano**: Suspende ou reduz a prioridade de tarefas não essenciais.
- **Otimização de CPU/GPU**: Ajusta o escalonamento da CPU e os clocks da GPU para maximizar o desempenho.
- **Redução de Latência**: Minimiza a latência do sistema através de ajustes no kernel e no ambiente gráfico.

### 6.2 Shader Cache Global

Para combater o stutter em jogos causado pela compilação de shaders, o BRX incluirá um cache global de shaders com pré-compilação automática e compartilhamento de cache entre jogos [1].

### 6.3 Otimização de GPU

Os drivers de GPU (AMD, NVIDIA, Intel) serão configurados automaticamente para desempenho máximo, com instalação e atualizações simplificadas.

## 7. Suporte a Linguagens de Programação

O BRX facilitará o desenvolvimento de software, oferecendo suporte fácil para uma ampla gama de linguagens, incluindo C, C++, Rust, Python, Java, JavaScript, TypeScript, Go, Swift, Kotlin, Ruby, PHP, Dart, Julia e Haskell. A instalação de toolchains será possível via interface gráfica e terminal [1].

## 8. Roadmap Técnico

| Fase | Período | Componentes | Status |
|---|---|---|---|
| **Fase 1: Fundação (KanelOS v0.1.0)** | Q1 2026 | Kernel 6.12 LTS, BORE, HAL, AI Engine, eBPF, Rust | Concluído |
| **Fase 2: Base do Sistema BRX** | Q2 2026 | brx-pkg (distrobox/flatpak), brx-driver-manager, Waydroid, Wine/Proton | Em Progresso |
| **Fase 3: Otimização de Jogos e UI** | Q3 2026 | brx-game-mode, Shader Cache, KDE Plasma/Wayland otimizado | Planejado |
| **Fase 4: Estabilização e Lançamento** | Q4 2026 | Testes extensivos, instalador gráfico, documentação final | Planejado |

---

## Referências

1.  Requisitos do usuário para o Sistema Operacional BRX. `pasted_file_ikAwQY_BRXKarnel.txt`.
2.  KanelOS Team. `docs/architecture/technical-base.md`.
3.  KanelOS Team. `kernel/patches/0001-kanel-bore-scheduler.patch`.
4.  kernelnewbies.org. [Linux 6.12 Release Notes](https://kernelnewbies.org/Linux_6.12).
5.  kernel.org. [sched_ext Documentation](https://www.kernel.org/doc/html/v6.12/scheduler/sched-ext.html).
6.  kernel.org. [MGLRU Documentation](https://www.kernel.org/doc/html/latest/mm/multigen_lru.html).
7.  KanelOS Team. `kernel/patches/0004-kanel-security-ipe-policy.patch`.
8.  nesbitt.io. [The Package Management Landscape](https://nesbitt.io/2026/01/03/the-package-management-landscape.html).
9.  gamingonlinux.com. [Proton and DXVK](https://www.gamingonlinux.com/articles/proton-and-dxvk-continue-to-improve-linux-gaming.14501).
10. Joshua-Riek. [kernel: ashmem and binder? waydroid #7](https://github.com/Joshua-Riek/ubuntu-rockchip/issues/7).
11. Reddit. [Plasma 6.4 Wayland vs X11 desktop performance numbers](https://www.reddit.com/r/linux/comments/1lt419z/plasma_64_wayland_vs_x11_desktop_performance/).
12. dedoimedo.com. [Plasma 6.4 Wayland vs X11 desktop performance numbers](https://www.dedoimedo.com/computers/plasma-6-4-performance-wayland-x11-comparison.html).
13. Phoronix. [Vulkan vs OpenGL Gaming Performance](https://www.phoronix.com/news/Vulkan-vs-OpenGL-2024).
