#!/usr/bin/env bash
# =============================================================================
# installer.sh -- instala/remove o tema SDDM do Cadroc
# =============================================================================
#
# Uso:
#   ./installer.sh                     Instala o tema (copia este repositório)
#   ./installer.sh --recolor [ARQUIVO] Aplica a paleta gerada pelo Cadroc
#   ./installer.sh --wallpaper IMAGEM  Usa IMAGEM como fundo da tela de login
#   ./installer.sh --hide-users a,b    Oculta usuários da lista do SDDM
#   ./installer.sh --install-deps      Instala as dependências via pacman
#   ./installer.sh --enable            Habilita o sddm como display-manager
#   ./installer.sh --test              Abre o tema em modo de teste (sem instalar)
#   ./installer.sh --test-installed    Testa o tema já instalado em /usr/share
#   ./installer.sh --uninstall         Remove o tema e o drop-in do SDDM
#   ./installer.sh --dry-run           Mostra o que faria, sem alterar nada
#
# O tema é copiado para /usr/share/sddm/themes/sddm-cadroc-theme e o SDDM é
# apontado por /etc/sddm.conf.d/10-cadroc-theme.conf (não mexe em
# /etc/sddm.conf). Reexecutar é seguro: a instalação anterior vai para
# ~/.cache/sddm-cadroc-theme/backups/<timestamp>/.
#
# Variáveis de ambiente opcionais:
#   SDDM_THEMES_DIR   instala em outro prefixo (útil para testar sem root)
#   SDDM_CONF_DIR     diretório do drop-in (padrão: /etc/sddm.conf.d)
# =============================================================================

set -euo pipefail

readonly THEME_NAME="sddm-cadroc-theme"
readonly THEMES_DIR="${SDDM_THEMES_DIR:-/usr/share/sddm/themes}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SRC_DIR
readonly DEST_DIR="$THEMES_DIR/$THEME_NAME"
readonly SDDM_DROPIN="${SDDM_CONF_DIR:-/etc/sddm.conf.d}/10-cadroc-theme.conf"
readonly STATE_CONF="${XDG_STATE_HOME:-$HOME/.local/state}/cadrocspace/sddm/theme.conf"
readonly BACKUP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/sddm-cadroc-theme/backups"

DRY_RUN=0
ASSUME_YES=0
DO_TEST=0
DO_UNINSTALL=0
DO_ENABLE=0
DO_DEPS=0
RECOLOR_FILE=""
WALLPAPER=""
PALETTE_WALLPAPER=""
HIDE_USERS=""

info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -eq 0 ]] || { [[ -d "$THEMES_DIR" ]] && [[ -w "$THEMES_DIR" ]]; }; then
    # root ou instalação em um prefixo gravável (SDDM_THEMES_DIR=...).
    SUDO=()
else
    SUDO=(sudo)
fi

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

usage() { sed -n '4,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# -----------------------------------------------------------------------------
# Dependências
# -----------------------------------------------------------------------------

check_deps() {
    local missing=()
    command -v sddm-greeter-qt6 >/dev/null 2>&1 || missing+=("sddm")
    if command -v pacman >/dev/null 2>&1; then
        for pkg in qt6-svg qt6-multimedia; do
            pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
        done
        # Teclado virtual é opcional: sem ele o botão simplesmente não aparece.
        if ! pacman -Qq qt6-virtualkeyboard >/dev/null 2>&1; then
            warn "qt6-virtualkeyboard ausente: o teclado virtual não aparecerá."
        fi
    fi
    if ((${#missing[@]})); then
        warn "Dependências ausentes: ${missing[*]}"
        warn "Instale com: ./installer.sh --install-deps"
        return 1
    fi
    return 0
}

install_deps() {
    command -v pacman >/dev/null 2>&1 || die "Este instalador só instala dependências via pacman."
    run "${SUDO[@]}" pacman --needed --noconfirm -S sddm qt6-svg qt6-multimedia qt6-virtualkeyboard
}

# -----------------------------------------------------------------------------
# Instalação
# -----------------------------------------------------------------------------

backup_existing() {
    [[ -d "$DEST_DIR" ]] || return 0
    local stamp dest
    stamp="$(date +%Y%m%d-%H%M%S)"
    dest="$BACKUP_ROOT/$stamp"
    info "Backup do tema anterior: $dest"
    run mkdir -p "$dest"
    run "${SUDO[@]}" cp -a "$DEST_DIR/." "$dest/"
}

copy_theme() {
    run "${SUDO[@]}" mkdir -p "$DEST_DIR"
    if command -v rsync >/dev/null 2>&1; then
        run "${SUDO[@]}" rsync -a --delete \
            --exclude '.git' --exclude '.github' --exclude 'screenshots' \
            "$SRC_DIR/" "$DEST_DIR/"
    else
        run "${SUDO[@]}" rm -rf "$DEST_DIR"
        run "${SUDO[@]}" mkdir -p "$DEST_DIR"
        run "${SUDO[@]}" cp -a "$SRC_DIR/." "$DEST_DIR/"
        run "${SUDO[@]}" rm -rf "$DEST_DIR/.git" "$DEST_DIR/.github"
    fi
    run "${SUDO[@]}" chmod -R a+rX "$DEST_DIR"
}

write_dropin() {
    local tmp
    tmp="$(mktemp)"
    {
        printf '[Theme]\nCurrent=%s\n' "$THEME_NAME"
        if [[ -n "$HIDE_USERS" ]]; then
            printf '\n[Users]\nHideUsers=%s\n' "$HIDE_USERS"
        fi
    } > "$tmp"

    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] escrever %s:\n' "$SDDM_DROPIN"
        sed 's/^/    /' "$tmp"
    else
        "${SUDO[@]}" install -Dm644 "$tmp" "$SDDM_DROPIN"
    fi
    rm -f "$tmp"
    info "Tema selecionado no SDDM: $THEME_NAME"
}

apply_recolor() {
    local src="${RECOLOR_FILE:-$STATE_CONF}"

    # Sem arquivo de paleta: mantém a paleta padrão do repositório.
    if [[ -z "$RECOLOR_FILE" && ! -f "$STATE_CONF" ]]; then
        info "Nenhuma paleta do Cadroc encontrada em $STATE_CONF; mantendo a padrão."
        return 0
    fi
    [[ -f "$src" ]] || die "Arquivo de paleta não encontrado: $src"

    info "Aplicando paleta: $src"

    # A paleta gerada pelo Cadroc contém só as chaves que ela controla (cores,
    # fonte e, opcionalmente, Wallpaper). O resto do conf do tema é preservado,
    # para que o repositório continue sendo a fonte de verdade do comportamento.
    local base="$DEST_DIR/Themes/cadroc-default.conf" tmp line key merged=0
    [[ -f "$base" ]] || base="$SRC_DIR/Themes/cadroc-default.conf"
    tmp="$(mktemp)"
    cp "$base" "$tmp"

    while IFS= read -r line; do
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        [[ "$key" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || continue

        if [[ "$key" == "Wallpaper" ]]; then
            PALETTE_WALLPAPER="${line#*=}"
            PALETTE_WALLPAPER="${PALETTE_WALLPAPER%\"}"
            PALETTE_WALLPAPER="${PALETTE_WALLPAPER#\"}"
            continue
        fi

        merged=$((merged + 1))
        if grep -qE "^${key}=" "$tmp"; then
            awk -v k="$key" -v v="$line" 'index($0, k "=") == 1 { print v; next } { print }' \
                "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
        else
            printf '%s\n' "$line" >> "$tmp"
        fi
    done < <(grep -vE '^[[:space:]]*(#|$)' "$src" || true)

    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] mesclar %d chaves de %s em %s\n' "$merged" "$src" "$base"
        [[ -n "$PALETTE_WALLPAPER" ]] && printf '[dry-run] wallpaper da paleta: %s\n' "$PALETTE_WALLPAPER"
        rm -f "$tmp"
    else
        "${SUDO[@]}" install -Dm644 "$tmp" "$base"
        rm -f "$tmp"
        info "Paleta aplicada ($merged chaves)."
    fi
}

apply_wallpaper() {
    local src="$1" ext base
    [[ -f "$src" ]] || die "Wallpaper não encontrado: $src"
    case "${src,,}" in
        *.png|*.jpg|*.jpeg|*.webp) ext="${src##*.}" ;;
        *) die "Formato não suportado (use png/jpg/webp): $src" ;;
    esac
    base="wallpaper.${ext,,}"

    info "Instalando wallpaper de login: $src"
    run "${SUDO[@]}" install -Dm644 "$src" "$DEST_DIR/Backgrounds/$base"

    if [[ $DRY_RUN -eq 0 ]]; then
        # Reescreve só a chave Background no conf do tema instalado.
        "${SUDO[@]}" sed -i "s|^Background=.*|Background=\"Backgrounds/$base\"|" \
            "$DEST_DIR/Themes/cadroc-default.conf"
    else
        printf '[dry-run] ajustar Background=%s em %s\n' "$base" "$DEST_DIR/Themes/cadroc-default.conf"
    fi
}

install_theme() {
    [[ -f "$SRC_DIR/Main.qml" ]] || die "Rode este script de dentro do repositório do tema."
    check_deps || true
    backup_existing
    copy_theme
    write_dropin
    apply_recolor
    if [[ -n "$WALLPAPER" ]]; then
        apply_wallpaper "$WALLPAPER"
    elif [[ -n "$PALETTE_WALLPAPER" ]]; then
        # Wallpaper sugerido pela paleta do Cadroc (o atual do desktop).
        if [[ -f "$PALETTE_WALLPAPER" ]]; then
            apply_wallpaper "$PALETTE_WALLPAPER"
        else
            warn "Wallpaper da paleta não existe mais: $PALETTE_WALLPAPER"
        fi
    fi
    info "Instalação concluída. Teste sem sair da sessão:"
    info "    ./installer.sh --test"
}

# -----------------------------------------------------------------------------
# Remoção
# -----------------------------------------------------------------------------

uninstall_theme() {
    if [[ -d "$DEST_DIR" ]]; then
        info "Removendo $DEST_DIR"
        run "${SUDO[@]}" rm -rf "$DEST_DIR"
    else
        warn "Tema não está instalado em $DEST_DIR."
    fi

    if [[ -f "$SDDM_DROPIN" ]]; then
        info "Removendo $SDDM_DROPIN"
        run "${SUDO[@]}" rm -f "$SDDM_DROPIN"
    fi

    info "Pronto. O SDDM volta ao tema padrão no próximo login."
}

# -----------------------------------------------------------------------------
# Teste
# -----------------------------------------------------------------------------

test_theme() {
    local dir="$SRC_DIR"
    [[ $DO_TEST -eq 2 ]] && dir="$DEST_DIR"
    command -v sddm-greeter-qt6 >/dev/null 2>&1 || die "sddm-greeter-qt6 não encontrado."
    info "Abrindo o tema em modo de teste ($dir). Feche a janela para sair."
    exec sddm-greeter-qt6 --test-mode --theme "$dir"
}

enable_sddm() {
    if command -v systemctl >/dev/null 2>&1; then
        run "${SUDO[@]}" systemctl enable sddm.service
        info "sddm.service habilitado."
    else
        warn "systemctl não encontrado; habilite o sddm manualmente."
    fi
}

# -----------------------------------------------------------------------------
# Argumentos
# -----------------------------------------------------------------------------

while (($#)); do
    case "$1" in
        --recolor)
            RECOLOR_FILE="${2:-}"
            [[ -n "$RECOLOR_FILE" && ! -f "$RECOLOR_FILE" ]] && die "Arquivo inexistente: $RECOLOR_FILE"
            [[ -n "$RECOLOR_FILE" ]] && shift
            ;;
        --wallpaper)      WALLPAPER="${2:?informe o caminho da imagem}"; shift ;;
        --hide-users)     HIDE_USERS="${2:?informe usuários separados por vírgula}"; shift ;;
        --install-deps)   DO_DEPS=1 ;;
        --enable)         DO_ENABLE=1 ;;
        --test)           DO_TEST=1 ;;
        --test-installed) DO_TEST=2 ;;
        --uninstall)      DO_UNINSTALL=1 ;;
        --yes|-y)         ASSUME_YES=1 ;;
        --dry-run)        DRY_RUN=1 ;;
        --help|-h)        usage; exit 0 ;;
        *)                die "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
done

# --assume-yes é aceito para simetria com outros instaladores; o script não
# faz perguntas interativas.
: "$ASSUME_YES"

[[ $DRY_RUN -eq 1 ]] && info "Modo dry-run: nada será alterado."

if [[ $DO_DEPS -eq 1 ]]; then
    install_deps
    exit 0
fi

if [[ $DO_TEST -ne 0 ]]; then
    test_theme
fi

if [[ $DO_UNINSTALL -eq 1 ]]; then
    uninstall_theme
    exit 0
fi

install_theme

if [[ $DO_ENABLE -eq 1 ]]; then
    enable_sddm
fi
