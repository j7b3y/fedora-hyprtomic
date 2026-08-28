#!/usr/bin/env bash
set -oue pipefail

dnf -y install cargo git gcc

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/ry2x/HyprBind.git "$TMP/HyprBind"
( cd "$TMP/HyprBind" && cargo build --release )

install -Dm755 "$TMP/HyprBind/target/release/hyprbind" /usr/local/bin/hyprbind
