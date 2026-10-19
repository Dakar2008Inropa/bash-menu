# ============================================================
# lib/system.sh — System-sider (opgave 2–7): Processes … Users
# Sources efter lib/tui.sh
# ============================================================

# ---------- Processes (opgave 2): live liste, bashtop-agtig ----------
list_processes() {
    local w h top max_rows offset=0 total=0 dirty=1
    local -a procs
    local header ctrl line pid user cpu mem cmd
    local i row left inner col_pid col_user col_cpu col_mem col_cmd
    local sort_key="pcpu"   # pcpu | pmem | pid

    _proc_load() {
        procs=()
        local fmt sortf
        case $sort_key in
            pmem) sortf=-pmem ;;
            pid)  sortf=pid ;;
            *)    sortf=-pcpu ;;
        esac
        # pid user cpu mem command — kommando trimmes ved tegning
        while IFS= read -r line; do
            [[ -z $line ]] && continue
            procs+=("$line")
        done < <(ps -eo pid=,user=,pcpu=,pmem=,comm= --sort="$sortf" 2>/dev/null)
        total=${#procs[@]}
        (( offset > total - 1 )) && offset=0
        (( offset < 0 )) && offset=0
    }

    _proc_paint() {
        local idx shown end
        w=$(cols); h=$(rows)
        top=$PAGE_MSG_ROW
        max_rows=$(( h - top - 4 ))
        (( max_rows < 5 )) && max_rows=5
        left=2
        inner=$(( w - 4 ))
        (( inner < 40 )) && inner=40

        # Kolonnebredder (fast, så listen ikke hopper)
        col_pid=7
        col_user=10
        col_cpu=6
        col_mem=6
        col_cmd=$(( inner - col_pid - col_user - col_cpu - col_mem - 4 ))
        (( col_cmd < 8 )) && col_cmd=8

        cls
        hide_cursor
        draw_page_banner PROCESSES "Running processes"
        top=$PAGE_MSG_ROW

        # Header
        goto "$top" "$left"
        printf '%s%s%s%-*s %-*s %-*s %-*s %-*s%s' \
            "$NOBG" "$FG_TITLE" "$BOLD" \
            "$col_pid" "PID" "$col_user" "USER" \
            "$col_cpu" "CPU%" "$col_mem" "MEM%" \
            "$col_cmd" "COMMAND" "$R"
        ((top++))
        goto "$top" "$left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$(repeat '─' "$inner")" "$R"
        ((top++))

        end=$(( offset + max_rows ))
        (( end > total )) && end=$total
        shown=0
        for ((idx = offset; idx < end; idx++)); do
            line=${procs[idx]}
            # ps: leading spaces on pid — trim + split
            read -r pid user cpu mem cmd <<<"$line"
            # Truncér kommando til kolonne
            if (( ${#cmd} > col_cmd )); then
                cmd="${cmd:0:$((col_cmd - 2))}.."
            fi
            goto $((top + shown)) "$left"
            printf '%s%s%-*s %s%-*s %s%*s %s%*s %s%-*s%s' \
                "$NOBG" "$FG_NUM" "$col_pid" "$pid" \
                "$FG_LABEL" "$col_user" "${user:0:$col_user}" \
                "$FG_YEL1" "$col_cpu" "$cpu" \
                "$FG_ORANGE" "$col_mem" "$mem" \
                "$FG_BYLINE" "$col_cmd" "$cmd" "$R"
            ((shown++))
        done

        # Ryd resten af listen (undgå ghost-linjer efter refresh)
        for ((i = shown; i < max_rows; i++)); do
            goto $((top + i)) "$left"
            printf '%s%s' "$NOBG" "$(repeat ' ' "$inner")"
        done

        ctrl="R refresh   J up  K down   1 CPU   2 MEM   3 PID   Enter/Q back"
        goto $((h - 3)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        local cl=$(( (w - ${#ctrl}) / 2 ))
        (( cl < 1 )) && cl=1
        goto $((h - 3)) "$cl"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl" "$R"

        # Status: antal + sort
        local st="showing $((offset + 1))-$((offset + shown > 0 ? offset + shown : 0)) / $total   sort: $sort_key"
        goto $((h - 2)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        local sl=$(( (w - ${#st}) / 2 ))
        (( sl < 1 )) && sl=1
        goto $((h - 2)) "$sl"
        printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$st" "$R"
    }

    _proc_load
    while true; do
        if (( dirty )); then
            _proc_paint
            dirty=0
        fi
        # Vent på tast (ingen busy redraw → ingen flimmer)
        local c1="" c2="" c3=""
        if ! IFS= read -r -s -N 1 -t 0.4 c1; then
            (( CLOCK_ROW > 0 )) && paint_clock
            (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
            continue
        fi
        if [[ $c1 == $'\e' ]]; then
            IFS= read -r -s -N 1 -t 0.03 c2 || true
            if [[ $c2 == '[' || $c2 == O ]]; then
                IFS= read -r -s -N 1 -t 0.03 c3 || true
                case $c3 in
                    A|D)  # up / left
                        (( offset > 0 )) && ((offset--)) && dirty=1
                        ;;
                    B|C)  # down / right
                        (( offset + max_rows < total )) && ((offset++)) && dirty=1
                        ;;
                esac
            fi
            continue
        fi
        [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]] && return
        case $c1 in
            q|Q|0) return ;;
            r|R)
                _proc_load
                dirty=1
                ;;
            # J = op, K = ned (W/S og pile følger samme retning)
            j|J|w|W)
                (( offset > 0 )) && ((offset--)) && dirty=1
                ;;
            k|K|s|S)
                (( offset + max_rows < total )) && ((offset++)) && dirty=1
                ;;
            1) sort_key=pcpu; offset=0; _proc_load; dirty=1 ;;
            2) sort_key=pmem; offset=0; _proc_load; dirty=1 ;;
            3) sort_key=pid;  offset=0; _proc_load; dirty=1 ;;
        esac
    done
}

# ---------- Kill Process: PID + bekræftelse ----------
kill_process() {
    local w h top left
    local pid_in="" target_pid="" target_user="" target_cmd=""
    local msg="" msg_col=$FG_LABEL
    local phase=input   # input | confirm | done
    local dirty=1
    local line="" ch=""

    _kill_center() {
        local row=$1 len=$2; shift 2
        local col=$(( (w - len) / 2 ))
        (( col < 1 )) && col=1
        goto "$row" "$col"
        printf '%s' "$NOBG"
        printf "$@"
        printf '%s' "$R"
    }

    _kill_blank() {
        goto "$1" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    }

    _kill_lookup() {
        target_pid=""
        target_user=""
        target_cmd=""
        local raw
        raw=$(ps -p "$1" -o pid=,user=,comm= 2>/dev/null) || return 1
        [[ -z $raw ]] && return 1
        read -r target_pid target_user target_cmd <<<"$raw"
        [[ -n $target_pid ]] || return 1
        return 0
    }

    _kill_paint() {
        w=$(cols); h=$(rows)
        cls
        hide_cursor
        draw_page_banner KILL "Stop a process"
        top=$PAGE_MSG_ROW
        left=4

        case $phase in
            input)
                _kill_blank "$top"
                _kill_center "$top" 28 '%s%sEnter PID to stop' "$FG_TITLE" "$BOLD"
                ((top += 2))
                local pid_vis=$(( 5 + ${#pid_in} ))   # "PID: " + digits
                _kill_blank "$top"
                _kill_center "$top" "$pid_vis" '%sPID: %s%s%s' \
                    "$FG_HINT" "$FG_YEL1" "$BOLD" "$pid_in"
                local pid_row=$top
                ((top += 2))
                if [[ -n $msg ]]; then
                    _kill_blank "$top"
                    _kill_center "$top" "${#msg}" '%s%s' "$msg_col" "$msg"
                fi
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _kill_center $((h - 3)) 46 '%sDigits + Enter   Backspace erase   Q cancel' "$FG_DIM"
                # Markør lige efter sidste ciffer
                local pc=$(( (w - pid_vis) / 2 + pid_vis ))
                (( pc < 1 )) && pc=1
                goto "$pid_row" "$pc"
                show_cursor
                ;;
            confirm)
                hide_cursor
                _kill_blank "$top"
                _kill_center "$top" 22 '%s%sConfirm kill' "$FG_EXIT" "$BOLD"
                ((top += 2))
                local info="PID $target_pid   USER $target_user   CMD $target_cmd"
                _kill_blank "$top"
                _kill_center "$top" "${#info}" '%s%s' "$FG_BYLINE" "$info"
                ((top += 2))
                _kill_blank "$top"
                _kill_center "$top" 36 '%sSend SIGTERM to this process?' "$FG_LABEL"
                ((top += 2))
                _kill_blank "$top"
                _kill_center "$top" 18 '%s%sY%s yes    %s%sN%s no' \
                    "$FG_YEL1" "$BOLD" "$R$NOBG$FG_DIM" \
                    "$FG_EXIT" "$BOLD" "$R$NOBG$FG_DIM"
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _kill_center $((h - 3)) 28 '%sY confirm   N / Q cancel' "$FG_DIM"
                ;;
            done)
                hide_cursor
                _kill_blank "$top"
                _kill_center "$top" "${#msg}" '%s%s%s' "$msg_col" "$BOLD" "$msg"
                ((top += 2))
                if [[ -n $target_cmd ]]; then
                    local det="was: PID $target_pid ($target_cmd)"
                    _kill_blank "$top"
                    _kill_center "$top" "${#det}" '%s%s' "$FG_DIM" "$det"
                fi
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _kill_center $((h - 3)) 22 '%sEnter / Q return' "$FG_DIM"
                ;;
        esac
    }

    while true; do
        if (( dirty )); then
            _kill_paint
            dirty=0
        fi

        case $phase in
            input)
                # Læs ét tegn ad gangen (synligt PID-felt)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                    if [[ -z $pid_in ]]; then
                        msg="Enter a PID first"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if [[ ! $pid_in =~ ^[0-9]+$ ]]; then
                        msg="PID must be digits only"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if (( pid_in == 1 )); then
                        msg="Refusing to kill PID 1 (init)"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if (( pid_in == $$ )); then
                        msg="Refusing to kill this menu (PID $$)"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if ! _kill_lookup "$pid_in"; then
                        msg="No process with PID $pid_in"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    phase=confirm
                    msg=""
                    dirty=1
                    continue
                fi
                case $ch in
                    q|Q)
                        hide_cursor
                        return
                        ;;
                    $'\x7f'|$'\b')
                        (( ${#pid_in} > 0 )) && pid_in=${pid_in:0:$((${#pid_in} - 1))}
                        msg=""; dirty=1
                        ;;
                    [0-9])
                        (( ${#pid_in} < 10 )) && pid_in+="$ch"
                        msg=""; dirty=1
                        ;;
                esac
                ;;
            confirm)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]] && continue
                case $ch in
                    y|Y)
                        hide_cursor
                        if kill "$target_pid" 2>/dev/null; then
                            # Kort pause så ps kan opdatere
                            sleep 0.15
                            if kill -0 "$target_pid" 2>/dev/null; then
                                msg="Signal sent — process still running (try later / no permission?)"
                                msg_col=$FG_ORANGE
                            else
                                msg="Process $target_pid terminated"
                                msg_col=$FG_YEL1
                            fi
                        else
                            msg="Kill failed — permission denied or already gone"
                            msg_col=$FG_EXIT
                        fi
                        phase=done
                        dirty=1
                        ;;
                    n|N|q|Q)
                        phase=input
                        pid_in=""
                        msg="Cancelled"
                        msg_col=$FG_HINT
                        dirty=1
                        ;;
                esac
                ;;
            done)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                [[ -z $ch || $ch == $'\n' || $ch == $'\r' || $ch == q || $ch == Q ]] && {
                    hide_cursor
                    return
                }
                ;;
        esac
    done
}

# ---------- System Info: CPU, RAM, disk ----------
system_info() {
    local w h top left dirty=1
    local host os kern cpu_model cpu_n load1 load5 load15
    local mem_total mem_used mem_avail mem_pct
    local swap_total swap_used up_str
    local -a disks
    local bar_w=28

    _sys_bar() {
        # _sys_bar pct → [########----]
        local pct=$1 i filled
        (( pct < 0 )) && pct=0
        (( pct > 100 )) && pct=100
        filled=$(( pct * bar_w / 100 ))
        printf '['
        for ((i = 0; i < bar_w; i++)); do
            if (( i < filled )); then printf '#'; else printf '-'; fi
        done
        printf '] %3d%%' "$pct"
    }

    _sys_load() {
        host=$(hostname 2>/dev/null || echo unknown)
        os=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}")
        kern=$(uname -sr 2>/dev/null)
        cpu_n=$(nproc 2>/dev/null || echo '?')
        cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ { gsub(/^[ \t]+/, "", $2); print $2; exit }')
        [[ -z $cpu_model ]] && cpu_model="CPU × $cpu_n"
        read -r load1 load5 load15 _ </proc/loadavg

        # Mem i MiB fra /proc/meminfo (stabilt til %)
        local mt ma mf mb
        mt=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
        ma=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
        (( mt < 1 )) && mt=1
        mem_used=$(( mt - ma ))
        mem_total=$mt
        mem_avail=$ma
        mem_pct=$(( mem_used * 100 / mt ))

        swap_total=$(awk '/SwapTotal:/ {print int($2/1024)}' /proc/meminfo)
        swap_used=$(awk '/SwapTotal:/ {t=$2} /SwapFree:/ {print int((t-$2)/1024)}' /proc/meminfo)

        up_str=$(uptime -p 2>/dev/null || awk '{printf "up %.0f min", $1/60}' /proc/uptime)

        disks=()
        local line
        while IFS= read -r line; do
            [[ -z $line || $line == Filesystem* ]] && continue
            disks+=("$line")
        done < <(df -hT -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null)
    }

    _sys_paint() {
        local row line label val
        w=$(cols); h=$(rows)
        cls
        hide_cursor
        draw_page_banner SYSTEM "CPU · RAM · Disk"
        top=$PAGE_MSG_ROW
        left=3

        _sys_row() {
            # _sys_row "LABEL" "value" [color]
            local lab=$1 val=$2 col=${3:-$FG_BYLINE}
            goto "$row" "$left"
            printf '%s%s%-10s%s %s%s%s' "$NOBG" "$FG_HINT" "$lab" "$R$NOBG" "$col" "$val" "$R"
            ((row++))
        }

        row=$top
        _sys_row "Host" "$host" "$FG_YEL1"
        _sys_row "OS" "$os"
        _sys_row "Kernel" "$kern"
        _sys_row "Uptime" "$up_str" "$FG_LABEL"
        ((row++))

        goto "$row" "$left"
        printf '%s%s%sCPU%s' "$NOBG" "$FG_TITLE" "$BOLD" "$R"
        ((row++))
        # Truncér model hvis nødvendig
        local cm=$cpu_model
        if (( ${#cm} > w - 16 )); then
            cm="${cm:0:$((w - 18))}.."
        fi
        _sys_row "Model" "$cm"
        _sys_row "Cores" "$cpu_n logical"
        _sys_row "Load" "$load1  $load5  $load15   (1 / 5 / 15 min)" "$FG_ORANGE"
        ((row++))

        goto "$row" "$left"
        printf '%s%s%sMEMORY%s' "$NOBG" "$FG_TITLE" "$BOLD" "$R"
        ((row++))
        local mem_line bar
        bar=$(_sys_bar "$mem_pct")
        mem_line=$(printf '%s MiB used / %s MiB   avail %s MiB' "$mem_used" "$mem_total" "$mem_avail")
        _sys_row "Usage" "$mem_line"
        goto "$row" "$left"
        printf '%s%s%-10s%s ' "$NOBG" "$FG_HINT" "" "$R$NOBG"
        if (( mem_pct >= 90 )); then
            printf '%s%s%s' "$FG_EXIT" "$bar" "$R"
        elif (( mem_pct >= 70 )); then
            printf '%s%s%s' "$FG_ORANGE" "$bar" "$R"
        else
            printf '%s%s%s' "$FG_YEL1" "$bar" "$R"
        fi
        ((row++))
        if (( swap_total > 0 )); then
            _sys_row "Swap" "$(printf '%s / %s MiB used' "$swap_used" "$swap_total")"
        fi
        ((row++))

        goto "$row" "$left"
        printf '%s%s%sDISK%s' "$NOBG" "$FG_TITLE" "$BOLD" "$R"
        ((row++))
        goto "$row" "$left"
        printf '%s%s%-12s %-6s %6s %6s %6s %4s  %s%s' \
            "$NOBG" "$FG_DIM" "Filesystem" "Type" "Size" "Used" "Avail" "Use%" "Mount" "$R"
        ((row++))

        local fs typ size used avail usep mount rest
        local max_disk=$(( h - row - 3 ))
        (( max_disk < 1 )) && max_disk=1
        local di=0
        for line in "${disks[@]}"; do
            (( di >= max_disk )) && break
            # df -hT: Filesystem Type Size Used Avail Use% Mounted
            read -r fs typ size used avail usep mount <<<"$line"
            [[ -z $fs ]] && continue
            goto "$row" "$left"
            printf '%s%s%-12s %s%-6s %s%6s %s%6s %s%6s %s%4s  %s%s%s' \
                "$NOBG" "$FG_NUM" "${fs:0:12}" \
                "$FG_HINT" "${typ:0:6}" \
                "$FG_BYLINE" "$size" \
                "$FG_BYLINE" "$used" \
                "$FG_BYLINE" "$avail" \
                "$FG_ORANGE" "$usep" \
                "$FG_LABEL" "$mount" "$R"
            ((row++)); ((di++))
        done

        local ctrl="R refresh     Enter / Q back"
        goto $((h - 2)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        local cl=$(( (w - ${#ctrl}) / 2 ))
        (( cl < 1 )) && cl=1
        goto $((h - 2)) "$cl"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl" "$R"
    }

    _sys_load
    while true; do
        if (( dirty )); then
            _sys_paint
            dirty=0
        fi
        local c1=""
        if ! IFS= read -r -s -N 1 -t 0.4 c1; then
            (( CLOCK_ROW > 0 )) && paint_clock
            (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
            continue
        fi
        [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]] && return
        case $c1 in
            q|Q|0) return ;;
            r|R)
                _sys_load
                dirty=1
                ;;
        esac
    done
}

# ---------- Services: systemd-liste ----------
list_services() {
    local w h top left dirty=1
    local filter=running   # running | failed | all
    local -a svcs
    local total=0 offset=0 max_rows=10
    local n_run=0 n_fail=0

    _svc_load() {
        svcs=()
        local unit load active sub desc state_arg
        case $filter in
            failed) state_arg=--state=failed ;;
            all)    state_arg=--all ;;
            *)      state_arg=--state=running ;;
        esac
        # Format: UNIT|ACTIVE|DESCRIPTION  (ikke "IFS= read" — det slår split fra)
        while read -r unit load active sub desc; do
            [[ -z $unit ]] && continue
            unit=${unit#●}
            svcs+=("${unit%.service}|${active}|${desc}")
        done < <(systemctl list-units --type=service $state_arg --no-legend --no-pager --plain 2>/dev/null)
        total=${#svcs[@]}
        (( offset > 0 && offset >= total )) && offset=$(( total > 0 ? total - 1 : 0 ))
        (( offset < 0 )) && offset=0

        n_run=$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | wc -l)
        n_fail=$(systemctl list-units --type=service --state=failed --no-legend --no-pager 2>/dev/null | wc -l)
        n_run=${n_run// /}
        n_fail=${n_fail// /}
    }

    _svc_paint() {
        local idx shown end line unit active desc short stcol rest
        local col_unit=28 col_state=10 col_desc
        w=$(cols); h=$(rows)
        cls
        hide_cursor
        draw_page_banner SERVICES "systemd services"
        top=$PAGE_MSG_ROW
        left=2
        max_rows=$(( h - top - 5 ))
        (( max_rows < 5 )) && max_rows=5
        col_desc=$(( w - left - col_unit - col_state - 4 ))
        (( col_desc < 10 )) && col_desc=10

        goto "$top" "$left"
        printf '%s%sFilter:%s %s%s%-8s%s  %srunning:%s %s%s%s  %sfailed:%s %s%s%s' \
            "$NOBG" "$FG_HINT" "$R$NOBG" \
            "$FG_YEL1" "$BOLD" "$filter" "$R$NOBG" \
            "$FG_HINT" "$R$NOBG" "$FG_LABEL" "$n_run" "$R$NOBG" \
            "$FG_HINT" "$R$NOBG" "$FG_EXIT" "$n_fail" "$R"
        ((top++))
        goto "$top" "$left"
        printf '%s%s%-*s %-*s %-*s%s' \
            "$NOBG" "$FG_TITLE$BOLD" \
            "$col_unit" "UNIT" "$col_state" "STATE" "$col_desc" "DESCRIPTION" "$R"
        ((top++))
        goto "$top" "$left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$(repeat '─' $((w - left - 1)))" "$R"
        ((top++))

        end=$(( offset + max_rows ))
        (( end > total )) && end=$total
        shown=0
        for ((idx = offset; idx < end; idx++)); do
            line=${svcs[idx]}
            unit=${line%%|*}
            rest=${line#*|}
            active=${rest%%|*}
            desc=${rest#*|}
            short=$unit
            (( ${#short} > col_unit )) && short="${short:0:$((col_unit - 2))}.."
            (( ${#desc} > col_desc )) && desc="${desc:0:$((col_desc - 2))}.."

            stcol=$FG_LABEL
            case $active in
                active)   stcol=$FG_YEL1 ;;
                failed)   stcol=$FG_EXIT ;;
                inactive) stcol=$FG_DIM ;;
            esac

            goto $((top + shown)) "$left"
            printf '%s%s%-*s %s%-*s %s%-*s%s' \
                "$NOBG" "$FG_NUM" "$col_unit" "$short" \
                "$stcol" "$col_state" "${active:-?}" \
                "$FG_BYLINE" "$col_desc" "$desc" "$R"
            ((shown++))
        done

        local i
        for ((i = shown; i < max_rows; i++)); do
            goto $((top + i)) "$left"
            printf '%s%s' "$NOBG" "$(repeat ' ' $((w - left - 1)))"
        done

        local from=0 to=0
        if (( total > 0 )); then
            from=$(( offset + 1 ))
            to=$(( offset + shown ))
        fi
        local st="showing $from-$to / $total"
        local ctrl="R refresh   J up  K down   1 running   2 failed   3 all   Enter/Q back"
        goto $((h - 3)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        local cl=$(( (w - ${#ctrl}) / 2 ))
        (( cl < 1 )) && cl=1
        goto $((h - 3)) "$cl"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl" "$R"
        goto $((h - 2)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        local sl=$(( (w - ${#st}) / 2 ))
        (( sl < 1 )) && sl=1
        goto $((h - 2)) "$sl"
        printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$st" "$R"
    }

    _svc_load
    while true; do
        if (( dirty )); then
            _svc_paint
            dirty=0
        fi
        local c1="" c2="" c3=""
        if ! IFS= read -r -s -N 1 -t 0.4 c1; then
            (( CLOCK_ROW > 0 )) && paint_clock
            (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
            continue
        fi
        if [[ $c1 == $'\e' ]]; then
            IFS= read -r -s -N 1 -t 0.03 c2 || true
            if [[ $c2 == '[' || $c2 == O ]]; then
                IFS= read -r -s -N 1 -t 0.03 c3 || true
                case $c3 in
                    A|D) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
                    B|C) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
                esac
            fi
            continue
        fi
        [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]] && return
        case $c1 in
            q|Q|0) return ;;
            r|R) _svc_load; dirty=1 ;;
            # J = op, K = ned (W/S og pile følger samme retning)
            j|J|w|W) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
            k|K|s|S) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
            1) filter=running; offset=0; _svc_load; dirty=1 ;;
            2) filter=failed;  offset=0; _svc_load; dirty=1 ;;
            3) filter=all;     offset=0; _svc_load; dirty=1 ;;
        esac
    done
}

# ---------- Find File: søg filnavn med find ----------
find_file() {
    local w h top left dirty=1
    local phase=input   # input | results
    local query=""
    local root_key=home # home | project | rootfs
    local search_root="$HOME"
    # ROOT sættes i menu.sh (projektrod). Fallback hvis funktionen testes alene.
    local project_root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local -a hits
    local total=0 offset=0 max_rows=10
    local msg="" msg_col=$FG_LABEL

    _find_set_root() {
        case $root_key in
            project) search_root=$project_root ;;
            rootfs)  search_root=/ ;;
            *)       search_root=$HOME; root_key=home ;;
        esac
    }

    _find_center() {
        local row=$1 len=$2; shift 2
        local col=$(( (w - len) / 2 ))
        (( col < 1 )) && col=1
        goto "$row" "$col"
        printf '%s' "$NOBG"
        printf "$@"
        printf '%s' "$R"
    }

    _find_blank() {
        goto "$1" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    }

    # hits[] = "path|size|date"  (size human, date = birth eller mtime*)
    _find_humansize() {
        local b=$1
        if ! [[ $b =~ ^[0-9]+$ ]]; then
            printf '%s' "$b"
            return
        fi
        # numfmt hvis tilgængelig (IEC: 1K=1024)
        if command -v numfmt >/dev/null 2>&1; then
            numfmt --to=iec --suffix=B "$b" 2>/dev/null | sed 's/B$//'
            return
        fi
        local u=(B K M G T) i=0 n=$b
        while (( n >= 1024 && i < ${#u[@]} - 1 )); do
            n=$(( (n + 512) / 1024 ))
            ((i++))
        done
        printf '%d%s' "$n" "${u[i]}"
    }

    _find_meta_line() {
        # stdout: path|SIZE|DATE   DATE = YYYY-MM-DD HH:MM  (* = mtime fallback)
        local path=$1 size_raw size date birth mtime
        if [[ -d $path ]]; then
            size=DIR
        elif [[ -L $path ]]; then
            size=LINK
        else
            size_raw=$(stat -c '%s' "$path" 2>/dev/null || echo '?')
            size=$(_find_humansize "$size_raw")
        fi
        birth=$(stat -c '%w' "$path" 2>/dev/null || echo '-')
        if [[ -n $birth && $birth != '-' ]]; then
            date=$(date -d "$birth" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%.16s' "$birth")
        else
            mtime=$(stat -c '%y' "$path" 2>/dev/null || echo '')
            if [[ -n $mtime ]]; then
                date=$(date -d "$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%.16s' "$mtime")
                date="${date}*"
            else
                date='?'
            fi
        fi
        printf '%s|%s|%s' "$path" "$size" "$date"
    }

    _find_run() {
        hits=()
        total=0
        offset=0
        _find_set_root
        local pat="*${query}*"
        local depth=8
        local max_hits=150
        [[ $root_key == rootfs ]] && depth=4

        local line path
        while IFS= read -r path; do
            [[ -z $path ]] && continue
            hits+=("$(_find_meta_line "$path")")
        done < <(
            find "$search_root" -maxdepth "$depth" -iname "$pat" \
                \( -type f -o -type d -o -type l \) \
                2>/dev/null | head -n "$max_hits"
        )
        total=${#hits[@]}
        if (( total == 0 )); then
            msg="No matches for \"$query\" under $search_root"
            msg_col=$FG_ORANGE
        else
            msg="$total hit(s)  root=$root_key  depth<=$depth  max=$max_hits  (* = mtime)"
            msg_col=$FG_YEL1
        fi
    }

    _find_paint() {
        w=$(cols); h=$(rows)
        cls
        hide_cursor
        draw_page_banner FIND "Search by filename"
        top=$PAGE_MSG_ROW
        left=2

        case $phase in
            input)
                local root_label
                case $root_key in
                    project) root_label="project" ;;
                    rootfs)  root_label="/ (shallow)" ;;
                    *)       root_label="home" ;;
                esac

                _find_blank "$top"
                _find_center "$top" 26 '%s%sSearch filename' "$FG_TITLE" "$BOLD"
                ((top += 2))
                _find_blank "$top"
                local qvis=$(( 7 + ${#query} ))
                _find_center "$top" "$qvis" '%sQuery: %s%s%s' "$FG_HINT" "$FG_YEL1" "$BOLD" "$query"
                local qrow=$top
                ((top += 2))
                _find_blank "$top"
                _find_center "$top" $(( 6 + ${#root_label} )) '%sRoot: %s%s' "$FG_HINT" "$FG_LABEL" "$root_label"
                ((top += 1))
                _find_blank "$top"
                _find_center "$top" ${#search_root} '%s%s' "$FG_DIM" "$search_root"
                ((top += 2))
                if [[ -n $msg ]]; then
                    _find_blank "$top"
                    _find_center "$top" "${#msg}" '%s%s' "$msg_col" "$msg"
                fi

                local ctrl="Enter search   Tab change root   Backspace   Esc back"
                goto $((h - 2)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                local cl=$(( (w - ${#ctrl}) / 2 ))
                (( cl < 1 )) && cl=1
                goto $((h - 2)) "$cl"
                printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl" "$R"

                local pc=$(( (w - qvis) / 2 + qvis ))
                (( pc < 1 )) && pc=1
                goto "$qrow" "$pc"
                show_cursor
                ;;
            results)
                local idx shown end path size date showp rest line i from=0 to=0
                local col_size=7 col_date=17 col_path
                max_rows=$(( h - top - 6 ))
                (( max_rows < 5 )) && max_rows=5
                col_path=$(( w - left - col_size - col_date - 3 ))
                (( col_path < 12 )) && col_path=12

                goto "$top" "$left"
                printf '%s%s%s%s' "$NOBG" "$msg_col" "$msg" "$R"
                ((top++))
                goto "$top" "$left"
                printf '%s%s%-*s %-*s %-*s%s' \
                    "$NOBG" "$FG_TITLE$BOLD" \
                    "$col_size" "SIZE" "$col_date" "CREATED" "$col_path" "PATH" "$R"
                ((top++))
                goto "$top" "$left"
                printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$(repeat '─' $((w - left - 1)))" "$R"
                ((top++))

                end=$(( offset + max_rows ))
                (( end > total )) && end=$total
                shown=0
                for ((idx = offset; idx < end; idx++)); do
                    line=${hits[idx]}
                    path=${line%%|*}; rest=${line#*|}
                    size=${rest%%|*}; date=${rest#*|}
                    showp=$path
                    [[ -d $path ]] && showp="${showp}/"
                    if (( ${#showp} > col_path )); then
                        showp="..${showp:$(( ${#showp} - (col_path - 2) ))}"
                    fi
                    (( ${#size} > col_size )) && size="${size:0:$col_size}"
                    (( ${#date} > col_date )) && date="${date:0:$col_date}"
                    goto $((top + shown)) "$left"
                    if [[ -d $path ]]; then
                        printf '%s%s%-*s %s%-*s %s%-*s%s' \
                            "$NOBG" "$FG_NUM" "$col_size" "$size" \
                            "$FG_HINT" "$col_date" "$date" \
                            "$FG_NUM" "$col_path" "$showp" "$R"
                    else
                        printf '%s%s%-*s %s%-*s %s%-*s%s' \
                            "$NOBG" "$FG_YEL1" "$col_size" "$size" \
                            "$FG_HINT" "$col_date" "$date" \
                            "$FG_BYLINE" "$col_path" "$showp" "$R"
                    fi
                    ((shown++))
                done
                for ((i = shown; i < max_rows; i++)); do
                    goto $((top + i)) "$left"
                    printf '%s%s' "$NOBG" "$(repeat ' ' $((w - left - 1)))"
                done

                (( total > 0 )) && { from=$(( offset + 1 )); to=$(( offset + shown )); }
                local st="showing $from-$to / $total"
                local ctrl="J up  K down   N new search   Enter/Esc back"
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                local cl=$(( (w - ${#ctrl}) / 2 ))
                (( cl < 1 )) && cl=1
                goto $((h - 3)) "$cl"
                printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl" "$R"
                goto $((h - 2)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                local sl=$(( (w - ${#st}) / 2 ))
                (( sl < 1 )) && sl=1
                goto $((h - 2)) "$sl"
                printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$st" "$R"
                ;;
        esac
    }

    _find_set_root
    while true; do
        if (( dirty )); then
            _find_paint
            dirty=0
        fi
        local c1="" c2="" c3=""
        case $phase in
            input)
                if ! IFS= read -r -s -N 1 -t 0.4 c1; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                # Enter = søg
                if [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]]; then
                    if [[ -z $query ]]; then
                        msg="Type part of a filename first"
                        msg_col=$FG_EXIT
                        dirty=1
                        continue
                    fi
                    hide_cursor
                    msg="Searching…"
                    msg_col=$FG_HINT
                    phase=results
                    _find_paint
                    _find_run
                    dirty=1
                    continue
                fi
                # Esc = tilbage (Q/0/cifre må gerne indgå i søgestrengen)
                if [[ $c1 == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    [[ -z $c2 ]] && { hide_cursor; return; }
                    continue
                fi
                # Backspace
                if [[ $c1 == $'\x7f' || $c1 == $'\b' ]]; then
                    (( ${#query} > 0 )) && query=${query:0:$((${#query} - 1))}
                    msg=""; dirty=1
                    continue
                fi
                # Tab = skift rod (home → project → / → home)
                if [[ $c1 == $'\t' ]]; then
                    case $root_key in
                        home) root_key=project ;;
                        project) root_key=rootfs ;;
                        *) root_key=home ;;
                    esac
                    _find_set_root
                    msg="Root: $root_key"
                    msg_col=$FG_HINT
                    dirty=1
                    continue
                fi
                # Alle printbare tegn → query (inkl. q, 0, 1, 2, 3, …)
                if (( ${#query} < 80 )) && [[ $c1 =~ [[:print:]] ]]; then
                    query+="$c1"
                    msg=""
                    dirty=1
                fi
                ;;
            results)
                if ! IFS= read -r -s -N 1 -t 0.4 c1; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ $c1 == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    if [[ $c2 == '[' || $c2 == O ]]; then
                        IFS= read -r -s -N 1 -t 0.03 c3 || true
                        case $c3 in
                            A|D) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
                            B|C) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
                        esac
                    else
                        return
                    fi
                    continue
                fi
                [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]] && return
                case $c1 in
                    n|N) phase=input; msg=""; dirty=1 ;;
                    j|J|w|W) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
                    k|K|s|S) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
                esac
                ;;
        esac
    done
}

# ---------- Users & Groups (+ add/remove member) ----------
users_and_groups() {
    local w h top left dirty=1
    # Tab: users → groups → logged-in
    # S: system ON/OFF · A: add to group · D: remove from group
    local view=users
    local show_system=0
    local -a rows
    local total=0 offset=0 max_rows=10
    local msg="" msg_col=$FG_HINT
    local phase=browse   # browse | user | group | confirm | done
    local edit_op=""     # add | remove
    local edit_user="" edit_group=""
    local ch="" c1="" c2="" c3=""

    _ug_center() {
        local row=$1 len=$2; shift 2
        local col=$(( (w - len) / 2 ))
        (( col < 1 )) && col=1
        goto "$row" "$col"
        printf '%s' "$NOBG"
        printf "$@"
        printf '%s' "$R"
    }

    _ug_blank() {
        goto "$1" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    }

    _ug_next_view() {
        case $view in
            users) view=groups ;;
            groups) view=loggedin ;;
            *) view=users ;;
        esac
        offset=0
        _ug_load
    }

    _ug_user_exists() { getent passwd "$1" >/dev/null 2>&1; }
    _ug_group_exists() { getent group "$1" >/dev/null 2>&1; }

    _ug_me() { id -un 2>/dev/null || printf '%s' "${USER:-}"; }

    # Beskyttede konti: root + typiske systembrugere + UID < 1000
    _ug_protected_user() {
        local u=$1 uid
        case $u in
            root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|\
            www-data|backup|list|irc|gnats|nobody|_apt|systemd-network|\
            systemd-resolve|messagebus|sshd|pollinate)
                return 0
                ;;
        esac
        uid=$(id -u "$u" 2>/dev/null) || return 0
        (( uid < 1000 || uid >= 65534 )) && return 0
        return 1
    }

    # Kritiske grupper: navne + GID < 1000 (system)
    _ug_protected_group() {
        local g=$1 gid
        case $g in
            root|daemon|bin|sys|adm|tty|disk|sudo|wheel|shadow|staff|\
            nogroup|docker|lxd|netdev|sudoers|systemd-journal)
                return 0
                ;;
        esac
        gid=$(getent group "$g" 2>/dev/null | cut -d: -f3)
        [[ -z $gid ]] && return 0
        (( gid < 1000 || gid >= 65534 )) && return 0
        return 1
    }

    # Returnerer 0 hvis operationen er tilladt; ellers sætter msg og returnerer 1
    _ug_safety_check() {
        local op=$1 user=$2 group=$3
        local me pg
        me=$(_ug_me)

        if [[ -z $user || -z $group ]]; then
            msg="User and group required"; msg_col=$FG_EXIT; return 1
        fi
        if _ug_protected_user "$user"; then
            msg="Protected user — refused ($user)"
            msg_col=$FG_EXIT
            return 1
        fi
        if _ug_protected_group "$group"; then
            msg="Protected group — refused ($group)"
            msg_col=$FG_EXIT
            return 1
        fi
        # Aldrig ændre egen medlemskab (hverken add eller remove)
        if [[ -n $me && $user == "$me" ]]; then
            msg="Refusing to change YOUR own group membership"
            msg_col=$FG_EXIT
            return 1
        fi
        if [[ $op == remove ]]; then
            pg=$(id -gn "$user" 2>/dev/null || true)
            if [[ $pg == "$group" ]]; then
                msg="Cannot remove — $group is primary group"
                msg_col=$FG_EXIT
                return 1
            fi
        fi
        return 0
    }

    _ug_in_group() {
        local user=$1 group=$2 members pg
        pg=$(id -gn "$user" 2>/dev/null) || return 1
        [[ $pg == "$group" ]] && return 0
        members=$(getent group "$group" 2>/dev/null | cut -d: -f4)
        [[ -z $members ]] && return 1
        local IFS=,
        local m
        for m in $members; do
            [[ $m == "$user" ]] && return 0
        done
        return 1
    }

    # Kør gpasswd; returnerer 0 ved success. Sætter msg/msg_col ved fejl.
    _ug_gpasswd() {
        local op=$1 user=$2 group=$3
        local err rc=0
        # Sikkerhedsnet igen lige før systemkald
        if ! _ug_safety_check "$op" "$user" "$group"; then
            return 1
        fi
        err=$(mktemp) || { msg="Could not create temp file"; msg_col=$FG_EXIT; return 1; }
        if [[ $op == add ]]; then
            gpasswd -a "$user" "$group" >/dev/null 2>"$err"
            rc=$?
        else
            gpasswd -d "$user" "$group" >/dev/null 2>"$err"
            rc=$?
        fi
        if (( rc == 0 )); then
            rm -f "$err"
            return 0
        fi
        # Pæn fejl — ingen rå stderr-dump
        local raw
        raw=$(tr '\n' ' ' <"$err" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
        rm -f "$err"
        if [[ $raw == *[Pp]ermission* || $raw == *"not allowed"* || $raw == *"Only root"* ]]; then
            msg="Permission denied — need root/sudo for group changes"
        elif [[ $raw == *"not a member"* || $raw == *"Not a member"* || $raw == *"not in"* ]]; then
            msg="User is not a member of that group"
        elif [[ $raw == *[Aa]lready* ]]; then
            msg="User is already in that group"
        else
            msg="Group change failed"
            [[ -n $raw ]] && msg="Group change failed ($raw)"
            (( ${#msg} > 70 )) && msg="${msg:0:67}..."
        fi
        msg_col=$FG_EXIT
        return 1
    }

    _ug_start_edit() {
        edit_op=$1
        edit_user=""
        edit_group=""
        msg=""
        phase=user
        dirty=1
    }

    _ug_load() {
        rows=()
        local line name uid gid home shell members
        case $view in
            groups)
                while IFS=: read -r name _ gid members; do
                    [[ -z $name ]] && continue
                    if (( ! show_system )); then
                        (( gid < 1000 || gid >= 65534 )) && continue
                    fi
                    rows+=("${name}|${gid}|${members}")
                done < <(getent group 2>/dev/null)
                if (( show_system )); then
                    msg="All groups (system ON)"
                else
                    msg="Human groups (GID ≥ 1000)"
                fi
                msg_col=$FG_HINT
                ;;
            loggedin)
                while IFS= read -r line; do
                    [[ -z $line ]] && continue
                    rows+=("$line")
                done < <(who 2>/dev/null)
                msg="Logged-in sessions"
                msg_col=$FG_HINT
                ;;
            *)
                view=users
                while IFS=: read -r name _ uid _ _ home shell; do
                    [[ -z $name ]] && continue
                    if (( ! show_system )); then
                        (( uid < 1000 || uid >= 65534 )) && continue
                    fi
                    rows+=("${name}|${uid}|${home}|${shell}")
                done < <(getent passwd 2>/dev/null)
                if (( show_system )); then
                    msg="All users (system ON)"
                else
                    msg="Human users (UID ≥ 1000)"
                fi
                msg_col=$FG_HINT
                ;;
        esac
        total=${#rows[@]}
        (( offset > 0 && offset >= total )) && offset=$(( total > 0 ? total - 1 : 0 ))
        (( offset < 0 )) && offset=0
    }

    _ug_paint_browse() {
        local idx shown end line a b c d short rest
        local col1=16 col2=8 col3=24 col4
        local view_lbl sys_lbl=off sys_col=$FG_DIM
        local ctrl1 ctrl2 st from=0 to=0 cl sl i
        max_rows=$(( h - top - 6 ))
        (( max_rows < 4 )) && max_rows=4
        col4=$(( w - left - col1 - col2 - col3 - 6 ))
        (( col4 < 8 )) && col4=8

        case $view in
            groups) view_lbl=groups ;;
            loggedin) view_lbl=logged-in ;;
            *) view_lbl=users ;;
        esac
        if (( show_system )); then
            sys_lbl=ON
            sys_col=$FG_ORANGE
        fi

        goto "$top" "$left"
        printf '%s%s%s%s%s  %ssystem:%s %s%s%s  %s%s%s' \
            "$NOBG" "$FG_YEL1" "$BOLD" "$view_lbl" "$R$NOBG" \
            "$FG_HINT" "$R$NOBG" "$sys_col" "$sys_lbl" "$R$NOBG" \
            "$msg_col" "$msg" "$R"
        ((top++))

        goto "$top" "$left"
        case $view in
            groups)
                printf '%s%s%-*s %-*s %-*s%s' \
                    "$NOBG" "$FG_TITLE$BOLD" \
                    "$col1" "GROUP" "$col2" "GID" $((col3 + col4 + 1)) "MEMBERS" "$R"
                ;;
            loggedin)
                printf '%s%s%-*s%s' \
                    "$NOBG" "$FG_TITLE$BOLD" $((w - left - 1)) "USER  LINE  WHEN  FROM" "$R"
                ;;
            *)
                printf '%s%s%-*s %-*s %-*s %-*s%s' \
                    "$NOBG" "$FG_TITLE$BOLD" \
                    "$col1" "USER" "$col2" "UID" "$col3" "HOME" "$col4" "SHELL" "$R"
                ;;
        esac
        ((top++))
        goto "$top" "$left"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$(repeat '─' $((w - left - 1)))" "$R"
        ((top++))

        end=$(( offset + max_rows ))
        (( end > total )) && end=$total
        shown=0
        for ((idx = offset; idx < end; idx++)); do
            line=${rows[idx]}
            goto $((top + shown)) "$left"
            case $view in
                groups)
                    a=${line%%|*}; rest=${line#*|}; b=${rest%%|*}; c=${rest#*|}
                    (( ${#a} > col1 )) && a="${a:0:$((col1-2))}.."
                    (( ${#c} > col3 + col4 )) && c="${c:0:$((col3+col4-2))}.."
                    printf '%s%s%-*s %s%-*s %s%-*s%s' \
                        "$NOBG" "$FG_NUM" "$col1" "$a" \
                        "$FG_YEL1" "$col2" "$b" \
                        "$FG_BYLINE" $((col3 + col4 + 1)) "$c" "$R"
                    ;;
                loggedin)
                    short=$line
                    (( ${#short} > w - left - 1 )) && short="${short:0:$((w-left-3))}.."
                    printf '%s%s%-*s%s' "$NOBG" "$FG_BYLINE" $((w - left - 1)) "$short" "$R"
                    ;;
                *)
                    a=${line%%|*}; rest=${line#*|}
                    b=${rest%%|*}; rest=${rest#*|}
                    c=${rest%%|*}; d=${rest#*|}
                    (( ${#a} > col1 )) && a="${a:0:$((col1-2))}.."
                    (( ${#c} > col3 )) && c="${c:0:$((col3-2))}.."
                    (( ${#d} > col4 )) && d="${d:0:$((col4-2))}.."
                    printf '%s%s%-*s %s%-*s %s%-*s %s%-*s%s' \
                        "$NOBG" "$FG_NUM" "$col1" "$a" \
                        "$FG_YEL1" "$col2" "$b" \
                        "$FG_LABEL" "$col3" "$c" \
                        "$FG_BYLINE" "$col4" "$d" "$R"
                    ;;
            esac
            ((shown++))
        done

        for ((i = shown; i < max_rows; i++)); do
            goto $((top + i)) "$left"
            printf '%s%s' "$NOBG" "$(repeat ' ' $((w - left - 1)))"
        done

        (( total > 0 )) && { from=$(( offset + 1 )); to=$(( offset + shown )); }
        st="showing $from-$to / $total"
        ctrl1="Tab views   A add→group   D remove←group   (safe: no self/root/sys)"
        ctrl2="S system   J/K scroll   R refresh   Enter/Q back   ·   $st"

        goto $((h - 3)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        cl=$(( (w - ${#ctrl1}) / 2 )); (( cl < 1 )) && cl=1
        goto $((h - 3)) "$cl"
        printf '%s%s%s%s' "$NOBG" "$FG_DIM" "$ctrl1" "$R"

        goto $((h - 2)) 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
        sl=$(( (w - ${#ctrl2}) / 2 )); (( sl < 1 )) && sl=1
        goto $((h - 2)) "$sl"
        printf '%s%s%s%s' "$NOBG" "$FG_HINT" "$ctrl2" "$R"
    }

    _ug_paint_edit() {
        local title action_lbl field_lbl field_val field_vis cursor_row
        if [[ $edit_op == add ]]; then
            action_lbl="Add user to group"
        else
            action_lbl="Remove user from group"
        fi

        case $phase in
            user)
                title=$action_lbl
                field_lbl="User"
                field_val=$edit_user
                _ug_blank "$top"
                _ug_center "$top" "${#title}" '%s%s%s' "$FG_TITLE" "$BOLD" "$title"
                ((top += 2))
                field_vis=$(( ${#field_lbl} + 2 + ${#field_val} ))
                _ug_blank "$top"
                _ug_center "$top" "$field_vis" '%s%s: %s%s%s' \
                    "$FG_HINT" "$field_lbl" "$FG_YEL1" "$BOLD" "$field_val"
                cursor_row=$top
                ((top += 2))
                if [[ -n $msg ]]; then
                    _ug_blank "$top"
                    _ug_center "$top" "${#msg}" '%s%s' "$msg_col" "$msg"
                fi
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _ug_center $((h - 3)) 48 '%sType name + Enter   Backspace   Esc cancel' "$FG_DIM"
                local pc=$(( (w - field_vis) / 2 + field_vis ))
                (( pc < 1 )) && pc=1
                goto "$cursor_row" "$pc"
                show_cursor
                ;;
            group)
                title=$action_lbl
                field_lbl="Group"
                field_val=$edit_group
                _ug_blank "$top"
                _ug_center "$top" "${#title}" '%s%s%s' "$FG_TITLE" "$BOLD" "$title"
                ((top += 2))
                local uline="User: $edit_user"
                _ug_blank "$top"
                _ug_center "$top" "${#uline}" '%s%s' "$FG_BYLINE" "$uline"
                ((top += 2))
                field_vis=$(( ${#field_lbl} + 2 + ${#field_val} ))
                _ug_blank "$top"
                _ug_center "$top" "$field_vis" '%s%s: %s%s%s' \
                    "$FG_HINT" "$field_lbl" "$FG_YEL1" "$BOLD" "$field_val"
                cursor_row=$top
                ((top += 2))
                if [[ -n $msg ]]; then
                    _ug_blank "$top"
                    _ug_center "$top" "${#msg}" '%s%s' "$msg_col" "$msg"
                fi
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _ug_center $((h - 3)) 48 '%sType name + Enter   Backspace   Esc cancel' "$FG_DIM"
                local pc2=$(( (w - field_vis) / 2 + field_vis ))
                (( pc2 < 1 )) && pc2=1
                goto "$cursor_row" "$pc2"
                show_cursor
                ;;
            confirm)
                hide_cursor
                local qline
                if [[ $edit_op == add ]]; then
                    qline="Add \"$edit_user\" to group \"$edit_group\"?"
                else
                    qline="Remove \"$edit_user\" from group \"$edit_group\"?"
                fi
                _ug_blank "$top"
                _ug_center "$top" 18 '%s%sConfirm' "$FG_EXIT" "$BOLD"
                ((top += 2))
                _ug_blank "$top"
                _ug_center "$top" "${#qline}" '%s%s' "$FG_BYLINE" "$qline"
                ((top += 2))
                _ug_blank "$top"
                _ug_center "$top" 18 '%s%sY%s yes    %s%sN%s no' \
                    "$FG_YEL1" "$BOLD" "$R$NOBG$FG_DIM" \
                    "$FG_EXIT" "$BOLD" "$R$NOBG$FG_DIM"
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _ug_center $((h - 3)) 28 '%sY confirm   N / Esc cancel' "$FG_DIM"
                ;;
            done)
                hide_cursor
                _ug_blank "$top"
                _ug_center "$top" "${#msg}" '%s%s%s' "$msg_col" "$BOLD" "$msg"
                ((top += 2))
                local det="user=$edit_user  group=$edit_group"
                _ug_blank "$top"
                _ug_center "$top" "${#det}" '%s%s' "$FG_DIM" "$det"
                goto $((h - 3)) 0
                printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
                _ug_center $((h - 3)) 28 '%sEnter / Esc back to list' "$FG_DIM"
                ;;
        esac
    }

    _ug_paint() {
        w=$(cols); h=$(rows)
        cls
        hide_cursor
        draw_page_banner USERS "Users and Groups"
        top=$PAGE_MSG_ROW
        left=2
        if [[ $phase == browse ]]; then
            _ug_paint_browse
        else
            _ug_paint_edit
        fi
    }

    _ug_name_char_ok() {
        # Linux user/group: letters, digits, _ - .
        [[ $1 =~ ^[A-Za-z0-9._-]$ ]]
    }

    _ug_load
    while true; do
        if (( dirty )); then
            _ug_paint
            dirty=0
        fi

        case $phase in
            browse)
                if ! IFS= read -r -s -N 1 -t 0.4 c1; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ $c1 == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    if [[ $c2 == '[' || $c2 == O ]]; then
                        IFS= read -r -s -N 1 -t 0.03 c3 || true
                        case $c3 in
                            A) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
                            B) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
                            # Esc alone / ignore left-right as scroll
                        esac
                    else
                        return
                    fi
                    continue
                fi
                [[ -z $c1 || $c1 == $'\n' || $c1 == $'\r' ]] && return
                case $c1 in
                    q|Q|0) return ;;
                    $'\t') _ug_next_view; dirty=1 ;;
                    r|R) _ug_load; dirty=1 ;;
                    j|J|w|W) (( offset > 0 )) && ((offset--)) && dirty=1 ;;
                    k|K) (( offset + max_rows < total )) && ((offset++)) && dirty=1 ;;
                    s|S)
                        (( show_system = ! show_system ))
                        offset=0
                        _ug_load
                        dirty=1
                        ;;
                    a|A) _ug_start_edit add ;;
                    d|D) _ug_start_edit remove ;;
                esac
                ;;
            user|group)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ $ch == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    if [[ -z $c2 ]]; then
                        hide_cursor
                        phase=browse
                        edit_op=""; edit_user=""; edit_group=""
                        _ug_load
                        msg="Cancelled"
                        msg_col=$FG_HINT
                        dirty=1
                    fi
                    continue
                fi
                if [[ -z $ch || $ch == $'\n' || $ch == $'\r' ]]; then
                    if [[ $phase == user ]]; then
                        if [[ -z $edit_user ]]; then
                            msg="Enter a username"; msg_col=$FG_EXIT; dirty=1
                            continue
                        fi
                        if ! _ug_user_exists "$edit_user"; then
                            msg="No such user: $edit_user"; msg_col=$FG_EXIT; dirty=1
                            continue
                        fi
                        if _ug_protected_user "$edit_user"; then
                            msg="Protected user — refused ($edit_user)"
                            msg_col=$FG_EXIT; dirty=1
                            continue
                        fi
                        if [[ $edit_user == "$(_ug_me)" ]]; then
                            msg="Refusing to change YOUR own group membership"
                            msg_col=$FG_EXIT; dirty=1
                            continue
                        fi
                        phase=group
                        msg=""
                        dirty=1
                        continue
                    fi
                    # phase=group
                    if [[ -z $edit_group ]]; then
                        msg="Enter a group name"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if ! _ug_group_exists "$edit_group"; then
                        msg="No such group: $edit_group"; msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if _ug_protected_group "$edit_group"; then
                        msg="Protected group — refused ($edit_group)"
                        msg_col=$FG_EXIT; dirty=1
                        continue
                    fi
                    if ! _ug_safety_check "$edit_op" "$edit_user" "$edit_group"; then
                        dirty=1
                        continue
                    fi
                    if [[ $edit_op == add ]]; then
                        if _ug_in_group "$edit_user" "$edit_group"; then
                            msg="Already a member of $edit_group"; msg_col=$FG_ORANGE; dirty=1
                            continue
                        fi
                    else
                        if ! _ug_in_group "$edit_user" "$edit_group"; then
                            msg="$edit_user is not in $edit_group"; msg_col=$FG_ORANGE; dirty=1
                            continue
                        fi
                    fi
                    phase=confirm
                    msg=""
                    dirty=1
                    continue
                fi
                case $ch in
                    $'\x7f'|$'\b')
                        if [[ $phase == user ]]; then
                            (( ${#edit_user} > 0 )) && edit_user=${edit_user:0:$((${#edit_user} - 1))}
                        else
                            (( ${#edit_group} > 0 )) && edit_group=${edit_group:0:$((${#edit_group} - 1))}
                        fi
                        msg=""; dirty=1
                        ;;
                    *)
                        if _ug_name_char_ok "$ch"; then
                            if [[ $phase == user ]]; then
                                (( ${#edit_user} < 32 )) && edit_user+="$ch"
                            else
                                (( ${#edit_group} < 32 )) && edit_group+="$ch"
                            fi
                            msg=""; dirty=1
                        fi
                        ;;
                esac
                ;;
            confirm)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ $ch == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    [[ -z $c2 ]] && {
                        phase=browse; _ug_load
                        msg="Cancelled"; msg_col=$FG_HINT; dirty=1
                    }
                    continue
                fi
                case $ch in
                    y|Y)
                        hide_cursor
                        if _ug_gpasswd "$edit_op" "$edit_user" "$edit_group"; then
                            if [[ $edit_op == add ]]; then
                                msg="Added $edit_user → $edit_group"
                            else
                                msg="Removed $edit_user ← $edit_group"
                            fi
                            msg_col=$FG_YEL1
                        fi
                        # msg already set on failure
                        phase=done
                        dirty=1
                        ;;
                    n|N)
                        phase=browse
                        _ug_load
                        msg="Cancelled"
                        msg_col=$FG_HINT
                        dirty=1
                        ;;
                esac
                ;;
            done)
                if ! IFS= read -r -s -N 1 -t 0.4 ch; then
                    (( CLOCK_ROW > 0 )) && paint_clock
                    (( NEED_REDRAW )) && { NEED_REDRAW=0; dirty=1; }
                    continue
                fi
                if [[ $ch == $'\e' ]]; then
                    IFS= read -r -s -N 1 -t 0.03 c2 || true
                    [[ -n $c2 ]] && continue
                fi
                if [[ -z $ch || $ch == $'\n' || $ch == $'\r' || $ch == q || $ch == Q || $ch == $'\e' ]]; then
                    phase=browse
                    edit_op=""; edit_user=""; edit_group=""
                    _ug_load
                    dirty=1
                fi
                ;;
        esac
    done
}


