-- HyprTomic (Base Dotfiles) environment additions.
-- fcitx5 input method (hazkey engine): must be exported by the session.
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")
