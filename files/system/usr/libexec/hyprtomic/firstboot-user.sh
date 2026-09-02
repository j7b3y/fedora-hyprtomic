#!/usr/bin/env bash
set -u

flag=/var/lib/hyprtomic/.user-created
mkdir -p /var/lib/hyprtomic

if awk -F: '$3 >= 1000 && $3 < 60000 { found = 1 } END { exit !found }' /etc/passwd; then
  echo "User account already exists; skipping first-boot user creation."
  touch "$flag"
  exit 0
fi

echo "Welcome to HyprTomic!"
echo "No user account exists on this machine, so let's create one."
echo

while true; do
  read -r -p "Username: " name
  if [[ "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && ! getent passwd "$name" >/dev/null; then
    break
  fi
  echo "Invalid or already taken username (lowercase letters/digits/_/-, max 32 chars, starting with letter or _)."
done

read -r -p "Full name (optional): " gecos
if [ -n "$gecos" ]; then
  useradd -m -G wheel -s /usr/bin/bash -c "$gecos" "$name"
else
  useradd -m -G wheel -s /usr/bin/bash "$name"
fi

passwd "$name"

touch "$flag"
echo
echo "User '$name' created (wheel member)."
echo "After reboot, log in via SDDM, then run: ujust dotfiles"
echo
read -r -p "Press Enter to reboot... " _
systemctl reboot
