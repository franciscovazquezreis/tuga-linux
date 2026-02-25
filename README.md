# 🇵🇹 Tuga Linux

<div align="center">

![Tuga Linux](branding/wallpaper.png)

**Distribuição Linux portuguesa, criada de raiz com a ajuda da IA.**

[![Version](https://img.shields.io/badge/versão-1.0.0-brightgreen?style=for-the-badge)](https://github.com/tuga-linux/releases)
[![Base](https://img.shields.io/badge/base-Debian%20Trixie-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org)
[![Desktop](https://img.shields.io/badge/desktop-Budgie-4C8BF5?style=for-the-badge)](https://buddiesofbudgie.org)
[![Boot](https://img.shields.io/badge/boot-BIOS%20%2B%20UEFI-blue?style=for-the-badge)](.)
[![License](https://img.shields.io/badge/licença-GPL--3.0-orange?style=for-the-badge)](LICENSE)
[![AI](https://img.shields.io/badge/feito%20com-IA-blueviolet?style=for-the-badge&logo=openai&logoColor=white)](.)

</div>

---

## ✨ O que é o Tuga Linux?

O **Tuga Linux** é uma distribuição Linux portuguesa, construída de raiz sobre Debian Trixie com o desktop **Budgie**. Foi criada inteiramente com a assistência de IA — desde o bootstrap até à geração do ISO.

> 🎯 **Objetivo**: Oferecer um sistema operativo completo, bonito e funcional, pronto a usar em português.

---

## 🖥️ Características

| Componente | Detalhe |
|:---|:---|
| 🏗️ **Base** | Debian Trixie (amd64) |
| 🎨 **Desktop** | Budgie Desktop |
| 🎭 **Tema** | Arc-Darker + Papirus + Breeze Snow |
| 🔤 **Fontes** | Noto Sans + Fira Code |
| 🔊 **Áudio** | PipeWire |
| 🔒 **Firewall** | UFW (ativo por defeito) |
| 🤖 **IA** | Ollama (LLMs locais) |
| 💾 **Instalador** | Calamares |
| ⚡ **Boot** | BIOS (isolinux) + UEFI (GRUB) |

---

## 📦 Software Pré-instalado

<details>
<summary><b>🌐 Browsers</b></summary>

- Firefox ESR (com localização pt-PT)
- Google Chrome

</details>

<details>
<summary><b>📝 Produtividade</b></summary>

- LibreOffice (com localização pt)

</details>

<details>
<summary><b>🎬 Multimédia</b></summary>

- VLC Media Player
- Darktable (fotografia RAW)
- Eye of GNOME (visualizador de imagens)
- Codecs completos (GStreamer)

</details>

<details>
<summary><b>🔧 Sistema</b></summary>

- Timeshift (backups do sistema)
- Gufw (firewall gráfico)
- GParted (partições)
- Déjà Dup (backups pessoais)
- GNOME Disks
- GNOME System Monitor

</details>

<details>
<summary><b>🛠️ Utilitários</b></summary>

- Nemo (gestor de ficheiros)
- GNOME Terminal
- Gedit (editor de texto)
- Calculadora, Captura de ecrã, File Roller
- fastfetch, htop, inxi

</details>

<details>
<summary><b>🤖 Inteligência Artificial</b></summary>

- Ollama — Executar LLMs localmente
- Python 3 + pip + venv + NumPy

```bash
ollama serve &
ollama run llama3.2
```

</details>

---

## 🚀 Como Construir

### Pré-requisitos

- Sistema Linux (Debian/Ubuntu recomendado) com `sudo`
- ~15 GB de espaço em disco
- Ligação à internet

### Build

```bash
# Clonar o repositório
git clone https://github.com/SEU_USERNAME/tuga-linux.git
cd tuga-linux

# Tornar executável
chmod +x build.sh scripts/*.sh

# Executar o build completo (~30-60 min)
sudo ./build.sh
```

O ISO final será gerado como `tuga-linux.1.0.0-amd64.iso`.

---

## 🧪 Testar

```bash
# GNOME Boxes — basta abrir o ISO

# QEMU (BIOS)
qemu-system-x86_64 -enable-kvm -m 4096 \
  -cdrom tuga-linux.1.0.0-amd64.iso -boot d

# QEMU (UEFI)
qemu-system-x86_64 -enable-kvm -m 4096 \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom tuga-linux.1.0.0-amd64.iso -boot d

# Gravar em USB
sudo dd if=tuga-linux.1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## 🔑 Sessão Live

| | |
|:---|:---|
| 👤 **Utilizador** | `tuga` |
| 🔒 **Password** | `tuga` |
| 🔄 **Auto-login** | Sim |
| 💿 **Instalar** | Clicar em **"Instalar Tuga Linux 1.0.0"** no desktop |

---

## 📁 Estrutura do Projeto

```
tuga-linux/
├── build.sh                    # 🏗️  Script master de build
├── README.md                   # 📖 Este ficheiro
├── branding/
│   └── wallpaper.png           # 🖼️  Wallpaper do desktop
├── config/
│   └── apt/
│       └── sources.list        # 📋 Repositórios APT
└── scripts/
    ├── config.sh               # ⚙️  Configuração central
    ├── 00-preparar-host.sh     # 📥 Dependências do host
    ├── 01-bootstrap.sh         # 🏗️  Debootstrap
    ├── 02-configurar-chroot.sh # 🔧 Hostname, locale, users
    ├── 03-kernel-boot.sh       # 🐧 Kernel + GRUB + live-boot
    ├── 04-desktop.sh           # 🖥️  Budgie + LightDM
    ├── 05-software.sh          # 📦 Aplicações
    ├── 06-theming.sh           # 🎨 Temas, painel, wallpaper
    ├── 07-calamares.sh         # 💿 Instalador Calamares
    └── 08-gerar-iso.sh         # 📀 Geração do ISO
```

---

## 🗺️ Roadmap

- [x] Build from scratch (Debian Trixie)
- [x] Budgie Desktop + LightDM
- [x] Calamares installer com branding
- [x] Tema Arc-Darker + Papirus
- [x] Boot BIOS + UEFI
- [x] Ollama (IA local)
- [ ] Repositório de pacotes próprio
- [ ] Suporte a Flatpak pré-configurado
- [ ] Welcome App personalizada
- [ ] Tuga Software Center

---

## 🤝 Contribuir

Contribuições são bem-vindas! Sinta-se à vontade para:

1. Fazer **fork** do repositório
2. Criar uma **branch** para a sua funcionalidade
3. Submeter um **pull request**

---

## 📄 Licença

Este projeto está licenciado sob a [GPL-3.0](LICENSE).

---

<div align="center">

**Tuga Linux** — A distro portuguesa, feita com ajuda da IA. 🤖🇵🇹

*Porque Portugal também merece a sua própria distribuição Linux.*

</div>
