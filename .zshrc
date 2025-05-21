# Source/Load zinit & zsh-defer
source /usr/local/opt/zinit/zinit.zsh

#######################################################
# ZSH Basic Options
#######################################################
setopt autocd
setopt correct
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst

#######################################################
# Environment Variables
#######################################################
export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim
export FCEDIT=nvim
export TERMINAL=kitty

#######################################################
# ZSH Keybindings
#######################################################
bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
########################################################
# History Configuration
#######################################################

HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
#######################################################
# Aliases, fzf setup
#######################################################
 source ~/.zsh/aliases.zsh
 source ~/.zsh/fzf.zsh
#######################################################
# Shell integrations
#######################################################
zinit ice wait"1" lucid atload'eval "$(/usr/local/bin/starship init zsh)"'
zinit snippet OMZ::plugins/starship/starship.plugin.zsh
### --- zoxide ---
zinit ice wait"1" lucid atload'eval "$(/usr/local/bin/zoxide init zsh)"'
zinit snippet OMZ::plugins/zoxide/zoxide.plugin.zsh
### --- fast-syntax-highlighting ---
zinit ice wait"1" lucid
zinit light zdharma-continuum/fast-syntax-highlighting
### --- thefuck ---
zinit ice wait"2" lucid atload'eval "$(/usr/local/bin/thefuck --alias )"'
zinit snippet OMZ::plugins/thefuck/thefuck.plugin.zsh
### --- zsh-autosuggestions ---
zinit ice wait"1" lucid
zinit light zsh-users/zsh-autosuggestions
### --- zsh-completions ---
zinit ice wait"1" lucid
zinit light zsh-users/zsh-completions
### --- fzf ---
zinit ice wait"1" lucid atload'source /usr/local/opt/fzf/shell/key-bindings.zsh; source /usr/local/opt/fzf/shell/completion.zsh'
zinit snippet OMZ::plugins/fzf/fzf.plugin.zsh
### --- fzf tab --- 
zinit ice wait"1" lucid
zinit light Aloxaf/fzf-tab
#######################################################
# Completion styling (after plugin setup)
#######################################################
autoload -Uz compinit &&  compinit

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

#######################################################
# Functions
#######################################################
function _load_secrets() {
  export GEMINI_API_KEY="$(pass show google/geminiApiKey)"
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(pass show github/GITHUB_PERSONAL_ACCESS_TOKEN)"
}
function pass() {
  if [[ -z $GEMINI_API_KEY || -z $GITHUB_PERSONAL_ACCESS_TOKEN ]]; then
    _load_secrets
  fi
  unset -f pass
  command pass "$@"
}
function zz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
