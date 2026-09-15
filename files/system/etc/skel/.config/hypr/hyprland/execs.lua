-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- GUI shell (quickshell, wallpaper, clipboard history). These run in the
    -- Arch distrobox container: hyprtomic-gui-shell creates/enters it and starts
    -- the illogical-impulse session there. Manage it with `ujust gui-container-*`.
    hl.exec_cmd("hyprtomic-gui-shell")

    -- Core components (authentication, lock screen)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Cursor (theme must be present on the host: hyprctl loads it in the compositor)
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
