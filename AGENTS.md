# AGENTS.md — working in this repository

HyprTomic is a personal Fedora Atomic (wayblue) desktop image whose GUI lives in
an Arch distrobox container. This file describes the architecture, the
operational method and the rules for changing things. Read it before editing
anything.

## TL;DR

- **Host** (`recipes/recipe.yml` → `ghcr.io/j7b3y/fedora-hyprtomic:latest`): Fedora
  Atomic base + Hyprland/SDDM session, system services, host CLI tools. Both
  host recipes share `recipes/recipe-common-packages.yml` +
  `recipes/recipe-common-dotfiles.yml`; `recipes/recipe-vypr.yml` adds Vypr
  and the libvirt/QEMU stack and publishes the same repository under
  `:latest-vypr` (`alt-tags`), so the variants can never be upgraded into one
  another by accident.
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
| `recipes/recipe.yml` | Host image (`:latest`): common modules + signing |
| `recipes/recipe-vypr.yml` | Vypr host image (`:latest-vypr`): common modules + Vypr build stage + libvirt/QEMU stack |
| `recipes/recipe-common-packages.yml` | Shared host os-release + package layer (both host images) |
| `recipes/recipe-common-dotfiles.yml` | Shared host skel/scripts/systemd/flatpak layer (both host images) |
| `recipes/gui.yml` | GUI container image: package layers + session asset |
| `files/system/**` | Copied verbatim to `/` of the host image (skel dotfiles, systemd units, `hyprtomic-gui-shell`, SDDM assets, polkit rule, ujust recipe) |
| `files/vypr/**` | Copied verbatim to `/` of the **Vypr image only** (`hyprtomic-vypr-setup`, ujust fragment; folded into 60-custom.just by `vypr-finalize.sh`) |
| `files/scripts/**` | Host build-time scripts (run inside the image build; referenced by bare name from `recipe.yml`). `vypr-build.sh` runs in the Vypr build stage; `vypr-finalize.sh` only in the Vypr image |
| `files/gui-build/scripts/gui-*.sh` | GUI container build scripts, one per package layer (see below) |
| `files/gui/**` | Copied verbatim to `/` of the **GUI container** (session entrypoint, python requirements, the `vypr` host-exec shim) |
| `.github/workflows/build.yml` | Host image CI (paths-filtered) |
| `.github/workflows/vypr.yml` | Vypr host image CI (paths-filtered) |
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
   - registers the other distroboxes' `.desktop` files for the launcher in the
     background (`hyprtomic-distrobox-apps`; the
     `hyprtomic-distrobox-apps.service` user unit keeps following container
     starts, `ujust refresh-distrobox-apps` forces a pass),
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
| Hyprland config | `~/.config/hypr/hyprland.lua` (Lua). It starts the GUI container with `hyprtomic-gui-shell` (autostart). `finalize.sh` deletes wayblue's stale `/etc/skel/.config/hypr/hyprland.conf`. Machine-specific overrides go in `~/.config/hypr/local.conf` (Lua, **not** shipped in skel), which `hyprland.lua` executes **last** so it wins over the defaults; overriding a default keybind needs `hl.unbind(keys)` first (a second `hl.bind` would leave both actions active). The GUI container's `nwg-displays` writes `monitors.lua`/`workspaces.lua`; `hyprland.lua` requires them when present (before `local.conf`, so manual overrides win). |
| SDDM login | `/etc/pam.d/sddm` (shipped) is password-first with a fingerprint fallback: `pam_exec` + `/usr/libexec/hyprtomic/pam-fingerprint-gate` skips `pam_fprintd` when a password was submitted, otherwise `pam_fprintd` (10s, 2 tries) runs before `password-auth`. `fprintd`/`fprintd-pam` ship on the host. The theme is the upstream astronaut theme overlaid from `files/system/usr/share/hyprtomic/sddm/` by `install-sddm-theme.sh`; `Components/LoginForm.qml` there is a copy of upstream plus the `FingerprintStatus` line — refresh it when upstream changes the form. |
| Lock screen | `~/.config/hypr/hyprlock.conf` (skel) keeps hyprlock's native fingerprint **off** (`auth:fingerprint:enabled = false`): native holds the fprintd device for the whole lock session and overheats the sensor (~3 min, then hyprlock segfaults on unlock). Fingerprint runs bounded through PAM instead: `/etc/pam.d/hyprlock` (shipped) reuses `pam-fingerprint-gate` (typed password skips `pam_fprintd`, empty submit runs one `timeout=10 max-tries=1` window) followed by `password-auth`; the `$PAMPROMPT` label shows the reader messages and the input placeholder hints at the empty-submit flow. Never enable native and `pam_fprintd` together. The container's hyprlock shares the config and reaches the host's fprintd over the shared system bus. |
| GUI shell config | `~/.config/quickshell/ii` inside the container. Set `HYPRTOMIC_QS_CONFIG` on the host if the config name is not `ii` (passed through by `hyprtomic-gui-shell`, read by `hyprtomic-gui-session`). The config's internal scripts reference `~/.config/quickshell/ii/...` — keep that path. |
| Terminal | The host ships `ghostty` (copr `scottames/ghostty`); its config falls back to a host CJK mono font (HackGen ships in the container only). The container keeps its own ghostty for shell actions, but its desktop entry is overridden in `/usr/local/share/applications/com.mitchellh.ghostty.desktop` to run `distrobox-host-exec ghostty`, so the launcher/rofi open the host terminal like `Super+Q`. |
| Bar / notifications | quickshell owns the shelf / launcher / control-center / notifications / powermenu / OSD. waybar/dunst are **not** installed; `swaybg` (host) sets the wallpaper. The shelf's left button and `Super+Alt` (or the Henkan key) open the quickshell launcher; the bell at the right end opens the notification center (unread badge; history persisted to `~/.cache/quickshell/notifications.json`, opening the center marks it read); `rofi` (container, exported) remains for the `Super+Escape` window switcher. |
| Launcher sources | The launcher has two single-line filter rows (horizontal scroll): a container/launch-source row above the app categories. Sources: the GUI container (`CONTAINER_ID`), `Flatpak`, `Host` (the host's own applications) and other distroboxes registered by `hyprtomic-distrobox-apps`. There is no `All` chip (it only duplicated apps across sources); `activeContainer` selects the first source until a chip is clicked. The exporter writes standard `~/.local/share/applications/<container>-*.desktop` files with `Exec=distrobox-host-exec distrobox-enter -n <c> -- …` (the GUI container has no `distrobox` CLI), tags them with `X-HyprTomic-Container=`. The same script registers the host's visible `/usr/share/applications` entries as `host-<id>.desktop` (host-native `Exec`, `X-HyprTomic-Host=1` marker, refreshed and pruned as the source changes), so host apps (virt-manager on the vypr image, nemo, ...) are launchable from the launcher; the launcher drops `host-X` when the GUI container or a flatpak also provides `X` (the ghostty override wins over the host entry), and runs host entries through `distrobox-host-exec` (a `Terminal=true` entry opens in the host ghostty). Each pass converges: it re-exports (overwrite), prunes entries whose source `.desktop` disappeared or no longer passes the export filter, refreshes mirrored icons and copies absolute container-only `Icon=` files into `~/.local/share/hyprtomic/app-icons/`, drops stale Steam cover art, and removes exports plus distrobox's own `<container>.desktop` entries of deleted containers. It scans the application dirs recursively (wine installs into `wine/Programs/...` subdirectories) and, when home is shared, only wraps entries whose `Exec` binary exists in that container, so one container never registers another container's or the host's apps. Only real distrobox commands count as "already exported" — container homes (`~/distrobox/<name>/`) are fine, so wine `WINEPREFIX` paths and apps installed there are registered. Entries whose id uwsm rejects (Steam shortcuts with spaces) launch through their `Exec`. The exporter runs as the `hyprtomic-distrobox-apps.service` user unit (`--watch`, polls the running-container list) plus a one-shot at session start. It also mirrors container-home icons (Steam `steam_icon_*`) into `~/.local/share/icons/` and writes Steam cover art to `~/.local/share/hyprtomic/app-icons/` for games whose clienticon is tiny or missing. |
| Clipboard / IME | `clipse` + `clipse-gui` (container AUR): the daemon is started by `hyprtomic-gui-session`, `Super+V` opens the GUI (exported). fcitx5 + mozkey-ibg-bin live in the container; the host env exports `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS`. |
| Video player | Haruna runs in the GUI container (Qt/QML + libmpv; its Kirigami colors come from the generated `~/.config/kdeglobals`, widget dialogs from qt6ct/Kvantum; MPRIS for `playerctl`/media keys). `files/system/etc/skel/.local/share/applications/org.kde.haruna.desktop` overrides the container's own entry in the shared `$HOME`, so the host's nemo/`xdg-open` find it; `Exec=haruna` resolves on both sides through the shim `hyprtomic-gui-shell` exports to `~/.local/bin`. `register_haruna_mimes()` (same script) makes it the default handler **only** for MIME types that have none, so a user's own choice wins. |
| GTK / Qt theming | Driven by `~/.config/quickshell/ii/scripts/apply-theme.sh` (see "Theming"): GTK3/4 gtk.css, qt5ct/qt6ct palettes + a recolored Kvantum theme, ghostty palette, rofi colors and Hyprland borders. Adwaita base + Bibata-Modern-Classic cursor (baked into the dconf db). Icons: Papirus-Dark on the host, Tela-circle-dark in the GUI container (see "Where the theme is consumed"). |
| Python deps | The shell venv is built from `files/gui/usr/share/hyprtomic/uv-requirements.txt` (installed into the container at `/usr/share/hyprtomic/`, currently empty; `resolve-icons.py` needs only the container's python-gobject + gtk3). |
| Flatpaks | Host-managed (system scope). `hyprtomic-gui-shell` bind-mounts `/var/lib/flatpak` read-only into the container and sets `XDG_DATA_DIRS`; the shell launches flatpaks via `distrobox-host-exec flatpak run <app-id>`. Startup / run-in-background permissions: `xdg-desktop-portal-gnome` provides `org.freedesktop.portal.Background` (the Hyprland and GTK backends do not; `files/system/etc/xdg/xdg-desktop-portal/portals.conf` routes only Background to it), `hyprtomic-gui-shell` seeds the empty `background/background` permission-store row so Flatseal's Background toggle is usable, and `dex-autostart` (autostart in `hyprland.lua`) runs host-owned `~/.config/autostart` entries at login. Entries owned by the GUI container (its own `/etc/xdg/autostart` plus user entries whose command exists only inside it) are run inside the container by `hyprtomic-container-autostart`, which `hyprtomic-gui-session` starts; the fcitx5 entry is excluded there because the session starts fcitx5 manually. Discord Rich Presence: the same session script points `$XDG_RUNTIME_DIR/discord-ipc-0` at the installed flatpak client (Vesktop) and adds the matching global flatpak overrides. |
| Bitwarden | The flatpak's "Unlock with system authentication" (`https://bitwarden.com/help/biometrics/`) checks the polkit action `com.bitwarden.Bitwarden.unlock`; a sandboxed install cannot set the policy up itself (the app only shows "Automatic setup not available" and links to the docs), so the image ships `files/system/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` with that action id. Keep it in sync with upstream `apps/desktop/resources/com.bitwarden.desktop.policy`; the authentication prompt comes from `hyprpolkitagent` (started by `hyprland.lua`). |
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
| Kvantum | `~/.config/Kvantum/hyprtomic/{hyprtomic.kvconfig,hyprtomic.svg}` | recolored copy of the catppuccin theme from skel; text selection is overridden to an opaque accent with background-coloured text (the upstream 30%-alpha highlight is unreadable with light accents); running apps pick it up on restart |
| KDE / Kirigami | `~/.config/kdeglobals` (`[Colors:*]` groups) | KColorScheme ignores the Qt palette and falls back to Breeze Light without these groups, so KDE apps (Haruna, kdialog) would be light on a dark desktop; generated from the same hexes, running apps pick it up on restart |
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
- **Icon theme**: the host db (`files/system/etc/dconf`) keeps
  **Papirus-Dark** (Fedora `papirus-icon-theme`). The GUI container ships
  **Tela-circle-dark** plus its **own** dconf system db under
  `files/gui/etc/dconf` (compiled by `gui-99-finalize.sh`): without it the
  container's gsettings falls back to the schema default (Adwaita) and the
  shell's `resolve-icons.py` resolves blurry legacy 16px icons. Papirus is not
  duplicated into the GUI image (distrobox bind-mounts the host's
  `/usr/share/icons` at `/usr/local/share/icons`, so it stays available).
  When changing the icon theme, update both dbs (and the GUI package list).
  `qt5ct`/`qt6ct` (`~/.config/qt{5,6}ct/*.conf`, shared with the host) also
  point at Tela-circle-dark so the container's Qt apps match; the host's only
  Qt apps are `qt6ct`/`kvantummanager`, which fall back to generic icons
  because Tela is not packaged for Fedora.
  Per-app fixes for low-resolution icons (flatpak exports, e.g. Firefox's
  128px one) go in `~/.local/share/hyprtomic/app-icons/<icon-name>.svg|png`;
  `resolve-icons.py` checks that directory before the theme lookup.
- **Other distrobox containers**: distrobox bind-mounts the host's
  `/usr/share/{fonts,icons,themes}` into every container at
  `/usr/local/share/...`, and `$HOME` is shared. Assets installed only in the
  GUI container are therefore invisible to the host and to other containers —
  put shared fonts/themes on the host image, not in the GUI container. (The
  icon theme is a deliberate exception: the GUI container's Tela-circle only
  has to be visible to the shell inside it.)
- **Flatpaks**: only host fonts (`/run/host/fonts`) and per-app `xdg-config`
  permissions are visible. Firefox has `xdg-config/gtk-3.0:ro`, Chrome does
  not, and Kvantum/Qt theming cannot be shipped to flatpaks. Keep flatpak
  expectations low and document deviations instead of chasing parity.
- **Known upstream issue**: flatpak ≥ 1.18 exposes host fonts only through
  `<remap-dir>` entries that point at the host fontconfig caches (`cache-9`).
  Chromium/Electron bundle a newer fontconfig (`cache-11`), cannot read those
  caches and do not rescan, so all host fonts disappear for them (Japanese
  renders as tofu, Latin still works because the runtime ships Latin fonts).
  `hyprtomic-flatpak-fonts` fixes it per app by re-registering plain
  `/run/host/fonts` dirs in the app's own fontconfig; it runs at session start
  and via `ujust fix-flatpak-fonts`. Firefox uses the runtime fontconfig and is
  unaffected.

## Vypr (latest-vypr image)

`recipes/recipe-vypr.yml` publishes `ghcr.io/j7b3y/fedora-hyprtomic:latest-vypr`
(Vypr shows each Windows-VM application as a native window, over shared memory,
with a passed-through GPU; https://github.com/Amzi-01/Vypr). The base
`:latest` image stays without it. Contract and gotchas:

- **Pin**: host binaries are built in the `vypr` build stage from the v0.5.0
  source tarball (`files/scripts/vypr-build.sh`, sha256-pinned) and copied to
  `/usr/bin`; the same release's `vypr-setup.exe` (the Windows-side installer)
  ships at `/usr/share/vypr/vypr-setup.exe`. Bump `VYPR_TAG` and both hashes
  together — host and guest protocol versions must match. The build script
  applies two patches to the installed `launcher/vypr` (report upstream, drop
  them when fixed there - the patch step asserts its anchors): its `virsh`
  calls run under `LC_ALL=C` (the script compares `virsh domstate` output
  against the English words "running"/"shut off", and ja_JP made `vypr
  detect` try to start an already-running VM and exit), and
  `ensure_guest_ram` no longer treats an unreadable `/etc/libvirt/qemu.conf`
  (root-only on the Fedora base) as a wrong one - it asks the running QEMU
  first and only fails on a value it actually read.
- **Setup**: `ujust vypr-setup` runs `hyprtomic-vypr-setup` (`files/vypr/`):
  picks a libvirt domain, edits the domain XML (memfd shared RAM, removes the
  USB tablet, topoext, emulated sound card, optional virtiofs share), checks
  qemu.conf/libvirt group/default network/IOMMU kargs and offers the root
  steps via sudo after confirmation, creates `~/.ssh/vypr-guest` and
  `~/.config/vypr/config`, then builds the pairing CD (`vypr-setup.exe`,
  public key, `pair.cmd`, `vc_redist.x64.exe` - the guest agent is a dynamic
  MSVC build and upstream ships no Visual C++ runtime, which made the agent
  task die with 0xC0000135 - and a Japanese README; xorriso) and attaches it
  as a USB CD - `--live` when the VM runs, so a running Windows sees it at
  once. `pair.cmd` installs the runtime, copies the key to the clipboard and
  opens the installer, so the guest side is one double-click. It is
  idempotent and **never rewrites** an existing config (only appends missing
  keys). With no domain on the machine it offers to create the Vypr-ready VM
  first (asks only for the Windows ISO, looks in Downloads/Documents/Desktop
  for it, then runs `ujust vypr-create-vm`) and continues.
  `ujust vypr-guest-exe` remains for copying the files out by hand;
  `ujust vypr-doctor` runs Vypr's own health check.
- **VM creation**: `ujust vypr-create-vm <iso>` runs
  `hyprtomic-vypr-create-vm`: virt-install with UEFI + Secure Boot + TPM 2.0,
  SATA disk and e1000e NIC (no extra Windows drivers) and an optional
  passed-through GPU (boot_vga cards are excluded; the HDMI audio function is
  matched by subsystem id and attached too; virt-install's hostdev is managed,
  so libvirt detaches/reattaches the card around VM runs). The USB tablet
  virt-install adds by default stays until `ujust vypr-setup` removes it - it
  helps while installing, and raw-input games need it gone. If the ISO's
  directory has non-UTF-8 file names (virt-install crashes listing them in
  the auto-created pool), the ISO is hardlinked into
  `~/.local/share/vypr/iso/` first. The ISO is a normal argument; right after
  starting, a few keypresses are sent so OVMF's "Press any key to boot from
  CD or DVD" prompt is not missed and the installer really starts.
- **libvirt state dirs**: BlueBuild wipes `/var`, so the RPM-created
  `/var/lib/libvirt/**` and their SELinux labels are missing from the image;
  on first boot the daemons recreate them as `var_lib_t` and `virtnetworkd`
  (enforcing) cannot create `dnsmasq/`, leaving the default network down.
  `files/vypr/usr/lib/tmpfiles.d/10-vypr-libvirt.conf` recreates + relabels
  the tree at boot, and the ujust root steps run `restorecon` + `net-define`
  to heal a machine that already booted without it.
- **IOMMU**: the kargs step (`rpm-ostree kargs --append-if-missing=...`) is
  only offered when the firmware exposes DMAR/IVRS but the kernel has IOMMU
  off. If neither table exists (hidden BIOS setting) the scripts say the OS
  cannot enable it rather than adding a useless karg.
- **Atomic updates**: `~/.config/vypr/**`, `~/.ssh/vypr-guest*`, registered
  `.desktop`/icons are in `$HOME`; domain XML is in `/etc/libvirt/qemu/`;
  qemu.conf, `/etc/libvirt/hooks/qemu`, `/etc/modprobe.d/` and
  `rpm-ostree kargs` are `/etc`/deployment state. None of it is image-managed,
  so upgrades never clobber it. Only `/usr/bin/vypr*` and `/usr/share/vypr/`
  follow the image. `hyprtomic-vypr-setup` leaves a
  `/etc/libvirt/qemu.conf.hyprtomic-vypr.bak` before editing.
- **PCIe passthrough**: IOMMU args are suggested as
  `rpm-ostree kargs --append-if-missing=...` (revert with `--delete`);
  boot-time vfio binding lives in `/etc/modprobe.d/vfio.conf`; the dynamic GPU
  swap uses libvirt's single `/etc/libvirt/hooks/qemu` file (`ujust
  vypr-gpu-swap` prints upstream's steps; do not turn it into a qemu.d/
  directory, libvirt never calls those).
- **Launcher**: `vypr add`/`detect` write
  `~/.local/share/applications/vypr-<app>.desktop` with `Exec=/usr/bin/vypr
  run <app>` and icons in `~/.local/share/icons/hicolor/...`; the shared
  `$HOME` makes the quickshell launcher list them under the GUI-container
  source chip. `files/gui/usr/bin/vypr` is a shim that forwards the whole
  command to the host with `distrobox-host-exec`, so the absolute Exec resolves
  inside the container; on the host the same path is the real launcher.
- **Hyprland**: Vypr windows are ordinary xdg_toplevels whose class/app_id is
  `vypr-<app>` (matching the desktop entry for icon/name). The skel
  `float-vypr` window rule floats them, centers them, sets
  `idle_inhibit = "focus"` (windowed games must not let the screen blank) and
  `no_blur`; the guest owns the window size and Vypr negotiates resizes, so
  tiling would fight it. Users override in `local.conf` if they want.
- **Windows side** (`vypr-setup.exe`): grants "Lock pages in memory", enables
  auto-login (a locked screen has nothing to capture), installs an SSH server
  with the host key, optionally Parsec's mouse driver and WinFsp; with
  `OPEN_ELEVATION=1` (default) it turns the UAC prompt off, which is a real
  security reduction for the VM — `vypr open-elevation --remove` undoes it.
- The GUI image carries the shim for **all** host variants; it fails cleanly
  ("vypr: not configured"/command not found) if the host is the base image.

## Build + CI rules

- **Only `main` publishes images.** Feature branches are validated by opening a
  PR (or `workflow_dispatch`). Pushing to a feature branch does not build.
- Do not push commits to a branch you do not own; create a new branch and open a
  PR instead. New branches are safe to push (no workflow triggers on push).
- `build.yml` ignores `files/scripts/gui-*` and `files/scripts/vypr-*`;
  `vypr.yml` builds `recipe-vypr.yml` and watches the two common recipe files,
  `files/system/**`, `files/vypr/**` and `files/scripts/**`; `gui.yml` only
  watches `recipes/gui.yml`, `files/gui/**`, `files/gui-build/**`. If you move
  files between those trees, update the path filters.
- **PRs always report all checks.** All three workflows trigger on every pull
  request (no `pull_request.paths`), and a `dorny/paths-filter` step mirrors
  the push `paths:` lists to gate only the BlueBuild step: one-sided PRs still
  report `bluebuild` / `bluebuild-vypr` / `bluebuild-gui` as green with the
  expensive build skipped (`build.yml` is required by the `main protect`
  ruleset; a workflow-level paths filter used to leave it "Expected" and block
  merges). Keep the PR filter lists in sync with the push `paths:` lists;
  push/schedule/dispatch keep the workflow-level filters and always build.
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
bash -n files/system/usr/bin/hyprtomic-distrobox-apps
bash -n files/gui/usr/bin/hyprtomic-gui-session
sh -n files/system/usr/libexec/hyprtomic/pam-fingerprint-gate
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
- Vypr ships as a second host tag (`latest-vypr`, see "Vypr" above): the
  host binaries + `vypr-setup.exe` are built/downloaded at image build time,
  `ujust vypr-create-vm <iso>` creates the Windows VM (GPU attach included),
  `ujust vypr-setup` configures it and the guest setup at any time, and
  the GUI container's `/usr/bin/vypr` shim makes the registered apps work
  from the launcher. The `:latest` image is unchanged and has none of it.
- The hostname is not assigned at first boot: the installer's name (os-release
  `DEFAULT_HOSTNAME` is only a default) or `hostnamectl set-hostname` is used
  and persists in `/etc` across image updates (README "ホスト名").
- Video playback lives in the GUI container: Haruna (Qt6/QML + libmpv,
  theme-following, MPRIS). The skel desktop entry plus the exported `haruna`
  shim make host-side nemo / `xdg-open` work, and `hyprtomic-gui-shell`
  registers it as the default handler for MIME types without one.
- SDDM logs in password-first and only falls back to the fingerprint reader
  when the password field is submitted empty (`/etc/pam.d/sddm` +
  `pam-fingerprint-gate`); the theme shows the pam_fprintd prompts and hints
  at the empty-submit flow in the password placeholder. hyprlock keeps its
  native fingerprint off (continuous verify overheats the sensor) and runs
  one bounded pam_fprintd window per empty submit (/etc/pam.d/hyprlock +
  pam-fingerprint-gate, $PAMPROMPT label); a typed password skips the
  reader with no wait.
- The Arch dotfiles are ported under `files/system/etc/skel/`: a Lua Hyprland
  config (defaults + optional `~/.config/hypr/local.conf` for machine-specific
  settings), the quickshell `ii` shell, GTK/Qt/Kvantum theming, ghostty / rofi /
  hyprbind / fastfetch configs, the zsh setup, nemo actions, the Bibata cursor
  theme and the wallpaper.
- quickshell loads the shelf plus the launcher / control-center / notifications /
  powermenu / OSD. Quick settings (control center) open from the shelf's
  bottom-right cluster (click) or its thin bottom-right hot strip (hover), from
  `Super+A`, or via `qs -c ii ipc call controlcenter toggle`. The launcher's
  filter chips are two single-line rows: container/launch-source (the GUI
  container, Flatpak, Host, other distroboxes) above the app categories; both
  scroll horizontally when they overflow (`FilterChipRow.qml`). The container
  row has no `All` chip (it only duplicated apps across sources); Host lists
  the host's applications registered by `hyprtomic-distrobox-apps` as
  `host-<id>.desktop` (virt-manager on the vypr image, nemo, ...) and runs them
  through `distrobox-host-exec`, with the container/flatpak variant winning
  when both sides provide the same app (the ghostty override over the host
  entry). The first source is selected by default. Exported entries whose id
  uwsm rejects (Steam shortcuts contain spaces) are launched through their
  `Exec` instead.
- Shelf layout: launcher button on the left (quickshell launcher), a 1..10 workspace pager with
  per-workspace app icons in the center, and `[system tray][wifi/bt/battery/
  volume][clock]` on the right — the clock shows `yyyy-MM-dd HH:mm`. System
  tray right-click menus need `//@ pragma UseQApplication` in `shell.qml`.
- Power actions in the power menu are forwarded to the host with
  `distrobox-host-exec systemctl …` (the GUI container is not booted with
  systemd).
- Flatpak startup/background permissions work end to end: the Background portal
  (`xdg-desktop-portal-gnome`, routed via
  `/etc/xdg/xdg-desktop-portal/portals.conf`) serves app requests and Flatseal's
  per-app Background toggle; the host's `dex-autostart` runs host-owned
  `~/.config/autostart` entries at login, while entries owned by the GUI
  container (the GUI image's `/etc/xdg/autostart` and user entries whose command
  exists only inside the container) are run inside it by
  `hyprtomic-container-autostart` (fcitx5 stays manually started by
  `hyprtomic-gui-session`). The GNOME backend's app-state monitor needs
  gnome-shell, so background-app monitoring (kill/notify) stays inactive under
  Hyprland; the permission grant, the autostart file and Flatseal are
  unaffected.
- Discord Rich Presence works with flatpak clients (Vesktop): `hyprtomic-gui-shell`
  points `$XDG_RUNTIME_DIR/discord-ipc-0` at the client's sandbox socket and adds
  the matching global flatpak override, so games and apps can set presence. Only
  Game SDK games work - process scanning cannot see other sandboxes.
- The theme switcher keeps Hyprland, GTK, Qt/Kvantum, ghostty and rofi in sync
  (see "Theming"); `apply-theme.sh` runs on every shell start and on theme
  change.
- The GUI container package lists (`files/gui-build/scripts/gui-*.sh`) match
  this set (quickshell + Qt6 + clipse/hypremoji/rofi/fcitx5). Trim/extend them
  as the dotfiles evolve.
- Real-machine specifics (primary monitor, quadgrid workspace rules, extra binds,
  rebinding a default via `hl.unbind` + `hl.bind`) belong in
  `~/.config/hypr/local.conf` — never in skel, so they survive `overwrite=1`
  re-syncs.
