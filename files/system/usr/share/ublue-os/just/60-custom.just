# HyprTomic ujust recipes.
# Loaded by ublue-os-just's justfile via `import "/usr/share/ublue-os/just/60-custom.just"`.

# --- GUI container (Arch distrobox; the shell + GUI helpers live there) ---

# Create and initialize the GUI container (safe to re-run).
gui-container-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell init
    /usr/bin/hyprtomic-gui-shell status

# Recreate the GUI container from the latest published image.
gui-container-update:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell update
    /usr/bin/hyprtomic-gui-shell status

# Recreate the GUI container from scratch (same as update, explicit).
gui-container-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/hyprtomic-gui-shell reset
    /usr/bin/hyprtomic-gui-shell status

# Show whether the GUI container exists.
gui-container-status:
    @/usr/bin/hyprtomic-gui-shell status

# --- Fonts ---

# Fix CJK rendering in Chromium/Electron flatpaks: flatpak >= 1.18 exposes the
# host fonts only through caches their bundled fontconfig cannot read, so every
# host font disappears (Japanese renders as tofu). Writes a per-app
# ~/.var/app/<id>/config/fontconfig/fonts.conf; restart the affected apps
# afterwards. Also run automatically on session start.
fix-flatpak-fonts:
    @/usr/bin/hyprtomic-flatpak-fonts

# --- Dotfiles ---

# Sync the baked /etc/skel into $HOME (oameye/atomic-hyprland-style).
# Pass overwrite=1 to replace managed files from the shipped skel and prune
# files that previous overwrite runs synced but the image has since removed.
# Leave the default to only copy files that don't yet exist.
# Note: just overrides must come *before* the recipe name.
# Example:
#   ujust sync-skel-config                # safe -- skips files that exist
#   ujust overwrite=1 sync-skel-config    # replace managed files from skel
overwrite := "0"

sync-skel-config:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{overwrite}}" = "1" ]; then
        state_dir="$HOME/.local/state/hyprtomic"
        manifest_file="${state_dir}/skel-manifest"
        new_manifest="$(mktemp)"
        trap 'rm -f "$new_manifest"' EXIT

        install -d "$state_dir"
        find /etc/skel -mindepth 1 ! -type d -printf '%P\n' | LC_ALL=C sort > "$new_manifest"

        # Prune files we synced on a previous overwrite run that the image has
        # since removed. Only runs when a manifest from a prior overwrite exists:
        # we never speculatively delete on a first run, because /etc/skel paths
        # like .local/share are shared with non-skel data (podman storage, user
        # app data, etc.) and a blind rm -rf would destroy unrelated files.
        if [ -f "$manifest_file" ]; then
            while IFS= read -r relpath; do
                [ -n "$relpath" ] || continue
                target="$HOME/$relpath"
                rm -f "$target"

                parent="$(dirname "$target")"
                while [ "$parent" != "$HOME" ]; do
                    rmdir "$parent" 2>/dev/null || break
                    parent="$(dirname "$parent")"
                done
            done < <(comm -23 "$manifest_file" "$new_manifest")
            echo "Replacing managed dotfiles from /etc/skel and pruning removed files ..."
        else
            echo "Replacing managed dotfiles from /etc/skel (first overwrite -- seeding manifest, no prune) ..."
        fi

        rsync -av /etc/skel/ "$HOME/"
        cp "$new_manifest" "$manifest_file"
    else
        echo "Syncing /etc/skel into \$HOME (skipping files that already exist) ..."
        rsync -av --ignore-existing /etc/skel/ "$HOME/"
    fi
    echo
    echo "Done. Run 'hyprctl reload' or log out/in to apply."

# --- SDDM login screen ---

# Replace the SDDM login-screen wallpaper. Copies the astronaut theme to a
# private name under /usr/local (=/var/usrlocal host state: survives updates)
# and selects it via /etc/sddm.conf.d/zz-wallpaper.conf (sorts after the
# baked zz-theme.conf). Undo: delete both paths and restart sddm.
login-wallpaper path:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{ path }}"
    [ -f "$src" ] || { echo "no such file: $src"; exit 1; }
    dest=/usr/local/share/sddm/themes/hyprtomic-login
    [ -d "$dest" ] || sudo cp -a /usr/share/sddm/themes/sddm-astronaut-theme "$dest"
    sudo install -Dm644 "$src" "$dest/Backgrounds/wallpaper.jpg"
    printf '[Theme]\nCurrent=hyprtomic-login\n' | sudo tee /etc/sddm.conf.d/zz-wallpaper.conf >/dev/null
    sudo systemctl restart sddm || true
    echo "login wallpaper updated"
