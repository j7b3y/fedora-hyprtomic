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
- **This branch carries the ported Arch dotfiles**: a Lua Hyprland config,
  the quickshell `ii` shell and the app configs live under
  `files/system/etc/skel/`. Machine-specific settings go in
  `~/.config/hypr/local.conf`, which is intentionally **not** shipped in skel so
  it survives `overwrite=1` (see "Dotfile integration contract" and
  "Current state").

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
     mounting the host's `/var/lib/flatpak` read-only so the shell's
     DesktopEntries/icons see system flatpaks,
   - exports container GUI binaries to `~/.local/bin` (hypremoji, hyprbind,
     fuzzel, wlogout, swappy, hyprpicker, rofi, clipse-gui, clipse),
   - builds the shell python venv (`~/.local/state/quickshell/.venv`) once,
   - passes the Wayland/Hyprland environment into the container and sets
     `XDG_DATA_DIRS` so DesktopEntries sees both container apps and host
     flatpak exports,
   - forces software rendering when the VM has only a virtio GPU,
   - logs the session to `~/.local/state/hyprtomic/gui-session.log`.
4. Inside the container, `hyprtomic-gui-session` starts fcitx5 (IME), the clipse
   clipboard-history daemon and the cliphist watchers, then runs
   `qs -c "$HYPRTOMIC_QS_CONFIG"` (default `ii`).

Bridges between the two sides:

- Container → host command: `distrobox-host-exec <cmd>` (e.g. flatpak launch).
- Host system D-Bus: distrobox only shares the user session bus, so
  `hyprtomic-gui-shell` (and `files/gui/etc/profile.d/00-hyprtomic-host-dbus.sh`
  inside the image) points `DBUS_SYSTEM_BUS_ADDRESS` at
  `/run/host/run/dbus/system_bus_socket`. That is what lets the container's
  `bluetoothctl` / `nmcli` reach the host's BlueZ and NetworkManager.
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
| Hyprland config | `~/.config/hypr/hyprland.lua` (Lua). It starts the GUI container with `hyprtomic-gui-shell` (autostart). `finalize.sh` deletes wayblue's stale `/etc/skel/.config/hypr/hyprland.conf`. Machine-specific overrides go in `~/.config/hypr/local.conf` (Lua, **not** shipped in skel). |
| GUI shell config | `~/.config/quickshell/ii` inside the container. Set `HYPRTOMIC_QS_CONFIG` on the host if the config name is not `ii` (passed through by `hyprtomic-gui-shell`, read by `hyprtomic-gui-session`). The config's internal scripts reference `~/.config/quickshell/ii/...` — keep that path. |
| Terminal | The host ships `ghostty` (copr `scottames/ghostty`); its config falls back to a host CJK mono font (HackGen ships in the container only). The container keeps its own ghostty for shell actions. |
| Bar / notifications | quickshell owns the shelf / launcher / control-center / notifications / powermenu / OSD. waybar/dunst are **not** installed; `swaybg` (host) sets the wallpaper. The shelf's left button and the Henkan key open the quickshell launcher; `rofi` (container, exported) remains for the `Super+Escape` window switcher. |
| Clipboard / IME | `clipse` + `clipse-gui` (container AUR): the daemon is started by `hyprtomic-gui-session`, `Super+V` opens the GUI (exported). fcitx5 + mozkey-ibg-bin live in the container; the host env exports `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS`. |
| GTK / Qt theming | Driven by `~/.config/quickshell/ii/scripts/apply-theme.sh` (see "Theming"): GTK3/4 gtk.css, qt5ct/qt6ct palettes + a recolored Kvantum theme, ghostty palette, rofi colors and Hyprland borders. Adwaita base + Papirus-Dark icons + Bibata-Modern-Classic cursor (baked into the dconf db). |
| Python deps | The shell venv is built from `files/gui/usr/share/hyprtomic/uv-requirements.txt` (installed into the container at `/usr/share/hyprtomic/`, currently empty; `resolve-icons.py` needs only the container's python-gobject + gtk3). |
| Flatpaks | Host-managed (system scope). `hyprtomic-gui-shell` bind-mounts `/var/lib/flatpak` read-only into the container and sets `XDG_DATA_DIRS`; the shell launches flatpaks via `distrobox-host-exec flatpak run <app-id>`. |
| Licenses | Anything vendored into `/etc/skel` must ship its license under `files/system/usr/share/licenses/` and be listed in `THIRD-PARTY-NOTICES.md`. |

Also keep in mind:

- `/etc/skel` is the single source of truth. Do not hand-edit files in `$HOME`
  on a test machine; they will be overwritten/pruned by `overwrite=1`.
- Dotfiles that reference container-only binaries will silently fail on the
  host (and vice versa). Check which side runs what before adding an `exec`.

## Theming

`Theme.qml` (quickshell singleton) holds the theme table; the control center's
theme page switches `Theme.currentTheme`, writes
`~/.config/quickshell/ii/current-theme` and runs
`~/.config/quickshell/ii/scripts/apply-theme.sh <theme>`. The script is also run
on every shell start, so the whole desktop follows the saved theme:

| Output | File(s) | Notes |
|---|---|---|
| Hyprland borders | `hyprctl keyword …` + `~/.config/hypr/theme.lua` | the lua file is loaded by `hyprland.lua` on startup; the live hyprctl call covers the running session |
| GTK3 / GTK4 | `~/.config/gtk-{3,4}.0/gtk.css` | Adwaita + named-color overrides |
| Qt | `~/.config/{qt5ct,qt6ct}/colors/<theme>.conf` + `custom_palette=true` in the ct configs | QPalette dumps; covers widgets Kvantum does not paint |
| Kvantum | `~/.config/Kvantum/hyprtomic/{hyprtomic.kvconfig,hyprtomic.svg}` | recolored copy of the catppuccin theme from skel; running apps pick it up on restart |
| Ghostty | `~/.config/ghostty/theme.conf` | pulled in by `config-file = ?theme.conf` at the end of the ghostty config (later entries win) |
| Rofi | `~/.config/rofi/colors.rasi` | imported by `launcher.rasi` |

Adding a theme means editing `Theme.qml` **and** the `case` block in
`apply-theme.sh` (the script cannot read QML). Keep the hexes in sync.

Where the theme is consumed:

- **Host + GUI container**: `qt6ct`/`kvantum` are installed on **both** sides
  (`recipes/recipe.yml`, `files/gui-build/scripts/gui-01-packages.sh`) and
  `hyprland.lua` exports `QT_QPA_PLATFORMTHEME=qt6ct`. `files/system/etc/environment`
  is intentionally minimal: the base image's `GTK_THEME=Adwaita:dark` and
  `QT_STYLE_OVERRIDE=adwaita-dark` are removed because they shadowed the
  generated palette (QT_STYLE_OVERRIDE beats qt6ct's Kvantum style).
- **Other distrobox containers**: distrobox bind-mounts the host's
  `/usr/share/{fonts,icons,themes}` into every container at
  `/usr/local/share/...`, and `$HOME` is shared. Assets installed only in the
  GUI container are therefore invisible to the host and to other containers —
  put shared fonts/themes on the host image, not in the GUI container.
- **Flatpaks**: only host fonts (`/run/host/fonts`) and per-app `xdg-config`
  permissions are visible. Firefox has `xdg-config/gtk-3.0:ro`, Chrome does
  not, and Kvantum/Qt theming cannot be shipped to flatpaks. Keep flatpak
  expectations low and document deviations instead of chasing parity.
- **Known upstream issue**: flatpak 1.18.1+ (CVE-2026-34078 hardening) breaks
  CJK font rendering in Chromium/Gecko flatpaks even though `fc-match` resolves
  the fonts (`flatpak/flatpak#6800`). Verify with
  `flatpak run --command=fc-match <app> "sans-serif:lang=ja"` before touching
  the font pipeline.

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

## Current state

- Host + GUI container pipelines, session plumbing, skel sync, SDDM theme,
  firstboot services and the ujust recipes are in place.
- The Arch dotfiles are ported under `files/system/etc/skel/`: a Lua Hyprland
  config (defaults + optional `~/.config/hypr/local.conf` for machine-specific
  settings), the quickshell `ii` shell, GTK/Qt/Kvantum theming, ghostty / rofi /
  hyprbind / fastfetch configs, the zsh setup, nemo actions, the Bibata cursor
  theme and the wallpaper.
- quickshell loads the shelf plus the launcher / control-center / notifications /
  powermenu / OSD. Quick settings (control center) open from the shelf's
  bottom-right cluster (click) or its thin bottom-right hot strip (hover), from
  `Super+A`, or via `qs -c ii ipc call controlcenter toggle`.
- Shelf layout: launcher button on the left (quickshell launcher), a 1..10 workspace pager with
  per-workspace app icons in the center, and `[system tray][wifi/bt/battery/
  volume][clock]` on the right — the clock shows `yyyy-MM-dd HH:mm`. System
  tray right-click menus need `//@ pragma UseQApplication` in `shell.qml`.
- Power actions in the power menu are forwarded to the host with
  `distrobox-host-exec systemctl …` (the GUI container is not booted with
  systemd).
- The theme switcher keeps Hyprland, GTK, Qt/Kvantum, ghostty and rofi in sync
  (see "Theming"); `apply-theme.sh` runs on every shell start and on theme
  change.
- The GUI container package lists (`files/gui-build/scripts/gui-*.sh`) match
  this set (quickshell + Qt6 + clipse/hypremoji/rofi/fcitx5). Trim/extend them
  as the dotfiles evolve.
- Real-machine specifics (primary monitor, quadgrid workspace rules, extra
  binds) belong in `~/.config/hypr/local.conf` — never in skel, so they survive
  `overwrite=1` re-syncs.
