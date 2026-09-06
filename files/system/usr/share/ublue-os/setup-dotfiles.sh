#!/usr/bin/env bash
set -e

SRC=/usr/share/dotfiles
CFG="$HOME/.config"
LOC="$HOME/.local"
SHARE="$LOC/share"
OVERWRITE="${OVERWRITE:-0}"

mkdir -p "$CFG"/{hypr/scripts,waybar/scripts,rofi/themes,dunst,nwg-dock-hyprland,Kvantum,quickshell,qt5ct,qt6ct,gtk-3.0,gtk-4.0,hyprbind,opencode,ghostty,fastfetch}
mkdir -p "$SHARE"/{backgrounds,nemo/actions/scripts}
mkdir -p "$HOME/.local/bin"

# Hyprland (lua config, dotfiles arch/lua 基準。hyprland.lua は .conf より優先)
ln -sf "$SRC/hypr/hyprland.lua" "$CFG/hypr/hyprland.lua"
ln -sfn "$SRC/hypr/layouts" "$CFG/hypr/layouts"
ln -sf "$SRC/hypr/hypridle.conf"  "$CFG/hypr/hypridle.conf"
ln -sf "$SRC/hypr/hyprlock.conf"  "$CFG/hypr/hyprlock.conf"
for f in "$SRC"/hypr/scripts/*; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$CFG/hypr/scripts/$(basename "$f")"
  chmod +x "$f" 2>/dev/null || true
done

# host.lua (任意のデバイス別オーバーライド; lua から require("host") される)
# テンプレはコメントのみ = dwindle + 全出力ドック。有効化すると:
#   - monitor_primary : nwg-dock をその出力に固定
#   - quadgrid        : 大画面向け自作タイルレイアウトをワークスペースに適用
if [ "$OVERWRITE" = "1" ] || [ ! -f "$CFG/hypr/host.lua" ]; then
  cat > "$CFG/hypr/host.lua" <<'EOF'
-- デバイス別のオーバーライド (hyprland.lua が require("host") する)。
-- このファイル内でも hyprland.lua と同じ hl.* API が使える (return より先に書く)。

-- 例: 大画面自作タイルレイアウト quadgrid をワークスペース 1-10 に適用する
-- for i = 1, 10 do
--     hl.workspace_rule({ workspace = tostring(i), layout = "lua:quadgrid" })
-- end

return {
    -- nwg-dock を表示する出力名 (省略 = 全出力)。例:
    -- monitor_primary = "eDP-1",
}
EOF
fi

# waybar (汎用 shelf config; style.css とは symlink で共有)
if [ "$OVERWRITE" = "1" ] || [ ! -f "$CFG/waybar/config" ]; then
  cp "$SRC/waybar/config" "$CFG/waybar/config"
fi
ln -sf "$SRC/waybar/style.css" "$CFG/waybar/style.css"
for f in "$SRC"/waybar/scripts/*; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$CFG/waybar/scripts/$(basename "$f")"
  chmod +x "$f" 2>/dev/null || true
done

# nwg-dock
ln -sf "$SRC/nwg-dock-hyprland/style.css" "$CFG/nwg-dock-hyprland/style.css"

# rofi
ln -sf "$SRC/rofi/config.rasi"  "$CFG/rofi/config.rasi"
ln -sf "$SRC/rofi/colors.rasi"  "$CFG/rofi/colors.rasi"
ln -sf "$SRC/rofi/launcher.rasi" "$CFG/rofi/launcher.rasi"

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
  chmod +x "$f" 2>/dev/null || true
done

# Kvantum
ln -sf "$SRC/Kvantum/kvantum.kvconfig" "$CFG/Kvantum/kvantum.kvconfig"
[ -e "$SRC/Kvantum/catppuccin-mocha-blue" ] && ln -sfn "$SRC/Kvantum/catppuccin-mocha-blue" "$CFG/Kvantum/catppuccin-mocha-blue"

# Qt / GTK theming
ln -sf "$SRC/qt5ct/qt5ct.conf" "$CFG/qt5ct/qt5ct.conf"
ln -sf "$SRC/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf"
ln -sf "$SRC/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
ln -sf "$SRC/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"

# quickshell (current-theme 以外は symlink; theme 選択はユーザー書き込み状態なので
# copy。symlink 経由だと read-only な /usr を書こうとして失敗する)
for f in "$SRC"/quickshell/*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = "current-theme" ] && continue
  ln -sfn "$f" "$CFG/quickshell/$base"
done
if [ "$OVERWRITE" = "1" ] || [ ! -f "$CFG/quickshell/current-theme" ]; then
  cp "$SRC/quickshell/current-theme" "$CFG/quickshell/current-theme"
fi
for f in "$SRC"/quickshell/scripts/*.sh; do
  [ -e "$f" ] || continue
  chmod +x "$f" 2>/dev/null || true
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

# fastfetch (HyprTomic raw ANSI logo)
ln -sf "$SRC/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
ln -sf "$SRC/fastfetch/logo.txt" "$CFG/fastfetch/logo.txt"

# fcitx5 input method profile (hazkey enabled; copy so it stays user-writable)
mkdir -p "$CFG/fcitx5"
if { [ "$OVERWRITE" = "1" ] || [ ! -f "$CFG/fcitx5/profile" ]; } && [ -f "$SRC/fcitx5/profile" ]; then
  cp "$SRC/fcitx5/profile" "$CFG/fcitx5/profile"
fi

# assets
ln -sf "$SRC/assets/wallpaper.jpg" "$SHARE/backgrounds/wallpaper.jpg"

echo "dotfiles linked from $SRC"
