#!/usr/bin/env bash
# Установка темы входа SDDM «serpantinum». ЗАПУСКАТЬ ТОЛЬКО ПОСЛЕ ПОДТВЕРЖДЕНИЯ: sudo sddm/install.sh
# Меняет: /usr/share/sddm/themes/serpantinum, /etc/sddm.conf.d/10-serpantinum.conf, /usr/share/sddm/faces/<user>.face.icon.
# Не трогает: GRUB, EFI, Windows, учётные записи, PAM.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/build/serpantinum"
[ -f "$src/Main.qml" ] || { echo "Сначала: sddm/build-theme.sh"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }
real_user="${SUDO_USER:-rauan}"; real_home="$(getent passwd "$real_user" | cut -d: -f6)"
avatar="$real_home/.config/serpantinum/avatars/current.png"

cat <<PLAN
План:
  1. Копия темы в /usr/share/sddm/themes/serpantinum
  2. /etc/sddm.conf.d/10-serpantinum.conf  ->  [Theme] Current=serpantinum
  3. Аватар $real_user -> /usr/share/sddm/faces/$real_user.face.icon (если есть $avatar)
Откат: sudo rm /etc/sddm.conf.d/10-serpantinum.conf  (вернётся тема по умолчанию)
Если экран входа не появится: Ctrl+Alt+F3, войти и выполнить указанную выше команду.
PLAN
read -r -p "Введите YES для продолжения: " a; [ "$a" = YES ] || { echo "Отменено"; exit 1; }

install -d -m 755 /usr/share/sddm/themes/serpantinum
rm -rf /usr/share/sddm/themes/serpantinum/*
cp -r "$src/." /usr/share/sddm/themes/serpantinum/
find /usr/share/sddm/themes/serpantinum -type d -exec chmod 755 {} +
find /usr/share/sddm/themes/serpantinum -type f -exec chmod 644 {} +

install -d -m 755 /etc/sddm.conf.d
[ -f /etc/sddm.conf.d/10-serpantinum.conf ] && cp -a /etc/sddm.conf.d/10-serpantinum.conf "/etc/sddm.conf.d/10-serpantinum.conf.bak.$(date +%s)"
printf '[Theme]\nCurrent=serpantinum\n' > /etc/sddm.conf.d/10-serpantinum.conf

if [ -f "$avatar" ]; then
  install -d -m 755 /usr/share/sddm/faces
  install -m 644 "$avatar" "/usr/share/sddm/faces/$real_user.face.icon"
fi
echo "Готово. Тема применится при следующем показе экрана входа (выход из сессии или перезагрузка)."
echo "Проверка без выхода:  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/serpantinum"
