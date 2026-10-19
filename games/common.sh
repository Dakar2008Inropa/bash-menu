#!/bin/bash
# ============================================================
# games/common.sh – fælles helpers til alle spil
# Sourced fra menu.sh før de enkelte spil-filer
# ============================================================

# Efter blok-banner: spillene starter typisk omkring række 9
GAME_CONTENT_TOP=9

# Defaults (menu.sh kan overstyre før source)
: "${GAMES_DEBUG:=1}"
: "${GAMES_LOG:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/games.debug.log}"

# Bash-logging (som simpel logger når vi ikke har C#-exceptions)
_game_log() {
    (( GAMES_DEBUG )) || return 0
    printf '%s | %s\n' "$(date '+%H:%M:%S')" "$*" >> "$GAMES_LOG"
}

_game_log_start() {
    local name=$1
    (( GAMES_DEBUG )) || return 0
    {
        echo "========== $name start $(date '+%Y-%m-%d %H:%M:%S') =========="
        echo "cols=$(cols 2>/dev/null || echo ?) rows=$(rows 2>/dev/null || echo ?)"
    } >> "$GAMES_LOG"
}

# ------------------------------------------------------------
# TTY helpers (samme idé som Breakout – undgå echo/freeze)
# ------------------------------------------------------------
GAME_OLD_STTY=""

game_tty_setup() {
    GAME_OLD_STTY=""
    if [[ -t 0 ]]; then
        GAME_OLD_STTY=$(stty -g 2>/dev/null || true)
        stty -echo -icanon min 0 time 0 2>/dev/null || stty -echo -icanon 2>/dev/null || true
    fi
    hide_cursor
    _game_log "tty_setup ok"
}

game_tty_restore() {
    if [[ -n ${GAME_OLD_STTY:-} ]]; then
        stty "$GAME_OLD_STTY" 2>/dev/null || stty echo icanon 2>/dev/null || true
    fi
    local _c n=0
    while (( n < 40 )) && IFS= read -r -s -n 1 -t 0.001 _c; do ((n++)); done
    _game_log "tty_restore ok"
}

game_drain() {
    local _c n=0
    while (( n < 40 )) && IFS= read -r -s -n 1 -t 0.001 _c; do ((n++)); done
}

# Læs tast (a/d/w/s/pile/space/enter/q/f/…). Sætter GAME_KEY.
# Brug -N (ikke -n): -n stopper ved newline og giver tom streng ved Enter/Return.
# Enter/Return = LF eller CR; numpad Enter = ESC O M; Space = open/place i flere spil.
game_read_key() {
    GAME_KEY=""
    local c1="" c2="" c3=""
    if ! IFS= read -r -s -N 1 -t 0.01 c1; then
        return 1
    fi
    if [[ $c1 == $'\e' ]]; then
        IFS= read -r -s -N 1 -t 0.03 c2 || true
        if [[ $c2 == '[' || $c2 == O ]]; then
            IFS= read -r -s -N 1 -t 0.03 c3 || true
            case $c3 in
                A) GAME_KEY=w; return 0 ;;
                B) GAME_KEY=s; return 0 ;;
                C) GAME_KEY=d; return 0 ;;
                D) GAME_KEY=a; return 0 ;;
                M) GAME_KEY=enter; return 0 ;;  # keypad Enter (application mode)
            esac
        fi
        return 1
    fi
    # Enter / Return (hovedtastatur + typisk numpad i normal mode)
    if [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]]; then
        GAME_KEY=enter
        return 0
    fi
    case $c1 in
        '['|O|$'\t') return 1 ;;
    esac
    if [[ $c1 == ' ' ]]; then
        GAME_KEY=space
        return 0
    fi
    if [[ $c1 < ' ' ]]; then
        return 1
    fi
    GAME_KEY=$c1
    return 0
}

# ------------------------------------------------------------
# Blok-banner (samme stil som FUN / GAMES / BASH SYSTEM)
# Brug: draw_game_banner KEY
# Sætter GAME_CONTENT_TOP
# ------------------------------------------------------------
# 6-trins gradient omkring en spilfarve (lys → mørk)
# Sætter colors[] ud fra spil-nøgle — samme brandfarve som menu-tallet
_game_banner_palette() {
    local key=$1
    case $key in
        BREAKOUT)
            # cyan
            colors=(
                $'\e[38;2;120;235;255m' $'\e[38;2;40;220;255m' $'\e[38;2;0;200;245m'
                $'\e[38;2;0;175;220m' $'\e[38;2;0;150;195m' $'\e[38;2;0;125;170m'
            )
            GAME_BRAND_FG=${FG_GAME_BREAKOUT:-$'\e[38;2;0;210;255m'}
            ;;
        PONG)
            # green
            colors=(
                $'\e[38;2;140;255;170m' $'\e[38;2;90;235;130m' $'\e[38;2;70;220;110m'
                $'\e[38;2;50;190;95m' $'\e[38;2;40;160;80m' $'\e[38;2;30;130;65m'
            )
            GAME_BRAND_FG=${FG_GAME_PONG:-$'\e[38;2;70;220;110m'}
            ;;
        SNAKE)
            # lime
            colors=(
                $'\e[38;2;200;255;120m' $'\e[38;2;175;255;80m' $'\e[38;2;160;255;60m'
                $'\e[38;2;130;220;45m' $'\e[38;2;105;185;35m' $'\e[38;2;80;150;25m'
            )
            GAME_BRAND_FG=${FG_GAME_SNAKE:-$'\e[38;2;160;255;60m'}
            ;;
        TETRIS)
            # blue
            colors=(
                $'\e[38;2;140;185;255m' $'\e[38;2;100;155;255m' $'\e[38;2;70;130;255m'
                $'\e[38;2;55;110;230m' $'\e[38;2;45;90;200m' $'\e[38;2;35;70;170m'
            )
            GAME_BRAND_FG=${FG_GAME_TETRIS:-$'\e[38;2;70;130;255m'}
            ;;
        INVADERS)
            # violet
            colors=(
                $'\e[38;2;210;160;255m' $'\e[38;2;190;120;255m' $'\e[38;2;170;90;255m'
                $'\e[38;2;145;70;230m' $'\e[38;2;120;55;200m' $'\e[38;2;95;40;170m'
            )
            GAME_BRAND_FG=${FG_GAME_INVADERS:-$'\e[38;2;170;90;255m'}
            ;;
        XO|TTT)
            # magenta
            colors=(
                $'\e[38;2;255;150;220m' $'\e[38;2;255;110;210m' $'\e[38;2;255;80;200m'
                $'\e[38;2;230;60;175m' $'\e[38;2;200;45;150m' $'\e[38;2;165;30;125m'
            )
            GAME_BRAND_FG=${FG_GAME_XO:-$'\e[38;2;255;80;200m'}
            ;;
        MINES)
            # teal
            colors=(
                $'\e[38;2;120;235;220m' $'\e[38;2;70;220;200m' $'\e[38;2;40;200;185m'
                $'\e[38;2;30;175;160m' $'\e[38;2;25;150;135m' $'\e[38;2;20;125;110m'
            )
            GAME_BRAND_FG=${FG_GAME_MINES:-$'\e[38;2;40;200;185m'}
            ;;
        BLACKJACK|BJ)
            # wine/rose
            colors=(
                $'\e[38;2;235;140;175m' $'\e[38;2;220;110;155m' $'\e[38;2;200;90;140m'
                $'\e[38;2;175;70;120m' $'\e[38;2;150;55;100m' $'\e[38;2;125;40;80m'
            )
            GAME_BRAND_FG=${FG_GAME_BJ:-$'\e[38;2;200;90;140m'}
            ;;
        *)
            colors=(
                ${FG_YEL1:-$'\e[38;2;255;220;80m'} ${FG_YEL2:-$'\e[38;2;255;190;50m'}
                ${FG_YEL3:-$'\e[38;2;255;160;35m'} ${FG_ORANGE:-$'\e[38;2;255;160;40m'}
                ${FG_ACCENT:-$'\e[38;2;220;140;90m'} ${FG_YEL5:-$'\e[38;2;220;110;20m'}
            )
            GAME_BRAND_FG=${FG_ORANGE:-$'\e[38;2;255;160;40m'}
            ;;
    esac
}

# Tegn ét blok-ord centreret fra række $1
# _draw_game_block_word TOP lines_array_name colors_array_name
_draw_game_block_word() {
    local top=$1
    local -n _glines=$2
    local -n _gcols=$3
    local w left i bw
    w=$(cols)
    bw=${#_glines[0]}
    left=$(( (w - bw) / 2 ))
    (( left < 1 )) && left=1
    for i in "${!_glines[@]}"; do
        goto $((top + i)) "$left"
        printf '%s%s%s%s%s' "$NOBG" "${_gcols[$i]}" "$BOLD" "${_glines[$i]}" "$R"
    done
}

draw_game_banner() {
    local key=${1^^}
    local w left i
    local lines=()
    local lines2=()
    local colors=()
    local colors2=()
    local GAME_BRAND_FG=""
    local dual=0
    w=$(cols)
    _game_banner_palette "$key"

    case $key in
        BREAKOUT)
            lines=(
                '██████╗ ██████╗ ███████╗ █████╗ ██╗  ██╗ ██████╗ ██╗   ██╗████████╗'
                '██╔══██╗██╔══██╗██╔════╝██╔══██╗██║ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝'
                '██████╔╝██████╔╝█████╗  ███████║█████╔╝ ██║   ██║██║   ██║   ██║   '
                '██╔══██╗██╔══██╗██╔══╝  ██╔══██║██╔═██╗ ██║   ██║██║   ██║   ██║   '
                '██████╔╝██║  ██║███████╗██║  ██║██║  ██╗╚██████╔╝╚██████╔╝   ██║   '
                '╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝   '
            )
            ;;
        PONG)
            lines=(
                '██████╗  ██████╗ ███╗   ██╗ ██████╗ '
                '██╔══██╗██╔═══██╗████╗  ██║██╔════╝ '
                '██████╔╝██║   ██║██╔██╗ ██║██║  ███╗'
                '██╔═══╝ ██║   ██║██║╚██╗██║██║   ██║'
                '██║     ╚██████╔╝██║ ╚████║╚██████╔╝'
                '╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ '
            )
            ;;
        SNAKE)
            lines=(
                '███████╗███╗   ██╗ █████╗ ██╗  ██╗███████╗'
                '██╔════╝████╗  ██║██╔══██╗██║ ██╔╝██╔════╝'
                '███████╗██╔██╗ ██║███████║█████╔╝ █████╗  '
                '╚════██║██║╚██╗██║██╔══██║██╔═██╗ ██╔══╝  '
                '███████║██║ ╚████║██║  ██║██║  ██╗███████╗'
                '╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝'
            )
            ;;
        TETRIS)
            lines=(
                '████████╗███████╗████████╗██████╗ ██╗███████╗'
                '╚══██╔══╝██╔════╝╚══██╔══╝██╔══██╗██║██╔════╝'
                '   ██║   █████╗     ██║   ██████╔╝██║███████╗'
                '   ██║   ██╔══╝     ██║   ██╔══██╗██║╚════██║'
                '   ██║   ███████╗   ██║   ██║  ██║██║███████║'
                '   ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝'
            )
            ;;
        INVADERS)
            # Som BASH / SYSTEM: SPACE ovenpå, INVADERS under (fuld 6+6)
            dual=1
            lines=(
                '███████╗██████╗  █████╗  ██████╗███████╗'
                '██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝'
                '███████╗██████╔╝███████║██║     █████╗  '
                '╚════██║██╔═══╝ ██╔══██║██║     ██╔══╝  '
                '███████║██║     ██║  ██║╚██████╗███████╗'
                '╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝'
            )
            lines2=(
                '██╗███╗   ██╗██╗   ██╗ █████╗ ██████╗ ███████╗██████╗ ███████╗'
                '██║████╗  ██║██║   ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝'
                '██║██╔██╗ ██║██║   ██║███████║██║  ██║█████╗  ██████╔╝███████╗'
                '██║██║╚██╗██║╚██╗ ██╔╝██╔══██║██║  ██║██╔══╝  ██╔══██╗╚════██║'
                '██║██║ ╚████║ ╚████╔╝ ██║  ██║██████╔╝███████╗██║  ██║███████║'
                '╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝'
            )
            colors2=("${colors[@]}")
            ;;
        XO|TTT)
            lines=(
                '██╗  ██╗ ██████╗ '
                '╚██╗██╔╝██╔═══██╗'
                ' ╚███╔╝ ██║   ██║'
                ' ██╔██╗ ██║   ██║'
                '██╔╝ ██╗╚██████╔╝'
                '╚═╝  ╚═╝ ╚═════╝ '
            )
            ;;
        MINES)
            lines=(
                '███╗   ███╗██╗███╗   ██╗███████╗███████╗'
                '████╗ ████║██║████╗  ██║██╔════╝██╔════╝'
                '██╔████╔██║██║██╔██╗ ██║█████╗  ███████╗'
                '██║╚██╔╝██║██║██║╚██╗██║██╔══╝  ╚════██║'
                '██║ ╚═╝ ██║██║██║ ╚████║███████╗███████║'
                '╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝'
            )
            ;;
        BLACKJACK|BJ)
            lines=(
                '██████╗      ██╗ █████╗  ██████╗██╗  ██╗'
                '██╔══██╗     ██║██╔══██╗██╔════╝██║ ██╔╝'
                '██████╔╝     ██║███████║██║     █████╔╝ '
                '██╔══██╗██   ██║██╔══██║██║     ██╔═██╗ '
                '██████╔╝╚█████╔╝██║  ██║╚██████╗██║  ██╗'
                '╚═════╝  ╚════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝'
            )
            ;;
        *)
            lines=(
                ' ██████╗  █████╗ ███╗   ███╗███████╗'
                '██╔════╝ ██╔══██╗████╗ ████║██╔════╝'
                '██║  ███╗███████║██╔████╔██║█████╗  '
                '██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  '
                '╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗'
                ' ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝'
            )
            ;;
    esac

    # Hvis banner er for bredt: fald tilbage til teksttitel i brandfarve
    local need_w=${#lines[0]}
    if (( dual )) && (( ${#lines2[0]} > need_w )); then
        need_w=${#lines2[0]}
    fi
    if (( need_w > w - 2 )); then
        local title="SPACE INVADERS"
        [[ $key != INVADERS ]] && title=$key
        left=$(( (w - ${#title}) / 2 ))
        (( left < 1 )) && left=1
        goto 2 "$left"
        printf '%s%s%s%s%s' "$NOBG" "$GAME_BRAND_FG" "$BOLD" "$title" "$R"
        GAME_CONTENT_TOP=4
        return
    fi

    _draw_game_block_word 1 lines colors
    if (( dual )); then
        # Andet ord under første (som BASH / SYSTEM)
        _draw_game_block_word 8 lines2 colors2
        GAME_CONTENT_TOP=15
    else
        GAME_CONTENT_TOP=8
    fi
}

# ------------------------------------------------------------
# Intro-skærm før spil
# Brug: game_intro KEY "Title" "Year" "Creator" "How to play..." "History..." "Controls..."
# Controls: adskil kommandoer med " · " (bevares ved wrap)
# Return: 0 = play, 1 = back
# ------------------------------------------------------------

# Tegn én indholdslinje i boksen: præcis inner bredde (pad/trim)
# _intro_row ROW LEFT INNER "ansi_prefix" "plain_text"
_intro_row() {
    local row=$1 left=$2 inner=$3 prefix=$4 text=$5
    # Trim hvis for lang (plain length)
    if (( ${#text} > inner )); then
        text="${text:0:$((inner - 1))}…"
    fi
    local pad=$((inner - ${#text}))
    (( pad < 0 )) && pad=0
    goto "$row" "$left"
    printf '%s%s│%s%s%s%s%s│%s' \
        "$NOBG" "$FG_WHITE" "$R$NOBG" \
        "$prefix" "$text" "$(repeat ' ' "$pad")" \
        "$FG_WHITE" "$R"
}

# Word-wrap. Hvis teksten indeholder " · ", wraps pr. segment (bevarer adskillelse).
# _intro_wrap_text START_ROW LEFT INNER PREFIX "text" → sætter INTRO_ROW
_intro_wrap_text() {
    local row=$1 left=$2 inner=$3 prefix=$4
    local text=$5
    local parts=() word line=" " sep=" "
    INTRO_ROW=$row

    if [[ $text == *" · "* ]]; then
        # Split på " · " så controls ikke klasker sammen
        local rest=$text
        while [[ $rest == *" · "* ]]; do
            parts+=("${rest%% · *}")
            rest="${rest#* · }"
        done
        parts+=("$rest")
        sep=" · "
    else
        # shellcheck disable=SC2206
        parts=($text)
        sep=" "
    fi

    for word in "${parts[@]}"; do
        # Trim leading space from first segment if present
        word="${word#"${word%%[![:space:]]*}"}"
        [[ -z $word ]] && continue
        if (( ${#line} + ${#sep} + ${#word} > inner )); then
            _intro_row "$INTRO_ROW" "$left" "$inner" "$prefix" "$line"
            ((INTRO_ROW++))
            line=" $word"
        else
            if [[ $line == ' ' ]]; then
                line=" $word"
            else
                line+="${sep}${word}"
            fi
        fi
    done
    _intro_row "$INTRO_ROW" "$left" "$inner" "$prefix" "$line"
    ((INTRO_ROW++))
}

_intro_divider() {
    local row=$1 left=$2 inner=$3
    goto "$row" "$left"
    printf '%s%s├%s┤%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$inner")" "$R"
}

game_intro() {
    local key=$1 title=$2 year=$3 creator=$4 about=$5 history=$6 controls=$7
    local w h left row box_w inner
    _game_log "intro key=$key title=$title"
    # Undgå at menu-uret tegnes ovenpå intro / spil / quit
    if declare -F set_clock_row >/dev/null 2>&1; then
        set_clock_row 0
    else
        CLOCK_ROW=0
    fi
    hide_cursor
    cls
    w=$(cols); h=$(rows)
    draw_game_banner "$key"

    row=$((GAME_CONTENT_TOP + 1))
    box_w=$((w - 8))
    (( box_w > 76 )) && box_w=76
    (( box_w < 44 )) && box_w=44
    left=$(( (w - box_w) / 2 ))
    (( left < 2 )) && left=2
    inner=$((box_w - 2))

    # Top
    goto "$row" "$left"
    printf '%s%s┌%s┐%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$inner")" "$R"
    ((row++))

    # Title
    _intro_row "$row" "$left" "$inner" "$FG_TITLE$BOLD" " $title"
    ((row++))

    # Creator / year
    _intro_wrap_text "$row" "$left" "$inner" "$FG_HINT" " $creator  ·  $year"
    row=$INTRO_ROW

    _intro_divider "$row" "$left" "$inner"
    ((row++))

    # How to play (for sig selv)
    _intro_row "$row" "$left" "$inner" "$FG_CHOICE$BOLD" " How to play"
    ((row++))
    _intro_wrap_text "$row" "$left" "$inner" "$FG_LABEL" " $about"
    row=$INTRO_ROW

    _intro_divider "$row" "$left" "$inner"
    ((row++))

    # History (for sig selv)
    _intro_row "$row" "$left" "$inner" "$FG_CHOICE$BOLD" " History"
    ((row++))
    _intro_wrap_text "$row" "$left" "$inner" "$FG_LABEL" " $history"
    row=$INTRO_ROW

    _intro_divider "$row" "$left" "$inner"
    ((row++))

    # Controls
    _intro_row "$row" "$left" "$inner" "$FG_CHOICE$BOLD" " Controls"
    ((row++))
    _intro_wrap_text "$row" "$left" "$inner" "$FG_BYLINE" " $controls"
    row=$INTRO_ROW

    # Bottom
    goto "$row" "$left"
    printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$inner")" "$R"
    ((row += 2))

    local tip="Enter = play      0 = back to Games"
    local tip_left=$(( (w - ${#tip}) / 2 ))
    (( tip_left < 1 )) && tip_left=1
    goto "$row" "$tip_left"
    printf '%s%s%s%s' "$NOBG" "$FG_ORANGE" "$tip" "$R"

    show_cursor
    local ch
    while true; do
        if IFS= read -r -s -n 1 ch; then
            if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                hide_cursor
                _game_log "intro PLAY $key"
                return 0
            fi
            if [[ $ch == 0 ]]; then
                hide_cursor
                _game_log "intro BACK $key"
                return 1
            fi
        fi
    done
}

# game_result "message" [row]
# Hvis row er sat (>0), tegnes teksten dér (fx under Tetris-brættet).
# Ellers centreret midt på skærmen.
# Under beskeden: centreret "Press Enter to return..." — venter på Enter.
game_result() {
    local msg=$1
    local row=${2:-0}
    local w h left tip tip_row tip_left ch
    _game_log "result: $msg row=$row"
    # Slå menu-uret fra
    if declare -F set_clock_row >/dev/null 2>&1; then
        set_clock_row 0
    else
        CLOCK_ROW=0
    fi
    w=$(cols); h=$(rows)
    if (( row < 1 )); then
        row=$((h / 2 + 2))
    fi
    tip="▶ Press Enter to return..."
    tip_row=$((row + 2))
    # Plads til tip under resultat (ikke nederst til venstre)
    (( row > h - 4 )) && row=$((h - 4))
    (( tip_row > h - 1 )) && tip_row=$((h - 1))

    left=$(( (w - ${#msg}) / 2 ))
    (( left < 1 )) && left=1
    tip_left=$(( (w - ${#tip}) / 2 ))
    (( tip_left < 1 )) && tip_left=1

    goto "$row" "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_TITLE" "$BOLD" "$msg" "$R"
    goto "$tip_row" "$tip_left"
    printf '%s%s%s%s' "$NOBG" "$FG_ORANGE" "$tip" "$R"

    # Vent på Enter (virker både med blocking og non-blocking tty)
    show_cursor
    game_drain 2>/dev/null || true
    while true; do
        if IFS= read -r -s -n 1 -t 0.25 ch; then
            if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                break
            fi
        fi
    done
    hide_cursor
}

