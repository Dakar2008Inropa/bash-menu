# ============================================================
# lib/boot.sh — Boot / Shutdown / quit
# Sources efter lib/tui.sh
# ============================================================

# ============================================================
# BOOT / SHUTDOWN screens (cool fake system sequences)
# Boot  = cyan/amber (samme palet som hovedmenu)
# Shutdown = rød/varm power-down (anderledes layout)
# ============================================================

_boot_draw_frame() {
    # Lille panel i menu-stil (hvid ramme + amber titel)
    local top=$1 title=$2
    local w total start
    w=$(cols)
    total=$((w - 4))
    (( total > 78 )) && total=78
    (( total < 50 )) && total=50
    start=$(( (w - total) / 2 ))
    (( start < 1 )) && start=1
    BOOT_FRAME_START=$start
    BOOT_FRAME_TOTAL=$total

    goto "$top" "$start"
    printf '%s%s┌─ %s%s%s%s %s┐%s' \
        "$NOBG" "$FG_WHITE" \
        "$FG_TITLE" "$BOLD" "$title" "$R$NOBG$FG_WHITE" \
        "$(repeat '─' $((total - ${#title} - 5)))" \
        "$R"
}

_boot_status() {
    # Cyan/teal tags — matcher menupunkternes FG_NUM / FG_LABEL
    local row=$1 msg=$2 kind=${3:-ok}
    local tag tag_fg msg_fg
    case $kind in
        ok)   tag="  OK  "; tag_fg=$FG_NUM;    msg_fg=$FG_LABEL ;;
        fail) tag=" FAIL "; tag_fg=$FG_EXIT;   msg_fg=$FG_LABEL ;;
        wait) tag=" .... "; tag_fg=$FG_HINT;   msg_fg=$FG_HINT ;;
        *)    tag=" INFO "; tag_fg=$FG_CHOICE; msg_fg=$FG_LABEL ;;
    esac
    local start=${BOOT_FRAME_START:-2}
    goto "$row" $((start + 2))
    printf '%s%s[%s%s%s]%s %s%s%s' \
        "$NOBG" "$FG_DIM" "$tag_fg" "$BOLD" "$tag" "$R$NOBG" \
        "$msg_fg" "$msg" "$R"
}

# Boot-progress gradient: teal → cyan (gemmes til pulse ved 100%)
BOOT_BAR_ROW=0
BOOT_BAR_COL=0
BOOT_BAR_W=0

_boot_progress() {
    local row=$1 pct=$2 label=$3
    local w bar_w left
    # Teal → cyan
    local r1=40 g1=160 b1=190 r2=80 g2=230 b2=245
    w=$(cols)
    bar_w=$((w - 24))
    (( bar_w > 50 )) && bar_w=50
    (( bar_w < 16 )) && bar_w=16
    left=$(( (w - (bar_w + 5)) / 2 ))
    (( left < 2 )) && left=2
    BOOT_BAR_ROW=$row
    BOOT_BAR_COL=$left
    BOOT_BAR_W=$bar_w
    goto $((row - 1)) "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_CHOICE" "$BOLD" "$label" "$R"
    # Ryd linjen først (gradient ændrer ikke længde, men undgår rester)
    goto "$row" "$left"
    printf '%s%s' "$NOBG" "$(repeat ' ' $((bar_w + 5)))"
    _progress_paint "$row" "$left" "$bar_w" "$pct" \
        "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
    if (( pct >= 100 )); then
        _progress_pulse "$row" "$left" "$bar_w" "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
    fi
}

_boot_scan_effect() {
    # Cyan scanline (menu-farve, ikke lilla)
    local h w y
    h=$(rows); w=$(cols)
    for ((y = 1; y < h - 2; y++)); do
        goto "$y" 0
        printf '%s%s%s%s' "$NOBG" "$FG_NUM" "$(repeat '─' "$w")" "$R"
        sleep_ms 0.028
        goto "$y" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    done
}

# --- Shutdown-specifikke helpers (rød / anderledes look) ---
# Chip-grid: 2×24 tegn + gap 4 = 52. Header/bar centreres ift. dette grid.
SHUTDOWN_CHIP_W=24
SHUTDOWN_CHIP_GAP=4
SHUTDOWN_GRID_W=0
SHUTDOWN_GRID_LEFT=0
SHUTDOWN_COL1=0
SHUTDOWN_COL2=0

_shutdown_layout() {
    # Beregn kolonner centreret i terminalen
    local w=$1
    SHUTDOWN_GRID_W=$((SHUTDOWN_CHIP_W * 2 + SHUTDOWN_CHIP_GAP))
    SHUTDOWN_GRID_LEFT=$(( (w - SHUTDOWN_GRID_W) / 2 ))
    (( SHUTDOWN_GRID_LEFT < 2 )) && SHUTDOWN_GRID_LEFT=2
    SHUTDOWN_COL1=$SHUTDOWN_GRID_LEFT
    SHUTDOWN_COL2=$((SHUTDOWN_GRID_LEFT + SHUTDOWN_CHIP_W + SHUTDOWN_CHIP_GAP))
}

_shutdown_center_x() {
    # _shutdown_center_x VISUAL_WIDTH → print kolonne centreret i chip-grid
    local vis=$1
    local left=$(( SHUTDOWN_GRID_LEFT + (SHUTDOWN_GRID_W - vis) / 2 ))
    (( left < 1 )) && left=1
    printf '%s' "$left"
}

_shutdown_header() {
    local title="⚠  POWER DOWN SEQUENCE"
    # ⚠ fylder typisk 2 display-kolonner, men tæller som 1 i ${#}
    local title_vis=$(( ${#title} + 1 ))
    local left sub sub_vis
    left=$(_shutdown_center_x "$title_vis")
    goto 2 "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_EXIT" "$BOLD" "$title" "$R"

    sub="${OWNER_NAME} · session ending · ${COMPANY}"
    sub_vis=${#sub}
    left=$(_shutdown_center_x "$sub_vis")
    goto 3 "$left"
    printf '%s%s%s%s' "$NOBG" "$FG_ACCENT" "$sub" "$R"
}

_shutdown_module() {
    # Tegn et “module chip” der slukker: LIVE → STOP
    # _shutdown_module ROW COL LABEL STATE(live|stop|off)
    local row=$1 col=$2 label=$3 state=$4
    local tag tag_fg box_fg
    case $state in
        live) tag=" LIVE "; tag_fg=$FG_NUM;   box_fg=$FG_HINT ;;
        stop) tag=" STOP "; tag_fg=$FG_EXIT;  box_fg=$FG_RED2 ;;
        off)  tag=" OFF  "; tag_fg=$FG_DIM;   box_fg=$FG_DIM ;;
    esac
    local inner=$((SHUTDOWN_CHIP_W - 2))
    goto "$row" "$col"
    printf '%s%s┌%s┐%s' "$NOBG" "$box_fg" "$(repeat '─' "$inner")" "$R"
    goto $((row + 1)) "$col"
    printf '%s%s│%s[%s%s%s]%s %-12s%s│%s' \
        "$NOBG" "$box_fg" "$R$NOBG" \
        "$tag_fg" "$BOLD" "$tag" "$R$NOBG$FG_LABEL" \
        "$label" "$box_fg" "$R"
    goto $((row + 2)) "$col"
    printf '%s%s└%s┘%s' "$NOBG" "$box_fg" "$(repeat '─' "$inner")" "$R"
}

SHUTDOWN_BAR_ROW=0
SHUTDOWN_BAR_COL=0
SHUTDOWN_BAR_W=0

_shutdown_power_bar() {
    # Progress går NEDAD (100 → 0) — mørkerød → lys rød gradient
    local row=$1 remaining=$2
    local bar_w left label label_left line_w
    local r1=140 g1=25 b1=35 r2=255 g2=100 b2=90
    bar_w=$((SHUTDOWN_GRID_W - 8))
    (( bar_w < 14 )) && bar_w=14
    line_w=$((bar_w + 5))
    left=$(_shutdown_center_x "$line_w")
    label="POWER REMAINING"
    label_left=$(_shutdown_center_x "${#label}")
    SHUTDOWN_BAR_ROW=$row
    SHUTDOWN_BAR_COL=$left
    SHUTDOWN_BAR_W=$bar_w
    goto $((row - 1)) "$label_left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_EXIT" "$BOLD" "$label" "$R"
    goto "$row" "$left"
    printf '%s%s' "$NOBG" "$(repeat ' ' "$line_w")"
    _progress_paint "$row" "$left" "$bar_w" "$remaining" \
        "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
}

_shutdown_power_pulse() {
    # Sidste “power cut”-pulse når baren rammer 0 (flash fuld rød, så tom)
    local r1=140 g1=25 b1=35 r2=255 g2=100 b2=90
    (( SHUTDOWN_BAR_W < 1 )) && return
    _progress_pulse "$SHUTDOWN_BAR_ROW" "$SHUTDOWN_BAR_COL" "$SHUTDOWN_BAR_W" \
        "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
    _progress_paint "$SHUTDOWN_BAR_ROW" "$SHUTDOWN_BAR_COL" "$SHUTDOWN_BAR_W" 0 \
        "$r1" "$g1" "$b1" "$r2" "$g2" "$b2"
}

_shutdown_collapse() {
    # Rød “collapse”-bølge opad (modsat boot-scan)
    local h w y
    h=$(rows); w=$(cols)
    for ((y = h - 2; y >= 1; y--)); do
        goto "$y" 0
        printf '%s%s%s%s' "$NOBG" "$FG_RED3" "$(repeat '═' "$w")" "$R"
        sleep_ms 0.022
        goto "$y" 0
        printf '%s%s' "$NOBG" "$(repeat ' ' "$w")"
    done
}

boot_screen() {
    hide_cursor
    cls
    local w h
    w=$(cols); h=$(rows)

    _boot_draw_frame 2 "BOOT  ·  ${COMPANY}"
    goto 3 $((BOOT_FRAME_START + 2))
    printf '%s%sBootloader v2.%s · operator: %s%s' \
        "$FG_HINT" "$BOLD" "$COPY_YEAR" "$OWNER_NAME" "$R"

    local steps=(
        "Probing CPU topology and cache layout"
        "Mapping memory banks and hugepages"
        "Mounting secure runtime filesystem"
        "Loading kernel extension pack"
        "Starting network fabric + DNS resolvers"
        "Hydrating process index (PID table)"
        "Importing service catalog from systemd"
        "Calibrating TUI renderer / truecolor"
        "Decrypting operator profile vault"
        "Warming module: Processes / Kill / Services"
        "Warming module: Find File / Users & Groups"
        "Loading Fun & Extras effect engine"
        "Syncing live clock subsystem"
        "Applying bashtop-inspired theme pack"
        "Indexing disk quotas and mount points"
        "Loading ACL / permission matrix"
        "Starting background telemetry agents"
        "Running self-test: menu layout OK"
        "Validating keyboard & resize hooks"
        "Handshaking with terminal (${w}x${h})"
    )

    local n=${#steps[@]}
    local effect_budget=2.2   # scan + SYSTEM READY
    local step_total per_step wait_s hold_s
    step_total=$(awk -v t="$BOOT_SCREEN_SECONDS" -v e="$effect_budget" 'BEGIN{printf "%.3f", t - e}')
    per_step=$(awk -v s="$step_total" -v n="$n" 'BEGIN{printf "%.3f", s / n}')
    wait_s=$(awk -v p="$per_step" 'BEGIN{printf "%.3f", p * 0.35}')
    hold_s=$(awk -v p="$per_step" 'BEGIN{printf "%.3f", p * 0.65}')

    local i max_visible=$((h - 10))
    (( max_visible < 8 )) && max_visible=8
    local start=0 pct

    for i in "${!steps[@]}"; do
        if (( i >= max_visible )); then
            start=$((i - max_visible + 1))
            local j disp=5
            cls
            _boot_draw_frame 2 "BOOT  ·  ${COMPANY}"
            goto 3 $((BOOT_FRAME_START + 2))
            printf '%s%sBootloader v2.%s · operator: %s%s' \
                "$FG_HINT" "$BOLD" "$COPY_YEAR" "$OWNER_NAME" "$R"
            for ((j = start; j <= i; j++)); do
                _boot_status "$disp" "${steps[j]}" ok
                ((disp++))
            done
            sleep_ms "$hold_s"
        else
            _boot_status $((5 + i)) "${steps[i]}" wait
            sleep_ms "$wait_s"
            _boot_status $((5 + i)) "${steps[i]}" ok
            sleep_ms "$hold_s"
        fi
        pct=$(( (i + 1) * 100 / n ))
        _boot_progress $((h - 3)) "$pct" "SYSTEM INIT"
    done

    _boot_scan_effect
    cls
    local ready="SYSTEM READY"
    local left=$(( (w - ${#ready}) / 2 ))
    goto $((h / 2)) "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_TITLE" "$BOLD" "$ready" "$R"
    goto $((h / 2 + 2)) $(( (w - 28) / 2 ))
    printf '%s%sEntering control panel...%s' "$FG_NUM" "$BOLD" "$R"
    sleep 1.0
    cls
}

shutdown_screen() {
    hide_cursor
    cls
    local w h
    w=$(cols); h=$(rows)

    # Fælles grid: chips + header + power-bar deler samme midte
    _shutdown_layout "$w"
    _shutdown_header

    local modules=(
        "TUI Core"
        "Fun Engine"
        "File Index"
        "Users DB"
        "Services"
        "Proc Snap"
        "Network"
        "Vault"
        "Mounts"
        "Telemetry"
        "ACL Matrix"
        "Live Clock"
        "Key Hooks"
        "Diagnostics"
        "FS Sync"
        "Session"
    )

    local n=${#modules[@]}
    # matrix + collapse + goodbye
    local effect_budget
    effect_budget=$(awk -v m="$SHUTDOWN_MATRIX_SECONDS" 'BEGIN{printf "%.3f", m + 2.0}')
    local step_total per_step
    step_total=$(awk -v t="$SHUTDOWN_SCREEN_SECONDS" -v e="$effect_budget" 'BEGIN{printf "%.3f", t - e}')
    per_step=$(awk -v s="$step_total" -v n="$n" 'BEGIN{printf "%.3f", s / n}')

    local chip_top=5
    local i row col remaining

    # Tegn alle som LIVE først
    for i in "${!modules[@]}"; do
        row=$((chip_top + (i / 2) * 3))
        if (( i % 2 == 0 )); then col=$SHUTDOWN_COL1; else col=$SHUTDOWN_COL2; fi
        (( row + 2 < h - 4 )) && _shutdown_module "$row" "$col" "${modules[i]}" live
    done
    _shutdown_power_bar $((h - 3)) 100

    # Sluk ét modul ad gangen
    for i in "${!modules[@]}"; do
        row=$((chip_top + (i / 2) * 3))
        if (( i % 2 == 0 )); then col=$SHUTDOWN_COL1; else col=$SHUTDOWN_COL2; fi
        if (( row + 2 < h - 4 )); then
            _shutdown_module "$row" "$col" "${modules[i]}" stop
            sleep_ms "$(awk -v p="$per_step" 'BEGIN{printf "%.3f", p * 0.45}')"
            _shutdown_module "$row" "$col" "${modules[i]}" off
        fi
        remaining=$(( 100 - (i + 1) * 100 / n ))
        _shutdown_power_bar $((h - 3)) "$remaining"
        sleep_ms "$(awk -v p="$per_step" 'BEGIN{printf "%.3f", p * 0.55}')"
    done

    # Pulse når power er brugt op (svarer til “100% færdig”)
    _shutdown_power_pulse

    # Cyan matrix henover (samme effekt som Fun, men i menu-cyan)
    _matrix_rain "$SHUTDOWN_MATRIX_SECONDS" "$FG_NUM"
    _shutdown_collapse
    cls

    local bye="SYSTEM OFFLINE"
    local left=$(( (w - ${#bye}) / 2 ))
    goto $((h / 2 - 1)) "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_RED1" "$BOLD" "$bye" "$R"
    local msg="Goodbye, ${OWNER_NAME}"
    left=$(( (w - ${#msg}) / 2 ))
    goto $((h / 2 + 1)) "$left"
    printf '%s%s%s%s%s' "$NOBG" "$FG_BYLINE" "$BOLD" "$msg" "$R"
    local copy="© ${COMPANY} • ${COPY_YEAR}"
    left=$(( (w - ${#copy}) / 2 ))
    goto $((h / 2 + 3)) "$left"
    printf '%s%s%s%s' "$NOBG" "$FG_ACCENT" "$copy" "$R"
    sleep 3.0
}

# Stop hele scriptet med det samme (fra enhver menu via +)
quit_program() {
    shutdown_screen
    exit 0
}

# Hemmelig hurtig-exit (CHOICE: !!) — uden shutdown-sekvens
quit_fast() {
    hide_cursor
    cls
    exit 0
}

