#!/usr/bin/env bash
# Диагностика GRUB-темы. Только чтение, ничего не меняет. Запуск: sudo bootloader/diagnose.sh
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo"; exit 1; }
echo "=== ESP (/boot): структура ==="; find /boot -maxdepth 3 -not -path '/boot/grub/themes/*' 2>/dev/null | sort | head -60
echo; echo "=== шрифты GRUB ==="; ls -la /boot/grub/fonts 2>&1 | head
echo; echo "=== тема на ESP ==="; ls /boot/grub/themes/serpantinum 2>&1 | head -40; du -sh /boot/grub/themes/serpantinum 2>&1
echo; echo "=== grub.cfg: графика/тема/префикс ==="
grep -nE "gfxterm|gfxmode|gfxpayload|insmod (all_video|gfxterm|gfxmenu|png|jpeg|video|efi_gop|efi_uga)|loadfont|terminal_output|terminal_input|theme|set root|set prefix|search |^\s*uki|menuentry '|menuentry \"|timeout" /boot/grub/grub.cfg | cut -c1-150
echo; echo "=== прошивка: какой загрузчик у записей ==="; efibootmgr -v 2>/dev/null | grep -E "Boot(0000|0003|Current|Order)" | cut -c1-180
echo; echo "=== EFI-бинарники GRUB ==="; find /boot/EFI -iname '*.efi' 2>/dev/null
echo; echo "=== конфиги grub на ESP ==="; find /boot -iname 'grub.cfg' 2>/dev/null
