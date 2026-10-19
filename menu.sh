#!/bin/bash
# ============================================================
# menu.sh — Entrypoint (tynd)
# Sourcer lib/*.sh + games/*.sh, kører boot + hovedløkke.
# .NET-bro: tænk Program.cs / Main() — logikken ligger i modulerne.
# ============================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib"
GAMES_DIR="$ROOT/games"

OWNER_NAME="Daniel Vinther Andersen"
COMPANY="Inropa A/S"
COPY_YEAR=$(date +%Y)

# ------------------------------------------------------------
# Fun & Extras – konfiguration
# ------------------------------------------------------------
FUN_TYPEWRITER_MSG="Hello from ${COMPANY} — Bash can be fun too."
FUN_TYPEWRITER_DELAY="0.035"
FUN_TYPEWRITER_JITTER="0.045"
FUN_TYPEWRITER_PUNCT="0.18"
FUN_PROGRESS_TITLE="Deploying awesomeness"
FUN_PROGRESS_SECONDS=3
FUN_MATRIX_SECONDS=5
FUN_MATRIX_COLOR=$'\e[38;2;40;220;80m'
SHUTDOWN_MATRIX_SECONDS=1.5
FUN_CLOCK_SECONDS=8
FUN_COW_MSG="Moo! Bash beats notepad.exe"
FUN_RAINBOW_TEXT="INROPA · BASH SYSTEM"
FUN_FIRE_SECONDS=4
FUN_CONFETTI_SECONDS=3
FUN_SPRITE_SECONDS=5
FUN_BREAKOUT_SECONDS=25
BREAKOUT_MAIN_SECONDS=0
BREAKOUT_PADDLE_STEP=5
BREAKOUT_DEBUG=0
BREAKOUT_LOG="$ROOT/breakout.debug.log"
GAMES_DEBUG=1
GAMES_LOG="$ROOT/games.debug.log"
FUN_BOOT_TITLE="${COMPANY} Boot Sequence"
FUN_BANNER_WORD="INROPA"
BOOT_SCREEN_SECONDS=8
SHUTDOWN_SCREEN_SECONDS=8

FUN_SPINNER_DELAY="0.12"
FUN_SPINNER_FRAMES=60
FUN_SPINNER_LOAD="Loading - Please Wait"
FUN_SPINNER_DONE="Complete"
FG_SPINNER_TEXT=$'\e[38;2;140;210;255m'
FG_SPINNER_ICON=$'\e[38;2;255;255;255m'

VALG_ROW=0
VALG_COL=0
BOX_START=0
BOX_TOTAL=0
CHOICE_BOT=0
DEMO_ROW=0
DEMO_ROW2=0
DEMO_ROW_TOP=0
DEMO_COL=0
DEMO_W=0
CLOCK_ROW=0
MENU_MODE="main"
NEED_REDRAW=0
on_winch() { NEED_REDRAW=1; }

hide_cursor() { printf '\e[?25l'; }
show_cursor() { printf '\e[?25h'; }

cleanup() {
    show_cursor
    printf '\e[0m'
    printf '\e[2J\e[H'
}
trap cleanup EXIT
trap 'exit 130' INT
trap on_winch WINCH

# --- Moduler (rækkefølge er vigtig) ---
# shellcheck source=lib/tui.sh
source "$LIB_DIR/tui.sh"
FUN_SPINNER_LOAD_BIG=$(to_fullwidth "$FUN_SPINNER_LOAD")
FUN_SPINNER_DONE_BIG=$(to_fullwidth "$FUN_SPINNER_DONE")

# shellcheck source=lib/menus.sh
source "$LIB_DIR/menus.sh"
# shellcheck source=lib/system.sh
source "$LIB_DIR/system.sh"
# shellcheck source=lib/fun.sh
source "$LIB_DIR/fun.sh"
# shellcheck source=lib/boot.sh
source "$LIB_DIR/boot.sh"
# shellcheck source=lib/tools.sh
source "$LIB_DIR/tools.sh"
# shellcheck source=lib/ssh.sh
source "$LIB_DIR/ssh.sh"

# Spillene (ét spil pr. fil)
# shellcheck source=games/common.sh
[[ -f $GAMES_DIR/common.sh ]] && source "$GAMES_DIR/common.sh"
# shellcheck source=games/highscore.sh
[[ -f $GAMES_DIR/highscore.sh ]] && source "$GAMES_DIR/highscore.sh"
for _game_file in breakout pong snake tetris invaders ttt mines blackjack; do
    # shellcheck disable=SC1090
    [[ -f $GAMES_DIR/${_game_file}.sh ]] && source "$GAMES_DIR/${_game_file}.sh"
done
unset _game_file

CHOICE_VALUE=""

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<'EOF'
Usage: ./menu.sh

  -h, --help    Vis denne hjælp

Moduler: lib/tui.sh menus.sh system.sh fun.sh boot.sh tools.sh ssh.sh + games/
EOF
            exit 0
            ;;
    esac
done

boot_screen

while true; do
    MENU_MODE=main
    show_menu
    wait_for_choice
    case "$CHOICE_VALUE" in
        1) list_processes; continue ;;
        2) kill_process; continue ;;
        3) system_info; continue ;;
        4) list_services; continue ;;
        5) find_file; continue ;;
        6) users_and_groups; continue ;;
        7) fun_extras; continue ;;
        8) games_menu; continue ;;
        9) tools_menu; continue ;;
        10) ssh_menu; continue ;;
        +) quit_program ;;
        *)
            cls
            goto $(( $(rows) / 2 )) 4
            printf '%s%s%s  Invalid choice: %s  %s' "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$CHOICE_VALUE" "$R"
            sleep 1.2
            continue
            ;;
    esac
    pause
done
