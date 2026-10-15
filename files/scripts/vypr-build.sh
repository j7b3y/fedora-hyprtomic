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

# Four fixes are applied to the pinned source here (reportable upstream; drop
# them when upstream fixes them - the python asserts below fail loudly if the
# anchors move). Three are in the launcher, one in the window code:
#
#  1. The launcher compares `virsh domstate` output against the English state
#     words ("running", "shut off"), but virsh translates them: under a
#     Japanese locale the check fails, 'vypr detect' (and the start step of
#     `vypr run`) tries to start an already-running VM. virsh runs in the C
#     locale now.
#  2. ensure_guest_ram() reads /etc/libvirt/qemu.conf, which is root-only on
#     the Fedora base: the read yields nothing and the check died with "QEMU
#     does not run under your group" for a perfectly correct file. An
#     unreadable file is treated as unknown now (the running QEMU is asked
#     first) and only a value that was actually read can fail the check.
#  3. ssh/scp pass -o IdentityAgent=none: the desktop's agent (Bitwarden's,
#     say) popped unlock dialogs for guest calls that use the -i key and never
#     need an agent.
#  4. Fixed-size windows (host/src/main.c): the compositor's size hints are
#     pinned to the frame size, so a user resize does nothing instead of
#     stretching the picture into a size the guest cannot follow (a maximized
#     guest window used to leave that permanent).
python3 - ../launcher/vypr ../host/src/main.c <<'PY_PATCH'
import pathlib, sys

p = pathlib.Path(sys.argv[1])
s = p.read_text()

# 1. virsh prints its state words translated; the comparisons expect English.
old = "set -uo pipefail\n"
new = (
    "set -uo pipefail\n\n"
    "# virsh prints its state words translated; the checks below expect English.\n"
    "# ja_JP made \"vypr detect\" try to start an already-running VM.\n"
    "virsh() { LC_ALL=C command virsh \"$@\"; }\n"
)
assert s.count(old) == 1, "locale anchor"
s = s.replace(old, new, 1)

# 2. qemu.conf and the checks that read it: /etc/libvirt is root-only on the
#    Fedora base, so the read yields nothing and both ensure_guest_ram() and
#    'vypr status'/'doctor' treated "unreadable" as "wrong". Read the running
#    QEMU instead when the file cannot be read, and only fail the check on a
#    value that was actually obtained.
old = """qemu_conf() {
    grep -sE "^[[:space:]]*$1[[:space:]]*=" /etc/libvirt/qemu.conf 2>/dev/null | tail -1 |
        sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?.*/\\1/'
}"""
new = """qemu_conf() {
    local v
    v=$(grep -sE "^[[:space:]]*$1[[:space:]]*=" /etc/libvirt/qemu.conf 2>/dev/null | tail -1 |
        sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?.*/\\1/')
    if [ -z "$v" ]; then
        # /etc/libvirt is root-only on the Fedora base; ask the running QEMU
        # rather than pretending the file says nothing.
        local p
        p=$(ps -C qemu-system-x86_64 -o pid=,args= | awk -v n="-name guest=$VM," 'index($0, n) { print $1; exit }')
        if [ -n "$p" ]; then
            case "$1" in
                user)  v=$(stat -c %U /proc/"$p") ;;
                group) v=$(stat -c %G /proc/"$p") ;;
            esac
        fi
    fi
    printf '%s\\n' "$v"
}"""
assert s.count(old) == 1, "qemu_conf anchor"
s = s.replace(old, new, 1)

old = """ensure_guest_ram() {
    local want; want=$(id -gn)
    if [ "$(qemu_conf group)" != "$want" ]; then"""
new = """ensure_guest_ram() {
    local want have; want=$(id -gn); have=$(qemu_conf group)
    if [ -n "$have" ] && [ "$have" != "$want" ]; then"""
assert s.count(old) == 1, "guest ram anchor"
s = s.replace(old, new, 1)

# 3. ssh/scp also talk to whatever agent the desktop runs (Bitwarden's, say),
#    which then pops unlock dialogs for connections that authenticate with the
#    -i key and never need an agent at all.
old = '-i "$KEY"'
new = '-i "$KEY" -o IdentityAgent=none'
assert s.count(old) == 4, "ssh/scp anchors"
s = s.replace(old, new)

p.write_text(s)

# 4. Fixed-size the application windows (host/src/main.c). With the size hints
#    pinned to the frame size, the compositor refuses user resizes instead of
#    leaving a stretched picture when the guest cannot follow (a maximized
#    guest window made that permanent). SDL commits queued limit changes with
#    the next SetWindowSize, so the adoption below updates hints and size
#    together; the whole-desktop view stays resizable, as it is decorated and
#    dragged by its decorations.
m = pathlib.Path(sys.argv[2])
s = m.read_text()

old = """    views[0].win = SDL_CreateWindow(opt.title, win_w, win_h,
                                    SDL_WINDOW_RESIZABLE | vk_window_flag(opt.backend) |
                                    (decorated ? 0 : SDL_WINDOW_BORDERLESS));
    if (!views[0].win) {
        fprintf(stderr, "vypr: SDL_CreateWindow: %s\\n", SDL_GetError());
        return 1;
    }
"""
new = old + """
    /*
     * Fixed window size: the guest owns the size and the picture is never
     * scaled, so pin the compositor's size hints to the window size - a user
     * resize then does nothing instead of stretching the frame into a size the
     * guest cannot follow. The frame-size adoption below keeps the hints in
     * step. The whole-desktop view stays resizable: it is decorated and is
     * dragged by its decorations.
     */
    if (!decorated) {
        SDL_SetWindowMinimumSize(views[0].win, win_w, win_h);
        SDL_SetWindowMaximumSize(views[0].win, win_w, win_h);
    }
"""
assert s.count(old) == 1, "create anchor"
s = s.replace(old, new, 1)

old = """                    if (!v->is_popup && resize_at == 0 && !(opt.size_w && opt.size_h))
                        SDL_SetWindowSize(v->win, (int)f.width, (int)f.height);
"""
new = """                    if (!v->is_popup && resize_at == 0 && !(opt.size_w && opt.size_h)) {
                        if (opt.window_id != VYPR_DESKTOP_WINDOW_ID) {
                            SDL_SetWindowMinimumSize(v->win, (int)f.width, (int)f.height);
                            SDL_SetWindowMaximumSize(v->win, (int)f.width, (int)f.height);
                        }
                        SDL_SetWindowSize(v->win, (int)f.width, (int)f.height);
                    }
"""
assert s.count(old) == 1, "adoption anchor"
s = s.replace(old, new, 1)

m.write_text(s)
print("window code patched")
PY_PATCH

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
