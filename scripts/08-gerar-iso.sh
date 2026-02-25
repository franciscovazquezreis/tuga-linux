#!/bin/bash
set -euo pipefail

###############################################################################
# Tuga Linux — Fase 8: Geração do ISO
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_root

if [[ ! -d "$CHROOT_DIR" ]]; then
    log_error "Directório chroot não encontrado: ${CHROOT_DIR}"
    exit 1
fi

# Fase 1: Limpar chroot
log_step "Fase 1/6 — A limpar o chroot..."
chroot "${CHROOT_DIR}" apt-get clean 2>/dev/null || true
rm -rf "${CHROOT_DIR}/var/cache/apt/archives"/*.deb
rm -rf "${CHROOT_DIR}/tmp"/* "${CHROOT_DIR}/var/tmp"/*
find "${CHROOT_DIR}/var/log" -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -f "${CHROOT_DIR}/etc/resolv.conf"
touch "${CHROOT_DIR}/etc/resolv.conf"
log_info "Chroot limpo."

# Fase 2: Preparar estrutura ISO
log_step "Fase 2/6 — A preparar estrutura do ISO..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/live" "${ISO_DIR}/boot/grub" "${ISO_DIR}/.disk"
echo "Tuga Linux 1.0.0 amd64" > "${ISO_DIR}/.disk/info"
touch "${ISO_DIR}/.disk/base_installable"

# Fase 3: Reconstruir initramfs e copiar kernel
log_step "Fase 3/6 — A reconstruir initramfs e copiar kernel..."

# Garantir que o initramfs contém todos os hooks (live-boot, firmware, etc.)
mount_chroot
chroot "${CHROOT_DIR}" update-initramfs -u 2>/dev/null || \
    echo "[AVISO] update-initramfs falhou (pode ser normal em chroot)"
umount_chroot
VMLINUZ=$(ls -1 "${CHROOT_DIR}/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -1)
INITRD=$(ls -1 "${CHROOT_DIR}/boot/initrd.img-"* 2>/dev/null | sort -V | tail -1)
if [[ -z "$VMLINUZ" || -z "$INITRD" ]]; then
    log_error "Kernel ou initrd não encontrados em ${CHROOT_DIR}/boot/"
    exit 1
fi
cp "$VMLINUZ" "${ISO_DIR}/live/vmlinuz"
cp "$INITRD" "${ISO_DIR}/live/initrd.img"
log_info "Kernel: $(basename "$VMLINUZ")"
log_info "Initrd: $(basename "$INITRD")"

# Fase 4: Comprimir rootfs
log_step "Fase 4/6 — A comprimir rootfs (pode demorar vários minutos)..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/live/filesystem.squashfs" \
    -comp xz -b 1M -Xbcj x86 \
    -wildcards \
    -ef /dev/stdin <<'EXCLUDE_LIST'
proc/*
sys/*
dev/*
run/*
tmp/*
var/cache/apt/archives/*.deb
EXCLUDE_LIST
SQUASHFS_SIZE=$(du -sh "${ISO_DIR}/live/filesystem.squashfs" | cut -f1)
log_info "Squashfs criado: ${SQUASHFS_SIZE}"

# Fase 5: Configurar boot BIOS (isolinux) + UEFI (GRUB)
log_step "Fase 5/7 — A configurar boot BIOS + UEFI..."

# ── 5a: BIOS boot via isolinux ──
log_info "A configurar isolinux (BIOS boot)..."
mkdir -p "${ISO_DIR}/isolinux"

# Copiar binários isolinux
ISOLINUX_DIR="/usr/lib/ISOLINUX"
SYSLINUX_DIR="/usr/lib/syslinux/modules/bios"

cp "${ISOLINUX_DIR}/isolinux.bin"    "${ISO_DIR}/isolinux/"
cp "${ISOLINUX_DIR}/isohdpfx.bin"    "${ISO_DIR}/isolinux/" 2>/dev/null || \
    cp "/usr/lib/ISOLINUX/isohdpfx.bin" "${ISO_DIR}/isolinux/"
cp "${SYSLINUX_DIR}/ldlinux.c32"     "${ISO_DIR}/isolinux/"
cp "${SYSLINUX_DIR}/libcom32.c32"    "${ISO_DIR}/isolinux/"
cp "${SYSLINUX_DIR}/libutil.c32"     "${ISO_DIR}/isolinux/"
cp "${SYSLINUX_DIR}/vesamenu.c32"    "${ISO_DIR}/isolinux/"

# Menu isolinux
cat > "${ISO_DIR}/isolinux/isolinux.cfg" <<'ISOCFG'
UI vesamenu.c32
PROMPT 0
TIMEOUT 100
DEFAULT live

MENU TITLE Tuga Linux 1.0.0
MENU COLOR border       30;44    #40ffffff #a0000000 std
MENU COLOR title        1;36;44  #9033ccff #a0000000 std
MENU COLOR sel          7;37;40  #e0ffffff #20ffffff all
MENU COLOR unsel        37;44    #50ffffff #a0000000 std
MENU COLOR help         37;40    #c0ffffff #a0000000 std
MENU COLOR tabmsg       31;40    #90ffff00 #a0000000 std

LABEL live
    MENU LABEL ^Tuga Linux - Sessao Live
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live components quiet username=tuga hostname=tuga-linux locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon

LABEL safe
    MENU LABEL Tuga Linux - Modo ^Seguro
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live components nomodeset username=tuga hostname=tuga-linux locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon

LABEL ram
    MENU LABEL Tuga Linux - Carregar em ^RAM
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live components toram quiet username=tuga hostname=tuga-linux locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon
ISOCFG

log_info "Isolinux (BIOS) configurado."

# ── 5b: UEFI boot via GRUB ──
log_info "A configurar GRUB (UEFI boot)..."
mkdir -p "${ISO_DIR}/boot/grub"

cat > "${ISO_DIR}/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=10
set color_normal=white/black
set color_highlight=cyan/black
insmod all_video
insmod gfxterm
set gfxmode=auto
terminal_output gfxterm

menuentry "Tuga Linux — Sessão Live" --class tuga --class linux {
    linux /live/vmlinuz boot=live components quiet \
        username=tuga hostname=tuga-linux \
        locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon
    initrd /live/initrd.img
}

menuentry "Tuga Linux — Sessão Live (Modo Seguro)" --class tuga --class linux {
    linux /live/vmlinuz boot=live components nomodeset \
        username=tuga hostname=tuga-linux \
        locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon
    initrd /live/initrd.img
}

menuentry "Tuga Linux — Sessão Live (RAM)" --class tuga --class linux {
    linux /live/vmlinuz boot=live components toram quiet \
        username=tuga hostname=tuga-linux \
        locales=pt_PT.UTF-8 keyboard-layouts=pt timezone=Europe/Lisbon
    initrd /live/initrd.img
}

menuentry "" { true }

menuentry "Desligar" --class shutdown {
    echo "A desligar..."
    halt
}

menuentry "Reiniciar" --class restart {
    echo "A reiniciar..."
    reboot
}
EOF

# Criar imagem EFI
log_info "A criar imagem EFI..."
GRUB_MODULES="normal boot linux configfile part_gpt part_msdos fat iso9660 \
search search_fs_uuid search_fs_file search_label ls cat echo test true \
all_video font gfxterm loopback squash4 ext2 chain efifwsetup reboot halt"

grub-mkstandalone \
    --format=x86_64-efi \
    --output="${WORK_DIR}/bootx64.efi" \
    --locales="" \
    --fonts="" \
    --modules="${GRUB_MODULES}" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"

EFI_IMG="${ISO_DIR}/boot/grub/efi.img"
dd if=/dev/zero of="${EFI_IMG}" bs=1K count=4096
mkfs.vfat -F 12 "${EFI_IMG}"
mmd -i "${EFI_IMG}" ::/EFI ::/EFI/BOOT
mcopy -i "${EFI_IMG}" "${WORK_DIR}/bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI

# Copiar EFI bootloader para iso_root (exigido por UEFI USB boot)
mkdir -p "${ISO_DIR}/EFI/BOOT"
cp "${WORK_DIR}/bootx64.efi" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
rm -f "${WORK_DIR}/bootx64.efi"
log_info "Imagem EFI criada."

# Fase 6: Gerar ISO híbrido (BIOS + UEFI)
log_step "Fase 6/7 — A gerar ISO híbrido BIOS+UEFI..."

xorriso -as mkisofs \
    -r -V "TUGA_LINUX" \
    -iso-level 3 \
    -o "${OUTPUT_ISO}" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr "${ISO_DIR}/isolinux/isohdpfx.bin" \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -append_partition 2 0xef "${ISO_DIR}/boot/grub/efi.img" \
    "${ISO_DIR}/"

# Fase 7: Verificação
log_step "Fase 7/7 — A verificar ISO..."
ISO_SIZE=$(du -sh "${OUTPUT_ISO}" | cut -f1)

echo ""
echo "============================================================================="
echo -e "${GREEN}  ✅  TUGA LINUX — ISO GERADO COM SUCESSO!${NC}"
echo "============================================================================="
echo ""
echo -e "  📁 Ficheiro:  ${CYAN}${OUTPUT_ISO}${NC}"
echo -e "  📦 Tamanho:   ${CYAN}${ISO_SIZE}${NC}"
echo -e "  🏗️  Squashfs:  ${CYAN}${SQUASHFS_SIZE}${NC}"
echo -e "  🖥️  Boot:      ${CYAN}BIOS (isolinux) + UEFI (GRUB)${NC}"
echo ""
echo "  Testar em VM (BIOS — funciona no GNOME Boxes):"
echo "    qemu-system-x86_64 -enable-kvm -m 4096 \\"
echo "      -cdrom ${OUTPUT_ISO} -boot d"
echo ""
echo "  Testar em VM (UEFI):"
echo "    qemu-system-x86_64 -enable-kvm -m 4096 \\"
echo "      -bios /usr/share/ovmf/OVMF.fd \\"
echo "      -cdrom ${OUTPUT_ISO} -boot d"
echo ""
echo "  Gravar em USB:"
echo "    sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress oflag=sync"
echo ""
echo "============================================================================="
