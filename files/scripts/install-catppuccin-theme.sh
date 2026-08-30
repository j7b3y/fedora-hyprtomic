#!/usr/bin/env bash
set -ou pipefail
# catppuccin/gtk is archived but ships prebuilt release zips. Theme name:
# catppuccin-mocha-blue-standard+default  (must match gtk-theme-name / GTK_THEME)
dnf -y install unzip || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-blue-standard%2Bdefault.zip"
if curl -fL -o "$TMP/ctp.zip" "$URL"; then
  mkdir -p /usr/share/themes
  unzip -q "$TMP/ctp.zip" -d /usr/share/themes || true
  echo "### catppuccin-mocha-blue theme installed ###"
else
  echo "### catppuccin theme download failed (non-fatal) ###"
fi
