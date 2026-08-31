#!/bin/bash
exec rofi -modi emoji -show emoji -emoji-format "{emoji}  <span weight='bold'>{name}</span>  <span size='small' foreground='#8E90A8'>{group} › {subgroup}</span>" -theme ~/.config/rofi/dmenu.rasi
