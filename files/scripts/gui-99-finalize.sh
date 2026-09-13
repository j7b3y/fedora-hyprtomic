#!/usr/bin/env bash
set -euo pipefail
# Tidy the GUI container image: drop build caches/clones but keep the builder
# user (handy for in-container iteration while this is still experimental).
pacman -Scc --noconfirm
rm -rf /tmp/yay /tmp/hyprbind.pkg.tar.zst
rm -rf /home/builder/.cache/yay /home/builder/.cache/pikaur 2>/dev/null || true
