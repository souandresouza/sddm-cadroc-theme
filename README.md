# SDDM Cadroc Theme Installer

Professional installer for the SDDM Cadroc theme with automation, rollback support, and CI integration.

## ✨ Features

- Automated theme installation
- Silent (non-interactive) mode
- Automatic rollback on failure
- Uninstall support
- Environment detection (Wayland/X11)
- Logging system
- CI workflow integration
- Multi-distro support

## 📦 Requirements

- Linux system with systemd
- sudo privileges
- git installed
- Internet connection

## 🚀 Installation

### Interactive mode

```bash
git clone https://github.com/souandresouza/sddm-cadroc-theme.git
cd sddm-cadroc-theme
chmod +x installer.sh
./installer.sh
./installer.sh --non-interactive
./installer.sh --debug
./installer.sh --uninstall
./installer.sh --test
.
├── installer.sh
├── README.md
├── tests/
│   └── smoke-test.sh
└── .github/
    └── workflows/
        └── ci.yml
/var/log/sddm-cadroc-installer.log
🛠 Supported Package Managers

pacman (Arch)

apt (Debian/Ubuntu)

dnf (Fedora)

zypper (openSUSE)

xbps-install (Void)
