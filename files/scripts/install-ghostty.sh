#!/usr/bin/env bash
set -ou pipefail
# copr (scottames/ghostty) is Anubis-blocked from GitHub CI runners, so use the
# community AppImage from GitHub releases (github.com is reachable). Runs without
# FUSE via --appimage-extract-and-run. Non-fatal.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ASSET="$(curl -fsSL --retry 3 \
  https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest \
  | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64\.AppImage' | head -1 || true)"

if [ -z "$ASSET" ]; then
  echo "### ghostty: no AppImage asset found (non-fatal) ###"
  exit 0
fi

if ! curl -fL --retry 3 -o /opt/Ghostty.AppImage "$ASSET"; then
  echo "### ghostty AppImage download failed (non-fatal) ###"
  rm -f /opt/Ghostty.AppImage
  exit 0
fi

chmod +x /opt/Ghostty.AppImage
cat > /usr/local/bin/ghostty <<'EOF'
#!/bin/sh
exec /opt/Ghostty.AppImage --appimage-extract-and-run "$@"
EOF
chmod +x /usr/local/bin/ghostty
echo "### ghostty installed from AppImage ###"
