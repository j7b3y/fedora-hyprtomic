-- HyprTomic (Base Dotfiles) autostart additions.
-- Put former exec-once commands inside the function (see hyprland.execs).
hl.on("hyprland.start", function ()
    -- IME: fcitx5 with the hazkey engine
    hl.exec_cmd("fcitx5 -d")
    -- Clipboard manager daemon (clipryx; ii's clipboard overview uses cliphist)
    hl.exec_cmd("clipryx -d")
end)
