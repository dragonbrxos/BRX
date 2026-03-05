# Guia de Contribuição — KanelOS

Obrigado por considerar contribuir com o KanelOS! Este documento descreve o processo para contribuir com patches, documentação e código.

---

## Código de Conduta

Este projeto adere ao [Contributor Covenant](https://www.contributor-covenant.org/). Ao participar, você concorda em manter um ambiente respeitoso e colaborativo.

---

## Como Contribuir

### Reportar Bugs

Antes de reportar um bug, verifique se ele já foi reportado nas [Issues](https://github.com/dragonbrxos/BRX/issues). Ao criar uma nova issue, inclua:

- Versão do KanelOS e perfil de kernel usado
- Hardware afetado (CPU, GPU, etc.)
- Passos para reproduzir o problema
- Saída de `dmesg`, `journalctl` ou logs relevantes
- Resultado esperado vs. resultado obtido

### Propor Melhorias

Para propor novas funcionalidades ou melhorias, abra uma issue descrevendo:

- O problema que a melhoria resolve
- A solução proposta com justificativa técnica
- Impacto em performance, compatibilidade e segurança
- Referências a benchmarks ou documentação relevante

### Enviar Patches

O KanelOS segue o estilo de patches do kernel Linux. Todo patch deve:

**1. Ter um commit message bem formatado:**

```
subsistema: Descrição curta em inglês (máx. 72 chars)

Descrição mais detalhada explicando o que muda e por quê.
Inclua referências a benchmarks, documentação ou issues.

Signed-off-by: Seu Nome <seu@email.com>
```

**2. Seguir o estilo de código do kernel Linux:**

```bash
# Verificar estilo antes de submeter
./scripts/checkpatch.pl --strict seu-patch.patch
```

**3. Incluir testes quando aplicável:**

```bash
# Executar testes existentes
make test

# Adicionar benchmark se o patch afeta performance
make benchmark
```

**4. Ser baseado no branch `develop`:**

```bash
git clone https://github.com/dragonbrxos/BRX.git
cd BRX
git checkout develop
git checkout -b feature/minha-melhoria

# Fazer alterações
git add .
git commit -m "sched/bore: Melhoria no cálculo de burst penalty"
git push origin feature/minha-melhoria
```

---

## Áreas de Contribuição

### Patches de Kernel

Os patches ficam em `kernel/patches/` e devem ser numerados sequencialmente:

```
0001-kanel-bore-scheduler.patch
0002-kanel-network-optimizations.patch
0003-kanel-hal-universal.patch
...
```

Cada patch deve ser aplicável ao kernel Linux 6.12 LTS sem conflitos.

### Configurações de Kernel

As configurações ficam em `kernel/configs/` e devem ser testadas nos perfis correspondentes. Ao adicionar ou modificar opções, documente a justificativa técnica no comentário acima da opção.

### HAL (Hardware Abstraction Layer)

Contribuições de suporte a novo hardware são bem-vindas. Para adicionar suporte a um novo dispositivo:

1. Adicionar o ID PCI/USB na tabela correspondente em `hal/src/`
2. Implementar a detecção e configuração em `kanel-hal-core.c`
3. Adicionar regra udev em `udev/rules.d/99-kanelos-hal.rules`
4. Documentar na matriz de compatibilidade em `docs/architecture/technical-base.md`

### eBPF e Scheduler

Contribuições ao scheduler `scx_kanel` devem:

- Ser testadas com `make benchmark` antes de submeter
- Incluir comparativo de latência e throughput
- Não degradar performance em nenhum dos perfis existentes

### Documentação

A documentação é tão importante quanto o código. Contribuições de:

- Guias de instalação para hardware específico
- Tutoriais de configuração
- Traduções (o projeto aceita PT-BR e EN)
- Correções de erros técnicos

---

## Processo de Review

Todo pull request passa por:

1. **CI automático**: compilação, lint e testes básicos
2. **Review técnico**: análise do código por mantenedores
3. **Teste de hardware**: quando aplicável, teste em hardware real
4. **Merge**: após aprovação de pelo menos um mantenedor

O processo pode levar de alguns dias a algumas semanas dependendo da complexidade.

---

## Ambiente de Desenvolvimento

```bash
# Configurar ambiente de desenvolvimento
sudo ./scripts/install/build-deps.sh

# Compilar kernel de desenvolvimento (sem ISO)
make kernel PROFILE=desktop

# Testar em QEMU (sem hardware real)
make test-qemu PROFILE=desktop

# Executar benchmarks
make benchmark
```

---

## Contato

- **Issues**: [github.com/dragonbrxos/BRX/issues](https://github.com/dragonbrxos/BRX/issues)
- **Discussões**: [github.com/dragonbrxos/BRX/discussions](https://github.com/dragonbrxos/BRX/discussions)
