// Serpantinum: кнопки активного окна «свернуть / развернуть / закрыть» для верхней панели.
// Свернуть = перенос в скрытый special:minimized (вернуть — клик по приложению в доке).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../../"

Item {
    id: root

    property var module: null
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool isVertical: module ? module.orientation === "vertical" : false

    // окно этого монитора: активное, если фокус здесь, иначе последнее сфокусированное на его рабочем столе
    readonly property var mon: barWindow && barWindow.screen ? Hyprland.monitorFor(barWindow.screen) : null
    readonly property var win: {
        let a = Hyprland.activeToplevel;
        if (!mon) return a;
        if (a && a.monitor && a.monitor.name === mon.name) return a;
        let ws = mon.activeWorkspace;
        if (!ws) return null;
        let best = null, bestH = 1e9;
        let list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            if (!t || !t.workspace || t.workspace.id !== ws.id) continue;
            let h = (t.lastIpcObject && t.lastIpcObject.focusHistoryID !== undefined) ? t.lastIpcObject.focusHistoryID : 1e8;
            if (h < bestH) { bestH = h; best = t; }
        }
        return best;
    }
    readonly property var ipc: win ? win.lastIpcObject : null
    readonly property string addr: win && win.address ? (String(win.address).startsWith("0x") ? String(win.address) : "0x" + win.address) : ""
    readonly property bool maximized: !!ipc && ipc.fullscreen !== undefined && ipc.fullscreen !== 0
    readonly property bool isFaceVisible: addr !== ""

    function c(v) { return barWindow ? barWindow.cs(v) : v }
    // действие выполняет serp-win: окно определяется через hyprctl в момент нажатия
    function act(what) {
        let m = barWindow && barWindow.screen ? barWindow.screen.name : "";
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-win", what, m]);
        refreshTimer.restart();
    }
    Timer { id: refreshTimer; interval: 120; onTriggered: Hyprland.refreshToplevels() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "fullscreen") refreshTimer.restart() }
    }

    readonly property real btn: c(30)
    readonly property real targetLength: isFaceVisible ? (row.implicitWidth + c(8)) : 0
    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : btn
    clip: true
    opacity: isFaceVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.c(4)

        WinBtn {
            kind: "min"; tip: "Свернуть"
            onClicked: root.act("min")
        }
        WinBtn {
            kind: root.maximized ? "restore" : "max"; tip: root.maximized ? "Восстановить" : "Развернуть"
            onClicked: root.act("max")
        }
        WinBtn {
            kind: "close"; tip: "Закрыть"; danger: true
            onClicked: root.act("close")
        }
    }

    component WinBtn: Rectangle {
        id: b
        property string kind: "min"
        property string tip: ""
        property bool danger: false
        signal clicked()

        width: root.btn; height: root.btn
        radius: root.c(9)
        color: area.containsMouse ? (danger ? Qt.alpha("#e5484d", area.pressed ? 0.75 : 0.9) : Qt.alpha(ThemeBackend.text, area.pressed ? 0.18 : 0.11)) : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        readonly property color fg: area.containsMouse && danger ? "#ffffff" : ThemeBackend.subtext0
        readonly property real g: root.c(10)   // размер глифа

        // свернуть: линия
        Rectangle {
            visible: b.kind === "min"
            anchors.centerIn: parent
            width: b.g; height: Math.max(1, root.c(1.5)); radius: height / 2
            color: b.fg
        }
        // развернуть: квадрат
        Rectangle {
            visible: b.kind === "max"
            anchors.centerIn: parent
            width: b.g; height: b.g; radius: root.c(2)
            color: "transparent"; border.color: b.fg; border.width: Math.max(1, root.c(1.4))
        }
        // восстановить: два квадрата
        Item {
            visible: b.kind === "restore"
            anchors.centerIn: parent
            width: b.g; height: b.g
            Rectangle {
                x: root.c(2.5); y: 0; width: parent.width - root.c(2.5); height: parent.height - root.c(2.5); radius: root.c(2)
                color: "transparent"; border.color: Qt.alpha(b.fg, 0.7); border.width: Math.max(1, root.c(1.3))
            }
            Rectangle {
                x: 0; y: root.c(2.5); width: parent.width - root.c(2.5); height: parent.height - root.c(2.5); radius: root.c(2)
                color: b.color.a > 0 ? b.color : (root.barWindow ? Qt.alpha(ThemeBackend.base, 1) : "black")
                border.color: b.fg; border.width: Math.max(1, root.c(1.3))
            }
        }
        // закрыть: крест
        Repeater {
            model: b.kind === "close" ? [45, -45] : []
            Rectangle {
                anchors.centerIn: parent
                width: b.g * 1.25; height: Math.max(1, root.c(1.5)); radius: height / 2
                rotation: modelData
                color: b.fg
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }
}
