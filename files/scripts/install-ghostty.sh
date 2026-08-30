#!/usr/bin/env bash
set -ou pipefail
# ghostty via official Fedora copr (scottames/ghostty). Use the direct repo-file
# endpoint (avoids the api_3/rpmrepo path that throttled in CI). Non-fatal.
. /etc/os-release
REPO="/etc/yum.repos.d/_copr_scottames_ghostty.repo"
curl -fsSL --retry 3 --max-time 90 \
  "https://copr.fedorainfracloud.org/coprs/scottames/ghostty/repo/fedora-${VERSION_ID}/scottames-ghostty-fedora-${VERSION_ID}.repo" \
  -o "$REPO" || true

if [ -s "$REPO" ]; then
  dnf -y install ghostty || echo "### ghostty not installed (non-fatal) ###"
else
  echo "### ghostty copr repo fetch failed (non-fatal) ###"
fi
