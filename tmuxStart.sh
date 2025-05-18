#!/bin/bash
if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
  exec tmux attach || exec tmux new -s Dev
else
  exec fish
fi
