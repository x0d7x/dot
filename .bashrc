set -o vi
# Silence zsh deprecation on macOS
export BASH_SILENCE_DEPRECATION_WARNING=1

# Speed tip: Lazy-load Homebrew only when needed
function brew() {
  unset -f brew
  eval "$(/usr/local/bin/brew shellenv)"
  command brew "$@"
}
# load all completions
for bcfile in /usr/local/etc/bash_completion.d/*; do
  if [[ -r $bcfile ]]; then
    source "$bcfile"
  fi
done
eval "$(starship init bash)"
PROMPT_COMMAND='PS1=$(starship prompt)'
# Lazy-load Starship prompt
# if [ -f "$(which starship)" ]; then
#   function _init_starship() {
#     eval "$(starship init bash)"
#   }
#   PROMPT_COMMAND="_init_starship; $PROMPT_COMMAND"
# fi

# Aliases
alias ls="eza --all --icons=always --long --git --color=always --no-user --no-filesize --no-time"
alias c="clear"
alias e="exit"
alias n="nvim"
alias lg="lazygit"
alias cat="bat"
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'
alias tok='tokei'
alias gcn="git clone --no-checkout"
alias gsi="git sparse-checkout init"
alias gss="git sparse-checkout set"
alias g="z"
alias gi="zi"
alias clone='git clone'

# brew shortcut aliases (lazy-load will still work)
alias br=brew
alias bri="brew install"

# bun
alias bi="bun i"
alias bx=bunx
alias b=bun
alias ba="bun add"
alias bu="bun update"
alias brm="bun remove"
alias brd="bun run dev"
alias brb="bun run build"

# codex
alias dx=open-codex

# Editor
export EDITOR=nvim
export VISUAL="$EDITOR"

# Secrets (lazy evaluated)
function _load_secrets() {
  export GEMINI_API_KEY="$(pass show google/geminiApiKey)"
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(pass show github/GITHUB_PERSONAL_ACCESS_TOKEN)"
}
# Load them only when pass is first called
function pass() {
  _load_secrets
  unset -f pass
  command pass "$@"
}

# Manpage viewer
export MANPAGER="nvim +Man!"

# zoxide (lazy)
function z() {
  unset -f z
  eval "$(zoxide init bash)"
  z "$@"
}
function zi() {
  z "$@"
}

# thefuck (lazy)
function fk() {
  unset -f fk
  eval "$(thefuck --alias fk)"
  fk "$@"
}
function fuck() {
  unset -f fuck
  eval "$(thefuck --alias)"
  fuck "$@"
}

# fzf (lazy)
function _init_fzf() {
  unset -f fzf
  eval "$(fzf --bash)"
  fzf "$@"
}
alias fzf=_init_fzf

# fzf previews
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
  cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
  export | unset) fzf --preview "eval 'echo \${}'" "$@" ;;
  ssh) fzf --preview 'dig {}' "$@" ;;
  *) fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# Yazi CWD restore
function zz() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
function set_bash_prompt() {
  if [[ $KEYMAP == "vicmd" ]]; then
    mode="-- NORMAL --"
  else
    mode=""
  fi
  PS1="\[\e[32m\]\u@\h \[\e[33m\]\w \[\e[31m\]$mode\[\e[0m\]\n\$ "
}
