-- Автозапуск при старте сессии.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("hypridle")
    -- оболочка Serpantinum: панель, док, лаунчер, уведомления, блокировка, обои
    hl.exec_cmd("$HOME/.config/serpantinum/bin/serpantinum-shell --login")
    -- история буфера обмена (запускается, только если пакеты установлены)
    hl.exec_cmd("sh -c 'command -v wl-paste >/dev/null && command -v cliphist >/dev/null && { wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store; }'")
end)
