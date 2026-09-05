# Set to 1 with: ujust overwrite=1 setup-dotfiles  (variables go BEFORE the recipe name)
overwrite := "0"

# Link baked generic dotfiles from /usr/share/dotfiles into the user's home.
# Fresh installs get this layout automatically (baked into /etc/skel); this
# recipe is for rebased machines whose account predates the image. Re-running
# is safe: symlinks are refreshed, user-edited copies are left alone.
# overwrite=1 also replaces the user-editable copies (hypr/host.conf,
# waybar/config, fcitx5/profile, quickshell/current-theme) with the image
# defaults -- commit ~/.config to git first if it holds customizations.
setup-dotfiles:
    OVERWRITE={{ overwrite }} /usr/share/ublue-os/setup-dotfiles.sh
