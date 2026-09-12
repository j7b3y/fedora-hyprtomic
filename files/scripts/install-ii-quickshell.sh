#!/usr/bin/env bash
set -uo pipefail
# illogical-impulse shell runtime: quickshell + matugen.
#
# Fedora official only ships quickshell 0.2.1 (2026-02), which predates the
# pinned dots (2026-08): the quickshell QML/API mismatch makes `qs -c ii` exit
# immediately (no bar). The COPR ririko66z/dots-hyprland quickshell-git is built
# against Qt 6.10 private API and cannot install on the base's Qt 6.11. end-4
# publishes prebuilt Fedora 44 RPMs built against Qt 6.11; install those,
# pinned by version+sha256 (see /usr/share/hyprtomic/versions.env).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() { # <url> <sha256> <out>
  curl -fL --retry 3 -o "$3" "$1" \
    && echo "$2  $3" | sha256sum -c -
}

if fetch \
      "https://github.com/end-4/ii-package-builds/releases/download/packages-fedora/quickshell-git-0.2.1.770.git7511545-1.fc44.x86_64.rpm" \
      "7b580ac4196d8283f8627f9649fa21b23bef225901b2428bfdba1fd0b5b15052" \
      "$tmp/quickshell-git.rpm" \
   && fetch \
      "https://github.com/end-4/ii-package-builds/releases/download/packages-fedora/matugen-4.1.0-0.fc44.x86_64.rpm" \
      "a77f25a0981dc3ac2f0d54fb7f6b92540d1fccbe70dd7908837c40a4be219d1c" \
      "$tmp/matugen.rpm"
then
  dnf -y install "$tmp/quickshell-git.rpm" "$tmp/matugen.rpm" \
    || echo "### illogical-impulse quickshell/matugen install failed (non-fatal) ###"
else
  echo "### download/checksum of the illogical-impulse RPMs failed (non-fatal) ###"
fi
