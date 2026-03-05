#!/bin/bash
# =============================================================================
# DragonBRX OS — Network Setup Automator
# =============================================================================
# Detecta interfaces de rede e auxilia na conexão Wi-Fi durante a instalação.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-NET]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}      $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}    $*"; }

log "Iniciando detecção de interfaces de rede..."

# 1. Listar interfaces
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')
log "Interfaces encontradas: ${INTERFACES}"

# 2. Verificar conexão Ethernet
for IFACE in ${INTERFACES}; do
    if [[ $IFACE == e* ]]; then
        if ip addr show $IFACE | grep -q "inet "; then
            ok "Conexão Ethernet detectada em ${IFACE}."
            exit 0
        fi
    fi
done

# 3. Configurar Wi-Fi (se necessário)
WIFI_IFACE=$(ip -o link show | grep -oE "wlan[0-9]|wlp[0-9]s[0-9]" | head -1)

if [ -n "$WIFI_IFACE" ]; then
    warn "Nenhuma conexão Ethernet ativa. Wi-Fi detectado em ${WIFI_IFACE}."
    log "Iniciando assistente de Wi-Fi..."
    
    # Verificar se o NetworkManager está rodando
    if systemctl is-active --quiet NetworkManager; then
        log "Escaneando redes Wi-Fi disponíveis..."
        nmcli dev wifi list
        
        echo -e "${YELLOW}Digite o SSID da rede:${NC} "
        read SSID
        echo -e "${YELLOW}Digite a senha (deixe em branco para rede aberta):${NC} "
        read -s PASSWORD
        
        if [ -z "$PASSWORD" ]; then
            nmcli dev wifi connect "$SSID"
        else
            nmcli dev wifi connect "$SSID" password "$PASSWORD"
        fi
        
        if [ $? -eq 0 ]; then
            ok "Conectado com sucesso a ${SSID}."
            exit 0
        else
            err "Falha ao conectar a ${SSID}."
            exit 1
        fi
    else
        err "NetworkManager não está rodando. Não foi possível configurar o Wi-Fi."
        exit 1
    fi
else
    err "Nenhuma interface de rede funcional detectada. A instalação requer internet."
    exit 1
fi
