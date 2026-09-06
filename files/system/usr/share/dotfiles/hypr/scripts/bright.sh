#!/usr/bin/env bash
# bright.sh: brightnessctl wrapper accepting 0-100 absolute or +N%/-N% steps.
# Uses brightnessctl's default backlight device (no device-specific pinning).
set -euo pipefail

arg="${1:?usage: bright.sh <0-100 | +N% | -N%>}"
[[ "$arg" =~ ^[0-9]+%?$ ]] && arg="${arg%\%}%"

exec brightnessctl set "$arg"
