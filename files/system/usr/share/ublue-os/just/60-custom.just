# HyprTomic GUI container management (Arch distrobox: the end-4 shell lives there)
# vim: set ft=make :

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
