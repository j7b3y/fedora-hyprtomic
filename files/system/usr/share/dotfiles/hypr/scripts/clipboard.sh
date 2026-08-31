#!/usr/bin/env bash
# Clipboard picker (cliphist) with multi-field preview:
#   <type-icon> <preview> <length>
# Uses rofi -dmenu and returns the cliphist id of the selected entry.

set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
    notify-send "clipboard" "cliphist not found" 2>/dev/null || true
    exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
tsv="$tmpdir/entries.tsv"
: > "$tsv"

# Read cliphist list (format: <id>\t<encoded_data>) and build TSV.
# Display: "icon  preview  length"
while IFS=$'\t' read -r id data; do
    [[ -z "$id" || -z "$data" ]] && continue
    decoded=$(printf '%s' "$data" | cliphist decode 2>/dev/null || true)
    if [[ -z "$decoded" ]]; then
        icon="📦"
        preview="<unreadable>"
        len=0
    elif [[ "${#decoded}" -gt 0 ]] && printf '%s' "$decoded" | grep -Pq '[\x80-\xFF]'; then
        icon="🖼️"
        preview=$(printf '%s' "$decoded" | tr -d '\n' | head -c 60)
        len=${#decoded}
    elif printf '%s' "$decoded" | grep -Pq '^(https?|ftp|file)://'; then
        icon="🔗"
        preview=$(printf '%s' "$decoded" | tr -d '\n' | head -c 80)
        len=${#decoded}
    else
        icon="📋"
        preview=$(printf '%s' "$decoded" | tr '\n' ' ' | tr -s ' ' | head -c 80)
        len=${#decoded}
    fi
    printf '%s\t%s\t%s\t%s\n' "$icon" "$preview" "$len" "$id" >> "$tsv"
done < <(cliphist list 2>/dev/null || true)

if [[ ! -s "$tsv" ]]; then
    exit 0
fi

# Display only icon + preview + length; id is selected by row index.
display=$(awk -F'\t' '{printf "%s  %s  [%d chars]\n", $1, $2, $3}' "$tsv")
theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/dmenu.rasi"

selected=$(printf '%s\n' "$display" | rofi -dmenu \
    -p "Clipboard" \
    -i \
    -format 'i' \
    -theme "$theme" \
    2>/dev/null) || exit 0

if [[ -z "$selected" ]]; then
    exit 0
fi

# Map selected row index back to cliphist id.
id=$(awk -F'\t' -v n="$((selected + 1))" 'NR==n {print $4}' "$tsv")
if [[ -n "$id" ]]; then
    cliphist decode "$id" | wl-copy
    notify-send "clipboard" "Copied: $(awk -F'\t' -v n="$((selected + 1))" 'NR==n {print $2}' "$tsv" | head -c 40)" 2>/dev/null || true
fi
