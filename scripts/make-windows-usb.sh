#!/usr/bin/env bash
# Флешка: отформатировать (чтобы её было видно в Dolphin) или записать установщик Windows.
#   sudo scripts/make-windows-usb.sh             — разметить и отформатировать флешку в FAT32 (метка USB)
#   sudo scripts/make-windows-usb.sh WIN.iso     — то же + записать установщик Windows из ISO (загрузка UEFI)
# Берёт ТОЛЬКО съёмный USB-диск (внутренние SSD не трогает); если флешек несколько — спросит, какую.
# ВСЕ данные на флешке стираются — перед этим показывает, что нашёл, и ждёт «да».
# Windows 7: в её ISO нет efi/boot/bootx64.efi — достаём загрузчик из sources/install.wim (нужен 7-Zip).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0 ${1:-}"; exit 1; }
iso="${1:-}"
user="${SUDO_USER:-rauan}"

# --- проверить ISO заранее (до стирания флешки) ---
if [ -n "$iso" ]; then
  [ -f "$iso" ] || { echo "Нет файла: $iso"; exit 1; }
  list=$(bsdtar -tf "$iso" 2>/dev/null || true)
  if ! grep -qiE '^(\./)?sources/install\.(wim|esd)$' <<<"$list" || ! grep -qiE '^(\./)?bootmgr$' <<<"$list"; then
    echo "Это не установщик Windows: внутри нет sources/install.wim (или .esd) и bootmgr."
    echo "Например, Windows-KB913086-*.iso — это сборник обновлений, установить с него Windows нельзя."
    exit 1
  fi
  command -v 7z >/dev/null || { echo "Нужен 7-Zip, чтобы достать загрузчик UEFI: sudo pacman -S --needed 7zip"; exit 1; }
fi

# --- найти флешку ---
mapfile -t usb < <(lsblk -dnpo NAME,TRAN,RM,TYPE | awk '$2 == "usb" && $3 == 1 && $4 == "disk" { print $1 }')
[ ${#usb[@]} -gt 0 ] || { echo "Флешка не найдена (нужен съёмный USB-диск)."; exit 1; }
dev="${usb[0]}"
if [ ${#usb[@]} -gt 1 ]; then
  echo "Найдено несколько флешек:"; for d in "${usb[@]}"; do echo "  $d  $(lsblk -dno SIZE,MODEL "$d")"; done
  read -r -p "Какую стереть? (например ${usb[0]}): " dev
  printf '%s\n' "${usb[@]}" | grep -qx "$dev" || { echo "Это не флешка из списка."; exit 1; }
fi
echo "Флешка: $dev — $(lsblk -dno SIZE,MODEL "$dev" | xargs)"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$dev"
echo
if [ -n "$iso" ]; then echo "Будет: стереть флешку и записать установщик Windows из $(basename "$iso")."
else echo "Будет: стереть флешку и отформатировать в FAT32 (метка USB)."; fi
read -r -p "ВСЕ данные на $dev будут удалены. Продолжить? Напишите «да»: " ok
[ "$ok" = "да" ] || { echo "Отменено."; exit 1; }

# --- разметка: MBR, один раздел FAT32, активный (так грузится и UEFI, и старые BIOS) ---
for p in $(lsblk -lnpo NAME "$dev" | tail -n +2); do umount "$p" 2>/dev/null || true; done
wipefs -a "$dev" >/dev/null
parted -s "$dev" mklabel msdos mkpart primary fat32 1MiB 100% set 1 boot on
partprobe "$dev"; udevadm settle; sleep 1
part=$(lsblk -lnpo NAME "$dev" | sed -n 2p)
[ -n "$part" ] || { echo "Раздел не появился"; exit 1; }
label=USB; [ -n "$iso" ] && label=WINSETUP
mkfs.fat -F 32 -n "$label" "$part" >/dev/null
echo "Раздел $part (FAT32, $label) готов."

if [ -n "$iso" ]; then
  src=$(mktemp -d); dst=$(mktemp -d)
  trap 'umount "$src" "$dst" 2>/dev/null; rmdir "$src" "$dst" 2>/dev/null' EXIT
  mount -o loop,ro "$iso" "$src"
  mount "$part" "$dst"
  # FAT32: файл не больше 4 ГБ
  big=$(find "$src" -type f -size +4095M -printf '%P\n' | head -1)
  [ -z "$big" ] || { echo "Файл $big больше 4 ГБ — на FAT32 не поместится. Нужен образ поменьше или разбивка install.wim."; exit 1; }
  echo "Копирую файлы установщика ($(du -sh "$src" | cut -f1))…"
  cp -r --no-preserve=ownership,mode "$src"/. "$dst"/
  # загрузка UEFI: Windows 7 не кладёт efi/boot/bootx64.efi — берём bootmgfw.efi из install.wim
  if [ ! -e "$dst/efi/boot/bootx64.efi" ] && [ ! -e "$dst/EFI/BOOT/BOOTX64.EFI" ]; then
    wim=$(find "$src/sources" -maxdepth 1 -iname 'install.wim' | head -1)
    if [ -n "$wim" ]; then
      tmp=$(mktemp -d)
      7z e -y -o"$tmp" "$wim" '1/Windows/Boot/EFI/bootmgfw.efi' >/dev/null 2>&1 || true
      if [ -f "$tmp/bootmgfw.efi" ]; then
        mkdir -p "$dst/efi/boot"; cp "$tmp/bootmgfw.efi" "$dst/efi/boot/bootx64.efi"; echo "Добавлен загрузчик UEFI efi/boot/bootx64.efi."
      else
        echo "Не удалось достать bootmgfw.efi из install.wim — загрузка UEFI может не работать (только BIOS/CSM)."
      fi
      rm -rf "$tmp"
    fi
  fi
  echo "Записываю на флешку (sync)…"; sync
fi
echo
echo "Готово: $part — $(lsblk -no SIZE,FSTYPE,LABEL "$part" | xargs). Флешку видно в Dolphin."
[ -n "$iso" ] && echo "Загрузка: при включении ноутбука — меню загрузки (F12 у Gigabyte), выбрать флешку (UEFI)."
