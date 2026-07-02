#!/usr/bin/env zsh
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export GPG_TTY=$TTY
export EDITOR=nvim
export VISUAL=nvim
export BROWSER=${BROWSER:-flatpak run app.zen_browser.zen}
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
export PI_CODING_AGENT_DIR=$HOME/.config/pi/agent/
export MANGO_INSTANCE_SIGNATURE=$(ls /run/user/1000/mango-*.sock 2>/dev/null | head -1)
path+=(
$HOME/.local/bin
$HOME/.bun/bin
$HOME/.local/share/pnpm/bin
$HOME/go/bin
)
typeset -gU path
export PATH
# ---------- Pager ----------
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi
xdg_base_dirs=("$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME")
for dir in "${xdg_base_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
done
. "/home/dox/.local/share/bob/env/env.sh"
