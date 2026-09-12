-- HyprTomic (Base Dotfiles) overrides for the default variables.
-- Loaded after hyprland.variables; the ii keybinds pick these up.

-- Base Dotfiles: ghostty is the only terminal (kitty is intentionally not
-- installed), nemo the file manager.
terminal = "ghostty"
fileManager = "nemo"

-- Browser: the image ships Firefox as a Flatpak, which provides no PATH
-- binary, so extend the launch chain with the Flatpak invocation.
browser = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'google-chrome-stable' 'zen-browser' 'flatpak run org.mozilla.firefox'"

-- Replace the upstream kitty-based fallbacks with ghostty.
codeEditor = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'code' 'codium' 'zed' 'kate' 'gnome-text-editor' 'command -v nvim && ghostty -e nvim'"
taskManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'gnome-system-monitor' 'command -v btop && ghostty -e btop'"
volumeMixer = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'pavucontrol'"
