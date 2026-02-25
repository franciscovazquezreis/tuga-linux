#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 4: Desktop Environment
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

log_info "A instalar Budgie Desktop e componentes gráficos..."

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Xorg
apt-get install -y xorg xserver-xorg xserver-xorg-input-all xserver-xorg-video-all
echo "[INFO] Xorg instalado."

# Budgie Desktop
apt-get install -y budgie-desktop budgie-indicator-applet
echo "[INFO] Budgie Desktop instalado."

# LightDM
apt-get install -y lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
echo "[INFO] LightDM instalado."

# PipeWire
apt-get install -y pipewire pipewire-pulse pipewire-alsa wireplumber gstreamer1.0-pipewire pavucontrol
echo "[INFO] PipeWire instalado."

# Rede
apt-get install -y network-manager network-manager-gnome
echo "[INFO] NetworkManager instalado."

# Bluetooth
apt-get install -y bluez blueman
echo "[INFO] Bluetooth instalado."

# Impressão
apt-get install -y cups system-config-printer
echo "[INFO] CUPS instalado."

# Auto-login na sessão live
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-tuga-autologin.conf <<EOF
[Seat:*]
autologin-user=tuga
autologin-session=budgie-desktop
user-session=budgie-desktop
greeter-session=lightdm-gtk-greeter
EOF
echo "[INFO] Auto-login configurado."

# Ativar serviços
systemctl enable lightdm.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable bluetooth.service 2>/dev/null || true
systemctl enable cups.service 2>/dev/null || true
echo "[INFO] Serviços ativados."

CHROOT_SCRIPT

log_info "Budgie Desktop instalado com sucesso."
