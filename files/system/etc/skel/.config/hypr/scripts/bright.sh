#!/usr/bin/env bash
# bright.sh: brightnessctl の 0-100% 範囲を BRIGHT_MAX 上限に再マップ
# キーバインド経由で 0-100 / +N% / -N% を受け取り、実値に変換して渡す
set -euo pipefail
MAX=${BRIGHT_MAX:-24134}
DEVICE=intel_backlight

cur=$(brightnessctl -d "$DEVICE" get)
arg="${1:?usage: bright <0-100|+N%|-N%>}"

if [[ "$arg" =~ ^([0-9]+)%?\+$ ]]; then
    target=$(( cur + ${BASH_REMATCH[1]} * MAX / 100 ))
elif [[ "$arg" =~ ^([0-9]+)%?-$ ]]; then
    target=$(( cur - ${BASH_REMATCH[1]} * MAX / 100 ))
else
    target=$(( ${arg%\%} * MAX / 100 ))
fi

(( target > MAX )) && target=$MAX
(( target < 0 )) && target=0

exec brightnessctl -d "$DEVICE" -e4 -n2 set "$target"
