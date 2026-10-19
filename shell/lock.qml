import QtQuick
import Quickshell
import Quickshell.Wayland
import "lock"

// Экран блокировки Serpantinum (точка входа; корень Quickshell — каталог shell/).
// SERP_LOCK_PREVIEW=1       — обычное окно вместо блокировки (для разработки, ничего не блокирует)
// SERP_LOCK_TEST_SECONDS=N  — автоматически разблокировать через N секунд (тест)
ShellRoot {
    id: shell
    readonly property bool preview: Quickshell.env("SERP_LOCK_PREVIEW") === "1"
    readonly property int testSeconds: parseInt(Quickshell.env("SERP_LOCK_TEST_SECONDS") || "0")

    LockController {
        id: ctl
        onUnlocked: {
            if (!shell.preview) lock.locked = false
            quitTimer.start()
        }
    }

    Timer { id: quitTimer; interval: 250; onTriggered: Qt.quit() }
    Timer { running: shell.testSeconds > 0; interval: shell.testSeconds * 1000; onTriggered: ctl.unlocked() }

    WlSessionLock {
        id: lock
        locked: !shell.preview
        WlSessionLockSurface {
            LockContent {
                anchors.fill: parent
                controller: ctl
                screenName: screen.name
            }
        }
    }

    LazyLoader {
        active: shell.preview
        FloatingWindow {
            implicitWidth: 1600
            implicitHeight: 900
            LockContent {
                anchors.fill: parent
                controller: ctl
                screenName: "eDP-1"
            }
        }
    }
}
