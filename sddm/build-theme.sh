#!/usr/bin/env bash
# Собирает тему SDDM «serpantinum» в sddm/build/serpantinum/ (ничего не устанавливает).
# Нужны: imagemagick, jq. Цвета берутся из палитры matugen (если файл есть), иначе из значений по умолчанию.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(cd "$here/.." && pwd)"
out="$here/build/serpantinum"
wall="${WALLPAPER:-$root/config/wallpapers/forest-mist.jpg}"
pal="${PALETTE:-$HOME/.local/state/serpantinum/qs_matugen_colors.json}"
rm -rf "$out"; mkdir -p "$out"
cp "$here/serpantinum/Main.qml" "$here/serpantinum/metadata.desktop" "$out/"

wj="${WEATHER_JSON:-$HOME/.cache/serpantinum/weather/weather.json}"
LAT="$(jq -r '.latitude // empty' "$wj" 2>/dev/null || true)"; LON="$(jq -r '.longitude // empty' "$wj" 2>/dev/null || true)"
c() { jq -r --arg k "$1" --arg d "$2" '.[$k] // $d' "$pal" 2>/dev/null || echo "$2"; }
[ -f "$pal" ] || pal=/dev/null
sed -e "s|@BASE@|$(c base '#0d0f08')|" -e "s|@TEXT@|$(c text '#e4e3d7')|" -e "s|@SUBTEXT@|$(c subtext0 '#c7c8b8')|" \
    -e "s|@ACCENT@|$(c blue '#bdce80')|" -e "s|@ACCENT2@|$(c peach '#a1d0c5')|" \
    -e "s|@LAT@|$LAT|" -e "s|@LON@|$LON|" "$here/serpantinum/theme.conf.in" > "$out/theme.conf"

magick "$wall" -resize 1920x1080^ -gravity center -extent 1920x1080 -modulate 82,92,100 -quality 90 "$out/bg.jpg"
magick "$wall" -resize 1920x1080^ -gravity center -extent 1920x1080 -blur 0x22 -modulate 88,95,100 -quality 90 "$out/bg-blur.jpg"
echo "sddm theme built: $out ($(du -sh "$out" | cut -f1))"; cat "$out/theme.conf"
