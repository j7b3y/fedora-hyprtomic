#!/usr/bin/env bash
set -euo pipefail
# Google Sans Flex: optional UI font for the dotfiles. Not packaged for
# Arch/AUR, so take the upstream Fedora COPR RPM and extract the font files from
# it (pinned by sha256). bsdtar (libarchive) can read RPMs.
URL="https://download.copr.fedorainfracloud.org/results/ririko66z/dots-hyprland/fedora-44-x86_64/09820466-google-sans-flex-vf-fonts/google-sans-flex-vf-fonts-20251118^1.git251aa5a-1.fc44.noarch.rpm"
SHA256="dd7476baad452b435d9c9f76495762eed1952ca61a53bf641340afb74b2008a6"

pacman -S --needed --noconfirm libarchive >/dev/null

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp/font.rpm" "$URL"
echo "${SHA256}  $tmp/font.rpm" | sha256sum -c -
bsdtar -xf "$tmp/font.rpm" -C /
fc-cache -f >/dev/null 2>&1 || true
