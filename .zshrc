#!/bin/zsh
 # zmodload zsh/zprof
# ─── Load zsh-defer ────────────────────────────────────────────────
source ~/.local/share/zsh-defer/zsh-defer.plugin.zsh
# ─── Defer: Prompt and Tools ───────────────────────────────────────
eval "$(starship init zsh)"
# ─── Lazy-load zsh-autosuggestions ───────────────
zsh-defer source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# ─── Lazy-load zsh-syntax-highlighting ───────────
zsh-defer source /usr/local/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
# defer plugin-like tools
zsh-defer eval "$(zoxide init zsh)"
zsh-defer eval "$(thefuck --alias)"
zsh-defer eval "$(fzf --zsh)"
# Avoid slow completion on startup, defer it
# export ZSH_DISABLE_COMPFIX=true
zsh-defer compinit 
zsh-defer source ~/.zsh/fzf.zsh
zsh-defer source ~/.zsh/aliases.zsh
function _load_secrets() {
  export GEMINI_API_KEY="$(pass show google/geminiApiKey)"
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(pass show github/GITHUB_PERSONAL_ACCESS_TOKEN)"
}
# Load them only when pass is first called
function pass() {
  if [[ -z $GEMINI_API_KEY || -z $GITHUB_PERSONAL_ACCESS_TOKEN ]]; then
    _load_secrets
  fi
  unset -f pass
  command pass "$@"
}
# yazi setup for CWD when exit 
function zz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history hist_expire_dups_first hist_ignore_dups hist_verify
setopt NO_HASH_LIST_ALL NO_AUTO_NAME_DIRS
# keymaps
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
# env
export EDITOR=nvim
export VISUAL="$EDITOR"
export skip_global_compinit=1
# Man pager
export MANPAGER="nvim +Man!"
# cheat sheet
function ch ()
{
 curl https://cht.sh/$1;   
}
