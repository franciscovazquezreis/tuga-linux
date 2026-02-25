#!/bin/bash
###############################################################################
# Tuga Linux — Configuração Central
# Variáveis partilhadas por todos os scripts de build.
###############################################################################

# Directório do projecto (onde estão os scripts e configs)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Directório de trabalho para build (SEM ESPAÇOS — obrigatório para debootstrap)
WORK_DIR="/tmp/tuga-build"

# Caminhos derivados
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso_root"
CONFIG_DIR="${PROJECT_DIR}/config"
BRANDING_DIR="${PROJECT_DIR}/branding"
OUTPUT_ISO="${PROJECT_DIR}/tuga-linux.1.0.0-amd64.iso"

# Parâmetros do sistema
ARCH="amd64"
SUITE="trixie"
MIRROR="http://deb.debian.org/debian"
HOSTNAME_DISTRO="tuga-linux"
LIVE_USER="tuga"
LIVE_PASS="tuga"

# Cores para logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Funções de logging
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC}  $1" >&2; }
log_step()  { echo -e "${CYAN}[FASE]${NC}  $1"; }

# Verificação de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root (sudo)."
        exit 1
    fi
}

# Montar filesystems virtuais no chroot
mount_chroot() {
    mount --bind /dev     "${CHROOT_DIR}/dev"     2>/dev/null || true
    mount --bind /dev/pts "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
    mount -t proc proc    "${CHROOT_DIR}/proc"    2>/dev/null || true
    mount -t sysfs sys    "${CHROOT_DIR}/sys"     2>/dev/null || true
}

# Desmontar filesystems virtuais
umount_chroot() {
    umount -lf "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${CHROOT_DIR}/dev"     2>/dev/null || true
    umount -lf "${CHROOT_DIR}/proc"    2>/dev/null || true
    umount -lf "${CHROOT_DIR}/sys"     2>/dev/null || true
}
