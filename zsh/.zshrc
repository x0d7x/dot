[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
# plug "zap-zsh/supercharge"
plug "TunaCuma/zsh-vi-man"
# ZSH Basic Options
setopt autocd
setopt correct
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
# Environment Variables
export GPG_TTY=$TTY
export EDITOR=nvim
export VISUAL=nvim
# export GEMINI_API_KEY=$(pass show google/geminiApiKey)
# export GITHUB_PERSONAL_ACCESS_TOKEN=$(pass show github/GITHUB_PERSONAL_ACCESS_TOKEN)
# export ZVM_MAN_PAGER='bat'
export SUDO_EDITOR=nvim
export FCEDIT=nvim
# Set unique PATH entries with correct order
path+=(
$HOME/.local/bin
$HOME/.bun/bin
)
typeset -U path
path=($^path(N-/))
export PATH
# ZSH Keybindings
bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
# History Configuration
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
# Set zstyle
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --color=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
