#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 0: Preparação do Host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_root

log_info "A instalar dependências do host para build do Tuga Linux..."

apt-get update

PACOTES_HOST=(
    debootstrap
    debian-archive-keyring
    squashfs-tools
    xorriso
    grub-efi-amd64-bin
    grub-pc-bin
    grub-common
    isolinux
    syslinux-common
    mtools
    dosfstools
    rsync
    git
)

apt-get install -y "${PACOTES_HOST[@]}"

log_info "Todas as dependências do host foram instaladas com sucesso."
