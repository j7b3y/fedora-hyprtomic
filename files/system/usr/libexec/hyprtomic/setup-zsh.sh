#!/usr/bin/env bash
set -u

flag=/var/lib/hyprtomic/.zsh-default-set
mkdir -p /var/lib/hyprtomic
[ -e "$flag" ] && exit 0

zsh="$(command -v zsh)" || exit 0

# rpm %post scriptlets never run on ostree, so /etc/shells may lack zsh
grep -qxF "$zsh" /etc/shells || echo "$zsh" >>/etc/shells

# switch human users (skip service/nologin accounts)
awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /nologin|false/ { print $1 }' /etc/passwd |
while read -r user; do
    usermod --shell "$zsh" "$user"
done

touch "$flag"
