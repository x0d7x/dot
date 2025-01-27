#!/bin/bash
source "$CONFIG_DIR/color.sh"
sketchybar --add event aerospace_workspace_change
current_workspace=$(aerospace list-workspaces --focused)
    sketchybar --add item workspace_label left \
        --subscribe workspace_label aerospace_workspace_change \
        --set workspace_label \
        background.color=0x44ffffff \
        background.corner_radius=9 \
        background.drawing=on \
        label="$current_workspace" \
         icon.padding_left=3                           \
        click_script="aerospace workspace $current_workspace" \
        script="$CONFIG_DIR/plugins/aerospace.sh"
done
