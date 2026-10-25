#!/usr/bin/env bash

PIP_REGEX='picture[._ -]?in[._ -]?picture|\bpip\b'

get_focused_workspace() {
    niri msg --json workspaces 2>/dev/null |
        jq -r '.[] | select(.is_focused) | .idx'
}

get_pip_window() {
    niri msg --json windows 2>/dev/null |
        jq -r --arg regex "$PIP_REGEX" '
            .[] | select(
                .is_floating and
                (.title | test($regex; "i"))
            ) | .id
        ' | head -n1
}

move_pip() {
    local workspace="$1"
    local wid
    wid=$(get_pip_window)
    [[ -z "$wid" ]] && return
    niri msg action move-window-to-workspace "$workspace" \
        --window-id "$wid" \
        --focus false \
        >/dev/null 2>&1
}

last_workspace=$(get_focused_workspace)

niri msg --json event-stream 2>/dev/null | while read -r line; do
    current_workspace=$(get_focused_workspace)

    if [[ "$current_workspace" != "$last_workspace" ]]; then
        move_pip "$current_workspace"
        last_workspace="$current_workspace"
    fi
done
