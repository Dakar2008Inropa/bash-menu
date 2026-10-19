# ============================================================
# lib/tui.sh — TUI-primitives (farver, cls/goto, clock, page banner)
# Sourced af menu.sh — .NET-bro: fælles UI-helpers / "controls"
# ============================================================

to_fullwidth() {
    local s=$1 i c out="" 
    local -i o
    for ((i = 0; i < ${#s}; i++)); do
        c=${s:i:1}
        printf -v o '%d' "'$c"
        if (( o == 32 )); then
            out+=$'　'   # ideographic space (bredde 2)
        elif (( o >= 33 && o <= 126 )); then
            printf -v c '\\U%08x' $((o + 0xFEE0))
            out+=$(printf '%b' "$c")
        else
            out+=$c
        fi
    done
    printf '%s' "$out"
}

R=$'\e[0m'
BOLD=$'\e[1m'
NOBG=$'\e[49m'

FG_WHITE=$'\e[38;2;240;240;240m'
FG_DIM=$'\e[38;2;140;140;140m'
FG_MENU=$'\e[38;2;100;200;220m'
FG_ORANGE=$'\e[38;2;255;160;40m'

FG_NUM=$'\e[38;2;80;220;235m'
FG_LABEL=$'\e[38;2;190;230;240m'
FG_HINT=$'\e[38;2;120;160;175m'
FG_TITLE=$'\e[38;2;255;185;70m'
FG_CHOICE=$'\e[38;2;255;175;55m'
FG_BY=$'\e[38;2;255;175;60m'
FG_BYLINE=$'\e[38;2;255;230;190m'
FG_ACCENT=$'\e[38;2;220;140;90m'
FG_EXIT=$'\e[38;2;255;120;110m'      # [+] Exit / Quit (rød) — må ikke bruges til spil
FG_BACK=$'\e[38;2;255;185;70m'       # [0] Back (amber) — må ikke bruges til spil
FG_FUN=$'\e[38;2;180;130;255m'       # lilla accent til Fun-punktet
FG_GAMES=$'\e[38;2;255;160;40m'      # orange accent til Games-punktet

# Unikke spilfarver (menu-tal + banner) — ingen overlap med Back/Quit
FG_GAME_BREAKOUT=$'\e[38;2;0;210;255m'     # cyan
FG_GAME_PONG=$'\e[38;2;70;220;110m'        # green
FG_GAME_SNAKE=$'\e[38;2;160;255;60m'       # lime
FG_GAME_TETRIS=$'\e[38;2;70;130;255m'      # blue
FG_GAME_INVADERS=$'\e[38;2;170;90;255m'    # violet
FG_GAME_XO=$'\e[38;2;255;80;200m'          # magenta
FG_GAME_MINES=$'\e[38;2;40;200;185m'       # teal
FG_GAME_BJ=$'\e[38;2;200;90;140m'          # wine/rose (≠ quit-rød)
# FUN-banner gradient (lilla → magenta)
FG_FUN1=$'\e[38;2;210;170;255m'
FG_FUN2=$'\e[38;2;190;140;255m'
FG_FUN3=$'\e[38;2;170;110;245m'
FG_FUN4=$'\e[38;2;150;90;230m'
FG_FUN5=$'\e[38;2;130;70;210m'
FG_FUN6=$'\e[38;2;110;55;185m'

FG_RED1=$'\e[38;2;255;90;90m'
FG_RED2=$'\e[38;2;235;60;60m'
FG_RED3=$'\e[38;2;210;45;50m'
FG_RED4=$'\e[38;2;180;35;40m'
FG_RED5=$'\e[38;2;150;25;35m'
FG_RED6=$'\e[38;2;120;20;30m'

FG_YEL1=$'\e[38;2;255;220;80m'
FG_YEL2=$'\e[38;2;255;190;50m'
FG_YEL3=$'\e[38;2;255;160;35m'
FG_YEL4=$'\e[38;2;240;130;25m'
FG_YEL5=$'\e[38;2;220;110;20m'
FG_YEL6=$'\e[38;2;190;90;15m'

BG_FOOTER=$'\e[48;2;120;25;35m'

cols() { tput cols 2>/dev/null || echo 80; }
rows() { tput lines 2>/dev/null || echo 24; }
goto() { printf '\e[%d;%dH' "$(($1 + 1))" "$(($2 + 1))"; }
# 3J = ryd scrollback, 2J = ryd synlig skærm, H = cursor hjem
# (navigation er app-niveau — J/K i lister påvirkes ikke)
cls()  { printf '\e[3J\e[2J\e[H'; }

repeat() {
    local c=$1 n=$2 i
    for ((i = 0; i < n; i++)); do printf '%s' "$c"; done
}

# Live clock — centreret på CLOCK_ROW (opdateres i input-loops)
set_clock_row() { CLOCK_ROW=$1; }

paint_clock() {
    (( CLOCK_ROW < 1 )) && return
    local t w left
    t=$(date '+%H:%M:%S')
    w=$(cols)
    left=$(( (w - ${#t}) / 2 ))
    (( left < 1 )) && left=1
    # Ryd et fast felt, så gamle cifre ikke “hænger”
    goto "$CLOCK_ROW" $((left > 2 ? left - 2 : 1))
    printf '%s%s' "$NOBG" "$(repeat ' ' $((${#t} + 4)))"
    goto "$CLOCK_ROW" "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_YEL1" "$BOLD" "$t" "$R"
}

sleep_ms() {
    # sleep med decimal (bash / sleep)
    sleep "$1" 2>/dev/null || sleep 0.05
}


# Tegn ét blok-ord (centreret) startende på række $1
_draw_block_word() {
    local top=$1
    shift
    local -n _blines=$1
    local -n _bcols=$2
    local w left i bw
    w=$(cols)
    bw=${#_blines[0]}
    left=$(( (w - bw) / 2 ))
    (( left < 1 )) && left=1
    for i in "${!_blines[@]}"; do
        goto $((top + i)) "$left"
        printf '%s%s%s%s%s' "$NOBG" "${_bcols[$i]}" "$BOLD" "${_blines[$i]}" "$R"
    done
}

# Mini-banner til undersider (samme stil som FUN / BASH+SYSTEM)
# Nogle sider har to ord stablet (som BASH / SYSTEM): KILL+PROCESS, USERS+GROUPS
draw_page_banner() {
    local key=$1
    local subtitle=$2
    local skip_clock=${3:-}
    local w left
    local lines=()
    local colors=()
    local lines2=()
    local colors2=()
    local dual=0
    local sub_row=8
    local clock_row=9
    PAGE_MSG_ROW=12

    w=$(cols)
    case $key in
        PROCESSES)
            lines=(
                '██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗███████╗███████╗'
                '██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝'
                '██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗█████╗  ███████╗'
                '██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║██╔══╝  ╚════██║'
                '██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║███████╗███████║'
                '╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝'
            )
            colors=("$FG_NUM" "$FG_MENU" "$FG_LABEL" "$FG_NUM" "$FG_MENU" "$FG_HINT")
            ;;
        KILL)
            # To linjer: KILL / PROCESS (som BASH / SYSTEM)
            dual=1
            lines=(
                '██╗  ██╗██╗██╗     ██╗     '
                '██║ ██╔╝██║██║     ██║     '
                '█████╔╝ ██║██║     ██║     '
                '██╔═██╗ ██║██║     ██║     '
                '██║  ██╗██║███████╗███████╗'
                '╚═╝  ╚═╝╚═╝╚══════╝╚══════╝'
            )
            colors=("$FG_RED1" "$FG_RED2" "$FG_RED3" "$FG_RED4" "$FG_RED5" "$FG_RED6")
            lines2=(
                '██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗'
                '██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝'
                '██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗'
                '██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║'
                '██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║'
                '╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝'
            )
            colors2=("$FG_ORANGE" "$FG_YEL3" "$FG_YEL2" "$FG_YEL3" "$FG_ORANGE" "$FG_ACCENT")
            ;;
        SYSTEM)
            # To linjer: SYSTEM / INFO
            dual=1
            lines=(
                '███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗'
                '██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║'
                '███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║'
                '╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║'
                '███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║'
                '╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝'
            )
            colors=("$FG_YEL1" "$FG_YEL2" "$FG_YEL3" "$FG_YEL4" "$FG_YEL5" "$FG_YEL6")
            lines2=(
                '██╗███╗   ██╗███████╗ ██████╗ '
                '██║████╗  ██║██╔════╝██╔═══██╗'
                '██║██╔██╗ ██║█████╗  ██║   ██║'
                '██║██║╚██╗██║██╔══╝  ██║   ██║'
                '██║██║ ╚████║██║     ╚██████╔╝'
                '╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝ '
            )
            colors2=("$FG_NUM" "$FG_MENU" "$FG_LABEL" "$FG_NUM" "$FG_MENU" "$FG_HINT")
            ;;
        SERVICES)
            lines=(
                '███████╗███████╗██████╗ ██╗   ██╗██╗ ██████╗███████╗███████╗'
                '██╔════╝██╔════╝██╔══██╗██║   ██║██║██╔════╝██╔════╝██╔════╝'
                '███████╗█████╗  ██████╔╝██║   ██║██║██║     █████╗  ███████╗'
                '╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║     ██╔══╝  ╚════██║'
                '███████║███████╗██║  ██║ ╚████╔╝ ██║╚██████╗███████╗███████║'
                '╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝ ╚═════╝╚══════╝╚══════╝'
            )
            colors=("$FG_YEL2" "$FG_ORANGE" "$FG_ACCENT" "$FG_YEL3" "$FG_ORANGE" "$FG_ACCENT")
            ;;
        FIND)
            lines=(
                '███████╗██╗███╗   ██╗██████╗ '
                '██╔════╝██║████╗  ██║██╔══██╗'
                '█████╗  ██║██╔██╗ ██║██║  ██║'
                '██╔══╝  ██║██║╚██╗██║██║  ██║'
                '██║     ██║██║ ╚████║██████╔╝'
                '╚═╝     ╚═╝╚═╝  ╚═══╝╚═════╝ '
            )
            colors=("$FG_FUN1" "$FG_FUN2" "$FG_FUN3" "$FG_FUN4" "$FG_FUN5" "$FG_FUN6")
            ;;
        USERS)
            # To linjer: USERS / GROUPS
            dual=1
            lines=(
                '██╗   ██╗███████╗███████╗██████╗ ███████╗'
                '██║   ██║██╔════╝██╔════╝██╔══██╗██╔════╝'
                '██║   ██║███████╗█████╗  ██████╔╝███████╗'
                '██║   ██║╚════██║██╔══╝  ██╔══██╗╚════██║'
                '╚██████╔╝███████║███████╗██║  ██║███████║'
                ' ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝'
            )
            colors=("$FG_BYLINE" "$FG_BY" "$FG_TITLE" "$FG_BYLINE" "$FG_BY" "$FG_ACCENT")
            lines2=(
                ' ██████╗ ██████╗  ██████╗ ██╗   ██╗██████╗ ███████╗'
                '██╔════╝ ██╔══██╗██╔═══██╗██║   ██║██╔══██╗██╔════╝'
                '██║  ███╗██████╔╝██║   ██║██║   ██║██████╔╝███████╗'
                '██║   ██║██╔══██╗██║   ██║██║   ██║██╔═══╝ ╚════██║'
                '╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║     ███████║'
                ' ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚══════╝'
            )
            colors2=("$FG_FUN1" "$FG_FUN2" "$FG_FUN3" "$FG_FUN4" "$FG_FUN5" "$FG_FUN6")
            ;;
        TOOLS)
            lines=(
                '████████╗ ██████╗  ██████╗ ██╗     ███████╗'
                '╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝'
                '   ██║   ██║   ██║██║   ██║██║     ███████╗'
                '   ██║   ██║   ██║██║   ██║██║     ╚════██║'
                '   ██║   ╚██████╔╝╚██████╔╝███████╗███████║'
                '   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝'
            )
            colors=("$FG_YEL2" "$FG_ORANGE" "$FG_ACCENT" "$FG_YEL3" "$FG_ORANGE" "$FG_ACCENT")
            ;;
        SSH)
            lines=(
                '███████╗███████╗██╗  ██╗'
                '██╔════╝██╔════╝██║  ██║'
                '███████╗███████╗███████║'
                '╚════██║╚════██║██╔══██║'
                '███████║███████║██║  ██║'
                '╚══════╝╚══════╝╚═╝  ╚═╝'
            )
            colors=("$FG_NUM" "$FG_MENU" "$FG_LABEL" "$FG_NUM" "$FG_MENU" "$FG_HINT")
            ;;
        *)
            lines=('????')
            colors=("$FG_WHITE")
            ;;
    esac

    if (( ${#lines[@]} )); then
        _draw_block_word 1 lines colors
    fi

    if (( dual )); then
        _draw_block_word 8 lines2 colors2
        sub_row=15
        clock_row=16
        PAGE_MSG_ROW=18
    fi

    left=$(( (w - ${#subtitle}) / 2 ))
    (( left < 1 )) && left=1
    goto "$sub_row" "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_TITLE" "$BOLD" "$subtitle" "$R"

    if [[ $skip_clock != noclock ]]; then
        set_clock_row "$clock_row"
        paint_clock
    fi
}

PAGE_MSG_ROW=12

run_page() {
    local key=$1 subtitle=$2 msg=$3
    cls
    hide_cursor
    draw_page_banner "$key" "$subtitle"
    goto "$PAGE_MSG_ROW" 4
    printf '%s%s%s%s' "$NOBG" "$FG_LABEL" "$msg" "$R"
}

