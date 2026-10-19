import QtQuick
import QtQuick.Layouts
import "fmt.js" as Fmt

// Вкладка «Параметры»: настройки сохраняются в ~/.config/serpantinum/taskmgr.json.
Flickable {
    id: sv
    required property var tm
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Segmented: Row {
        id: seg
        property var options: []       // [{v, label}]
        property var value
        signal picked(var v)
        spacing: 6
        Repeater {
            model: seg.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: seg.value === modelData.v
                width: sl.implicitWidth + 28; height: 32; radius: 7
                color: on ? Style.a(Style.accent, 0.16) : (sma.containsMouse ? Style.hover : Style.field)
                border.width: 1; border.color: on ? Style.a(Style.accent, 0.45) : Style.line
                Text { id: sl; anchors.centerIn: parent; text: modelData.label; color: parent.on ? Style.text : Style.sub; font { family: Style.font; pixelSize: 12 } }
                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(modelData.v) }
            }
        }
    }

    component Section: Rectangle {
        id: secR
        property string title: ""
        property string hint: ""
        default property alias content: holder.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 28
        radius: 9; color: Style.card; border.width: 1; border.color: Style.line
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 8
            Text { text: secR.title; color: Style.text; font { family: Style.font; pixelSize: 14; weight: Font.Medium } }
            Text { visible: secR.hint !== ""; Layout.fillWidth: true; text: secR.hint; wrapMode: Text.Wrap; color: Style.dim; font { family: Style.font; pixelSize: 12 } }
            Item { id: holder; Layout.fillWidth: true; implicitHeight: childrenRect.height }
        }
    }

    ColumnLayout {
        id: col
        width: sv.width
        spacing: 12

        Section {
            title: "Скорость обновления данных"
            hint: "Как часто диспетчер опрашивает систему. «Пауза» останавливает обновление."
            Segmented {
                options: [{ v: 500, label: "Высокая · 0,5 с" }, { v: 1000, label: "Обычная · 1 с" }, { v: 2000, label: "Низкая · 2 с" }, { v: 0, label: "Пауза" }]
                value: sv.tm.interval
                onPicked: v => sv.tm.setOption("interval", v)
            }
        }
        Section {
            title: "Страница по умолчанию"
            hint: "Какая вкладка открывается при запуске (Ctrl+Tab)."
            Segmented {
                options: [{ v: "procs", label: "Процессы" }, { v: "perf", label: "Производительность" }, { v: "history", label: "Журнал" }, { v: "details", label: "Подробности" }]
                value: sv.tm.startTab
                onPicked: v => sv.tm.setOption("startTab", v)
            }
        }
        Section {
            title: "Список процессов"
            hint: "Группировать процессы по разделам: приложения, фоновые и системные."
            Segmented {
                options: [{ v: false, label: "Единым списком" }, { v: true, label: "По разделам" }]
                value: sv.tm.groupByType
                onPicked: v => sv.tm.setOption("groupByType", v)
            }
        }
        Section {
            title: "О системе"
            Text {
                width: parent.width
                text: !sv.tm.data ? "Нет данных (обновление на паузе)" :
                      sv.tm.data.static.hostname + "  ·  ядро " + sv.tm.data.static.kernel + "  ·  время работы " + Fmt.uptime(sv.tm.data.uptime)
                      + "\n" + sv.tm.data.static.cpu_name + "  ·  " + sv.tm.data.static.ncpu + " логических процессоров"
                      + (sv.tm.data.static.igpu ? "\n" + sv.tm.data.static.igpu : "") + (sv.tm.data.gpu ? "  ·  " + sv.tm.data.gpu.name : "")
                wrapMode: Text.Wrap; lineHeight: 1.3
                color: Style.sub; font { family: Style.font; pixelSize: 12 }
            }
        }
    }
}
