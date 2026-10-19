#!/usr/bin/env bash
# Установка темы GRUB «Serpantinum» и записи «Windows 11». ЗАПУСКАТЬ ТОЛЬКО ПОСЛЕ ПОДТВЕРЖДЕНИЯ.
# Что НЕ делает: grub-install, efibootmgr, BootOrder, разметка, файлы на ESP Windows.
# Меняет: /boot/grub/themes/serpantinum, /etc/default/grub, /etc/grub.d/40_custom, /boot/grub/grub.cfg.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
theme_src="$here/grub-theme/serpantinum"
WIN_ESP_UUID="${WIN_ESP_UUID:-2211-1D95}"
ts="$(date +%Y%m%d-%H%M%S)"
bak="/var/backups/serpantinum-grub-$ts"

[ -d "$theme_src" ] || { echo "Сначала: bootloader/build-theme.sh"; exit 1; }
lsblk -o UUID | grep -qx "$WIN_ESP_UUID" || { echo "ESP Windows с UUID $WIN_ESP_UUID не найден"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }

cat <<PLAN
План:
  1. Бэкап в $bak: /etc/default/grub, /etc/grub.d/40_custom, /boot/grub/grub.cfg
  2. Копирование темы в /boot/grub/themes/serpantinum
  3. /etc/default/grub: GRUB_THEME, GRUB_GFXMODE=1920x1080,auto, GRUB_DISTRIBUTOR="Serpantinum", GRUB_DISABLE_OS_PROBER=true
  4. /etc/grub.d/40_custom: запись «Windows 11» (chainloader на ESP $WIN_ESP_UUID)
  5. grub-mkconfig во временный файл -> grub-script-check -> замена /boot/grub/grub.cfg
PLAN
read -r -p "Введите YES для продолжения: " a; [ "$a" = YES ] || { echo "Отменено"; exit 1; }

mkdir -p "$bak"
cp -a /etc/default/grub "$bak/default-grub"
cp -a /etc/grub.d/40_custom "$bak/40_custom"
cp -a /boot/grub/grub.cfg "$bak/grub.cfg"
echo "бэкап: $bak"

rm -rf /boot/grub/themes/serpantinum
mkdir -p /boot/grub/themes
cp -r --no-preserve=mode,ownership,timestamps "$theme_src" /boot/grub/themes/serpantinum   # ESP — FAT: владельца сохранить нельзя

setkv() { # setkv KEY VALUE (значение берётся в двойные кавычки)
  if grep -qE "^#?\s*$1=" /etc/default/grub; then sed -i -E "s|^#?\s*$1=.*|$1=\"$2\"|" /etc/default/grub
  else echo "$1=\"$2\"" >> /etc/default/grub; fi
}
setkv GRUB_THEME "/boot/grub/themes/serpantinum/theme.txt"
setkv GRUB_GFXMODE "1920x1080,auto"
setkv GRUB_DISTRIBUTOR "Serpantinum"
setkv GRUB_DISABLE_OS_PROBER "true"
setkv GRUB_TERMINAL_OUTPUT "gfxterm"

if ! grep -q 'Windows 11' /etc/grub.d/40_custom; then
cat >> /etc/grub.d/40_custom <<ENTRY

menuentry "Windows 11" --class windows --class os {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $WIN_ESP_UUID
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
ENTRY
fi

new="$(mktemp)"
grub-mkconfig -o "$new"
# 10_linux называет пункт "<DISTRIBUTOR> Linux"; переименовываем только заголовок главного пункта
sed -i "s/^menuentry 'Serpantinum Linux'/menuentry 'Serpantinum (Arch Linux)'/" "$new"
grub-script-check "$new"
grep -c '^menuentry' "$new" | xargs echo "пунктов меню верхнего уровня:"
grep -E "^\s*(menuentry|submenu)" "$new" | cut -c1-90
read -r -p "Применить новый grub.cfg? (YES): " b; [ "$b" = YES ] || { echo "grub.cfg не заменён. Бэкап: $bak"; exit 1; }
cp "$new" /boot/grub/grub.cfg
echo "Готово. Откат: sudo $here/rollback.sh $bak"
