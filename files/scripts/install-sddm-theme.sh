#!/usr/bin/env bash
set -oue pipefail

dnf -y install git

THEME=/usr/share/sddm/themes/sddm-astronaut-theme
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$TMP/sddm-theme"
mkdir -p "$THEME"
cp -r "$TMP/sddm-theme/." "$THEME/"

if [ -f /usr/share/dotfiles/sddm/theme.conf ]; then
  mkdir -p "$THEME/Themes"
  cp /usr/share/dotfiles/sddm/theme.conf "$THEME/Themes/custom.conf"
  sed -i 's|ConfigFile=.*|ConfigFile=Themes/custom.conf|' "$THEME/metadata.desktop"
fi

systemctl enable sddm
