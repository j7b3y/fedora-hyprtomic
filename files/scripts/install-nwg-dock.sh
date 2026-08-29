#!/usr/bin/env bash
set -oue pipefail
# upstream master uses gotk4 (GTK4) + gtk4-layer-shell
dnf -y install golang gtk4-devel gtk4-layer-shell-devel glib2-devel gcc pkgconf-pkg-config

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/nwg-piotr/nwg-dock-hyprland.git "$TMP/dock"
( cd "$TMP/dock" && mkdir -p bin && GOTOOLCHAIN=auto go build -v -o bin/nwg-dock-hyprland . )

install -Dm755 "$TMP/dock/bin/nwg-dock-hyprland" /usr/local/bin/nwg-dock-hyprland
mkdir -p /usr/share/nwg-dock-hyprland
cp -r "$TMP/dock/images" /usr/share/nwg-dock-hyprland/ 2>/dev/null || true
cp -r "$TMP/dock/config/." /usr/share/nwg-dock-hyprland/ 2>/dev/null || true
