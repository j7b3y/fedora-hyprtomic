# HyprTomic &nbsp; [![host image](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml) [![gui image](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/gui.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/gui.yml)

A personal Fedora Atomic desktop image with a split architecture:

| Layer | What it is | Built from |
|---|---|---|
| **Host** | Fedora Atomic (wayblue base) + Hyprland/SDDM session, system services and CLI tools | `recipes/recipe.yml` → `ghcr.io/j7b3y/fedora-hyprtomic:latest` |
| **GUI container** | Arch Linux distrobox container with the GUI foundation (quickshell, Qt6) and the GUI apps | `recipes/gui.yml` → `ghcr.io/j7b3y/hyprtomic-gui:latest` |
| **Dotfiles** | Baked into `/etc/skel`, synced into `$HOME` with a `ujust` recipe | `files/system/etc/skel/**` |

`$HOME` is shared between host and container, so the same dotfiles serve both
sides. The GUI shell itself (quickshell) runs inside the container; the
compositor and the system services run on the host.

Session flow:

1. SDDM starts the Hyprland session on the host.
2. `~/.config/hypr/hyprland.lua` runs `hyprtomic-gui-shell` on `hyprland.start`.
3. `hyprtomic-gui-shell` creates/updates the `hyprtomic-gui` distrobox container,
   exports GUI helpers (fuzzel, wlogout, clipse, hypremoji, hyprbind, rofi, …)
   to `~/.local/bin`, and starts `hyprtomic-gui-session` inside the container.
4. `quickshell` (config name `ii`) draws the shelf, launcher, control center,
   notifications, OSD and power menu.

Bridges between host and container:

- Container → host command: `distrobox-host-exec <cmd>` (flatpak launches,
  power actions, host CLI helpers).
- Host **system** D-Bus: distrobox only shares the user session bus, so the GUI
  session sets `DBUS_SYSTEM_BUS_ADDRESS`
  (`unix:path=/run/host/run/dbus/system_bus_socket`) to reach the host's BlueZ
  and NetworkManager.
- Container → host entry point: `distrobox enter hyprtomic-gui`.
- GUI apps are not installed on the host; run them from the container (or
  through the exported wrappers).

## What you get

- **Shelf** (bottom bar): launcher button on the left (opens the quickshell
  launcher), a 1–10 workspace
  pager with per-workspace app icons in the center, and
  `[system tray][wifi/bt/battery/volume][clock]` on the right. The clock shows
  `yyyy-MM-dd HH:mm`.
- **Control center** (bottom-right hot strip, click or hover; `Super+A`):
  Wi-Fi, Bluetooth, airplane mode, theme switcher, volume + output device
  selector, brightness.
- **Theming**: `apply-theme.sh` keeps Hyprland borders, GTK3/4, Qt (qt6ct +
  Kvantum), ghostty, rofi and the shell palette in sync. Six md3 themes ship in
  `Theme.qml`; switching is done from the control center.
- **Notifications / OSD / power menu** owned by quickshell: volume OSD, volume
  keys, `Super+Delete` power menu (shutdown / reboot / lock / suspend — power
  actions are forwarded to the host). Notifications keep an unread history:
  the shelf's right end has a bell with an unread badge that opens the
  notification center, and the history is persisted across restarts.
- **IME + clipboard**: fcitx5 with the Mozkey IbG engine and `clipse` run in the
  container (`Super+V` clipboard history, `Super+.` emoji picker).
- **Flatpaks** are managed on the host (system scope). Their desktop entries are
  visible to the container launchers, and the shell starts them through
  `distrobox-host-exec flatpak run …` so they use the host's sandbox.
- **Audio / network / Bluetooth**: PipeWire, NetworkManager and BlueZ run on the
  host; the container talks to them through the shared session bus / host system
  bus.

## Installation

> [!WARNING]
> [Ostree native containers are experimental](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) — use at your own discretion.

To rebase an existing Fedora Atomic installation to the latest build:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/j7b3y/fedora-hyprtomic:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/j7b3y/fedora-hyprtomic:latest
systemctl reboot
```

## First boot

```bash
ujust sync-skel-config                # copy /etc/skel into $HOME (skips existing files)
ujust overwrite=1 sync-skel-config    # replace managed files and prune removed ones, then re-login
```

The GUI container is created automatically by `hyprtomic-gui-shell` on the
first login; it can also be managed explicitly:

```bash
ujust gui-container-setup             # create + initialize the container
ujust gui-container-update            # recreate from the latest image
ujust gui-container-reset             # same as update, explicit
ujust gui-container-status            # show container state
hyprtomic-gui-shell status            # same, via the CLI
```

Session logs: `~/.local/state/hyprtomic/gui-session.log` (quickshell output) and
`/run/user/$UID/quickshell/by-id/*/log.qslog` (details).

## Updating

```bash
rpm-ostree upgrade && systemctl reboot   # host image
ujust gui-container-update               # GUI container image (after a new gui build)
```

Dotfiles only change when the **host image** is updated (they live in
`/etc/skel`), so after a host upgrade re-run `ujust overwrite=1 sync-skel-config`
and re-login to pick them up. The theme is re-applied automatically on every
shell start.

## Configuration

### Hyprland (`~/.config/hypr/`)

| File | Managed? | Purpose |
|---|---|---|
| `hyprland.lua` | yes (skel) | Defaults: monitors, gaps, animations, keybinds, window rules, autostart. Do not edit by hand — it is replaced by `overwrite=1`. |
| `local.conf` | **no** (never shipped) | Machine-specific overrides. Loaded only when present, so it survives every `sync-skel-config`, including `overwrite=1`. Executed as the **last** step of `hyprland.lua`, so it wins over the defaults. |
| `monitors.lua` / `workspaces.lua` | generated (nwg-displays) | Monitor layout and workspace → output assignments written by the `nwg-displays` GUI. Loaded when present, **before** `local.conf`, so a manual override still wins. Delete them to go back to auto-detection. |
| `theme.lua` | generated | Border colours written by `apply-theme.sh`; do not edit. |
| `layouts/quadgrid.lua` | yes (skel) | Custom 2×2 tiling layout; register/apply per monitor via rules. |

`local.conf` is plain Lua, executed by `hyprland.lua` as the very last step, so
whatever it does wins over the defaults. The `hl` API is available, so monitors,
window rules and keybinds can be added or overridden here:

```lua
-- ~/.config/hypr/local.conf
-- Machine-specific overrides are plain Lua executed by hyprland.lua after all
-- defaults; the `hl` API is available.
-- hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.0 })
-- hl.window_rule({ name = "my-rule", match = { class = "^Steam$" }, float = true })
-- hl.bind("SUPER + G", hl.dsp.exec_cmd("flatpak run com.spotify.Client"), { desc = "Spotify" })
--
-- Replacing a default keybind (e.g. open Brave instead of Firefox on Super+C)
-- needs an explicit unbind first: Hyprland runs *every* bind matching the keys,
-- so a second hl.bind alone would fire both actions.
-- hl.unbind("SUPER + C")
-- hl.bind("SUPER + C", hl.dsp.exec_cmd("flatpak run com.brave.Browser"), { desc = "ブラウザ" })
```

Keep machine-specific settings out of skel (this is the whole point of
`local.conf`): the sync recipe prunes anything that the image no longer ships,
but never touches `local.conf`.

**Monitor arrangement (GUI):** `nwg-displays` ships in the GUI container and is
exported to the host PATH, so it can be started from the launcher, rofi or a
terminal. Drag the displays, set mode/scale/rotation and press *Apply* — it
writes `~/.config/hypr/monitors.lua` (+ `monitors.conf`) and reloads Hyprland.
The Hyprland config loads `monitors.lua`/`workspaces.lua` when present (before
`local.conf`), so the layout survives restarts. Delete those files to fall back
to auto-detection.

### Login screen (SDDM)

The astronaut theme is cloned at build time and overlaid from
`files/system/usr/share/hyprtomic/sddm/` (`theme.conf`, wallpaper and the
`Components/` QML overrides). The login policy itself lives in
`/etc/pam.d/sddm`:

- **Password first, fingerprint on empty submit.** `pam_exec` passes the
  submitted password to `/usr/libexec/hyprtomic/pam-fingerprint-gate`. A
  non-empty password makes the stack skip `pam_fprintd` and verifies the
  password as before — a typed password never waits for the reader. An empty
  password fails the gate and starts `pam_fprintd`
  (`timeout=10 max-tries=2`); if that fails or times out, the login fails and
  the password can be typed and submitted again.
- **Enrollment**: run `ujust enroll-fingerprint` (or `fprintd-enroll`) in a
  host terminal; the daemon is D-Bus activated, there is no service to enable.
  `fprintd-list` shows the enrolled fingers, `fprintd-delete` removes them.
- **Feedback**: the theme shows the pam_fprintd messages (e.g.
  “指紋読取装置に指を置いてください”, “検証がタイムアウトしました”) below the
  password field, and the empty password field hints at the flow via
  `TranslatePlaceholderPassword` in `theme.conf`.
- **Caveat**: fingerprint logins pass an empty password to the session, so
  gnome-keyring/KWallet are not unlocked; use the password when a keyring is
  needed.
- **Tuning**: adjust `timeout=`/`max-tries=` on the `pam_fprintd.so` line.
  `/etc/pam.d/sddm` is a copy of the sddm package's PAM file plus the
  fingerprint lines, so re-check it after a Fedora/sddm update. authselect's
  `with-fingerprint` feature only patches `system-auth` (sudo, TTY, hyprlock),
  which is why SDDM needs its own copy.

### Lock screen (hyprlock)

hyprlock does not use PAM for fingerprints: it talks to fprintd itself, in
parallel with the password field, and only when enabled in
`~/.config/hypr/hyprlock.conf` (shipped) via `auth:fingerprint:enabled`
(`auth { fingerprint { enabled = true } }`). The `$FPRINTPROMPT` label below the
input field shows the scan hint and stays empty when fingerprint auth is off or
unavailable, so nothing changes on machines without a reader or enrolled
prints.

- **Password path**: `/etc/pam.d/hyprlock` is shipped with `password-auth` on
  purpose. The hyprlock package's `auth include login` would inherit
  `system-auth`, whose `pam_fprintd` (authselect's `with-fingerprint`) fights
  hyprlock for the reader and makes typed passwords wait for the fingerprint
  timeout.
- **Container**: the power menu's lock runs the container's hyprlock with the
  same config; it reaches the host's fprintd through the shared system bus and
  falls back to the password if that is not possible.
- **Disable**: set `auth:fingerprint:enabled = false` (or drop the block) for
  password-only unlocking.

### Shell (`~/.config/quickshell/ii/`)

- `Theme.qml` + `current-theme`: the theme table and the saved selection. The
  control center's theme page writes `current-theme` and runs
  `scripts/apply-theme.sh <theme>`; the same script runs on every shell start.
- `scripts/apply-theme.sh` owns every generated file (GTK/Qt/Kvantum/ghostty/
  rofi/Hyprland borders). Adding a theme means editing `Theme.qml` **and** the
  `case` block in the script — see `AGENTS.md`.
- The shell config name can be changed with `HYPRTOMIC_QS_CONFIG` (passed
  through by `hyprtomic-gui-shell`); the default is `ii`.

### Container / environment overrides

| Variable | Default | Meaning |
|---|---|---|
| `HYPRTOMIC_GUI_CONTAINER` | `hyprtomic-gui` | distrobox container name |
| `HYPRTOMIC_GUI_IMAGE` | `ghcr.io/j7b3y/hyprtomic-gui:latest` | container image |
| `HYPRTOMIC_QS_CONFIG` | `ii` | quickshell config directory name |

## Key bindings

`SUPER` is the main modifier. The full list is available with `Super+/`
(hyprbind).

| Shortcut | Action |
|---|---|
| `Super+Q` / `Super+E` | Ghostty / Nemo |
| `Super+C` / `Super+B` / `Super+M` | Firefox / Bitwarden / Mission Center (flatpaks) |
| `Super+X` / `Super+F` | Close window / toggle floating |
| `Super+Arrow` / `Super+Shift+Arrow` | Focus / move window |
| `Super+1…0` / `Super+Shift+1…0` | Focus / move window to workspace 1–10 |
| `Super+Tab`, `Super+[` `]`, `Super+wheel` | Previous / next workspace |
| `Super+/` | Keybind viewer (hyprbind) |
| `Super+Alt` (hold Super, tap Alt) or 変換 (`Henkan`) | App launcher (quickshell launcher) |
| `Super+A` | Control center |
| `Super+Delete` | Power menu |
| `Super+L` | Lock (hyprlock) |
| `Super+Escape` | Window switcher (rofi) |
| `Super+V` / `Super+.` | Clipboard history / emoji picker |
| `Super+Shift+S` / `Super+Ctrl+Shift+S` | Region screenshot → clipboard + file / file only |
| `Super+Shift+P` | Colour picker |
| `XF86Audio*` | Volume, mute, mic mute, media control |

## Repository layout

| Path | Purpose |
|---|---|
| `recipes/recipe.yml` | Host image: packages, os-release rebrand, build scripts, default flatpaks |
| `recipes/gui.yml` | GUI container image: package layers + session assets |
| `files/system/**` | Copied verbatim to `/` of the host image (skel dotfiles, systemd units, `hyprtomic-gui-shell`, SDDM assets, ujust recipe) |
| `files/scripts/**` | Host build-time scripts (referenced by bare name from `recipe.yml`) |
| `files/gui-build/scripts/gui-*.sh` | GUI container build scripts, one per package layer |
| `files/gui/**` | Copied verbatim to `/` of the GUI container (session entrypoint, profile snippets) |
| `AGENTS.md` | Architecture notes, dotfile integration contract, theming pipeline and change rules |

`docs/` and `opencode.json(c)` are intentionally gitignored.

## Known issues / notes

- **Chromium/Electron flatpaks and CJK fonts**: flatpak ≥ 1.18 exposes host fonts
  to the sandbox only through `/run/host/font-dirs.xml` `<remap-dir>` entries,
  which reuse the host fontconfig caches (`cache-9`). Chromium and Electron
  bundle a newer fontconfig (`cache-11`), cannot read those caches and do not
  rescan the remapped directories, so every host font disappears — Latin still
  renders (runtime fonts), Japanese becomes tofu. `hyprtomic-flatpak-fonts`
  writes a per-app `~/.var/app/<app-id>/config/fontconfig/fonts.conf` with
  plain `<dir>` entries; it runs on every session start and can be re-run with
  `ujust fix-flatpak-fonts`. Restart the affected app afterwards. Firefox is
  not affected (it uses the runtime fontconfig).
- **Theming reach**: host fonts/themes are visible to the containers (distrobox
  bind-mounts `/usr/share/{fonts,themes,icons}`), but assets installed *only* in
  the GUI container are not visible to the host or other distroboxes. Flatpaks
  see host fonts plus their per-app `xdg-config` permissions; Kvantum/Qt theming
  cannot be shipped to flatpaks. See `AGENTS.md` → "Theming".
- **`local.conf` is the escape hatch** for anything machine-specific; never rely
  on hand-editing files that live in `/etc/skel`.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s
[cosign](https://github.com/sigstore/cosign). Download `cosign.pub` from this
repo and run:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
cosign verify --key cosign.pub ghcr.io/j7b3y/hyprtomic-gui
```
