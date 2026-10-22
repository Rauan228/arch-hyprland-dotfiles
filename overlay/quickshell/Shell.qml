// Serpantinum (проект) — точка входа оболочки.
// Подключает оригинальные компоненты Serpantinum (AGPL-3.0, см. third_party/serpantinum).
// Не включены: Idle (используем hypridle), WidgetLoader/WidgetRedactor, Floating, ScreenshotOverlay
// (вместо него — свой скриншотер snip/ в стиле Lightshot).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "taskmgr"
import "snip"
import "apps"
import "switcher"

ShellRoot {
    id: shellRoot
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    // «Свернуть» из заголовка самой программы (Chrome, Telegram…): Hyprland сообщает событием minimized,
    // а мы убираем окно в скрытый special:minimized (вернуть — кликом в доке или Alt+Tab)
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            // новое окно — открыть там, где программа была в прошлый раз (scripts/bin/serp-geom)
            if (ev.name === "openwindow") { geomTimer.addr = String(ev.data).split(",")[0]; geomTimer.restart(); }
            // скрытый стол свёрнутых окон открылся сам (программа попросила фокус) — сразу закрыть (scripts/bin/serp-win)
            if (ev.name === "activespecial" && String(ev.data).indexOf("special:minimized,") === 0) {
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-win", "special", String(ev.data).split(",")[1]]);
                return;
            }
            if (ev.name !== "minimized" && ev.name !== "minimize") return;
            var p = String(ev.data).split(",");
            if (p.length > 1 && p[1] === "1")   // свернуть как кнопкой «─» в заголовке (scripts/bin/serp-win)
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-win", "min", "0x" + p[0].replace(/^0x/, "")]);
        }
    }

    // Окна не «улетают» за край, развёрнутые окна, запоминание мест — один постоянный процесс
    // scripts/bin/serp-windowd: сам слушает события Hyprland и ходит в него через сокет. Раньше на каждое событие
    // запускалась связка serp-fit → serp-max check → serp-geom save (~100 процессов, ~20 запросов к Hyprland),
    // и при нескольких рабочих столах это давало подтормаживания курсора и анимаций.
    Timer { id: geomTimer; interval: 180; property string addr: ""
            onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-geom", "apply", addr]) }
    Process {
        id: windowd
        command: [Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-windowd"]
        running: true
        onExited: restartWindowd.start()        // упал — перезапустить через 2 с
    }
    Timer { id: restartWindowd; interval: 2000; onTriggered: windowd.running = true }

    WallpaperEngine {}
    Main {}
    Bar {}
    Dock {}
    Launcher {}
    Clipboard {}
    Polkit {}
    PopoutManager {}
    Lock { id: lockScreen }

    // Блокировка при входе (автовход): включается изнутри, когда оболочка полностью загрузилась.
    // SERP_LOCK_ON_START=1 выставляет scripts/bin/serpantinum-shell (при автовходе или после сбоя под блокировкой).
    Timer {
        interval: 2500
        running: Quickshell.env("SERP_LOCK_ON_START") === "1"
        onTriggered: lockScreen.lockStatic()
    }
    TaskManager {}
    Snip {}
    AppLauncher {}
    Switcher {}
}
