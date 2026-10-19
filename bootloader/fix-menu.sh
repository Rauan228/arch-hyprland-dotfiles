#!/usr/bin/env bash
# Убирает лишние пункты «EFI BootNext: ...» (дубли Windows, USB, DVD, сеть) из меню GRUB.
# Меняет: /etc/default/grub (GRUB_DISABLE_BOOTNEXT=true) и /boot/grub/grub.cfg. С бэкапом.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }
ts="$(date +%Y%m%d-%H%M%S)"; bak="/var/backups/serpantinum-grub-fix-$ts"
mkdir -p "$bak"; cp -a /etc/default/grub "$bak/default-grub"; cp /boot/grub/grub.cfg "$bak/grub.cfg"; chmod 600 "$bak/grub.cfg"
echo "бэкап: $bak"
if grep -qE '^#?\s*GRUB_DISABLE_BOOTNEXT=' /etc/default/grub; then
  sed -i -E 's|^#?\s*GRUB_DISABLE_BOOTNEXT=.*|GRUB_DISABLE_BOOTNEXT="true"|' /etc/default/grub
else echo 'GRUB_DISABLE_BOOTNEXT="true"' >> /etc/default/grub; fi
new="$(mktemp)"
grub-mkconfig -o "$new"
grub-script-check "$new"
echo "--- пункты меню (включая вложенные в условия) ---"
grep -nE "^\s*(menuentry|submenu)" "$new" | cut -c1-110
echo "--- генерация UKI-пунктов (команда uki) ---"
grep -nE "^\s*uki\b" "$new" || echo "ВНИМАНИЕ: команды uki в новом grub.cfg нет!"
grep -qE "^\s*uki\b" "$new" || { echo "Прерываю: без uki Serpantinum не загрузится. grub.cfg не заменён."; exit 1; }
read -r -p "Применить? (YES): " a; [ "$a" = YES ] || { echo "Не применено. Бэкап: $bak"; exit 1; }
cp "$new" /boot/grub/grub.cfg
echo "Готово. Откат: sudo cp $bak/grub.cfg /boot/grub/grub.cfg && sudo cp $bak/default-grub /etc/default/grub"
