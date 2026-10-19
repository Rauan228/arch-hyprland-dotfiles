#!/usr/bin/env bash
# startup-toggle.sh <file> <enable:1|0>: включает/отключает пункт автозагрузки через пользовательский override.
f="$1"; en="$2"; b=$(basename "$f"); u="$HOME/.config/autostart/$b"
mkdir -p "$HOME/.config/autostart"
[ -e "$u" ] || cp "$f" "$u"
if grep -qi '^Hidden=' "$u"; then sed -i "s/^Hidden=.*/Hidden=$([ "$en" = 1 ] && echo false || echo true)/I" "$u"
else echo "Hidden=$([ "$en" = 1 ] && echo false || echo true)" >> "$u"; fi
