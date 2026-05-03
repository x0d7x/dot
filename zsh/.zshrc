if [[ -o interactive ]]; then
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
[ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zap" ] && git clone -b release-v1 https://github.com/zap-zsh/zap.git "${XDG_DATA_HOME:-$HOME/.local/share}/zap"
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zdharma-continuum/fast-syntax-highlighting"
plug "romkatv/powerlevel10k"
autoload -Uz compinit && compinit
plug "Aloxaf/fzf-tab"
plug "TunaCuma/zsh-vi-man"
source "$HOME/aliases"
source "$HOME/fzf"
source "$HOME/func"

setopt autocd
setopt correct
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst

bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select=2
zstyle ':completion:*' special-dirs true
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --color=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
setopt hist_expire_dups_first
setopt hist_reduce_blanks

export GPG_TTY=$TTY
export EDITOR=nvim
export VISUAL=nvim
export ZVM_MAN_PAGER='bat'
export SUDO_EDITOR=nvim
export FCEDIT=nvim

path+=(
$HOME/.local/bin
$HOME/.bun/bin
)
typeset -gU path
export PATH

HISTSIZE=10000
HISTFILE=$HOME/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
