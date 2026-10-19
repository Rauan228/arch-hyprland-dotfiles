import QtQuick

// Линейные иконки панели скриншотера (собственные SVG-пути, viewBox 24×24).
Item {
    id: ic
    property string name: ""
    property color color: "#ffffff"
    property real stroke: 1.8
    implicitWidth: 20; implicitHeight: 20

    readonly property var paths: ({
        pen: '<path d="M4.5 19.5l1-4.2L15.8 5a2.1 2.1 0 0 1 3 3L8.6 18.3z"/><path d="M13.8 7l3 3"/>',
        line: '<path d="M5 19 19 5"/>',
        arrow: '<path d="M5 19 18.5 5.5"/><path d="M10 5.5h8.5V14"/>',
        rect: '<rect x="4.5" y="6" width="15" height="12" rx="1.5"/>',
        marker: '<path d="M9.5 15.5 4 21h5l2.3-2.3"/><path d="M8 14l7.6-9.4a2 2 0 0 1 2.9-.2l1.1 1.1a2 2 0 0 1-.2 2.9L10 16z"/>',
        text: '<path d="M5.5 6.5V5h13v1.5M12 5v14M9.5 19h5"/>',
        undo: '<path d="M8.5 6 4.5 10l4 4"/><path d="M4.5 10h10a5 5 0 0 1 0 10h-2.5"/>',
        copy: '<rect x="8.5" y="8.5" width="11" height="11" rx="2"/><path d="M15.5 8.5V6.2a1.7 1.7 0 0 0-1.7-1.7H6.2a1.7 1.7 0 0 0-1.7 1.7v7.6a1.7 1.7 0 0 0 1.7 1.7h2.3"/>',
        save: '<path d="M5 4.5h11l3.5 3.5v11.5H5z"/><path d="M8.5 4.5v4.5h6.5V4.5M8 19.5v-6h8v6"/>',
        folder: '<path d="M3.8 7.2a1.7 1.7 0 0 1 1.7-1.7h4l2 2h7a1.7 1.7 0 0 1 1.7 1.7v8.6a1.7 1.7 0 0 1-1.7 1.7h-13a1.7 1.7 0 0 1-1.7-1.7z"/>',
        close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'
    })

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(Math.max(1, ic.width) * 2, Math.max(1, ic.height) * 2)
        smooth: true
        source: ic.name === "" ? "" : "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + ic.color.toString()
            + '" stroke-width="' + ic.stroke + '" stroke-linecap="round" stroke-linejoin="round">' + (ic.paths[ic.name] || "") + '</svg>')
    }
}
