#!/bin/bash
# ============================================================
# games/highscore.sh – fælles highscore (gemt ved siden af spillene)
# Filformat pr. linje: SCORE|LEVEL|NAME|DATE
# ============================================================

: "${GAMES_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
HS_MAX=10

# Sti til highscore-fil for et spil (fx invaders → games/invaders.scores)
hs_file() {
    printf '%s/%s.scores' "$GAMES_DIR" "${1,,}"
}

# Indlæs top-liste til HS_ENTRIES[] (allerede sorteret desc)
hs_load() {
    local game=$1 file
    file=$(hs_file "$game")
    HS_ENTRIES=()
    [[ -f $file ]] || return 0
    # shellcheck disable=SC2207
    mapfile -t HS_ENTRIES < <(sort -t'|' -k1,1nr -k2,2nr "$file" 2>/dev/null | head -n "$HS_MAX")
}

# Returnerer 0 hvis score kommer på top-listen
hs_qualifies() {
    local game=$1 score=$2
    local file n last
    file=$(hs_file "$game")
    hs_load "$game"
    n=${#HS_ENTRIES[@]}
    if (( n < HS_MAX )); then
        return 0
    fi
    last=${HS_ENTRIES[$((n - 1))]}
    last=${last%%|*}
    (( score > last ))
}

# Gem score (navn 1–3 tegn). Opdaterer fil sorteret.
hs_save() {
    local game=$1 score=$2 level=$3 name=$4
    local file tmp date
    file=$(hs_file "$game")
    date=$(date '+%Y-%m-%d')
    name=${name^^}
    name=${name:0:3}
    [[ -z $name ]] && name="???"
    {
        [[ -f $file ]] && cat "$file"
        printf '%d|%d|%s|%s\n' "$score" "$level" "$name" "$date"
    } | sort -t'|' -k1,1nr -k2,2nr | head -n "$HS_MAX" > "${file}.tmp" \
        && mv -f "${file}.tmp" "$file"
}

# Læs initialer (1–3 bogstaver/cifre). Sætter HS_NAME.
hs_prompt_name() {
    local prompt=${1:-"Initials (1-3): "}
    local w h left name="" ch
    w=$(cols); h=$(rows)
    left=$(( (w - ${#prompt} - 4) / 2 ))
    (( left < 1 )) && left=1
    goto $((h / 2 + 4)) "$left"
    printf '%s%s%s%s' "$NOBG" "$FG_ORANGE" "$prompt" "$R"
    show_cursor
    # Blocking input til navn
    local old=""
    if [[ -t 0 ]]; then
        old=$(stty -g 2>/dev/null || true)
        stty echo icanon 2>/dev/null || true
    fi
    name=""
    while (( ${#name} < 3 )); do
        IFS= read -r -s -n 1 ch || break
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            (( ${#name} >= 1 )) && break
            continue
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#name} > 0 )) && name="${name:0:${#name}-1}"
        elif [[ $ch =~ ^[A-Za-z0-9]$ ]]; then
            name+="${ch^^}"
        fi
        goto $((h / 2 + 4)) $((left + ${#prompt}))
        printf '%s%s%-3s%s' "$NOBG" "$FG_YEL1" "$name" "$R"
    done
    [[ -n $old ]] && stty "$old" 2>/dev/null || true
    hide_cursor
    HS_NAME=${name:-???}
}

# Tegn top-liste (til intro). Valgfri limit som 5. arg (default HS_MAX).
# hs_draw_table START_ROW LEFT INNER [game] [limit]
hs_draw_table() {
    local row=$1 left=$2 inner=$3
    local game=${4:-invaders}
    local limit=${5:-$HS_MAX}
    local i score level name date plain
    local shown=0
    hs_load "$game"
    INTRO_ROW=$row
    if (( ${#HS_ENTRIES[@]} == 0 )); then
        _intro_row "$INTRO_ROW" "$left" "$inner" "$FG_DIM" " (no scores yet — be the first!)"
        ((INTRO_ROW++))
        return
    fi
    for i in "${!HS_ENTRIES[@]}"; do
        (( shown >= limit )) && break
        IFS='|' read -r score level name date <<< "${HS_ENTRIES[$i]}"
        plain=$(printf ' #%d  %-3s  %6d  L%-2d  %s' "$((i + 1))" "$name" "$score" "$level" "$date")
        _intro_row "$INTRO_ROW" "$left" "$inner" "$FG_LABEL" "$plain"
        ((INTRO_ROW++))
        ((shown++))
    done
}
