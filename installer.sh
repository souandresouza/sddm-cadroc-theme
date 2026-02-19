#!/usr/bin/env bash
set -Eeuo pipefail

## SDDM Cadroc Theme Installer — Enterprise Edition

readonly APP_NAME="sddm-cadroc-installer"
readonly LOG_FILE="/var/log/${APP_NAME}.log"

readonly THEME_REPO="https://github.com/souandresouza/sddm-cadroc-theme.git"
readonly THEME_NAME="sddm-cadroc-theme"
readonly THEMES_DIR="/usr/share/sddm/themes"
readonly FONT_DIR="/usr/local/share/fonts/$THEME_NAME"

readonly BACKUP_SUFFIX=".$(date +%s).bak"

NON_INTERACTIVE=false
DEBUG=false
ROLLBACK_ACTIONS=()

# ---------------- LOGGING ----------------

log(){
    local level="$1"; shift
    echo "[$(date '+%F %T')] [$level] $*" | sudo tee -a "$LOG_FILE" >/dev/null
}

info(){ log INFO "$*"; }
warn(){ log WARN "$*"; }
error(){ log ERROR "$*"; }

# ---------------- ROLLBACK ----------------

rollback(){
    warn "Rollback triggered..."

    for action in "${ROLLBACK_ACTIONS[@]}"; do
        eval "$action" || true
    done

    warn "Rollback finished"
}

trap rollback ERR

add_rollback(){
    ROLLBACK_ACTIONS+=("$1")
}

# ---------------- ENV DETECTION ----------------

detect_display(){
    if loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | grep -q wayland; then
        info "Wayland detected"
    else
        info "X11 detected"
    fi
}

detect_pkg_manager(){
    for m in pacman xbps-install dnf zypper apt; do
        command -v "$m" &>/dev/null && { echo "$m"; return; }
    done
    error "Unsupported package manager"
    exit 1
}

check_requirements(){
    command -v git &>/dev/null || { error "git missing"; exit 1; }
    command -v sudo &>/dev/null || { error "sudo missing"; exit 1; }
}

# ---------------- INSTALL ----------------

install_deps(){
    local mgr
    mgr=$(detect_pkg_manager)
    info "Installing dependencies via $mgr"

    case $mgr in
        pacman) sudo pacman --needed -S sddm ;;
        dnf) sudo dnf install -y sddm ;;
        apt) sudo apt update && sudo apt install -y sddm ;;
        zypper) sudo zypper install -y sddm ;;
        xbps-install) sudo xbps-install -y sddm ;;
    esac
}

clone_repo(){
    info "Cloning repository"

    local tmp="/tmp/$THEME_NAME"
    rm -rf "$tmp"

    git clone --depth 1 "$THEME_REPO" "$tmp"

    echo "$tmp"
}

install_theme(){
    local src="$1"
    local dst="$THEMES_DIR/$THEME_NAME"

    if [[ -d "$dst" ]]; then
        sudo mv "$dst" "$dst$BACKUP_SUFFIX"
        add_rollback "sudo rm -rf '$dst'; sudo mv '$dst$BACKUP_SUFFIX' '$dst'"
    fi

    sudo mkdir -p "$dst"
    sudo cp -r "$src"/* "$dst"

    if [[ -d "$dst/Fonts" ]]; then
        sudo mkdir -p "$FONT_DIR"
        sudo cp -r "$dst/Fonts"/* "$FONT_DIR"
        sudo fc-cache -f
        add_rollback "sudo rm -rf '$FONT_DIR'"
    fi

    sudo mkdir -p /etc/sddm.conf.d
    echo -e "[Theme]\nCurrent=$THEME_NAME" \
        | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null

    add_rollback "sudo rm -f /etc/sddm.conf.d/theme.conf"
}

enable_sddm(){
    sudo systemctl enable sddm.service
}

uninstall(){
    info "Uninstalling"

    sudo rm -rf "$THEMES_DIR/$THEME_NAME"
    sudo rm -rf "$FONT_DIR"
    sudo rm -f /etc/sddm.conf.d/theme.conf

    sudo fc-cache -f
}

# ---------------- PIPELINE ----------------

pipeline(){
    check_requirements
    detect_display
    install_deps

    local repo
    repo=$(clone_repo)

    install_theme "$repo"
    enable_sddm

    info "Installation successful"
}

# ---------------- CLI ----------------

usage(){
    echo "Usage: $0 [--non-interactive] [--uninstall] [--debug]"
}

parse_args(){
    for arg in "$@"; do
        case $arg in
            --non-interactive) NON_INTERACTIVE=true ;;
            --uninstall) uninstall; exit 0 ;;
            --debug) DEBUG=true; set -x ;;
            *) usage; exit 1 ;;
        esac
    done
}

# ---------------- MAIN ----------------

main(){
    parse_args "$@"

    if $NON_INTERACTIVE; then
        pipeline
    else
        echo "SDDM Cadroc Installer"
        read -rp "Install now? (y/n) " r
        [[ "$r" =~ ^[Yy]$ ]] && pipeline
    fi
}

main "$@"
