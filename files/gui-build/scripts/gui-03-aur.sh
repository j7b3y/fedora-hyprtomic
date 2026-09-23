#!/usr/bin/env bash
set -euo pipefail
# Remaining AUR packages + a bundled binary package for the HyprTomic GUI
# container. Relies on the builder user and yay from gui-02-quickshell.sh.
#
# NOTE: microtex-git (LaTeX widget used by some dotfile sets) is omitted: its
# 2024 source snapshot fails to compile against the current Arch toolchain.
AUR_PKGS=(
  mozkey-ibg-bin     # Japanese IME engine (Mozkey IbG, prebuilt for fcitx5)
  fcitx5-hazkey-bin  # Fallback Japanese IME
  wlogout
  hypremoji           # emoji picker
  clipse              # clipboard history daemon (clipse -listen)
  clipse-gui          # clipboard history UI (Super+V)
  bibata-cursor-theme
  ttf-hackgen-nerd    # ghostty font (HackGen Console NF)
  ttf-twemoji         # emoji fallback font
)

# hyprbind: Base Dotfiles tool, shipped as a prebuilt Arch package.
HYPRBIND_URL="https://github.com/ry2x/HyprBind/releases/download/v0.1.4/hyprbind-0.1.4-1-x86_64.pkg.tar.zst"
HYPRBIND_SHA256="50860866f3565fd155bd6fd60b5bf707db63bed4dd91f3053b2d3edad9eae3eb"

curl -fL --retry 3 -o /tmp/hyprbind.pkg.tar.zst "$HYPRBIND_URL"
echo "${HYPRBIND_SHA256}  /tmp/hyprbind.pkg.tar.zst" | sha256sum -c -
pacman -U --noconfirm /tmp/hyprbind.pkg.tar.zst

sudo -u builder bash -lc "yay -S --noconfirm --needed \
  --answerclean None --answeredit None --answerupgrade None \
  ${AUR_PKGS[*]}"
