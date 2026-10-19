import QtQuick

// Линейные иконки меню приложений (собственные SVG-пути, viewBox 24×24).
Item {
    id: ic
    property string name: ""
    property color color: "#ffffff"
    property color fill: "transparent"
    property real stroke: 1.6
    implicitWidth: 22; implicitHeight: 22
    // SVG не понимает #AARRGGBB из Qt — цвет отдельно, прозрачность отдельно
    function rgb(c) { return "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")" }

    readonly property var paths: ({
        all: '<rect x="3.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.6"/>',
        recent: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
        star: '<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>',
        dev: '<path d="M8.5 7.5 4 12l4.5 4.5M15.5 7.5 20 12l-4.5 4.5"/><path d="M13.3 5.5 10.7 18.5"/>',
        design: '<path d="M7 4.5h3.5v3.5H7zM13.5 16h3.5v3.5h-3.5z"/><path d="M10.5 6.2c4.5 0 6.3 2 6.3 6.3v3.5M7 8v4.2c0 4.3 2 6.3 6.5 6.3"/>',
        office: '<path d="M7 3.5h7l4.5 4.5v12.5H7z"/><path d="M14 3.5V8h4.5M4.5 7v14.5h11"/>',
        web: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.5 3.5 5.3 3.5 8.5s-1.1 6-3.5 8.5c-2.4-2.5-3.5-5.3-3.5-8.5s1.1-6 3.5-8.5z"/>',
        media: '<path d="M9 17.5V5.5l10-2v12"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="15.5" r="2.5"/>',
        games: '<path d="M7.5 7.5h9a4.5 4.5 0 0 1 4.4 5.4l-.8 3.9a2.3 2.3 0 0 1-4 1l-1.8-2.3h-4.6L7.9 17.8a2.3 2.3 0 0 1-4-1l-.8-3.9a4.5 4.5 0 0 1 4.4-5.4z"/><path d="M7.5 10.5v3M6 12h3"/><path d="M15.5 11.2h.01M17.5 13h.01" stroke-width="2.4"/>',
        utils: '<path d="M14.5 6.5a4 4 0 0 0 5 5L12 19a2.1 2.1 0 0 1-3-3l7.5-7.5"/><path d="M14.5 6.5l3-3a4 4 0 0 1-3 3z"/><path d="M5 19l2-2"/>',
        system: '<circle cx="12" cy="12" r="3"/><path d="M19.4 13.5a7.6 7.6 0 0 0 0-3l2-1.5-2-3.4-2.4 1a7.4 7.4 0 0 0-2.6-1.5L14 2.5h-4l-.4 2.6A7.4 7.4 0 0 0 7 6.6l-2.4-1-2 3.4 2 1.5a7.6 7.6 0 0 0 0 3l-2 1.5 2 3.4 2.4-1a7.4 7.4 0 0 0 2.6 1.5l.4 2.6h4l.4-2.6a7.4 7.4 0 0 0 2.6-1.5l2.4 1 2-3.4z"/>',
        search: '<circle cx="10.8" cy="10.8" r="6.5"/><path d="M15.7 15.7 20.5 20.5"/>'
    })

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(Math.max(1, ic.width) * 2, Math.max(1, ic.height) * 2)
        smooth: true
        source: ic.name === "" ? "" : "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="' + (ic.fill.a > 0 ? ic.rgb(ic.fill) : "none") + '" fill-opacity="' + ic.fill.a
            + '" stroke="' + ic.rgb(ic.color) + '" stroke-opacity="' + ic.color.a
            + '" stroke-width="' + ic.stroke + '" stroke-linecap="round" stroke-linejoin="round">' + (ic.paths[ic.name] || "") + '</svg>')
    }
}
