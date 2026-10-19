pragma Singleton
import QtQuick

// Единая дизайн-система Serpantinum: графит + индиго → бирюза.
QtObject {
    readonly property string font: "JetBrainsMono Nerd Font"

    readonly property color bg:        "#0b0d17"
    readonly property color glass:     Qt.rgba(0.07, 0.08, 0.14, 0.58)
    readonly property color glassSoft: Qt.rgba(1, 1, 1, 0.06)
    readonly property color glassHi:   Qt.rgba(1, 1, 1, 0.12)
    readonly property color border:    Qt.rgba(1, 1, 1, 0.12)
    readonly property color text:      "#f0f2ff"
    readonly property color muted:     Qt.rgba(0.94, 0.95, 1, 0.62)
    readonly property color accent:    "#7c6cff"
    readonly property color accent2:   "#2dd4bf"
    readonly property color danger:    "#ff6378"
    readonly property color warn:      "#facc15"

    readonly property int radius: 22
    readonly property int radiusSm: 14
    readonly property int animFast: 140
    readonly property int animMed: 320
    readonly property int animSlow: 700
}
