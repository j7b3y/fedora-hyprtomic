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

```bash
ujust setup-dotfiles                  # link baked Hyprland/quickshell/waybar/... configs into ~/.config
ujust choose-kernel kernel-cachyos    # switch to the CachyOS kernel, then reboot
```

Note: the Linux Lite kernel is not available for Fedora Atomic, so `kernel-cachyos` is used as the "latest/optimized kernel" substitute.

GUI apps default to Flatpak (Flathub). The image auto-provisions the standard set:

- **ghostty** (terminal, copr `scottames/ghostty`), **nemo** + extensions (dnf), **firefox / loupe / bitwarden** (system flatpak)
- **clipryx** (clipboard), **hypr-emoji-picker** (emoji), **snipland** (snipping) — source-built (best-effort, non-fatal)
- **fcitx5 + mozc** (Japanese input) via native dnf, with IM env + autostart baked into `hyprland.conf`

Manual (not auto-installable):
- **fcitx5-hazkey** engine: not on Flathub/Fedora. Build from the gist's flatpak manifest if you specifically want hazkey (mozc covers Japanese input meanwhile).

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
