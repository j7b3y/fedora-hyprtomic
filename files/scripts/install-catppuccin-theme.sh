#!/usr/bin/env bash
set -ou pipefail
dnf -y install sassc git || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/catppuccin/gtk.git "$TMP/gtk"; then
  echo "### catppuccin clone failed (non-fatal) ###"
  exit 0
fi

( cd "$TMP/gtk" && ./install.sh ) 2>&1 | tee "$TMP/build.log"
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then
  echo "### catppuccin build FAILED (rc=$rc) — log below ###"
  cat "$TMP/build.log"
  echo "### continuing without catppuccin theme (non-fatal) ###"
  exit 0
fi

mkdir -p /usr/share/themes
if [ -d "$HOME/.themes" ]; then
  cp -r "$HOME/.themes/"* /usr/share/themes/ 2>/dev/null || true
fi
