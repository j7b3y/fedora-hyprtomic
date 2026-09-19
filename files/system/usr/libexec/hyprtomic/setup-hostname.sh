#!/usr/bin/env bash
set -u

flag=/var/lib/hyprtomic/.hostname-set
mkdir -p /var/lib/hyprtomic
[ -e "$flag" ] && exit 0

cur="$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || true)"
case "$cur" in
  "" | localhost | localhost.localdomain | fedora | wayblue | hyprtomic)
    id4="$(cut -c1-4 /etc/machine-id 2>/dev/null)"
    if [ -z "$id4" ] || [ "$id4" = "uninitialized" ]; then
      id4="$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    hostnamectl set-hostname "hyprtomic-${id4}"
    ;;
esac

touch "$flag"
