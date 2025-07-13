#!/bin/bash
APP_NAME="OBS Studio"
WINDOW_ID=$(aerospace list-windows --all | awk -v app="$APP_NAME" '$0 ~ app && $0 !~ "Chat" {print $1}')
PIP_WIN=$(aerospace list-windows --all | grep -E "(Picture in Picture)" | awk '{print $1}')
CHAT_WIN=$(aerospace list-windows --all | grep -E "(Chat)" | awk '{print $1}')
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE
# if [ -n "$WINDOW_ID" ]; then
#   aerospace move-node-to-workspace $FOCUSED_WORKSPACE --window-id $WINDOW_ID
# fi
if [[ -n "$PIP_WIN" ]]; then
  aerospace move-node-to-workspace --window-id "$PIP_WIN" "$CURRENT_WORKSPACE"
fi
if [[ -n "$CHAT_WIN" ]]; then
  aerospace move-node-to-workspace --window-id "$CHAT_WIN" "$CURRENT_WORKSPACE"
fi
