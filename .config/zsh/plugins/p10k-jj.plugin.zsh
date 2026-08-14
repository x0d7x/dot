setopt localoptions NO_shwordsplit
typeset -g POWERLEVEL9K_JJ_COMMAND=(
    jj log --ignore-working-copy --color always --revisions @ --no-graph --template '
    if(root,
      format_root_commit(self),
      concat(
        separate(" ",
          if(immutable, label("immutable", "◆")),
          if(conflict, label("conflict", "×")),
          change_id.shortest(8),
          truncate_end(18, bookmarks, "…"),
          tags,
          working_copies,
          if(empty, label("empty", "∅")),
          if(description,
            truncate_end(24, description.first_line(), "…"),
            label(if(empty, "empty", "description placeholder"), "#"),
          ),
        ),
        "\n"
      ),
    )')
function prompt_jj() {
    [[ -d .jj ]] || return
    p10k segment -t \
        "$(${POWERLEVEL9K_JJ_COMMAND[@]} \
            | tr -d '\n' \
            | sed -r 's/\x1b\[[0-9;]*m/%{&%}/g')"
}
