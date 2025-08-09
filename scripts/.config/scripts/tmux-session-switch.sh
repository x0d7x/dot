#!/bin/bash
# Get a list of tmux sessions, and allow switching to one of them.

# Get the list of sessions.
SESSIONS=$(tmux list-sessions -F '#S (#{session_windows} windows, #{session_panes} panes)')

# If there are no sessions, we can exit.
if [ -z "$SESSIONS" ]; then
  exit 0
fi

# Use fzf to select a session.
SELECTED_SESSION=$(echo "$SESSIONS" | fzf --reverse \
  --prompt="-> " \
  --header="═══ Session Switcher ═══ | Ctrl-R: refresh | Ctrl-D: delete | Ctrl-N: new-session" \
  --header-first \
  --color="header:italic" \
  --bind="ctrl-r:reload(tmux list-sessions -F \"#{session_name}|#{session_windows}|#{?session_attached,attached,detached}\" | grep -v \"^\$(tmux display-message -p \"#S\")|\" | awk -F\"|\" \"{status = (\\\$3 == \\\"attached\\\") ? \\\"\\\" : \\\"\\\"; printf \\\"%-20s %s %2s windows %s\\\\n\\\", \\\$1, status, \\\$2, \\\"\\\"}\")" \
  --bind="ctrl-d:execute(tmux kill-session -t {1})+reload(tmux list-sessions -F \"#{session_name}|#{session_windows}|#{?session_attached,attached,detached}\" | grep -v \"^\$(tmux display-message -p \"#S\")|\" | awk -F\"|\" \"{status = (\\\$3 == \\\"attached\\\") ? \\\"\\\" : \\\"\\\"; printf \\\"%-20s %s %2s windows %s\\\\n\\\", \\\$1, status, \\\$2, \\\"\\\"}\")" \
  --info=inline \
  --layout=reverse |
  awk "{print \$1}" |
  xargs -r tmux switch-client -t)

# If the user selected a session, switch to it.
if [ -n "$SELECTED_SESSION" ]; then
  SESSION_NAME=$(echo "$SELECTED_SESSION" | awk '{print $1}')
  tmux switch-client -t "$SESSION_NAME"
fi
