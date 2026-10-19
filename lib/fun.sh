# ============================================================
# lib/fun.sh — Fun-gimmicks + fun_extras()-løkke
# Sources efter lib/tui.sh og lib/menus.sh
# ============================================================

# ======================== FUN GIMMICKS ========================

# --- Inline helpers (Preview-boks under CHOICE) -----------------
# Tegnes først når brugeren vælger en inline-gimmick
show_preview_box() {
    local start=$BOX_START total=$BOX_TOTAL
    local prev_top=$((CHOICE_BOT + 1))
    local ppad=$((total - 2 - 10))  # "─ Preview " ≈ 10
    local r
    (( ppad < 1 )) && ppad=1

    goto "$prev_top" "$start"
    printf '%s%s┌─ %s%sPreview%s %s┐%s' \
        "$NOBG" "$FG_WHITE" \
        "$FG_TITLE" "$BOLD" "$R$NOBG$FG_WHITE" \
        "$(repeat '─' "$ppad")" "$R"

    # 3 indholdslinjer → bedre lodret centrering / mere “rum”
    for r in 1 2 3; do
        goto $((prev_top + r)) "$start"
        printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
        printf '%s%s' "$NOBG" "$(repeat ' ' $((total - 2)))"
        goto $((prev_top + r)) $((start + total - 1))
        printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
    done

    goto $((prev_top + 4)) "$start"
    printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' $((total - 2)))" "$R"

    # Midterste linje = primært indhold; nederste = Enter-hint
    DEMO_ROW=$((prev_top + 2))
    DEMO_ROW2=$((prev_top + 3))
    DEMO_ROW_TOP=$((prev_top + 1))
    # Fuld indre bredde (centrer ift. hele Preview, ikke en indrykket strip)
    DEMO_COL=$((start + 1))
    DEMO_W=$((total - 2))
    (( DEMO_W < 10 )) && DEMO_W=10
}

demo_clear() {
    local row=${1:-$DEMO_ROW}
    (( DEMO_W < 1 )) && return
    goto "$row" "$DEMO_COL"
    printf '%s%s' "$NOBG" "$(repeat ' ' "$DEMO_W")"
}

demo_text() {
    # demo_text [row] "text" [color]  — centreret horisontalt i hele Preview-bredden
    local row=$DEMO_ROW
    local color=$FG_BYLINE
    local msg pad
    if [[ $1 =~ ^[0-9]+$ ]]; then
        row=$1; shift
    fi
    msg=$1
    [[ -n ${2:-} ]] && color=$2
    demo_clear "$row"
    if (( ${#msg} > DEMO_W )); then
        msg="${msg:0:$((DEMO_W - 1))}…"
    fi
    pad=$(( (DEMO_W - ${#msg}) / 2 ))
    (( pad < 0 )) && pad=0
    goto "$row" $((DEMO_COL + pad))
    printf '%s%s%s%s%s' "$NOBG" "$color" "$BOLD" "$msg" "$R"
}

# Centrer tekst + ikon på samme linje.
# text_cols = display-bredde for teksten (fullwidth = 2 pr. tegn)
# icon_cols = hvor mange terminal-celler ikonet fylder
demo_text_icon() {
    local row=$1
    local text=$2
    local icon=$3
    local text_cols=$4
    local icon_cols=$5
    local text_fg=${6:-$FG_SPINNER_TEXT}
    local icon_fg=${7:-$FG_SPINNER_ICON}
    local gap=3
    local total_cols pad
    total_cols=$((text_cols + gap + icon_cols))
    demo_clear "$row"
    if (( total_cols > DEMO_W )); then
        # Fallback: almindelig (ikke-fullwidth) tekst
        demo_text "$row" "${FUN_SPINNER_LOAD}  ${icon}" "$text_fg"
        return
    fi
    pad=$(( (DEMO_W - total_cols) / 2 ))
    (( pad < 0 )) && pad=0
    goto "$row" $((DEMO_COL + pad))
    printf '%s%s%s%s%s  %s%s%s%s' \
        "$NOBG" "$text_fg" "$BOLD" "$text" \
        "$R$NOBG" "$icon_fg" "$BOLD" "$icon" "$R"
}

choice_status() {
    # Skriv status i CHOICE-feltet (efter "CHOICE: ")
    goto "$VALG_ROW" "$VALG_COL"
    printf '%s%s' "$NOBG" "$(repeat ' ' $((BOX_TOTAL - 14)))"
    goto "$VALG_ROW" "$VALG_COL"
    printf '%s%s%s%s' "$NOBG" "$FG_FUN" "$BOLD" "$1"
    printf '%s' "$R"
}

pause_inline() {
    demo_text "$DEMO_ROW2" "▶ Press Enter..." "$FG_ORANGE"
    show_cursor
    NEED_REDRAW=0
    while true; do
        if read -r -t 0.25 _; then
            hide_cursor
            return
        fi
        paint_clock
        if (( NEED_REDRAW )); then
            NEED_REDRAW=0
            hide_cursor
            return
        fi
    done
}

gimmick_title() {
    local title=$1
    cls
    hide_cursor
    local w left
    w=$(cols)
    left=$(( (w - ${#title} - 4) / 2 ))
    (( left < 1 )) && left=1
    goto 2 "$left"
    printf '%s%s%s  %s  %s' "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$title" "$R"
}

# 1) Spinner — INLINE
fun_spinner() {
    hide_cursor
    show_preview_box
    choice_status "Spinner"
    demo_clear "$DEMO_ROW_TOP"
    demo_clear "$DEMO_ROW2"
    # Samme linje: fullwidth-tekst + BRED blok-spinner (fylder flere celler = ser større ud)
    # Enkelt-tegn (⠋/◐) bliver altid “små” i terminalen — derfor en 8-cellers bar i stedet.
    local frames=(
        '██░░░░░░'
        '███░░░░░'
        '░███░░░░'
        '░░███░░░'
        '░░░███░░'
        '░░░░███░'
        '░░░░░███'
        '░░░░███░'
        '░░░███░░'
        '░░███░░░'
        '░███░░░░'
        '███░░░░░'
    )
    local i=0 n=$FUN_SPINNER_FRAMES
    local nframes=${#frames[@]}
    local icon text_cols icon_cols
    text_cols=$(( ${#FUN_SPINNER_LOAD_BIG} * 2 ))
    icon_cols=8
    while (( i < n )); do
        icon="${frames[i % nframes]}"
        demo_text_icon "$DEMO_ROW" "$FUN_SPINNER_LOAD_BIG" "$icon" \
            "$text_cols" "$icon_cols" "$FG_SPINNER_TEXT" "$FG_SPINNER_ICON"
        paint_clock
        sleep_ms "$FUN_SPINNER_DELAY"
        ((i++))
    done
    demo_clear "$DEMO_ROW_TOP"
    demo_clear "$DEMO_ROW2"
    local done_cols=$(( ${#FUN_SPINNER_DONE_BIG} * 2 ))
    local pad=$(( (DEMO_W - done_cols) / 2 ))
    (( pad < 0 )) && pad=0
    demo_clear "$DEMO_ROW"
    goto "$DEMO_ROW" $((DEMO_COL + pad))
    printf '%s%s%s%s%s' "$NOBG" "$FG_SPINNER_TEXT" "$BOLD" "$FUN_SPINNER_DONE_BIG" "$R"
}

# ------------------------------------------------------------
# Fælles gradient-progressbar
#   _progress_paint ROW COL BAR_W PCT R1 G1 B1 R2 G2 B2 [BRIGHT%]
#   Procent er altid hvid. BRIGHT bruges til pulse (100 = normal).
# Gradients pr. sted:
#   Fun      amber → gul
#   Boot     teal → cyan
#   Shutdown mørkerød → lys rød
# ------------------------------------------------------------
_progress_paint() {
    local row=$1 col=$2 bar_w=$3 pct=$4
    local r1=$5 g1=$6 b1=$7 r2=$8 g2=$9 b2=$10
    local bright=${11:-100}
    local filled i t r g b
    filled=$(( pct * bar_w / 100 ))
    (( filled > bar_w )) && filled=$bar_w
    (( filled < 0 )) && filled=0
    goto "$row" "$col"
    printf '%s' "$NOBG"
    for ((i = 0; i < filled; i++)); do
        if (( bar_w <= 1 )); then
            t=0
        else
            t=$(( i * 1000 / (bar_w - 1) ))
        fi
        r=$(( (r1 * (1000 - t) + r2 * t) / 1000 ))
        g=$(( (g1 * (1000 - t) + g2 * t) / 1000 ))
        b=$(( (b1 * (1000 - t) + b2 * t) / 1000 ))
        r=$(( r * bright / 100 )); (( r > 255 )) && r=255
        g=$(( g * bright / 100 )); (( g > 255 )) && g=255
        b=$(( b * bright / 100 )); (( b > 255 )) && b=255
        printf '\e[38;2;%d;%d;%dm█' "$r" "$g" "$b"
    done
    if (( filled < bar_w )); then
        printf '%s%s' "$FG_DIM" "$(repeat '░' $((bar_w - filled)))"
    fi
    printf '%s%s %3d%%%s' "$NOBG" "$FG_WHITE" "$pct" "$R"
}

_progress_pulse() {
    # Blink ved 100% — _progress_pulse ROW COL BAR_W R1 G1 B1 R2 G2 B2
    local row=$1 col=$2 bar_w=$3
    local r1=$4 g1=$5 b1=$6 r2=$7 g2=$8 b2=$9
    local b
    for b in 140 55 155 50 145 100; do
        _progress_paint "$row" "$col" "$bar_w" 100 "$r1" "$g1" "$b1" "$r2" "$g2" "$b2" "$b"
        sleep_ms 0.07
    done
    _progress_paint "$row" "$col" "$bar_w" 100 "$r1" "$g1" "$b1" "$r2" "$g2" "$b2" 100
}

# 2) Progress — INLINE (amber → gul)
fun_progress() {
    hide_cursor
    show_preview_box
    choice_status "Progress bar"
    local bar_w pct pad col
    # Amber → gul
    local r1=255 g1=160 b1=40 r2=255 g2=220 b2=80
    bar_w=$((DEMO_W - 16))
    (( bar_w > 44 )) && bar_w=44
    (( bar_w < 12 )) && bar_w=12
    demo_text "$DEMO_ROW_TOP" "$FUN_PROGRESS_TITLE" "$FG_LABEL"
    pad=$(( (DEMO_W - (bar_w + 5)) / 2 ))
    (( pad < 0 )) && pad=0
    col=$((DEMO_COL + pad))
    for ((pct = 0; pct <= 100; pct += 2)); do
        demo_clear "$DEMO_ROW"
        _progress_paint "$DEMO_ROW" "$col" "$bar_w" "$pct" \
            "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
        paint_clock
        sleep_ms "$(awk -v s="$FUN_PROGRESS_SECONDS" 'BEGIN{printf "%.3f", s/50}')"
    done
    _progress_pulse "$DEMO_ROW" "$col" "$bar_w" "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
}

# Menneskelig typewriter-delay (basis + jitter + pause ved tegnsætning).
# Brug: _typewriter_delay CHAR
_typewriter_delay() {
    local ch=$1
    local d
    d=$(awk -v base="$FUN_TYPEWRITER_DELAY" -v jit="$FUN_TYPEWRITER_JITTER" \
        -v r="$RANDOM" 'BEGIN {
            # r/32767 → 0..1, jitter fra ~0 til jit (lidt ujævn rytme)
            printf "%.4f", base + (r / 32767.0) * jit
        }')
    case $ch in
        [.\!\?])
            d=$(awk -v d="$d" -v p="$FUN_TYPEWRITER_PUNCT" 'BEGIN{printf "%.4f", d + p}')
            ;;
        [,\;:])
            d=$(awk -v d="$d" -v p="$FUN_TYPEWRITER_PUNCT" 'BEGIN{printf "%.4f", d + p * 0.55}')
            ;;
        ' ')
            # Små “tænkepauser” ved mellemrum (~25% chance)
            if (( RANDOM % 4 == 0 )); then
                d=$(awk -v d="$d" 'BEGIN{printf "%.4f", d + 0.06}')
            fi
            ;;
    esac
    sleep_ms "$d"
}

# Typewriter ind i Preview (standard = menneskelig rytme)
# Brug: _typewriter_into_preview "tekst" [farve]
_typewriter_into_preview() {
    local msg=$1
    local color=${2:-$FG_BYLINE}
    local i ch built=""
    if (( ${#msg} > DEMO_W )); then
        msg="${msg:0:$((DEMO_W - 1))}…"
    fi
    for ((i = 0; i < ${#msg}; i++)); do
        ch="${msg:i:1}"
        built+="$ch"
        demo_text "$DEMO_ROW" "$built" "$color"
        _typewriter_delay "$ch"
    done
}

# 3) Typewriter — INLINE
fun_typewriter() {
    hide_cursor
    show_preview_box
    choice_status "Typewriter"
    demo_clear "$DEMO_ROW2"
    _typewriter_into_preview "$FUN_TYPEWRITER_MSG" "$FG_BYLINE"
}

# Matrix-regn (genbrugelig). Brug: _matrix_rain SECONDS COLOR
_matrix_rain() {
    local duration=$1 color=$2
    local w h cols_n c r ch frames i
    w=$(cols); h=$(rows)
    cols_n=$((w - 2))
    (( cols_n < 10 )) && cols_n=10
    frames=$(awk -v d="$duration" 'BEGIN{printf "%d", d / 0.04}')
    (( frames < 20 )) && frames=20
    local drops=()
    for ((c = 0; c < cols_n; c++)); do
        drops[c]=$(( RANDOM % h ))
    done
    for ((i = 0; i < frames; i++)); do
        for ((c = 0; c < cols_n; c+=2)); do
            r=${drops[c]}
            ch=$(printf '\\%03o' $(( 33 + RANDOM % 90 )))
            ch=$(printf '%b' "$ch")
            goto "$r" $((c + 1))
            printf '%s%s%s' "$color" "$ch" "$R"
            drops[c]=$(( (r + 1) % (h - 4) + 2 ))
            goto $(( (r + h - 5) % (h - 4) + 2 )) $((c + 1))
            printf ' '
        done
        sleep_ms 0.04
    done
}

# 4) Matrix — FULLSCREEN (grøn, Fun-gimmick)
fun_matrix() {
    gimmick_title "Matrix rain"
    _matrix_rain "$FUN_MATRIX_SECONDS" "$FUN_MATRIX_COLOR"
}

# 5) Clock — INLINE
fun_clock() {
    hide_cursor
    show_preview_box
    choice_status "Live clock"
    local end now
    end=$((SECONDS + FUN_CLOCK_SECONDS))
    while (( SECONDS < end )); do
        now=$(date '+%H:%M:%S')
        demo_text "$DEMO_ROW" "$now" "$FG_YEL1"
        demo_text "$DEMO_ROW2" "$(date '+%A %d %B %Y')" "$FG_HINT"
        sleep_ms 0.2
    done
}

# 6) Palette — FULLSCREEN
fun_palette() {
    gimmick_title "Color palette"
    local r g b x y
    goto 5 2
    printf '%sTruecolor gradient (R→G→B):%s\n' "$FG_LABEL" "$R"
    for ((y = 0; y < 12; y++)); do
        goto $((6 + y)) 2
        for ((x = 0; x < 60; x++)); do
            r=$(( 255 - x * 4 ))
            g=$(( x * 2 + y * 8 ))
            b=$(( y * 20 ))
            (( r < 0 )) && r=0
            (( g > 255 )) && g=255
            (( b > 255 )) && b=255
            printf '\e[38;2;%d;%d;%dm█' "$r" "$g" "$b"
        done
        printf '%s' "$R"
    done
}

# 7) Rainbow — INLINE
fun_rainbow() {
    hide_cursor
    show_preview_box
    choice_status "Rainbow text"
    demo_clear "$DEMO_ROW2"
    local text="$FUN_RAINBOW_TEXT" i ch n hue r g b
    if (( ${#text} > DEMO_W )); then
        text="${text:0:$((DEMO_W - 1))}…"
    fi
    n=${#text}
    demo_clear "$DEMO_ROW"
    goto "$DEMO_ROW" "$DEMO_COL"
    for ((i = 0; i < n; i++)); do
        ch="${text:i:1}"
        hue=$(( i * 360 / (n > 1 ? n : 1) ))
        local sector=$(( hue / 60 ))
        local f=$(( hue % 60 ))
        local p=80 q t
        q=$(( 255 - f * 175 / 60 ))
        t=$(( 80 + f * 175 / 60 ))
        case $sector in
            0) r=255; g=$t; b=$p ;;
            1) r=$q; g=255; b=$p ;;
            2) r=$p; g=255; b=$t ;;
            3) r=$p; g=$q; b=255 ;;
            4) r=$t; g=$p; b=255 ;;
            *) r=255; g=$p; b=$q ;;
        esac
        printf '\e[38;2;%d;%d;%dm%s%s' "$r" "$g" "$b" "$BOLD" "$ch"
        sleep_ms 0.02
    done
    printf '%s' "$R"
}

# 8) Cowsay — FULLSCREEN
fun_cowsay() {
    gimmick_title "Cowsay"
    local msg="$FUN_COW_MSG" len pad
    len=${#msg}
    pad=$(repeat '─' $((len + 2)))
    goto 5 4
    printf '%s%s┌%s┐%s\n' "$FG_WHITE" "$BOLD" "$pad" "$R"
    goto 6 4
    printf '%s%s│ %s%s%s │%s\n' "$FG_WHITE" "$BOLD" "$FG_BYLINE" "$msg" "$FG_WHITE" "$R"
    goto 7 4
    printf '%s%s└%s┘%s\n' "$FG_WHITE" "$BOLD" "$pad" "$R"
    goto 8 6
    printf '%s%s\\%s\n' "$FG_ORANGE" "$BOLD" "$R"
    goto 9 7
    printf '%s%s\\%s\n' "$FG_ORANGE" "$BOLD" "$R"
    goto 10 4
    cat <<'COW'
        ^__^
        (oo)\_______
        (__)\       )\/\
            ||----w |
            ||     ||
COW
}

# 9) Confetti — FULLSCREEN
fun_confetti() {
    gimmick_title "Confetti"
    local w h end i x y colors chs
    w=$(cols); h=$(rows)
    end=$((SECONDS + FUN_CONFETTI_SECONDS))
    colors=("$FG_RED1" "$FG_YEL1" "$FG_NUM" "$FG_FUN" "$FG_ORANGE" "$FG_BYLINE")
    chs=('*' '+' '·' '✦' 'o' 'x')
    while (( SECONDS < end )); do
        for ((i = 0; i < 25; i++)); do
            x=$(( RANDOM % (w - 1) ))
            y=$(( 4 + RANDOM % (h - 8) ))
            goto "$y" "$x"
            printf '%s%s%s' "${colors[RANDOM % ${#colors[@]}]}" "${chs[RANDOM % ${#chs[@]}]}" "$R"
        done
        sleep_ms 0.08
    done
}

# 10) Fire — FULLSCREEN
fun_fire() {
    gimmick_title "ASCII fire"
    local w h end row col i
    w=$(cols); h=$(rows)
    local fire_h=12
    local fire_w=$((w - 8))
    (( fire_w > 60 )) && fire_w=60
    (( fire_w < 20 )) && fire_w=20
    end=$((SECONDS + FUN_FIRE_SECONDS))
    local -a heatmap
    for ((i = 0; i < fire_w; i++)); do heatmap[i]=0; done

    while (( SECONDS < end )); do
        for ((i = 0; i < fire_w; i++)); do
            heatmap[i]=$(( RANDOM % 8 ))
        done
        for ((row = fire_h - 1; row >= 0; row--)); do
            goto $((5 + row)) 4
            for ((col = 0; col < fire_w; col++)); do
                local v=${heatmap[col]}
                v=$(( v - (fire_h - 1 - row) / 2 ))
                (( v < 0 )) && v=0
                (( v > 7 )) && v=7
                case $v in
                    0) printf ' ' ;;
                    1) printf '%s.%s' "$FG_DIM" "$R" ;;
                    2) printf '%s:%s' "$FG_ACCENT" "$R" ;;
                    3) printf '%s*%s' "$FG_ORANGE" "$R" ;;
                    4) printf '%sx%s' "$FG_YEL3" "$R" ;;
                    5) printf '%sX%s' "$FG_YEL2" "$R" ;;
                    6) printf '%s#%s' "$FG_YEL1" "$R" ;;
                    7) printf '%s@%s' "$FG_WHITE" "$R" ;;
                esac
            done
        done
        for ((i = 0; i < fire_w; i++)); do
            heatmap[i]=$(( (heatmap[i] + RANDOM % 3) % 8 ))
        done
        sleep_ms 0.07
    done
}

# Breakout ligger i games/breakout.sh
breakout_game() {
    if declare -F run_breakout >/dev/null 2>&1; then
        run_breakout
    elif declare -F play_breakout >/dev/null 2>&1; then
        play_breakout "$BREAKOUT_MAIN_SECONDS"
    else
        echo "Breakout not loaded" >&2
    fi
}

# Fun #11 — simpel bouncing sprite (Breakout ligger under Games)
fun_sprite() {
    gimmick_title "Bouncing sprite"
    local w h end x y dx dy frames fi
    w=$(cols); h=$(rows)
    x=4; y=6; dx=1; dy=1
    frames=('◉' '◎' '●' '○')
    fi=0
    end=$((SECONDS + FUN_SPRITE_SECONDS))
    while (( SECONDS < end )); do
        goto "$y" "$x"
        printf '%s%s%s%s' "$FG_NUM" "$BOLD" "${frames[fi % 4]}" "$R"
        sleep_ms 0.06
        goto "$y" "$x"
        printf ' '
        ((x += dx)); ((y += dy)); ((fi++))
        (( x <= 2 || x >= w - 3 )) && dx=$(( -dx ))
        (( y <= 5 || y >= h - 5 )) && dy=$(( -dy ))
    done
}

# 12) Banner — FULLSCREEN
fun_big_banner() {
    gimmick_title "Big word banner"
    local word="${FUN_BANNER_WORD^^}"
    if [[ $word == INROPA ]]; then
        local lines=(
            '██╗ ███╗   ██╗██████╗  ██████╗ ██████╗  █████╗ '
            '██║ ████╗  ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗'
            '██║ ██╔██╗ ██║██████╔╝██║   ██║██████╔╝███████║'
            '██║ ██║╚██╗██║██╔══██╗██║   ██║██╔═══╝ ██╔══██║'
            '██║ ██║ ╚████║██║  ██║╚██████╔╝██║     ██║  ██║'
            '╚═╝ ╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝'
        )
        local i fg=("$FG_FUN" "$FG_NUM" "$FG_YEL1" "$FG_ORANGE" "$FG_RED1" "$FG_RED3")
        local w left
        w=$(cols)
        for i in "${!lines[@]}"; do
            left=$(( (w - ${#lines[i]}) / 2 ))
            (( left < 1 )) && left=1
            goto $((6 + i)) "$left"
            printf '%s%s%s%s' "${fg[i]}" "$BOLD" "${lines[i]}" "$R"
        done
    else
        goto 8 4
        printf '%s%s%s%s' "$FG_BYLINE" "$BOLD" "$word" "$R"
    fi
}

# 13) Boot — FULLSCREEN
fun_boot() {
    gimmick_title "$FUN_BOOT_TITLE"
    local steps=(
        "Initializing kernel modules..."
        "Mounting virtual filesystems..."
        "Starting network stack..."
        "Loading ${COMPANY} services..."
        "Checking coffee levels... OK"
        "Starting BASH SYSTEM UI..."
        "Ready."
    )
    local i frames=('|' '/' '-' '\\') s f=0
    for i in "${!steps[@]}"; do
        s=${steps[i]}
        goto $((6 + i)) 4
        printf '%s[%s*%s] %s%s' "$FG_DIM" "$FG_YEL1" "$FG_DIM" "$FG_LABEL" "$s"
        local j
        for ((j = 0; j < 8; j++)); do
            goto $((6 + i)) $(( 8 + ${#s} ))
            printf ' %s%s%s' "$FG_NUM" "${frames[f % 4]}" "$R"
            ((f++))
            sleep_ms 0.05
        done
        goto $((6 + i)) $(( 8 + ${#s} ))
        printf ' %s%sok%s' "$FG_YEL1" "$BOLD" "$R"
    done
}

# 14) Mario — INLINE: Super Mario Bros overworld (Mindstorms-stil)
# SSH: Cursor-bell (\a) pr. tone. Samtidig wav til VM-lydkort.
fun_beep() {
    hide_cursor
    show_preview_box
    choice_status "Mario"
    demo_clear "$DEMO_ROW2"

    local wav="/tmp/menu-mario-$$.wav"
    local notes="/tmp/menu-mario-$$.notes"
    local note="" play_pid=0

    # Python skriver både wav + notes-fil (label|freq|ms). Tempo ~langsommere end før.
    _beep_make_mario() {
        python3 - "$1" "$2" <<'PY' 2>/dev/null
import sys, wave, math, struct
wav_path, notes_path = sys.argv[1], sys.argv[2]

# Tempo: tæt på den genkendelige intro (~140), lidt roligere — ikke for langsom
E = 155   # eighth
Q = 310   # quarter
H = 465   # longer rest / phrase end

# (label, freq_hz, ms) — freq 0 = pause
# SMB1 overworld: intro + 1. vers (to fraser), Mindstorms playTone-stil
melody = [
    # Intro: E E - E - C E - G -- G -
    ("E5", 659, E), ("E5", 659, E), ("·", 0, E), ("E5", 659, E), ("·", 0, E),
    ("C5", 523, E), ("E5", 659, E), ("·", 0, E), ("G5", 784, Q), ("·", 0, Q),
    ("G4", 392, E), ("·", 0, Q),
    # Vers A
    ("C5", 523, E), ("·", 0, Q), ("G4", 392, E), ("·", 0, Q), ("E4", 330, E), ("·", 0, Q),
    ("A4", 440, E), ("·", 0, E), ("B4", 494, E), ("·", 0, E), ("Bb4", 466, E), ("A4", 440, E), ("·", 0, E),
    ("G4", 392, E), ("E5", 659, E), ("G5", 784, E), ("A5", 880, Q),
    ("F5", 698, E), ("G5", 784, E), ("·", 0, E), ("E5", 659, E), ("·", 0, E),
    ("C5", 523, E), ("D5", 587, E), ("B4", 494, E), ("·", 0, Q),
    # Vers A (gentagelse / 2. frase)
    ("C5", 523, E), ("·", 0, Q), ("G4", 392, E), ("·", 0, Q), ("E4", 330, E), ("·", 0, Q),
    ("A4", 440, E), ("·", 0, E), ("B4", 494, E), ("·", 0, E), ("Bb4", 466, E), ("A4", 440, E), ("·", 0, E),
    ("G4", 392, E), ("E5", 659, E), ("G5", 784, E), ("A5", 880, Q),
    ("F5", 698, E), ("G5", 784, E), ("·", 0, E), ("E5", 659, E), ("·", 0, E),
    ("C5", 523, E), ("D5", 587, E), ("B4", 494, E), ("·", 0, H),
]

fr = 22050
frames = bytearray()
with open(notes_path, "w", encoding="utf-8") as nf:
    for label, freq, ms in melody:
        nf.write(f"{label}|{freq}|{ms}\n")
        n = int(fr * (ms / 1000.0))
        for i in range(n):
            if freq <= 0:
                v = 0
            else:
                env = 1.0
                fade = min(120, max(1, n // 5))
                if i < fade:
                    env = i / fade
                elif i > n - fade:
                    env = max(0.0, (n - i) / fade)
                v = int(11000 * env * math.sin(2 * math.pi * freq * i / fr))
            frames += struct.pack("<h", v)

with wave.open(wav_path, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(fr)
    w.writeframes(frames)
PY
    }

    _beep_play_wav() {
        [[ -f $1 ]] || return 1
        if command -v pw-play >/dev/null 2>&1; then
            pw-play "$1" >/dev/null 2>&1 && return 0
        fi
        if command -v paplay >/dev/null 2>&1; then
            paplay "$1" >/dev/null 2>&1 && return 0
        fi
        if command -v aplay >/dev/null 2>&1; then
            aplay -q "$1" >/dev/null 2>&1 && return 0
        fi
        return 1
    }

    demo_text "$DEMO_ROW" "Mario overworld…" "$FG_ORANGE"
    demo_text "$DEMO_ROW2" "Overworld  ·  Mid-tempo  ·  ~15s" "$FG_HINT"
    sleep_ms 0.3

    if ! _beep_make_mario "$wav" "$notes"; then
        demo_text "$DEMO_ROW" "Could not build melody (python3?)" "$FG_EXIT"
        return
    fi

    _beep_play_wav "$wav" &
    play_pid=$!

    local label freq ms sec n=0 total
    total=$(wc -l < "$notes" 2>/dev/null | tr -d ' ')
    while IFS='|' read -r label freq ms; do
        ((n++))
        demo_text "$DEMO_ROW" "♪  $label  ♪" "$FG_YEL1"
        demo_text "$DEMO_ROW2" "note $n / $total" "$FG_DIM"
        if (( freq > 0 )); then
            printf '\a'
            if (( freq >= 700 )); then
                sleep_ms 0.05
                printf '\a'
            fi
        fi
        sec=$(awk -v ms="$ms" 'BEGIN{printf "%.3f", ms/1000}')
        sleep_ms "$sec"
    done < "$notes"

    wait "$play_pid" 2>/dev/null || true
    rm -f "$wav" "$notes" 2>/dev/null

    demo_text "$DEMO_ROW" "It's-a me!" "$FG_YEL1"
    demo_text "$DEMO_ROW2" "Mario overworld — bell rhythm + VM wav" "$FG_HINT"
}



fun_extras() {
    MENU_MODE=fun
    while true; do
        show_fun_menu
        wait_for_choice
        case "$CHOICE_VALUE" in
            # Inline (under CHOICE / Preview)
            1)  fun_spinner; pause_inline; continue ;;
            2)  fun_progress; pause_inline; continue ;;
            3)  fun_typewriter; pause_inline; continue ;;
            5)  fun_clock; pause_inline; continue ;;
            7)  fun_rainbow; pause_inline; continue ;;
            14) fun_beep; pause_inline; continue ;;
            # Fullscreen (egen plads)
            4)  fun_matrix; pause ;;
            6)  fun_palette; pause ;;
            8)  fun_cowsay; pause ;;
            9)  fun_confetti; pause ;;
            10) fun_fire; pause ;;
            11) fun_sprite; pause ;;
            12) fun_big_banner; pause ;;
            13) fun_boot; pause ;;
            0)
                MENU_MODE=main
                return
                ;;
            +)
                quit_program
                ;;
            '!!')
                quit_fast
                ;;
            *)
                cls
                goto $(( $(rows) / 2 )) 4
                printf '%s%s%s  Invalid choice: %s  %s' "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$CHOICE_VALUE" "$R"
                sleep 1.0
                ;;
        esac
    done
}

