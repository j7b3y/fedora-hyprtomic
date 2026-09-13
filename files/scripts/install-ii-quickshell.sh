#!/usr/bin/env bash
set -uo pipefail
# illogical-impulse shell runtime: quickshell (built here) + matugen (prebuilt).
#
# quickshell uses Qt PRIVATE APIs, so a binary only runs against the exact Qt
# private ABI it was built with. Fedora bumps Qt on every stable rebase, which
# broke end-4's prebuilt RPM (built for Qt 6.11.1 -> "undefined symbol ...
# Qt_6.11_PRIVATE_API" on the base Qt 6.11.2), and Fedora's own quickshell is
# stuck on a 2026-02 snapshot that is too old for the pinned dots. Therefore we
# build the pinned upstream commit against the base image's Qt. matugen is a
# Rust binary with no Qt dependency, so the prebuilt RPM is fine.
#
# Build deps are installed then removed again; runtime libs (jemalloc,
# libunwind) are kept. cpptrace is vendored via FetchContent
# (-DVENDOR_CPPTRACE=ON, needs git + libunwind). Sources/versions are pinned in
# /usr/share/hyprtomic/versions.env.

QS_COMMIT="7511545ee20664e3b8b8d3322c0ffe7567c56f7a"
QS_SRC_SHA256="9bb72a896b6893c440286d54da43f311a1c5dfdaefa1aa3372d635c67df3cec2"
MATUGEN_URL="https://github.com/end-4/ii-package-builds/releases/download/packages-fedora/matugen-4.1.0-0.fc44.x86_64.rpm"
MATUGEN_SHA256="a77f25a0981dc3ac2f0d54fb7f6b92540d1fccbe70dd7908837c40a4be219d1c"

BUILD_DEPS="cmake ninja-build gcc-c++ git cli11-devel libdrm-devel
mesa-libgbm-devel mesa-libEGL-devel vulkan-headers spirv-tools pipewire-devel
glib2-devel polkit-devel wayland-devel wayland-protocols-devel pam-devel
libxcb-devel jemalloc-devel libunwind-devel qt6-qtbase-devel
qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtdeclarative-private-devel
qt6-qtshadertools-devel qt6-qtwayland-devel breakpad-static breakpad-devel"

# The dnf module's COPR files were cleaned up (frozen at build time); the
# breakpad headers/libs needed here come from the same COPR.
cat > /etc/yum.repos.d/_copr_ririko66z_dots-hyprland.repo <<'EOF'
[copr:copr.fedorainfracloud.org:ririko66z:dots-hyprland]
name=Copr repo for dots-hyprland owned by ririko66z
baseurl=https://download.copr.fedorainfracloud.org/results/ririko66z/dots-hyprland/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ririko66z/dots-hyprland/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

dnf -y install --skip-unavailable --setopt=install_weak_deps=False \
    $BUILD_DEPS jemalloc libunwind \
  || echo "### some quickshell build deps were unavailable (continuing) ###"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" /tmp/qsbuild' EXIT

# matugen: prebuilt RPM (Rust, no Qt).
if curl -fL --retry 3 -o "$tmp/matugen.rpm" "$MATUGEN_URL" \
     && echo "$MATUGEN_SHA256  $tmp/matugen.rpm" | sha256sum -c -; then
    dnf -y install "$tmp/matugen.rpm" || echo "### matugen install failed (non-fatal) ###"
else
    echo "### matugen download/checksum failed (non-fatal) ###"
fi

# quickshell: build the pinned commit against the base Qt.
if curl -fL --retry 3 -o "$tmp/quickshell.tar.gz" \
       "https://github.com/quickshell-mirror/quickshell/archive/${QS_COMMIT}.tar.gz" \
     && echo "${QS_SRC_SHA256}  $tmp/quickshell.tar.gz" | sha256sum -c -; then
    mkdir -p /tmp/qsbuild
    tar -xzf "$tmp/quickshell.tar.gz" -C /tmp/qsbuild
    srcdir="/tmp/qsbuild/quickshell-${QS_COMMIT}"
    cmake -GNinja -S "$srcdir" -B "$srcdir/build" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DVENDOR_CPPTRACE=ON \
        -DGIT_REVISION="$QS_COMMIT" \
        -DINSTALL_QML_PREFIX=/usr/lib64/qt6/qml \
        -DCMAKE_INSTALL_PREFIX=/usr \
      && ninja -C "$srcdir/build" -j"$(nproc)" \
      && ninja -C "$srcdir/build" install \
      || echo "### quickshell build failed ###"
else
    echo "### quickshell source download/checksum failed ###"
fi

# Drop the build-only toolchain/headers; keep jemalloc/libunwind and the Qt
# runtime. (No autoremove: avoids touching base packages.)
dnf -y remove $BUILD_DEPS >/dev/null 2>&1 || true
dnf -y clean all >/dev/null 2>&1 || true
rm -f /etc/yum.repos.d/_copr_ririko66z_dots-hyprland.repo
rm -rf /tmp/qsbuild
