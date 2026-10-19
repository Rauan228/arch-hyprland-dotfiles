local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "dolphin"   -- проводник: Dolphin в оформлении Serpantinum (scripts/setup-filemanager.sh)
local serp        = "$HOME/.config/serpantinum/bin/serp"
local menu        = serp .. " toggle launcher" -- меню приложений (оригинальный лаунчер Serpantinum)

-- Приложения
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + C",      hl.dsp.exec_cmd("code"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class serp-info sh -c 'command -v fastfetch >/dev/null && fastfetch; exec $SHELL'"))
hl.bind("CTRL + Tab",           hl.dsp.exec_cmd(serp .. " toggle taskmgr"))

-- Окна
hl.bind(mainMod .. " + L",  hl.dsp.exec_cmd("$HOME/.config/serpantinum/bin/lock"))
hl.bind("ALT + F4",         hl.dsp.window.close())
hl.bind(mainMod .. " + V",  hl.dsp.exec_cmd(serp .. " toggle clipboard"))                 -- журнал буфера обмена (как Win+V)
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P",  hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",  hl.dsp.layout("togglesplit"))

-- Рабочие столы (Win+1…9, Win+Ctrl+←/→ …) — в modules/desktops.lua

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }))

-- Скриншоты (как Lightshot / Windows): выделить область, рисовать, копировать или сохранить
local shot = "$HOME/.config/serpantinum/bin/serp-shot"
hl.bind("Print",                     hl.dsp.exec_cmd(shot .. " area"))
hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd(shot .. " area"))
hl.bind("SHIFT + Print",             hl.dsp.exec_cmd(shot .. " full"))   -- весь экран: в буфер и в ~/Pictures/Screenshots
hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd(shot .. " full"))
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("$HOME/.config/serpantinum/bin/serp-desk next"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_cmd("$HOME/.config/serpantinum/bin/serp-desk prev"))

-- Мышь: перенос / изменение размера
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Громкость / яркость / медиа
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
