#!/usr/bin/env bash
# Курсор как в Windows: тема Windows-10 (red-magic/cursor-themes, та же, что в AUR windows-10-cursor),
# ставится в ~/.local/share/icons без sudo и включается для Hyprland, GTK и XWayland.
set -euo pipefail
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -sL -o "$tmp/w.tar.gz" https://github.com/red-magic/cursor-themes/releases/download/2.0/windows-10-cursor.tar.gz
echo "c2145e28061d044ebe0839de7a88bfaa76424409f9632bfee84ece547d652a2da8c377465453a3d97d770efe3f4ebc2c4796b56d429403e893d9bed803a9a742  $tmp/w.tar.gz" | b2sum -c --quiet
mkdir "$tmp/x"; tar -xzf "$tmp/w.tar.gz" -C "$tmp/x"
mkdir -p ~/.local/share/icons ~/.icons/default
rm -rf ~/.local/share/icons/Windows-10; cp -r "$tmp/x/windows-10-cursor/Windows-10" ~/.local/share/icons/
printf '[Icon Theme]\nInherits=Windows-10\n' > ~/.icons/default/index.theme
gsettings set org.gnome.desktop.interface cursor-theme Windows-10
gsettings set org.gnome.desktop.interface cursor-size 24
hyprctl setcursor Windows-10 24 >/dev/null 2>&1 || true
echo "курсор Windows-10 установлен"
