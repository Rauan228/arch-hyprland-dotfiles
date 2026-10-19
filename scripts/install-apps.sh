#!/usr/bin/env bash
# Установка программ: Telegram, WhatsApp (ZapZap), Steam, Spotify, Discord, Antigravity, Obsidian.
# Запускать ОТ ПОЛЬЗОВАТЕЛЯ (не через sudo): пароль sudo спросят сами pacman и yay.
#
# Что меняется в системе:
#   - /etc/pacman.conf: включается репозиторий [multilib] (32-битные библиотеки, нужен для Steam).
#     Копия старого файла: /var/backups/serpantinum-pacman.conf.<время>
#   - pacman -Syu: синхронизация баз и обновление системы (частичные обновления в Arch запрещены).
#   - Steam: 32-битные драйверы lib32-nvidia-utils (RTX 4060) и lib32-vulkan-intel (Iris Xe).
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "запустите без sudo: yay нельзя запускать от root" >&2; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  echo "==> включаю [multilib] (копия: /var/backups/serpantinum-pacman.conf.$ts)"
  sudo cp -a /etc/pacman.conf "/var/backups/serpantinum-pacman.conf.$ts"
  # раскомментировать строки «#[multilib]» и следующую за ней «#Include = /etc/pacman.d/mirrorlist»
  sudo sed -i '/^#\[multilib\]$/{s/^#//;n;s/^#Include/Include/}' /etc/pacman.conf
  grep -A1 '^\[multilib\]' /etc/pacman.conf
fi

echo "==> официальные пакеты"
sudo pacman -Syu --needed \
  telegram-desktop discord obsidian spotify-launcher \
  steam lib32-nvidia-utils lib32-vulkan-intel \
  7zip zip unzip \
  easyeffects lsp-plugins-lv2 calf

echo "==> AUR: WhatsApp (ZapZap) и Google Antigravity"
yay -S --needed zapzap antigravity

echo "готово. Spotify при первом запуске сам скачает клиент (spotify-launcher)."
