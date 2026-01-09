#!/usr/bin/env bash

wallpaper_dir="$HOME/Documents/wallpaper"

if [[ ! -d "$wallpaper_dir" ]]; then
  echo "❌ Wallpaper directory not found: $wallpaper_dir"
  exit 1
fi

wallpapers=($(/run/current-system/sw/bin/fd . "$wallpaper_dir" -e jpg -e png -e jpeg -e webp))

if [[ ${#wallpapers[@]} -eq 0 ]]; then
  echo "❌ No wallpapers found in: $wallpaper_dir"
  exit 1
fi

random_wallpaper="${wallpapers[RANDOM % ${#wallpapers[@]}]}"

# wal -i "$random_wallpaper"

/usr/bin/osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$random_wallpaper\""

echo "✅ Wallpaper changed to:"
echo "$random_wallpaper"
