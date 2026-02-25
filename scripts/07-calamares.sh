#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 7: Calamares (Instalador Gráfico)
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

# Instalar Calamares
log_info "A instalar Calamares..."

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y calamares calamares-settings-debian os-prober
echo "[INFO] Calamares instalado."
CHROOT_SCRIPT

# Configuração personalizada
log_info "A configurar Calamares com branding Tuga Linux..."

CALA_DIR="${CHROOT_DIR}/etc/calamares"
BRAND_DIR="${CALA_DIR}/branding/tuga"
mkdir -p "${BRAND_DIR}" "${CALA_DIR}/modules"

# settings.conf
cat > "${CALA_DIR}/settings.conf" <<'EOF'
---
modules-search: [ local, /usr/lib/calamares/modules ]
sequence:
  - show:
      - welcome
      - locale
      - keyboard
      - partition
      - users
      - summary
  - exec:
      - partition
      - mount
      - unpackfs
      - machineid
      - fstab
      - locale
      - keyboard
      - localecfg
      - luksbootkeyfile
      - users
      - displaymanager
      - networkcfg
      - hwclock
      - services-systemd
      - bootloader
      - packages
      - removeuser
      - umount
  - show:
      - finished
branding: tuga
prompt-install: true
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
EOF

# Branding
cat > "${BRAND_DIR}/branding.desc" <<'EOF'
---
componentName: tuga
strings:
    productName:         "Tuga Linux"
    shortProductName:    "Tuga"
    version:             "1.0.0"
    shortVersion:        "1.0.0"
    versionedName:       "Tuga Linux 1.0.0"
    shortVersionedName:  "Tuga 1.0.0"
    bootloaderEntryName: "Tuga Linux"
    productUrl:          "https://github.com/tuga-linux"
    supportUrl:          "https://github.com/tuga-linux/issues"
    knownIssuesUrl:      "https://github.com/tuga-linux/issues"
    releaseNotesUrl:     "https://github.com/tuga-linux/releases"
images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "welcome.png"
slideshow:               "show.qml"
style:
    SidebarBackground:    "#1a1a2e"
    SidebarText:          "#FFFFFF"
    SidebarTextSelect:    "#4fc3f7"
    SidebarTextHighlight: "#4fc3f7"
EOF

# Imagens do branding
cp "${BRANDING_DIR}/wallpaper.png" "${BRAND_DIR}/welcome.png"
if [[ -f "${BRANDING_DIR}/logo.png" ]]; then
    cp "${BRANDING_DIR}/logo.png" "${BRAND_DIR}/logo.png"
else
    cp "${BRANDING_DIR}/wallpaper.png" "${BRAND_DIR}/logo.png"
fi

# Slideshow QML
cat > "${BRAND_DIR}/show.qml" <<'QMLEOF'
import QtQuick 2.0;
Presentation {
    id: presentation
    Slide {
        Image {
            id: background
            source: "welcome.png"
            width: 800; height: 440
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background.horizontalCenter
            anchors.top: background.bottom
            anchors.topMargin: 20
            text: "Bem-vindo ao Tuga Linux"
            color: "#FFFFFF"
            font.pixelSize: 22
            font.bold: true
        }
    }
}
QMLEOF

# Módulos de configuração
cat > "${CALA_DIR}/modules/welcome.conf" <<'EOF'
---
showSupportUrl: true
showKnownIssuesUrl: true
showReleaseNotesUrl: true
requirements:
    requiredStorage:    8.0
    requiredRam:        1.0
    internetCheckUrl:   http://deb.debian.org
    check:
        - storage
        - ram
        - root
    required:
        - storage
        - ram
        - root
EOF

cat > "${CALA_DIR}/modules/locale.conf" <<'EOF'
---
region: "Europe"
zone: "Lisbon"
localeGenPath: /etc/locale.gen
EOF

cat > "${CALA_DIR}/modules/keyboard.conf" <<'EOF'
---
xOrgConfFileName: /etc/X11/xorg.conf.d/00-keyboard.conf
convertedKeymapPath: /lib/kbd/keymaps/xkb
writeEtcDefaultKeyboard: true
EOF

cat > "${CALA_DIR}/modules/partition.conf" <<'EOF'
---
efiSystemPartition: /boot/efi
efiSystemPartitionSize: 512M
efiSystemPartitionName: EFI
userSwapChoices:
    - none
    - small
    - file
drawNestedPartitions: false
alwaysShowPartitionLabels: true
defaultFileSystemType: "ext4"
availableFileSystemTypes: ["ext4", "btrfs", "xfs"]
EOF

cat > "${CALA_DIR}/modules/users.conf" <<'EOF'
---
defaultGroups:
    - name: users
      must_exist: true
    - name: sudo
      must_exist: true
    - name: audio
    - name: video
    - name: plugdev
    - name: netdev
    - name: bluetooth
    - name: cdrom
autologinGroup: autologin
doAutologin: false
sudoersGroup: sudo
setRootPassword: true
doReusePassword: true
passwordRequirements:
    minLength: 6
    maxLength: -1
allowWeakPasswords: false
allowWeakPasswordsDefault: false
EOF

cat > "${CALA_DIR}/modules/displaymanager.conf" <<'EOF'
---
displaymanagers:
    - lightdm
basicSetup: false
EOF

cat > "${CALA_DIR}/modules/bootloader.conf" <<'EOF'
---
efiBootLoader: "grub"
kernel: "/vmlinuz"
img: "/initrd.img"
timeout: 10
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
installEFIFallback: true
grubUseLinuxProbe: true
EOF

cat > "${CALA_DIR}/modules/unpackfs.conf" <<'EOF'
---
unpack:
    -   source: "/run/live/medium/live/filesystem.squashfs"
        sourcefs: "squashfs"
        destination: ""
EOF

cat > "${CALA_DIR}/modules/packages.conf" <<'EOF'
---
backend: apt
operations:
    - remove:
        - calamares
        - calamares-settings-debian
        - live-boot
        - live-config
        - live-config-systemd
    - try_remove:
        - os-prober
EOF

cat > "${CALA_DIR}/modules/removeuser.conf" <<'EOF'
---
username: tuga
EOF

cat > "${CALA_DIR}/modules/finished.conf" <<'EOF'
---
restartNowEnabled: true
restartNowChecked: true
restartNowCommand: "systemctl -i reboot"
notifyOnFinished: true
EOF

# Atalho no desktop
DESKTOP_DIR="${CHROOT_DIR}/usr/share/applications"
cat > "${DESKTOP_DIR}/tuga-installer.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar Tuga Linux 1.0.0
Name[en]=Install Tuga Linux 1.0.0
Comment=Instalar o Tuga Linux 1.0.0 no disco
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
EOF

mkdir -p "${CHROOT_DIR}/home/tuga/Desktop"
cp "${DESKTOP_DIR}/tuga-installer.desktop" "${CHROOT_DIR}/home/tuga/Desktop/"
chmod +x "${CHROOT_DIR}/home/tuga/Desktop/tuga-installer.desktop"
chroot "${CHROOT_DIR}" chown -R tuga:tuga /home/tuga/Desktop

# Criar script que garante que o atalho fica "trusted" no primeiro login
# (GNOME/Budgie exigem metadata::trusted para mostrar atalhos no desktop)
cat > "${CHROOT_DIR}/usr/local/bin/tuga-desktop-shortcut.sh" <<'SHORTCUT_SCRIPT'
#!/bin/bash
###############################################################################
# Tuga Linux — Garantir atalho de instalação no Desktop
# Executado via autostart no primeiro login.
###############################################################################

DESKTOP_FILE="/home/tuga/Desktop/tuga-installer.desktop"
FLAG_FILE="$HOME/.config/tuga-shortcut-configured"

# Se já foi configurado, sair
[[ -f "$FLAG_FILE" ]] && exit 0

# Esperar que o desktop carregue
sleep 2

# Garantir que o ficheiro existe
if [[ ! -f "$DESKTOP_FILE" ]]; then
    cp /usr/share/applications/tuga-installer.desktop "$DESKTOP_FILE" 2>/dev/null || exit 0
    chmod +x "$DESKTOP_FILE"
fi

# Marcar como trusted (permite execução sem perguntar)
gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true

# Tornar executável (redundante mas seguro)
chmod +x "$DESKTOP_FILE"

# Marcar como configurado
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

exit 0
SHORTCUT_SCRIPT

chmod +x "${CHROOT_DIR}/usr/local/bin/tuga-desktop-shortcut.sh"

# Autostart
mkdir -p "${CHROOT_DIR}/etc/xdg/autostart"
cat > "${CHROOT_DIR}/etc/xdg/autostart/tuga-desktop-shortcut.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Tuga Desktop Shortcut Setup
Comment=Configura o atalho de instalação no desktop
Exec=/usr/local/bin/tuga-desktop-shortcut.sh
Terminal=false
NoDisplay=true
X-GNOME-Autostart-Phase=Applications
EOF

# Remover ficheiros .desktop do Debian que o calamares-settings-debian instala
log_info "A remover branding Debian do Calamares..."
rm -f "${CHROOT_DIR}/usr/share/applications/install-debian.desktop"
rm -f "${CHROOT_DIR}/usr/share/applications/calamares-install-debian.desktop"
# Remover branding Debian do Calamares (se existir)
rm -rf "${CHROOT_DIR}/etc/calamares/branding/debian"

log_info "Calamares instalado e configurado com sucesso."

