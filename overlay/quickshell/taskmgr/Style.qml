pragma Singleton
import QtQuick
import Quickshell

// Палитра диспетчера задач: тёмное стекло с бирюзовым акцентом (как меню выбора ОС).
Singleton {
    readonly property string font: "Noto Sans"

    readonly property color glass: Qt.rgba(0.055, 0.075, 0.082, 0.76)
    readonly property color sidebar: Qt.rgba(1, 1, 1, 0.0)
    readonly property color panel: Qt.rgba(1, 1, 1, 0.035)
    readonly property color card: Qt.rgba(1, 1, 1, 0.045)
    readonly property color field: Qt.rgba(1, 1, 1, 0.06)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color line: Qt.rgba(1, 1, 1, 0.07)
    readonly property color border: Qt.rgba(1, 1, 1, 0.10)
    readonly property color menuBg: Qt.rgba(0.075, 0.098, 0.106, 0.97)

    readonly property color text: "#e8eef0"
    readonly property color sub: "#a9b6ba"
    readonly property color dim: "#738388"

    readonly property color accent: "#5ed3e5"
    readonly property color cpu: "#4fc8dc"
    readonly property color mem: "#b783f0"
    readonly property color disk: "#6cc76c"
    readonly property color net: "#4c9cf0"
    readonly property color gpu: "#45cfc4"
    readonly property color leaf: "#7fd47f"
    readonly property color danger: "#e5484d"
    readonly property color heat: "#3f93ad"

    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }
}
