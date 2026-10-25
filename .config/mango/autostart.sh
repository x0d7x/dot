#!/bin/bash

set -e

# Mango IPC socket

MANGO_INSTANCE_SIGNATURE="$(systemctl --user show-environment | sed -n 's/^MANGO_INSTANCE_SIGNATURE=//p')"
export MANGO_INSTANCE_SIGNATURE
tmux set-environment -g MANGO_INSTANCE_SIGNATURE "$MANGO_INSTANCE_SIGNATURE" 2>/dev/null || true

# XDG Desktop Portal
#NOTE: no need for this after release v0.7.13

# /usr/lib/xdg-desktop-portal-gtk >/dev/null 2>&1 &
# /usr/lib/xdg-desktop-portal-wlr >/dev/null 2>&1 &
#
#
# /usr/lib/xdg-desktop-portal >/dev/null 2>&1 &

# Wayland services
# kanshi -c "$HOME/.config/kanshi/config" >/tmp/kanshi.log 2>&1 &
awww-daemon >/tmp/awww.log 2>&1 &
waybar >/tmp/waybar.log 2>&1 &
vicinae server >/tmp/vicinae.log 2>&1 &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/tmp/polkit-gnome-authentication-agent-1.log 2>&1 &
# swaync >/tmp/swaync.log 2>&1 &
# noctalia >/tmp/noctalia.log 2>&1 &

# Clipboard history

# insted i use vicinae launcher clipboard
# wl-paste --type text --watch cliphist store &
# wl-paste --type image/png --watch cliphist store &

# Optional services
# gsr-ui launch-daemon >/tmp/gsr-ui.log 2>&1 &

# Lock after 2 minutes of inactivity
# Turn off monitors after 5 minutes
# swayidle -w \
#   timeout 120 'swaylock -f' \
#   timeout 300 'mmsg dispatch disable_monitor,eDP-1; mmsg dispatch sleep_monitor,DP-3' \
#   resume 'mmsg dispatch wakeup_monitor,DP-3' \
#   before-sleep 'swaylock -f'

# mmsg dispatch disable_monitor,eDP-1
# mmsg dispatch create_virtual_output
# /home/dox/Developer/mango-history/mango-history daemon &
# /home/dox/Downloads/activitywatch/aw-qt >/dev/null 2>&1 &
