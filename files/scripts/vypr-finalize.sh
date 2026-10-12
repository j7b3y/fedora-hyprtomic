#!/usr/bin/env bash
# latest-vypr image tidy-up (runs in the final image build).
set -oue pipefail

# ujust only imports /usr/share/ublue-os/just/60-custom.just, so fold the
# Vypr fragment into it. The fragment is shipped by the vypr files module and
# exists only in this image.
fragment=/usr/share/ublue-os/just/61-vypr.just
target=/usr/share/ublue-os/just/60-custom.just
if [ -f "$fragment" ] && ! grep -q "61-vypr.just" "$target"; then
    {
        printf '\n'
        printf '# >>> 61-vypr.just (folded in by vypr-finalize.sh)\n'
        cat "$fragment"
        printf '# <<< 61-vypr.just\n'
    } >> "$target"
fi
rm -f "$fragment"

# The setup helper must be executable (the files module preserves the repo
# mode, but keep this explicit like the other hyprtomic helpers).
chmod +x /usr/bin/hyprtomic-vypr-setup
