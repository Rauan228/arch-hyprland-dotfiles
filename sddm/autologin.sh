#!/usr/bin/env bash
# Автовход SDDM в Hyprland (uwsm) для одного пользователя; экран блокировки Serpantinum включается сразу после входа
# (scripts/bin/lock-at-login из автозапуска Hyprland). Запуск: sudo sddm/autologin.sh   Откат: sudo sddm/autologin.sh --off
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo"; exit 1; }
conf=/etc/sddm.conf.d/20-serpantinum-autologin.conf
if [ "${1:-}" = "--off" ]; then rm -f "$conf"; echo "Автовход выключен (снова будет экран входа SDDM)."; exit 0; fi
user="${SUDO_USER:-rauan}"
session="${SESSION:-hyprland-uwsm.desktop}"
[ -f "/usr/share/wayland-sessions/$session" ] || { echo "Нет сессии $session"; exit 1; }
home="$(getent passwd "$user" | cut -d: -f6)"
[ -x "$home/.config/serpantinum/bin/lock-at-login" ] || { echo "Нет $home/.config/serpantinum/bin/lock-at-login — без него сессия не заблокируется. Отмена."; exit 1; }
cat <<PLAN
План: $conf
  [Autologin] User=$user  Session=$session  Relogin=false
После входа сессия сразу блокируется экраном Serpantinum (пароль вводится там).
При выходе из сессии автовход не повторяется — откроется экран входа SDDM (для других пользователей).
Откат: sudo $0 --off
PLAN
read -r -p "Введите YES для продолжения: " a; [ "$a" = YES ] || { echo "Отменено"; exit 1; }
install -d -m 755 /etc/sddm.conf.d
printf '[Autologin]\nUser=%s\nSession=%s\nRelogin=false\n' "$user" "$session" > "$conf"
chmod 644 "$conf"
echo "Готово: $conf"; cat "$conf"
