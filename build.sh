#!/bin/bash
set -euo pipefail

###############################################################################
#
#  ████████╗██╗   ██╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
#  ╚══██╔══╝██║   ██║██╔════╝ ██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
#     ██║   ██║   ██║██║  ███╗███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
#     ██║   ██║   ██║██║   ██║██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
#     ██║   ╚██████╔╝╚██████╔╝██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
#     ╚═╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝
#
#  Script Master de Build — Tuga Linux 1.0.0
#  Baseado em Debian Trixie | Budgie Desktop | BIOS + UEFI
#
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

source "${SCRIPTS_DIR}/config.sh"

BUILD_START=$(date +%s)

# Verificações iniciais
if [[ $EUID -ne 0 ]]; then
    log_error "Este script deve ser executado como root."
    echo "  Utilização:  sudo ./build.sh"
    exit 1
fi

# Verificar debootstrap
if ! command -v debootstrap &>/dev/null; then
    log_warn "debootstrap não encontrado. A executar script de preparação do host..."
    bash "${SCRIPTS_DIR}/00-preparar-host.sh"
fi

# Trap para limpeza em caso de erro
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        log_error "O build falhou com código de saída: ${exit_code}"
        log_info "A limpar mounts residuais..."
        umount_chroot
        log_info "Limpeza concluída. Corrige o erro e volta a executar o build."
    fi
}
trap cleanup_on_error EXIT

# Execução sequencial
FASES=(
    "00-preparar-host.sh    |Fase 0/8 — Preparação do Host"
    "01-bootstrap.sh        |Fase 1/8 — Bootstrap (debootstrap)"
    "02-configurar-chroot.sh|Fase 2/8 — Configuração do Chroot"
    "03-kernel-boot.sh      |Fase 3/8 — Kernel e Bootloader"
    "04-desktop.sh          |Fase 4/8 — Budgie Desktop"
    "05-software.sh         |Fase 5/8 — Software Adicional"
    "06-theming.sh          |Fase 6/8 — Theming e Polish"
    "07-calamares.sh        |Fase 7/8 — Calamares (Instalador)"
    "08-gerar-iso.sh        |Fase 8/8 — Geração do ISO"
)

for entry in "${FASES[@]}"; do
    SCRIPT_NAME=$(echo "$entry" | cut -d'|' -f1 | xargs)
    PHASE_DESC=$(echo "$entry" | cut -d'|' -f2)

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ${PHASE_DESC}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "Script não encontrado: ${SCRIPT_PATH}"
        exit 1
    fi

    PHASE_START=$(date +%s)
    bash "$SCRIPT_PATH"
    PHASE_END=$(date +%s)
    PHASE_DURATION=$((PHASE_END - PHASE_START))
    log_info "$(date '+%H:%M:%S') — ${PHASE_DESC} concluída em ${PHASE_DURATION}s"
done

# Resumo final
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
BUILD_MINUTES=$((BUILD_DURATION / 60))
BUILD_SECONDS=$((BUILD_DURATION % 60))

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅  BUILD DO TUGA LINUX CONCLUÍDO COM SUCESSO!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ -f "$OUTPUT_ISO" ]]; then
    ISO_SIZE=$(du -sh "$OUTPUT_ISO" | cut -f1)
    echo -e "  📁 ISO:        ${BOLD}${OUTPUT_ISO}${NC}"
    echo -e "  📦 Tamanho:    ${BOLD}${ISO_SIZE}${NC}"
fi
echo -e "  ⏱️  Duração:    ${BOLD}${BUILD_MINUTES}m ${BUILD_SECONDS}s${NC}"
echo -e "  🖥️  Base:       ${BOLD}Tuga Linux 1.0.0 (Trixie) amd64${NC}"
echo -e "  🎨 Desktop:    ${BOLD}Budgie + Arc-Darker + Papirus${NC}"
echo -e "  🔧 Boot:       ${BOLD}BIOS (isolinux) + UEFI (GRUB)${NC}"
echo -e "  🤖 IA:         ${BOLD}Ollama (LLMs locais)${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
