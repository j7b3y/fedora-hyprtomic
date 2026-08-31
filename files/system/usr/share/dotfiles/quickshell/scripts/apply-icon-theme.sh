#!/usr/bin/env bash
# Apply the same icon theme to GTK (nwg-dock), Qt (quickshell fallback),
# and trigger quickshell to re-resolve its launcher/shelf icons.
# Usage: apply-icon-theme.sh [theme_name]
# If no theme name is given, reads from org.cinnamon.desktop.interface
# or org.gnome.desktop.interface icon-theme.

set -e

THEME="${1:-}"

# ── Determine target theme ───────────────────────────────────────────────────
if [[ -z "$THEME" ]]; then
    if command -v gsettings &>/dev/null; then
        for schema in org.cinnamon.desktop.interface org.gnome.desktop.interface; do
            if gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
                THEME=$(gsettings get "$schema" icon-theme 2>/dev/null | tr -d "'")
                [[ -n "$THEME" ]] && break
            fi
        done
    fi
fi

if [[ -z "$THEME" ]]; then
    echo "Usage: $0 <icon-theme-name>" >&2
    exit 1
fi

echo "Applying icon theme: $THEME"

# ── Update gsettings (GTK / nwg-dock) ────────────────────────────────────────
if command -v gsettings &>/dev/null; then
    for schema in org.cinnamon.desktop.interface org.gnome.desktop.interface; do
        if gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
            gsettings set "$schema" icon-theme "$THEME" || true
        fi
    done
fi

# ── Update qt5ct / qt6ct (Qt / Quickshell fallback) ──────────────────────────
update_qtct() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$(dirname "$file")"
        if grep -q "^icon_theme=" "$file" 2>/dev/null; then
            sed -i "s/^icon_theme=.*/icon_theme=$THEME/" "$file"
        else
            # Add under [Appearance] if it exists
            if grep -q "^\[Appearance\]" "$file" 2>/dev/null; then
                sed -i "/^\[Appearance\]/a icon_theme=$THEME" "$file"
            else
                printf '[Appearance]\nicon_theme=%s\n' "$THEME" >> "$file"
            fi
        fi
    fi
}

update_qtct "$HOME/.config/qt5ct/qt5ct.conf"
update_qtct "$HOME/.config/qt6ct/qt6ct.conf"

# ── Signal quickshell to reload (it re-runs resolve-icons.py on restart) ─────
if command -v qs &>/dev/null; then
    # Quickshell does not have a built-in reload for the icon cache,
    # so restart it. The launcher/shelf re-resolve icons on startup.
    if pgrep -x qs &>/dev/null; then
        echo "Restarting quickshell to pick up new icon theme..."
        killall -q qs || true
        sleep 0.5
        nohup qs > /dev/null 2>&1 &
    fi
fi
