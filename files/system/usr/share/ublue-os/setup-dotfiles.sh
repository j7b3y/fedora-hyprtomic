#!/usr/bin/env bash
set -e

SRC=/usr/share/dotfiles
CFG="$HOME/.config"
LOC="$HOME/.local"
SHARE="$LOC/share"

mkdir -p "$CFG"/{hypr/scripts,waybar/scripts,rofi,dunst,nwg-dock-hyprland,Kvantum,quickshell,qt5ct,qt6ct,gtk-3.0,gtk-4.0,hyprbind,opencode,ghostty}
mkdir -p "$SHARE"/{backgrounds,icons,nemo/actions/scripts}
mkdir -p "$HOME/.local/bin"

# Hyprland core
ln -sf "$SRC/hypr/hyprland.conf" "$CFG/hypr/hyprland.conf"
ln -sf "$SRC/hypr/hypridle.conf"  "$CFG/hypr/hypridle.conf"
ln -sf "$SRC/hypr/hyprlock.conf"  "$CFG/hypr/hyprlock.conf"
for f in "$SRC"/hypr/scripts/*; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$CFG/hypr/scripts/$(basename "$f")"
  chmod +x "$f"
done

# host.conf (optional per-device overrides; safe no-op if absent)
if [ ! -f "$CFG/hypr/host.conf" ]; then
  cat > "$CFG/hypr/host.conf" <<'EOF'
# Optional per-device overrides.
# Uncomment to pin the dock (and optionally waybar) to your primary output:
# env = MONITOR_PRIMARY, eDP-1
EOF
fi

# waybar (generic config; device-specific layout is optional user-supplied)
if [ ! -f "$CFG/waybar/config" ]; then
  cp "$SRC/waybar/config" "$CFG/waybar/config"
fi
ln -sf "$SRC/waybar/style.css" "$CFG/waybar/style.css"
for f in "$SRC"/waybar/scripts/*; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$CFG/waybar/scripts/$(basename "$f")"
  chmod +x "$f"
done

# nwg-dock
ln -sf "$SRC/nwg-dock-hyprland/style.css" "$CFG/nwg-dock-hyprland/style.css"

# rofi
ln -sf "$SRC/rofi/config.rasi"  "$CFG/rofi/config.rasi"
ln -sf "$SRC/rofi/colors.rasi"  "$CFG/rofi/colors.rasi"
ln -sf "$SRC/rofi/launcher.rasi" "$CFG/rofi/launcher.rasi"
ln -sf "$SRC/rofi/dmenu.rasi"   "$CFG/rofi/dmenu.rasi"

# dunst
ln -sf "$SRC/dunst/dunstrc" "$CFG/dunst/dunstrc"

# nemo actions
for f in "$SRC"/nemo/actions/*.nemo_action; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$SHARE/nemo/actions/$(basename "$f")"
done
for f in "$SRC"/nemo/actions/scripts/*.sh; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$SHARE/nemo/actions/scripts/$(basename "$f")"
  chmod +x "$f"
done

# Kvantum
ln -sf "$SRC/Kvantum/kvantum.kvconfig" "$CFG/Kvantum/kvantum.kvconfig"
[ -e "$SRC/Kvantum/catppuccin-mocha-blue" ] && ln -sfn "$SRC/Kvantum/catppuccin-mocha-blue" "$CFG/Kvantum/catppuccin-mocha-blue"

# Qt / GTK theming
ln -sf "$SRC/qt5ct/qt5ct.conf" "$CFG/qt5ct/qt5ct.conf"
ln -sf "$SRC/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf"
ln -sf "$SRC/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
ln -sf "$SRC/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"

# quickshell
ln -sfn "$SRC/quickshell"/* "$CFG/quickshell/" 2>/dev/null || true
for f in "$SRC"/quickshell/scripts/*.sh; do
  [ -e "$f" ] || continue
  chmod +x "$f"
done

# zsh
ln -sf "$SRC/zsh/.zshrc" "$HOME/.zshrc"

# ghostty
ln -sf "$SRC/ghostty/config" "$CFG/ghostty/config"
ln -sf "$SRC/ghostty/gtk.css" "$CFG/ghostty/gtk.css"

# hyprbind theme
ln -sf "$SRC/hyprbind/hyprbind-theme.css" "$CFG/hyprbind/hyprbind-theme.css"

# opencode
ln -sf "$SRC/opencode/opencode.jsonc" "$CFG/opencode/opencode.jsonc"

# fcitx5 input method profile (hazkey enabled; copy so it stays user-writable)
mkdir -p "$CFG/fcitx5"
if [ ! -f "$CFG/fcitx5/profile" ] && [ -f "$SRC/fcitx5/profile" ]; then
  cp "$SRC/fcitx5/profile" "$CFG/fcitx5/profile"
fi

# assets
ln -sf "$SRC/assets/wallpaper.jpg" "$SHARE/backgrounds/wallpaper.jpg"

echo "dotfiles linked from $SRC"
