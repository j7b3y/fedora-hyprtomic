# Set to 1 with: ujust overwrite=1 setup-dotfiles  (variables go BEFORE the recipe name)
overwrite := "0"

# Materialize baked dotfiles from /usr/share/dotfiles into the user's home.
# Fresh installs get this automatically (baked into /etc/skel); this recipe is
# for rebased machines whose account predates the image. Re-running is safe:
# symlinks (session plumbing) are refreshed from the image, user-owned copies
# (~/.zshrc, ghostty, rofi, dunst, waybar/config, hypr/host.lua, opencode,
# hyprbind, nwg-dock, fcitx5/profile, quickshell/current-theme) are left alone.
# overwrite=1 resets those copies to the image defaults -- back up ~/.config
# first if it holds customizations.
setup-dotfiles:
    OVERWRITE={{ overwrite }} /usr/share/ublue-os/setup-dotfiles.sh

# Replace the SDDM login-screen wallpaper. Copies the astronaut theme to a
# private name under /usr/local (=/var/usrlocal host state: survives updates)
# and selects it via /etc/sddm.conf.d/zz-wallpaper.conf (sorts after the
# baked zz-theme.conf). Undo: delete both paths and restart sddm.
login-wallpaper path:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{ path }}"
    [ -f "$src" ] || { echo "no such file: $src"; exit 1; }
    dest=/usr/local/share/sddm/themes/hyprtomic-login
    [ -d "$dest" ] || sudo cp -a /usr/share/sddm/themes/sddm-astronaut-theme "$dest"
    sudo install -Dm644 "$src" "$dest/Backgrounds/wallpaper.jpg"
    printf '[Theme]\nCurrent=hyprtomic-login\n' | sudo tee /etc/sddm.conf.d/zz-wallpaper.conf >/dev/null
    sudo systemctl restart sddm || true
    echo "login wallpaper updated"
