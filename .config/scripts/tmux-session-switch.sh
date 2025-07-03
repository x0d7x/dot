#!/bin/bash
# Get a list of tmux sessions, and allow switching to one of them.

# Get the list of sessions.
SESSIONS=$(tmux list-sessions -F '#S (#{session_windows} windows, #{session_panes} panes)')

# If there are no sessions, we can exit.
if [ -z "$SESSIONS" ]; then
    exit 0
fi

# Use fzf to select a session.
SELECTED_SESSION=$(echo "$SESSIONS" | fzf)

# If the user selected a session, switch to it.
if [ -n "$SELECTED_SESSION" ]; then
    SESSION_NAME=$(echo "$SELECTED_SESSION" | awk '{print $1}')
    tmux switch-client -t "$SESSION_NAME"
fi
