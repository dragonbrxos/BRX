# Changelog — KanelOS

Todas as mudanças notáveis neste projeto serão documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).

---

## [Não Lançado] — Em Desenvolvimento

### Adicionado

- Estrutura completa do projeto KanelOS
- Base no kernel Linux 6.12 LTS (suporte até Dez/2028)
- Patch BORE (Burst-Oriented Response Enhancer) sobre EEVDF
- Scheduler BPF `scx_kanel` usando sched_ext (Linux 6.12)
- HAL Universal (Hardware Abstraction Layer) para x86_64, ARM64, RISC-V
- Configurações de kernel para 4 perfis: desktop, server, rt, laptop
- Kanel-AI Engine: daemon de otimização preditiva via eBPF
- Regras udev para detecção automática de hardware
- Configurações sysctl otimizadas baseadas em benchmarks reais
- Scripts de build e instalação de dependências
- Documentação técnica completa com dados reais
- Suporte a NPUs: AMD XDNA (Ryzen AI) e Intel NPU (Meteor Lake+)
- Integração com io_uring IOPOLL para NVMe PCIe 4.0/5.0
- TCP BBR v3 como padrão de controle de congestionamento
- Suporte a PREEMPT_RT (mainline desde Linux 6.12)
- Drivers em Rust (aproveitando suporte nativo do Linux 6.12)
- Programa eBPF XDP para processamento de rede de alta performance

### Técnico

- Kernel base: Linux 6.12.22 LTS
- Scheduler: EEVDF + BORE + sched_ext
- Preempção: PREEMPT (desktop), PREEMPT_RT (rt), PREEMPT_NONE (server)
- I/O: io_uring com IOPOLL, zero-copy, buffer registration
- Memória: MGLRU, KSM, Zswap/Zstd, THP (madvise)
- Rede: BBR v3, XDP, nftables, fq_codel/CAKE
- Segurança: IPE, BPF LSM, AppArmor, KASLR, CFI, Shadow Stack
- Compilação: GCC 13+ / Clang 17+ com suporte a LLVM

---

## Versões Planejadas

### [0.2.0] — Q2 2026

- HAL completo com detecção automática de todos os componentes
- scx_kanel scheduler estável e testado
- Kanel-AI Engine com modelos de predição refinados
- Suporte completo a ARM64 (Qualcomm Snapdragon X Elite)
- ISO bootável para testes

### [0.3.0] — Q3 2026

- Integração completa do Kanel-AI Engine
- eBPF scheduler com suporte a cgroups v2
- Políticas IPE para boot seguro
- Suporte experimental a RISC-V (StarFive VisionFive 2)

### [0.4.0] — Q4 2026

- Hardening de segurança completo
- Auditoria de código
- Testes de performance automatizados
- Documentação completa

### [1.0.0] — Q2 2027

- Primeira versão estável pública
- ISO para desktop e servidor
- Suporte de longo prazo
