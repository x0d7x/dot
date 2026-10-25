#!/bin/sh

CONFIG="$HOME/.config/mango/config.conf"
STATE="$XDG_RUNTIME_DIR/mango-effects-off"

if [ -f "$STATE" ]; then
  # ON
  sed -i \
    -e 's/^blur=.*/blur=1/' \
    -e 's/^focused_opacity=.*/focused_opacity=0.9/' \
    -e 's/^unfocused_opacity=.*/unfocused_opacity=0.6/' \
    "$CONFIG"

  rm "$STATE"
else
  # OFF
  sed -i \
    \
    -e 's/^focused_opacity=.*/focused_opacity=1.0/' \
    -e 's/^unfocused_opacity=.*/unfocused_opacity=1.0/' \
    "$CONFIG" # -e 's/^blur=.*/blur=0/' \ # if i want to toggle the blur no need for this

  touch "$STATE"
fi

mmsg dispatch reload_config
