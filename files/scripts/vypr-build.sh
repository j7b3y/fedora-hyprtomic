#!/usr/bin/env bash
# Build the Vypr host binaries for the latest-vypr image.
#
# Runs in the BlueBuild stage container (docker.io/library/fedora:44), not in
# the final image, so cmake/ninja/gcc and the -devel packages stay out of the
# shipped system. Artifacts are staged under /out and copied in by
# recipe-vypr.yml.
#
# Pinned to the v0.5.0 release: the guest installer shipped at
# /usr/share/vypr/vypr-setup.exe is the release asset of the same tag, so the
# two halves speak the same protocol. Bump VYPR_TAG and both hashes together.
set -euo pipefail

VYPR_TAG="v0.5.0"
# sha256 of https://github.com/Amzi-01/Vypr/archive/refs/tags/v0.5.0.tar.gz
VYPR_SRC_SHA256="12b7de089ce073c200121fc217d9db38aa4ff8813acbc61f69c3e04efb1fc185"
# sha256 of https://github.com/Amzi-01/Vypr/releases/download/v0.5.0/vypr-setup.exe
VYPR_SETUP_SHA256="ebf783cb676f400a01828fdb6b3274b5ea06a75860f4b1596795257e4421ef47"

dnf -y install --setopt=install_weak_deps=False \
    cmake ninja-build gcc-c++ SDL3-devel vulkan-headers vulkan-loader-devel tar gzip

src=/tmp/vypr-src.tar.gz
curl -fsSL "https://github.com/Amzi-01/Vypr/archive/refs/tags/${VYPR_TAG}.tar.gz" -o "$src"
echo "${VYPR_SRC_SHA256}  ${src}" | sha256sum -c -

rm -rf /src && mkdir -p /src
tar -xzf "$src" -C /src --strip-components=1

cd /src/host
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Staged tree; recipe-vypr.yml copies these into the final image.
mkdir -p /out/usr/bin \
         /out/usr/share/vypr/hooks \
         /out/usr/share/vypr/xorg \
         /out/usr/share/licenses/vypr \
         /out/usr/share/icons/hicolor/256x256/apps

install -m755 build/vyprd build/vypr-window /out/usr/bin/
install -m755 ../launcher/vypr ../launcher/vypr-gpu-swap /out/usr/bin/
install -m755 ../install/anti-detect.py /out/usr/share/vypr/anti-detect.py
install -m755 ../install/hooks/vypr-gpu /out/usr/share/vypr/hooks/vypr-gpu
install -m644 ../install/xorg/20-vypr-gpu-swap.conf /out/usr/share/vypr/xorg/20-vypr-gpu-swap.conf
install -m644 ../LICENSE /out/usr/share/licenses/vypr/LICENSE
install -m644 ../launcher/vypr.png /out/usr/share/icons/hicolor/256x256/apps/vypr.png

# The Windows-side installer, so `ujust vypr-guest-exe` never has to download
# anything on the user's machine. Same tag as the host binaries.
setup=/out/usr/share/vypr/vypr-setup.exe
curl -fsSL "https://github.com/Amzi-01/Vypr/releases/download/${VYPR_TAG}/vypr-setup.exe" -o "$setup"
echo "${VYPR_SETUP_SHA256}  ${setup}" | sha256sum -c -
