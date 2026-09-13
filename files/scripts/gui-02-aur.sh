#!/usr/bin/env bash
set -euo pipefail
# AUR packages + a bundled binary package for the HyprTomic GUI container.
# Without this, a GUI-equivalent image cannot be made from Fedora packages:
# quickshell must match the (Arch) Qt private API, and several Base Dotfiles /
# end-4 tools are AUR-only.
#
# Deferred for now (heavier builds): clipryx (dotnet-sdk), fcitx5-hazkey (swift).

AUR_PKGS=(
  wlogout
  quickshell-git      # built against the container's Qt -> stable private ABI
  microtex-git
  hypremoji           # Base Dotfiles' hypr-emoji-picker replacement
  snipland
  darkly-bin
  breeze-plus
  adw-gtk-theme-git
  bibata-cursor-theme
  # end-4 decoration fonts (base is noto-fonts-cjk + noto-fonts-emoji)
  otf-space-grotesk
  ttf-readex-pro
  ttf-rubik-vf
  ttf-twemoji
)

# hyprbind: Base Dotfiles tool, shipped as a prebuilt Arch package.
HYPRBIND_URL="https://github.com/ry2x/HyprBind/releases/download/v0.1.4/hyprbind-0.1.4-1-x86_64.pkg.tar.zst"
HYPRBIND_SHA256="50860866f3565fd155bd6fd60b5bf707db63bed4dd91f3053b2d3edad9eae3eb"

# Non-root build user (makepkg must not run as root; sudo is passwordless here
# because the build is unattended and this user is removed with the image layer
# it was created for).
useradd -m -G wheel builder 2>/dev/null || true
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

# Bootstrap yay (resolves AUR dependency order, e.g. breakpad for quickshell).
sudo -u builder bash -lc '
  set -e
  cd /tmp
  git clone --depth 1 https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  yay -Y --gendb || true
'

# hyprbind prebuilt package.
curl -fL --retry 3 -o /tmp/hyprbind.pkg.tar.zst "$HYPRBIND_URL"
echo "${HYPRBIND_SHA256}  /tmp/hyprbind.pkg.tar.zst" | sha256sum -c -
pacman -U --noconfirm /tmp/hyprbind.pkg.tar.zst

# AUR packages.
sudo -u builder bash -lc "yay -S --noconfirm --needed \
  --answerclean None --answeredit None --answerupgrade None \
  ${AUR_PKGS[*]}"
