#!/usr/bin/env bash
# Add human users to the groups the session needs (video/input). Idempotent;
# runs on every boot so
# accounts created after the image is installed are covered too.
set -u

awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /nologin|false/ { print $1 }' /etc/passwd |
while read -r user; do
    for group in video input; do
        getent group "$group" >/dev/null 2>&1 || continue
        id -nG "$user" 2>/dev/null | grep -qw "$group" || usermod -aG "$group" "$user"
    done
done

exit 0
