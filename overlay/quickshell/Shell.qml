// Serpantinum (проект) — точка входа оболочки.
// Подключает оригинальные компоненты Serpantinum (AGPL-3.0, см. third_party/serpantinum).
// Не включены: Idle (используем hypridle), WidgetLoader/WidgetRedactor, Floating, ScreenshotOverlay
// (вместо него — свой скриншотер snip/ в стиле Lightshot).
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
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
            if (p.length > 1 && p[1] === "1")
                Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", window = "address:0x' + p[0].replace(/^0x/, "") + '", silent = true })');
        }
    }

    // Окна не должны «улетать» за край: после событий окон (и раз в 4 с) serp-fit возвращает плавающие окна
    // в пределы монитора — уменьшает слишком большие и опускает те, у которых заголовок ушёл за верхний край
    readonly property var fitEvents: ["openwindow", "movewindowv2", "changefloatingmode", "activewindowv2", "monitoradded", "monitorremoved", "fullscreen"]
    readonly property string fitCmd: Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-fit"
    Timer { id: geomTimer; interval: 180; property string addr: ""
            onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-geom", "apply", addr]) }
    Timer { id: fitTimer; interval: 350; onTriggered: Quickshell.execDetached([shellRoot.fitCmd]) }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: Quickshell.execDetached([shellRoot.fitCmd]) }
    // пока есть «развёрнутые» окна (scripts/bin/serp-max) — проверяем часто, чтобы потянутое за заголовок
    // развёрнутое окно сразу вернулось к прежнему размеру, как в Windows
    FolderListModel {
        id: maxedDir
        folder: "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/serpantinum/maxed"
        showDirs: false; showHidden: false
    }
    Timer { interval: 250; running: maxedDir.count > 0; repeat: true; onTriggered: Quickshell.execDetached([shellRoot.fitCmd]) }

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
