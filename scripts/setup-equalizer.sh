#!/usr/bin/env bash
# Эквалайзер и вкладка «Аудио» в окне музыки работают через EasyEffects.
# Сначала (с паролем):  sudo pacman -S --needed easyeffects lsp-plugins-lv2 calf
#   easyeffects      — обработка звука (PipeWire)
#   lsp-plugins-lv2  — эквалайзер, компрессор и лимитер («Динамика»)
#   calf             — моно и перестановка каналов
# Потом этот скрипт (без sudo): EasyEffects в фоне при входе + применить текущие настройки эквалайзера.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
for p in easyeffects lsp-plugins-lv2 calf; do
  pacman -Q "$p" >/dev/null 2>&1 || { echo "нет пакета $p — сначала: sudo pacman -S --needed easyeffects lsp-plugins-lv2 calf" >&2; exit 1; }
done
mkdir -p "$HOME/.config/systemd/user"
ln -sfn "$root/config/systemd/ee-eq.service" "$HOME/.config/systemd/user/ee-eq.service"
systemctl --user daemon-reload
# настройки эквалайзера из окна музыки → пресет live_eq, затем служба
eq="$HOME/.local/share/serpantinum/runtime/quickshell/media/equalizer.sh"
[ -x "$eq" ] || eq="$root/third_party/serpantinum/src/quickshell/media/equalizer.sh"
bash "$eq" get >/dev/null
systemctl --user enable --now ee-eq.service
sleep 2
bash "$eq" apply
systemctl --user --no-pager --lines=0 status ee-eq.service | head -3
echo "готово: эквалайзер работает (EasyEffects в фоне, пресет live_eq)"
