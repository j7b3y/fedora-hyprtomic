#!/usr/bin/env bash
# dock-watch.sh: run nwg-dock-hyprland and restart it when the target monitor
# reconnects. Upstream bug (nwg-piotr/nwg-dock-hyprland#103): the layer-shell
# surface is destroyed on a transient disconnect and never comes back.
# usage: dock-watch.sh [output]
#   Empty/unknown output (or unset MONITOR_PRIMARY) = show on all outputs.
set -euo pipefail

output="${1:-${MONITOR_PRIMARY:-}}"

# normalize unknown monitor names to the all-outputs fallback
if [ -n "$output" ] && ! hyprctl monitors "$output" >/dev/null 2>&1; then
    output=""
fi

dock_args=(-r -i 24 -p bottom -a center -l overlay -nolauncher)
if [ -n "$output" ]; then
    dock_args+=(-o "$output")
fi

restart_dock() {
    # -x hits the 15-char comm limit; -f matches the full command line
    pkill -f '^nwg-dock-hyprland' 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -f '^nwg-dock-hyprland' >/dev/null || break
        sleep 0.1
    done
    # 9>&-: do not leak the lock fd, else a surviving dock keeps it held
    nwg-dock-hyprland "${dock_args[@]}" 9>&- &
}

# singleton: if a watcher already runs, just nudge the dock (manual reload)
exec 9>"$XDG_RUNTIME_DIR/dock-watch.lock"
if ! flock -n 9; then
    restart_dock
    exit 0
fi

restart_dock

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
for line in s.makefile("r"):
    print(line, end="", flush=True)
' "$socket" | while IFS= read -r line; do
    if [ -n "$output" ]; then
        [ "$line" = "monitoradded>>$output" ] || continue
    else
        [[ "$line" == "monitoradded>>"* ]] || continue
    fi
    sleep 1 # let the output settle
    restart_dock
done
