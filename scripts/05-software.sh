#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 5: Software Adicional
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_root

if [[ ! -d "$CHROOT_DIR" ]]; then
    log_error "Directório chroot não encontrado: ${CHROOT_DIR}"
    exit 1
fi

mount_chroot
trap umount_chroot EXIT

log_info "A instalar software adicional..."

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'

export DEBIAN_FRONTEND=noninteractive

apt-get update

# --- Firefox ESR ---
apt-get install -y firefox-esr firefox-esr-l10n-pt-pt
echo "[INFO] Firefox ESR instalado."

# --- Google Chrome ---
apt-get install -y wget gnupg2 ca-certificates
wget -q -O /tmp/google-chrome.deb \
    "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" || true
if [[ -f /tmp/google-chrome.deb ]]; then
    apt-get install -y /tmp/google-chrome.deb || apt-get install -fy
    rm -f /tmp/google-chrome.deb
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list
    echo "[INFO] Google Chrome instalado."
else
    echo "[AVISO] Não foi possível descarregar o Google Chrome."
fi

# --- Produtividade ---
apt-get install -y libreoffice libreoffice-l10n-pt libreoffice-gtk3
apt-get install -y gnome-terminal gnome-calculator
echo "[INFO] LibreOffice e utilitários instalados."

# --- Sistema ---
apt-get install -y gufw timeshift deja-dup
echo "[INFO] Gufw, Timeshift, Déjà Dup instalados."

# --- Multimédia ---
apt-get install -y darktable nemo vlc eog
apt-get install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly \
    gstreamer1.0-plugins-bad gstreamer1.0-libav
echo "[INFO] Multimédia instalada."

# --- Utilitários ---
apt-get install -y gedit file-roller gnome-screenshot gnome-system-monitor \
    gnome-disk-utility evince baobab seahorse
echo "[INFO] Utilitários instalados."

# --- Ferramentas de sistema ---
apt-get install -y gparted htop fastfetch curl wget git unzip 7zip \
    usbutils pciutils lshw inxi
echo "[INFO] Ferramentas de sistema instaladas."

# --- Fontes ---
apt-get install -y fonts-noto fonts-noto-color-emoji fonts-firacode \
    fonts-crosextra-carlito fonts-crosextra-caladea
echo "[INFO] Fontes instaladas."

# --- IA: Ollama ---
curl -fsSL https://ollama.com/install.sh | sh || {
    echo "[AVISO] Não foi possível instalar o Ollama."
}
echo "[INFO] Ollama instalado."

# --- Python3 + IA ---
apt-get install -y python3 python3-pip python3-venv python3-numpy
echo "[INFO] Python3 instalado."

# --- Firewall ---
ufw default deny incoming
ufw default allow outgoing
ufw enable || true
echo "[INFO] Firewall UFW ativado."

CHROOT_SCRIPT

log_info "Todo o software adicional foi instalado com sucesso."
