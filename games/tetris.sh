#!/bin/bash
# ============================================================
# games/tetris.sh
# Sourced fra menu.sh (kræver games/common.sh)
# ============================================================

# ============================================================
# TETRIS (mini)
# ============================================================
play_tetris() {
    game_tty_setup
    _game_log_start TETRIS
    cls
    local w h
    w=$(cols); h=$(rows)
    draw_game_banner TETRIS
    # HUD: score-linje + controls-linje, derefter bræt
    local hud_row=$GAME_CONTENT_TOP
    local ctrl_row=$((GAME_CONTENT_TOP + 1))
    local top=$((GAME_CONTENT_TOP + 2))   # board top
    local gh=16 gw=10
    local board_left=$(( (w - (gw * 2 + 4)) / 2 ))
    (( board_left < 2 )) && board_left=2
    # Plads til bræt + bundkant + resultat-linje under brættet
    if (( top + gh + 3 > h - 1 )); then gh=$((h - top - 4)); fi
    (( gh < 10 )) && { game_result "Terminal too small"; game_tty_restore; return; }
    local result_row=$((top + gh + 2))

    local -a cell
    local x y i score=0 lines_cleared=0 quit=0
    for ((y = 0; y < gh; y++)); do
        for ((x = 0; x < gw; x++)); do
            cell[$((y * gw + x))]=0
        done
    done

    # 7 pieces as 4 cells offsets (rotations simplified: 4 states hardcoded per type)
    local px py ptype prot
    local -a shapes

    _tetris_set_shape() {
        # fylder shapes[0..3] med "dx,dy" for current ptype/prot
        local t=$ptype r=$prot
        case $t in
            0) # I
                case $r in
                    0|2) shapes=('0,1' '1,1' '2,1' '3,1') ;;
                    *)   shapes=('1,0' '1,1' '1,2' '1,3') ;;
                esac ;;
            1) # O
                shapes=('1,0' '2,0' '1,1' '2,1') ;;
            2) # T
                case $r in
                    0) shapes=('1,0' '0,1' '1,1' '2,1') ;;
                    1) shapes=('1,0' '1,1' '2,1' '1,2') ;;
                    2) shapes=('0,1' '1,1' '2,1' '1,2') ;;
                    *) shapes=('1,0' '0,1' '1,1' '1,2') ;;
                esac ;;
            3) # L
                case $r in
                    0) shapes=('2,0' '0,1' '1,1' '2,1') ;;
                    1) shapes=('1,0' '1,1' '1,2' '2,2') ;;
                    2) shapes=('0,1' '1,1' '2,1' '0,2') ;;
                    *) shapes=('0,0' '1,0' '1,1' '1,2') ;;
                esac ;;
            4) # J
                case $r in
                    0) shapes=('0,0' '0,1' '1,1' '2,1') ;;
                    1) shapes=('1,0' '2,0' '1,1' '1,2') ;;
                    2) shapes=('0,1' '1,1' '2,1' '2,2') ;;
                    *) shapes=('1,0' '1,1' '0,2' '1,2') ;;
                esac ;;
            5) # S
                case $r in
                    0|2) shapes=('1,0' '2,0' '0,1' '1,1') ;;
                    *)   shapes=('1,0' '1,1' '2,1' '2,2') ;;
                esac ;;
            *) # Z
                case $r in
                    0|2) shapes=('0,0' '1,0' '1,1' '2,1') ;;
                    *)   shapes=('2,0' '1,1' '2,1' '1,2') ;;
                esac ;;
        esac
    }

    _tetris_fits() {
        local ox=$1 oy=$2 or=$3
        local save_r=$prot s
        prot=$or
        _tetris_set_shape
        for s in "${shapes[@]}"; do
            local dx=${s%%,*} dy=${s##*,}
            local tx=$((ox + dx)) ty=$((oy + dy))
            if (( tx < 0 || tx >= gw || ty >= gh )); then
                prot=$save_r; return 1
            fi
            if (( ty >= 0 )) && (( cell[ty * gw + tx] )); then
                prot=$save_r; return 1
            fi
        done
        prot=$save_r
        return 0
    }

    _tetris_draw_board() {
        local yy xx v
        for ((yy = 0; yy < gh; yy++)); do
            goto $((top + yy)) "$board_left"
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
            for ((xx = 0; xx < gw; xx++)); do
                v=${cell[yy * gw + xx]}
                if (( v )); then
                    printf '%s%s██%s' "$FG_ORANGE" "$BOLD" "$R"
                else
                    printf '%s  %s' "$NOBG" "$R"
                fi
            done
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
        done
        goto $((top + gh)) "$board_left"
        printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' $((gw * 2)))" "$R"
    }

    _tetris_draw_piece() {
        local mode=$1 s dx dy tx ty
        _tetris_set_shape
        for s in "${shapes[@]}"; do
            dx=${s%%,*}; dy=${s##*,}
            tx=$((px + dx)); ty=$((py + dy))
            (( ty < 0 || ty >= gh || tx < 0 || tx >= gw )) && continue
            goto $((top + ty)) $((board_left + 1 + tx * 2))
            if [[ $mode == draw ]]; then
                printf '%s%s██%s' "$FG_NUM" "$BOLD" "$R"
            else
                printf '%s  %s' "$NOBG" "$R"
            fi
        done
    }

    _tetris_lock() {
        local s dx dy tx ty
        _tetris_set_shape
        for s in "${shapes[@]}"; do
            dx=${s%%,*}; dy=${s##*,}
            tx=$((px + dx)); ty=$((py + dy))
            (( ty < 0 )) && continue
            cell[$((ty * gw + tx))]=1
        done
    }

    _tetris_clear_lines() {
        local yy xx full ny
        for ((yy = gh - 1; yy >= 0; yy--)); do
            full=1
            for ((xx = 0; xx < gw; xx++)); do
                (( cell[yy * gw + xx] )) || { full=0; break; }
            done
            if (( full )); then
                ((lines_cleared++)); ((score += 100))
                for ((ny = yy; ny > 0; ny--)); do
                    for ((xx = 0; xx < gw; xx++)); do
                        cell[$((ny * gw + xx))]=${cell[$(((ny - 1) * gw + xx))]}
                    done
                done
                for ((xx = 0; xx < gw; xx++)); do cell[$xx]=0; done
                ((yy++))
            fi
        done
    }

    _tetris_spawn() {
        ptype=$((RANDOM % 7))
        prot=0
        px=3; py=-1
        if ! _tetris_fits "$px" "$py" "$prot"; then
            return 1
        fi
        return 0
    }

    _tetris_hud() {
        goto "$hud_row" "$board_left"
        printf '%s%sSCORE %s%-4d%s    LINES %s%-3d%s' \
            "$NOBG" "$FG_HINT" "$FG_YEL1" "$score" "$R$NOBG$FG_HINT" \
            "$FG_NUM" "$lines_cleared" "$R"
        goto "$ctrl_row" "$board_left"
        printf '%s%sA/D move · W rotate · S drop · Q quit%s' \
            "$NOBG" "$FG_DIM" "$R"
    }

    _tetris_draw_board
    _tetris_hud
    _tetris_spawn || { game_result "GAME OVER" "$result_row"; game_tty_restore; return; }
    _tetris_draw_piece draw
    game_drain

    local tick=0
    while (( ! quit )); do
        while game_read_key; do
            case $GAME_KEY in
                a|A)
                    _tetris_draw_piece erase
                    if _tetris_fits $((px - 1)) "$py" "$prot"; then ((px--)); fi
                    _tetris_draw_piece draw
                    ;;
                d|D)
                    _tetris_draw_piece erase
                    if _tetris_fits $((px + 1)) "$py" "$prot"; then ((px++)); fi
                    _tetris_draw_piece draw
                    ;;
                w|W)
                    _tetris_draw_piece erase
                    if _tetris_fits "$px" "$py" $(( (prot + 1) % 4 )); then
                        prot=$(( (prot + 1) % 4 ))
                    fi
                    _tetris_draw_piece draw
                    ;;
                s|S)
                    _tetris_draw_piece erase
                    if _tetris_fits "$px" $((py + 1)) "$prot"; then
                        ((py++))
                    fi
                    _tetris_draw_piece draw
                    ;;
                q|Q) quit=1; break ;;
            esac
        done
        (( quit )) && break

        ((tick++))
        if (( tick % 8 == 0 )); then
            _tetris_draw_piece erase
            if _tetris_fits "$px" $((py + 1)) "$prot"; then
                ((py++))
                _tetris_draw_piece draw
            else
                _tetris_draw_piece draw
                _tetris_lock
                _tetris_clear_lines
                _tetris_draw_board
                _tetris_hud
                if ! _tetris_spawn; then
                    game_result "GAME OVER  ·  score $score" "$result_row"
                    game_tty_restore
                    return
                fi
                _tetris_draw_piece draw
            fi
        fi
        sleep_ms 0.05
    done
    game_result "QUIT  ·  score $score" "$result_row"
    game_tty_restore
}


run_tetris() {
    if game_intro TETRIS "Tetris" "1984" "Alexey Pajitnov" \
        "Stack falling tetrominoes and clear full lines. Fill a row to score; the pile rises until there is no room left." \
        "Origin: Pajitnov loved pentomino / geometric puzzles and designed falling tetrominoes for a computer. First digital: Tetris (1984) on an Electronika 60 in Moscow — born digital, then a worldwide hit especially after the Game Boy release." \
        "A/D = move  ·  W = rotate  ·  S = soft drop  ·  Q = quit"
    then
        play_tetris
    fi
}

