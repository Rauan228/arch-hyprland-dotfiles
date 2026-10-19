import QtQuick
import "../theme"

// Плитка со шкалой, заполняющейся снизу (как в референсе).
GlassCard {
    id: tile
    property string label
    property string valueText
    property real fraction: 0   // 0..1
    property color fill: Theme.accent
    clip: true

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.max(3, tile.height * Math.min(1, tile.fraction))
        radius: Theme.radiusSm
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(tile.fill.r, tile.fill.g, tile.fill.b, 0.55) }
            GradientStop { position: 1; color: Qt.rgba(tile.fill.r, tile.fill.g, tile.fill.b, 0.20) }
        }
        Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
    }
    Text {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        text: tile.label
        color: Theme.muted
        font { family: Theme.font; pixelSize: 12 }
    }
    Text {
        anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
        text: tile.valueText
        color: Theme.text
        font { family: Theme.font; pixelSize: 20; bold: true }
    }
}
