#!/bin/bash
# ============================================================
# games/invaders.sh
# Uendelige levels · layouts · powerups (+/-) · fjendeskud · highscore
# ============================================================

# Highscore-fil: games/invaders.scores (ved siden af spillet)

# Farver til powerup-bogstaver (god / dårlig)
_inv_pup_color() {
    case $1 in
        F) printf '%s' "${FG_ORANGE:-$'\e[38;2;255;160;40m'}" ;;
        W) printf '%s' "${FG_NUM:-$'\e[38;2;80;220;235m'}" ;;
        S) printf '%s' "${FG_GAME_SNAKE:-$'\e[38;2;160;255;60m'}" ;;
        M) printf '%s' "${FG_FUN:-$'\e[38;2;180;130;255m'}" ;;
        P) printf '%s' "${FG_YEL1:-$'\e[38;2;255;220;80m'}" ;;
        D) printf '%s' "${FG_RED1:-$'\e[38;2;255;90;90m'}" ;;
        N) printf '%s' "${FG_RED2:-$'\e[38;2;235;60;60m'}" ;;
        Z) printf '%s' "${FG_EXIT:-$'\e[38;2;255;120;110m'}" ;;
        V) printf '%s' "${FG_RED3:-$'\e[38;2;210;45;50m'}" ;;
        *) printf '%s' "${FG_WHITE:-$'\e[38;2;240;240;240m'}" ;;
    esac
}

# Én powerup-linje med farvet bogstav
_inv_intro_pup_row() {
    local row=$1 left=$2 inner=$3 letter=$4 desc=$5
    local col pad plain
    col=$(_inv_pup_color "$letter")
    plain=" $letter  $desc"
    if (( ${#plain} > inner )); then
        desc="${desc:0:$((inner - 4))}…"
        plain=" $letter  $desc"
    fi
    pad=$((inner - ${#plain}))
    (( pad < 0 )) && pad=0
    goto "$row" "$left"
    printf '%s%s│%s %s%s%s%s  %s%s%s%s│%s' \
        "$NOBG" "$FG_WHITE" "$R$NOBG" \
        "$col" "$BOLD" "$letter" "$R$NOBG" \
        "$FG_LABEL" "$desc" "$(repeat ' ' "$pad")" \
        "$FG_WHITE" "$R"
}

# Fælles ramme: banner + tip + box start. Sætter INV_LEFT / INV_INNER / INV_ROW
_inv_page_begin() {
    local tip tip_left
    if declare -F set_clock_row >/dev/null 2>&1; then
        set_clock_row 0
    else
        CLOCK_ROW=0
    fi
    hide_cursor
    cls
    INV_W=$(cols); INV_H=$(rows)
    draw_game_banner INVADERS

    tip=${1:-"Enter = play      0 = back"}
    tip_left=$(( (INV_W - ${#tip}) / 2 ))
    (( tip_left < 1 )) && tip_left=1
    goto "$GAME_CONTENT_TOP" "$tip_left"
    printf '%s%s%s%s' "$NOBG" "$FG_ORANGE" "$tip" "$R"

    INV_BOX_W=$((INV_W - 6))
    (( INV_BOX_W > 72 )) && INV_BOX_W=72
    (( INV_BOX_W < 44 )) && INV_BOX_W=44
    INV_LEFT=$(( (INV_W - INV_BOX_W) / 2 ))
    (( INV_LEFT < 2 )) && INV_LEFT=2
    INV_INNER=$((INV_BOX_W - 2))
    INV_ROW=$((GAME_CONTENT_TOP + 2))

    goto "$INV_ROW" "$INV_LEFT"
    printf '%s%s┌%s┐%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$INV_INNER")" "$R"
    ((INV_ROW++))
}

_inv_page_end_box() {
    goto "$INV_ROW" "$INV_LEFT"
    printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' "$INV_INNER")" "$R"
}

# Vent på Enter (ok) / 0 (back). Return 0 / 1
_inv_wait_enter_or_0() {
    local ch
    show_cursor
    while true; do
        if IFS= read -r -s -n 1 ch; then
            if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                hide_cursor; return 0
            fi
            if [[ $ch == 0 ]]; then
                hide_cursor; return 1
            fi
        fi
    done
}

# Undersider — 0 = tilbage til invaders-menu
_inv_page_howto() {
    _inv_page_begin "0 = back to Space Invaders menu"
    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_TITLE$BOLD" " How to play"
    ((INV_ROW++))
    _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))
    _intro_wrap_text "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_LABEL" \
        " Endless levels with changing alien layouts. Clear every alien to advance."
    INV_ROW=$INTRO_ROW
    _intro_wrap_text "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_LABEL" \
        " From level 3 the aliens shoot back — dodge their red shots. You have 3 lives."
    INV_ROW=$INTRO_ROW
    _intro_wrap_text "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_LABEL" \
        " Powerups fall when aliens die: catch them with your ship or shoot them. Green/bright = good, red = bad."
    INV_ROW=$INTRO_ROW
    _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))
    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_CHOICE$BOLD" " Controls"
    ((INV_ROW++))
    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_BYLINE" " A/D = move  ·  SPACE = shoot  ·  Q = quit"
    ((INV_ROW++))
    _inv_page_end_box
    _inv_wait_enter_or_0
    return 0
}

_inv_page_powerups() {
    _inv_page_begin "0 = back to Space Invaders menu"
    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_TITLE$BOLD" " Powerups"
    ((INV_ROW++))
    _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))

    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_CHOICE$BOLD" " Good  (catch or shoot)"
    ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "F" "Faster fire rate"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "W" "Wider laser beam"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "S" "Move faster"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "M" "More shots at once"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "P" "Bonus points"; ((INV_ROW++))
    _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))

    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_EXIT$BOLD" " Bad  (avoid these!)"
    ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "D" "Slower fire (delay)"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "N" "Narrower laser"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "Z" "Slower movement"; ((INV_ROW++))
    _inv_intro_pup_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "V" "Virus — lose points"; ((INV_ROW++))
    _inv_page_end_box
    _inv_wait_enter_or_0
    return 0
}

_inv_page_highscores() {
    _inv_page_begin "0 = back to Space Invaders menu"
    _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_TITLE$BOLD" " High scores"
    ((INV_ROW++))
    _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))
    if declare -F hs_draw_table >/dev/null 2>&1; then
        hs_draw_table "$INV_ROW" "$INV_LEFT" "$INV_INNER" invaders 10
        INV_ROW=$INTRO_ROW
    else
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_DIM" " (no scores yet)"; ((INV_ROW++))
    fi
    _inv_page_end_box
    _inv_wait_enter_or_0
    return 0
}

# ------------------------------------------------------------
# Hovedmenu: kun historie + kreditering + menupunkter
# Return: 0 = play, 1 = back to Games
# ------------------------------------------------------------
invaders_intro() {
    local ch
    while true; do
        _inv_page_begin "Enter = play      0 = back to Games"

        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_TITLE$BOLD" " Space Invaders"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_HINT" " Taito · Tomohiro Nishikado  ·  1978"
        ((INV_ROW++))
        _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))

        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_CHOICE$BOLD" " History"
        ((INV_ROW++))
        _intro_wrap_text "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_LABEL" \
            " Origin: Nishikado blended sci-fi invaders with shooting-gallery ideas and earlier Taito electromechanical games."
        INV_ROW=$INTRO_ROW
        _intro_wrap_text "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_LABEL" \
            " First digital: Space Invaders (Taito, 1978) — the arcade hit that defined the shoot-’em-up and sparked the golden age of video arcades."
        INV_ROW=$INTRO_ROW
        _intro_divider "$INV_ROW" "$INV_LEFT" "$INV_INNER"; ((INV_ROW++))

        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_CHOICE$BOLD" " Menu"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_NUM" " [1]  How to play"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_NUM" " [2]  Powerups"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_NUM" " [3]  High scores"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_DIM" " Enter = start game"
        ((INV_ROW++))
        _intro_row "$INV_ROW" "$INV_LEFT" "$INV_INNER" "$FG_DIM" " 0 = back to Games"
        ((INV_ROW++))

        _inv_page_end_box

        show_cursor
        while true; do
            if IFS= read -r -s -n 1 ch; then
                hide_cursor
                case $ch in
                    ""|$'\n'|$'\r') return 0 ;;
                    0) return 1 ;;
                    1) _inv_page_howto; break ;;
                    2) _inv_page_powerups; break ;;
                    3) _inv_page_highscores; break ;;
                    *) show_cursor ;;
                esac
            fi
        done
    done
}

# ------------------------------------------------------------
play_invaders() {
    game_tty_setup
    _game_log_start INVADERS
    cls
    local w h
    w=$(cols); h=$(rows)
    draw_game_banner INVADERS

    local hud_row=$GAME_CONTENT_TOP
    local ctrl_row=$((GAME_CONTENT_TOP + 1))
    local top=$((GAME_CONTENT_TOP + 3))
    local bottom=$((h - 2))
    local left=3 right=$((w - 4))
    if (( bottom - top < 14 || right - left < 36 )); then
        game_result "Terminal too small"
        game_tty_restore
        return
    fi

    local level=1 score=0 quit=0 lost=0 lives=3
    local tick=0
    local px=$(( (left + right) / 2 ))
    local r c idx ax n_alive off x col ei

    local move_step=2
    local fire_cd=0
    local fire_rate=10
    local shot_width=1
    local max_bullets=1

    local cols_n=0 rows_n=0
    local -a alive
    local ox=0 oy=0 adx=1
    local alien_pace=8
    local layout=0
    local alien_fire_chance=0   # % chance pr. move-tick (stiger med level)

    local -a bx by
    local bi
    # Enemy bullets
    local -a ebx eby
    local MAX_EB=6

    local -a pup_x pup_y pup_t
    local MAX_PUP=6
    local pi

    for ((bi = 0; bi < 8; bi++)); do bx[bi]=0; by[bi]=-1; done
    for ((ei = 0; ei < MAX_EB; ei++)); do ebx[ei]=0; eby[ei]=-1; done
    for ((pi = 0; pi < MAX_PUP; pi++)); do pup_x[pi]=0; pup_y[pi]=-1; pup_t[pi]=""; done

    _inv_clear_field() {
        local y
        for ((y = top; y <= bottom; y++)); do
            goto "$y" "$left"
            printf '%s%s' "$NOBG" "$(repeat ' ' $((right - left + 1)))"
        done
    }

    _inv_hud() {
        local score_txt="L$level  SCORE $score  LIVES $lives"
        local ctrl_txt="A/D move · SPACE shoot · Q quit"
        local score_left=$(( (w - ${#score_txt}) / 2 ))
        local ctrl_left=$(( (w - ${#ctrl_txt}) / 2 ))
        (( score_left < 1 )) && score_left=1
        (( ctrl_left < 1 )) && ctrl_left=1
        goto "$hud_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$hud_row" "$score_left"
        printf '%s%sL%s%d%s  %sSCORE %s%d%s  %sLIVES %s%d%s' \
            "$NOBG" "$FG_HINT" "$FG_FUN" "$level" "$R$NOBG" \
            "$FG_HINT" "$FG_YEL1" "$score" "$R$NOBG" \
            "$FG_HINT" "$FG_EXIT" "$lives" "$R"
        goto "$ctrl_row" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        goto "$ctrl_row" "$ctrl_left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl_txt" "$R"
    }

    _inv_draw_player() {
        goto "$bottom" $((px - 1))
        printf '%s%s▀█▀%s' "$FG_NUM" "$BOLD" "$R"
    }
    _inv_erase_player() {
        goto "$bottom" $((px - 1))
        printf '%s   %s' "$NOBG" "$R"
    }

    _inv_alien_active() {
        local r=$1 c=$2
        local idx=$((r * cols_n + c))
        case $layout in
            1)
                if (( r % 2 == 1 && c % 2 == 0 )); then alive[idx]=0
                else alive[idx]=1; fi
                ;;
            2)
                local mid=$((cols_n / 2))
                local dist=$(( c < mid ? mid - c : c - mid ))
                if (( dist <= r + 1 )); then alive[idx]=1; else alive[idx]=0; fi
                ;;
            3)
                if (( r == 0 || r == rows_n - 1 || c == 0 || c == cols_n - 1 )); then
                    alive[idx]=1
                elif (( r == rows_n / 2 && c > 1 && c < cols_n - 2 )); then
                    alive[idx]=1
                else
                    alive[idx]=0
                fi
                ;;
            4)
                if (( c % 2 == 0 )); then alive[idx]=1; else alive[idx]=0; fi
                ;;
            *) alive[idx]=1 ;;
        esac
    }

    _inv_spawn_level() {
        local i r c
        layout=$(( (level - 1) % 5 ))
        cols_n=$(( 6 + (level / 2) ))
        (( cols_n > 12 )) && cols_n=12
        rows_n=$(( 2 + (level / 3) ))
        (( rows_n > 5 )) && rows_n=5
        alien_pace=$(( 8 - level / 2 ))
        (( alien_pace < 2 )) && alien_pace=2
        # Fjender skyder fra level 3; chance stiger
        if (( level >= 3 )); then
            alien_fire_chance=$(( 8 + (level - 3) * 4 ))
            (( alien_fire_chance > 45 )) && alien_fire_chance=45
        else
            alien_fire_chance=0
        fi

        alive=()
        for ((r = 0; r < rows_n; r++)); do
            for ((c = 0; c < cols_n; c++)); do
                _inv_alien_active "$r" "$c"
            done
        done
        local any=0
        for ((i = 0; i < cols_n * rows_n; i++)); do
            (( alive[i] )) && { any=1; break; }
        done
        if (( ! any )); then
            for ((i = 0; i < cols_n * rows_n; i++)); do alive[i]=1; done
        fi

        ox=$((left + 2))
        oy=$top
        adx=1
        for ((bi = 0; bi < 8; bi++)); do by[bi]=-1; done
        for ((ei = 0; ei < MAX_EB; ei++)); do eby[ei]=-1; done
        for ((pi = 0; pi < MAX_PUP; pi++)); do pup_y[pi]=-1; done
        fire_cd=0
    }

    _inv_glyph() {
        case $(( $1 % 3 )) in
            0) echo 'W' ;;
            1) echo 'M' ;;
            *) echo 'V' ;;
        esac
    }

    _inv_draw_aliens() {
        local r c idx g
        for ((r = 0; r < rows_n; r++)); do
            for ((c = 0; c < cols_n; c++)); do
                idx=$((r * cols_n + c))
                goto $((oy + r)) $((ox + c * 3))
                if (( alive[idx] )); then
                    g=$(_inv_glyph "$r")
                    printf '%s%s%s%s' "$FG_FUN" "$BOLD" "$g" "$R"
                else
                    printf '%s %s' "$NOBG" "$R"
                fi
            done
        done
    }

    _inv_erase_aliens() {
        local r c
        for ((r = 0; r < rows_n; r++)); do
            for ((c = 0; c < cols_n; c++)); do
                goto $((oy + r)) $((ox + c * 3))
                printf '%s %s' "$NOBG" "$R"
            done
        done
    }

    _inv_count_alive() {
        local i
        n_alive=0
        for ((i = 0; i < cols_n * rows_n; i++)); do
            (( alive[i] )) && ((n_alive++))
        done
    }

    _inv_spawn_bullet() {
        local n=0
        for ((bi = 0; bi < 8; bi++)); do
            (( by[bi] >= 0 )) && ((n++))
        done
        (( n >= max_bullets )) && return 1
        (( fire_cd > 0 )) && return 1
        local offsets=()
        case $shot_width in
            5) offsets=(-2 -1 0 1 2) ;;
            3) offsets=(-1 0 1) ;;
            *) offsets=(0) ;;
        esac
        for off in "${offsets[@]}"; do
            n=0
            for ((bi = 0; bi < 8; bi++)); do
                (( by[bi] >= 0 )) && ((n++))
            done
            (( n >= 8 )) && break
            for ((bi = 0; bi < 8; bi++)); do
                if (( by[bi] < 0 )); then
                    x=$((px + off))
                    (( x < left )) && x=$left
                    (( x > right )) && x=$right
                    bx[bi]=$x
                    by[bi]=$((bottom - 1))
                    break
                fi
            done
        done
        fire_cd=$fire_rate
        return 0
    }

    _inv_enemy_try_fire() {
        (( alien_fire_chance <= 0 )) && return
        (( RANDOM % 100 >= alien_fire_chance )) && return
        # Find nederste alien i en tilfældig kolonne
        local tries=0 c r idx found_r=-1 found_c=-1
        for ((tries = 0; tries < cols_n; tries++)); do
            c=$((RANDOM % cols_n))
            found_r=-1
            for ((r = rows_n - 1; r >= 0; r--)); do
                idx=$((r * cols_n + c))
                if (( alive[idx] )); then
                    found_r=$r; found_c=$c; break
                fi
            done
            (( found_r >= 0 )) && break
        done
        (( found_r < 0 )) && return
        for ((ei = 0; ei < MAX_EB; ei++)); do
            if (( eby[ei] < 0 )); then
                ebx[ei]=$((ox + found_c * 3))
                eby[ei]=$((oy + found_r + 1))
                return
            fi
        done
    }

    _inv_player_hit() {
        ((lives--))
        _inv_hud
        # Flash
        _inv_erase_player
        sleep_ms 0.15
        _inv_draw_player
        # Clear enemy bullets
        for ((ei = 0; ei < MAX_EB; ei++)); do
            if (( eby[ei] >= 0 )); then
                goto "${eby[ei]}" "${ebx[ei]}"
                printf '%s %s' "$NOBG" "$R"
                eby[ei]=-1
            fi
        done
        (( lives <= 0 )) && lost=1
    }

    _inv_drop_powerup() {
        local x=$1 y=$2
        # ~70% good, ~30% bad (flere bad på høje levels)
        local types
        if (( level >= 5 && RANDOM % 100 < 35 )); then
            types=(D N Z V D N)
        elif (( RANDOM % 100 < 28 )); then
            types=(D N Z V)
        else
            types=(F W S M P F W S)
        fi
        local t=${types[RANDOM % ${#types[@]}]}
        for ((pi = 0; pi < MAX_PUP; pi++)); do
            if (( pup_y[pi] < 0 )); then
                pup_x[pi]=$x
                pup_y[pi]=$y
                pup_t[pi]=$t
                return
            fi
        done
    }

    _inv_apply_powerup() {
        local t=$1
        case $t in
            F)
                (( fire_rate -= 2 )); (( fire_rate < 3 )) && fire_rate=3
                ((score += 15))
                ;;
            W)
                if (( shot_width < 3 )); then shot_width=3
                elif (( shot_width < 5 )); then shot_width=5
                else ((score += 40)); fi
                ;;
            S)
                (( move_step++ )); (( move_step > 4 )) && move_step=4
                ((score += 15))
                ;;
            M)
                (( max_bullets++ )); (( max_bullets > 4 )) && max_bullets=4
                ((score += 20))
                ;;
            P) ((score += 50)) ;;
            D)
                (( fire_rate += 3 )); (( fire_rate > 18 )) && fire_rate=18
                ;;
            N)
                if (( shot_width >= 5 )); then shot_width=3
                elif (( shot_width >= 3 )); then shot_width=1
                fi
                ;;
            Z)
                (( move_step-- )); (( move_step < 1 )) && move_step=1
                ;;
            V)
                ((score -= 40)); (( score < 0 )) && score=0
                ;;
        esac
        _inv_hud
    }

    _inv_level_banner() {
        local msg="LEVEL $level"
        local ml=$(( (w - ${#msg}) / 2 ))
        (( ml < 1 )) && ml=1
        goto $(( (top + bottom) / 2 )) "$ml"
        printf '%s%s%s%s%s' "$NOBG" "$FG_FUN" "$BOLD" "$msg" "$R"
        sleep_ms 0.65
        goto $(( (top + bottom) / 2 )) "$ml"
        printf '%s%s' "$NOBG" "$(repeat ' ' ${#msg})"
    }

    _inv_spawn_level
    _inv_hud
    _inv_level_banner
    _inv_draw_aliens
    _inv_draw_player
    game_drain

    while (( ! quit && ! lost )); do
        while game_read_key; do
            case $GAME_KEY in
                a|A)
                    _inv_erase_player
                    ((px -= move_step))
                    (( px < left + 1 )) && px=$((left + 1))
                    _inv_draw_player
                    ;;
                d|D)
                    _inv_erase_player
                    ((px += move_step))
                    (( px > right - 1 )) && px=$((right - 1))
                    _inv_draw_player
                    ;;
                space) _inv_spawn_bullet ;;
                q|Q) quit=1; break ;;
            esac
        done
        (( quit )) && break

        (( fire_cd > 0 )) && ((fire_cd--))

        # Player bullets
        for ((bi = 0; bi < 8; bi++)); do
            (( by[bi] < 0 )) && continue
            goto "${by[bi]}" "${bx[bi]}"
            printf '%s %s' "$NOBG" "$R"
            ((by[bi]--))
            if (( by[bi] < top )); then by[bi]=-1; continue; fi
            for ((pi = 0; pi < MAX_PUP; pi++)); do
                if (( pup_y[pi] >= 0 && by[bi] == pup_y[pi] && bx[bi] == pup_x[pi] )); then
                    goto "${pup_y[pi]}" "${pup_x[pi]}"
                    printf '%s %s' "$NOBG" "$R"
                    _inv_apply_powerup "${pup_t[pi]}"
                    pup_y[pi]=-1
                    by[bi]=-1
                    break
                fi
            done
            (( by[bi] < 0 )) && continue
            for ((r = 0; r < rows_n; r++)); do
                for ((c = 0; c < cols_n; c++)); do
                    idx=$((r * cols_n + c))
                    (( alive[idx] )) || continue
                    ax=$((ox + c * 3))
                    if (( by[bi] == oy + r && bx[bi] >= ax && bx[bi] <= ax + 1 )); then
                        alive[idx]=0
                        ((score += 20 + level * 2))
                        goto $((oy + r)) "$ax"
                        printf '%s %s' "$NOBG" "$R"
                        by[bi]=-1
                        _inv_hud
                        if (( RANDOM % 100 < 32 )); then
                            _inv_drop_powerup "$ax" $((oy + r))
                        fi
                        break 2
                    fi
                done
            done
            if (( by[bi] >= 0 )); then
                goto "${by[bi]}" "${bx[bi]}"
                printf '%s%s│%s' "$FG_YEL1" "$BOLD" "$R"
            fi
        done

        # Enemy bullets
        for ((ei = 0; ei < MAX_EB; ei++)); do
            (( eby[ei] < 0 )) && continue
            goto "${eby[ei]}" "${ebx[ei]}"
            printf '%s %s' "$NOBG" "$R"
            ((eby[ei]++))
            if (( eby[ei] > bottom )); then
                eby[ei]=-1
                continue
            fi
            if (( eby[ei] == bottom && ebx[ei] >= px - 1 && ebx[ei] <= px + 1 )); then
                eby[ei]=-1
                _inv_player_hit
                (( lost )) && break
                continue
            fi
            goto "${eby[ei]}" "${ebx[ei]}"
            printf '%s%s▼%s' "$FG_RED1" "$BOLD" "$R"
        done
        (( lost )) && break

        # Powerups fall
        if (( tick % 2 == 0 )); then
            for ((pi = 0; pi < MAX_PUP; pi++)); do
                (( pup_y[pi] < 0 )) && continue
                goto "${pup_y[pi]}" "${pup_x[pi]}"
                printf '%s %s' "$NOBG" "$R"
                ((pup_y[pi]++))
                if (( pup_y[pi] >= bottom )); then
                    if (( pup_x[pi] >= px - 1 && pup_x[pi] <= px + 1 )); then
                        _inv_apply_powerup "${pup_t[pi]}"
                    fi
                    pup_y[pi]=-1
                    continue
                fi
                col=$(_inv_pup_color "${pup_t[pi]}")
                goto "${pup_y[pi]}" "${pup_x[pi]}"
                printf '%s%s%s%s' "$col" "$BOLD" "${pup_t[pi]}" "$R"
            done
        fi

        # Aliens move (+ maybe shoot)
        ((tick++))
        if (( tick % alien_pace == 0 )); then
            _inv_erase_aliens
            ((ox += adx))
            if (( ox < left || ox + cols_n * 3 > right )); then
                adx=$(( -adx ))
                ((oy++))
                ((ox += adx))
            fi
            if (( oy + rows_n >= bottom - 1 )); then
                lost=1
            fi
            _inv_draw_aliens
            _inv_enemy_try_fire
        fi
        (( lost )) && break

        _inv_count_alive
        if (( n_alive == 0 )); then
            ((score += 100 * level))
            ((level++))
            _inv_clear_field
            _inv_hud
            _inv_level_banner
            _inv_spawn_level
            _inv_draw_aliens
            _inv_draw_player
        fi

        sleep_ms 0.045
    done

    local end_msg
    if (( quit )); then
        end_msg="QUIT  ·  L$level  ·  score $score"
    else
        end_msg="INVADED  ·  L$level  ·  score $score"
    fi

    # Highscore?
    if declare -F hs_qualifies >/dev/null 2>&1 && (( score > 0 )) && hs_qualifies invaders "$score"; then
        cls
        draw_game_banner INVADERS
        local ml
        ml=$(( (w - ${#end_msg}) / 2 )); (( ml < 1 )) && ml=1
        goto $((GAME_CONTENT_TOP + 2)) "$ml"
        printf '%s%s%s%s%s' "$NOBG" "$FG_TITLE" "$BOLD" "$end_msg" "$R"
        local hsmsg="NEW HIGH SCORE — enter initials"
        ml=$(( (w - ${#hsmsg}) / 2 )); (( ml < 1 )) && ml=1
        goto $((GAME_CONTENT_TOP + 4)) "$ml"
        printf '%s%s%s%s' "$NOBG" "$FG_FUN" "$hsmsg" "$R"
        game_tty_restore
        hs_prompt_name "Initials (1-3): "
        hs_save invaders "$score" "$level" "$HS_NAME"
        game_result "Saved  ·  ${HS_NAME}  ·  $score" $((GAME_CONTENT_TOP + 8))
    else
        game_result "$end_msg"
        game_tty_restore
    fi
}


run_invaders() {
    if invaders_intro; then
        play_invaders
    fi
}
