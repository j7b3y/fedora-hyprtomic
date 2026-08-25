#!/bin/bash
# Open selected file(s) / folder(s) in Visual Studio Code.
# Falls back to code-oss or codium if code is not available.

set -e

editor=""
for cmd in code code-oss codium; do
    if command -v "$cmd" &> /dev/null; then
        editor="$cmd"
        break
    fi
done

if [ -z "$editor" ]; then
    if command -v notify-send &> /dev/null; then
        notify-send "Open in VSCode" "VSCode not found. Please install code, code-oss, or codium."
    else
        echo "VSCode not found. Please install code, code-oss, or codium." >&2
    fi
    exit 1
fi

$editor "$@" &
