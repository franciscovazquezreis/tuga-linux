#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 6: Theming e Polish
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

# ═════════════════════════════════════════════════════════════════════════════
# 1. Instalar pacotes de tema
# ═════════════════════════════════════════════════════════════════════════════
log_info "A instalar pacotes de tema..."

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y arc-theme papirus-icon-theme breeze-cursor-theme gnome-tweaks dconf-cli
echo "[INFO] Pacotes de tema instalados."
CHROOT_SCRIPT

# ═════════════════════════════════════════════════════════════════════════════
# 2. Copiar wallpaper
# ═════════════════════════════════════════════════════════════════════════════
log_info "A copiar wallpaper..."
mkdir -p "${CHROOT_DIR}/usr/share/backgrounds/tuga-linux"
cp "${BRANDING_DIR}/wallpaper.png" "${CHROOT_DIR}/usr/share/backgrounds/tuga-linux/wallpaper.png"

# ═════════════════════════════════════════════════════════════════════════════
# 3. dconf system-db — GTK, fonts, wallpaper
#    NOTA: Aqui colocamos APENAS definições GNOME/GTK.
#    As definições do Budgie (painel, menu) vão no GSchema override (secção 4).
# ═════════════════════════════════════════════════════════════════════════════
log_info "A configurar tema padrão via dconf..."

mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
mkdir -p "${CHROOT_DIR}/etc/dconf/db/tuga.d"

cat > "${CHROOT_DIR}/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:tuga
EOF

cat > "${CHROOT_DIR}/etc/dconf/db/tuga.d/00-tuga-defaults" <<'EOF'
[org/gnome/desktop/interface]
gtk-theme='Arc-Darker'
icon-theme='Papirus'
cursor-theme='Breeze_Snow'
font-name='Noto Sans 10'
monospace-font-name='Fira Code 11'
document-font-name='Noto Sans 10'
color-scheme='prefer-dark'
enable-animations=true
clock-show-weekday=true

[org/gnome/desktop/wm/preferences]
titlebar-font='Noto Sans Bold 11'
button-layout='appmenu:minimize,maximize,close'
theme='Arc-Darker'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/tuga-linux/wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/tuga-linux/wallpaper.png'
picture-options='zoom'
primary-color='#1a1a2e'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/tuga-linux/wallpaper.png'
lock-enabled=true

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true

[org/gnome/settings-daemon/plugins/color]
night-light-enabled=true
night-light-schedule-automatic=true

[org/nemo/preferences]
show-hidden-files=false
default-folder-viewer='icon-view'

[org/nemo/desktop]
show-desktop-icons=true
EOF

chroot "${CHROOT_DIR}" dconf update
log_info "dconf compilado."

# ═════════════════════════════════════════════════════════════════════════════
# 4. Budgie Panel — Forçar painel no TOPO via autostart
#    O Budgie ignora dconf system-db para panel layouts.
#    Solução: script autostart que aplica a config no primeiro login.
# ═════════════════════════════════════════════════════════════════════════════
log_info "A configurar painel Tuga Linux via autostart..."

mkdir -p "${CHROOT_DIR}/usr/local/bin"
cat > "${CHROOT_DIR}/usr/local/bin/tuga-panel-setup.sh" <<'PANELSCRIPT'
#!/bin/bash
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

FLAG_FILE="$HOME/.config/tuga-panel-configured"
if [[ -f "$FLAG_FILE" ]]; then exit 0; fi

sleep 5
nohup budgie-panel --reset --replace &>/dev/null &
sleep 3

dconf write /com/solus-project/budgie-panel/builtin-theme true
dconf write /com/solus-project/budgie-panel/dark-theme true

PANEL_UUID=$(dconf list /com/solus-project/budgie-panel/panels/ | head -1 | tr -d '{}/')
if [[ -n "$PANEL_UUID" ]]; then
    dconf write "/com/solus-project/budgie-panel/panels/{${PANEL_UUID}}/location" "'top'"
    dconf write "/com/solus-project/budgie-panel/panels/{${PANEL_UUID}}/size" 36
fi

for SCHEMA in "com.solus-project.budgie-menu" "org.budgie-desktop.menu"; do
    if gsettings list-keys "$SCHEMA" 2>/dev/null | grep -q "menu-categories-hover"; then
        gsettings set "$SCHEMA" menu-categories-hover true
        break
    fi
done

dconf write /com/solus-project/budgie-menu/menu-categories-hover true 2>/dev/null || true

mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

sleep 1
nohup budgie-panel --replace &>/dev/null &
exit 0
PANELSCRIPT
chmod +x "${CHROOT_DIR}/usr/local/bin/tuga-panel-setup.sh"

mkdir -p "${CHROOT_DIR}/etc/xdg/autostart"
cat > "${CHROOT_DIR}/etc/xdg/autostart/tuga-panel-setup.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Configuracao do Painel Tuga Linux
Exec=/usr/local/bin/tuga-panel-setup.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP

log_info "Autostart do painel configurado."


# NOTA: Plymouth foi REMOVIDO intencionalmente.
# - O módulo 'bgrt' requer UEFI BGRT ACPI table (não existe em VMs BIOS)
# - O módulo 'script' produz texto "Au Au Au" em fallback
# - O 'update-initramfs -u' no chroot pode corromper os hooks do live-boot
# - O parâmetro 'quiet' do kernel já suprime as mensagens de boot
# - Plymouth será adicionado numa versão futura com tema spinner testado

# ═════════════════════════════════════════════════════════════════════════════
# 7. LightDM Greeter
# ═════════════════════════════════════════════════════════════════════════════
log_info "A configurar ecrã de login..."
mkdir -p "${CHROOT_DIR}/etc/lightdm"

cat > "${CHROOT_DIR}/etc/lightdm/lightdm-gtk-greeter.conf" <<'EOF'
[greeter]
background=/usr/share/backgrounds/tuga-linux/wallpaper.png
theme-name=Arc-Darker
icon-theme-name=Papirus
font-name=Noto Sans 10
cursor-theme-name=Breeze_Snow
xft-antialias=true
xft-dpi=96
xft-hintstyle=hintslight
xft-rgba=rgb
indicators=~host;~spacer;~clock;~spacer;~session;~power
clock-format=%H:%M  •  %d %b %Y
position=50%,center 50%,center
EOF

# ═════════════════════════════════════════════════════════════════════════════
# 8. GTK3 Skeleton
# ═════════════════════════════════════════════════════════════════════════════
log_info "A configurar skeleton..."
SKEL_DIR="${CHROOT_DIR}/etc/skel"
mkdir -p "${SKEL_DIR}/.config/gtk-3.0"

cat > "${SKEL_DIR}/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Darker
gtk-icon-theme-name=Papirus
gtk-cursor-theme-name=Breeze_Snow
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

mkdir -p "${CHROOT_DIR}/home/tuga/.config/gtk-3.0"
cp "${SKEL_DIR}/.config/gtk-3.0/settings.ini" \
    "${CHROOT_DIR}/home/tuga/.config/gtk-3.0/settings.ini"
chroot "${CHROOT_DIR}" chown -R tuga:tuga /home/tuga/.config

# ═════════════════════════════════════════════════════════════════════════════
# 9. /etc/os-release — Tuga Linux 1.0.0
# ═════════════════════════════════════════════════════════════════════════════
log_info "A personalizar /etc/os-release..."

cat > "${CHROOT_DIR}/etc/os-release" <<'EOF'
PRETTY_NAME="Tuga Linux 1.0.0"
NAME="Tuga Linux"
VERSION_ID="1.0.0"
VERSION="1.0.0"
ID=tuga-linux
ID_LIKE=debian
HOME_URL="https://github.com/tuga-linux"
SUPPORT_URL="https://github.com/tuga-linux/issues"
BUG_REPORT_URL="https://github.com/tuga-linux/issues"
EOF

cat > "${CHROOT_DIR}/etc/issue" <<'EOF'
Tuga Linux 1.0.0 \n \l

EOF

cat > "${CHROOT_DIR}/etc/issue.net" <<'EOF'
Tuga Linux 1.0.0
EOF

cat > "${CHROOT_DIR}/etc/lsb-release" <<'EOF'
DISTRIB_ID=TugaLinux
DISTRIB_RELEASE=1.0.0
DISTRIB_CODENAME=tuga
DISTRIB_DESCRIPTION="Tuga Linux 1.0.0"
EOF

# ═════════════════════════════════════════════════════════════════════════════
# 10. Remoção de referências Debian
# ═════════════════════════════════════════════════════════════════════════════
log_info "A remover referências Debian do ambiente gráfico..."

rm -f "${CHROOT_DIR}/usr/share/pixmaps/debian-logo.png" 2>/dev/null || true
rm -f "${CHROOT_DIR}/usr/share/pixmaps/debian-logo.svg" 2>/dev/null || true
rm -f "${CHROOT_DIR}/usr/share/pixmaps/debian-logo.eps" 2>/dev/null || true
rm -rf "${CHROOT_DIR}/usr/share/plymouth/themes/debian-logo" 2>/dev/null || true

chroot "${CHROOT_DIR}" /bin/bash -e <<'CHROOT_SCRIPT'
export DEBIAN_FRONTEND=noninteractive
apt-get remove -y desktop-base 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
echo "[INFO] desktop-base removido."
CHROOT_SCRIPT

cat > "${CHROOT_DIR}/etc/motd" <<'EOF'

  ████████╗██╗   ██╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
  ╚══██╔══╝██║   ██║██╔════╝ ██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
     ██║   ██║   ██║██║  ███╗███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
     ██║   ██║   ██║██║   ██║██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
     ██║   ╚██████╔╝╚██████╔╝██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
     ╚═╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝

  Tuga Linux 1.0.0 — Bem-vindo!

EOF

log_info "Theming e polish aplicados com sucesso."
