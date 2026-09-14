#!/usr/bin/env bash
set -euo pipefail
# Official Arch packages for the HyprTomic GUI container (end-4 illogical-impulse).
# AUR packages are handled in gui-02-aur.sh.

pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

PACMAN_PKGS=(
  # toolchain (AUR builds) + general CLI
  base-devel git go
  fish eza starship btop fastfetch jq go-yq ripgrep wget rsync unzip bc uv
  python-pip python-gobject python-cairo
  # terminal (the only GUI terminal; exported to the host PATH by
  # hyprtomic-gui-shell so the ii terminal keybind works)
  ghostty
  # ii widgets / apps
  fuzzel cava libqalculate songrec translate-shell hyprpicker wf-recorder swappy
  tesseract tesseract-data-eng tesseract-data-jpn imagemagick
  wtype cliphist brightnessctl playerctl libnotify dex
  kdialog kirigami syntax-highlighting matugen
  # audio / video clients (daemons live on the host)
  pavucontrol
  # Qt6 stack used by quickshell / ii
  qt6-base qt6-declarative qt6-wayland qt6-5compat qt6-imageformats
  qt6-positioning qt6-quicktimeline qt6-sensors qt6-tools qt6-translations
  qt6-multimedia qt6-svg
  # fonts (base: noto CJK + emoji; decorations added in the AUR step)
  noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd
  ttf-material-symbols-variable
  # file manager (Base Dotfiles override: nemo)
  nemo nemo-fileroller nemo-image-converter nemo-python
  # IME
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool
  # screenshot / clipboard / hardware clients
  grim slurp wl-clipboard upower ddcutil bluez bluez-utils
  # compositor: present for libraries/IPC used by hypremoji/hyprbind/snipland
  # (the actual session runs on the host; this is not started in the container)
  hyprland
)
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
