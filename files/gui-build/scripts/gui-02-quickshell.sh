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

# quickshell-git with local fix patches applied. The AUR package compiles
# upstream git master; fetch its recipe, add a prepare() that applies
# files/gui-build/patches/ (gui-02-quickshell-apply-patches.sh) and build with
# makepkg. The apply helper fuzzes the patches and skips any that upstream has
# already fixed, so upstream changes only break the build when they refactor
# the affected code without fixing the crash (then it fails loudly instead of
# silently shipping an unpatched shell).
sudo -u builder bash -lc '
  set -e
  cd /tmp
  rm -rf quickshell-git
  git clone --depth 1 https://aur.archlinux.org/quickshell-git.git
  cd quickshell-git
  if grep -qE "^[[:space:]]*prepare[[:space:]]*\(\)" PKGBUILD; then
    echo "quickshell-git PKGBUILD gained a prepare(); update gui-02-quickshell.sh" >&2
    exit 1
  fi
  printf "\nprepare() {\n  cd \"\$srcdir/\$_pkgname\"\n  bash /tmp/gui-02-quickshell-apply-patches.sh\n}\n" >>PKGBUILD
  makepkg -si --noconfirm
'
