#!/bin/bash
# ============================================================
# games/ttt.sh — Tic-Tac-Toe
# ============================================================

play_ttt() {
    game_tty_setup
    _game_log_start TTT
    cls
    local w h
    w=$(cols); h=$(rows)
    draw_game_banner XO

    # HUD under banner (centreret), bræt under
    local hud_row=$GAME_CONTENT_TOP
    local ctrl_row=$((GAME_CONTENT_TOP + 1))
    local top=$((GAME_CONTENT_TOP + 3))
    local quit=0
    local you_wins=0 cpu_wins=0 draws=0
    local left=$(( w / 2 - 6 ))

    # Farver: spiller (X) cyan, CPU (O) orange/rød
    local COL_YOU=${FG_NUM:-$'\e[38;2;80;220;235m'}
    local COL_CPU=${FG_ORANGE:-$'\e[38;2;255;160;40m'}

    local -a b
    local turn winner cursor

    _ttt_hud() {
        # Ét scoreboard: farve + bogstav + wins (ingen ekstra legend under bræt)
        local score_txt="YOU(X) $you_wins    CPU(O) $cpu_wins    DRAWS $draws"
        local ctrl_txt="Arrows move · Enter/Space place · Q quit"
        local score_left=$(( (w - ${#score_txt}) / 2 ))
        local ctrl_left=$(( (w - ${#ctrl_txt}) / 2 ))
        (( score_left < 1 )) && score_left=1
        (( ctrl_left < 1 )) && ctrl_left=1
        goto "$hud_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$hud_row" "$score_left"
        printf '%s%sYOU(%sX%s)%s %s%d%s    %sCPU(%sO%s)%s %s%d%s    %sDRAWS %s%d%s' \
            "$NOBG" "$FG_HINT" \
            "$COL_YOU$BOLD" "$R$NOBG$FG_HINT" "$R$NOBG" \
            "$COL_YOU" "$you_wins" "$R$NOBG" \
            "$FG_HINT" \
            "$COL_CPU$BOLD" "$R$NOBG$FG_HINT" "$R$NOBG" \
            "$COL_CPU" "$cpu_wins" "$R$NOBG" \
            "$FG_HINT" "$FG_DIM" "$draws" "$R"
        goto "$ctrl_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$ctrl_row" "$ctrl_left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl_txt" "$R"
    }

    _ttt_cell_color() {
        case $1 in
            X) printf '%s' "$COL_YOU" ;;
            O) printf '%s' "$COL_CPU" ;;
            *) printf '%s' "$FG_LABEL" ;;
        esac
    }

    _ttt_draw() {
        local r c i ch col
        for ((r = 0; r < 3; r++)); do
            goto $((top + 1 + r * 2)) "$left"
            for ((c = 0; c < 3; c++)); do
                i=$((r * 3 + c))
                ch=${b[i]}
                [[ $ch == . ]] && ch=' '
                col=$(_ttt_cell_color "${b[i]}")
                if (( i == cursor )); then
                    printf '%s%s[%s%s%s%s]%s' \
                        "$FG_TITLE" "$BOLD" \
                        "$col" "$BOLD" "$ch" "$R$NOBG" \
                        "$R"
                else
                    printf '%s %s%s%s%s %s' \
                        "$NOBG" "$col" "$BOLD" "$ch" "$R$NOBG" "$R"
                fi
                (( c < 2 )) && printf '%s│%s' "$FG_HINT" "$R"
            done
            if (( r < 2 )); then
                goto $((top + 2 + r * 2)) "$left"
                printf '%s───┼───┼───%s' "$FG_HINT" "$R"
            fi
        done
    }

    _ttt_winner() {
        local lines=('0 1 2' '3 4 5' '6 7 8' '0 3 6' '1 4 7' '2 5 8' '0 4 8' '2 4 6')
        local L a b1 c1
        winner=""
        for L in "${lines[@]}"; do
            # shellcheck disable=SC2086
            set -- $L
            a=${b[$1]}; b1=${b[$2]}; c1=${b[$3]}
            if [[ $a != . && $a == "$b1" && $a == "$c1" ]]; then
                winner=$a
                return 0
            fi
        done
        local i full=1
        for ((i = 0; i < 9; i++)); do
            [[ ${b[i]} == . ]] && full=0
        done
        (( full )) && winner=draw
        [[ -n $winner ]]
    }

    _ttt_cpu() {
        local i opts=() empty=0
        for i in 0 1 2 3 4 5 6 7 8; do
            [[ ${b[i]} == . ]] && ((empty++))
        done
        # Første træk (tomt bræt): tilfældigt felt — ikke altid midten
        if (( empty == 9 )); then
            b[$((RANDOM % 9))]=O
            return
        fi
        for i in 0 1 2 3 4 5 6 7 8; do
            [[ ${b[i]} == . ]] || continue
            b[i]=O
            if _ttt_winner && [[ $winner == O ]]; then winner=""; return; fi
            b[i]=.
            winner=""
        done
        for i in 0 1 2 3 4 5 6 7 8; do
            [[ ${b[i]} == . ]] || continue
            b[i]=X
            if _ttt_winner && [[ $winner == X ]]; then
                b[i]=O; winner=""; return
            fi
            b[i]=.
            winner=""
        done
        # Senere træk: midten ok som fallback, ellers random
        if [[ ${b[4]} == . ]] && (( RANDOM % 2 == 0 )); then
            b[4]=O
            return
        fi
        for i in 0 1 2 3 4 5 6 7 8; do
            [[ ${b[i]} == . ]] && opts+=("$i")
        done
        (( ${#opts[@]} )) && b[${opts[RANDOM % ${#opts[@]}]}]=O
    }

    _ttt_new_round() {
        b=(. . . . . . . . .)
        winner=""
        cursor=4
        # Tilfældig start: spiller (X) eller CPU (O)
        if (( RANDOM % 2 == 0 )); then
            turn=X
        else
            turn=O
        fi
    }

    _ttt_hud
    _ttt_new_round
    _ttt_draw
    game_drain
    show_cursor

    while (( ! quit )); do
        while (( ! quit )) && [[ -z $winner ]]; do
            if [[ $turn == X ]]; then
                if game_read_key; then
                    case $GAME_KEY in
                        a|A) ((cursor % 3 > 0)) && ((cursor--)) ;;
                        d|D) ((cursor % 3 < 2)) && ((cursor++)) ;;
                        w|W) ((cursor >= 3)) && ((cursor -= 3)) ;;
                        s|S) ((cursor <= 5)) && ((cursor += 3)) ;;
                        enter|space)
                            if [[ ${b[cursor]} == . ]]; then
                                b[cursor]=X
                                turn=O
                            fi
                            ;;
                        q|Q) quit=1; break ;;
                    esac
                    _ttt_draw
                else
                    sleep_ms 0.05
                fi
            else
                sleep_ms 0.35
                _ttt_cpu
                turn=X
                _ttt_draw
            fi
            _ttt_winner || true
        done
        (( quit )) && break

        if [[ $winner == X ]]; then ((you_wins++))
        elif [[ $winner == O ]]; then ((cpu_wins++))
        else ((draws++)); fi
        _ttt_hud

        # Kort pause, så næste runde
        sleep_ms 0.9
        _ttt_new_round
        # Ryd bræt-område
        local y
        for ((y = top; y <= top + 7; y++)); do
            goto "$y" $((left - 2))
            printf '%s%s' "$NOBG" "$(repeat ' ' 28)"
        done
        _ttt_draw
    done

    hide_cursor
    if (( you_wins > cpu_wins )); then
        game_result "YOU WIN  ·  $you_wins–$cpu_wins"
    elif (( cpu_wins > you_wins )); then
        game_result "CPU WINS  ·  $you_wins–$cpu_wins"
    else
        game_result "DRAW  ·  $you_wins–$cpu_wins"
    fi
    game_tty_restore
}


run_ttt() {
    if game_intro XO "Tic-Tac-Toe" "Folk tradition / digital 1952" "Noughts and Crosses · A.S. Douglas (OXO)" \
        "Get three in a row. You are X (cyan); the CPU is O (orange). Play multiple rounds — score stays until you quit." \
        "Origin: a folk pencil-and-paper game (noughts and crosses) played for centuries across cultures. First digital: OXO (1952) by A.S. Douglas on Cambridge’s EDSAC — one of the earliest computer games, shown on a CRT with moves entered on a rotary dial." \
        "Arrows = move  ·  Enter/Return/Space = place  ·  Q = quit"
    then
        play_ttt
    fi
}
