# DragonBRX OS — Guia de Instalação e Estrutura da ISO

**Versão do Documento:** 0.1.0  
**Data:** Março de 2026  
**Autor:** Manus AI

---

## 1. Introdução ao DragonBRX OS

O **DragonBRX OS** é uma distribuição Linux de nova geração, projetada para oferecer desempenho extremo, compatibilidade universal de hardware e software, e uma experiência de usuário otimizada para jogos e desenvolvimento. Sua filosofia de instalação foca na simplicidade e na eficiência, utilizando um modelo de "netinstaller" que constrói o sistema em tempo real a partir de um repositório centralizado [1].

Este guia detalha a estrutura da ISO de instalação, o fluxo de usuário e os componentes técnicos que tornam a instalação do DragonBRX OS uma experiência moderna e robusta.

## 2. Estrutura da ISO de Instalação

A ISO do DragonBRX OS é construída para ser leve e modular, contendo apenas o essencial para iniciar o processo de instalação. Ela atua como um ambiente "Live" que permite ao usuário experimentar o sistema antes de instalar e, crucialmente, serve como plataforma para o **Apex Installer** [2].

| Componente da ISO | Descrição | Função Principal |
|---|---|---|
| **Live Environment** | Um sistema operacional mínimo e temporário que é carregado na memória RAM. | Fornece um ambiente funcional para executar o instalador e ferramentas de recuperação. |
| **Desktop Live (KDE Plasma)** | Uma sessão gráfica completa do KDE Plasma, pré-configurada para o instalador. | Oferece uma interface gráfica amigável para o usuário interagir com o **Apex Installer**. |
| **Apex Core (Mínimo)** | O conjunto mínimo de binários e bibliotecas essenciais para o sistema base. | Garante que o instalador tenha as ferramentas básicas de rede, disco e sistema para iniciar o processo de download e construção. |
| **Apex Installer (Calamares)** | O framework de instalação gráfico, altamente configurável. | Guia o usuário através das etapas de instalação, desde a conexão de rede até o particionamento e a criação de usuários. |
| **`apex-install.sh`** | O script principal de instalação, executado pelo Calamares. | Orquestra o download do repositório, a compilação do kernel, a instalação dos pacotes e a configuração final do sistema. |

## 3. Fluxo de Instalação (Experiência do Usuário)

O processo de instalação do DragonBRX OS é projetado para ser intuitivo e direto, mesmo para usuários menos experientes. O fluxo de usuário é o seguinte:

1.  **Boot da ISO:** O usuário inicia o computador a partir da ISO do DragonBRX OS (USB ou DVD).
2.  **Ambiente Live:** O sistema carrega um ambiente Live com o KDE Plasma, onde o **Apex Installer** é iniciado automaticamente.
3.  **Boas-vindas:** O instalador apresenta uma tela de boas-vindas e permite a seleção do idioma.
4.  **Conexão de Rede:** O instalador detecta e solicita a conexão a uma rede Wi-Fi ou Ethernet. Esta etapa é crucial, pois o sistema será baixado do repositório online [1].
5.  **Localização:** Configuração de fuso horário e layout de teclado.
6.  **Particionamento de Disco:** O usuário escolhe como o disco será utilizado:
    *   **Apagar Disco:** Instalação completa, utilizando todo o disco.
    *   **Dual Boot:** Instalação ao lado de um sistema operacional existente (ex: Windows), redimensionando partições automaticamente.
    *   **Particionamento Manual:** Opção avançada para criar e configurar partições manualmente. O sistema de arquivos padrão sugerido é Btrfs para aproveitar recursos como snapshots [2].
7.  **Criação de Usuário:** O usuário define seu nome, nome de usuário, senha e nome do computador.
8.  **Resumo:** O instalador exibe um resumo das configurações selecionadas para confirmação final.
9.  **Instalação:** O processo de instalação é iniciado. Nesta fase, o `apex-install.sh` é executado, clonando o repositório `dragonbrxos/BRX`, compilando o kernel, instalando o Apex Core, o KDE Plasma e as ferramentas padrão.
10. **Finalização:** Após a conclusão, o usuário é solicitado a reiniciar o sistema para entrar no DragonBRX OS recém-instalado.

## 4. Apex Installer (Integração Calamares)

O **Apex Installer** é uma instância customizada do **Calamares**, um framework de instalação independente de distribuição [3]. A customização inclui:

-   **Módulos Calamares:** Configuração de módulos específicos para as etapas de boas-vindas, rede, localização, particionamento e criação de usuário.
-   **Módulo `shellprocess`:** Este módulo é a chave para a instalação dinâmica. Ele executa o script `apex-install.sh` em um ambiente chroot no disco de destino. Isso permite que o sistema seja construído de forma flexível, baixando os componentes mais recentes do repositório GitHub durante a instalação [2].

## 5. Apex Core: A Base do Sistema

O **Apex Core** é a base mínima do DragonBRX OS, instalada e configurada pelo `apex-install.sh`. Ele inclui:

-   **BRX Kernel:** O kernel Linux 6.12 LTS otimizado, compilado com os patches e configurações do DragonBRX OS.
-   **Systemd:** O init system padrão.
-   **NetworkManager:** Para gerenciamento de conexões de rede, incluindo Wi-Fi (com `iwd` ou `wpa_supplicant`).
-   **Ferramentas de Disco:** `parted`, `fdisk`, `e2fsprogs`, `btrfs-progs`.
-   **Utilitários Essenciais:** GNU Coreutils, Bash, Git, Curl, Wget.
-   **Bootloader:** GRUB (configurado para suporte a Dual Boot).

## 6. Ferramentas Padrão (Pós-Instalação)

Após a instalação, o DragonBRX OS virá pré-configurado com um conjunto de ferramentas essenciais para uma experiência de usuário completa e produtiva:

-   **Navegador Web:** Mozilla Firefox (com otimizações de performance e privacidade).
-   **Terminal:** Konsole (terminal padrão do KDE Plasma).
-   **Gerenciador de Arquivos:** Dolphin (gerenciador de arquivos do KDE Plasma).
-   **Loja de Aplicativos:** KDE Discover (integrado com `brx-pkg` para acesso a Flatpaks, Snaps e pacotes nativos).
-   **Gerenciador de Drivers:** `brx-driver-manager` (para detecção e instalação automática de drivers).
-   **Ferramentas de Desenvolvimento:** Git, compiladores (GCC, Clang), Python.

## 7. Detalhes Técnicos da Construção da ISO

A ISO será construída utilizando **Archiso**, que oferece a flexibilidade necessária para criar um ambiente Live customizado com o KDE Plasma e o Calamares. O processo envolverá:

-   **`packages.x86_64`:** Definição dos pacotes a serem incluídos no ambiente Live e no sistema base.
-   **`airootfs/`:** Estrutura de diretórios para arquivos customizados, como o script `apex-install.sh` e as configurações iniciais do Calamares.
-   **Autostart do KDE Plasma:** Configuração para iniciar o Calamares automaticamente após o boot do ambiente Live.

---

## Referências

1.  Requisitos do usuário para o Sistema Operacional DragonBRX OS. `pasted_file_ikAwQY_BRXKarnel.txt`.
2.  Pesquisa Tecnológica: ISO DragonBRX OS. `dragonbrx_iso_research.md`.
3.  Calamares Installer Framework. [GitHub Repository](https://github.com/calamares/calamares).
