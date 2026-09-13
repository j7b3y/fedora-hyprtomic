#!/usr/bin/env bash
set -euo pipefail
# Smoke test for the Arch-based GUI container: verifies pacman works inside the
# BlueBuild pipeline. Replaced by the real package/AUR setup once validated.
pacman -Syu --noconfirm --needed git
