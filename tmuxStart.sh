#!/bin/bash
if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then tmux attach || tmux new -s Dev; else fish; fi
