#!/usr/bin/env bash
# Диагностика только для чтения.
hyprland --version | head -1
echo "--- configerrors"; hyprctl configerrors 2>&1
echo "--- services"; systemctl is-active sddm NetworkManager bluetooth upower
echo "--- layout"; hyprctl devices -j 2>/dev/null | grep -m1 -o '"active_keymap": *"[^"]*"'
for b in quickshell hyprlock hypridle hyprpaper brightnessctl playerctl wl-copy cliphist; do
  command -v "$b" >/dev/null && echo "ok   $b" || echo "MISS $b"
done
