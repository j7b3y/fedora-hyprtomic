#!/usr/bin/env bash
set -oue pipefail
chmod +x /usr/libexec/hyprtomic/setup-hostname.sh
chmod +x /usr/libexec/hyprtomic/setup-zsh.sh
chmod +x /usr/libexec/hyprtomic/setup-groups.sh
# wayblue bakes its own hyprland.conf into /etc/skel; with Hyprland 0.55+ the
# .lua config wins anyway, but drop the stale file so there is no ambiguity
rm -f /etc/skel/.config/hypr/hyprland.conf
# compile the baked dconf system db (files/etc/dconf/db/hyprtomic.d)
dconf update
