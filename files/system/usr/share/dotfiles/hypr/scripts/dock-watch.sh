#!/usr/bin/env bash
# dock-watch.sh: nwg-dock-hyprland を起動し、対象モニタの再接続時に再起動する
# 上流バグ (nwg-piotr/nwg-dock-hyprland#103): 出力の瞬断で layer-shell
# サーフェスが破棄されたまま復帰しないため、monitoradded イベントで作り直す。
# usage: dock-watch.sh [output]
#   基準 (dotfiles arch/lua) は $monitor_primary を必須引数とするが、イメージ版は
#   デバイス固有値を持たないため省略可: 空/未知の出力名なら全出力に表示する。
set -euo pipefail

output="${1:-${MONITOR_PRIMARY:-}}"

# 存在しない出力名を渡された場合は全出力フォールバックに正規化
if [ -n "$output" ] && ! hyprctl monitors "$output" >/dev/null 2>&1; then
    output=""
fi

dock_args=(-r -i 24 -p bottom -a center -l overlay -nolauncher)
if [ -n "$output" ]; then
    dock_args+=(-o "$output")
fi

restart_dock() {
    # -x はプロセス名15文字制限にかかるため -f で完全コマンドラインを見る
    pkill -f '^nwg-dock-hyprland' 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -f '^nwg-dock-hyprland' >/dev/null || break
        sleep 0.1
    done
    # 9>&-: ロック fd を継承させない(dock が生き残るとロックが解放されないため)
    nwg-dock-hyprland "${dock_args[@]}" 9>&- &
}

# 多重起動防止: 監視が既にいる場合は dock の再起動だけして終了(手動リロード用)
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
    sleep 1   # 出力の安定待ち
    restart_dock
done
