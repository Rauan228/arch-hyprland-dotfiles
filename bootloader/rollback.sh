#!/usr/bin/env bash
# Откат: sudo bootloader/rollback.sh /var/backups/serpantinum-grub-<ts>
set -euo pipefail
bak="${1:?укажите каталог бэкапа}"
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo"; exit 1; }
cp -a "$bak/default-grub" /etc/default/grub
cp -a "$bak/40_custom" /etc/grub.d/40_custom
cp "$bak/grub.cfg" /boot/grub/grub.cfg
rm -rf /boot/grub/themes/serpantinum
echo "Откат выполнен: возвращены /etc/default/grub, 40_custom, grub.cfg"
