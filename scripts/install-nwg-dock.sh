#!/usr/bin/env bash
set -oue pipefail
dnf -y install golang gtk3-devel gtk-layer-shell-devel glib2-devel gcc pkgconf

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/nwg-piotr/nwg-dock-hyprland.git "$TMP/dock"
( cd "$TMP/dock" && make )

install -Dm755 "$TMP/dock/nwg-dock-hyprland" /usr/local/bin/nwg-dock-hyprland
