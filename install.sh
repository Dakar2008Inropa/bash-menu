#!/bin/bash
# Installer til bash-menu.
# Fra et clone:  ./install.sh
# Direkte:       curl -fsSL https://raw.githubusercontent.com/Dakar2008Inropa/bash-menu/main/install.sh | bash
set -euo pipefail

REPO="Dakar2008Inropa/bash-menu"
BRANCH="main"
DEST="${BASH_MENU_DIR:-$HOME/bash-menu}"

chmod_tree() {
    chmod +x "$1/menu.sh" "$1/install.sh" "$1/tools/hello.py" "$1/tools/mygrep.sh" 2>/dev/null || true
}

install_desktop() {
    local root="$1"
    local apps="$HOME/.local/share/applications"
    local desktop=""
    local file
    mkdir -p "$apps"

    if command -v xdg-user-dir >/dev/null 2>&1; then
        desktop="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    if [[ -z "$desktop" || "$desktop" == "$HOME" ]]; then
        if [[ -d "$HOME/Skrivebord" ]]; then
            desktop="$HOME/Skrivebord"
        else
            desktop="$HOME/Desktop"
            mkdir -p "$desktop"
        fi
    fi
    mkdir -p "$desktop"

    write_desktop() {
        local target="$1"
        cat >"$target" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Bash Menu
Name[da]=Bash-menu
GenericName=Administrationsmenu
Comment=Åbn Bash-administrationsmenuen i et terminalvindue
Exec=${root}/menu.sh
Path=${root}
Terminal=true
Categories=System;Utility;
Icon=utilities-terminal
StartupNotify=false
EOF
        chmod +x "$target"
        if command -v gio >/dev/null 2>&1; then
            gio set "$target" metadata::trusted true 2>/dev/null || true
        fi
    }

    write_desktop "$apps/bash-menu.desktop"
    write_desktop "$desktop/Bash-menu.desktop"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps" 2>/dev/null || true
    fi
    echo "Skrivebordsikon: $desktop/Bash-menu.desktop"
    echo "Programmet ligger også i applikationsmenuen som Bash Menu."
    echo "På GNOME: højreklik ikonet og vælg Tillad start, hvis det spørger."
}

finish() {
    local root="$1"
    chmod_tree "$root"
    install_desktop "$root"
    echo "bash-menu er klar i: $root"
    echo "Start fra ikonet, eller:  cd \"$root\" && ./menu.sh"
}

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$here/menu.sh" && -d "$here/lib" ]]; then
        finish "$here"
        exit 0
    fi
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl mangler. Installer den med: sudo apt install curl" >&2
    exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
    echo "tar mangler." >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Henter $REPO …"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}" -o "$tmp/src.tgz"
tar -xzf "$tmp/src.tgz" -C "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
mkdir -p "$DEST"
cp -a "$src"/. "$DEST"/
finish "$DEST"
