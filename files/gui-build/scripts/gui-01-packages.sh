#!/usr/bin/env bash
set -euo pipefail
# Official Arch packages for the HyprTomic GUI container (GUI foundation + apps).
# AUR packages are handled in gui-03-aur.sh.

pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

PACMAN_PKGS=(
  # toolchain (AUR builds) + general CLI
  base-devel git go
  fish eza starship btop fastfetch jq go-yq ripgrep wget rsync unzip bc uv
  python-pip python-gobject python-cairo gtk3 # gtk3: resolve-icons.py (PyGObject Gtk)
  # terminal (container side; the host has its own ghostty from
  # install-ghostty.sh, so this one stays inside the container)
  ghostty
  # GUI apps / widgets
  fuzzel cava libqalculate songrec translate-shell hyprpicker wf-recorder swappy
  rofi # wayland-native since 2.0 (provides/replaces the old rofi-wayland); shelf search + window switcher
  tesseract tesseract-data-eng tesseract-data-jpn imagemagick
  wtype cliphist brightnessctl playerctl libnotify dex
  kdialog kirigami syntax-highlighting matugen
  # audio / video clients (daemons live on the host)
  pavucontrol
  # session helpers used by the shell (systemd/hyprland sockets are shared)
  uwsm           # launcher starts apps via `uwsm app` scopes
  networkmanager # nmcli -> host NetworkManager over the shared system D-Bus
  hyprlock       # power menu lock action
  # Qt6 stack used by quickshell / ii
  qt6-base qt6-declarative qt6-wayland qt6-5compat qt6-imageformats
  qt6-positioning qt6-quicktimeline qt6-sensors qt6-tools qt6-translations
  qt6-multimedia qt6-svg
  # Qt theming (kvantum-dark via qt6ct; the catppuccin Kvantum theme ships in skel)
  qt5ct qt6ct kvantum
  # fonts (base: noto CJK + emoji; decorations added in the AUR step)
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd
  ttf-material-symbols-variable
  # icon theme (GTK/Qt/launcher icon resolution)
  papirus-icon-theme
  # file manager (Base Dotfiles override: nemo)
  nemo nemo-fileroller nemo-image-converter nemo-python
  # IME
  # IME (managed here so container GUI apps get it). The Japanese engine is
  # mozkey-ibg-bin (AUR, installed in the next step); this is only the fcitx5
  # framework + config tool.
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool
  # screenshot / clipboard / hardware clients
  grim slurp wl-clipboard upower ddcutil bluez bluez-utils
  # compositor: present for libraries/IPC used by hypremoji/hyprbind
  # (the actual session runs on the host; this is not started in the container)
  hyprland
)
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
