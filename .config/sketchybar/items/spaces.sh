#!/usr/bin/env bash
source "$CONFIG_DIR/color.sh"
sketchybar --add event aerospace_workspace_change

# Remove old space items if they exist
for sid in $(aerospace list-workspaces --all); do
  sketchybar --remove space.$sid 2>/dev/null || true
done

# Create single focused workspace item
current_workspace=$(aerospace list-workspaces --focused)
sketchybar --add item focused_workspace left \
  --subscribe focused_workspace aerospace_workspace_change \
  --set focused_workspace \
  background.color=0xff5d3a1a \
  background.corner_radius=13 \
  background.height=30 \
  background.padding_left=10 \
  background.padding_right=10 \
  background.drawing=off \
  label.color=0xffeda95b \
  label="$current_workspace" \
  click_script="aerospace workspace next" \
  script="$CONFIG_DIR/plugins/aerospace_focused.sh"
