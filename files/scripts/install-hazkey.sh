#!/usr/bin/env bash
set -ou pipefail
# hazkey (fcitx5 engine) via copr cocoa/hazkey. Write the repo file directly and
# point it at the CDN (download.copr...) to avoid the Anubis-protected api_3 host.
# Non-fatal; --skip-unavailable covers both possible package names.
cat > /etc/yum.repos.d/_copr_cocoa_hazkey.repo <<'EOF'
[copr:copr.fedorainfracloud.org:cocoa:hazkey]
name=Copr repo for hazkey owned by cocoa
baseurl=https://download.copr.fedorainfracloud.org/results/cocoa/hazkey/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/cocoa/hazkey/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

dnf -y install --skip-unavailable fcitx5-hazkey hazkey \
  || echo "### hazkey not installed (non-fatal) ###"
