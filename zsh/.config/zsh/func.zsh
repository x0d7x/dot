function zz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# if we ewant to start starship on zsh startup
# autoload -Uz add-zsh-hook
# __starship_boot_once() {
#   add-zsh-hook -d precmd __starship_boot_once
#   eval "$(starship init zsh)"
#   zle && zle reset-prompt
# }
# add-zsh-hook precmd __starship_boot_once

