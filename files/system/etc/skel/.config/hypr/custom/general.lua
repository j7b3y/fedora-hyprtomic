-- HyprTomic (Base Dotfiles) overrides for the ii general config.
-- Everything (layout, decoration, animations, ...) stays ii's default;
-- only the input section is adapted for a Japanese keyboard (jp layout,
-- caps:none, Base touchpad/scroll feel).

hl.config({
    input = {
        kb_layout          = "jp",
        kb_options         = "caps:none",
        numlock_by_default = true,
        repeat_delay       = 800,
        repeat_rate        = 35,
        follow_mouse       = 1,
        sensitivity        = 0.2,
        touchpad = {
            natural_scroll      = false,
            scroll_factor       = 1.5,
            disable_while_typing = true,
        },
    },

    -- ii ships render_power = 10, but Hyprland only accepts 1-4
    -- ("decoration:shadow:render_power" errors out and falls back to default).
    decoration = {
        shadow = {
            render_power = 4,
        },
    },
})

-- quadgrid: large-screen 2x2-cell custom layout (Base Dotfiles).
-- Registered here; applied per-workspace via a workspace rule, e.g.
--   hl.workspace_rule({ workspace = "1", layout = "lua:quadgrid" })
-- The default layout (ii: dwindle) stays untouched.
pcall(require, "layouts.quadgrid")
