-- HyprTomic (Base Dotfiles) keybind additions.
-- Only NON-CONFLICTING keys are used here: ii's own binds keep their keys
-- (SUPER+Return terminal, SUPER+SHIFT+S screenshot, SUPER+V clipboard
-- overview, SUPER+Period emoji, SUPER+/ cheatsheet, ...).

-- 変換キー (Henkan_Mode) also opens the shell search, like the Base Dotfiles launcher
hl.bind("Henkan_Mode", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search (変換キー)" })

-- Base Dotfiles tools on keys ii does not use
hl.bind("SUPER + CTRL + SHIFT + S", hl.dsp.exec_cmd("snipland"), { description = "Utilities: Screenshot (snipland)" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("clipryx"), { description = "Utilities: Clipboard history (clipryx)" })
hl.bind("SUPER + SHIFT + K", hl.dsp.exec_cmd("hyprbind"), { description = "Utilities: Keybind list (hyprbind)" })

-- Disable noisy keys (Base Dotfiles parity)
hl.bind("Caps_Lock", hl.dsp.no_op(), { description = "Caps Lock 無効化" })
hl.bind("Insert", hl.dsp.no_op(), { description = "Insert キー無効化" })

hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
