#!/usr/bin/env bash
# Разворачивает проект в ~/.config через symlink'и. Перед этим делает бэкап.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/backup.sh" >/dev/null
link() { # link <src> <dst>
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && [ ! -L "$2" ]; then mv "$2" "$2.pre-serpantinum"; fi
  ln -sfn "$1" "$2"; echo "linked $2 -> $1"
}
link "$root/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
link "$root/hypr/modules"      "$HOME/.config/hypr/modules"

# --- экран блокировки ---
link "$root/lock/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
link "$root/lock/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
link "$root/lock"               "$HOME/.config/serpantinum/lock"
# аватар: ~/.face, иначе стандартный (личные аватары в git не попадают)
av="$HOME/.config/serpantinum/avatars"; mkdir -p "$av"
if [ -f "$HOME/.face" ]; then ln -sfn "$HOME/.face" "$av/current.png"
elif [ ! -e "$av/current.png" ]; then rsvg-convert -w 256 -h 256 "$root/lock/default-avatar.svg" -o "$av/$USER.png"; ln -sfn "$av/$USER.png" "$av/current.png"; fi
link "$root/shell"              "$HOME/.config/serpantinum/shell"
link "$root/scripts/bin"        "$HOME/.config/serpantinum/bin"
