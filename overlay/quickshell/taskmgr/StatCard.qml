import QtQuick

// Карточка ресурса над таблицей процессов: метка, мини-график, значение, подпись.
Rectangle {
    id: card
    property string label: ""
    property color accent: Style.accent
    property string value: "—"
    property string sub: ""
    property var values: []
    property real maxValue: 100
    property bool autoMax: false
    property int tick: 0
    signal clicked()

    radius: 9
    color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Style.card
    border.width: 1; border.color: ma.containsMouse ? Style.a(accent, 0.35) : Style.line
    Behavior on color { ColorAnimation { duration: 140 } }

    Row {
        x: 12; y: 12; spacing: 8
        Rectangle { width: 3; height: 15; radius: 1.5; color: card.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: card.label; color: Style.text; font { family: Style.font; pixelSize: 13; weight: Font.Medium } }
    }

    Rectangle {
        id: spark
        x: 12; y: 37; width: Math.min(92, card.width * 0.38); height: card.height - 49
        radius: 4; color: Qt.rgba(0, 0, 0, 0.22); border.width: 1; border.color: Style.line; clip: true
        Graph {
            anchors { fill: parent; margins: 1 }
            grid: false; points: 30; fillAlpha: 0.55
            values: { card.tick; return (card.values || []).slice(-30); }
            maxValue: card.maxValue; autoMax: card.autoMax; tick: card.tick
            lineColor: card.accent
        }
    }

    Column {
        anchors { left: spark.right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: spark.verticalCenter }
        spacing: 3
        Text { width: parent.width; text: card.value; color: Style.text; font { family: Style.font; pixelSize: 18; weight: Font.Medium }
               fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11 }
        Text { width: parent.width; text: card.sub; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; color: Style.sub; font { family: Style.font; pixelSize: 11 } }
    }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.clicked() }
}
