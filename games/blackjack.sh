#!/bin/bash
# ============================================================
# games/blackjack.sh — blackjack (bunke, bet, split, double)
# Tegner kun ved ændring — ingen busy-loop redraw (undgår flimmer).
# ============================================================

play_blackjack() {
    game_tty_setup
    hide_cursor
    _game_log_start BLACKJACK
    cls
    local w h
    w=$(cols); h=$(rows)
    draw_game_banner BJ

    local hud_row=$GAME_CONTENT_TOP
    local top=$((GAME_CONTENT_TOP + 2))
    local quit=0
    local money=100
    local bet=10
    local min_bet=5 max_bet=50

    local COL_YOU=${FG_NUM:-$'\e[38;2;80;220;235m'}
    local COL_DEAL=${FG_EXIT:-$'\e[38;2;255;120;110m'}
    local COL_CARD=${FG_LABEL:-$'\e[38;2;190;230;240m'}
    local COL_RED=${FG_RED1:-$'\e[38;2;255;90;90m'}

    local -a deck
    local di=0
    local BJ_CARD=""
    local MSG=""

    local -a hand0 hand1 dealer
    local stake0=0 stake1=0
    local hands=1
    local cur=0

    # ---------- deck (aldrig i $() — di++ skal ske i samme shell) ----------
    _bj_new_deck() {
        deck=()
        local s v i j tmp
        for s in S H D C; do
            for v in A 2 3 4 5 6 7 8 9 T J Q K; do
                deck+=("${v}${s}")
            done
        done
        for ((i = ${#deck[@]} - 1; i > 0; i--)); do
            j=$((RANDOM % (i + 1)))
            tmp=${deck[i]}; deck[i]=${deck[j]}; deck[j]=$tmp
        done
        di=0
    }

    _bj_draw() {
        (( di >= ${#deck[@]} - 8 )) && _bj_new_deck
        BJ_CARD=${deck[di]}
        ((di++))
    }

    _bj_rank() { printf '%s' "${1:0:1}"; }
    _bj_suit() { printf '%s' "${1:1:1}"; }

    _bj_suit_sym() {
        case $1 in
            S) printf 'S' ;; H) printf 'H' ;; D) printf 'D' ;; C) printf 'C' ;;
            *) printf '?' ;;
        esac
    }

    _bj_card_fg() {
        case $1 in H|D) printf '%s' "$COL_RED" ;; *) printf '%s' "$COL_CARD" ;; esac
    }

    _bj_fmt_card() {
        local r s
        r=$(_bj_rank "$1"); s=$(_bj_suit "$1")
        [[ $r == T ]] && r=10
        printf '%s%s' "$r" "$(_bj_suit_sym "$s")"
    }

    _bj_value() {
        local c v sum=0 aces=0
        for c in "$@"; do
            [[ -z $c ]] && continue
            v=${c:0:1}
            case $v in
                A) ((sum += 11)); ((aces++)) ;;
                T|J|Q|K) ((sum += 10)) ;;
                *) ((sum += v)) ;;
            esac
        done
        while (( sum > 21 && aces > 0 )); do
            ((sum -= 10)); ((aces--))
        done
        printf '%d' "$sum"
    }

    _bj_cards_line() {
        local hide=$1; shift
        local c i=0 s fg txt
        for c in "$@"; do
            if (( hide && i == 1 )); then
                printf ' %s%s[ ?? ]%s' "$NOBG" "$FG_DIM" "$R"
            else
                s=$(_bj_suit "$c")
                fg=$(_bj_card_fg "$s")
                txt=$(_bj_fmt_card "$c")
                printf ' %s%s[ %-3s ]%s' "$NOBG" "$fg$BOLD" "$txt" "$R"
            fi
            ((i++))
        done
    }

    _bj_blank_row() {
        goto "$1" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    }

    _bj_center() {
        # _bj_center row "plain_len_estimate" then printf args...
        local row=$1 len=$2; shift 2
        local col=$(( (w - len) / 2 ))
        (( col < 1 )) && col=1
        goto "$row" "$col"
        printf '%s' "$NOBG"
        printf "$@"
        printf '%s' "$R"
    }

    _bj_hud() {
        local plain="CASH \$$money    BET \$$bet"
        _bj_blank_row "$hud_row"
        _bj_center "$hud_row" "${#plain}" \
            '%sCASH %s$%d%s    %sBET %s$%d' \
            "$FG_HINT" "$FG_YEL1$BOLD" "$money" "$R$NOBG$FG_HINT" \
            "$FG_HINT" "$FG_ORANGE$BOLD" "$bet"
    }

    _bj_footer() {
        local msg=$1 ctrl=$2
        _bj_blank_row $((h - 4))
        if [[ -n $msg ]]; then
            _bj_center $((h - 4)) "${#msg}" '%s%s%s' "$FG_TITLE" "$BOLD" "$msg"
        fi
        _bj_blank_row $((h - 2))
        [[ -n $ctrl ]] && _bj_center $((h - 2)) "${#ctrl}" '%s%s' "$FG_DIM" "$ctrl"
    }

    _bj_clear_body() {
        local y
        for ((y = top; y < h - 4; y++)); do
            _bj_blank_row "$y"
        done
    }

    _bj_draw_table() {
        local hide=${1:-1}
        local row=$top
        local left=$(( w / 2 - 28 ))
        (( left < 2 )) && left=2
        local hv st hi label

        _bj_hud
        _bj_clear_body

        goto "$row" "$left"
        printf '%s%s%sDEALER%s' "$NOBG" "$COL_DEAL" "$BOLD" "$R"
        ((row++))
        goto "$row" "$left"
        _bj_cards_line "$hide" "${dealer[@]}"
        if (( hide )); then
            printf '  %s?%s' "$FG_DIM" "$R"
        else
            printf '  %s= %s%s%d%s' "$FG_HINT" "$FG_YEL1" "$BOLD" "$(_bj_value "${dealer[@]}")" "$R"
        fi
        row=$((row + 2))

        for ((hi = 0; hi < hands; hi++)); do
            if (( hi == 0 )); then
                label="YOU"
                (( hands > 1 )) && label="YOU  hand 1"
                hv=$(_bj_value "${hand0[@]}")
                st=$stake0
            else
                label="YOU  hand 2"
                hv=$(_bj_value "${hand1[@]}")
                st=$stake1
            fi
            goto "$row" "$left"
            if (( hands > 1 && cur == hi && hide )); then
                printf '%s%s%s%s >%s' "$NOBG" "$COL_YOU" "$BOLD" "$label" "$R"
            else
                printf '%s%s%s%s%s' "$NOBG" "$COL_YOU" "$BOLD" "$label" "$R"
            fi
            ((row++))
            goto "$row" "$left"
            if (( hi == 0 )); then
                _bj_cards_line 0 "${hand0[@]}"
            else
                _bj_cards_line 0 "${hand1[@]}"
            fi
            printf '  %s= %s%s%d%s  %s($%d)%s' \
                "$FG_HINT" "$COL_YOU" "$BOLD" "$hv" "$R$NOBG" "$FG_DIM" "$st" "$R"
            row=$((row + 2))
        done
    }

    # Vent på tast uden at genoptegne
    _bj_wait_key() {
        while true; do
            if game_read_key; then
                return 0
            fi
            sleep_ms 0.05
        done
    }

    _bj_wait_enter() {
        local ctrl=${1:-"Enter continue   Q quit"}
        _bj_footer "$MSG" "$ctrl"
        while true; do
            _bj_wait_key
            case $GAME_KEY in
                enter|space) return 0 ;;
                q|Q) quit=1; return 1 ;;
            esac
        done
    }

    # ---------- bet (tegn én gang, kun igen ved ændring) ----------
    _bj_paint_bet() {
        local row=$top
        local line

        _bj_hud
        _bj_clear_body

        line="PLACE YOUR BET"
        _bj_center "$row" "${#line}" '%s%s%s' "$FG_TITLE" "$BOLD" "$line"
        row=$((row + 2))

        line="Bet  \$$bet"
        _bj_center "$row" "${#line}" '%sBet  %s$%d' "$FG_HINT" "$FG_ORANGE$BOLD" "$bet"
        row=$((row + 2))

        line="W / + raise      S / - lower"
        _bj_center "$row" "${#line}" '%sW / +%s raise      %sS / -%s lower' \
            "$COL_YOU" "$R$NOBG$FG_DIM" "$COL_YOU" "$R$NOBG$FG_DIM"
        row=$((row + 1))

        line="Enter deal the cards      Q leave table"
        _bj_center "$row" "${#line}" '%sEnter%s deal the cards      %sQ%s leave table' \
            "$FG_YEL1" "$R$NOBG$FG_DIM" "$FG_EXIT" "$R$NOBG$FG_DIM"

        _bj_footer "" "Min \$$min_bet   Max \$$max_bet   step \$5"
    }

    _bj_bet_phase() {
        local dirty=1
        while true; do
            (( bet > money )) && bet=$money
            (( bet < min_bet )) && bet=$min_bet
            (( bet > max_bet )) && bet=$max_bet
            (( bet > money )) && bet=$money

            if (( dirty )); then
                _bj_paint_bet
                dirty=0
            fi

            _bj_wait_key
            case $GAME_KEY in
                w|W|+|=)
                    ((bet += 5))
                    (( bet > max_bet )) && bet=$max_bet
                    (( bet > money )) && bet=$money
                    dirty=1
                    ;;
                s|S|-|_)
                    ((bet -= 5))
                    (( bet < min_bet )) && bet=$min_bet
                    dirty=1
                    ;;
                enter|space)
                    (( money >= bet && bet >= min_bet )) && return 0
                    ;;
                q|Q)
                    quit=1
                    return 1
                    ;;
            esac
        done
    }

    _bj_same_rank() {
        local a=$1 b=$2 ra rb
        ra=$(_bj_rank "$a"); rb=$(_bj_rank "$b")
        [[ $ra == "$rb" ]] && return 0
        case $ra in T|J|Q|K)
            case $rb in T|J|Q|K) return 0 ;; esac ;;
        esac
        return 1
    }

    _bj_play_hand() {
        local hi=$1
        cur=$hi
        local done_hand=0 pv dirty=1
        local ctrl
        if (( hi == 1 )); then
            local -n _H=hand1
            local -n _ST=stake1
        else
            local -n _H=hand0
            local -n _ST=stake0
        fi

        while (( ! done_hand && ! quit )); do
            if (( dirty )); then
                pv=$(_bj_value "${_H[@]}")
                _bj_draw_table 1
                ctrl="H hit   S stand"
                if (( ${#_H[@]} == 2 && money >= bet )); then
                    ctrl+="   D double"
                fi
                if (( hi == 0 && hands == 1 && ${#_H[@]} == 2 && money >= bet )) && _bj_same_rank "${_H[0]}" "${_H[1]}"; then
                    ctrl+="   P split"
                fi
                ctrl+="   Q quit"
                _bj_footer "" "$ctrl"
                dirty=0
            fi

            _bj_wait_key
            case $GAME_KEY in
                h|H)
                    _bj_draw
                    _H+=("$BJ_CARD")
                    pv=$(_bj_value "${_H[@]}")
                    if (( pv > 21 )); then
                        MSG="BUST — $pv"
                        _bj_draw_table 1
                        _bj_footer "$MSG" ""
                        sleep_ms 0.9
                        done_hand=1
                    else
                        dirty=1
                    fi
                    ;;
                s|S)
                    done_hand=1
                    ;;
                d|D)
                    if (( ${#_H[@]} == 2 && money >= bet )); then
                        ((money -= bet))
                        ((_ST += bet))
                        _bj_draw
                        _H+=("$BJ_CARD")
                        pv=$(_bj_value "${_H[@]}")
                        if (( pv > 21 )); then MSG="Double BUST — $pv"
                        else MSG="Doubled to $pv"
                        fi
                        _bj_draw_table 1
                        _bj_footer "$MSG" ""
                        sleep_ms 0.9
                        done_hand=1
                    fi
                    ;;
                p|P)
                    if (( hi == 0 && hands == 1 && ${#_H[@]} == 2 && money >= bet )) && _bj_same_rank "${_H[0]}" "${_H[1]}"; then
                        ((money -= bet))
                        hands=2
                        hand1=("${hand0[1]}")
                        hand0=("${hand0[0]}")
                        stake1=$bet
                        _bj_draw; hand0+=("$BJ_CARD")
                        _bj_draw; hand1+=("$BJ_CARD")
                        MSG="Split"
                        dirty=1
                    fi
                    ;;
                q|Q)
                    quit=1
                    return
                    ;;
            esac
        done
    }

    _bj_settle() {
        local hi=$1
        local -a ph
        local st pv dv
        if (( hi == 0 )); then
            ph=("${hand0[@]}"); st=$stake0
        else
            ph=("${hand1[@]}"); st=$stake1
        fi
        pv=$(_bj_value "${ph[@]}")
        dv=$(_bj_value "${dealer[@]}")
        if (( pv > 21 )); then
            MSG+="H$((hi+1)) BUST  "
        elif (( dv > 21 || pv > dv )); then
            ((money += st * 2))
            MSG+="H$((hi+1)) WIN +\$$st  "
        elif (( pv < dv )); then
            MSG+="H$((hi+1)) LOSE  "
        else
            ((money += st))
            MSG+="H$((hi+1)) PUSH  "
        fi
    }

    # ---------- main ----------
    _bj_new_deck
    game_drain

    while (( money >= min_bet && ! quit )); do
        hand0=(); hand1=(); dealer=()
        hands=1; cur=0
        stake0=0; stake1=0
        MSG=""
        cls
        draw_game_banner BJ
        hide_cursor

        _bj_bet_phase || break
        (( quit )) && break

        ((money -= bet))
        stake0=$bet

        _bj_draw; hand0+=("$BJ_CARD")
        _bj_draw; dealer+=("$BJ_CARD")
        _bj_draw; hand0+=("$BJ_CARD")
        _bj_draw; dealer+=("$BJ_CARD")

        if (( $(_bj_value "${hand0[@]}") == 21 )); then
            if (( $(_bj_value "${dealer[@]}") == 21 )); then
                MSG="Push — both blackjack"
                ((money += bet))
            else
                local win=$(( bet * 3 / 2 ))
                MSG="BLACKJACK!  +\$$win"
                ((money += bet + win))
            fi
            _bj_draw_table 0
            _bj_wait_enter || break
            continue
        fi

        if (( $(_bj_value "${dealer[@]}") == 21 )); then
            MSG="Dealer blackjack"
            _bj_draw_table 0
            _bj_wait_enter || break
            continue
        fi

        _bj_play_hand 0
        (( quit )) && break
        if (( hands == 2 )); then
            _bj_play_hand 1
            (( quit )) && break
        fi

        local need_dealer=0
        (( $(_bj_value "${hand0[@]}") <= 21 )) && need_dealer=1
        if (( hands == 2 && $(_bj_value "${hand1[@]}") <= 21 )); then need_dealer=1; fi

        if (( need_dealer )); then
            _bj_draw_table 0
            sleep_ms 0.4
            while (( $(_bj_value "${dealer[@]}") < 17 )); do
                _bj_draw
                dealer+=("$BJ_CARD")
                _bj_draw_table 0
                sleep_ms 0.4
            done
        fi

        MSG=""
        _bj_settle 0
        (( hands == 2 )) && _bj_settle 1
        _bj_draw_table 0
        _bj_wait_enter || break
    done

    hide_cursor
    if (( quit )); then
        game_result "QUIT  ·  cash \$$money"
    else
        game_result "BROKE  ·  cash \$0"
    fi
    game_tty_restore
}


run_blackjack() {
    if game_intro BJ "Blackjack" "Casino classic / digital 1954" "Twenty-One · early computer programs" \
        "Place a bet, then beat the dealer without going over 21. Aces count 1 or 11; face cards are 10. You can hit, stand, double down, or split a pair. Dealer stands on 17." \
        "Origin: twenty-one / vingt-et-un. First digital: Los Alamos IBM 701 Blackjack (1954); later home carts e.g. Channel F Video Blackjack (1976)." \
        "Bet +/− or arrows  ·  Enter deal  ·  H hit  ·  S stand  ·  D double  ·  P split  ·  Q quit"
    then
        play_blackjack
    fi
}
