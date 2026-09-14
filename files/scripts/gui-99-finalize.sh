#!/usr/bin/env bash
set -euo pipefail
# Tidy the GUI container image: drop build caches/clones but keep the builder
# user (handy for in-container iteration while this is still experimental).
#
# BlueBuild's post_build step unconditionally runs `rm -rf /tmp/* /var/* /opt`
# (it assumes an ostree image where /var is populated at boot). This is a plain
# distrobox container, so redirect pacman's DB/cache/log outside /var and keep a
# copy of the DB, otherwise pacman is unusable inside the running container.
pacman -Scc --noconfirm

mkdir -p /usr/share/pacman/db /usr/share/pacman/cache
cp -a /var/lib/pacman/. /usr/share/pacman/db/
sed -i -e 's|^#DBPath.*|DBPath         = /usr/share/pacman/db/|' \
       -e 's|^#CacheDir.*|CacheDir       = /usr/share/pacman/cache/|' \
       -e 's|^#LogFile.*|LogFile        = /usr/share/pacman/pacman.log|' \
       /etc/pacman.conf

rm -rf /tmp/yay /tmp/hyprbind.pkg.tar.zst
rm -rf /home/builder/.cache/yay /home/builder/.cache/pikaur 2>/dev/null || true
