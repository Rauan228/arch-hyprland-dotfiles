-- (правило suppress_event = "maximize" убрано: из-за него не работали кнопки «развернуть» в самих программах)

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class = "^$", title = "^$",
        xwayland = true, float = true, fullscreen = false, pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Диспетчер задач Serpantinum (окно Quickshell): плавающее, по центру
hl.window_rule({
    name  = "serp-taskmgr",
    match = { title = "^Диспетчер задач$" },
    float = true,
    size  = "monitor_w*0.8 monitor_h*0.84",
    center = true,
})

-- Диспетчер файлов Serpantinum (Win+E)
hl.window_rule({
    name  = "serp-files",
    match = { title = "^Диспетчер файлов$" },
    float = true,
    size  = "monitor_w*0.84 monitor_h*0.9",
    center = true,
})

-- Терминал Ctrl+Shift+Esc
hl.window_rule({
    name  = "serp-info-terminal",
    match = { class = "^serp-info$" },
    float = true,
    size  = "900 560",
    center = true,
})

-- Меню приложений Serpantinum (Win+D): стеклянная панель с размытием фона
hl.layer_rule({
    name  = "serp-apps-blur",
    match = { namespace = "^serp-apps$" },
    blur  = true,
    ignore_alpha = 0.05,
})

-- Alt+Tab / Win+Tab / подсказка рабочего стола: стекло с размытием
hl.layer_rule({
    name  = "serp-switcher-blur",
    match = { namespace = "^serp-switcher$" },
    blur  = true,
    ignore_alpha = 0.05,
})
