#!/usr/bin/env bash
# Собрать плагин hyprbars (заголовки окон с кнопками — □ ✕) под установленную версию Hyprland
# с доработкой Serpantinum (hypr/plugins/hyprbars-serpantinum.patch).
# Нужно запускать после каждого обновления Hyprland (иначе Hyprland откажется грузить старый плагин).
# Без hyprpm: берётся коммит hyprland-plugins, сопоставленный коммиту Hyprland в hyprpm.toml.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/build/hyprland-plugins"
dst="$HOME/.local/share/serpantinum/plugins"
[ -d "$src" ] || git clone -q https://github.com/hyprwm/hyprland-plugins "$src"
git -C "$src" fetch -q origin
git -C "$src" checkout -q origin/main -- hyprpm.toml 2>/dev/null || true
hl=$(hyprctl version -j | jq -r .commit)
pin=$(grep -oE "\[\"$hl\", *\"[0-9a-f]+\"\]" "$src/hyprpm.toml" | grep -oE '[0-9a-f]{40}' | tail -1 || true)
[ -n "$pin" ] || { echo "нет сопоставления для Hyprland $hl в hyprpm.toml — обновите hyprland-plugins позже" >&2; exit 1; }
git -C "$src" checkout -q -- hyprbars 2>/dev/null || true
git -C "$src" checkout -q "$pin"
# доработка Serpantinum: кнопки в стиле Windows (button_style) и прилипание окон (snap_command)
git -C "$src" apply "$root/hypr/plugins/hyprbars-serpantinum.patch"
make -s -C "$src/hyprbars" all >/dev/null 2>&1
mkdir -p "$dst"
cp "$src/hyprbars/hyprbars.so" "$dst/hyprbars.so.new" && mv "$dst/hyprbars.so.new" "$dst/hyprbars.so"
echo "hyprbars собран для Hyprland ${hl:0:8} (плагины ${pin:0:8}) → $dst/hyprbars.so"
