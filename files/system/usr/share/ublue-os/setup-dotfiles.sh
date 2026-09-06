#!/usr/bin/env bash
set -e

SRC=/usr/share/dotfiles
CFG="$HOME/.config"
SHARE="$HOME/.local/share"
OVERWRITE="${OVERWRITE:-0}"

# Two delivery modes:
#   symlink -> always tracks the image (session plumbing; image updates fix it)
#   copy    -> first-login default, user-owned afterwards; image updates never
#              touch it. `ujust overwrite=1 setup-dotfiles` restores defaults.
link() { ln -sf "$1" "$2"; }

copy() { # copy <src-relative-to-SRC> <dest>
    local src="$SRC/$1" dest="$2" real
    [ -e "$src" ] || return 0
    # migrate a stale image symlink into a real copy
    if [ -L "$dest" ]; then
        real="$(readlink -f "$dest" 2>/dev/null)"
        case "$real" in "$SRC"/*) rm -f "$dest" ;; esac
    fi
    if [ "$OVERWRITE" = "1" ] || [ ! -e "$dest" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
}

mkdir -p "$CFG"/{hypr/scripts,waybar/scripts,rofi/themes,dunst,nwg-dock-hyprland,Kvantum,quickshell,qt5ct,qt6ct,gtk-3.0,gtk-4.0,hyprbind,opencode,ghostty,fastfetch,fcitx5}
mkdir -p "$SHARE"/{backgrounds,nemo/actions/scripts}

# Hyprland core (symlink; lua config wins over .conf on Hyprland 0.55+)
link "$SRC/hypr/hyprland.lua" "$CFG/hypr/hyprland.lua"
ln -sfn "$SRC/hypr/layouts" "$CFG/hypr/layouts"
link "$SRC/hypr/hypridle.conf" "$CFG/hypr/hypridle.conf"
link "$SRC/hypr/hyprlock.conf" "$CFG/hypr/hyprlock.conf"
for f in "$SRC"/hypr/scripts/*; do
    [ -e "$f" ] || continue
    link "$f" "$CFG/hypr/scripts/$(basename "$f")"
    chmod +x "$f" 2>/dev/null || true
done

# host.lua: per-device overrides (user-writable, required by hyprland.lua)
if [ "$OVERWRITE" = "1" ] || [ ! -f "$CFG/hypr/host.lua" ]; then
    cat > "$CFG/hypr/host.lua" <<'EOF'
-- Per-device overrides (hyprland.lua does require("host")).
-- hl.* API is available here; put calls BEFORE the return.

-- Example: custom quadgrid tiling on workspaces 1-10 (big screens)
-- for i = 1, 10 do
--     hl.workspace_rule({ workspace = tostring(i), layout = "lua:quadgrid" })
-- end

return {
    -- nwg-dock output (unset = all outputs), e.g.:
    -- monitor_primary = "eDP-1",
}
EOF
fi

# waybar: config is a user-editable copy; style/scripts track the image
copy waybar/config "$CFG/waybar/config"
link "$SRC/waybar/style.css" "$CFG/waybar/style.css"
for f in "$SRC"/waybar/scripts/*; do
    [ -e "$f" ] || continue
    link "$f" "$CFG/waybar/scripts/$(basename "$f")"
    chmod +x "$f" 2>/dev/null || true
done

# per-app initial defaults (user-owned copies)
copy nwg-dock-hyprland/style.css "$CFG/nwg-dock-hyprland/style.css"
copy rofi/config.rasi "$CFG/rofi/config.rasi"
copy rofi/colors.rasi "$CFG/rofi/colors.rasi"
copy rofi/launcher.rasi "$CFG/rofi/launcher.rasi"
copy dunst/dunstrc "$CFG/dunst/dunstrc"
copy ghostty/config "$CFG/ghostty/config"
copy ghostty/gtk.css "$CFG/ghostty/gtk.css"
copy hyprbind/hyprbind-theme.css "$CFG/hyprbind/hyprbind-theme.css"
copy opencode/opencode.jsonc "$CFG/opencode/opencode.jsonc"
copy zsh/.zshrc "$HOME/.zshrc"
copy fcitx5/profile "$CFG/fcitx5/profile"

# nemo actions (symlink; shared with the read-only tree)
for f in "$SRC"/nemo/actions/*.nemo_action; do
    [ -e "$f" ] || continue
    link "$f" "$SHARE/nemo/actions/$(basename "$f")"
done
for f in "$SRC"/nemo/actions/scripts/*.sh; do
    [ -e "$f" ] || continue
    link "$f" "$SHARE/nemo/actions/scripts/$(basename "$f")"
    chmod +x "$f" 2>/dev/null || true
done

# Kvantum / Qt / GTK theming (symlink)
link "$SRC/Kvantum/kvantum.kvconfig" "$CFG/Kvantum/kvantum.kvconfig"
[ -e "$SRC/Kvantum/catppuccin-mocha-blue" ] && ln -sfn "$SRC/Kvantum/catppuccin-mocha-blue" "$CFG/Kvantum/catppuccin-mocha-blue"
link "$SRC/qt5ct/qt5ct.conf" "$CFG/qt5ct/qt5ct.conf"
link "$SRC/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf"
link "$SRC/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
link "$SRC/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"

# quickshell (symlink; current-theme is user-writable state, so a copy)
for f in "$SRC"/quickshell/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "current-theme" ] && continue
    ln -sfn "$f" "$CFG/quickshell/$base"
done
copy quickshell/current-theme "$CFG/quickshell/current-theme"
for f in "$SRC"/quickshell/scripts/*.sh; do
    [ -e "$f" ] || continue
    chmod +x "$f" 2>/dev/null || true
done

# fastfetch (branded config + shared logo; symlink)
link "$SRC/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
link "$SRC/fastfetch/logo.txt" "$CFG/fastfetch/logo.txt"

# assets
link "$SRC/assets/wallpaper.jpg" "$SHARE/backgrounds/wallpaper.jpg"

# zplug bootstrap: clone into the home (~/.zplug is user-owned state).
# Runs as root against /etc/skel at build time, so fresh accounts ship with it.
if [ ! -d "$HOME/.zplug" ] && command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/zplug/zplug "$HOME/.zplug" >/dev/null 2>&1 || {
        rm -rf "$HOME/.zplug"
        echo "zplug bootstrap skipped (offline?)"
    }
fi

echo "dotfiles materialized from $SRC"
