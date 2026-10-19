#!/bin/bash
# ============================================================
# games/breakout.sh – Breakout
# Sourced fra menu.sh (kræver games/common.sh for banner/intro)
# Debug: BREAKOUT_DEBUG (default 0 – slået fra)
# ============================================================

: "${BREAKOUT_MAIN_SECONDS:=0}"
: "${BREAKOUT_PADDLE_STEP:=5}"
: "${BREAKOUT_DEBUG:=0}"
: "${BREAKOUT_LOG:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/breakout.debug.log}"

# ============================================================
# Breakout — styrebar mini-udgave (A/D eller ←/→, Q = quit)
# Brug: play_breakout [SECONDS]
#   SECONDS > 0  → tidsbegrænset (Fun-demo)
#   SECONDS = 0  → spil til win / game over / Q (hovedmenu)
#
# Debug (bash “logging” i stedet for C#-exceptions):
#   BREAKOUT_DEBUG=1  → append til breakout.debug.log
#   Se log:  tail -f breakout.debug.log
# ============================================================

# Skriv én loglinje (no-op hvis BREAKOUT_DEBUG=0)
_breakout_log() {
    (( BREAKOUT_DEBUG )) || return 0
    printf '%s | %s\n' "$(date '+%H:%M:%S')" "$*" >> "$BREAKOUT_LOG"
}

# Sikker buffer-flush. VIGTIGT: brug ALDRIG read -t 0 med -icanon —
# det kan hænge for evigt (det var frysningen ved miss).
_breakout_drain_input() {
    local _c n=0
    while (( n < 40 )) && IFS= read -r -s -n 1 -t 0.001 _c; do
        ((n++))
    done
    (( BREAKOUT_DEBUG && n > 0 )) && _breakout_log "drain_input flushed=$n"
}

play_breakout() {
    local time_limit=${1:-0}
    local old_stty=""
    # Gem tty-indstillinger og slå echo fra — ellers vises ^[[D/^[[C fra piletaster
    # min 0 time 0 = non-blocking read (nødvendigt for sikker drain)
    if [[ -t 0 ]]; then
        old_stty=$(stty -g 2>/dev/null || true)
        stty -echo -icanon min 0 time 0 2>/dev/null || stty -echo -icanon 2>/dev/null || true
    fi
    # Sørg for at stty genskabes ved return/exit fra spillet
    _breakout_restore_tty() {
        if [[ -n $old_stty ]]; then
            stty "$old_stty" 2>/dev/null || stty echo icanon 2>/dev/null || true
        fi
        _breakout_log "tty restored"
    }

    if (( BREAKOUT_DEBUG )); then
        {
            echo "========== Breakout start $(date '+%Y-%m-%d %H:%M:%S') =========="
            echo "time_limit=$time_limit  cols=$(cols) rows=$(rows)  paddle_step=$BREAKOUT_PADDLE_STEP"
        } >> "$BREAKOUT_LOG"
    fi

    hide_cursor
    cls
    local w h top bottom left right
    w=$(cols); h=$(rows)
    # Samme blok-banner-stil som hovedmenu / Games
    # HUD: score under banner, controls under score, luft, derefter mursten
    local hud_row ctrl_row
    if declare -F draw_game_banner >/dev/null 2>&1; then
        draw_game_banner BREAKOUT
        hud_row=$GAME_CONTENT_TOP
        ctrl_row=$((GAME_CONTENT_TOP + 1))
        top=$((GAME_CONTENT_TOP + 2))          # loft for bolden
    else
        hud_row=3
        ctrl_row=4
        top=5
        goto 1 $(( (w - 8) / 2 ))
        printf '%s%s%sBREAKOUT%s' "$NOBG" "$FG_ORANGE" "$BOLD" "$R"
    fi
    bottom=$((h - 3))
    left=2
    right=$((w - 3))
    local brick_rows=4
    local brick_top=$((top + 2))              # ekstra luft mellem forklaring og bokse
    _breakout_log "field top=$top brick_top=$brick_top bottom=$bottom left=$left right=$right"
    if (( right - left < 30 || bottom - brick_top < 12 )); then
        goto 5 4
        printf '%s%sTerminal for lille til Breakout (prøv større vindue).%s' \
            "$FG_EXIT" "$BOLD" "$R"
        sleep 1.5
        _breakout_restore_tty
        return
    fi

    _breakout_drain_input

    local pad_w=7
    local pad_x=$(( (left + right - pad_w) / 2 ))
    local ball_x=$((pad_x + pad_w / 2))
    local ball_y=$((bottom - 2))
    local dx=1 dy=-1
    local lives=3 score=0 bricks_left=0 quit=0
    local timed=0 end=0
    if (( time_limit > 0 )); then
        timed=1
        end=$((SECONDS + time_limit))
    fi
    local ch esc key
    local bx r c idx
    local -a brick
    local -a brick_fg=("$FG_RED1" "$FG_ORANGE" "$FG_YEL2" "$FG_NUM")

    for ((r = 0; r < brick_rows; r++)); do
        for ((c = left + 1; c <= right - 2; c += 2)); do
            idx=$((r * 200 + c))
            brick[$idx]=1
            ((bricks_left++))
            goto $((brick_top + r)) "$c"
            printf '%s%s██%s' "${brick_fg[r]}" "$BOLD" "$R"
        done
    done

    _breakout_draw_paddle() {
        goto "$bottom" "$left"
        printf '%s%s' "$NOBG" "$(repeat ' ' $((right - left + 1)))"
        goto "$bottom" "$pad_x"
        printf '%s%s%s%s' "$FG_TITLE" "$BOLD" "$(repeat '█' "$pad_w")" "$R"
    }

    _breakout_reset_ball() {
        # Læg bolden midt over paddlen igen
        ball_x=$((pad_x + pad_w / 2))
        (( ball_x < left )) && ball_x=$left
        (( ball_x > right )) && ball_x=$right
        ball_y=$((bottom - 2))
        dx=1
        dy=-1
    }

    _breakout_erase_ball() {
        # Undgå at slette paddle/mursten når bolden står på dem
        if (( ball_y >= bottom )); then
            return
        fi
        if (( ball_y >= brick_top && ball_y < brick_top + brick_rows )); then
            local er=$((ball_y - brick_top))
            local ec=$(( left + 1 + ((ball_x - left - 1) / 2) * 2 ))
            local eidx=$((er * 200 + ec))
            if [[ ${brick[$eidx]:-0} == 1 ]]; then
                return
            fi
        fi
        goto "$ball_y" "$ball_x"
        printf '%s %s' "$NOBG" "$R"
    }

    _breakout_hud() {
        local score_txt ctrl_txt score_left ctrl_left
        local time_plain=""
        if (( timed )); then
            local left_s=$(( end - SECONDS ))
            (( left_s < 0 )) && left_s=0
            time_plain=$(printf '    TIME %-3d' "$left_s")
        fi
        score_txt="SCORE $score    LIVES $lives$time_plain"
        ctrl_txt="A/D or arrows · Q quit"
        score_left=$(( (w - ${#score_txt}) / 2 ))
        ctrl_left=$(( (w - ${#ctrl_txt}) / 2 ))
        (( score_left < 1 )) && score_left=1
        (( ctrl_left < 1 )) && ctrl_left=1
        # Ryd HUD-linjer (fjerner gamle cifre / escape-rester)
        goto "$hud_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$ctrl_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$hud_row" "$score_left"
        printf '%s%sSCORE %s%-4d%s    %sLIVES %s%d%s' \
            "$NOBG" "$FG_HINT" "$FG_YEL1" "$score" "$R$NOBG" \
            "$FG_HINT" "$FG_EXIT" "$lives" "$R"
        if (( timed )); then
            local left_s2=$(( end - SECONDS ))
            (( left_s2 < 0 )) && left_s2=0
            printf '%s%s    TIME %s%-3d%s' \
                "$NOBG" "$FG_HINT" "$FG_NUM" "$left_s2" "$R"
        fi
        goto "$ctrl_row" "$ctrl_left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl_txt" "$R"
    }

    # Læs én handling: a/d/q (pile oversættes). Returnerer via BREAKOUT_KEY.
    _breakout_read_key() {
        BREAKOUT_KEY=""
        local c1="" c2="" c3=""
        # -t 0.01: kort poll så bolden bliver ved med at bevæge sig
        if ! IFS= read -r -s -n 1 -t 0.01 c1; then
            return 1
        fi
        # Piletaster: ESC [ C/D  (eller ESC O C/D på nogle terminaler)
        if [[ $c1 == $'\e' ]]; then
            IFS= read -r -s -n 1 -t 0.03 c2 || true
            if [[ $c2 == '[' || $c2 == O ]]; then
                IFS= read -r -s -n 1 -t 0.03 c3 || true
                case $c3 in
                    D) BREAKOUT_KEY=a; return 0 ;;
                    C) BREAKOUT_KEY=d; return 0 ;;
                esac
            fi
            # Ukendt escape — ignorer (printes aldrig)
            return 1
        fi
        # Ignorer CSI-fragmenter / kontroltegn der ellers kan “lække”
        case $c1 in
            '['|O|$'\n'|$'\r'|$'\t') return 1 ;;
        esac
        if [[ $c1 < ' ' ]]; then
            return 1
        fi
        BREAKOUT_KEY=$c1
        return 0
    }

    _breakout_draw_paddle
    _breakout_hud

    while (( lives > 0 && bricks_left > 0 )); do
        if (( timed && SECONDS >= end )); then
            break
        fi

        # Max få paddle-træk pr. frame — ellers kan key-repeat “æde” bold-ticks
        local moves=0
        while (( moves < 3 )) && _breakout_read_key; do
            ((moves++))
            case $BREAKOUT_KEY in
                a|A|h|H)
                    ((pad_x -= BREAKOUT_PADDLE_STEP))
                    (( pad_x < left )) && pad_x=$left
                    ;;
                d|D|l|L)
                    ((pad_x += BREAKOUT_PADDLE_STEP))
                    (( pad_x + pad_w - 1 > right )) && pad_x=$((right - pad_w + 1))
                    ;;
                q|Q)
                    quit=1
                    break
                    ;;
            esac
        done
        (( quit )) && break

        _breakout_erase_ball

        ((ball_x += dx))
        ((ball_y += dy))

        if (( ball_x <= left )); then ball_x=$left; dx=1; fi
        if (( ball_x >= right )); then ball_x=$right; dx=-1; fi
        if (( ball_y <= top )); then ball_y=$top; dy=1; fi

        if (( ball_y >= brick_top && ball_y < brick_top + brick_rows )); then
            r=$((ball_y - brick_top))
            for bx in "$ball_x" $((ball_x - 1)); do
                (( bx < left || bx > right )) && continue
                c=$(( left + 1 + ((bx - left - 1) / 2) * 2 ))
                idx=$((r * 200 + c))
                if [[ ${brick[$idx]:-0} == 1 ]]; then
                    brick[$idx]=0
                    ((bricks_left--))
                    ((score += 10))
                    goto $((brick_top + r)) "$c"
                    printf '%s  %s' "$NOBG" "$R"
                    dy=$(( -dy ))
                    # Skub bolden ud af murstens-rækken så den ikke “fastlåses”
                    if (( dy < 0 )); then
                        ball_y=$((brick_top - 1))
                    else
                        ball_y=$((brick_top + brick_rows))
                    fi
                    _breakout_hud
                    break
                fi
            done
        fi

        if (( ball_y >= bottom )); then
            if (( ball_x >= pad_x && ball_x < pad_x + pad_w )); then
                _breakout_log "HIT  ball=($ball_x,$ball_y) pad_x=$pad_x"
                ball_y=$((bottom - 1))
                dy=-1
                if (( ball_x < pad_x + pad_w / 3 )); then
                    dx=-1
                elif (( ball_x > pad_x + (pad_w * 2) / 3 )); then
                    dx=1
                fi
            else
                # MISS — her frøs spillet før pga. read -t 0
                _breakout_log "MISS ball=($ball_x,$ball_y) pad_x=$pad_x pad_w=$pad_w lives_before=$lives"
                ((lives--))
                _breakout_log "MISS lives_after=$lives → reset ball"
                _breakout_hud
                _breakout_reset_ball
                _breakout_draw_paddle
                goto "$ball_y" "$ball_x"
                printf '%s%s●%s' "$FG_WHITE" "$BOLD" "$R"
                sleep_ms 0.35
                _breakout_drain_input
                _breakout_log "MISS resume ball=($ball_x,$ball_y)"
                continue
            fi
        fi

        # Sikkerhedsnet: bold uden for banen → reset
        if (( ball_y < top || ball_y > bottom || ball_x < left || ball_x > right )); then
            _breakout_log "OOB ball=($ball_x,$ball_y) → reset"
            _breakout_reset_ball
        fi

        _breakout_draw_paddle
        goto "$ball_y" "$ball_x"
        printf '%s%s●%s' "$FG_WHITE" "$BOLD" "$R"
        (( timed )) && _breakout_hud

        sleep_ms 0.045
    done

    local msg
    if (( quit )); then
        msg="QUIT  ·  score ${score}"
    elif (( bricks_left <= 0 )); then
        msg="YOU WIN  ·  score ${score}"
    elif (( lives <= 0 )); then
        msg="GAME OVER  ·  score ${score}"
    elif (( timed )); then
        msg="TIME UP  ·  score ${score}"
    else
        msg="DONE  ·  score ${score}"
    fi
    _breakout_log "END reason='$msg' score=$score lives=$lives bricks_left=$bricks_left quit=$quit"
    if declare -F game_result >/dev/null 2>&1; then
        game_result "$msg"
    else
        goto $(( (top + bottom) / 2 )) $(( (w - ${#msg}) / 2 ))
        printf '%s%s%s%s%s' "$NOBG" "$FG_TITLE" "$BOLD" "$msg" "$R"
        sleep 1.4
    fi
    _breakout_drain_input
    _breakout_restore_tty
}

# Intro + play (kaldes fra Games-menu)
run_breakout() {
    if declare -F game_intro >/dev/null 2>&1; then
        if game_intro BREAKOUT "Breakout" "1976" "Atari · Wozniak / Bushnell / Bristow" \
            "Keep the ball in play and smash every brick with the paddle. Clear the wall to win — miss the ball and you lose a life." \
            "Origin: Atari wanted a single-player follow-up to Pong; Steve Bristow sketched the brick-wall idea. First digital: Breakout (1976) — Wozniak (with Jobs) built a famous prototype; the arcade release defined the brick-breaker genre." \
            "A/D or arrows = move paddle  ·  Q = quit"
        then
            play_breakout "${BREAKOUT_MAIN_SECONDS:-0}"
        fi
    else
        play_breakout "${BREAKOUT_MAIN_SECONDS:-0}"
    fi
}
