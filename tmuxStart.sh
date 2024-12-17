if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
  tmux new-session -s dullx   
  tmux select-pane -t 0
  tmux rename-window "Dev"
  tmux send-keys 'cd ~/Developer' Enter
  tmux send-keys 'fastfetch' Enter
  tmux split-window -v
  tmux split-window -h
  tmux select-pane -t 2
  tmux send-keys 'btop' Enter
  tmux select-pane -t 0
  tmux attach-session -t dullx
fi
