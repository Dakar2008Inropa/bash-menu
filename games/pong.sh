#!/bin/bash
# ============================================================
# games/pong.sh
# Sourced fra menu.sh (kræver games/common.sh)
# ============================================================

# ============================================================
# PONG — 1 spiller vs CPU
# ============================================================
play_pong() {
    game_tty_setup
    _game_log_start PONG
    cls
    local w h top bottom left right
    w=$(cols); h=$(rows)
    draw_game_banner PONG
    # HUD: score under banner, controls under score, playfield under det
    local hud_row=$GAME_CONTENT_TOP
    local ctrl_row=$((GAME_CONTENT_TOP + 1))
    top=$((GAME_CONTENT_TOP + 2))
    bottom=$((h - 2))
    left=2
    right=$((w - 3))
    if (( bottom - top < 10 || right - left < 40 )); then
        game_result "Terminal too small"
        game_tty_restore
        return
    fi

    local py=$(( (top + bottom) / 2 ))   # player paddle y (right)
    local cy=$py                         # cpu paddle y (left)
    local bx=$(( (left + right) / 2 ))
    local by=$py
    local dx=1 dy=1
    local ps=3                           # paddle half-height
    local score_p=0 score_c=0
    local win=5 quit=0
    local cpu_tick=0                     # throttle CPU so it is beatable

    _pong_draw_pads() {
        local y
        for ((y = top; y <= bottom; y++)); do
            goto "$y" "$left"
            printf '%s %s' "$NOBG" "$R"
            goto "$y" "$right"
            printf '%s %s' "$NOBG" "$R"
        done
        for ((y = cy - ps; y <= cy + ps; y++)); do
            (( y < top || y > bottom )) && continue
            goto "$y" "$left"
            printf '%s%s█%s' "$FG_EXIT" "$BOLD" "$R"
        done
        for ((y = py - ps; y <= py + ps; y++)); do
            (( y < top || y > bottom )) && continue
            goto "$y" "$right"
            printf '%s%s█%s' "$FG_NUM" "$BOLD" "$R"
        done
    }

    _pong_hud() {
        local score_txt="CPU $score_c    YOU $score_p"
        local ctrl_txt="W/S or arrows · Q quit"
        local score_left=$(( (w - ${#score_txt}) / 2 ))
        local ctrl_left=$(( (w - ${#ctrl_txt}) / 2 ))
        (( score_left < 1 )) && score_left=1
        (( ctrl_left < 1 )) && ctrl_left=1
        goto "$hud_row" "$score_left"
        printf '%s%sCPU %s%d%s    %sYOU %s%d%s' \
            "$NOBG" "$FG_HINT" "$FG_EXIT" "$score_c" "$R$NOBG" \
            "$FG_HINT" "$FG_NUM" "$score_p" "$R"
        goto "$ctrl_row" "$ctrl_left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl_txt" "$R"
    }

    _pong_hud
    _pong_draw_pads
    game_drain

    while (( score_p < win && score_c < win && ! quit )); do
        while game_read_key; do
            case $GAME_KEY in
                w|W|a|A) ((py -= 2)); (( py - ps < top )) && py=$((top + ps)) ;;
                s|S|d|D) ((py += 2)); (( py + ps > bottom )) && py=$((bottom - ps)) ;;
                q|Q) quit=1; break ;;
            esac
        done
        (( quit )) && break

        goto "$by" "$bx"
        printf '%s %s' "$NOBG" "$R"

        ((bx += dx)); ((by += dy))

        # CPU AI: langsommere end bolden + større deadzone → spilleren kan score.
        ((cpu_tick++))
        if (( dx < 0 && cpu_tick % 3 == 0 )); then
            if (( by < cy - 2 )); then ((cy--)); fi
            if (( by > cy + 2 )); then ((cy++)); fi
        fi
        (( cy - ps < top )) && cy=$((top + ps))
        (( cy + ps > bottom )) && cy=$((bottom - ps))

        if (( by <= top )); then by=$top; dy=1; fi
        if (( by >= bottom )); then by=$bottom; dy=-1; fi

        if (( bx <= left + 1 )); then
            if (( by >= cy - ps && by <= cy + ps )); then
                bx=$((left + 2)); dx=1
            else
                ((score_p++))
                bx=$(( (left + right) / 2 )); by=$py; dx=1
                _pong_hud
                sleep_ms 0.25
            fi
        fi
        if (( bx >= right - 1 )); then
            if (( by >= py - ps && by <= py + ps )); then
                bx=$((right - 2)); dx=-1
            else
                ((score_c++))
                bx=$(( (left + right) / 2 )); by=$py; dx=-1
                _pong_hud
                sleep_ms 0.25
            fi
        fi

        _pong_draw_pads
        goto "$by" "$bx"
        printf '%s%s●%s' "$FG_WHITE" "$BOLD" "$R"
        sleep_ms 0.04
    done

    if (( quit )); then
        game_result "QUIT  ·  You $score_p – CPU $score_c"
    elif (( score_p >= win )); then
        game_result "YOU WIN  ·  $score_p – $score_c"
    else
        game_result "CPU WINS  ·  $score_p – $score_c"
    fi
    game_tty_restore
}


run_pong() {
    if game_intro PONG "Pong" "1972" "Atari · Nolan Bushnell & Allan Alcorn" \
        "Two paddles, one ball — digital table tennis. You play the right paddle against the CPU. First to 5 points wins." \
        "Origin: inspired by table tennis and earlier electronic experiments (including Tennis for Two, 1958). First digital hit: Atari’s Pong arcade (1972), engineered by Allan Alcorn — the breakthrough cabinet that helped launch the video-game industry." \
        "W/S or arrows = move  ·  First to 5  ·  Q = quit"
    then
        play_pong
    fi
}

