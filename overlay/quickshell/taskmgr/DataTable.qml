import QtQuick

// Таблица с сортируемыми заголовками, тепловой подсветкой ячеек и разворачиваемыми группами.
Item {
    id: t
    // columns: [{key, title, width (px, 0 = stretch), align: "left"|"right"}]
    property var columns: []
    property var rows: []            // [{key, depth, section, expandable, expanded, cells: {key: text}, heat: {key: 0..1}, icon, fallbackIcon, leaf}]
    property string sortKey: ""
    property bool sortDesc: true
    property string selectedKey: ""
    property int rowHeight: 33
    property var headerExtra: ({})   // key -> итог над названием колонки (например «37%»)
    signal headerClicked(string key)
    signal rowClicked(var row)
    signal rowRightClicked(var row, real gx, real gy)
    signal rowDoubleClicked(var row)
    signal toggleRequested(var row)

    readonly property bool hasExtra: Object.keys(headerExtra).length > 0
    readonly property real fixedW: { var s = 0; for (var i = 0; i < columns.length; i++) if (columns[i].width > 0) s += columns[i].width; return s; }
    function colW(c) { return c.width > 0 ? c.width : Math.max(140, t.width - 10 - fixedW); }

    // шапка
    Item {
        id: head
        width: parent.width; height: t.hasExtra ? 50 : 40
        Row {
            anchors.fill: parent
            Repeater {
                model: t.columns
                delegate: Item {
                    id: hc
                    required property var modelData
                    required property int index
                    readonly property bool alignRight: modelData.align === "right"
                    readonly property bool sorted: t.sortKey === modelData.key
                    width: t.colW(modelData); height: head.height
                    Rectangle { anchors.fill: parent; color: hma.containsMouse ? Style.hover : "transparent" }
                    Rectangle { visible: hc.index > 0; width: 1; height: parent.height; color: Style.line }
                    Column {
                        anchors { verticalCenter: parent.verticalCenter; left: hc.alignRight ? undefined : parent.left; right: hc.alignRight ? parent.right : undefined; leftMargin: 14; rightMargin: 14 }
                        spacing: 1
                        Text {
                            anchors.right: hc.alignRight ? parent.right : undefined
                            text: t.headerExtra[hc.modelData.key] !== undefined ? t.headerExtra[hc.modelData.key] : ""
                            visible: text !== ""
                            color: Style.text; font { family: Style.font; pixelSize: 14; weight: Font.Medium }
                        }
                        Row {
                            anchors.right: hc.alignRight ? parent.right : undefined
                            spacing: 6
                            Text {
                                text: hc.modelData.title
                                color: hc.sorted ? Style.text : Style.sub
                                font { family: Style.font; pixelSize: 12 }
                            }
                            Icon {
                                visible: hc.sorted; width: 13; height: 13; anchors.verticalCenter: parent.verticalCenter
                                name: t.sortDesc ? "down" : "up"; color: Style.sub; stroke: 1.8
                            }
                        }
                    }
                    MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.headerClicked(hc.modelData.key) }
                }
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Style.line }
    }

    ListView {
        id: lv
        anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: t.rows
        reuseItems: false
        // сохраняем прокрутку при обновлении модели
        property real keepY: 0
        onMovementEnded: keepY = contentY
        onContentYChanged: if (moving || dragging) keepY = contentY
        onModelChanged: Qt.callLater(function() { lv.contentY = Math.min(lv.keepY, Math.max(0, lv.contentHeight - lv.height)) })

        delegate: Item {
            id: rowItem
            required property var modelData
            width: lv.width; height: modelData.section ? 34 : t.rowHeight
            readonly property bool sel: t.selectedKey === modelData.key

            Rectangle {
                anchors.fill: parent
                color: rowItem.sel ? Style.a(Style.accent, 0.16) : (rma.containsMouse && !rowItem.modelData.section ? Style.hover : "transparent")
            }
            Rectangle { visible: rowItem.sel; width: 3; height: parent.height - 12; radius: 1.5; color: Style.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Qt.rgba(1, 1, 1, 0.035) }

            // раздел (Приложения / Фоновые ...)
            Text {
                visible: rowItem.modelData.section === true
                anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 7 }
                text: rowItem.modelData.title || ""
                color: Style.accent; font { family: Style.font; pixelSize: 12; weight: Font.DemiBold }
            }

            Row {
                visible: rowItem.modelData.section !== true
                anchors.fill: parent
                Repeater {
                    model: t.columns
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: t.colW(modelData); height: t.rowHeight
                        readonly property var row: rowItem.modelData
                        readonly property real heatV: row.heat && row.heat[modelData.key] !== undefined ? row.heat[modelData.key] : 0
                        Rectangle {
                            anchors.fill: parent
                            visible: cell.heatV > 0.004 && cell.index > 0
                            color: Style.heat; opacity: Math.min(0.62, 0.10 + cell.heatV * 0.6)
                        }
                        Rectangle { visible: cell.index > 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.035) }
                        // стрелка группы + иконка + имя в первой колонке
                        Item {
                            visible: cell.index === 0
                            anchors.fill: parent
                            Icon {
                                visible: cell.row.expandable === true
                                x: 10 + (cell.row.depth || 0) * 22; anchors.verticalCenter: parent.verticalCenter
                                width: 15; height: 15; name: "chevron"; color: Style.sub; stroke: 1.8
                                rotation: cell.row.expanded ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 140 } }
                                MouseArea { anchors { fill: parent; margins: -7 } onClicked: t.toggleRequested(cell.row) }
                            }
                            Image {
                                id: ic
                                x: 34 + (cell.row.depth || 0) * 22; anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20; sourceSize: Qt.size(40, 40); smooth: true
                                source: cell.row.icon || ""; visible: source !== "" && status === Image.Ready
                            }
                            Icon {
                                visible: !ic.visible && cell.row.fallbackIcon !== undefined && cell.row.fallbackIcon !== ""
                                x: ic.x; anchors.verticalCenter: parent.verticalCenter
                                width: 19; height: 19; name: cell.row.fallbackIcon || ""; color: Style.dim
                            }
                            Text {
                                readonly property bool hasIcon: ic.visible || (cell.row.fallbackIcon !== undefined && cell.row.fallbackIcon !== "")
                                x: (hasIcon ? 64 : 34) + (cell.row.depth || 0) * 22
                                width: parent.width - x - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: cell.row.cells[cell.modelData.key] || ""; elide: Text.ElideRight
                                color: Style.text; font { family: Style.font; pixelSize: 13 }
                            }
                        }
                        // «Состояние»: листок режима эффективности + текст
                        Row {
                            visible: cell.index > 0 && cell.modelData.key === "status"
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Icon { visible: cell.row.leaf === true; width: 16; height: 16; name: "leaf"; color: Style.leaf; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: cell.row.cells.status || ""; color: Style.sub
                                font { family: Style.font; pixelSize: 12 } anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            visible: cell.index > 0 && cell.modelData.key !== "status"
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: cell.modelData.align === "right" ? Text.AlignRight : Text.AlignLeft
                            text: cell.row.cells[cell.modelData.key] !== undefined ? cell.row.cells[cell.modelData.key] : ""
                            elide: Text.ElideRight
                            color: Style.text; font { family: Style.font; pixelSize: 13 }
                        }
                    }
                }
            }

            MouseArea {
                id: rma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    if (rowItem.modelData.section) return;
                    if (m.button === Qt.RightButton) { var p = mapToItem(null, m.x, m.y); t.rowRightClicked(rowItem.modelData, p.x, p.y); }
                    else t.rowClicked(rowItem.modelData);
                }
                onDoubleClicked: if (!rowItem.modelData.section) { if (rowItem.modelData.expandable) t.toggleRequested(rowItem.modelData); else t.rowDoubleClicked(rowItem.modelData); }
            }
        }
    }
}
