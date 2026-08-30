#!/usr/bin/env bash
set -ou pipefail
# hypr-emoji-picker: Rust + GTK4. Non-fatal.
dnf -y install cargo gtk4-devel gtk4-layer-shell-devel gcc pkgconf-pkg-config || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth 1 https://github.com/oneroa/hypr-emoji-picker.git "$TMP/ep"; then
  echo "### hypr-emoji-picker clone failed (non-fatal) ###"
  exit 0
fi

( cd "$TMP/ep" && cargo build --release ) 2>&1 | tee "$TMP/b.log"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  echo "### hypr-emoji-picker build FAILED (non-fatal) ###"
  cat "$TMP/b.log"
  exit 0
fi
install -Dm755 "$TMP/ep/target/release/hypr-emoji-picker" /usr/local/bin/hypr-emoji-picker
