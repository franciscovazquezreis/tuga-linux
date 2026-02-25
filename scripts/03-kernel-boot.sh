#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 3: Kernel e Bootloader
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

log_info "A instalar kernel, GRUB EFI e pacotes live..."

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Kernel Linux
apt-get install -y linux-image-amd64 initramfs-tools
echo "[INFO] Kernel Linux instalado."

# GRUB — módulos BIOS + UEFI (sem meta-packages que forçam um modo)
apt-get install -y \
    grub-common \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    efibootmgr
echo "[INFO] GRUB BIOS + UEFI módulos instalados."

# Pacotes para sessão live
apt-get install -y live-boot live-config live-config-systemd live-tools
echo "[INFO] Pacotes live-boot instalados."

# Garantir que os módulos necessários para o Live Boot estão no initramfs
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules

# Firmware
apt-get install -y \
    firmware-linux-free \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    firmware-iwlwifi \
    firmware-realtek \
    firmware-atheros \
    || echo "[AVISO] Alguns pacotes de firmware podem não estar disponíveis."

echo "[INFO] Firmware instalado."

CHROOT_SCRIPT

log_info "Kernel, GRUB EFI e pacotes live instalados com sucesso."
