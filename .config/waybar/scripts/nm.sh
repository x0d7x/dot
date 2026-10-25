#!/usr/bin/env bash

set -euo pipefail

mapfile -t networks < <(
  nmcli --terse --escape yes \
    --fields SSID,SIGNAL,SECURITY \
    device wifi list --rescan yes |
    awk -F: 'NF >= 3 && $1 != "" {
        printf "%s (%s%%) [%s]\n", $1, $2, $3
    }' |
    sort -u
)

((${#networks[@]})) || exit 0

selected=$(
  printf '%s\n' "${networks[@]}" |
    vicinae dmenu --placeholder "Select Wi-Fi network"
) || exit 0

ssid=${selected% (*}
[[ -n "$ssid" ]] || exit 0

if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
  nmcli connection up id "$ssid"
else
  kitty -e nmcli --ask device wifi connect "$ssid"
fi
