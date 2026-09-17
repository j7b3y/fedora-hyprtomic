# AGENTS.md — working in this repository

HyprTomic is a personal Fedora Atomic (wayblue) desktop image whose GUI lives in
an Arch distrobox container. This file describes the architecture, the
operational method and the rules for changing things. Read it before editing
anything.

## TL;DR

- **Host** (`recipes/recipe.yml` → `ghcr.io/j7b3y/fedora-hyprtomic`): Fedora
  Atomic base + Hyprland/SDDM session, system services, host CLI tools.
- **GUI container** (`recipes/gui.yml` → `ghcr.io/j7b3y/hyprtomic-gui`): an Arch
  distrobox container that carries the GUI foundation (quickshell, Qt6) and the
  GUI apps. It is started from the host by `hyprtomic-gui-shell`.
- **Dotfiles** (`files/system/etc/skel/**`): synced into `$HOME` by
  `ujust sync-skel-config` (add `overwrite=1` to replace managed files). `$HOME`
  is shared with the container, so the same dotfile tree serves both sides.
- **This branch is a base scaffold**: system + GUI foundation + sync mechanism,
  with the dotfiles intentionally removed. Add your dotfile set under
  `files/system/etc/skel/.config/` (see "Dotfile integration contract").

## Repository layout

| Path | Purpose |
|---|---|
| `recipes/recipe.yml` | Host image: package list, os-release rebrand, firstboot services, default flatpaks |
| `recipes/gui.yml` | GUI container image: package layers + session asset |
| `files/system/**` | Copied verbatim to `/` of the host image (skel dotfiles, systemd units, `hyprtomic-gui-shell`, SDDM assets, polkit rule, ujust recipe) |
| `files/scripts/**` | Host build-time scripts (run inside the image build; referenced by bare name from `recipe.yml`) |
| `files/gui-build/scripts/gui-*.sh` | GUI container build scripts, one per package layer (see below) |
| `files/gui/**` | Copied verbatim to `/` of the **GUI container** (session entrypoint, python requirements) |
| `.github/workflows/build.yml` | Host image CI (paths-filtered) |
| `.github/workflows/gui.yml` | GUI container CI (paths-filtered, expensive) |

`docs/` and `opencode.json(c)` are intentionally gitignored: local notes and
agent config must not be committed.

## How the system runs

1. SDDM starts the Hyprland session on the host.
2. The dotfiles' Hyprland config runs `hyprtomic-gui-shell` (`exec-once`).
   Without that, nothing starts the GUI container.
3. `hyprtomic-gui-shell`:
   - creates/updates the distrobox container if needed (`init`/`update`/`reset`),
   - builds the shell python venv (`~/.local/state/quickshell/.venv`) once,
   - passes the Wayland/Hyprland environment into the container and sets
     `XDG_DATA_DIRS` so DesktopEntries sees both container apps and host
     flatpak exports,
   - forces software rendering when the VM has only a virtio GPU,
   - logs the session to `~/.local/state/hyprtomic/gui-session.log`.
4. Inside the container, `hyprtomic-gui-session` starts cliphist watchers and
   `qs -c "$HYPRTOMIC_QS_CONFIG"` (default `ii`).

Bridges between the two sides:

- Container → host command: `distrobox-host-exec <cmd>` (e.g. flatpak launch).
- Container → host entry: `distrobox enter hyprtomic-gui`.
- Container app → host PATH: `distrobox-export --bin ...` in
  `hyprtomic-gui-shell init_container`. **Never export a binary that the host
  already ships** (this is why `ghostty` is excluded: the host has its own).
- GUI apps are not installed on the host; run them from the container.

## Skel sync (the dotfiles mechanism)

```bash
ujust sync-skel-config              # copy /etc/skel → $HOME, skipping existing files
ujust overwrite=1 sync-skel-config  # replace managed files, prune removed ones, then re-login
```

- The recipe implements this (`files/system/usr/share/ublue-os/just/60-custom.just`):
  `rsync -av /etc/skel/ "$HOME/"` plus a manifest in
  `~/.local/state/hyprtomic/skel-manifest` so `overwrite=1` can prune files that
  a previous run synced but the image has since removed.
- The sync always copies **from the deployed image's `/etc/skel`**. After
  changing dotfiles you must build/update the host image (CI publishes `main`
  only) and reboot before `sync-skel-config` can see the new files.
- `$HOME` is shared with the container: keep host-only paths out of dotfiles
  that the container also reads, and vice versa. Container-specific binaries
  (e.g. IME engines) live in the container but their config in `$HOME` is shared.

## Dotfile integration contract

Add a dotfile set under `files/system/etc/skel/`. The base assumes:

| Expectation | Detail |
|---|---|
| Hyprland config | Bring your own (lua or conf). It must start the GUI container with `exec-once = hyprtomic-gui-shell` (or your own wrapper). `finalize.sh` deletes wayblue's stale `/etc/skel/.config/hypr/hyprland.conf`. |
| GUI shell config | `~/.config/quickshell/<name>` inside the container. Set `HYPRTOMIC_QS_CONFIG` on the host if `<name>` is not `ii` (passed through by `hyprtomic-gui-shell`, read by `hyprtomic-gui-session`). |
| Terminal | The host ships `ghostty` (copr `scottames/ghostty`), so the terminal keybind launches a host shell. The container keeps its own ghostty for shell actions. |
| Clipboard / IME | cliphist + wl-clipboard run in the container; fcitx5 + engines are container packages with config in `$HOME/.config/fcitx5`. |
| Python deps | The shell venv is built from `files/system/usr/share/hyprtomic/uv-requirements.txt`; add packages there if your dotfiles import them. |
| Flatpaks | Host-managed. Launch from the container with `distrobox-host-exec flatpak run <app-id>`; DesktopEntries resolves them via the `XDG_DATA_DIRS` set in `hyprtomic-gui-shell`. |
| Licenses | Anything vendored into `/etc/skel` must ship its license under `files/system/usr/share/licenses/` and be listed in `THIRD-PARTY-NOTICES.md`. |

Also keep in mind:

- `/etc/skel` is the single source of truth. Do not hand-edit files in `$HOME`
  on a test machine; they will be overwritten/pruned by `overwrite=1`.
- Dotfiles that reference container-only binaries will silently fail on the
  host (and vice versa). Check which side runs what before adding an `exec`.

## Build + CI rules

- **Only `main` publishes images.** Feature branches are validated by opening a
  PR (or `workflow_dispatch`). Pushing to a feature branch does not build.
- Do not push commits to a branch you do not own; create a new branch and open a
  PR instead. New branches are safe to push (no workflow triggers on push).
- `build.yml` ignores `files/scripts/gui-*`; `gui.yml` only watches
  `recipes/gui.yml`, `files/gui/**`, `files/gui-build/**`. If you move files
  between those trees, update the path filters.
- GUI layer caching is deliberate: `gui-02-quickshell.sh` (the expensive
  quickshell compile) runs first and every other package layer `COPY`s only its
  own script. Do not turn these into a single layer or `COPY files/` wholesale.
- BlueBuild's `post_build` wipes `/var` (ostree assumption). `gui-99-finalize.sh`
  moves pacman's DB/cache to `/usr/share/pacman/` because of this; keep that
  logic when editing the container image.
- Signing: keys are gitignored (`cosign.key`, `cosign.private`); CI uses the
  `SIGNING_SECRET` secret. Verification: `cosign verify --key cosign.pub <image>`.

## Validation

There is no test suite. Minimum before pushing:

```bash
bash -n files/system/usr/bin/hyprtomic-gui-shell
bash -n files/gui/usr/bin/hyprtomic-gui-session
# shellcheck if available
python3 -m py_compile <changed .py>
```

QML (dotfiles) can be checked without a desktop session by using the GUI image
and generating a `qmldir` tree so imports resolve:

```bash
podman run --rm -v "$PWD:/src:ro" --entrypoint bash ghcr.io/j7b3y/hyprtomic-gui:latest -c '
  mkdir -p /tmp/imp && cp -a /src/files/system/etc/skel/.config/quickshell/ii /tmp/imp/qs
  cd /tmp/imp/qs
  find . -type d | while read -r d; do
    files=$(find "$d" -maxdepth 1 -name "*.qml" -printf "%f\n"); [ -z "$files" ] && continue
    : > "$d/qmldir"
    for f in $files; do n=${f%.qml}; if grep -q "pragma Singleton" "$d/$f"; then
      echo "singleton $n 1.0 $f" >> "$d/qmldir"; else echo "$n 1.0 $f" >> "$d/qmldir"; fi
    done
  done
  /usr/lib/qt6/bin/qmllint -I /tmp/imp -I /usr/lib/qt6/qml modules/.../file.qml
'
```

End-to-end: on a test machine, update the host image, reboot, run
`ujust overwrite=1 sync-skel-config`, re-login and check
`~/.local/state/hyprtomic/gui-session.log`.

## Environment cautions

- Never modify the running development host (packages, `/etc`, services). Use
  podman/distrobox for experiments; the image is the only delivery mechanism.
- The GUI container is disposable: `ujust gui-container-update` recreates it.
  Anything needed long-term belongs in `recipes/gui.yml` / `files/gui-build/`,
  not inside the container.
- Keep comments in English and commits conventional (`feat(scope): ...`,
  `fix(scope): ...`), matching the existing history.

## Current state (base scaffold branch)

- Host + GUI container pipelines, session plumbing, skel sync, SDDM theme,
  firstboot services and the ujust recipes are in place.
- The dotfiles (Hyprland config, quickshell config, app configs) are intentionally
  absent; the previous end-4/ii set lives on the `gui/arch-container` branch for
  reference. Add the new set under `files/system/etc/skel/`.
- The GUI container package lists (`files/gui-build/scripts/gui-*.sh`) are a
  working starting point (quickshell + Qt6 + common GUI apps). Trim/extend them
  to match the new dotfiles.
