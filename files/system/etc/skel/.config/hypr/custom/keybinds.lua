-- HyprTomic keybind layer: Base Dotfiles as the PRIMARY map. end-4's equivalents
-- are moved to free keys in hyprland/keybinds.lua (Super+Q close -> Super+X,
-- fullscreen -> Super+Shift+F, pin -> Super+Alt+P, bar -> Super+Alt+J,
-- media -> Ctrl+Super+M, editor -> Ctrl+Super+C).
-- end-4 keeps its mechanisms for clipboard (cliphist, Super+V) and screenshots
-- (region selector, Super+Shift+S); snipland stays as an extra on Super+Ctrl+Shift+S.

-- Base Dotfiles core
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal), { description = "App: Terminal (Base)" })
hl.bind("SUPER + S", hl.dsp.exec_cmd("hyprbind"), { description = "Utilities: Keybind list (Base)" })
hl.bind("SUPER + F", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float (Base)" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Window: Split direction (Base)" })
hl.bind("SUPER + P", hl.dsp.layout("pseudo"), { description = "Window: Pseudo (Base)" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(browser), { description = "App: Browser (Base)" })
hl.bind("SUPER + M", hl.dsp.exec_cmd(taskManager), { description = "App: Task manager (Base)" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("flatpak run com.bitwarden.desktop"), { description = "App: Bitwarden (Base)" })
hl.bind("SUPER + Delete", hl.dsp.global("quickshell:sessionToggle"), { description = "Shell: Session menu (Base)" })

-- 変換キー (Henkan_Mode) opens the shell search, like the Base launcher
hl.bind("Henkan_Mode", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search (変換キー)" })

-- Base tools on keys ii does not use
hl.bind("SUPER + CTRL + SHIFT + S", hl.dsp.exec_cmd("snipland"), { description = "Utilities: Screenshot (snipland)" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("clipryx"), { description = "Utilities: Clipboard history (clipryx)" })
hl.bind("SUPER + SHIFT + K", hl.dsp.exec_cmd("hyprbind"), { description = "Utilities: Keybind list (hyprbind)" })
hl.bind("SUPER + SHIFT + Period", hl.dsp.exec_cmd("hypremoji"), { description = "Utilities: Emoji picker (hypremoji)" })

-- Disable noisy keys (Base parity)
hl.bind("Caps_Lock", hl.dsp.no_op(), { description = "Caps Lock 無効化" })
hl.bind("Insert", hl.dsp.no_op(), { description = "Insert キー無効化" })

hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), { description = "Edit user keybinds" })
