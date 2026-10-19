# ============================================================
# lib/tools.sh — Moodle 8–14 + hurtige Niveau-2 værktøjer
# Undermenu "Tools" fra hovedmenu valg 9
# ============================================================

# ---------- 8: Anden shebang (Python) ----------
tool_python_demo() {
    local script="${ROOT:-.}/tools/hello.py"
    cls
    hide_cursor
    draw_page_banner TOOLS "Python shebang demo"
    goto "$PAGE_MSG_ROW" 3
    printf '%s%sKører:%s %s\n\n' "$NOBG" "$FG_HINT" "$R$NOBG$FG_BYLINE" "$script"
    if [[ ! -f $script ]]; then
        printf '%s%sFil mangler:%s %s\n' "$NOBG" "$FG_EXIT" "$R" "$script"
    else
        chmod +x "$script" 2>/dev/null || true
        # Kør eksplicit med python3 (shebang virker også ved ./hello.py)
        python3 "$script" 2>&1 | while IFS= read -r line; do
            printf '%s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
        done
        printf '\n%s%sShebang i filen:%s  ' "$NOBG" "$FG_HINT" "$R"
        head -1 "$script"
        printf '%s\n' "$R"
    fi
    pause
}

# ---------- 10: Asynkronitet med & ----------
tool_async_demo() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Async with &  (≈ await)"
    local top=$PAGE_MSG_ROW
    goto "$top" 3
    printf '%s%sStarter 3 jobs i baggrunden (&) …%s\n\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    local tmp
    tmp=$(mktemp -d)

    (
        sleep 1
        echo "job-A done at $(date +%H:%M:%S)" >"$tmp/a"
    ) &
    local pid_a=$!
    (
        sleep 2
        echo "job-B done at $(date +%H:%M:%S)" >"$tmp/b"
    ) &
    local pid_b=$!
    (
        sleep 1
        echo "job-C done at $(date +%H:%M:%S)" >"$tmp/c"
    ) &
    local pid_c=$!

    printf '%s%sPIDs:%s A=%s  B=%s  C=%s\n' "$NOBG" "$FG_HINT" "$R$NOBG$FG_NUM" "$pid_a" "$pid_b" "$pid_c"
    printf '%s%sMain venter med wait (som Task.WaitAll) …%s\n\n' "$NOBG" "$FG_HINT" "$R"
    wait "$pid_a" "$pid_b" "$pid_c"
    printf '%s%sResultater:%s\n' "$NOBG" "$FG_YEL1$BOLD" "$R"
    cat "$tmp"/* 2>/dev/null | while IFS= read -r line; do
        printf '  %s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
    done
    rm -rf "$tmp"
    printf '\n%s%sForklaring:%s  & = start async · wait = synkroniser igen\n' "$NOBG" "$FG_HINT" "$R"
    pause
}

# ---------- 11: IP + DNS ----------
tool_network_info() {
    cls
    hide_cursor
    draw_page_banner TOOLS "IP address & DNS"
    local top=$PAGE_MSG_ROW ip dns
    goto "$top" 3
    printf '%s%sIP-adresse(r):%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    # Primære IPv4 (ikke loopback)
    while IFS= read -r ip; do
        [[ -z $ip ]] && continue
        printf '  %s%s%s\n' "$NOBG" "$FG_YEL1" "$ip"
    done < <(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9.]+$' || \
             ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    printf '\n%s%sDNS-server(e):%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    while IFS= read -r dns; do
        [[ -z $dns || $dns == \#* ]] && continue
        printf '  %s%s%s\n' "$NOBG" "$FG_LABEL" "$dns"
    done < <(grep -E '^(nameserver|DNS)' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | sort -u)
    # systemd-resolved fallback
    if ! grep -q nameserver /etc/resolv.conf 2>/dev/null; then
        resolvectl dns 2>/dev/null | head -5 | while IFS= read -r line; do
            printf '  %s%s%s\n' "$NOBG" "$FG_LABEL" "$line"
        done
    fi
    pause
}

# ---------- 12a: Alle åbne porte ----------
tool_ports_all() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Open / listening ports"
    goto "$PAGE_MSG_ROW" 2
    printf '%s%s%-7s %-22s %s%s\n' "$NOBG" "$FG_TITLE$BOLD" "PROTO" "LOCAL" "PROCESS" "$R"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn 2>/dev/null | awk 'NR==1{next} {printf "  %-5s %-22s %s\n", $1, $5, $7}' | head -n 40
    else
        printf '%s%sss ikke fundet%s\n' "$NOBG" "$FG_EXIT" "$R"
    fi
    pause
}

# ---------- 12b: Undersøg bestemt port ----------
tool_port_check() {
    local port="" ch msg="" msg_col=$FG_HINT
    cls
    hide_cursor
    draw_page_banner TOOLS "Check one port"
    local top=$PAGE_MSG_ROW
    goto "$top" 3
    printf '%s%sPortnummer (1–65535) + Enter · Esc = tilbage%s\n' "$NOBG" "$FG_HINT" "$R"
    ((top += 2))
    goto "$top" 3
    printf '%s%sPort: %s' "$NOBG" "$FG_YEL1$BOLD" "$R"
    show_cursor
    while IFS= read -r -s -N 1 ch; do
        if [[ $ch == $'\e' ]]; then
            hide_cursor; return
        fi
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            break
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#port} > 0 )) && port=${port:0:$((${#port}-1))}
        elif [[ $ch =~ ^[0-9]$ ]] && (( ${#port} < 5 )); then
            port+=$ch
        fi
        goto "$top" 3
        printf '%s%sPort: %s%s%s   ' "$NOBG" "$FG_YEL1$BOLD" "$port" "$R" "$NOBG"
    done
    hide_cursor
    ((top += 2))
    if [[ -z $port || ! $port =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        goto "$top" 3
        printf '%s%sUgyldigt portnummer%s\n' "$NOBG" "$FG_EXIT" "$R"
        pause; return
    fi
    goto "$top" 3
    if ss -tuln 2>/dev/null | grep -Eq "[:.]$port[[:space:]]"; then
        printf '%s%sPort %s er I BRUG (lytter)%s\n' "$NOBG" "$FG_ORANGE$BOLD" "$port" "$R"
        ss -tulpn 2>/dev/null | grep -E "[:.]$port[[:space:]]" | head -5
    else
        printf '%s%sPort %s er LEDIG (ingen listener)%s\n' "$NOBG" "$FG_YEL1$BOLD" "$port" "$R"
    fi
    pause
}

# ---------- 13: Egen grep ----------
tool_custom_grep() {
    local word="" file="" ch
    local sample="${ROOT:-.}/OPGAVE-STATUS.md"
    cls
    hide_cursor
    draw_page_banner TOOLS "Custom grep (color + count)"
    goto "$PAGE_MSG_ROW" 3
    printf '%s%sSøgeord + Enter · Esc = tilbage%s\n' "$NOBG" "$FG_HINT" "$R"
    printf '%s%s(Default-fil: OPGAVE-STATUS.md — eller pipe-demo)%s\n\n' "$NOBG" "$FG_DIM" "$R"
    local row=$((PAGE_MSG_ROW + 3))
    goto "$row" 3
    printf '%s%sOrd: %s' "$NOBG" "$FG_YEL1$BOLD" "$R"
    show_cursor
    while IFS= read -r -s -N 1 ch; do
        [[ $ch == $'\e' ]] && { hide_cursor; return; }
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            break
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#word} > 0 )) && word=${word:0:$((${#word}-1))}
        elif [[ $ch =~ [[:print:]] ]] && (( ${#word} < 40 )); then
            word+=$ch
        fi
        goto "$row" 3
        printf '%s%sOrd: %s%s%s   ' "$NOBG" "$FG_YEL1$BOLD" "$word" "$R" "$NOBG"
    done
    hide_cursor
    [[ -z $word ]] && { goto $((row + 2)) 3; printf '%s%sIntet søgeord%s\n' "$NOBG" "$FG_EXIT" "$R"; pause; return; }
    file=$sample
    [[ ! -f $file ]] && file="/etc/hosts"
    local count=0
    local RED=$'\e[38;2;255;90;90m'
    printf '\n%s%s--- Matches in %s ---%s\n' "$NOBG" "$FG_HINT" "$file" "$R"
    while IFS= read -r line; do
        # highlight (case-insensitive simple)
        local shown
        shown=$(printf '%s' "$line" | sed -E "s/(${word})/${RED}\1${R}${FG_LABEL}/Ig")
        printf '%s%s%s\n' "$NOBG" "$FG_LABEL" "$shown"
        # count occurrences on line
        local n
        n=$(printf '%s' "$line" | grep -oi "$word" 2>/dev/null | wc -l)
        count=$((count + n))
    done < <(grep -i "$word" "$file" 2>/dev/null | head -n 30)
    printf '\n%s%sTotal forekomster:%s %s%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R$NOBG$FG_YEL1" "$count" "$R"
    printf '%s%s(Pipe-eksempel: cat fil | ./tools/mygrep.sh ord)%s\n' "$NOBG" "$FG_DIM" "$R"
    pause
}

# ---------- 14: Rekursiv filliste ----------
tool_recursive_list() {
    local folder="." filter="" ch
    cls
    hide_cursor
    draw_page_banner TOOLS "Recursive file list"
    goto "$PAGE_MSG_ROW" 3
    printf '%s%sMappe (default: projekt) + Enter%s\n' "$NOBG" "$FG_HINT" "$R"
    local row=$PAGE_MSG_ROW
    ((row += 2))
    folder="${ROOT:-.}"
    goto "$row" 3
    printf '%s%sMappe: %s%s' "$NOBG" "$FG_YEL1" "$folder" "$R"
    show_cursor
    local input=""
    while IFS= read -r -s -N 1 ch; do
        [[ $ch == $'\e' ]] && { hide_cursor; return; }
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            [[ -n $input ]] && folder=$input
            break
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#input} > 0 )) && input=${input:0:$((${#input}-1))}
        elif [[ $ch =~ [[:print:]] ]] && (( ${#input} < 80 )); then
            input+=$ch
        fi
        goto "$row" 3
        printf '%s%sMappe: %s%s%s   ' "$NOBG" "$FG_YEL1" "${input:-$folder}" "$R" "$NOBG"
    done
    hide_cursor
    ((row += 2))
    goto "$row" 3
    printf '%s%sFilter (fx *.sh — Enter = alle): %s' "$NOBG" "$FG_HINT" "$R"
    show_cursor
    input=""
    while IFS= read -r -s -N 1 ch; do
        [[ $ch == $'\e' ]] && { hide_cursor; return; }
        if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
            filter=$input
            break
        fi
        if [[ $ch == $'\x7f' || $ch == $'\b' ]]; then
            (( ${#input} > 0 )) && input=${input:0:$((${#input}-1))}
        elif [[ $ch =~ [[:print:]] ]] && (( ${#input} < 40 )); then
            input+=$ch
        fi
        goto "$row" 3
        printf '%s%sFilter (fx *.sh — Enter = alle): %s%s%s   ' "$NOBG" "$FG_HINT" "$input" "$R" "$NOBG"
    done
    hide_cursor
    printf '\n\n'
    if [[ ! -d $folder ]]; then
        printf '%s%sMappe findes ikke: %s%s\n' "$NOBG" "$FG_EXIT" "$folder" "$R"
        pause; return
    fi
    local n=0
    if [[ -n $filter ]]; then
        while IFS= read -r f; do
            printf '  %s\n' "$f"
            ((n++))
            (( n >= 80 )) && break
        done < <(find "$folder" -type f -name "$filter" 2>/dev/null | head -n 80)
    else
        while IFS= read -r f; do
            printf '  %s\n' "$f"
            ((n++))
            (( n >= 80 )) && break
        done < <(find "$folder" -type f 2>/dev/null | head -n 80)
    fi
    printf '\n%s%sAntal vist:%s %s (max 80)\n' "$NOBG" "$FG_HINT" "$R$NOBG$FG_YEL1" "$n"
    pause
}

# ---------- Docker (N1.9 + N2.4) ----------
tool_docker_status() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Docker status"
    goto "$PAGE_MSG_ROW" 3
    if ! command -v docker >/dev/null 2>&1; then
        printf '%s%sDocker er IKKE installeret%s\n' "$NOBG" "$FG_ORANGE$BOLD" "$R"
        printf '%s%s(Installer docker.io / Docker Engine for at bruge dette)%s\n' "$NOBG" "$FG_DIM" "$R"
        pause; return
    fi
    if docker info >/dev/null 2>&1; then
        printf '%s%sDocker kører:%s JA\n\n' "$NOBG" "$FG_YEL1$BOLD" "$R"
    else
        printf '%s%sDocker kører:%s NEJ (daemon ikke tilgængelig)\n\n' "$NOBG" "$FG_EXIT$BOLD" "$R"
        pause; return
    fi
    local names count
    names=$(docker ps --format '{{.Names}}' 2>/dev/null)
    count=$(printf '%s\n' "$names" | grep -c . || true)
    printf '%s%sAntal kørende containere:%s %s\n' "$NOBG" "$FG_TITLE" "$R$NOBG$FG_NUM" "$count"
    printf '%s%sNavne:%s\n' "$NOBG" "$FG_TITLE" "$R"
    if (( count == 0 )); then
        printf '  %s%s(ingen)%s\n' "$NOBG" "$FG_DIM" "$R"
    else
        printf '%s\n' "$names" | while IFS= read -r n; do
            [[ -n $n ]] && printf '  %s%s%s\n' "$NOBG" "$FG_LABEL" "$n"
        done
    fi
    pause
}

# ---------- N2.1 Systemrapport ----------
tool_system_report() {
    local out="${ROOT:-.}/systemrapport.txt"
    cls
    hide_cursor
    draw_page_banner TOOLS "Systemrapport → fil"
    {
        echo "=== Systemrapport ==="
        echo "Genereret: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Operatør:  ${OWNER_NAME:-unknown} / ${COMPANY:-}"
        echo
        echo "--- Hostname ---"
        hostname
        echo
        echo "--- IP-adresse ---"
        hostname -I 2>/dev/null || ip -4 -o addr show scope global | awk '{print $4}'
        echo
        echo "--- CPU ---"
        lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\)|Thread|Core' || cat /proc/cpuinfo | head -20
        echo
        echo "--- RAM ---"
        free -h
        echo
        echo "--- Diskforbrug ---"
        df -hT -x tmpfs -x devtmpfs
        echo
        echo "--- Aktive services (running) ---"
        systemctl list-units --type=service --state=running --no-pager --plain 2>/dev/null | head -n 40
    } >"$out"
    goto "$PAGE_MSG_ROW" 3
    printf '%s%sSkrevet:%s %s\n\n' "$NOBG" "$FG_YEL1$BOLD" "$R$NOBG$FG_LABEL" "$out"
    printf '%s%sUddrag:%s\n' "$NOBG" "$FG_HINT" "$R"
    head -n 25 "$out"
    pause
}

# ---------- N2.2 Systemstatus ----------
tool_system_status() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Systemstatus (live snapshot)"
    goto "$PAGE_MSG_ROW" 3
    printf '%s%sCPU / load (uptime):%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    uptime
    printf '\n%s%sRAM (free -h):%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    free -h
    printf '\n%s%sDisk (df -h):%s\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    df -h -x tmpfs -x devtmpfs | head -n 12
    printf '\n%s%sOpdateres hver gang du vælger dette punkt.%s\n' "$NOBG" "$FG_DIM" "$R"
    pause
}

# ---------- N2.3 Fejlsøgning ----------
tool_troubleshooting() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Fejlsøgning (logs)"
    goto "$PAGE_MSG_ROW" 2
    printf '%s%sSeneste fejl/advarsler (journalctl)%s\n\n' "$NOBG" "$FG_TITLE$BOLD" "$R"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -p err..warning -n 40 --no-pager 2>/dev/null \
            || journalctl -n 40 --no-pager 2>/dev/null | grep -iE 'error|failed|warning|critical' | tail -n 40
    else
        printf '%s%sgrep i /var/log/syslog (hvis tilgængelig)%s\n' "$NOBG" "$FG_HINT" "$R"
        grep -iE 'error|failed|warning|critical' /var/log/syslog 2>/dev/null | tail -n 40 \
            || printf '%s%sIngen logadgang / tomt resultat%s\n' "$NOBG" "$FG_ORANGE" "$R"
    fi
    pause
}

# ---------- N2.6 Health Check (+ SSH stub til N3) ----------
tool_health_check() {
    cls
    hide_cursor
    draw_page_banner TOOLS "Health Check"
    local top=$PAGE_MSG_ROW
    goto "$top" 3
    printf '%s%s%-20s %s%s\n' "$NOBG" "$FG_TITLE$BOLD" "CHECK" "STATUS" "$R"
    ((top++))

    _hc_line() {
        local name=$1 status=$2 col=$3
        goto "$top" 3
        printf '%s%s%-20s %s%s%s\n' "$NOBG" "$FG_BYLINE" "$name" "$col$BOLD" "$status" "$R"
        ((top++))
    }

    # Disk
    local use
    use=$(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    if [[ -z $use ]]; then
        _hc_line "Diskplads" "FEJL" "$FG_EXIT"
    elif (( use >= 95 )); then
        _hc_line "Diskplads" "FEJL (${use}%)" "$FG_EXIT"
    elif (( use >= 85 )); then
        _hc_line "Diskplads" "ADVARSEL (${use}%)" "$FG_ORANGE"
    else
        _hc_line "Diskplads" "OK (${use}%)" "$FG_YEL1"
    fi

    # Docker
    if ! command -v docker >/dev/null 2>&1; then
        _hc_line "Docker" "ADVARSEL (ikke installeret)" "$FG_ORANGE"
    elif docker info >/dev/null 2>&1; then
        _hc_line "Docker" "OK (kører)" "$FG_YEL1"
    else
        _hc_line "Docker" "FEJL (installeret, kører ikke)" "$FG_EXIT"
    fi

    # SSH: installeret, aktiv og port hver for sig (Niveau 3 opgave 6)
    local ssh_installed=0
    if command -v sshd >/dev/null 2>&1 || systemctl list-unit-files ssh.service >/dev/null 2>&1 \
        || systemctl list-unit-files sshd.service >/dev/null 2>&1; then
        ssh_installed=1
        _hc_line "SSH installeret" "OK" "$FG_YEL1"
    else
        _hc_line "SSH installeret" "FEJL" "$FG_EXIT"
    fi
    if ssh_daemon_active; then
        _hc_line "SSH aktiv" "OK" "$FG_YEL1"
    elif (( ssh_installed )); then
        _hc_line "SSH aktiv" "FEJL" "$FG_EXIT"
    else
        _hc_line "SSH aktiv" "ADVARSEL" "$FG_ORANGE"
    fi
    if ss -tln 2>/dev/null | grep -qE ':22[[:space:]]'; then
        _hc_line "SSH port 22" "OK" "$FG_YEL1"
    elif ssh_daemon_active; then
        _hc_line "SSH port 22" "ADVARSEL" "$FG_ORANGE"
    else
        _hc_line "SSH port 22" "FEJL" "$FG_EXIT"
    fi

    # Kritiske services
    local crit_ok=1 s
    for s in cron systemd-journald NetworkManager networking; do
        systemctl cat "${s}.service" >/dev/null 2>&1 || continue
        if ! systemctl is-active --quiet "$s" 2>/dev/null; then
            # networking vs NetworkManager — skip if unit exists but inactive alternate
            crit_ok=0
        fi
    done
    # Simpel: journald skal køre
    if systemctl is-active --quiet systemd-journald 2>/dev/null; then
        if (( crit_ok )); then
            _hc_line "Kritiske services" "OK" "$FG_YEL1"
        else
            _hc_line "Kritiske services" "ADVARSEL" "$FG_ORANGE"
        fi
    else
        _hc_line "Kritiske services" "FEJL" "$FG_EXIT"
    fi

    ((top += 1))
    goto "$top" 3
    printf '%s%sOK = sundt · ADVARSEL = tjek · FEJL = handling%s\n' "$NOBG" "$FG_DIM" "$R"
    pause
}

# ---------- Tools UI / loop ----------
draw_tools_ui() {
    draw_page_banner TOOLS "Moodle 8–14 + Niveau 2" noclock
    local items=(
        "1|Python shebang"
        "2|Async & demo"
        "3|Network IP/DNS"
        "4|Vis alle åbne porte"
        "5|Undersøg bestemt port"
        "6|Custom grep"
        "7|Recursive files"
        "8|Docker status"
        "9|Systemrapport"
        "10|Systemstatus"
        "11|Fejlsøgning"
        "12|Health Check"
        "0|Back"
        "+|Quit"
    )
    local hints=(
        "Anden fortolker end Bash"
        "Baggrundsjobs med &"
        "Kun IP og DNS"
        "Vis alle lyttende porte"
        "Tjek om én port er i brug"
        "Farve + count"
        "find rekursivt + filter"
        "Kører? containere?"
        "Skriv systemrapport.txt"
        "CPU/RAM/disk snapshot"
        "Errors i journal/logs"
        "OK / ADVARSEL / FEJL"
        "Tilbage til hovedmenu"
        "Stop script"
    )
    draw_dual_box 11 items hints
}

show_tools_menu() {
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
    draw_tools_ui
    place_valg_cursor
    show_cursor
}

tools_menu() {
    MENU_MODE=tools
    while true; do
        show_tools_menu
        wait_for_choice
        case "$CHOICE_VALUE" in
            1) tool_python_demo ;;
            2) tool_async_demo ;;
            3) tool_network_info ;;
            4) tool_ports_all ;;
            5) tool_port_check ;;
            6) tool_custom_grep ;;
            7) tool_recursive_list ;;
            8) tool_docker_status ;;
            9) tool_system_report ;;
            10) tool_system_status ;;
            11) tool_troubleshooting ;;
            12) tool_health_check ;;
            0) MENU_MODE=main; return ;;
            +) quit_program ;;
            *)
                cls
                goto $(( $(rows) / 2 )) 4
                printf '%s%s%s  Invalid: %s  %s' "$BG_FOOTER" "$FG_WHITE" "$BOLD" "$CHOICE_VALUE" "$R"
                sleep 0.8
                ;;
        esac
    done
}
