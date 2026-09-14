-- HyprTomic (Base Dotfiles) window rules.
-- ii's rules.lua already covers file dialogs, pavucontrol, portals,
-- Picture-in-Picture, etc.; only Base-specific behavior lives here.

-- Float for auth agents / remote-desktop tools
hl.window_rule({
    name  = "float-utils",
    match = { class = "^(authentication-agent|Rustdesk)$" },
    float = true,
})

-- Base Dotfiles picker tools
hl.window_rule({
    name    = "float-pickers",
    match   = { class = "^(clipryx|hypr-emoji-picker|Hypr-emoji-picker)$" },
    float   = true,
    center  = true,
})

-- Gaming / containers (inert unless the app exists)
hl.window_rule({
    name  = "float-steam",
    match = { initial_class = "^(steam)$" },
    float = true,
})

hl.window_rule({
    name  = "float-wine-proton",
    match = { class = "^(steam_app_.*|.*\\.exe)$" },
    float = true,
})

hl.window_rule({
    name           = "float-waydroid",
    match          = { class = "Waydroid" },
    float          = true,
    center         = true,
    suppress_event = "activate activatefocus",
})

-- Suppress maximize events so apps can't maximize themselves out of the tiling layout
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix xwayland drag artifacts
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- hyprbind (Base keybind list app)
hl.window_rule({
    name    = "float-hyprbind",
    match   = { initial_title = "^HyprBind$" },
    float   = true,
    size    = { "(monitor_w*0.5)", "(monitor_h*0.6)" },
    center  = true,
})
