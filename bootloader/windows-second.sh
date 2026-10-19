#!/usr/bin/env bash
# Переносит запись «Windows 11» из 40_custom в /etc/grub.d/29_windows, чтобы она шла сразу после Arch (UKI),
# до «UEFI Firmware Settings». Меняет: /etc/grub.d/{29_windows,40_custom}, /boot/grub/grub.cfg. С бэкапом.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }
WIN_ESP_UUID="${WIN_ESP_UUID:-2211-1D95}"
ts="$(date +%Y%m%d-%H%M%S)"; bak="/var/backups/serpantinum-grub-order-$ts"
mkdir -p "$bak"; cp -a /etc/grub.d/40_custom "$bak/40_custom"; cp /boot/grub/grub.cfg "$bak/grub.cfg"; chmod 600 "$bak/grub.cfg"
echo "бэкап: $bak"

cat > /etc/grub.d/29_windows <<SCRIPT
#!/bin/sh
cat << 'ENTRY'
menuentry "Windows 11" --class windows --class os {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $WIN_ESP_UUID
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
ENTRY
SCRIPT
chmod 755 /etc/grub.d/29_windows
sed -i '/^menuentry "Windows 11"/,/^}/d' /etc/grub.d/40_custom

new="$(mktemp)"
grub-mkconfig -o "$new"
grub-script-check "$new"
echo "--- порядок ---"
grep -nE "^\s*(uki\b|menuentry|submenu)" "$new" | grep -v menuentry_id_option= | cut -c1-100
u=$(grep -nE '^\s*uki\b' "$new" | head -1 | cut -d: -f1); w=$(grep -n '^menuentry "Windows 11"' "$new" | head -1 | cut -d: -f1)
[ -n "$u" ] && [ -n "$w" ] && [ "$u" -lt "$w" ] || { echo "Проверка порядка не пройдена (uki=$u windows=$w). Откат файлов."; cp "$bak/40_custom" /etc/grub.d/40_custom; rm -f /etc/grub.d/29_windows; exit 1; }
read -r -p "Применить? (YES): " a
[ "$a" = YES ] || { cp "$bak/40_custom" /etc/grub.d/40_custom; rm -f /etc/grub.d/29_windows; echo "Не применено, файлы возвращены."; exit 1; }
cp "$new" /boot/grub/grub.cfg
echo "Готово. Откат: sudo cp $bak/grub.cfg /boot/grub/grub.cfg && sudo cp $bak/40_custom /etc/grub.d/40_custom && sudo rm /etc/grub.d/29_windows"
