#!/usr/bin/env bash
set -euo pipefail
# quickshell-git: the expensive part of the GUI image (compiles C++/Qt).
# Kept in its own module/layer so that changing other AUR packages or fonts
# does not invalidate (and recompile) it; the registry layer cache can reuse it.
#
# Built from AUR against the container's Qt, which is what keeps the Qt private
# API self-consistent (the reason the GUI lives in an Arch container at all).

# This runs before gui-01 (so its heavy layer stays cached when other package
# lists change): install the minimal toolchain it needs here. The Arch base
# lacks sudo/base-devel.
pacman -Sy --needed --noconfirm sudo base-devel git go
mkdir -p /etc/sudoers.d

useradd -m -G wheel builder 2>/dev/null || true
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

sudo -u builder bash -lc '
  set -e
  cd /tmp
  git clone --depth 1 https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  yay -Y --gendb || true
'

sudo -u builder bash -lc 'yay -S --noconfirm --needed \
  --answerclean None --answeredit None --answerupgrade None \
  quickshell-git'
