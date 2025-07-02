#!/bin/bash
# This script makes a window sticky by moving it to the currently focused workspace.

# The application name to make sticky
APP_NAME="OBS Studio"

# Get the focused workspace name
FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE

# Move the application to the focused workspace
aerospace move-node-to-workspace $FOCUSED_WORKSPACE --window-id $(aerospace list-windows --all | awk -v app="$APP_NAME" '$0 ~ app {print $1}')
