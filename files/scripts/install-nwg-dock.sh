#!/usr/bin/env bash
set -ou pipefail
# gotk4-layer-shell needs BOTH gtk3 and gtk4 layer-shell .pc + gtk3/gtk4/atk dev
dnf -y install golang gtk3-devel gtk4-devel gtk-layer-shell-devel gtk4-layer-shell-devel glib2-devel gobject-introspection-devel atk-devel gcc pkgconf-pkg-config || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/nwg-piotr/nwg-dock-hyprland.git "$TMP/dock"; then
  echo "### nwg-dock: git clone failed; skipping (non-fatal) ###"
  exit 0
fi

( cd "$TMP/dock" && mkdir -p bin && GOTOOLCHAIN=auto go build -v -o bin/nwg-dock-hyprland . ) 2>&1 | tee "$TMP/build.log"
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then
  echo "### nwg-dock build FAILED (rc=$rc) — captured log below ###"
  cat "$TMP/build.log"
  echo "### continuing without nwg-dock (non-fatal) ###"
  exit 0
fi

install -Dm755 "$TMP/dock/bin/nwg-dock-hyprland" /usr/local/bin/nwg-dock-hyprland
mkdir -p /usr/share/nwg-dock-hyprland
cp -r "$TMP/dock/images" /usr/share/nwg-dock-hyprland/ 2>/dev/null || true
cp -r "$TMP/dock/config/." /usr/share/nwg-dock-hyprland/ 2>/dev/null || true
