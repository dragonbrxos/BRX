#!/bin/bash
# =============================================================================
# DragonBRX OS — Terminal Optimization Script (Konsole)
# =============================================================================
# Configura o terminal Konsole com o tema e fontes do DragonBRX OS.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-KONSOLE]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}          $*"; }

log "Configurando terminal Konsole com o tema DragonBRX OS..."

# 1. Criar diretórios de configuração
mkdir -p /etc/skel/.local/share/konsole
mkdir -p /etc/skel/.config

# 2. Definir perfil DragonBRX
cat << EOF > /etc/skel/.local/share/konsole/DragonBRX.profile
[Appearance]
ColorScheme=BreezeDark
Font=Hack,12,-1,5,50,0,0,0,0,0

[General]
Name=DragonBRX
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
HistorySize=10000
EOF

# 3. Definir perfil padrão no konsolerc
cat << EOF > /etc/skel/.config/konsolerc
[Desktop Entry]
DefaultProfile=DragonBRX.profile

[MainWindow]
Height=720
Width=1280
EOF

# 4. Configurações do Bash (Prompt Colorido)
cat << 'EOF' >> /etc/skel/.bashrc
# DragonBRX OS Custom Bash Prompt
export PS1="\[\033[01;34m\][BRX]\[\033[00m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias update='sudo /opt/dragonbrx/scripts/pkg/brx-pkg.sh update'
alias install='/opt/dragonbrx/scripts/pkg/brx-pkg.sh install'
EOF

ok "Terminal Konsole configurado com sucesso."
