# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Source/Load zinit 
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

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
# Set unique PATH entries with correct order
typeset -U path
path=(
/usr/local/bin
/usr/local/sbin
$HOME/.bun/bin
$HOME/.local/bin
$HOME/.cargo/bin
$path
)
export PATH="${(j/:/)path}"
# Homebrew shell environment
if [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
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
 source ~/.config/zsh/aliases.zsh
 source ~/.config/zsh/fzf.zsh
#######################################################
# Shell integrations
#######################################################
#### --- p10k ---
zinit ice depth"1"  
zinit light romkatv/powerlevel10k
# zinit ice wait"1" lucid 
# zinit snippet OMZ::plugins/starship/starship.plugin.zsh
### --- zoxide ---
zinit ice wait"1" lucid 
zinit snippet OMZP::zoxide
### --- fast-syntax-highlighting ---
zinit ice wait"1" lucid
zinit light zdharma-continuum/fast-syntax-highlighting
### --- thefuck ---
zinit ice wait"2" lucid 
zinit snippet OMZP::thefuck
### --- zsh-autosuggestions ---
zinit ice wait"1" lucid
zinit light zsh-users/zsh-autosuggestions
### --- zsh-completions ---
zinit ice wait"1" lucid
zinit light zsh-users/zsh-completions
### --- fzf ---
zinit ice wait"1" lucid atload'source /usr/local/opt/fzf/shell/key-bindings.zsh; source /usr/local/opt/fzf/shell/completion.zsh'
zinit snippet OMZP::fzf
### --- fzf tab --- 
zinit ice wait"1" lucid
zinit light Aloxaf/fzf-tab
#######################################################
# Completion styling (after plugin setup)
#######################################################
autoload -Uz compinit &&  compinit
zinit cdreplay -q
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --color=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
#######################################################
# Functions
#######################################################
function _load_secrets() {
  export GEMINI_API_KEY="$(command pass show google/geminiApiKey)"
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(command pass show github/GITHUB_PERSONAL_ACCESS_TOKEN)"
  # export OPENAI_API_KE="$GEMINI_API_KEY"
  # export OPENAI_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _load_secrets_once

function _load_secrets_once() {
  if [[ -z $GEMINI_API_KEY || -z $GITHUB_PERSONAL_ACCESS_TOKEN ]]; then
    _load_secrets
  fi
  add-zsh-hook -d precmd _load_secrets_once
}
function zz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

