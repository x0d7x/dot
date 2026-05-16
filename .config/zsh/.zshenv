#!/usr/bin/env zsh
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export GPG_TTY=$TTY
export EDITOR=nvim
export VISUAL=nvim
path+=(
$HOME/.local/bin
$HOME/.bun/bin
)
typeset -gU path
export PATH
export MANPAGER=${MANPAGER:-"less -R"}
xdg_base_dirs=("$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME")
for dir in "${xdg_base_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
done
