#!/bin/bash
# ============================================================
# games/snake.sh
# Sourced fra menu.sh (kræver games/common.sh)
# ============================================================

# ============================================================
# SNAKE
# ============================================================
play_snake() {
    game_tty_setup
    _game_log_start SNAKE
    cls
    local w h top bottom left right
    w=$(cols); h=$(rows)
    draw_game_banner SNAKE
    # HUD: score under banner, controls under score, luft til spillfelt
    local hud_row=$GAME_CONTENT_TOP
    local ctrl_row=$((GAME_CONTENT_TOP + 1))
    top=$((GAME_CONTENT_TOP + 3))
    bottom=$((h - 2))
    left=2
    right=$((w - 3))
    if (( bottom - top < 8 || right - left < 20 )); then
        game_result "Terminal too small"
        game_tty_restore
        return
    fi

    local -a sx sy
    local n=3 i
    local hx=$(( (left + right) / 2 ))
    local hy=$(( (top + bottom) / 2 ))
    for ((i = 0; i < n; i++)); do
        sx[i]=$((hx - i))
        sy[i]=$hy
    done
    local dx=1 dy=0
    local fx fy score=0 quit=0 dead=0
    local grow=0

    _snake_place_food() {
        local ok=0 j
        while (( ! ok )); do
            fx=$(( left + 1 + RANDOM % (right - left - 1) ))
            fy=$(( top + 1 + RANDOM % (bottom - top - 1) ))
            ok=1
            for ((j = 0; j < n; j++)); do
                if (( sx[j] == fx && sy[j] == fy )); then ok=0; break; fi
            done
        done
        goto "$fy" "$fx"
        printf '%s%s●%s' "$FG_EXIT" "$BOLD" "$R"
    }

    _snake_hud() {
        local score_txt="SCORE $score"
        local ctrl_txt="WASD/arrows · Q quit"
        local score_left=$(( (w - ${#score_txt}) / 2 ))
        local ctrl_left=$(( (w - ${#ctrl_txt}) / 2 ))
        (( score_left < 1 )) && score_left=1
        (( ctrl_left < 1 )) && ctrl_left=1
        goto "$hud_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$hud_row" "$score_left"
        printf '%s%sSCORE %s%-4d%s' \
            "$NOBG" "$FG_HINT" "$FG_YEL1" "$score" "$R"
        goto "$ctrl_row" "$ctrl_left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl_txt" "$R"
    }

    _snake_draw_border() {
        local y
        local inner=$((right - left - 1))
        (( inner < 1 )) && inner=1
        goto "$top" "$left"
        printf '%s%s┌%s┐%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$inner")" "$R"
        for ((y = top + 1; y < bottom; y++)); do
            goto "$y" "$left"
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
            goto "$y" "$right"
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
        done
        goto "$bottom" "$left"
        printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$inner")" "$R"
    }

    _snake_draw_border
    # tegn start
    for ((i = 0; i < n; i++)); do
        goto "${sy[i]}" "${sx[i]}"
        printf '%s%s█%s' "$FG_NUM" "$BOLD" "$R"
    done
    _snake_place_food
    _snake_hud
    game_drain

    while (( ! quit && ! dead )); do
        while game_read_key; do
            case $GAME_KEY in
                w|W) (( dy != 1 )) && { dx=0; dy=-1; } ;;
                s|S) (( dy != -1 )) && { dx=0; dy=1; } ;;
                a|A) (( dx != 1 )) && { dx=-1; dy=0; } ;;
                d|D) (( dx != -1 )) && { dx=1; dy=0; } ;;
                q|Q) quit=1; break ;;
            esac
        done
        (( quit )) && break

        local nx=$((sx[0] + dx))
        local ny=$((sy[0] + dy))

        # Wrap rundt om kanten (klassisk Snake) — dør kun ved kollision med dig selv
        if (( nx <= left )); then nx=$((right - 1)); fi
        if (( nx >= right )); then nx=$((left + 1)); fi
        if (( ny <= top )); then ny=$((bottom - 1)); fi
        if (( ny >= bottom )); then ny=$((top + 1)); fi

        for ((i = 0; i < n; i++)); do
            if (( sx[i] == nx && sy[i] == ny )); then dead=1; break; fi
        done
        (( dead )) && break

        if (( nx == fx && ny == fy )); then
            ((score += 10))
            grow=1
            _snake_hud
        fi

        if (( ! grow )); then
            goto "${sy[n-1]}" "${sx[n-1]}"
            printf '%s %s' "$NOBG" "$R"
        else
            ((n++))
            grow=0
            _snake_place_food
        fi

        for ((i = n - 1; i > 0; i--)); do
            sx[i]=${sx[i-1]}
            sy[i]=${sy[i-1]}
        done
        sx[0]=$nx; sy[0]=$ny

        goto "$ny" "$nx"
        printf '%s%s█%s' "$FG_NUM" "$BOLD" "$R"

        sleep_ms 0.09
    done

    if (( quit )); then
        game_result "QUIT  ·  score $score"
    else
        game_result "GAME OVER  ·  score $score"
    fi
    game_tty_restore
}


run_snake() {
    if game_intro SNAKE "Snake" "Arcade 1976 · Nokia 1998" "Blockade lineage · Nokia popularized" \
        "Steer the snake, eat the red dots, and avoid your own tail. Edges wrap to the opposite side — classic Snake rules." \
        "Origin: grow-and-survive “light cycle” / trail games of the mid-1970s. First digital wave: arcade titles like Blockade (1976) and clones. Mass culture: Nokia’s Snake (1998) on mobile phones made the idea a worldwide classic." \
        "WASD or arrows = steer  ·  Edges wrap  ·  Q = quit"
    then
        play_snake
    fi
}

