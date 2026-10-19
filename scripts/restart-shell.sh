#!/usr/bin/env bash
# Пересобрать и перезапустить оболочку Serpantinum (одна копия).
# Новая копия запускается через Hyprland, чтобы у неё было окружение сеанса (как при входе в систему).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/assemble-shell.sh" >/dev/null || exit 1
pkill -f 'bash .*bin/[s]erpantinum-shell'
pkill -TERM -f '^quickshell -p /home/[^ ]*/.local/share/serpantinum'
for _ in $(seq 30); do pgrep -f '^quickshell -p' >/dev/null || break; sleep 0.2; done
pkill -f '^/usr/bin/bash .*/serpantinum/runtime/quickshell/watchers/kb_wait'
log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/serpantinum/shell.log"; mkdir -p "$(dirname "$log")"
hyprctl dispatch "hl.dsp.exec_cmd(\"$root/scripts/bin/serpantinum-shell > $log 2>&1\")" >/dev/null
sleep 6
echo "копий оболочки: $(pgrep -c -f '^quickshell -p')  (журнал: $log)"
grep -E "ERROR|TypeError|ReferenceError" "$log" | head -20
