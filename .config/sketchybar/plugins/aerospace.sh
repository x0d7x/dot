#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh

# $1 is the workspace ID passed from the space item
WORKSPACE_ID="$1"

if [ "$WORKSPACE_ID" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.drawing=on label.color=0xffffffff
else
    sketchybar --set $NAME background.drawing=off label.color=0xff689d6a
fi
