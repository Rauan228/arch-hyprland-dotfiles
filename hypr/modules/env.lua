-- курсор как в Windows (тема Windows-10 в ~/.local/share/icons, ставится scripts/install-cursor.sh)
hl.env("XCURSOR_THEME", "Windows-10")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Electron-программы (Discord, Obsidian, Antigravity…) — нативно через Wayland, а не XWayland:
-- иначе на экране ноутбука с масштабом 1.5 они растягиваются и выглядят пиксельными
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
