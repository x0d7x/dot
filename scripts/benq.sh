#!/usr/bin/env bash

case "$1" in
set)
  value="${2:-}"
  [[ "$value" =~ ^[0-9]+$ ]] || exit 1
  ((value >= 0 && value <= 100)) || exit 1

  # Update the latest requested value.
  printf '%s\n' "$value" >/tmp/benq-brightness-value

  # Start a worker only if one isn't already running.
  (
    flock -n 9 || exit 0

    while [[ -f /tmp/benq-brightness-value ]]; do
      value=$(cat /tmp/benq-brightness-value)
      rm -f /tmp/benq-brightness-value

      ddcutil --display 1 setvcp 10 "$value" --noverify
    done
  ) 9>/tmp/benq-brightness.lock >/tmp/benq-brightness.log 2>&1 &

  ;;

get)
  ddcutil --display 1 getvcp 10 |
    sed -nE 's/.*current value = *([0-9]+),.*/\1/p'
  ;;
esac
