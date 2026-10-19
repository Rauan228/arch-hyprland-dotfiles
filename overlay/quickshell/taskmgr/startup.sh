#!/usr/bin/env bash
# Список автозагрузки XDG: name<TAB>exec<TAB>enabled(1/0)<TAB>file<TAB>origin(user|system)
declare -A seen
for dir in "$HOME/.config/autostart" /etc/xdg/autostart; do
  [ -d "$dir" ] || continue
  origin=system; [ "$dir" = "$HOME/.config/autostart" ] && origin=user
  for f in "$dir"/*.desktop; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); [ -n "${seen[$b]}" ] && continue; seen[$b]=1
    name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-); exec_=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
    hidden=$(grep -m1 -i '^Hidden=' "$f" | cut -d= -f2-); od=$(grep -m1 '^OnlyShowIn=' "$f" | cut -d= -f2-)
    en=1; [ "${hidden,,}" = "true" ] && en=0
    printf '%s\t%s\t%s\t%s\t%s\n' "${name:-$b}" "$exec_" "$en" "$f" "$origin"
  done
done
