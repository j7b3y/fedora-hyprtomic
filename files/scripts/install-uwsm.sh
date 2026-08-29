#!/usr/bin/env bash
set -ou pipefail
# uwsm is not on PyPI (GitHub only). Skip if the base image already provides it.
if command -v uwsm >/dev/null 2>&1; then
  echo "uwsm already present: $(command -v uwsm) — skipping"
  exit 0
fi
pip install --break-system-packages "git+https://github.com/Viergoor/uwsm.git" \
  || echo "### uwsm install failed (non-fatal) ###"
exit 0
