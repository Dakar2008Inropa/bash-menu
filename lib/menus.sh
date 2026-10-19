# ============================================================
# lib/menus.sh — Hovedmenu / Fun-menu / Games-menu tegning + input
# Sources efter lib/tui.sh
# ============================================================

draw_banner() {
    local w left i
    w=$(cols)

    local bash_lines=(
        '██████╗  █████╗ ███████╗██╗  ██╗'
        '██╔══██╗██╔══██╗██╔════╝██║  ██║'
        '██████╔╝███████║███████╗███████║'
        '██╔══██╗██╔══██║╚════██║██╔══██║'
        '██████╔╝██║  ██║███████║██║  ██║'
        '╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝'
    )
    local bash_fg=("$FG_RED1" "$FG_RED2" "$FG_RED3" "$FG_RED4" "$FG_RED5" "$FG_RED6")
    local bash_w=${#bash_lines[0]}
    left=$(( (w - bash_w) / 2 ))
    (( left < 1 )) && left=1

    for i in "${!bash_lines[@]}"; do
        goto $((1 + i)) "$left"
        printf '%s%s%s%s%s' "$NOBG" "${bash_fg[$i]}" "$BOLD" "${bash_lines[$i]}" "$R"
    done

    local sys_lines=(
        '███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗'
        '██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║'
        '███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║'
        '╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║'
        '███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║'
        '╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝'
    )
    local sys_fg=("$FG_YEL1" "$FG_YEL2" "$FG_YEL3" "$FG_YEL4" "$FG_YEL5" "$FG_YEL6")
    local sys_w=${#sys_lines[0]}
    local sys_left=$(( (w - sys_w) / 2 ))
    (( sys_left < 1 )) && sys_left=1
    local sys_top=8

    for i in "${!sys_lines[@]}"; do
        goto $((sys_top + i)) "$sys_left"
        printf '%s%s%s%s%s' "$NOBG" "${sys_fg[$i]}" "$BOLD" "${sys_lines[$i]}" "$R"
    done

    local by_word="By"
    local by_name="$OWNER_NAME"
    local copy_txt="© ${COMPANY} • ${COPY_YEAR}"
    local deco="──"
    local byline_plain="${deco} ${by_word} ${by_name}  ${copy_txt} ${deco}"
    local name_left=$(( (w - ${#byline_plain}) / 2 ))
    (( name_left < 1 )) && name_left=1
    goto $((sys_top + 7)) "$name_left"
    printf '%s%s%s%s %s%s%s %s%s%s  %s%s%s %s%s%s%s' \
        "$NOBG" \
        "$FG_ACCENT" "$BOLD" "$deco" \
        "$FG_BY" "$BOLD" "$by_word" \
        "$FG_BYLINE" "$BOLD" "$by_name" \
        "$FG_ACCENT" "$BOLD" "$copy_txt" \
        "$FG_ACCENT" "$BOLD" "$deco" \
        "$R"
}

# Del tekst i højst to linjer, så den bliver inden for max kolonner.
_box_split() {
    local max=$1
    local text=$2
    local i cut
    BOX_L1=""
    BOX_L2=""
    (( max < 1 )) && max=1
    if (( ${#text} <= max )); then
        BOX_L1=$text
        return
    fi
    cut=0
    for ((i = max; i > 0; i--)); do
        if [[ ${text:i-1:1} == ' ' ]]; then
            cut=$i
            break
        fi
    done
    if (( cut == 0 )); then
        BOX_L1=${text:0:max}
        BOX_L2=${text:max}
    else
        BOX_L1=${text:0:cut-1}
        BOX_L2=${text:cut}
    fi
    (( ${#BOX_L2} > max )) && BOX_L2=${BOX_L2:0:max}
}

# Generisk dobbeltboks. Brug: draw_dual_box TOP "items[@]" "hints[@]"
draw_dual_box() {
    local top=$1
    shift
    local -n _items=$1
    local -n _hints=$2

    local w total left_inner right_inner start
    w=$(cols)
    total=$((w - 4))
    (( total > 90 )) && total=90
    (( total < 62 )) && total=62
    left_inner=$(( (total - 3) * 52 / 100 ))
    right_inner=$(( total - 3 - left_inner ))
    start=$(( (w - total) / 2 ))
    (( start < 1 )) && start=1

    local lpad=$((left_inner - 7))
    local rpad=$((right_inner - 14))
    (( lpad < 1 )) && lpad=1
    (( rpad < 1 )) && rpad=1
    goto "$top" "$start"
    printf '%s%s┌─ %s%sMenu%s %s┬─ %s%sDescription%s %s┐%s' \
        "$NOBG" "$FG_WHITE" \
        "$FG_TITLE" "$BOLD" "$R$NOBG$FG_WHITE" \
        "$(repeat '─' "$lpad")" \
        "$FG_TITLE" "$BOLD" "$R$NOBG$FG_WHITE" \
        "$(repeat '─' "$rpad")" \
        "$R"

    local r=$((top + 1))
    local i num label num_fg
    for i in "${!_items[@]}"; do
        num="${_items[$i]%%|*}"
        label="${_items[$i]#*|}"
        case $num in
            0) num_fg=$FG_BACK ;;   # Back
            +) num_fg=$FG_EXIT ;;   # Exit / Quit
            *)
                # Games-menu: unik farve pr. spil (samme som spillets banner)
                if [[ ${MENU_MODE:-main} == games ]]; then
                    # Rækkefølge: første digitale udgivelse (brandfarve følger spillet)
                    case $num in
                        1) num_fg=$FG_GAME_XO ;;        # Tic-Tac-Toe
                        2) num_fg=$FG_GAME_PONG ;;      # Pong
                        3) num_fg=$FG_GAME_BREAKOUT ;;  # Breakout
                        4) num_fg=$FG_GAME_SNAKE ;;     # Snake
                        5) num_fg=$FG_GAME_INVADERS ;;  # Space Invaders
                        6) num_fg=$FG_GAME_BJ ;;        # Blackjack
                        7) num_fg=$FG_GAME_TETRIS ;;    # Tetris
                        8) num_fg=$FG_GAME_MINES ;;     # Minesweeper
                        *) num_fg=$FG_NUM ;;
                    esac
                else
                    case $num in
                        7) num_fg=$FG_FUN ;;      # Fun
                        8) num_fg=$FG_GAMES ;;    # Games
                        9) num_fg=$FG_ACCENT ;;   # Tools
                        *) num_fg=$FG_NUM ;;
                    esac
                fi
                ;;
        esac

        # "  [n]  " fylder 6 + længden af tallet. Én kolonne fri før stregerne.
        local prefix_w=$((6 + ${#num}))
        local label_max=$((left_inner - prefix_w - 1))
        local hint_max=$((right_inner - 3))
        (( label_max < 1 )) && label_max=1
        (( hint_max < 1 )) && hint_max=1
        _box_split "$label_max" "$label"
        local lab1=$BOX_L1 lab2=$BOX_L2
        _box_split "$hint_max" "${_hints[$i]}"
        local hint1=$BOX_L1 hint2=$BOX_L2
        local lines=1
        [[ -n $lab2 || -n $hint2 ]] && lines=2

        local line_no left_text hint_text
        for ((line_no = 1; line_no <= lines; line_no++)); do
            if (( line_no == 1 )); then
                left_text=$lab1
                hint_text=$hint1
            else
                left_text=$lab2
                hint_text=$hint2
            fi

            goto "$r" "$start"
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
            goto "$r" $((start + 1))
            printf '%s%s' "$NOBG" "$(repeat ' ' "$left_inner")"
            goto "$r" $((start + 1))
            if (( line_no == 1 )); then
                printf '%s%s%s  [%s]%s  %s%s%s' \
                    "$NOBG" "$num_fg" "$BOLD" "$num" \
                    "$R$NOBG$FG_LABEL" "$left_text" "$R"
            else
                printf '%s%s%s%s' \
                    "$NOBG" "$(repeat ' ' "$prefix_w")" "$FG_LABEL" "$left_text"
                printf '%s' "$R"
            fi

            goto "$r" $((start + 1 + left_inner))
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
            goto "$r" $((start + 2 + left_inner))
            printf '%s%s' "$NOBG" "$(repeat ' ' "$right_inner")"
            goto "$r" $((start + 2 + left_inner))
            printf '%s%s  %s%s' "$NOBG" "$FG_HINT" "$hint_text" "$R"

            goto "$r" $((start + total - 1))
            printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
            ((r++))
        done
    done

    goto "$r" "$start"
    printf '%s%s└%s┴%s┘%s' \
        "$NOBG" "$FG_WHITE" \
        "$(repeat '─' "$left_inner")" \
        "$(repeat '─' "$right_inner")" \
        "$R"

    # Live clock mellem Menu-boks og CHOICE-boks
    set_clock_row $((r + 1))
    paint_clock

    local valg_top=$((r + 2))
    goto "$valg_top" "$start"
    printf '%s%s┌%s┐%s' "$NOBG" "$FG_WHITE" "$(repeat '─' $((total - 2)))" "$R"

    goto $((valg_top + 1)) "$start"
    printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"
    printf '%s%s' "$NOBG" "$(repeat ' ' $((total - 2)))"
    goto $((valg_top + 1)) $((start + 1))
    printf '%s%s%s  CHOICE: %s' "$NOBG" "$FG_CHOICE" "$BOLD" "$R"
    goto $((valg_top + 1)) $((start + total - 1))
    printf '%s%s│%s' "$NOBG" "$FG_WHITE" "$R"

    goto $((valg_top + 2)) "$start"
    printf '%s%s└%s┘%s' "$NOBG" "$FG_WHITE" "$(repeat '─' $((total - 2)))" "$R"

    VALG_ROW=$((valg_top + 1))
    VALG_COL=$((start + 11))
    BOX_START=$start
    BOX_TOTAL=$total
    # Preview tegnes først når en inline-gimmick vælges (se show_preview_box)
    CHOICE_BOT=$((valg_top + 2))
    DEMO_ROW=0
    DEMO_ROW2=0
    DEMO_COL=0
    DEMO_W=0
}

draw_ui() {
    local h top
    h=$(rows)
    # Byline ~15; clock ligger nu mellem menu og CHOICE
    top=17
    (( h < 36 )) && top=16

    local items=(
        "1|Processes"
        "2|Kill Process"
        "3|System Info"
        "4|Services"
        "5|Find File"
        "6|Users"
        "7|Fun"
        "8|Games"
        "9|Tools"
        "10|SSH"
        "+|Exit"
    )
    local hints=(
        "Show running processes"
        "Stop a process"
        "CPU, RAM and disk"
        "Show active services"
        "Search for a filename"
        "Manage users and groups"
        "Gimmicks & terminal tricks"
        "Breakout and more bash games"
        "Moodle 8–14 + monitoring"
        "Status, nøgler og guide"
        "Close the program"
    )
    draw_dual_box "$top" items hints
}

draw_fun_banner() {
    # Mindre banner end forsiden — samme stil, lilla gradient
    local w left i
    w=$(cols)

    local fun_lines=(
        '███████╗██╗   ██╗███╗   ██╗'
        '██╔════╝██║   ██║████╗  ██║'
        '█████╗  ██║   ██║██╔██╗ ██║'
        '██╔══╝  ██║   ██║██║╚██╗██║'
        '██║     ╚██████╔╝██║ ╚████║'
        '╚═╝      ╚═════╝ ╚═╝  ╚═══╝'
    )
    local fun_fg=("$FG_FUN1" "$FG_FUN2" "$FG_FUN3" "$FG_FUN4" "$FG_FUN5" "$FG_FUN6")
    local fun_w=${#fun_lines[0]}
    left=$(( (w - fun_w) / 2 ))
    (( left < 1 )) && left=1

    for i in "${!fun_lines[@]}"; do
        goto $((1 + i)) "$left"
        printf '%s%s%s%s%s' "$NOBG" "${fun_fg[$i]}" "$BOLD" "${fun_lines[$i]}" "$R"
    done

    local tip="Gimmicks & terminal tricks"
    left=$(( (w - ${#tip}) / 2 ))
    (( left < 1 )) && left=1
    goto 8 "$left"
    printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$tip" "$R"
}

draw_fun_ui() {
    draw_fun_banner

    local items=(
        "1|Spinner"
        "2|Progress bar"
        "3|Typewriter"
        "4|Matrix rain"
        "5|Live clock"
        "6|Color palette"
        "7|Rainbow text"
        "8|Cowsay"
        "9|Confetti"
        "10|ASCII fire"
        "11|Bouncing sprite"
        "12|Big word banner"
        "13|Fake boot"
        "14|Mario"
        "0|Back"
        "+|Quit"
    )
    local hints=(
        "Inline under CHOICE"
        "Inline progress bar"
        "Inline typewriter"
        "Fullscreen effect"
        "Inline live clock"
        "Fullscreen colors"
        "Inline rainbow line"
        "Fullscreen ASCII art"
        "Fullscreen effect"
        "Fullscreen effect"
        "Fullscreen bounce"
        "Fullscreen banner"
        "Fullscreen sequence"
        "Overworld theme (bell)"
        "Return to main menu"
        "Stop script immediately"
    )
    # Menu under banner + tip + clock (række 1–9)
    draw_dual_box 11 items hints
}

place_valg_cursor() {
    goto "$VALG_ROW" "$VALG_COL"
    printf '%s%s%s' "$NOBG" "$FG_BYLINE" "$BOLD"
}

# Tegn det brugeren har skrevet i CHOICE-feltet (hele strengen, fx "10")
paint_choice_input() {
    local text=$1
    local maxw=$((BOX_TOTAL - 14))
    (( maxw < 4 )) && maxw=4
    if (( ${#text} > maxw )); then
        text="${text: -maxw}"
    fi
    goto "$VALG_ROW" "$VALG_COL"
    printf '%s%s' "$NOBG" "$(repeat ' ' "$maxw")"
    goto "$VALG_ROW" "$VALG_COL"
    printf '%s%s%s%s' "$NOBG" "$FG_BYLINE" "$BOLD" "$text"
    printf '%s' "$R"
}

redraw_current_menu() {
    case $MENU_MODE in
        fun)   show_fun_menu ;;
        games) show_games_menu ;;
        tools) show_tools_menu ;;
        ssh)   show_ssh_menu ;;
        *)     show_menu ;;
    esac
}

wait_for_choice() {
    # Læs tegn-for-tegn, så "10" virker (den gamle read -t satte markøren
    # tilbage hvert 0.25s og overskrev forrige ciffer visuelt).
    local line="" ch
    NEED_REDRAW=0
    CHOICE_VALUE=""
    paint_choice_input ""
    show_cursor
    while true; do
        place_valg_cursor
        # flyt markør til slutningen af det indtastede
        goto "$VALG_ROW" $((VALG_COL + ${#line}))
        printf '%s%s%s' "$NOBG" "$FG_BYLINE" "$BOLD"

        # -s = vi tegner selv (ingen terminal-echo der forvirrer)
        if IFS= read -r -s -n 1 -t 0.25 ch; then
            # Enter
            if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                hide_cursor
                CHOICE_VALUE=$line
                return 0
            fi
            # Backspace / Delete
            if [[ $ch == $'\177' || $ch == $'\b' ]]; then
                if (( ${#line} > 0 )); then
                    line="${line:0:$((${#line} - 1))}"
                    paint_choice_input "$line"
                fi
                continue
            fi
            # Ignorer andre kontroltegn
            if [[ $ch < ' ' ]]; then
                continue
            fi
            line+="$ch"
            paint_choice_input "$line"
        else
            # Timeout: opdater live clock + evt. resize
            paint_clock
            if (( NEED_REDRAW )); then
                NEED_REDRAW=0
                hide_cursor
                local saved=$line
                redraw_current_menu
                line=$saved
                paint_choice_input "$line"
                show_cursor
            fi
        fi
    done
}

pause() {
    local h
    NEED_REDRAW=0
    while true; do
        h=$(rows)
        goto $((h - 3)) 2
        printf '%s%s%s ▶ Press Enter to return... %s' \
            "$NOBG" "$FG_ORANGE" "$BOLD" "$R"
        show_cursor
        if read -r -t 0.25 _; then
            hide_cursor
            return
        fi
        # Kun opdater live clock hvis skærmen har sat CLOCK_ROW (ikke efter spil)
        (( CLOCK_ROW > 0 )) && paint_clock
        if (( NEED_REDRAW )); then
            NEED_REDRAW=0
        fi
    done
}



show_fun_menu() {
    local h w
    NEED_REDRAW=0
    while true; do
        h=$(rows); w=$(cols)
        # Fun-menuen har flere rækker
        if (( h >= 40 && w >= 76 )); then
            break
        fi
        cls
        echo "Please make the terminal larger (min. 76x40). Now: ${w}x${h}"
        show_cursor
        while true; do
            if read -r -t 0.25 _; then break; fi
            if (( NEED_REDRAW )); then NEED_REDRAW=0; break; fi
        done
        hide_cursor
    done
    hide_cursor
    cls
    draw_fun_ui
    place_valg_cursor
    show_cursor
}


# Games-undermenu UI (spillene selv ligger i games/*.sh)
draw_games_banner() {
    local w left i
    w=$(cols)

    local games_lines=(
        ' ██████╗  █████╗ ███╗   ███╗███████╗███████╗'
        '██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔════╝'
        '██║  ███╗███████║██╔████╔██║█████╗  ███████╗'
        '██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ╚════██║'
        '╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗███████║'
        ' ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝'
    )
    local games_fg=("$FG_YEL1" "$FG_YEL2" "$FG_YEL3" "$FG_ORANGE" "$FG_ACCENT" "$FG_YEL5")
    local games_w=${#games_lines[0]}
    left=$(( (w - games_w) / 2 ))
    (( left < 1 )) && left=1

    for i in "${!games_lines[@]}"; do
        goto $((1 + i)) "$left"
        printf '%s%s%s%s%s' "$NOBG" "${games_fg[$i]}" "$BOLD" "${games_lines[$i]}" "$R"
    done

    local tip="Classic games in Bash  ·  intro before each game"
    left=$(( (w - ${#tip}) / 2 ))
    (( left < 1 )) && left=1
    goto 8 "$left"
    printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$tip" "$R"
}

draw_games_ui() {
    draw_games_banner

    # Første digitale udgivelse først (ikke fysisk oprindelse) — ingen årstal i navne
    local items=(
        "1|Tic-Tac-Toe"
        "2|Pong"
        "3|Breakout"
        "4|Snake"
        "5|Space Invaders"
        "6|Blackjack"
        "7|Tetris"
        "8|Minesweeper"
        "0|Back"
        "+|Quit"
    )
    local hints=(
        "Three in a row vs CPU"
        "Bat and ball"
        "Brick breaker"
        "Grow and survive"
        "Shoot the aliens"
        "Get close to 21"
        "Stack the falling pieces"
        "Find mines, avoid boom"
        "Return to main menu"
        "Stop script immediately"
    )
    draw_dual_box 11 items hints
}

show_games_menu() {
    local h w
    NEED_REDRAW=0
    while true; do
        h=$(rows); w=$(cols)
        if (( h >= 34 && w >= 76 )); then
            break
        fi
        cls
        echo "Please make the terminal larger (min. 76x34). Now: ${w}x${h}"
        show_cursor
        while true; do
            if read -r -t 0.25 _; then break; fi
            if (( NEED_REDRAW )); then NEED_REDRAW=0; break; fi
        done
        hide_cursor
    done
    hide_cursor
    cls
    set_clock_row 0   # ingen live clock i Games / efter spil-quit
    draw_games_ui
    place_valg_cursor
    show_cursor
}

games_menu() {
    MENU_MODE=games
    while true; do
        show_games_menu
        wait_for_choice
        case "$CHOICE_VALUE" in
            # Digital udgivelsesrækkefølge — game_result() viser selv "Press Enter…"
            1) declare -F run_ttt >/dev/null && run_ttt ;;
            2) declare -F run_pong >/dev/null && run_pong ;;
            3) breakout_game ;;
            4) declare -F run_snake >/dev/null && run_snake ;;
            5) declare -F run_invaders >/dev/null && run_invaders ;;
            6) declare -F run_blackjack >/dev/null && run_blackjack ;;
            7) declare -F run_tetris >/dev/null && run_tetris ;;
            8) declare -F run_mines >/dev/null && run_mines ;;
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
                printf '%s%s%s  Invalid choice: %s  %s' \
                    "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$CHOICE_VALUE" "$R"
                sleep 1.0
                ;;
        esac
    done
}


show_menu() {
    local h w
    NEED_REDRAW=0

    while true; do
        h=$(rows); w=$(cols)
        if (( h >= 36 && w >= 76 )); then
            break
        fi
        cls
        echo "Please make the terminal larger (min. 76x36). Now: ${w}x${h}"
        echo "Resize the window — the menu redraws automatically."
        show_cursor
        while true; do
            if read -r -t 0.25 _; then
                break
            fi
            if (( NEED_REDRAW )); then
                NEED_REDRAW=0
                break
            fi
        done
        hide_cursor
    done

    hide_cursor
    cls
    draw_banner
    draw_ui
    place_valg_cursor
    show_cursor
}

