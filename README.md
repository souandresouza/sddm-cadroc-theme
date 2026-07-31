# SDDM Cadroc Theme Installer

Professional installer for the SDDM Cadroc theme with automation, rollback support, and CI integration.

## ✨ Features

* Automated theme installation
* Silent (non-interactive) mode
* Automatic rollback on failure
* Uninstall support
* Environment detection (Wayland/X11)
* Logging system
* CI workflow integration
* Multi-distro support

## 📦 Requirements

* Linux system with systemd
* sudo privileges
* git installed
* Internet connection

## 🚀 Installation

### Clone repository

```bash
git clone https://github.com/souandresouza/sddm-cadroc-theme.git
cd sddm-cadroc-theme
chmod +x installer.sh
```

### Interactive mode

```bash
./installer.sh
```

### Silent installation

```bash
./installer.sh --non-interactive
```

### Debug mode

```bash
./installer.sh --debug
```

## 🗑 Uninstall

```bash
./installer.sh --uninstall
```

## 📁 Project Structure

```
.
├── installer.sh
├── README.md
└── .github/
    └── workflows/
        └── ci.yml
```

## 📝 Logging

Logs are stored in:

```
/var/log/sddm-cadroc-installer.log
```

## 🛠 Supported Package Managers

* pacman (Arch)
* apt (Debian/Ubuntu)
* dnf (Fedora)
* zypper (openSUSE)
* xbps-install (Void)

## 🤝 Contributing

Contributions are welcome. Feel free to open issues or pull requests.

## 📄 License

MIT License
