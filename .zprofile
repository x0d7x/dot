if command -v tmux >/dev/null 3>&1 && [ -z "$TMUX" ] && [ -n "$PS1" ]; then
  exec tmux attach-session -t Dev || exec tmux new-session -s Dev
  else
    exec zsh
fi
# Set unique PATH entries with correct order
typeset -U path
path=(
  /usr/local/bin
  /usr/local/sbin
  /Users/dullx/.bun/bin
  $HOME/.local/bin
  $path
)
export PATH="${(j/:/)path}"
if [[ -f "/usr/local/bin/brew" ]] then
  # If you're using macOS, you'll want this enabled
  eval "$(/usr/local/bin/brew shellenv)"
fi
