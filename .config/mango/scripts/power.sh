#!/usr/bin/env bash

set -u

SELECTION="$(
  printf '%s\n' \
    '  Lock' \
    '⏾  Suspend' \
    '󰩈  Logout' \
    '󰑓  Reboot' \
    '  Shutdown' |
    vicinae dmenu --placeholder "see you space cowboy"
)" || exit 0

case "$SELECTION" in
*Lock)
  veila lock
  ;;
*Suspend)
  systemctl suspend
  ;;
*Logout)
  mmsg dispatch quit
  ;;
*Reboot)
  systemctl reboot
  ;;
*Shutdown)
  systemctl poweroff
  ;;
esac
