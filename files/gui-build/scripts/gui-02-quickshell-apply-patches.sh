#!/usr/bin/env bash
# Apply the quickshell fix patches to a fetched AUR source tree (run from the
# source directory, e.g. from PKGBUILD prepare()). The recipe copies
# files/gui-build/patches/ to /tmp/quickshell-patches/.
#
# Robustness rules:
#  - patches are applied with fuzz (-F3), so cosmetic upstream context changes
#    do not break the build;
#  - if a patch no longer applies AND the fix is already present upstream, it
#    is skipped (once upstream fixes the crash, this layer keeps building);
#  - otherwise the build fails with an explicit message. Never silently ship
#    an unpatched quickshell.
set -u

fail=0
found=0
for patch_file in /tmp/quickshell-patches/*.patch; do
    [ -e "$patch_file" ] || continue
    found=1
    name=$(basename "$patch_file")

    if patch -Np1 -F3 --batch --dry-run -i "$patch_file" >/dev/null 2>&1; then
        echo "quickshell: applying $name"
        if ! patch -Np1 -F3 --batch -i "$patch_file"; then
            echo "quickshell: ERROR: applying $name failed" >&2
            fail=1
        fi
    elif grep -q 'onObjectDestroying() { this->deleteLater(); }' src/services/pipewire/qml.cpp 2>/dev/null &&
         ! grep -q 'delete this;' src/services/pipewire/registry.cpp 2>/dev/null; then
        # The deferred-destruction fix landed upstream; nothing to do.
        echo "quickshell: $name already fixed upstream, skipping"
    else
        echo "quickshell: ERROR: $name does not apply and the fix is not present upstream." >&2
        echo "quickshell:        review the patch (upstream refactor?) or drop it if fixed." >&2
        fail=1
    fi
done

if [ "$found" -eq 0 ]; then
    echo "quickshell: ERROR: no patches found in /tmp/quickshell-patches/*.patch" >&2
    exit 1
fi

exit "$fail"
