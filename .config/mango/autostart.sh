#!/bin/bash

set -e

# Export the current mango socket so child processes find it
export MANGO_INSTANCE_SIGNATURE=$(ls /run/user/1000/mango-*.sock 2>/dev/null | head -1)
systemctl --user set-environment MANGO_INSTANCE_SIGNATURE="$MANGO_INSTANCE_SIGNATURE"
# Push Wayland env to systemd (so portal services see them)
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE QT_QPA_PLATFORMTHEME
/usr/lib/xdg-desktop-portal-gtk >/dev/null 2>&1 &
/usr/lib/xdg-desktop-portal-wlr >/dev/null 2>&1 &
sleep 1
/usr/lib/xdg-desktop-portal >/dev/null 2>&1 &
noctalia &
# /home/dox/Developer/mango-history/mango-history daemon &
wl-paste --type text --watch cliphist store &
wl-paste --type image/png --watch cliphist store &
