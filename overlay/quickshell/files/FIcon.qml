import QtQuick

// Иконки «Диспетчера файлов» (собственные SVG-пути, viewBox 24×24).
Item {
    id: ic
    property string name: ""
    property color color: "#ffffff"
    property color fill: "transparent"
    property real stroke: 1.6
    implicitWidth: 20; implicitHeight: 20
    function rgb(c) { return "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")" }

    readonly property var paths: ({
        back: '<path d="M19.5 12h-15M10.5 6l-6 6 6 6"/>',
        forward: '<path d="M4.5 12h15M13.5 6l6 6-6 6"/>',
        up: '<path d="M12 19.5v-15M6 10.5l6-6 6 6"/>',
        refresh: '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path d="M19.5 4.5v4h-4"/>',
        home: '<path d="M3.5 11 12 4l8.5 7"/><path d="M5.5 9.5v10h13v-10" /><path d="M10 19.5v-5h4v5"/>',
        homefill: '<path d="M3.5 11 12 4l8.5 7v8.5h-6v-5h-5v5h-6z"/>',
        chevron: '<path d="M9.5 6.5 15 12l-5.5 5.5"/>',
        down: '<path d="M7 9.5l5 5 5-5"/>',
        upsmall: '<path d="M7 14.5l5-5 5 5"/>',
        search: '<circle cx="10.8" cy="10.8" r="6.5"/><path d="M15.7 15.7 20.5 20.5"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        cut: '<circle cx="6.5" cy="17.5" r="2.7"/><circle cx="17.5" cy="17.5" r="2.7"/><path d="M8.4 15.6 17.5 4.5M15.6 15.6 6.5 4.5"/>',
        copy: '<rect x="8.5" y="8.5" width="11" height="11.5" rx="2"/><path d="M15.5 8.5V6a1.5 1.5 0 0 0-1.5-1.5H6A1.5 1.5 0 0 0 4.5 6v8.5A1.5 1.5 0 0 0 6 16h2.5"/>',
        paste: '<rect x="5" y="4.5" width="14" height="16" rx="2"/><path d="M9 4.5V3.5h6v1"/><rect x="9" y="3" width="6" height="3.5" rx="1"/>',
        trash: '<path d="M4.5 6.5h15M9.5 6.5V4.5h5v2M6.5 6.5l1 13h9l1-13"/><path d="M10 10.5v6M14 10.5v6"/>',
        sort: '<path d="M8 4.5v15M4.5 8 8 4.5 11.5 8M16 19.5v-15M12.5 16l3.5 3.5 3.5-3.5"/>',
        list: '<path d="M8.5 6.5h11M8.5 12h11M8.5 17.5h11"/><path d="M4.5 6.5h.01M4.5 12h.01M4.5 17.5h.01" stroke-width="2.6"/>',
        grid: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>',
        more: '<path d="M5.5 12h.01M12 12h.01M18.5 12h.01" stroke-width="2.6"/>',
        star: '<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>',
        desktop: '<rect x="3.5" y="4.5" width="17" height="11.5" rx="1.8"/><path d="M8.5 20h7M12 16v4"/>',
        download: '<path d="M12 4v11M7 10.5l5 5 5-5M5 19.5h14"/>',
        document: '<path d="M6.5 3.5h7.5l4 4v13h-11.5z"/><path d="M13.5 3.5v4.5h4.5M9 12h6M9 15.5h6"/>',
        image: '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><circle cx="9" cy="9.5" r="1.7"/><path d="M4 17l5-4.5 3.5 3 3-2.5 4.5 4"/>',
        video: '<circle cx="12" cy="12" r="8.5"/><path d="M10.2 8.6v6.8l5.5-3.4z"/>',
        music: '<path d="M9 17.5V5.5l10-2v12"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="15.5" r="2.5"/>',
        folder: '<path d="M3.5 7a1.5 1.5 0 0 1 1.5-1.5h4.3l2 2.2H19A1.5 1.5 0 0 1 20.5 9.2V18a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18z"/>',
        computer: '<rect x="3.5" y="4.5" width="17" height="11.5" rx="1.8"/><path d="M8.5 20h7M12 16v4"/>',
        drive: '<rect x="3.5" y="7" width="17" height="10" rx="2"/><path d="M16.5 12h.01M13.5 12h.01" stroke-width="2.4"/>',
        open: '<path d="M13.5 4.5h6v6M19.5 4.5 11 13"/><path d="M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10"/>',
        min: '<path d="M5.5 12h13"/>',
        max: '<rect x="5.5" y="5.5" width="13" height="13" rx="1.6"/><path d="M9.5 14.5l5-5M10.5 9.5h4v4"/>',
        close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
        restore: '<path d="M4.5 9.5A8 8 0 1 1 6.6 17"/><path d="M4.5 4.5v5h5"/>',
        terminal: '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M7.5 9.5l3 2.5-3 2.5M12.5 15h4"/>',
        eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
        rename: '<path d="M4.5 19.5l1-4.2L15.8 5a2.1 2.1 0 0 1 3 3L8.6 18.3z"/>',
        pin: '<path d="M9 4.5h6l-1 5 3 3H7l3-3z"/><path d="M12 12.5v7"/>',
        link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'
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
