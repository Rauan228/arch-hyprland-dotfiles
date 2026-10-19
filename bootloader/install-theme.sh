#!/usr/bin/env bash
# Обновляет тему GRUB на ESP и пересоздаёт grub.cfg (чтобы список loadfont совпадал с файлами темы).
# Записи меню обновляются из bootloader/grub.d (горячие клавиши A/W). Запуск: sudo bootloader/install-theme.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo"; exit 1; }
[ -f "$here/grub-theme/serpantinum/theme.txt" ] || { echo "Сначала: bootloader/build-theme.sh"; exit 1; }
bak="/var/backups/serpantinum-theme-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$bak"
cp /boot/grub/grub.cfg "$bak/grub.cfg"; chmod 600 "$bak/grub.cfg"
cp -r --no-preserve=ownership /boot/grub/themes/serpantinum "$bak/theme" 2>/dev/null || true
rm -rf /boot/grub/themes/serpantinum
cp -r --no-preserve=mode,ownership,timestamps "$here/grub-theme/serpantinum" /boot/grub/themes/serpantinum
# записи меню из проекта (Arch, Windows 11, Резерв) — с горячими клавишами A и W
cp -a /etc/grub.d/16_serpantinum /etc/grub.d/29_windows /etc/grub.d/35_serpantinum_fallback "$bak/" 2>/dev/null || true
for f in 16_serpantinum 29_windows 35_serpantinum_fallback; do install -m 755 "$here/grub.d/$f" "/etc/grub.d/$f"; done
new="$(mktemp)"
grub-mkconfig -o "$new"
grub-script-check "$new"
grep -q 'serpantinum-arch' "$new" || { echo "Нет записи Arch в новом grub.cfg — не применяю. Бэкап: $bak"; exit 1; }
grep -nE "^\s*(menuentry|submenu)|loadfont" "$new" | grep -v menuentry_id_option= | cut -c1-110
cp "$new" /boot/grub/grub.cfg
echo "Готово. Откат: sudo cp $bak/grub.cfg /boot/grub/grub.cfg && sudo rm -rf /boot/grub/themes/serpantinum && sudo cp -r $bak/theme /boot/grub/themes/serpantinum"
