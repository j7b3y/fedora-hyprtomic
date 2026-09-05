#!/usr/bin/env bash
set -euxo pipefail

# Materialize the same layout setup-dotfiles.sh creates at runtime into
# /etc/skel, so accounts created during install (anaconda/useradd copies
# /etc/skel) get the dotfiles on first login with no manual step. Symlinks
# are copied as symlinks by useradd, so they keep pointing into the read-only
# /usr/share/dotfiles and image updates propagate automatically; the
# user-editable pieces (host.conf, waybar config, fcitx5 profile) land as
# regular per-user files.
HOME=/etc/skel /usr/share/ublue-os/setup-dotfiles.sh
