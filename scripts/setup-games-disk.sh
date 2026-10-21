#!/usr/bin/env bash
# Раздел для игр на втором SSD (Kingston A2000 1 ТБ, там же Windows) — для библиотеки Steam под Linux.
#
# Порядок:
#   1) В Windows: «Управление дисками» → C: → «Сжать том» — освободить место под игры (неразмеченное).
#   2) В Linux:   sudo scripts/setup-games-disk.sh
#      Скрипт берёт САМЫЙ БОЛЬШОЙ кусок НЕРАЗМЕЧЕННОГО места на этом диске (≥ 50 ГБ) и только его:
#      существующие разделы (Windows C:, загрузчик Windows, восстановление) не трогает. Перед изменениями
#      показывает план и ждёт подтверждения.
#   Что делает: раздел ext4 «Games» → /mnt/games (подключается при загрузке, nofail — если диск недоступен,
#   система всё равно загрузится), папка /mnt/games/SteamLibrary для Steam. Копия /etc/fstab —
#   /var/backups/serpantinum-fstab.<время>.
#   3) В Steam: Настройки → Хранилище → Добавить диск → /mnt/games/SteamLibrary → «Сделать по умолчанию».
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }
user="${SUDO_USER:-rauan}"
MODEL="SA2000M8"            # Kingston A2000 1 ТБ — второй SSD, где Windows
MNT=/mnt/games
LABEL=Games

disk=""
for d in /sys/block/nvme*n1; do
  grep -q "$MODEL" "$d/device/model" 2>/dev/null && disk="/dev/$(basename "$d")"
done
[ -n "$disk" ] || { echo "Не нашёл диск $MODEL"; exit 1; }
if lsblk -no LABEL "$disk" | grep -qx "$LABEL"; then
  echo "Раздел $LABEL на $disk уже есть:"; lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$disk"; exit 0
fi

echo "Диск: $disk ($(cat /sys/block/$(basename "$disk")/device/model | xargs))"
parted -s "$disk" unit GiB print free
# самый большой свободный кусок: строки вида  N:STARTMiB:ENDMiB:SIZEMiB:free;
read -r start end size < <(parted -m -s "$disk" unit MiB print free | awk -F: '$5 ~ /^free/ { gsub("MiB","",$2); gsub("MiB","",$3); gsub("MiB","",$4); print $2, $3, $4 }' | sort -k3 -n | tail -1)
size=${size%.*}
if [ -z "${size:-}" ] || [ "$size" -lt 51200 ]; then
  echo; echo "Нет свободного (неразмеченного) места от 50 ГБ. Сначала сожмите том C: в Windows (шаг 1)."; exit 1
fi
start=${start%.*}; end=${end%.*}
start=$(( (start + 1 + 1) / 2 * 2 ))         # с запасом и выравниванием по 2 МиБ
end=$(( end - 1 ))
echo
echo "План: новый раздел ext4 «$LABEL» ${start}–${end} МиБ (~$(( (end - start) / 1024 )) ГиБ) в свободном месте $disk,"
echo "      подключение в $MNT (fstab, nofail), папка $MNT/SteamLibrary для пользователя $user."
echo "      Существующие разделы не меняются."
read -r -p "Продолжить? Напишите «да»: " ok
[ "$ok" = "да" ] || { echo "Отменено."; exit 1; }

before=$(lsblk -nro NAME "$disk")
parted -s -a optimal "$disk" mkpart "$LABEL" ext4 "${start}MiB" "${end}MiB"
partprobe "$disk"; udevadm settle
part=""
for i in $(seq 20); do
  part=$(comm -13 <(echo "$before" | sort) <(lsblk -nro NAME "$disk" | sort) | head -1)
  [ -n "$part" ] && break; sleep 0.3
done
[ -n "$part" ] || { echo "Новый раздел не появился — проверьте: lsblk $disk"; exit 1; }
part="/dev/$part"
echo "Создан $part"

mkfs.ext4 -F -L "$LABEL" -m 0 "$part"         # -m 0: без резерва под root — диск только для игр
uuid=$(blkid -s UUID -o value "$part")

ts=$(date +%Y%m%d-%H%M%S)
cp -a /etc/fstab "/var/backups/serpantinum-fstab.$ts"
grep -q "$uuid" /etc/fstab || printf '\n# Игры (второй SSD) — scripts/setup-games-disk.sh\nUUID=%s\t%s\text4\tdefaults,noatime,nofail,x-systemd.device-timeout=5s\t0 2\n' "$uuid" "$MNT" >> /etc/fstab
mkdir -p "$MNT"
systemctl daemon-reload
mount "$MNT"
mkdir -p "$MNT/SteamLibrary"
chown "$user:$user" "$MNT" "$MNT/SteamLibrary"

echo
df -h "$MNT"
echo
echo "Готово. В Steam: Настройки → Хранилище → «+» → Добавить диск → $MNT/SteamLibrary → «Сделать по умолчанию»."
echo "Копия старого /etc/fstab: /var/backups/serpantinum-fstab.$ts"
