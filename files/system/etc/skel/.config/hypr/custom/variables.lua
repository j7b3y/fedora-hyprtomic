-- HyprTomic (Base Dotfiles) overrides for the default variables.
-- Loaded after hyprland.variables; the ii keybinds pick these up.

-- Base Dotfiles: ghostty as the terminal, nemo as the file manager.
terminal = "ghostty"
fileManager = "nemo"

-- Browser: the image ships Firefox as a Flatpak, which provides no PATH
-- binary, so extend the launch chain with the Flatpak invocation.
browser = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'google-chrome-stable' 'zen-browser' 'flatpak run org.mozilla.firefox'"
