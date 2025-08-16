#!/bin/bash
sketchybar --add item front_app left \
  --set front_app \
  background.color=$BG \
  icon_color=0xff98971a \
  icon.font="sketchybar-app-font:Regular:16.0" \
  label.color=$WHITE \
  script="$PLUGIN_DIR/front_app.sh" \
  --subscribe front_app front_app_switched
