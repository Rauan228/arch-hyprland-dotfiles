import QtQuick
import Quickshell.Services.Mpris
import "../theme"

GlassCard {
    id: card
    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    visible: player !== null

    Row {
        anchors { fill: parent; margins: 12 }
        spacing: 12
        Rectangle {
            width: parent.height; height: parent.height; radius: 10
            color: Theme.glassSoft; clip: true
            Image {
                anchors.fill: parent
                source: card.player ? card.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - parent.height - 12
            spacing: 4
            Text {
                width: parent.width; elide: Text.ElideRight
                text: card.player ? card.player.trackTitle : ""
                color: Theme.text; font { family: Theme.font; pixelSize: 13; bold: true }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: card.player ? card.player.trackArtist : ""
                color: Theme.muted; font { family: Theme.font; pixelSize: 11 }
            }
            Row {
                spacing: 18
                Repeater {
                    model: [
                        { icon: "󰒮", act: "prev" },
                        { icon: card.player && card.player.isPlaying ? "󰏤" : "󰐊", act: "toggle" },
                        { icon: "󰒭", act: "next" }
                    ]
                    delegate: Text {
                        required property var modelData
                        text: modelData.icon
                        color: ma.containsMouse ? Theme.accent2 : Theme.text
                        font { family: Theme.font; pixelSize: 20 }
                        MouseArea {
                            id: ma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                            onClicked: {
                                if (!card.player) return
                                if (modelData.act === "prev") card.player.previous()
                                else if (modelData.act === "next") card.player.next()
                                else card.player.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
