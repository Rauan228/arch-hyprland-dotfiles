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
            if (fitEvents.indexOf(ev.name) >= 0) fitTimer.restart();
            // новое окно — открыть там, где программа была в прошлый раз (scripts/bin/serp-geom)
            if (ev.name === "openwindow") { geomTimer.addr = String(ev.data).split(",")[0]; geomTimer.restart(); }
            if (ev.name !== "minimized" && ev.name !== "minimize") return;
            var p = String(ev.data).split(",");
            if (p.length > 1 && p[1] === "1")   // свернуть как кнопкой «─» в заголовке (scripts/bin/serp-win)
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-win", "min", "0x" + p[0].replace(/^0x/, "")]);
        }
    }

    // Окна не должны «улетать» за край: после событий окон (и раз в 4 с) serp-fit возвращает плавающие окна
    // в пределы монитора — уменьшает слишком большие и опускает те, у которых заголовок ушёл за верхний край.
    // Запуски не накладываются: пока идёт один, следующий только откладывается (раньше копии копились и
    // засыпали Hyprland запросами — отсюда подвисания и задержка ввода). Смена фокуса окна сюда не входит.
    readonly property var fitEvents: ["openwindow", "movewindowv2", "changefloatingmode", "monitoradded", "monitorremoved", "fullscreen"]
    readonly property string fitCmd: Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-fit"
    Timer { id: geomTimer; interval: 180; property string addr: ""
            onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-geom", "apply", addr]) }
    Process {
        id: fitProc
        property bool again: false
        command: [shellRoot.fitCmd]
        onExited: if (again) { again = false; running = true; }
    }
    function runFit() { if (fitProc.running) fitProc.again = true; else fitProc.running = true; }
    Timer { id: fitTimer; interval: 350; onTriggered: shellRoot.runFit() }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: shellRoot.runFit() }
    // «развёрнутые» окна (scripts/bin/serp-max): потянули за заголовок — сразу прежний размер, как в Windows.
    // Следит один постоянный процесс без порождения hyprctl/jq (scripts/bin/serp-maxwatch).
    Process {
        id: maxWatch
        command: [Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-maxwatch"]
        running: true
        onExited: restartWatch.start()          // упал — перезапустить через 2 с
    }
    Timer { id: restartWatch; interval: 2000; onTriggered: maxWatch.running = true }

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
