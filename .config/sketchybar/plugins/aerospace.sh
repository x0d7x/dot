#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh
source "$CONFIG_DIR/items/spaces.sh"
if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set space.$current_workspace label="$current_workspace"

else
  sketchybar --set $NAME
fi
