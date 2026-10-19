# ============================================================
# lib/ssh.sh — Niveau 3: SSH-undermenu
# 1 status · 2 IP · 3 hjælp/guide · 4 nøgler · 5 test · 0 tilbage
# ============================================================

# Sandt hvis ssh-serveren kører (Ubuntu: ssh.service, andre: sshd.service)
ssh_daemon_active() {
    systemctl is-active --quiet ssh 2>/dev/null \
        || systemctl is-active --quiet sshd 2>/dev/null
}

_ssh_header() {
    cls
    hide_cursor
    draw_page_banner SSH "$1"
}

# Læs én linje uden at ødelægge TUI'en. Esc = afbryd (return 1).
_ssh_read_line() {
    local row=$1 prompt=$2
    local ch buf=""
    goto "$row" 3
    printf '%s%s%s%s' "$NOBG" "$FG_YEL1" "$BOLD" "$prompt"
    show_cursor
    while IFS= read -r -s -N 1 ch; do
        if [[ $ch == $'\e' ]]; then
            hide_cursor
            return 1
        fi
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            break
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#buf} > 0 )) && buf=${buf:0:$((${#buf} - 1))}
        elif [[ $ch =~ [[:print:]] ]] && (( ${#buf} < 60 )); then
            buf+=$ch
        fi
        goto "$row" 3
        printf '%s%s%s%s%s   ' "$NOBG" "$FG_YEL1" "$BOLD" "$prompt" "$buf"
    done
    hide_cursor
    SSH_LINE=$buf
    return 0
}

# ---------- 1: SSH status (krævede strenge) ----------
ssh_show_status() {
    _ssh_header "SSH status"
    local row=$PAGE_MSG_ROW
    goto "$row" 3
    if ssh_daemon_active; then
        printf '%s%s%sSSH kører%s\n' "$NOBG" "$FG_YEL1" "$BOLD" "$R"
    else
        printf '%s%s%sSSH kører ikke%s\n' "$NOBG" "$FG_EXIT" "$BOLD" "$R"
    fi
    ((row += 2))
    goto "$row" 3
    printf '%s%sTjeneste:%s  ' "$NOBG" "$FG_HINT" "$R"
    if systemctl list-unit-files ssh.service >/dev/null 2>&1; then
        systemctl is-active ssh 2>/dev/null || true
    elif systemctl list-unit-files sshd.service >/dev/null 2>&1; then
        systemctl is-active sshd 2>/dev/null || true
    else
        printf '%sikke installeret%s\n' "$FG_ORANGE" "$R"
    fi
    ((row += 2))
    goto "$row" 3
    printf '%s%sPort 22:%s\n' "$NOBG" "$FG_HINT" "$R"
    ((row++))
    if ss -tln 2>/dev/null | grep -qE ':22[[:space:]]'; then
        goto "$row" 3
        printf '%s%sSSH lytter på port 22%s\n' "$NOBG" "$FG_LABEL" "$R"
    else
        goto "$row" 3
        printf '%s%sIngen listener på port 22%s\n' "$NOBG" "$FG_ORANGE" "$R"
    fi
    pause
}

# ---------- 2: Vis IP ----------
ssh_show_ip() {
    _ssh_header "IP-adresse til SSH"
    local row=$PAGE_MSG_ROW ip
    goto "$row" 3
    printf '%s%sBrug en af adresserne med:  ssh bruger@ip%s\n' "$NOBG" "$FG_HINT" "$R"
    ((row += 2))
    local ip_start=$row
    while IFS= read -r ip; do
        [[ -z $ip ]] && continue
        goto "$row" 3
        printf '%s%s%s%s\n' "$NOBG" "$FG_YEL1" "$BOLD" "$ip"
        ((row++))
    done < <(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9.]+$' || true)
    if (( row == ip_start )); then
        goto "$row" 3
        printf '%s%sIngen IPv4-adresse fundet%s\n' "$NOBG" "$FG_EXIT" "$R"
    fi
    pause
}

# ---------- 3: Hjælp / trinvis guide ----------
ssh_show_help() {
    _ssh_header "Hvordan opretter man en SSH-forbindelse?"
    local row=$PAGE_MSG_ROW
    local -a lines=(
        "SSH er en krypteret fjernlogin. Kommandoen er:  ssh bruger@ip"
        "1. På serveren skal SSH køre (denne menu, punkt 1)."
        "2. Find serverens IP (punkt 2). Spring 127.0.0.1 over."
        "3. Fra den anden maskine:  ssh dakar2008@<ip>"
        "4. Første gang spørger SSH om host key. Skriv yes."
        "5. Log ind med nøgle (anbefalet) eller password."
        "6. Du lander i en shell på serveren. Afslut med exit."
        "Nøgle i stedet for password: punkt 4 i denne menu."
        "Test herfra uden at hænge i password: punkt 5."
    )
    local line
    for line in "${lines[@]}"; do
        goto "$row" 3
        printf '%s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
        ((row++))
    done
    pause
}

# ---------- 4: Nøgler ----------
ssh_show_keys() {
    _ssh_header "SSH-nøgler"
    local row=$PAGE_MSG_ROW
    local -a lines=(
        "Et nøglepar er to filer der hører sammen:"
        "  privat nøgle   ~/.ssh/id_ed25519      — hemmelig, bliver på din PC"
        "  offentlig nøgle ~/.ssh/id_ed25519.pub — må ligge på serveren"
        "Serveren gemmer den offentlige nøgle i ~/.ssh/authorized_keys."
        "Den private nøgle deles aldrig. Den der har den, kan logge ind som dig."
    )
    local line
    for line in "${lines[@]}"; do
        goto "$row" 3
        printf '%s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
        ((row++))
    done
    ((row++))
    goto "$row" 3
    printf '%s%s~/.ssh lige nu:%s\n' "$NOBG" "$FG_TITLE" "$BOLD"
    ((row++))
    if [[ -d $HOME/.ssh ]]; then
        while IFS= read -r line; do
            goto "$row" 3
            printf '%s%s%s\n' "$NOBG" "$FG_BYLINE" "$line"
            ((row++))
            (( row > 28 )) && break
        done < <(ls -la "$HOME/.ssh" 2>/dev/null)
    else
        goto "$row" 3
        printf '%s%sMappen findes ikke endnu%s\n' "$NOBG" "$FG_ORANGE" "$R"
        ((row++))
    fi
    ((row++))
    if [[ -f $HOME/.ssh/id_ed25519 ]]; then
        goto "$row" 3
        printf '%s%sNøgle findes. Overskriver ikke.%s\n' "$NOBG" "$FG_YEL1" "$R"
        pause
        return
    fi
    goto "$row" 3
    printf '%s%sTryk g + Enter for at køre ssh-keygen (ed25519). Esc = nej.%s\n' \
        "$NOBG" "$FG_HINT" "$R"
    if ! _ssh_read_line $((row + 1)) "Valg: "; then
        return
    fi
    if [[ $SSH_LINE != g && $SSH_LINE != G ]]; then
        pause
        return
    fi
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "bash-opgave" >/tmp/ssh-keygen.out 2>&1
    local rc=$?
    ((row += 3))
    goto "$row" 3
    if (( rc == 0 )); then
        printf '%s%sNøgle oprettet: ~/.ssh/id_ed25519%s\n' "$NOBG" "$FG_YEL1" "$BOLD"
    else
        printf '%s%sssh-keygen fejlede (se /tmp/ssh-keygen.out)%s\n' "$NOBG" "$FG_EXIT" "$R"
    fi
    pause
}

# ---------- 5: Test forbindelse (BatchMode, så password-prompt ikke hænger) ----------
ssh_test_connection() {
    _ssh_header "Test SSH-forbindelse"
    local row=$PAGE_MSG_ROW
    goto "$row" 3
    printf '%s%sSkriv bruger@ip  ·  Esc = tilbage%s\n' "$NOBG" "$FG_HINT" "$R"
    ((row += 2))
    goto "$row" 3
    printf '%s%sEksempel:  dakar2008@127.0.0.1%s\n' "$NOBG" "$FG_DIM" "$R"
    if ! _ssh_read_line $((row + 2)) "ssh "; then
        return
    fi
    local target=$SSH_LINE
    ((row += 4))
    if [[ ! $target =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9.:_-]+$ ]]; then
        goto "$row" 3
        printf '%s%sFormatet skal være bruger@vært%s\n' "$NOBG" "$FG_EXIT" "$R"
        pause
        return
    fi
    goto "$row" 3
    printf '%s%skører: ssh -o BatchMode=yes -o ConnectTimeout=5 %s%s\n' \
        "$NOBG" "$FG_HINT" "$target" "$R"
    ((row += 2))
    local out
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "$target" 'echo SSH_OK; hostname' 2>&1) || true
    while IFS= read -r line; do
        goto "$row" 3
        printf '%s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
        ((row++))
        (( row > 30 )) && break
    done <<< "$out"
    ((row++))
    goto "$row" 3
    if grep -q SSH_OK <<< "$out"; then
        printf '%s%sForbindelsen virker med nøgle.%s\n' "$NOBG" "$FG_YEL1" "$BOLD"
    else
        printf '%s%sIngen nøgle-login. Password kræver en rigtig terminal: ssh %s%s\n' \
            "$NOBG" "$FG_ORANGE" "$target" "$R"
    fi
    pause
}

draw_ssh_ui() {
    draw_page_banner SSH "Fjernadministration · Niveau 3" noclock
    local items=(
        "1|Vis SSH status"
        "2|Vis IP-adresse"
        "3|Hvordan opretter man en SSH-forbindelse?"
        "4|SSH-nøgler"
        "5|Test forbindelse"
        "0|Tilbage"
        "+|Quit"
    )
    local hints=(
        "SSH kører eller kører ikke"
        "Adressen til ssh bruger@ip"
        "Trin for trin"
        "Offentlig og privat nøgle"
        "Prøv ssh bruger@ip"
        "Tilbage til hovedmenu"
        "Stop programmet"
    )
    draw_dual_box 11 items hints
}

show_ssh_menu() {
    local h w
    NEED_REDRAW=0
    while true; do
        h=$(rows); w=$(cols)
        if (( h >= 36 && w >= 76 )); then break; fi
        cls
        echo "Terminal for lille (min. 76x36). Nu: ${w}x${h}"
        show_cursor
        while true; do
            if read -r -t 0.25 _; then break; fi
            if (( NEED_REDRAW )); then NEED_REDRAW=0; break; fi
        done
        hide_cursor
    done
    hide_cursor
    cls
    draw_ssh_ui
    place_valg_cursor
    show_cursor
}

ssh_menu() {
    MENU_MODE=ssh
    while true; do
        show_ssh_menu
        wait_for_choice
        case "$CHOICE_VALUE" in
            1) ssh_show_status ;;
            2) ssh_show_ip ;;
            3) ssh_show_help ;;
            4) ssh_show_keys ;;
            5) ssh_test_connection ;;
            0) MENU_MODE=main; return ;;
            +) quit_program ;;
            '!!') quit_fast ;;
            *)
                cls
                goto $(( $(rows) / 2 )) 4
                printf '%s%s%s  Invalid: %s  %s' "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$CHOICE_VALUE" "$R"
                sleep 0.8
                ;;
        esac
    done
}
