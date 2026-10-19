#!/usr/bin/env bash
# Собирает рабочее дерево оболочки: неизменённый upstream + overlay проекта.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dst="${SERPANTINUM_RUNTIME:-$HOME/.local/share/serpantinum/runtime}"
tmp="$dst.new"
rm -rf "$tmp"; mkdir -p "$tmp"
cp -a "$root/third_party/serpantinum/src/." "$tmp/"
rm -f "$tmp/version.txt"; cp "$root/third_party/serpantinum/version.txt" "$tmp/version.txt"
[ -d "$root/overlay/quickshell" ] && cp -a "$root/overlay/quickshell" "$tmp/"
# патчи поверх upstream (по порядку имён)
for p in "$root"/overlay/patches/*.patch; do
  [ -e "$p" ] || continue
  patch -p1 -d "$tmp" --no-backup-if-mismatch < "$p" >/dev/null || { echo "patch failed: $p" >&2; rm -rf "$tmp"; exit 1; }
  echo "applied $(basename "$p")"
done
rm -rf "$dst.old"; [ -d "$dst" ] && mv "$dst" "$dst.old"
mv "$tmp" "$dst"; rm -rf "$dst.old"
echo "assembled -> $dst"
