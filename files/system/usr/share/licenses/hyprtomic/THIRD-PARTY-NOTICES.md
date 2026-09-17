# Third-party notices / 引用元クレジット

This image adapts work from other projects. Each retains its own license.

## Design references

| Source | License | Used for |
|---|---|---|
| [oameye/atomic-hyprland](https://github.com/oameye/atomic-hyprland) | (per upstream repo) | The `sync-skel-config` ujust design (`/etc/skel` + rsync, `overwrite=1` manifest replace & prune) in `files/system/usr/share/ublue-os/just/60-custom.just` |

## Tools shipped by the image (built/downloaded at build time)

These are built by `files/scripts/install-*.sh` / `files/gui-build/scripts/gui-*.sh`
and shipped as packages or binaries; all rights remain with the upstream authors.

| Source | License | Tool |
|---|---|---|
| [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) | GPL-3.0 | SDDM login theme |
| ghostty (copr `scottames/ghostty`) | per upstream | host terminal |
| [ry2x/HyprBind](https://github.com/ry2x/HyprBind) | MIT | keybind list app (GUI container) |
| [oneroa/hypr-emoji-picker](https://github.com/oneroa/hypr-emoji-picker) (AUR `hypremoji`) | MIT | emoji picker (GUI container) |
| mozkey-ibg-bin (AUR) | per upstream | Japanese IME engine (GUI container) |
| fcitx5, quickshell-git and the remaining Arch packages | per upstream | GUI foundation (GUI container) |
| Google Sans Flex (copr `ririko66z/dots-hyprland`) | OFL-1.1 | optional UI font (GUI container) |

Dotfiles that are synced from `/etc/skel` are added per-branch by their authors;
anything vendored there must ship its own license alongside it.

## Dotfiles vendored into `/etc/skel`

| Path in `/etc/skel` | Source | License |
|---|---|---|
| `.config/quickshell/ii/` and `.config/hypr/` (hyprland.lua, hyprlock, hypridle, quadgrid.lua, scripts) | the user's own dotfiles (ported from the Arch `dotfiles` repo) | none (self-authored) |
| `.config/Kvantum/catppuccin-mocha-blue/` | [catppuccin/kvantum](https://github.com/catppuccin/kvantum) theme "catppuccin-mocha-blue" | GPL-3.0 (see `catppuccin-kvantum-LICENSE.txt`) |
| `.local/share/backgrounds/wallpaper.jpg` | personal asset | none (personal) |
| `.config/gtk-3.0/gtk.css`, `.config/gtk-4.0/gtk.css` | adapted from the `gui/arch-container` branch's matugen GTK templates | per the original matugen/Base Dotfiles upstream |

## Build-time references

- [BlueBuild](https://blue-build.org/) image pipeline & [ublue-os](https://universal-blue.org/) just/system plumbing
- [wayblueorg/wayblue](https://github.com/wayblueorg/wayblue) base image
