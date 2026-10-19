#!/usr/bin/env bash
# Оформление GRUB: тема + собственные записи «Arch» (UKI с ESP) и «Резерв» (штатная команда uki), порядок:
# Arch, Windows 11, Резерв (третий ряд ниже видимой области). Пункт «UEFI Firmware Settings» скрыт.
# Меняет: /boot/grub/themes/serpantinum, /etc/grub.d/{16_serpantinum,35_serpantinum_fallback} (новые),
#         права 15_uki и 30_uefi-firmware (chmod -x), /boot/grub/grub.cfg. С бэкапом.
# Не делает: grub-install, efibootmgr, BootOrder, разметка, ESP Windows. Запуск: sudo bootloader/apply-style.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }
[ -f "$here/grub-theme/serpantinum/theme.txt" ] || { echo "Сначала: bootloader/build-theme.sh"; exit 1; }

echo "=== UKI на ESP ==="
ls -la /boot/EFI/Linux/ 2>&1 || true
ls /boot/EFI/Linux/*.efi >/dev/null 2>&1 || { echo "Нет файлов /boot/EFI/Linux/*.efi — собственная запись Arch не подойдёт. Отмена."; exit 1; }
echo "Будет выбран (без 'fallback' в имени, иначе первый по алфавиту):"
ls /boot/EFI/Linux/*.efi | grep -v fallback | head -1 || ls /boot/EFI/Linux/*.efi | head -1

read -r -p "Продолжить? (YES): " a0; [ "$a0" = YES ] || { echo "Отменено"; exit 1; }

bak="/var/backups/serpantinum-style2-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$bak"
cp /boot/grub/grub.cfg "$bak/grub.cfg"; chmod 600 "$bak/grub.cfg"
cp -r --no-preserve=ownership /boot/grub/themes/serpantinum "$bak/theme" 2>/dev/null || true
ls -l /etc/grub.d > "$bak/grub.d.listing"
echo "бэкап: $bak"

rm -rf /boot/grub/themes/serpantinum
cp -r --no-preserve=mode,ownership,timestamps "$here/grub-theme/serpantinum" /boot/grub/themes/serpantinum

install -m 755 "$here/grub.d/16_serpantinum" /etc/grub.d/16_serpantinum
install -m 755 "$here/grub.d/35_serpantinum_fallback" /etc/grub.d/35_serpantinum_fallback
chmod -x /etc/grub.d/15_uki
[ -x /etc/grub.d/30_uefi-firmware ] && chmod -x /etc/grub.d/30_uefi-firmware || true

new="$(mktemp)"
grub-mkconfig -o "$new"
grub-script-check "$new"
echo "--- пункты меню ---"
grep -nE "^\s*(uki\b|menuentry|submenu)" "$new" | grep -v menuentry_id_option= | cut -c1-110
grep -q 'serpantinum-arch' "$new" || { echo "Нет записи serpantinum-arch в новом grub.cfg. Отмена (grub.cfg не заменён)."; exit 1; }
read -r -p "Применить новый grub.cfg? (YES): " a
[ "$a" = YES ] || { echo "grub.cfg не заменён. Бэкап: $bak"; exit 1; }
cp "$new" /boot/grub/grub.cfg
cat <<DONE
Готово.
Откат:  sudo cp $bak/grub.cfg /boot/grub/grub.cfg
        sudo chmod +x /etc/grub.d/15_uki
        sudo rm /etc/grub.d/16_serpantinum /etc/grub.d/35_serpantinum_fallback
Если «Arch» не загрузится, выберите нижний пункт «Резерв» или F12/Esc при включении.
DONE
