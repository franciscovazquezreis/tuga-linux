#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 2: Configuração do Chroot
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_root

if [[ ! -d "$CHROOT_DIR" ]]; then
    log_error "Directório chroot não encontrado: ${CHROOT_DIR}"
    log_error "Executa primeiro o script 01-bootstrap.sh"
    exit 1
fi

# Montar e configurar trap de limpeza
mount_chroot
trap umount_chroot EXIT

# Copiar resolv.conf para acesso à rede
log_info "A configurar DNS no chroot..."
cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

# Copiar sources.list
log_info "A configurar repositórios APT..."
cp "${CONFIG_DIR}/apt/sources.list" "${CHROOT_DIR}/etc/apt/sources.list"

# Executar configuração dentro do chroot
log_info "A entrar no chroot para configuração..."

chroot "${CHROOT_DIR}" /bin/bash -e <<CHROOT_SCRIPT

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

# --- Hostname ---
echo "${HOSTNAME_DISTRO}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME_DISTRO}
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
echo "[INFO] Hostname configurado: ${HOSTNAME_DISTRO}"

# --- Locale ---
apt-get update
apt-get install -y locales
sed -i 's/# pt_PT.UTF-8 UTF-8/pt_PT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=pt_PT.UTF-8 LC_ALL=pt_PT.UTF-8
echo "[INFO] Locale configurado: pt_PT.UTF-8"

# --- Timezone ---
ln -sf /usr/share/zoneinfo/Europe/Lisbon /etc/localtime
echo "Europe/Lisbon" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo "[INFO] Timezone configurado: Europe/Lisbon"

# --- Teclado ---
apt-get install -y console-setup keyboard-configuration
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="pt"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
echo "[INFO] Teclado configurado: layout português"

# --- Utilizador live ---
if ! id "${LIVE_USER}" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,cdrom -c "Tuga Linux" ${LIVE_USER}
    echo "${LIVE_USER}:${LIVE_PASS}" | chpasswd
    echo "[INFO] Utilizador '${LIVE_USER}' criado com password '${LIVE_PASS}'"
fi
echo "${LIVE_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${LIVE_USER}
chmod 0440 /etc/sudoers.d/${LIVE_USER}
echo "[INFO] Sudo sem password configurado"

# --- Password de root ---
echo "root:${LIVE_PASS}" | chpasswd
echo "[INFO] Password de root definida"

CHROOT_SCRIPT

log_info "Configuração do chroot concluída com sucesso."
