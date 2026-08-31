#!/usr/bin/env bash
set -ou pipefail
# clipryx: C#/.NET + Avalonia. No Makefile; build via dotnet publish (self-contained)
# so the final image needs no .NET runtime, then drop the SDK to save space. Non-fatal.
# clipryx targets .NET 10 → need dotnet-sdk-10.0 (fall back to generic dotnet-sdk).
dnf -y install dotnet-sdk-10.0 git || dnf -y install dotnet-sdk git || { echo "### clipryx: dotnet sdk unavailable (non-fatal) ###"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/Yot360/clipryx.git "$TMP/clipryx"; then
  echo "### clipryx clone failed (non-fatal) ###"; exit 0
fi

( cd "$TMP/clipryx" && dotnet publish clipryx/clipryx.csproj -c Release -r linux-x64 --self-contained true -o "$TMP/publish" ) 2>&1 | tail -40 | tee "$TMP/b.log"
if ! [ -x "$TMP/publish/clipryx" ]; then
  echo "### clipryx build FAILED (non-fatal) ###"
  dnf -y remove dotnet-sdk-10.0 dotnet-sdk || true
  exit 0
fi

mkdir -p /usr/local/lib/clipryx
cp -r "$TMP/publish/." /usr/local/lib/clipryx/
chmod +x /usr/local/lib/clipryx/clipryx
ln -sf /usr/local/lib/clipryx/clipryx /usr/local/bin/clipryx
dnf -y remove dotnet-sdk-10.0 dotnet-sdk || true
