# Commands to run in interactive sessions can go here
if status is-interactive
    # Aliases
    set -U fish_greeting
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
    # Abbreviations
    abbr --add clone 'git clone'
    abbr --add br brew
    abbr --add bri "brew install"
    abbr --add dn deno
    abbr --add dr "deno run"
    abbr --add ni "bun i"
    abbr --add nr "bun run"
    # Environment variables
    set -gx EDITOR nvim
    set -gx VISUAL "$EDITOR"
    #yazi 
    function zz
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp")
            and test -n "$cwd"
            and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end
    # FZF preview function
    #function show_file_or_dir_preview
    #    if test -d $argv[1]
    #        eza --tree --color=always $argv[1] | head -200
    #    else
    #        bat -n --color=always --line-range :500 $argv[1]
    #    end
    #end
    # FZF environment variables
    #set -gx FZF_CTRL_T_OPTS "--preview 'show_file_or_dir_preview {}'"
    #set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"

    # FZF command overrides
    #function _fzf_comprun
    #    set command $argv[1]
    #    set -e argv[1]
    #
    #    switch "$command"
    #        case cd
    #            fzf --preview 'eza --tree --color=always {} | head -200' $argv
    #        case export unset
    #            fzf --preview "eval 'echo \${}'" $argv
    #        case ssh
    #            fzf --preview 'dig {}' $argv
    #        case '*'
    #            fzf --preview "show_file_or_dir_preview {}" $argv
    #    end
    #end

    # Use fd instead of find for FZF
    #set -gx FZF_DEFAULT_COMMAND "fd --hidden --strip-cwd-prefix --exclude .git"
    #set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    #set -gx FZF_ALT_C_COMMAND "fd --type=d --hidden --strip-cwd-prefix --exclude .git"
    # FZF path and directory completion functions
    function _fzf_compgen_path
        fd --hidden --exclude .git . "$argv[1]"
    end
    function _fzf_compgen_dir
        fd --type=d --hidden --exclude .git . "$argv[1]"
    end
    #open tmux session in fzf
    function tz
        set session $(tmux list-sessions | cut -d ':' -f 1 | fzf)
        if test -n "$session"
            tmux attach-session -t $session
        else
            echo "No session selected"
        end
    end
    # opeen files or dir iin nvim
    function nz
        # get first argument
        # if it is a directory, cd into it
        set -l dir $argv[1]
        # check if it is empty
        if test -z "$dir"
        else
            z $dir
        end
        set file $(fzf)
        if test -n "$file"
            nvim $file
        else if test -n "$dir"
            cd $dir
        else
            echo "No file selected"
        end
    end
    # Lazy-load starship
    function starship_init --on-event fish_prompt
        starship init fish | source
        functions --erase starship_init
    end
    # Lazy-load thefuck
    function fk
        if not type -q __thefuck_init
            thefuck --alias fk | source
            __thefuck_init
        end
        fk $argv
    end

    # Lazy-load fzf
    function fzf_init --on-event fish_prompt
        fzf --fish | source
        functions --erase fzf_init
    end

    # Lazy-load zoxide
    function zoxide_init --on-event fish_prompt
        zoxide init fish | source
        functions --erase zoxide_init
    end

end
