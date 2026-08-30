#!/usr/bin/env bash
set -ou pipefail
# clipryx: C#/.NET + Avalonia clipboard manager. Non-fatal.
dnf -y install dotnet-sdk-8.0 ImageMagick git || dnf -y install dotnet-sdk ImageMagick git || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/Yot360/clipryx.git "$TMP/clipryx"; then
  echo "### clipryx clone failed (non-fatal) ###"
  exit 0
fi

( cd "$TMP/clipryx" && make build ) 2>&1 | tee "$TMP/b.log"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  echo "### clipryx build FAILED (non-fatal) ###"
  cat "$TMP/b.log"
  exit 0
fi
( cd "$TMP/clipryx" && make install ) || echo "### clipryx install failed (non-fatal) ###"
