# fedora-hyprtomic &nbsp; [![bluebuild build badge](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml)

A personal Fedora Atomic (wayblue) desktop image with a split architecture:

- **Host** — Fedora Atomic base + Hyprland/SDDM session, system services and CLI tools.
- **GUI container** — an Arch distrobox image (`ghcr.io/j7b3y/hyprtomic-gui`) that carries the GUI foundation (quickshell, Qt6) and the GUI apps, started from the host by `hyprtomic-gui-shell`.
- **Dotfiles** — baked into `/etc/skel` and synced into `$HOME` with a ujust recipe (`$HOME` is shared with the container).

> This branch carries the ported Arch dotfiles (Lua Hyprland config, the
> quickshell shell with shelf / launcher / control-center / notifications, and
> the app configs) on top of the system + GUI container pipeline. See
> [`AGENTS.md`](AGENTS.md) for the architecture, the dotfile integration
> contract and the theming pipeline.

## Repository layout

| Path | Purpose |
|---|---|
| `recipes/recipe.yml` | Host image (packages, firstboot services, default flatpaks) |
| `recipes/gui.yml` | GUI container image (package layers + session assets) |
| `files/system/**` | Host-side files copied to `/` (skel, systemd, `hyprtomic-gui-shell`, ujust) |
| `files/scripts/**` | Host build-time scripts |
| `files/gui-build/**`, `files/gui/**` | GUI container build scripts and container-side assets |
| `AGENTS.md` | Architecture notes, conventions and change rules |

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
- Then rebase to the signed image:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/j7b3y/fedora-hyprtomic:latest
  ```
- Reboot again to complete the installation.

## First boot / dotfiles

```bash
ujust sync-skel-config                # copy /etc/skel into $HOME (skips existing files)
ujust overwrite=1 sync-skel-config    # replace managed files, prune removed ones, then re-login
```

The GUI container is managed from the host:

```bash
ujust gui-container-setup             # create + initialize the container
ujust gui-container-update            # recreate from the latest image
ujust gui-container-status            # show container state
hyprtomic-gui-shell status            # same, via the CLI
```

The container shell session starts when the dotfiles' Hyprland config runs
`hyprtomic-gui-shell` (see `AGENTS.md`). Session logs:
`~/.local/state/hyprtomic/gui-session.log`.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s
[cosign](https://github.com/sigstore/cosign). Download `cosign.pub` from this repo
and run:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
```
