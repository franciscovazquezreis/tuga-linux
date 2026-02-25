#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 1: Bootstrap
# Cria o sistema base (Trixie) via debootstrap.
# Usa /tmp/tuga-build/chroot (sem espaços) para evitar bugs do debootstrap.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_root

# Criar directório de trabalho
mkdir -p "${WORK_DIR}"

if [[ -d "$CHROOT_DIR" ]]; then
    log_warn "Directório chroot já existe: ${CHROOT_DIR}"
    log_warn "A desmontar e remover chroot anterior..."
    umount_chroot
    rm -rf "$CHROOT_DIR"
fi

log_info "A iniciar debootstrap..."
log_info "  Arquitectura: ${ARCH}"
log_info "  Suite:        ${SUITE}"
log_info "  Mirror:       ${MIRROR}"
log_info "  Trabalho:     ${CHROOT_DIR}"

# Verificar keyring
KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
if [[ ! -f "$KEYRING" ]]; then
    log_warn "Keyring Debian não encontrada. A tentar instalar..."
    apt-get install -y debian-archive-keyring
fi

KEYRING_OPT=""
if [[ -f "$KEYRING" ]]; then
    KEYRING_OPT="--keyring=${KEYRING}"
fi

debootstrap \
    --arch="${ARCH}" \
    ${KEYRING_OPT} \
    --include=apt,apt-utils,locales,sudo,systemd,systemd-sysv,dbus \
    "${SUITE}" \
    "${CHROOT_DIR}" \
    "${MIRROR}"

log_info "Bootstrap concluído com sucesso."
log_info "Sistema base Tuga Linux (${SUITE}) criado em: ${CHROOT_DIR}"
