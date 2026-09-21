# BlueZ (bluetoothctl) and NetworkManager (nmcli) live on the host, but
# distrobox only shares the user session bus: the host's system D-Bus socket is
# deliberately not linked into the container. Distrobox does mount the host
# root read-only at /run/host, so point system-bus clients at the socket there.
#
# The GUI shell (hyprtomic-gui-shell) exports the same value; this file keeps
# interactive `distrobox enter hyprtomic-gui` sessions and `bash -lc` helpers
# consistent.
if [ -S /run/host/run/dbus/system_bus_socket ] && [ -z "${DBUS_SYSTEM_BUS_ADDRESS:-}" ]; then
    export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/host/run/dbus/system_bus_socket"
fi
