#!/bin/bash

set -e

# Import Wayland environment into systemd

# dbus-update-activation-environment --systemd --all
# systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME

# Mango IPC socket

MANGO_INSTANCE_SIGNATURE="$(systemctl --user show-environment | sed -n 's/^MANGO_INSTANCE_SIGNATURE=//p')"
export MANGO_INSTANCE_SIGNATURE

tmux set-environment -g MANGO_INSTANCE_SIGNATURE "$MANGO_INSTANCE_SIGNATURE" 2>/dev/null || true

# XDG Desktop Portal

/usr/lib/xdg-desktop-portal-gtk >/dev/null 2>&1 &
/usr/lib/xdg-desktop-portal-wlr >/dev/null 2>&1 &

sleep 1

/usr/lib/xdg-desktop-portal >/dev/null 2>&1 &

# Wayland services

kanshi &
noctalia &

# Clipboard history

wl-paste --type text --watch cliphist store &
wl-paste --type image/png --watch cliphist store &

# Optional services

# /home/dox/Developer/mango-history/mango-history daemon &
# /home/dox/Downloads/activitywatch/aw-qt >/dev/null 2>&1 &
