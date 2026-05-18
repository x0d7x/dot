#!/bin/bash
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

if [[ "$1" == "edit" ]]; then
  grim -g "$(slurp)" - | swappy -f - -o "$file"
elif [[ "$1" == "edit-full" ]]; then
  grim - | swappy -f - -o "$file"
elif [[ "$1" == "area" ]]; then
  grim -g "$(slurp)" "$file"
else
  grim "$file"
fi

wl-copy <"$file"
qs -c "noctalia-shell" ipc call toast send \
  "$(printf '{"title":"Screenshot Taken","body":"%s"}' "$(
    basename "$file"
  )")"
