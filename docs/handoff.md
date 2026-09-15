# HyprTomic — handoff (appDrawer port and current state)

Read this file and continue. Branch: `gui/arch-container` (PR #8, based on `main`).

## Goal / decisions
- Reproduce **end-4 (illogical-impulse)** experience: system foundation + frontend
  mechanism fully mirrored; only standalone tools swapped.
- Host = Fedora Atomic (wayblue, minimal); GUI = **Arch distrobox**
  (`ghcr.io/j7b3y/hyprtomic-gui`), wired via `/usr/bin/hyprtomic-gui-shell`.
- Role split (end-4 vs Base):
  - end-4 keeps: bar/notifications/launcher/lock/wallpaper+matugen/power/session/
    record/OCR/translate/color-pick, **clipboard (cliphist, Super+V)**,
    **screenshots (region selector + swappy, Super+Shift+S)**.
  - Base adopted: `ghostty` (terminal), `nemo` (file manager), `hypremoji`
    (Super+Shift+Period), `hyprbind` (Super+S).
  - Removed: `clipryx`, `snipland`, waybar/dunst/swaybg/qt5ct/qt6ct/kvantum/papirus.
- Keybinds: **Base primary** (Super+Q terminal, Super+X close, Super+F float,
  Super+J split, Super+P pseudo, Super+C browser, Super+M btop, Super+B Bitwarden,
  Super+Delete session). end-4 conflicts moved to free keys.
- IME: **mozkey-ibg-bin only** (AUR prebuilt), fcitx5 profile = JIS
  (`Default Layout=jp`, `keyboard-jp` + `mozkey-ibg`).
- Flatpak: host-managed. Flatseal/Warehouse not added.
- VM GPU: virgl/VF experiments; Moonlight abandoned. Real hardware is the target
  for final validation.

## Repo / CI
- Host recipe `recipes/recipe.yml`; GUI recipe `recipes/gui.yml`.
- Workflows: `build.yml` (host), `gui.yml` (GUI). paths-filtered; PR builds for
  validation, `main` pushes publish. Single `main` is the plan (no main/base,
  main/gui split).
- GUI package layers use `containerfile` snippets COPY+RUN of
  `files/gui-build/scripts/gui-*.sh` so edits under `files/` do not invalidate the
  quickshell layer. quickshell is built first (isolated layer).
- Host image fixed for BlueBuild's `post_build` wiping `/var`: pacman DB moved to
  `/usr/share/pacman/db` (see `gui-99-finalize.sh`).

## Verified working
- `qs -c ii` loads after vendoring the missing **shapes submodule**
  (`end-4/rounded-polygon-qmljs`, pin `e31ec4cb`, commit `b08b025`).
- Session log: `~/.local/state/hyprtomic/gui-session.log` (written by
  `hyprtomic-gui-shell`).
- Duplicate-key bugs fixed: Ctrl+Alt+Delete wlogout fallback removed (`2086089`),
  single-Super fuzzel fallback removed (`91af124`).
- Anime sidebar disabled via `policies.weeb = 0` (`63b5d7a`).
- virtio-only VMs force software rendering; real GPUs keep hardware (`bf6b4ab`,
  `56f59f0`).

## Known issues
- `hyprbind` (v0.1.4 binary) segfaults (core dump).
- VM has no GPU acceleration (llvmpipe/virgl); evaluate effects on real hardware.

## NEXT: appDrawer (ChromeOS-style launcher) — port in progress
Base Dotfiles' launcher was a search + Kickoff-category + app-grid drawer
(`files/system/usr/share/dotfiles/quickshell/modules/launcher/Launcher.qml` on
`main`). It was vendored (unwired) to
`files/system/etc/skel/.config/quickshell/ii/modules/ii/appDrawer/`
(`AppDrawer.qml`, `AppIcon.qml`, commit `34da38d`).

Remaining work:
1. Replace `Root.Theme.*` with ii's `Appearance` (needed props: panelBg,
   panelBorder, surfaceContainer, textPrimary, textSecondary, primary,
   fontFamily, fontSizeNormal, shelfHeight). Integrate with ii theme.
2. Vendor Base's `resolve-icons.py` (was `~/.config/quickshell/scripts/`) and fix
   the path in AppDrawer.qml (currently `Quickshell.env("HOME") +
   "/.config/quickshell/scripts/resolve-icons.py"`).
3. Flatpak launching: rewrite the Exec to `distrobox-host-exec flatpak run <id>`
   (fallback `flatpak run`). No dedicated Flatpak category.
4. Add `IpcHandler` + `GlobalShortcut` target `quickshell:appDrawerToggle`
   (follow the pattern of other ii modules).
5. Bar button: add `AppDrawerButton` at the **left end** of the bar, following the
   bar's position/orientation (bar is `bar.bottom = true`). Material Symbols
   `apps` icon; ii theme colors; must not break existing left-side clicks.
6. Density: `gridColumns` 5 -> 8, margins 12 -> 6, spacing 16 -> 8, icons 64 -> 48.
7. Bind `Henkan_Mode` to the appDrawer toggle and stop invoking ii's search
   launcher from it. Leave single Super press as-is (ii search; no mis-trigger
   risk); switch to Henkan/icon if it feels awkward.
8. Do not create a Flatpak category; just list and launch those apps.

Deliverable: `Henkan` or the bar-left icon opens the drawer with search +
categories + a dense app grid, and Flatpak apps launch via the host.
Commit, push, then on the VM: `ujust overwrite=1 sync-skel-config` + re-login.
