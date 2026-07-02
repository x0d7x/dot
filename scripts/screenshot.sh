#!/usr/bin/env bash

set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

notify() {
    command -v notify-send >/dev/null &&
        notify-send "$1" "$2" || true
}

copy_to_clipboard() {
    local file="$1"
    [[ -f "$file" ]] || return 1

    if command -v wl-copy >/dev/null; then
        wl-copy --type image/png < "$file"
    fi

    if command -v cliphist >/dev/null; then
        cliphist store < "$file"
    fi
}

# ---

file="$DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

case "${1:-full}" in
    edit)
        # Select region → annotate in swappy → save to $file
        if ! grim -g "$(slurp)" - | swappy -f - -o "$file"; then
            notify "Screenshot" "Cancelled or no screenshot was taken."
            exit 1
        fi
        ;;

    edit-full)
        # Full screen → annotate in swappy → save to $file
        if ! grim - | swappy -f - -o "$file"; then
            notify "Screenshot" "Cancelled or no screenshot was taken."
            exit 1
        fi
        ;;

    area)
        # Select region → save to $file immediately (no annotation)
        if ! grim -g "$(slurp)" "$file"; then
            notify "Screenshot" "Cancelled or no screenshot was taken."
            exit 1
        fi
        ;;

    full)
        # Full screen → save to $file immediately (no annotation)
        if ! grim "$file"; then
            notify "Screenshot" "Cancelled or no screenshot was taken."
            exit 1
        fi
        ;;

    *)
        echo "Usage:"
        echo "  screenshot full        — full screen, no annotation"
        echo "  screenshot area        — select region, no annotation"
        echo "  screenshot edit        — select region, then annotate (swappy)"
        echo "  screenshot edit-full   — full screen, then annotate (swappy)"
        exit 1
        ;;
esac

if [[ -f "$file" ]]; then
    copy_to_clipboard "$file"
    notify "Screenshot Saved" "$(basename "$file")"
else
    notify "Screenshot" "Cancelled or no screenshot was taken."
fi
