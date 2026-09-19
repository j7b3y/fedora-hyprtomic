#!/usr/bin/env bash
set -oue pipefail
chmod +x /usr/libexec/hyprtomic/setup-hostname.sh
chmod +x /usr/libexec/hyprtomic/setup-zsh.sh
chmod +x /usr/libexec/hyprtomic/setup-groups.sh
# wayblue bakes its own hyprland.conf into /etc/skel. HyprTomic dotfiles bring
# their own (lua) config, so drop the stale file to avoid ambiguity.
rm -f /etc/skel/.config/hypr/hyprland.conf
# compile the baked dconf system db (files/etc/dconf/db/hyprtomic.d)
dconf update
