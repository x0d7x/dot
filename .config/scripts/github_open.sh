#!/usr/bin/env bash

# Get current pane directory
dir=$(tmux display -p -F "#{pane_current_path}")
cd "$dir" || exit 1

# Get remote URL
url=$(git remote get-url origin 2>/dev/null) || {
  echo "No git remote found."
  exit 1
}

# Convert SSH URL to HTTPS if needed
if [[ "$url" =~ ^git@github.com:(.*)\.git$ ]]; then
  url="https://github.com/${BASH_REMATCH[1]}"
fi

# Open in browser
if [[ "$url" == *"github.com"* ]]; then
  if command -v open &>/dev/null; then
    open "$url" # macOS
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url" # Linux
  else
    echo "No method to open browser found."
    exit 1
  fi
else
  echo "This repository is not hosted on GitHub"
fi
