# Third-party notices / 引用元クレジット

This image vendors and adapts work from other projects. Each retains its own license.

## Vendored into the image (files/system/etc/skel/)

| Source | License | Used for |
|---|---|---|
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) | GPL-3.0 (+ MIT / LGPL-3.0 bits, see `dots-hyprland-*` files) | The entire quickshell GUI (`~/.config/quickshell/ii`), Hyprland Lua config (`~/.config/hypr`), and the app config set. Vendored at the pinned commit recorded in `/usr/share/hyprtomic/versions.env`; HyprTomic-specific changes live in `~/.config/hypr/custom/` and `~/.config/illogical-impulse/config.json`. |

License texts for the vendored upstream are kept in `licenses/` and shipped at `/usr/share/licenses/hyprtomic/`.

## Design references

| Source | License | Used for |
|---|---|---|
| [oameye/atomic-hyprland](https://github.com/oameye/atomic-hyprland) | (per upstream repo) | The `sync-skel-config` ujust design (`/etc/skel` + rsync, `overwrite=1` manifest replace & prune) in `files/system/usr/share/ublue-os/just/60-hyprtomic.just` |

## Base Dotfiles tools (built from source at image build time)

These are built by `files/scripts/install-*.sh` and shipped as binaries; all rights remain with the upstream authors.

| Source | License | Tool |
|---|---|---|
| [j7b3y/fedora-hyprtomic `fix/setup`](https://github.com/j7b3y/fedora-hyprtomic/tree/fix/setup) | Apache-2.0 (this repo) | Base Dotfiles layer (quadgrid layout, custom/ integration, zsh/SDDM plumbing) |
| [Yot360/clipryx](https://github.com/Yot360/clipryx) | Apache-2.0 | clipboard manager (daemon + GUI) |
| [ry2x/HyprBind](https://github.com/ry2x/HyprBind) | MIT | keybind list app |
| [AnrokX/snipland](https://github.com/AnrokX/snipland) | MIT | screenshot tool |
| [oneroa/hypr-emoji-picker](https://github.com/oneroa/hypr-emoji-picker) | MIT | emoji picker |
| [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) | GPL-3.0 | SDDM login theme |
| ghostty (copr `scottames/ghostty`), fcitx5-hazkey (copr `cocoa/hazkey`) | per upstream | terminal / IME engine |

## Build-time references

- [BlueBuild](https://blue-build.org/) image pipeline & [ublue-os](https://universal-blue.org/) just/system plumbing
- [wayblueorg/wayblue](https://github.com/wayblueorg/wayblue) base image
