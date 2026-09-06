# fedora-hyprtomic &nbsp; [![bluebuild build badge](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/j7b3y/fedora-hyprtomic:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/j7b3y/fedora-hyprtomic:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## Post-install (first login)

Fresh installs need **nothing**: the dotfiles layout is baked into `/etc/skel` at build
time, so the account created by the installer is fully configured on first login
(configs are symlinks into `/usr/share/dotfiles` and refresh automatically on image
updates).

Only a machine that was **rebased** onto this image (account predates it, `$HOME`
bypasses skel) needs a one-time sync:

```bash
ujust setup-dotfiles                  # safe: skips files you have customized
ujust overwrite=1 setup-dotfiles      # force-refresh the user-editable copies
ujust choose-kernel kernel-cachyos    # switch to the CachyOS kernel, then reboot
```

(The `overwrite=1` variable must come *before* the recipe name — that is how `just`
parses its CLI. Commit `~/.config` to git before a forced overwrite if it holds
customizations.)

Note: the Linux Lite kernel is not available for Fedora Atomic, so `kernel-cachyos` is used as the "latest/optimized kernel" substitute.

GUI apps default to Flatpak (Flathub). The image auto-provisions the standard set:

- **ghostty** (terminal, copr `scottames/ghostty`), **nemo** + extensions (dnf), **firefox / loupe / bitwarden** (system flatpak)
- **clipryx** (clipboard), **hypr-emoji-picker** (emoji), **snip**/snipland (snipping), **hyprbind**, **nwg-dock-hyprland**, **uwsm** — source-built into `/usr/bin` (best-effort, non-fatal; **not** `/usr/local`, which is `/var/usrlocal` on ostree and never ships in the image)
- **fcitx5 + hazkey** (Japanese input) via native dnf + copr `cocoa/hazkey`, with IM env + autostart baked into `hyprland.lua`

## Dotfiles reference

The baked config tree (`files/system/usr/share/dotfiles` → `/usr/share/dotfiles`)
mirrors the private **`dotfiles` repo, `arch/lua` branch** — Hyprland's Lua config
(`hyprland.lua`, preferred over `.conf` on Hyprland 0.55+), the custom `quadgrid`
tiling layout for big screens (`hypr/layouts/quadgrid.lua`, applied via the
user-editable `~/.config/hypr/host.lua`), and the quickshell shelf/launcher.

Fedora-side adaptations kept intentionally generic (no device-specific values):

- Arch-only tools replaced by image equivalents: `clipse`→`clipryx`, `hypremoji`→`hypr-emoji-picker`, polkit-gnome→`hyprpolkitagent`
- No cursor theme (license) — GTK/hypr cursor settings left to the desktop default
- No hardcoded monitors/users: primary output comes from `host.lua` (default: all outputs), waybar ships a generic bottom "shelf" config matching `waybar/style.css`, Nerd Font glyphs provided by `cascadia-mono-nf-fonts`
- fastfetch config lists explicit modules (a user config fully replaces the defaults; without `modules` only the logo printed)

### btrfs compression tuning (optional, run once after install)

Fedora Atomic installs on btrfs with `compress=zstd:1` by default. To move root to zstd:5 — note that since F42 (composefs) **root mount options in /etc/fstab are ignored**; they must go into the kernel arguments ([common issue](https://discussion.fedoraproject.org/t/root-mount-options-are-ignored-in-fedora-atomic-desktops-42-and-later/148562)):

```bash
findmnt -no TARGET,OPTIONS / /var /home   # check current state
sudo rpm-ostree kargs --delete=rootflags=subvol=root --append=rootflags=subvol=root,compress=zstd:5
sudo sed -i 's/compres…zstd:5/' /etc/fstab && sudo systemctl daemon-reload
sudo reboot
# force-compress existing data
sudo btrfs fi defragment -r -c zstd /var /home
# verify: sudo dnf install -y btrfs-progs; btrfs filesystem du -s /var | btrfs filesystem show is fine too
```

## ISO

Generate an offline installer from the published image (run on Fedora/WSL; builds the ostree payload into Fedora's anaconda media):

```bash
sudo bluebuild generate-iso --iso-name hyprtomic.iso -V server image ghcr.io/j7b3y/fedora-hyprtomic:latest
```

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
```
