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

Dotfiles are baked into `/etc/skel` (illogical-impulse quickshell UI + Base Dotfiles tools) and are applied automatically for new accounts. For an account that predates the image:

```bash
ujust sync-skel-config                # merge -- copies skel files that don't exist yet
ujust overwrite=1 sync-skel-config    # reset managed files to the image defaults (back up ~/.config first)
ujust login-wallpaper /path/to/img    # optional: swap the SDDM login wallpaper
```

GUI apps default to Flatpak (Flathub). The image auto-provisions the standard set:

- **ghostty** (terminal, copr `scottames/ghostty`), **nemo** + extensions (dnf), **firefox / loupe / bitwarden** (system flatpak)
- **clipryx** (clipboard), **hypr-emoji-picker** (emoji), **snipland** (snipping), **hyprbind** (keybind list) — source-built (best-effort, non-fatal)
- **fcitx5 + hazkey** (Japanese input) via native dnf + copr, with IM env + autostart baked into `~/.config/hypr/custom/`
- The quickshell python venv (`~/.local/state/quickshell/.venv`) is created on first login by `hyprtomic-ii-venv.service`

GUI reference: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (pinned commit recorded in `/usr/share/hyprtomic/versions.env`), with the bar placed at the bottom via `~/.config/illogical-impulse/config.json` and the Base Dotfiles quadgrid layout registered (per-workspace opt-in, default layout untouched).

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

These images are signed with [Sigstore](https://www.sigstore.com/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
```

## Credits / 引用元

See [THIRD-PARTY-NOTICES.md](./THIRD-PARTY-NOTICES.md) for the full attribution.

- GUI: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse, GPL-3.0) — vendored into `/etc/skel` at a pinned commit (`/usr/share/hyprtomic/versions.env`); license texts shipped at `/usr/share/licenses/hyprtomic/` and in [`licenses/`](./licenses/)
- sync-skel-config design: [oameye/atomic-hyprland](https://github.com/oameye/atomic-hyprland)
- Base Dotfiles layer (quadgrid, tools integration): this repo's [`fix/setup`](https://github.com/j7b3y/fedora-hyprtomic/tree/fix/setup) branch
- Source-built tools: [clipryx](https://github.com/Yot360/clipryx), [HyprBind](https://github.com/ry2x/HyprBind), [snipland](https://github.com/AnrokX/snipland), [hypr-emoji-picker](https://github.com/oneroa/hypr-emoji-picker), [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)
