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

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
```
