#!/bin/bash

AEROSPACE_CMD="/run/current-system/sw/bin/aerospace"
AWK_CMD="/usr/bin/awk"
RG_CMD="/run/current-system/sw/bin/rg"

if [[ ! -x "$AEROSPACE_CMD" || ! -x "$RG_CMD" ]]; then
  exit 1
fi

APP_NAME="mpv"

ALL_WINDOWS=$($AEROSPACE_CMD list-windows --all)

WINDOW_ID=$(echo "$ALL_WINDOWS" | $RG_CMD --fixed-strings "$APP_NAME" | $RG_CMD --invert-match "Chat" | $AWK_CMD '{print $1}')
PIP_WIN=$(echo "$ALL_WINDOWS" | $RG_CMD --ignore-case 'Picture[ -]in[ -]Picture' | $AWK_CMD '{print $1}')
CHAT_WIN=$(echo "$ALL_WINDOWS" | $RG_CMD --fixed-strings "$APP_NAME" | $RG_CMD --regexp "\(Chat\)" | $AWK_CMD '{print $1}')

CURRENT_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE

if [ -z "$CURRENT_WORKSPACE" ]; then
  CURRENT_WORKSPACE=$($AEROSPACE_CMD list-workspaces --focused)
fi

for id in $PIP_WIN $CHAT_WIN; do
  if [ -n "$id" ]; then
    $AEROSPACE_CMD move-node-to-workspace --window-id "$id" "$CURRENT_WORKSPACE"
  fi
done
