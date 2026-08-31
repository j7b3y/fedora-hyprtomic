#!/usr/bin/env bash
set -ou pipefail
# ghostty via copr scottames/ghostty (stable releases; .desktop/icon included).
# Write the repo file directly pointing at the CDN (download.copr...) to avoid the
# Anubis-protected api_3 host. Non-fatal.
# (alt: boydkelly/ghostty-tip for nightly builds)
cat > /etc/yum.repos.d/_copr_scottames_ghostty.repo <<'EOF'
[copr:copr.fedorainfracloud.org:scottames:ghostty]
name=Copr repo for ghostty owned by scottames
baseurl=https://download.copr.fedorainfracloud.org/results/scottames/ghostty/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/scottames/ghostty/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

dnf -y install ghostty || echo "### ghostty not installed (non-fatal) ###"
