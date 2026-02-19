#!/usr/bin/env bash
set -euo pipefail

# =============================
# CONFIG
# =============================

readonly THEME_REPO="https://github.com/souandresouza/sddm-cadroc-theme.git"
readonly THEME_NAME="sddm-cadroc-theme"
readonly THEMES_DIR="/usr/share/sddm/themes"
readonly INSTALL_DIR="$HOME/$THEME_NAME"
readonly DATE=$(date +%s)

readonly -a THEMES=(
    "theme-01" "theme-02" "theme-03" "theme-04" "theme-05"
    "theme-06" "theme-07" "theme-08"
    "theme-09" "theme-10"
)

NON_INTERACTIVE=false
DEBUG=false
UNINSTALL=false

# =============================
# LOGGING
# =============================

info()  { echo -e "\e[32m[INFO]\e[0m $*"; }
warn()  { echo -e "\e[33m[WARN]\e[0m $*"; }
error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# =============================
# PACKAGE MANAGER DETECTION
# =============================

detect_pkg_manager() {
    for m in pacman apt dnf zypper xbps-install; do
        command -v "$m" &>/dev/null && { echo "$m"; return; }
    done
    error "Unsupported package manager"
    exit 1
}

# =============================
# INSTALL DEPENDENCIES
# =============================

install_deps() {
    local mgr
    mgr=$(detect_pkg_manager)

    info "Installing dependencies using $mgr"

    case $mgr in
        pacman) sudo pacman --needed -S sddm qt6-svg qt6-virtualkeyboard qt6-multimedia ;;
        apt) sudo apt update && sudo apt install -y sddm qt6-svg-dev qml6-module-qtquick-virtualkeyboard ;;
        dnf) sudo dnf install -y sddm qt6-qtsvg qt6-qtvirtualkeyboard ;;
        zypper) sudo zypper install -y sddm libQt6Svg6 qt6-virtualkeyboard ;;
        xbps-install) sudo xbps-install -y sddm qt6-svg ;;
    esac
}

# =============================
# CLONE REPO
# =============================

clone_repo() {
    [[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "${INSTALL_DIR}_$DATE"
    git clone --depth 1 "$THEME_REPO" "$INSTALL_DIR"
}

# =============================
# INSTALL THEME
# =============================

install_theme() {
    local dst="$THEMES_DIR/$THEME_NAME"

    [[ ! -d "$INSTALL_DIR" ]] && {
        error "Repository not cloned"
        exit 1
    }

    [[ -d "$dst" ]] && sudo mv "$dst" "${dst}_$DATE"

    sudo mkdir -p "$dst"
    sudo cp -r "$INSTALL_DIR"/* "$dst"/

    echo -e "[Theme]\nCurrent=$THEME_NAME" | sudo tee /etc/sddm.conf >/dev/null
}

# =============================
# SELECT THEME
# =============================

select_theme() {
    local metadata="$THEMES_DIR/$THEME_NAME/metadata.desktop"

    [[ ! -f "$metadata" ]] && {
        error "Theme not installed"
        exit 1
    }

    local theme="${THEMES[0]}"

    if ! $NON_INTERACTIVE; then
        echo "Select theme:"
        select theme in "${THEMES[@]}"; do
            [[ -n "$theme" ]] && break
        done
    fi

    sudo sed -i "s|^ConfigFile=.*|ConfigFile=Themes/${theme}.conf|" "$metadata"
    info "Theme selected: $theme"
}

# =============================
# ENABLE SDDM
# =============================

enable_sddm() {
    sudo systemctl disable display-manager.service 2>/dev/null || true
    sudo systemctl enable sddm.service
    warn "Reboot required"
}

# =============================
# UNINSTALL
# =============================

uninstall_theme() {
    local dst="$THEMES_DIR/$THEME_NAME"

    if [[ -d "$dst" ]]; then
        sudo rm -rf "$dst"
        info "Theme removed"
    else
        warn "Theme not installed"
    fi
}

# =============================
# TESTS
# =============================

run_tests() {
    local test_script="$(dirname "$0")/tests/smoke-test.sh"

    [[ ! -f "$test_script" ]] && {
        error "Smoke test not found"
        exit 1
    }

    chmod +x "$test_script"

    info "Running smoke tests..."
    "$test_script"

    local result=$?

    if [[ $result -eq 0 ]]; then
        info "All tests passed ✅"
    else
        error "Tests failed ❌"
    fi

    exit $result
}

# =============================
# MAIN INSTALL FLOW
# =============================

main() {
    [[ $EUID -eq 0 ]] && {
        error "Do not run as root"
        exit 1
    }

    command -v git &>/dev/null || {
        error "git is required"
        exit 1
    }

    if $UNINSTALL; then
        uninstall_theme
        exit 0
    fi

    install_deps
    clone_repo
    install_theme
    select_theme
    enable_sddm

    info "Installation complete"
}

# =============================
# ARGUMENT PARSER
# =============================

usage() {
    echo "Usage: $0 [--non-interactive] [--uninstall] [--debug] [--test]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive) NON_INTERACTIVE=true ;;
        --uninstall) UNINSTALL=true ;;
        --debug) DEBUG=true; set -x ;;
        --test) run_tests ;;
        *) usage; exit 1 ;;
    esac
    shift
done

main
