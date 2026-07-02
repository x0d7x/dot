#!/bin/bash
# Dynamically find the current mango socket
# Dynamically find and export the current mango socket (fixes stale env)
export MANGO_INSTANCE_SIGNATURE=$(ls /run/user/1000/mango-*.sock 2>/dev/null | head -1)
systemctl --user set-environment MANGO_INSTANCE_SIGNATURE="$MANGO_INSTANCE_SIGNATURE"
noctalia &
wl-paste --type text --watch cliphist store &
wl-paste --type image/png --watch cliphist store &
/usr/lib/xdg-desktop-portal-wlr &
