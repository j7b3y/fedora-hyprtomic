#!/usr/bin/env python3
"""Resolve icon names to file paths using the GTK icon theme.

Uses the same icon resolution algorithm as nwg-dock (a GTK3 app), so the
icon pack is consistent between the dock and the Quickshell launcher/shelf.

GTK correctly follows the `Inherits` chain declared in each theme's
index.theme. For example, with `Papirus-Dark` active (which inherits
`breeze-dark,hicolor`), GTK searches:
  Papirus-Dark → breeze-dark → hicolor
and never `Papirus` (the light variant) unless that is also in the
inheritance chain. This fixes the previous bash resolver, which picked
`Papirus` icons when the active theme was `Papirus-Dark` because the
script's hardcoded scoring preferred the `Papirus` directory.

Usage:
    resolve-icons.py [icon_name ...]

If no icon names are given, scans all .desktop files for Icon= entries
and resolves those. Otherwise, resolves only the supplied names.

Output: name<TAB>path (one per line). Names that cannot be resolved are
omitted. Symbolic icons (`*/symbolic/*`) are skipped — they render as
black/transparent SVGs without theme colorization, so they're useless as
fallback art.
"""

from __future__ import annotations

import argparse
import glob
import os
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


def resolve(name: str) -> str | None:
    """Resolve an icon name to an absolute file path, or None."""
    if not name:
        return None
    direct = _direct_file(name)
    if direct:
        return direct
    # lookup_icon follows the Inherits chain. Pass size 0 to let the theme
    # pick its preferred size; the path is what matters for Image.source.
    info = THEME.lookup_icon(name, 0, 0)
    if info:
        path = info.get_filename()
        if path and not _is_symbolic(path):
            return path
    return _manual_search(name)


def _scan_desktop_icons() -> list[str]:
    """Return unique icon names from all installed .desktop files."""
    app_dirs = [
        "/usr/share/applications",
        "/usr/local/share/applications",
        "/run/current-system/sw/share/applications",
        "/etc/profiles/per-user/underdone/share/applications",
        os.path.expanduser("~/.nix-profile/share/applications"),
        os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    ]
    seen: set[str] = set()
    for d in app_dirs:
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "icons", nargs="*",
        help="Icon names to resolve (default: scan all .desktop files)",
    )
    args = parser.parse_args()
    names = args.icons if args.icons else _scan_desktop_icons()
    out = sys.stdout
    for name in names:
        path = resolve(name)
        if path:
            out.write(f"{name}\t{path}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
