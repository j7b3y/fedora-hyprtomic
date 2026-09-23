#!/usr/bin/env python3
"""Resolve icon names to file paths using the GTK icon theme.

Uses the same icon resolution algorithm as nwg-dock (a GTK3 app), so the
icon pack is consistent between the dock and the Quickshell launcher/shelf.

GTK correctly follows the `Inherits` chain declared in each theme's
index.theme. For example, with `Tela-circle-dark` active (which inherits
`hicolor,Adwaita,breeze`), GTK searches:
  Tela-circle-dark → hicolor → Adwaita → breeze
and not arbitrary theme directories. This fixes the previous bash resolver,
which picked `Papirus` icons when the active theme was `Papirus-Dark` because
the script's hardcoded scoring preferred the `Papirus` directory.

Usage:
    resolve-icons.py [icon_name ...]
    resolve-icons.py --wmclass [window_class ...]

If no icon names are given, scans all .desktop files for Icon= entries
and resolves those. Otherwise, resolves only the supplied names.
With ``--wmclass`` the arguments are window classes (as reported by the
compositor): each class is mapped to a desktop entry via ``StartupWMClass``
(or the entry id) before its ``Icon=`` value is resolved.

Output: name<TAB>path (one per line). Names that cannot be resolved are
omitted. Symbolic icons (`*/symbolic/*`) are skipped — they render as
black/transparent SVGs without theme colorization, so they're useless as
fallback art.

Per-app overrides: a file named after the icon (e.g.
`org.mozilla.firefox.png` or `.svg`) in `~/.local/share/hyprtomic/app-icons/`
wins over the theme lookup. Use it when an app ships a low-resolution icon
(some flatpak exports max out at 128px). hyprtomic-distrobox-apps also drops
Steam cover art there as `.jpg` when a game only ships a tiny clienticon.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402


def _read_gsettings_theme() -> str:
    """Read the active icon theme name from gsettings (same source nwg-dock uses)."""
    for schema in ("org.cinnamon.desktop.interface", "org.gnome.desktop.interface"):
        try:
            r = subprocess.run(
                ["gsettings", "get", schema, "icon-theme"],
                capture_output=True, text=True, timeout=2,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
        if r.returncode != 0:
            continue
        val = r.stdout.strip().strip("'")
        if val and val != "hicolor":
            return val
    return ""


def _init_theme() -> Gtk.IconTheme:
    """Build an IconTheme that honors the user's gsettings icon theme."""
    theme_name = _read_gsettings_theme()
    if theme_name:
        # Settings may be cached from process init; force the live value so
        # theme switches (via apply-icon-theme.sh → quickshell restart) take
        # effect on the very first lookup.
        Gtk.Settings.get_default().set_property("gtk-icon-theme-name", theme_name)
    return Gtk.IconTheme.get_default()


THEME = _init_theme()


def _direct_file(name: str) -> str | None:
    """Handle absolute-path icon entries (some .desktop files use these)."""
    if not os.path.isabs(name):
        return None
    if os.path.isfile(name) and os.access(name, os.R_OK):
        return name
    return None


def _override_icon(name: str) -> str | None:
    """Per-app icon override: ~/.local/share/hyprtomic/app-icons/<name>.<ext>.

    Checked before the theme lookup, so it also beats a low-resolution icon
    from a flatpak export. The file name is the desktop entry's Icon= value
    (e.g. org.mozilla.firefox.png).
    """
    if "/" in name:
        return None
    root = os.path.expanduser("~/.local/share/hyprtomic/app-icons")
    for ext in (".svg", ".png", ".webp", ".jpg", ".jpeg"):
        path = os.path.join(root, name + ext)
        if os.path.isfile(path) and os.access(path, os.R_OK):
            return path
    return None


def _is_symbolic(path: str) -> bool:
    return "/symbolic/" in path.split(os.sep) or path.endswith("/symbolic")


def _manual_search(name: str) -> str | None:
    """Fallback: walk GTK's search path manually (mirrors freedesktop spec).

    Directory size first (e.g. 256x256 > 64x64), PNG > SVG > XPM, no symbolic.
    This catches icons in flatpak/nix-profile dirs that the default theme
    might not search if not registered.
    """
    if "/" in name:
        return _direct_file(name)
    exts = (".png", ".svg", ".xpm")
    candidates: list[tuple[int, int, str]] = []
    for root in THEME.get_search_path():
        for sub in (
            f"{root}/apps/{name}",
            f"{root}/categories/{name}",
            f"{root}/devices/{name}",
            f"{root}/mimetypes/{name}",
            f"{root}/places/{name}",
            f"{root}/actions/{name}",
            f"{root}/status/{name}",
            f"{root}/apps/scalable/{name}",
            f"{root}/categories/scalable/{name}",
        ):
            for ext in exts:
                p = sub + ext
                if not os.path.isfile(p) or not os.access(p, os.R_OK):
                    continue
                if _is_symbolic(p):
                    continue
                # Size scoring: extract e.g. "64" from "64x64" in path
                size = 0
                for part in p.split("/"):
                    if "x" in part and part.replace("x", "").replace("@", "").isdigit():
                        try:
                            size = int(part.split("x")[0])
                        except ValueError:
                            size = 0
                        break
                # Format score (PNG > SVG > XPM)
                fmt = 2 if ext == ".png" else (1 if ext == ".svg" else 0)
                candidates.append((size, fmt, p))
    if not candidates:
        return None
    candidates.sort(key=lambda c: (-c[0], -c[1], c[2]))
    return candidates[0][2]


# ── Browser web apps ─────────────────────────────────────────────
# Web apps installed from Chrome/Chromium ("Install as app") show up as
# windows whose class is `<browser>-<32-char app id>-<profile>` (or
# `crx_<id>`). Their icons are not installed into the icon theme; each app
# keeps PNGs inside the browser profile, so resolve the class from there.
_BROWSER_CLASS_RE = re.compile(
    r"^(?:crx_|(?:google-chrome|chrome|chromium|brave|vivaldi|microsoft-edge|msedge|opera))",
    re.IGNORECASE,
)
_APP_ID_RE = re.compile(r"(?<![a-pA-P])([a-pA-P]{32})(?![a-pA-P])")

_WEBAPP_ROOTS: list[str] | None = None


def _webapp_roots() -> list[str]:
    """Return `<profile>/Web Applications` dirs of installed browsers.

    Covers native (`~/.config/<browser>/<profile>`) and Flatpak
    (`~/.var/app/<app>/config/<browser>/<profile>`) installs.
    """
    global _WEBAPP_ROOTS
    if _WEBAPP_ROOTS is None:
        roots: list[str] = []
        for pattern in (
            "~/.config/*/*/Web Applications",
            "~/.var/app/*/config/*/*/Web Applications",
        ):
            roots.extend(glob.glob(os.path.expanduser(pattern)))
        _WEBAPP_ROOTS = roots
    return _WEBAPP_ROOTS


def _webapp_icon(name: str) -> str | None:
    """Resolve a browser web-app window class to the profile's icon PNG.

    The icons live under
    ``<profile>/Web Applications/Manifest Resources/<app id>/Icons``.
    Prefer a mid-size (<= 256 px) icon, falling back to the largest one.
    """
    if not _BROWSER_CLASS_RE.match(name):
        return None
    match = _APP_ID_RE.search(name)
    if not match:
        return None
    app_id = match.group(1).lower()
    for root in _webapp_roots():
        icons_dir = os.path.join(root, "Manifest Resources", app_id, "Icons")
        if not os.path.isdir(icons_dir):
            continue
        candidates: list[tuple[int, str]] = []
        for entry in os.listdir(icons_dir):
            m = re.fullmatch(r"(\d+)\.png", entry)
            if not m:
                continue
            path = os.path.join(icons_dir, entry)
            if os.path.isfile(path) and os.access(path, os.R_OK):
                candidates.append((int(m.group(1)), path))
        if candidates:
            candidates.sort()
            small = [c for c in candidates if c[0] <= 256]
            return (small or candidates)[-1][1]
    return None


def resolve(name: str) -> str | None:
    """Resolve an icon name to an absolute file path, or None."""
    if not name:
        return None
    webapp = _webapp_icon(name)
    if webapp:
        return webapp
    direct = _direct_file(name)
    if direct:
        return direct
    override = _override_icon(name)
    if override:
        return override
    # Lookup with a large requested size: size 0 returns the smallest variant
    # (often a 16x16 PNG) even when 128/256/512 variants exist. FORCE_SVG
    # prefers scalable icons when the theme has one; the plain lookup is the
    # fallback for PNG-only entries (flatpak exports etc.).
    info = THEME.lookup_icon(name, 512, Gtk.IconLookupFlags.FORCE_SVG)
    if not info:
        info = THEME.lookup_icon(name, 512, 0)
    if info:
        path = info.get_filename()
        if path and not _is_symbolic(path):
            return path
    return _manual_search(name)


APP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    "/run/current-system/sw/share/applications",
    "/etc/profiles/per-user/underdone/share/applications",
    os.path.expanduser("~/.nix-profile/share/applications"),
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]


def _scan_desktop_icons() -> list[str]:
    """Return unique icon names from all installed .desktop files."""
    seen: set[str] = set()
    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for path in glob.glob(os.path.join(d, "*.desktop")):
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    for line in f:
                        if line.startswith("Icon="):
                            val = line[5:].strip()
                            if val:
                                seen.add(val)
                            break
            except OSError:
                continue
    return sorted(seen)


def _parse_desktop_entry(path: str) -> dict[str, str]:
    """Parse the [Desktop Entry] group of a .desktop file."""
    values: dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    in_entry = line == "[Desktop Entry]"
                    continue
                if not in_entry or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                values.setdefault(key.strip(), val.strip())
    except OSError:
        return {}
    return values


def _wmclass_index() -> dict[str, str]:
    """Map lowercased window classes to the desktop entry's Icon= value.

    Window classes (``google-chrome``) do not always match the icon name
    (``com.google.Chrome``); the desktop file's ``StartupWMClass`` and its
    own id are the canonical mappings.
    """
    index: dict[str, str] = {}
    for d in APP_DIRS:
        for path in glob.glob(os.path.join(d, "*.desktop")):
            entry = _parse_desktop_entry(path)
            icon = entry.get("Icon", "")
            if not icon:
                continue
            wmclass = entry.get("StartupWMClass", "")
            if wmclass:
                index.setdefault(wmclass.lower(), icon)
            index.setdefault(os.path.basename(path)[: -len(".desktop")].lower(), icon)
    return index


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "icons", nargs="*",
        help="Icon names to resolve (default: scan all .desktop files)",
    )
    parser.add_argument(
        "--wmclass", action="store_true",
        help="treat the arguments as window classes and map them through "
             "StartupWMClass / the desktop entry id",
    )
    args = parser.parse_args()
    out = sys.stdout

    if args.wmclass:
        index = _wmclass_index()
        for name in args.icons:
            for candidate in dict.fromkeys([name, index.get(name.lower(), "")]):
                if not candidate:
                    continue
                path = resolve(candidate)
                if path:
                    out.write(f"{name}\t{path}\n")
                    break
        return 0

    names = args.icons if args.icons else _scan_desktop_icons()
    for name in names:
        path = resolve(name)
        if path:
            out.write(f"{name}\t{path}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
