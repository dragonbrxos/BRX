#!/bin/bash
# =============================================================================
# DragonBRX OS — Firefox Optimization Script
# =============================================================================
# Configura o Firefox com otimizações de performance e privacidade para o BRX.
# =============================================================================

set -e

# Cores para output
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

log() { echo -e "${BLUE}[BRX-FIREFOX]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}          $*"; }

log "Configurando Firefox com otimizações DragonBRX OS..."

# 1. Criar diretório de políticas
mkdir -p /etc/firefox/policies

# 2. Definir políticas padrão (página inicial, extensões, etc.)
cat << EOF > /etc/firefox/policies/policies.json
{
  "policies": {
    "Homepage": {
      "URL": "https://github.com/dragonbrxos/BRX",
      "Locked": false,
      "StartPage": "homepage"
    },
    "DisplayBookmarksToolbar": "always",
    "NoDefaultBrowserCheck": true,
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "OverrideFirstRunPage": "",
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      }
    }
  }
}
EOF

# 3. Otimizações de performance (user.js)
mkdir -p /etc/skel/.mozilla/firefox/brx-profile
cat << EOF > /etc/skel/.mozilla/firefox/brx-profile/user.js
// DragonBRX OS Firefox Performance Optimizations
user_pref("gfx.webrender.all", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.navigator.mediadatadecoder_vpx_enabled", true);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("layout.css.devPixelsPerPx", "-1.0");
user_pref("browser.tabs.firefox-view", false);
EOF

ok "Firefox configurado com sucesso."
