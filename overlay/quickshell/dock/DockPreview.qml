import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Serpantinum: миниатюры окон приложения при наведении на значок в доке (как на панели задач Windows).
// Клик по миниатюре — перейти к окну (свёрнутое разворачивается), ✕ — закрыть окно.
Item {
    id: dp
    required property Item anchorItem
    property var info: null                 // runningInfo кнопки дока
    property bool hovered: false
    property bool popupHovered: false
    property bool open: false
    readonly property var wins: info && info.hasWindows ? (info.here || []).concat(info.elsewhere || []) : []

    Timer { id: openTimer; interval: 450; onTriggered: dp.open = dp.wins.length > 0 }
    Timer { id: closeTimer; interval: 250; onTriggered: if (!dp.hovered && !dp.popupHovered) dp.open = false }
    onHoveredChanged: { if (hovered) { closeTimer.stop(); openTimer.restart(); } else { openTimer.stop(); closeTimer.restart(); } }
    onPopupHoveredChanged: if (!popupHovered) closeTimer.restart()
    onWinsChanged: if (!wins.length) open = false

    PopupWindow {
        visible: dp.open && dp.wins.length > 0 && dp.anchorItem.visible
        anchor.item: dp.anchorItem
        anchor.rect.x: dp.anchorItem.width / 2
        anchor.rect.y: -10
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        implicitWidth: row.implicitWidth + 16
        implicitHeight: 178
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(0.11, 0.11, 0.14, 0.94); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            HoverHandler { onHoveredChanged: dp.popupHovered = hovered }

            Row {
                id: row
                x: 8; y: 8; spacing: 6
                Repeater {
                    model: dp.wins
                    Rectangle {
                        id: card
                        required property var modelData
                        width: 236; height: 162; radius: 10
                        color: cma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                        border.width: card.modelData.focused ? 1 : 0; border.color: Qt.rgba(1, 1, 1, 0.35)
                        Text {
                            x: 10; y: 8; width: parent.width - 44; elide: Text.ElideRight
                            text: card.modelData.title || card.modelData.appId || ""
                            color: "#e6e6eb"; font { family: "Noto Sans"; pixelSize: 12 }
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 8; topMargin: 30 }
                            radius: 6; color: Qt.rgba(0, 0, 0, 0.3); clip: true
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: card.modelData.native && card.modelData.native.wayland && card.modelData.workspace >= 0 ? card.modelData.native.wayland : null
                                live: true
                                constraintSize: Qt.size(width, height)
                            }
                            Text {
                                visible: card.modelData.workspace < 0
                                anchors.centerIn: parent; text: "свёрнуто"; color: Qt.rgba(1, 1, 1, 0.55); font { family: "Noto Sans"; pixelSize: 12 }
                            }
                        }
                        MouseArea {
                            id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { dp.open = false; WindowTracker.focusWindow(card.modelData); }
                        }
                        Rectangle {
                            visible: cma.containsMouse || xma.containsMouse
                            anchors { right: parent.right; top: parent.top; margins: 4 }
                            width: 24; height: 22; radius: 5; color: xma.containsMouse ? "#c42b1c" : "transparent"
                            Text { anchors.centerIn: parent; text: "✕"; color: "#e6e6eb"; font.pixelSize: 11 }
                            MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: WindowTracker.close(card.modelData) }
                        }
                    }
                }
            }
        }
    }
}
