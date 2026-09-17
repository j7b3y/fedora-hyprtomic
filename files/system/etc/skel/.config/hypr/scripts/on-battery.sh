#!/usr/bin/env bash
[ "$(cat /sys/class/power_supply/AC/online 2>/dev/null)" = "0" ]
