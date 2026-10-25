#!/usr/bin/env bash

service=veila-idle.service

if systemctl --user is-active --quiet "$service"; then
  systemctl --user stop "$service"
  notify-send "Idle Inhibitor" "تم تعطيل مراقبة الخمول"
else
  systemctl --user start "$service"
  notify-send "Idle Inhibitor" "تم تفعيل مراقبة الخمول"
fi
