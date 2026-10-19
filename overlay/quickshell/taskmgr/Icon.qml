import QtQuick

// Линейные иконки (собственные SVG-пути, viewBox 24×24).
Item {
    id: ic
    property string name: ""
    property color color: Style.sub
    property real stroke: 1.6
    implicitWidth: 20; implicitHeight: 20

    readonly property var paths: ({
        logo: '<rect x="3" y="3" width="18" height="18" rx="4.5"/><path d="M6.5 12.5h2.3l1.7-4.5 3 8 1.8-4.6h2.2"/>',
        search: '<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.6 15.6 20.5 20.5"/>',
        procs: '<rect x="3.5" y="3.5" width="17" height="17" rx="3.5"/><path d="M12 8.5v7M8.5 12h7"/>',
        perf: '<rect x="3.5" y="3.5" width="17" height="17" rx="3.5"/><path d="M6.8 14.2 9.4 11l2.6 2.8 3-5 2.2 2.6"/>',
        history: '<rect x="4.5" y="3.5" width="15" height="17" rx="2.5"/><path d="M8.3 8.5h7.4M8.3 12h7.4M8.3 15.5h4.4"/>',
        startup: '<path d="M4.6 17.2a8.2 8.2 0 1 1 14.8 0"/><path d="M12 13.2l3.4-3.8"/><circle cx="12" cy="13.6" r="1.1"/>',
        users: '<circle cx="12" cy="8.2" r="3.7"/><path d="M4.8 20c.9-3.9 3.7-5.6 7.2-5.6s6.3 1.7 7.2 5.6"/>',
        details: '<path d="M9 6.5h11M9 12h11M9 17.5h11"/><path d="M4.6 6.5h.01M4.6 12h.01M4.6 17.5h.01" stroke-width="2.6"/>',
        services: '<path d="M12 3.5 20.5 8 12 12.5 3.5 8z"/><path d="M3.5 12.2 12 16.7l8.5-4.5"/><path d="M3.5 16.2 12 20.7l8.5-4.5"/>',
        settings: '<circle cx="12" cy="12" r="3.1"/><path d="M12 2.8v2.6M12 18.6v2.6M2.8 12h2.6M18.6 12h2.6M5.5 5.5l1.9 1.9M16.6 16.6l1.9 1.9M5.5 18.5l1.9-1.9M16.6 7.4l1.9-1.9"/><circle cx="12" cy="12" r="6.6"/>',
        newtask: '<rect x="3.5" y="4.5" width="13" height="11" rx="2"/><path d="M3.5 8h13"/><circle cx="17" cy="17" r="4.3"/><path d="M17 15v4M15 17h4"/>',
        endtask: '<circle cx="12" cy="12" r="8.3"/><path d="M6.2 17.8 17.8 6.2"/>',
        more: '<path d="M5.5 12h.01M12 12h.01M18.5 12h.01" stroke-width="2.6"/>',
        chevron: '<path d="M9.5 6.5 15 12l-5.5 5.5"/>',
        up: '<path d="M7 14.5 12 9.5l5 5"/>',
        down: '<path d="M7 9.5l5 5 5-5"/>',
        min: '<path d="M5.5 12h13"/>',
        max: '<rect x="5.5" y="5.5" width="13" height="13" rx="1.6"/>',
        restore: '<rect x="5" y="8" width="11" height="11" rx="1.5"/><path d="M8.5 5.5h8.3a1.7 1.7 0 0 1 1.7 1.7v8.3"/>',
        close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
        leaf: '<path d="M5 19.2C5 11 10 5.8 19.3 4.8 19.3 14 14 19.2 5.9 19.2z"/><path d="M5 19.2 12.5 11.8"/>',
        app: '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M4 9h16"/>',
        terminal: '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M7.5 9.5l3 2.5-3 2.5M12.5 15h4"/>',
        pause: '<path d="M9 6.5v11M15 6.5v11"/>',
        check: '<path d="M5.5 12.5l4.2 4.2 8.8-9.4"/>'
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
