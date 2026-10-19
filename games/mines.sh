#!/bin/bash
# ============================================================
# games/mines.sh
# Sourced fra menu.sh (kræver games/common.sh)
# ============================================================

# ============================================================
# MINESWEEPER (mini 8x8)
# ============================================================
play_mines() {
    game_tty_setup
    _game_log_start MINES
    cls
    local w h
    w=$(cols); h=$(rows)
    draw_game_banner MINES
    local top=$GAME_CONTENT_TOP
    local gw=8 gh=8 mines=10
    local -a mine revealed flagged
    local i x y
    for ((i = 0; i < gw * gh; i++)); do
        mine[i]=0; revealed[i]=0; flagged[i]=0
    done
    local n=0 idx
    while (( n < mines )); do
        idx=$((RANDOM % (gw * gh)))
        if (( ! mine[idx] )); then mine[idx]=1; ((n++)); fi
    done

    local cx=0 cy=0 quit=0 dead=0 won=0
    local left=$(( w / 2 - gw - 2 ))

    _mines_count() {
        local x=$1 y=$2 c=0 dx dy nx ny
        for dx in -1 0 1; do
            for dy in -1 0 1; do
                (( dx == 0 && dy == 0 )) && continue
                nx=$((x + dx)); ny=$((y + dy))
                (( nx < 0 || ny < 0 || nx >= gw || ny >= gh )) && continue
                (( mine[ny * gw + nx] )) && ((c++))
            done
        done
        printf '%s' "$c"
    }

    # Reveal med flood-fill når feltet er 0
    _mines_reveal() {
        local x=$1 y=$2
        local i cnt dx dy
        (( x < 0 || y < 0 || x >= gw || y >= gh )) && return
        i=$((y * gw + x))
        (( revealed[i] || flagged[i] )) && return
        revealed[i]=1
        if (( mine[i] )); then dead=1; return; fi
        cnt=$(_mines_count "$x" "$y")
        if (( cnt == 0 )); then
            for dx in -1 0 1; do
                for dy in -1 0 1; do
                    (( dx == 0 && dy == 0 )) && continue
                    _mines_reveal $((x + dx)) $((y + dy))
                done
            done
        fi
    }

    _mines_draw() {
        local yy xx i ch cnt
        goto $((top - 1)) "$left"
        printf '%s%sArrows move · Enter/Space open · F flag · Q%s' "$FG_DIM" "$BOLD" "$R"
        for ((yy = 0; yy < gh; yy++)); do
            goto $((top + 1 + yy)) "$left"
            for ((xx = 0; xx < gw; xx++)); do
                i=$((yy * gw + xx))
                if (( flagged[i] && ! revealed[i] )); then ch='F'
                elif (( ! revealed[i] )); then ch='■'
                elif (( mine[i] )); then ch='*'
                else
                    cnt=$(_mines_count "$xx" "$yy")
                    if (( cnt == 0 )); then ch=' '
                    else ch=$cnt
                    fi
                fi
                if (( xx == cx && yy == cy )); then
                    printf '%s%s[%s]%s' "$FG_TITLE" "$BOLD" "$ch" "$R"
                else
                    printf ' %s%s%s ' "$FG_LABEL" "$ch" "$R"
                fi
            done
        done
    }

    _mines_draw
    game_drain

    while (( ! quit && ! dead && ! won )); do
        if game_read_key; then
            case $GAME_KEY in
                a|A) ((cx > 0)) && ((cx--)) ;;
                d|D) ((cx < gw - 1)) && ((cx++)) ;;
                w|W) ((cy > 0)) && ((cy--)) ;;
                s|S) ((cy < gh - 1)) && ((cy++)) ;;
                f|F)
                    i=$((cy * gw + cx))
                    (( ! revealed[i] )) && flagged[i]=$((1 - flagged[i]))
                    ;;
                enter|space)
                    i=$((cy * gw + cx))
                    (( flagged[i] )) || _mines_reveal "$cx" "$cy"
                    ;;
                q|Q) quit=1; break ;;
            esac
            # win?
            won=1
            for ((i = 0; i < gw * gh; i++)); do
                if (( ! mine[i] && ! revealed[i] )); then won=0; break; fi
            done
            _mines_draw
        else
            sleep_ms 0.05
        fi
    done

    if (( quit )); then game_result "QUIT"
    elif (( dead )); then game_result "BOOM  ·  GAME OVER"
    else game_result "YOU WIN  ·  cleared"
    fi
    game_tty_restore
}


run_mines() {
    if game_intro MINES "Minesweeper" "Windows 1990 · earlier PC mines" "Microsoft · Relentless Logic / Mined-Out roots" \
        "Open safe cells and avoid mines. Numbers show how many mines touch a cell. Flag suspects with F." \
        "Origin: logic / minefield puzzles inspired by clearing a grid without stepping on bombs. Early digital: Mined-Out (1983, ZX Spectrum) and Relentless Logic (DOS, ~1985). Famous digital: Windows Minesweeper (1990, Donner & Johnson) made the genre a PC classic worldwide." \
        "Arrows = move  ·  Enter/Return/Space = open  ·  F = flag  ·  Q = quit"
    then
        play_mines
    fi
}

