#!/usr/bin/env bash
set -ou pipefail
# snipland: Python + GTK4, no build step. Non-fatal.
dnf -y install python3-cairo python3-gobject gtk4 gtk4-layer-shell git || true

if ! git clone --depth 1 https://github.com/AnrokX/snipland.git /usr/share/snipland; then
  echo "### snipland clone failed (non-fatal) ###"
  exit 0
fi

chmod +x /usr/share/snipland/snip 2>/dev/null || true
ln -sf /usr/share/snipland/snip /usr/local/bin/snip
ln -sf /usr/share/snipland/snip /usr/local/bin/snipland
