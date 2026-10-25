#!/usr/bin/env bash

set -e

CONFIG="$HOME/.config/swaync/config.json"
SCRIPT="$HOME/.local/bin/power.sh"

current=$(tlpctl get)

case "$current" in
performance)
  next="balanced"
  icon=""
  ;;
balanced)
  next="power-saver"
  icon=""
  ;;
power-saver)
  next="performance"
  icon=""
  ;;
*)
  next="balanced"
  icon=""
  ;;
esac

tlpctl "$next"

tmp=$(mktemp "$HOME/.config/swaync/config.XXXXXX")

jq --arg icon "$icon" '
  .["widget-config"]["buttons-grid"].actions |=
  map(
    if .command == "~/.local/bin/power.sh" then
      .label = $icon
    else
      .
    end
  )
' "$CONFIG" >"$tmp"

mv "$tmp" "$CONFIG"

swaync-client --reload-config
