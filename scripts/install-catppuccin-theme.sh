#!/usr/bin/env bash
set -oue pipefail
dnf -y install sassc git

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/catppuccin/gtk.git "$TMP/gtk"
( cd "$TMP/gtk" && ./install.sh )

mkdir -p /usr/share/themes
if [ -d "$HOME/.themes" ]; then
  cp -r "$HOME/.themes/"* /usr/share/themes/ 2>/dev/null || true
fi
