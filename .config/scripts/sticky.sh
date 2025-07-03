#!/bin/bash
# This script makes a window sticky by moving it to the currently focused workspace.

# The application name to make sticky
APP_NAME="OBS Studio"

# Get the window ID for the application
WINDOW_ID=$(aerospace list-windows --all | awk -v app="$APP_NAME" '$0 ~ app {print $1}')

# If a window ID was found, move the application to the focused workspace
if [ -n "$WINDOW_ID" ]; then
  # Get the focused workspace name
  FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE

  # Move the application to the focused workspace
  aerospace move-node-to-workspace $FOCUSED_WORKSPACE --window-id $WINDOW_ID
fi
