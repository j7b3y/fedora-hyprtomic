#!/usr/bin/env bash
set -ou pipefail
# uwsm (Universal Wayland Session Manager) — quickshell Launcher.qml launches
# apps via `uwsm app -s a --`. Not packaged in Fedora repos, so build from
# source (pure-python + meson; installs under /usr, NOT /usr/local which is a
# symlink to /var/usrlocal and is never shipped by ostree images). Non-fatal.
dnf -y install git meson ninja-build python3-dbus || { echo "### uwsm: build deps unavailable (non-fatal) ###"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/Vladimir-csp/uwsm.git "$TMP/uwsm"; then
  echo "### uwsm clone failed (non-fatal) ###"
  exit 0
fi

( cd "$TMP/uwsm" && meson setup build --prefix=/usr \
    -Duuctl=disabled -Dfumon=disabled -Dttyautolock=disabled -Duwsm-app=disabled \
  && meson install -C build ) 2>&1 | tail -20

if ! command -v /usr/bin/uwsm >/dev/null; then
  echo "### uwsm build FAILED (non-fatal) ###"
  exit 0
fi

dnf -y remove meson ninja-build || true
