#!/bin/zsh
# zmodload zsh/zprof
# start starship 
eval "$(starship init zsh)"
# --------------aliases----------------
alias ls="eza --all --icons=always --long --git --color=always --no-user --no-filesize --no-time"
alias c="clear"
alias e="exit"
alias n="nvim"
alias lg="lazygit"
alias cat="bat"
alias br="brew"
alias bri="brew install"
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'
alias tok='tokei'
alias dn="deno"
alias dr="deno run"
alias ni="bun i"
alias nr="bun run"
alias gcn="git clone --no-checkout"
alias gsi="git sparse-checkout init"
alias gss="git sparse-checkout set"
alias g="z"
alias gi="zi"

# starting zsh tools
# ------- the fuck ------
eval $(thefuck --alias)
eval $(thefuck --alias fk)
# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}
# Set up zoxiide 
eval "$(zoxide init zsh)"
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
setopt share_history 
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify
# autoload -U _zsh_highlight_bind_widgets
# source ~/.zshshell/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
#set nvim as default editor
export EDITOR=nvim
export VISUAL="$EDITOR"
# --- php version --- 
export PATH="/usr/local/opt/php@5.6/sbin:$PATH"
export PATH="/usr/local/opt/php@5.6/bin:$PATH"
export PATH="/Users/dullx/.bun/bin:$PATH"
#------- run nerdfetch ------------
# tmux attach session 
# source ~/tmuxStart.sh
# cheat sheet
function ch ()
{
 curl https://cht.sh/$1;   
}
# --sourcing zsh-plugins --
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=cyan'
source ~/.zshshell/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
 # --------- Groq Api ------------ 
 export GROQ_API_KEY= 
 # zprof
