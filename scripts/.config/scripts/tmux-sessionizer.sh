#!/usr/bin/env bash

SEARCH_DIRS=(
  "$HOME"
  "$HOME/Developer"
  "$HOME/repo"
  "$HOME/dot"
  "$HOME/.config"
)

if [[ $# -eq 1 ]]; then
  selected="$1"
else
  selected="$(
    fd -H -t d -d 2 --absolute-path . "${SEARCH_DIRS[@]}" |
      sed "s|^$HOME/||" |
      fzf --margin=2% --color --border --cycle --prompt="📁 search> " |
      sed "s|^|$HOME/|"
  )"
fi

[[ -z "$selected" ]] && exit 0

selected_name="$(basename "$selected" | tr ' ./:' '_')"

if [[ -z "${TMUX:-}" ]] && ! pgrep -x tmux >/dev/null 2>&1; then
  exec tmux new-session -s "$selected_name" -c "$selected"
fi

if ! tmux has-session -t "$selected_name" 2>/dev/null; then
  tmux new-session -ds "$selected_name" -c "$selected"
fi

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$selected_name"
else
  exec tmux attach -t "$selected_name"
fi
