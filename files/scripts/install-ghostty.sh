#!/usr/bin/env bash
set -ou pipefail
# ghostty via official Fedora copr (scottames/ghostty). Non-fatal: if the copr
# lacks a fedora-44 chroot yet, the build still succeeds and we revisit.
dnf copr enable -y scottames/ghostty || true
dnf -y install ghostty \
  || echo "### ghostty not installed (non-fatal): copr fedora-44 chroot may be missing ###"
