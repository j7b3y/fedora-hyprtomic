#!/usr/bin/env bash
# dock-watch.sh: nwg-dock-hyprland を起動し、対象モニタの再接続時に再起動する
# 上流バグ (nwg-piotr/nwg-dock-hyprland#103): 出力の瞬断で layer-shell
# サーフェスが破棄されたまま復帰しないため、monitoradded イベントで作り直す。
# 出力は 引数 または 環境変数 MONITOR_PRIMARY で指定可能。
# 未指定の場合は全出力に表示する（特定の名称のモニタに依存しない）。
set -uo pipefail

output="${1:-${MONITOR_PRIMARY:-}}"

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
    if [[ "$line" == "monitoradded>>$output" ]]; then
      sleep 1   # 出力の安定待ち
      restart_dock
    fi
  else
    if [[ "$line" == "monitoradded>>"* ]]; then
      sleep 1
      restart_dock
    fi
  fi
done
