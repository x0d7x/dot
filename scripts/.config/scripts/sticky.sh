#!/bin/bash
APP_NAME="OBS Studio"

WINDOW_ID=$(aerospace list-windows --all | awk -v app="$APP_NAME" '$0 ~ app && $0 !~ "Chat" {print $1}')
PIP_WIN=$(aerospace list-windows --all | grep -Ei 'Picture[- ]in[- ]Picture' | awk '{print $1}')
CHAT_WIN=$(aerospace list-windows --all | grep -F "$APP_NAME" | grep -E "(Chat)" | awk '{print $1}')

CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE

# if [ -n "$WINDOW_ID" ]; then
#   aerospace move-node-to-workspace --window-id "$WINDOW_ID" "$CURRENT_WORKSPACE"
# fi

for id in $PIP_WIN $CHAT_WIN; do
  [ -n "$id" ] && aerospace move-node-to-workspace --window-id "$id" "$CURRENT_WORKSPACE"
done
