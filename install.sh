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

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$here/menu.sh" && -d "$here/lib" ]]; then
        chmod_tree "$here"
        echo "bash-menu er klar i: $here"
        echo "Start med:  cd \"$here\" && ./menu.sh -n"
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
chmod_tree "$DEST"
echo "Installeret i: $DEST"
echo "Start med:  cd \"$DEST\" && ./menu.sh -n"
