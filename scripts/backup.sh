#!/usr/bin/env bash
# Копирует текущие пользовательские конфиги в бэкап. Ничего не меняет в системе.
set -euo pipefail
ts="${1:-$(date +%Y%m%d-%H%M%S)}"
dest="$HOME/.local/share/serpantinum/backups/$ts"
mkdir -p "$dest"
for p in .config/hypr .config/kitty .config/mimeapps.list .config/quickshell; do
  [ -e "$HOME/$p" ] && { mkdir -p "$dest/$(dirname "$p")"; cp -a "$HOME/$p" "$dest/$p"; echo "saved $p"; }
done
echo "$dest"
