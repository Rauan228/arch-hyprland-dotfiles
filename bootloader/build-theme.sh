#!/usr/bin/env bash
# Тема GRUB «Serpantinum» по референсу: стеклянная панель, логотип, две плитки В РЯД со свечением выбранной.
# Приём: всё статичное запечено в background.png, а «ряд плиток» — это иконка пункта меню размером со весь ряд.
# Видимая высота меню = один пункт, поэтому GRUB всегда показывает ряд для выбранного пункта:
#   arch.png — выбран Arch, windows.png — выбран Windows, serpfallback.png — выбран «Резерв».
# Текст пунктов GRUB вынесен за экран (item_icon_space), шрифт нужен только для обратного отсчёта.
# Ничего не устанавливает. Нужны: imagemagick, librsvg, grub (grub-mkfont). Акцент: ACCENT='#5ed3e5'.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(cd "$here/.." && pwd)"
out="$here/grub-theme/serpantinum"; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ACCENT="${ACCENT:-#5ed3e5}"
W=1920; H=1080
F_L=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Light.ttf
F_R=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf
F_B=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf
rm -rf "$out"; mkdir -p "$out/icons"

# --- геометрия (экран 1920x1080) ---
PX=522; PY=172; PW=876; PH=743; PR=40          # панель
TW=344; TH=288; GAP=52; M=28                    # плитка, промежуток, поле под свечение
RX=$(( (W - (2*TW + GAP)) / 2 - M )); RY=402     # левый верхний угол картинки ряда
RW=$(( 2*TW + GAP + 2*M )); RH=$(( TH + 2*M ))

# --- фон: лес + тень + матовое стекло + блик + рамка + логотип + надписи ---
magick "$root/config/wallpapers/forest-mist.jpg" -resize ${W}x${H}^ -gravity center -extent ${W}x${H} -modulate 72,90,100 -brightness-contrast 0x12 "$tmp/bg.png"
magick -size ${W}x${H} xc:none -fill 'rgba(0,0,0,0.50)' -draw "roundrectangle $PX,$((PY+16)) $((PX+PW)),$((PY+PH+16)) $PR,$PR" -blur 0x34 "$tmp/shadow.png"
magick -size ${W}x${H} xc:black -fill white -draw "roundrectangle $PX,$PY $((PX+PW)),$((PY+PH)) $PR,$PR" "$tmp/mask.png"
magick "$tmp/bg.png" -blur 0x28 -modulate 74,92,100 "$tmp/mask.png" -alpha off -compose CopyOpacity -composite "$tmp/glass.png"
magick -size ${PW}x${PH} xc:none -fill white -draw "roundrectangle 0,0 $((PW-1)),$((PH-1)) $PR,$PR" "$tmp/pmask.png"
magick -size ${PW}x${PH} gradient:'#ffffff26-#ffffff05' "$tmp/pmask.png" -compose DstIn -composite "$tmp/sheen.png"
rsvg-convert -w 64 -h 80 "$here/assets/logo.svg" -o "$tmp/logo.png"
magick "$tmp/bg.png" "$tmp/shadow.png" -compose Over -composite "$tmp/glass.png" -compose Over -composite \
  "$tmp/sheen.png" -geometry +$PX+$PY -compose Over -composite +repage \
  -fill none -stroke 'rgba(255,255,255,0.32)' -strokewidth 2 -draw "roundrectangle $PX,$PY $((PX+PW)),$((PY+PH)) $PR,$PR" \
  "$tmp/logo.png" -geometry +$(( W/2 - 32 ))+212 -compose Over -composite \
  -gravity north -stroke none \
  -font "$F_L" -fill '#eef5f6' -pointsize 34 -kerning 6 -annotate +0+300 'SERPANTINUM' \
  -font "$F_R" -fill '#9fb0b5' -pointsize 13 -kerning 7 -annotate +0+352 'FREEDOM IN BALANCE' \
  -font "$F_R" -fill '#a9b7bb' -pointsize 15 -kerning 0 -annotate +0+848 'Use ↑ ↓ and Enter to select' \
  -depth 8 PNG24:"$out/background.png"

# --- плитка: <selected 0|1> <svg> <ширина иконки> <высота иконки> <название> <подпись> <файл> ---
tile() {
  local sel=$1 svg=$2 iw=$3 ih=$4 name=$5 sub=$6 o=$7
  local cw=$((TW+2*M)) chh=$((TH+2*M)) x0=$M y0=$M x1=$((M+TW-1)) y1=$((M+TH-1)) r=30
  magick -size ${cw}x${chh} xc:none -fill 'rgba(10,14,16,0.52)' -stroke none -draw "roundrectangle $x0,$y0 $x1,$y1 $r,$r" "$tmp/fill.png"
  if [ "$sel" = 1 ]; then
    magick -size ${cw}x${chh} xc:none -fill none -stroke "$ACCENT" -strokewidth 3 -draw "roundrectangle $x0,$y0 $x1,$y1 $r,$r" "$tmp/line.png"
    magick "$tmp/line.png" \( +clone -channel A -blur 0x16 -evaluate multiply 3.4 +channel \) +swap -background none -layers merge +repage "$tmp/glow.png"
    # мягкое внутреннее свечение
    magick -size ${cw}x${chh} xc:none -fill none -stroke "$ACCENT" -strokewidth 14 -draw "roundrectangle $x0,$y0 $x1,$y1 $r,$r" \
      -channel A -blur 0x12 -evaluate multiply 0.55 +channel "$tmp/inner.png"
    magick "$tmp/inner.png" "$tmp/fill.png" -compose dst_in -composite "$tmp/inner2.png"
    magick "$tmp/fill.png" "$tmp/inner2.png" -compose over -composite "$tmp/glow.png" -compose over -composite "$tmp/t.png"
  else
    magick "$tmp/fill.png" \( -size ${cw}x${chh} xc:none -fill none -stroke 'rgba(255,255,255,0.24)' -strokewidth 2 -draw "roundrectangle $x0,$y0 $x1,$y1 $r,$r" \) \
      -compose over -composite "$tmp/t.png"
  fi
  rsvg-convert -w "$iw" -h "$ih" "$svg" -o "$tmp/ic.png"
  local icol='#e9eef1'; [ "$sel" = 1 ] && icol="$ACCENT"
  magick "$tmp/ic.png" -fill "$icol" -colorize 100 "$tmp/ic.png"
  magick "$tmp/t.png" \( "$tmp/ic.png" \) -gravity north -geometry +0+$(( M + 104 - ih/2 )) -composite \
    -font "$F_B" -fill '#ffffff' -pointsize 25 -gravity north -annotate +0+$(( M + 186 )) "$name" \
    -font "$F_R" -fill '#9db0b6' -pointsize 14 -annotate +0+$(( M + 222 )) "$sub" "$o"
}
row() { # row <left.png> <right.png> <out>
  magick -size ${RW}x${RH} xc:none \( "$1" \) -geometry +0+0 -composite \( "$2" \) -geometry +$((TW+GAP))+0 -composite -depth 8 PNG32:"$3"
}
tile 1 "$here/assets/tux-mono.svg" 84 98 "Arch" "Linux"     "$tmp/arch_on.png"
tile 0 "$here/assets/tux-mono.svg" 84 98 "Arch" "Linux"     "$tmp/arch_off.png"
tile 1 "$here/assets/win-flat.svg" 82 82 "Windows 11" "Microsoft" "$tmp/win_on.png"
tile 0 "$here/assets/win-flat.svg" 82 82 "Windows 11" "Microsoft" "$tmp/win_off.png"
row "$tmp/arch_on.png"  "$tmp/win_off.png" "$out/icons/arch.png"
row "$tmp/arch_off.png" "$tmp/win_on.png"  "$out/icons/windows.png"
# «Резерв» (третий пункт, только если спуститься стрелкой вниз): обе плитки обычные + метка
row "$tmp/arch_off.png" "$tmp/win_off.png" "$tmp/row_off.png"
magick "$tmp/row_off.png" -fill 'rgba(10,14,16,0.85)' -stroke "$ACCENT" -strokewidth 2 \
  -draw "roundrectangle $((RW/2-170)),$((RH/2-24)) $((RW/2+170)),$((RH/2+24)) 24,24" -stroke none \
  -font "$F_R" -fill '#ffffff' -pointsize 17 -gravity center -annotate +0+0 'Резервный запуск Arch (UKI)' -depth 8 PNG32:"$out/icons/serpfallback.png"

# --- шрифт только для обратного отсчёта ---
grub-mkfont -s 20 -r '0x20-0x7e' -o "$out/f_regular_20.pf2" "$F_R" 2>/dev/null

sed -e "s/@RX@/$RX/; s/@RY@/$RY/; s/@RW@/$RW/g; s/@RH@/$RH/g" "$here/theme.txt" > "$out/theme.txt"
echo "theme built: $out ($(du -sh "$out" | cut -f1)); row at ${RX},${RY} size ${RW}x${RH}"
