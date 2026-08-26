#!/bin/sh
# snappy-dock — launcher/controller for snappydock-d + QuickShell
#
# Usage:
#   snappy-dock              Start the dock
#   snappy-dock --kill       Kill running instance
#   snappy-dock --restart    Restart (kill + start)
#   snappy-dock --status     Check if running
#   snappy-dock --config     Print config file path
#   snappy-dock --verbose    Start with verbose logging (repeat for debug)
#   snappy-dock --version    Print version
#   snappy-dock --help       This message

VERSION="0.1.0"
APP_NAME="snappy-dock"

# ── Locate shell directory ──────────────────────────────────────────
# Priority: 1) $SNAPPY_DOCK_SHELL  2) alongside this script  3) system install
find_shell_dir() {
    if [ -n "$SNAPPY_DOCK_SHELL" ] && [ -d "$SNAPPY_DOCK_SHELL" ]; then
        echo "$SNAPPY_DOCK_SHELL"
        return
    fi

    # Check relative to this script's location
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/../share/snappy-dock/shell/shell.qml" ]; then
        echo "$script_dir/../share/snappy-dock/shell"
        return
    fi

    # Check common install paths
    for dir in \
        "/usr/local/share/snappy-dock/shell" \
        "/usr/share/snappy-dock/shell" \
        "$HOME/.local/share/snappy-dock/shell" \
        "$HOME/.config/quickshell/snappy-dock"; do
        if [ -f "$dir/shell.qml" ]; then
            echo "$dir"
            return
        fi
    done

    echo ""
}

find_config_gui_dir() {
    if [ -n "$SNAPPY_DOCK_CONFIG_GUI" ] && [ -d "$SNAPPY_DOCK_CONFIG_GUI" ]; then
        echo "$SNAPPY_DOCK_CONFIG_GUI"
        return
    fi

    # Check relative to this script's location
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/config-gui/shell.qml" ]; then
        echo "$script_dir/config-gui"
        return
    fi
    if [ -f "$script_dir/../share/snappy-dock/config-gui/shell.qml" ]; then
        echo "$script_dir/../share/snappy-dock/config-gui"
        return
    fi

    # Check common install paths
    for dir in \
        "/usr/local/share/snappy-dock/config-gui" \
        "/usr/share/snappy-dock/config-gui" \
        "$HOME/.local/share/snappy-dock/config-gui"; do
        if [ -f "$dir/shell.qml" ]; then
            echo "$dir"
            return
        fi
    done

    echo ""
}

# ── Config path ─────────────────────────────────────────────────────
config_dir() {
    if [ -n "$XDG_CONFIG_HOME" ]; then
        echo "$XDG_CONFIG_HOME/snappy-dock"
    else
        echo "$HOME/.config/snappy-dock"
    fi
}

config_file() {
    echo "$(config_dir)/config.ini"
}

read_ini_value() {
    section="$1"
    key="$2"
    file="$(config_file)"

    [ -f "$file" ] || return

    awk -F= -v want_section="$section" -v want_key="$key" '
        function trim(s) {
            sub(/^[ \t\r\n]+/, "", s)
            sub(/[ \t\r\n]+$/, "", s)
            return s
        }
        BEGIN {
            current = ""
            want_section = tolower(want_section)
            want_key = tolower(want_key)
        }
        /^[ \t]*($|[#;])/ { next }
        /^[ \t]*\[/ {
            line = trim($0)
            sub(/^\[/, "", line)
            sub(/\].*$/, "", line)
            current = tolower(trim(line))
            next
        }
        index($0, "=") {
            raw_key = $1
            raw_value = substr($0, index($0, "=") + 1)
            if (current == want_section && tolower(trim(raw_key)) == want_key) {
                print trim(raw_value)
                exit
            }
        }
    ' "$file"
}

apply_icon_theme_config() {
    theme="$(read_ini_value Icons Theme)"
    if [ -z "$theme" ]; then
        theme="$(read_ini_value Icons IconTheme)"
    fi

    if [ -z "$theme" ]; then
        return
    fi

    case "$theme" in
    default | Default | system | System)
        unset QS_ICON_THEME
        ;;
    *)
        export QS_ICON_THEME="$theme"
        ;;
    esac
}

# ── Process management ──────────────────────────────────────────────
is_running() {
    pgrep -x "quickshell" >/dev/null 2>&1 &&
        pgrep -x "snappydock-d" >/dev/null 2>&1
}

do_kill() {
    pkill -x "snappydock-d" 2>/dev/null
    # Give the daemon a moment to exit, which will also close QuickShell
    sleep 0.2
    # Kill only dock quickshell processes (not config-gui)
    pkill -f "quickshell.*snappy-dock/shell" 2>/dev/null
    echo "$APP_NAME: stopped"
}

# Kill only the dock (daemon + dock shell), leave config-gui alive
do_kill_dock_only() {
    pkill -x "snappydock-d" 2>/dev/null
    sleep 0.2
    # Kill only the dock shell, not config-gui
    pkill -f "quickshell.*snappy-dock/shell" 2>/dev/null
    # Extra safety: don't kill anything matching config-gui
    echo "$APP_NAME: dock stopped"
}

do_start() {
    shell_dir="$(find_shell_dir)"
    if [ -z "$shell_dir" ]; then
        echo "$APP_NAME: ERROR: Cannot find shell directory." >&2
        echo "  Set SNAPPY_DOCK_SHELL or reinstall with 'sudo make install'" >&2
        exit 1
    fi

    if ! command -v snappydock-d >/dev/null 2>&1; then
        echo "$APP_NAME: ERROR: snappydock-d not found in PATH." >&2
        echo "  Build and install with 'sudo make install'" >&2
        exit 1
    fi

    if ! command -v quickshell >/dev/null 2>&1; then
        echo "$APP_NAME: ERROR: quickshell not found in PATH." >&2
        echo "  Install QuickShell: https://quickshell.outfoxxed.me/" >&2
        exit 1
    fi

    echo "$APP_NAME: starting (shell: $shell_dir)"
    apply_icon_theme_config
    # ── Isolate Qt from GTK/portal ──────────────────────────────────
    # Prevent Qt from loading the GTK platform theme plugin (avoids
    # gtk.css parse warnings like 'border-spacing is not a valid property').
    export QT_QPA_PLATFORMTHEME=""
    export QT_STYLE_OVERRIDE="Fusion"
    # A dock has no use for xdg-desktop-portal services (file dialogs,
    # etc.).  Disabling it avoids the 'Connection already associated
    # with an application ID' DBus collision when multiple quickshell
    # instances share a session bus.
    export QT_NO_XDG_DESKTOP_PORTAL=1
    exec quickshell -p "$shell_dir"
}

# Start the dock detached in background, return immediately
do_start_detached() {
    shell_dir="$(find_shell_dir)"
    if [ -z "$shell_dir" ]; then
        echo "$APP_NAME: ERROR: Cannot find shell directory." >&2
        exit 1
    fi

    if ! command -v snappydock-d >/dev/null 2>&1; then
        echo "$APP_NAME: ERROR: snappydock-d not found in PATH." >&2
        exit 1
    fi

    if ! command -v quickshell >/dev/null 2>&1; then
        echo "$APP_NAME: ERROR: quickshell not found in PATH." >&2
        exit 1
    fi

    apply_icon_theme_config
    # ── Isolate Qt from GTK/portal ──────────────────────────────────
    export QT_QPA_PLATFORMTHEME=""
    export QT_STYLE_OVERRIDE="Fusion"
    export QT_NO_XDG_DESKTOP_PORTAL=1
    nohup quickshell -p "$shell_dir" >/dev/null 2>&1 &
    disown
    echo "$APP_NAME: dock started (pid $!)"
}

do_config_gui() {
    gui_dir="$(find_config_gui_dir)"
    if [ -z "$gui_dir" ]; then
        echo "$APP_NAME: ERROR: Cannot find config-gui directory." >&2
        echo "  Set SNAPPY_DOCK_CONFIG_GUI or reinstall with 'sudo make install'" >&2
        exit 1
    fi

    if ! command -v quickshell >/dev/null 2>&1; then
        echo "$APP_NAME: ERROR: quickshell not found in PATH." >&2
        echo "  Install QuickShell: https://quickshell.outfoxxed.me/" >&2
        exit 1
    fi

    echo "$APP_NAME: opening settings GUI (shell: $gui_dir)"
    apply_icon_theme_config
    # ── Isolate Qt from GTK/portal ──────────────────────────────────
    export QT_QPA_PLATFORMTHEME=""
    export QT_STYLE_OVERRIDE="Fusion"
    export QT_NO_XDG_DESKTOP_PORTAL=1
    exec quickshell -p "$gui_dir"
}

# ── Main ────────────────────────────────────────────────────────────

# Parse all arguments — extract verbose flags and the primary action
VERBOSE_LEVEL=0
ACTION=""

for arg in "$@"; do
    case "$arg" in
    --verbose | -V)
        VERBOSE_LEVEL=$((VERBOSE_LEVEL + 1))
        ;;
    -VV)
        VERBOSE_LEVEL=2
        ;;
    *)
        if [ -z "$ACTION" ]; then
            ACTION="$arg"
        else
            echo "$APP_NAME: unexpected argument '$arg'" >&2
            echo "Run '$APP_NAME --help' for usage." >&2
            exit 1
        fi
        ;;
    esac
done

# Export verbose level for the daemon to inherit
if [ "$VERBOSE_LEVEL" -gt 0 ]; then
    export SNAPPY_DOCK_VERBOSE="$VERBOSE_LEVEL"
fi

case "${ACTION:-}" in
--config-gui | -g | --gui)
    do_config_gui
    ;;
--kill | -k)
    do_kill
    ;;
--restart | -r)
    do_kill
    sleep 0.3
    do_start
    ;;
--restart-dock)
    # Used by config-gui: kill only the dock, start it detached, exit cleanly
    do_kill_dock_only
    sleep 0.5
    do_start_detached
    ;;
--status | -s)
    if is_running; then
        echo "$APP_NAME: running (pid $(pgrep -x snappydock-d))"
    else
        echo "$APP_NAME: not running"
    fi
    ;;
--config | -c)
    cfg="$(config_dir)/config.ini"
    echo "Config:  $cfg"
    echo "Pinned:  $(config_dir)/pinned"
    if [ ! -f "$cfg" ]; then
        echo "(config file does not exist yet — using defaults)"
    fi
    ;;
--version | -v)
    echo "$APP_NAME $VERSION"
    ;;
--help | -h)
    cat <<EOF
$APP_NAME $VERSION — lightweight Hyprland dock

USAGE:
    snappy-dock                  Start the dock
    snappy-dock --config-gui     Open settings GUI
    snappy-dock --kill           Kill running instance
    snappy-dock --restart        Restart (kill + start)
    snappy-dock --status         Check if running
    snappy-dock --config         Show config file paths
    snappy-dock --verbose (-V)   Enable info logging (repeat for debug)
    snappy-dock --version        Print version
    snappy-dock --help           This message

FLAGS:
    --verbose can be combined with other commands:
        snappy-dock --restart --verbose
        snappy-dock -V -V   (debug level)
        snappy-dock -VV     (debug level, shorthand)

ENVIRONMENT:
    SNAPPY_DOCK_SHELL            Override shell directory path
    SNAPPY_DOCK_VERBOSE          Set verbosity (1=info, 2=debug)

CONFIG:
    $(config_dir)/config.ini     Dock settings (INI format)
    $(config_dir)/pinned         Pinned apps (one class per line)
EOF
    ;;
"")
    do_start
    ;;
*)
    echo "$APP_NAME: unknown option '$ACTION'" >&2
    echo "Run '$APP_NAME --help' for usage." >&2
    exit 1
    ;;
esac
