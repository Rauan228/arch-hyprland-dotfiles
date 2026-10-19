#!/usr/bin/env bash
# Пересоздание grub.cfg с сохранением названия «Serpantinum (Arch Linux)» (после обновления ядра/GRUB).
# Использовать вместо голого grub-mkconfig: sudo bootloader/update-grub.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo"; exit 1; }
new="$(mktemp)"
grub-mkconfig -o "$new"
sed -i "s/^menuentry 'Serpantinum Linux'/menuentry 'Serpantinum (Arch Linux)'/" "$new"
grub-script-check "$new"
cp /boot/grub/grub.cfg "/var/backups/grub.cfg.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
cp "$new" /boot/grub/grub.cfg
grep -E "^\s*(menuentry|submenu)" /boot/grub/grub.cfg | cut -c1-90
