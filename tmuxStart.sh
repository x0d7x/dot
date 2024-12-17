#!/bin/bash
EV_DIR=~/Developer
FASTFETCH_CMD=fastfetch
BTOP_CMD=btop
TARGET_PANES=3
if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
 if tmux has-session -t dullx; then
    echo "Joining existing session: dullx"
          tmux attach -t dullx
    num_windows=$(tmux list-panes -t dullx | wc -l)
     if [ "$num_windows" -eq 3 ]; then
          echo "Session already has 3 windows. Attaching..."
          tmux attach -t dullx
      else
        while [ "$num_windows" -lt "$TARGET_PANES" ]; do
        tmux split-window -v
        tmux split-window -h
        num_windows=$(tmux list-panes -t dullx | wc -l)
        done
 fi
  else
    echo "Creating new session: dullx"
    tmux new-session -s dullx
    tmux select-pane -t 0
    tmux rename-window "Dev"
    tmux send-keys "cd $DEV_DIR" Enter
    tmux send-keys "$FASTFETCH_CMD" Enter
    tmux split-window -v
    tmux split-window -h
    tmux select-pane -t 2
    tmux send-keys "$BTOP_CMD" Enter
    tmux select-pane -t 0
    tmux a -t dullx
  fi
fi
