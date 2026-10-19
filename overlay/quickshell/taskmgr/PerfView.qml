import QtQuick
import QtQuick.Layouts
import "fmt.js" as Fmt

// Вкладка «Производительность»: список ресурсов слева, график и показатели справа.
Item {
    id: pv
    required property var tm
    readonly property var d: tm.data

    function dash(v, f) { return v === null || v === undefined ? "—" : f(v); }

    readonly property var resources: {
        tm.tick;
        if (!d) return [];
        var r = [];
        r.push({ id: "cpu", title: "ЦП", sub: Fmt.pct(d.cpu.total, 0) + (d.cpu.freq ? "  " + (d.cpu.freq / 1000).toFixed(2).replace(".", ",") + " ГГц" : ""), color: Style.cpu, hist: "cpu", max: 100 });
        r.push({ id: "mem", title: "Память", sub: Fmt.bytes(d.mem.used, 1) + " / " + Fmt.bytes(d.mem.total, 1) + " (" + Fmt.pct(100 * d.mem.used / d.mem.total, 0) + ")", color: Style.mem, hist: "mem", max: 100 });
        var di = 0;
        for (var k in d.disk) { r.push({ id: "disk:" + k, title: "Диск " + di + " (" + k + ")", sub: Fmt.pct(d.disk[k].busy, 0), color: Style.disk, hist: "disk:" + k, max: 100 }); di++; }
        for (var n in d.net) r.push({ id: "net:" + n, title: (n.indexOf("wl") === 0 ? "Wi-Fi" : (n.indexOf("en") === 0 || n.indexOf("eth") === 0 ? "Ethernet" : n)) + " (" + n + ")",
                                       sub: "↓ " + Fmt.bits(d.net[n].rx) + "  ↑ " + Fmt.bits(d.net[n].tx), color: Style.net, hist: "rx:" + n, hist2: "tx:" + n, max: 0 });
        if (d.igpu) r.push({ id: "igpu", title: "ГП 0", sub: d.igpu.name + "  " + Fmt.pct(d.igpu.util, 0), color: Style.gpu, hist: "igpu", max: 100 });
        if (d.gpu) r.push({ id: "gpu", title: d.igpu ? "ГП 1" : "ГП 0", sub: Fmt.pct(d.gpu.util, 0) + (d.gpu.temp !== null ? "  (" + d.gpu.temp + " °C)" : ""), color: Style.gpu, hist: "gpu", max: 100 });
        return r;
    }
    readonly property var cur: { for (var i = 0; i < resources.length; i++) if (resources[i].id === tm.perfSel) return resources[i]; return resources.length ? resources[0] : null; }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // список
        Flickable {
            Layout.preferredWidth: 250; Layout.fillHeight: true
            contentHeight: lcol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: lcol
                width: parent.width; spacing: 6
                Repeater {
                    model: pv.resources
                    delegate: Rectangle {
                        required property var modelData
                        width: lcol.width; height: 70; radius: 9
                        color: tm.perfSel === modelData.id ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.18) : (rma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        border.width: tm.perfSel === modelData.id ? 1 : 0; border.color: modelData.color
                        Graph {
                            x: 8; y: 10; width: 74; height: 50; grid: false; points: 30
                            values: { tm.tick; return (tm.hist[modelData.hist] || []).slice(-30); }
                            values2: { tm.tick; return modelData.hist2 ? (tm.hist[modelData.hist2] || []).slice(-30) : []; }
                            maxValue: modelData.max || 100; autoMax: modelData.max === 0; tick: tm.tick
                            lineColor: modelData.color; lineColor2: Qt.darker(modelData.color, 1.5)
                        }
                        Column {
                            anchors { left: parent.left; leftMargin: 92; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } spacing: 3
                            Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; color: Style.text; font { family: Style.font; pixelSize: 13; weight: Font.Medium } }
                            Text { width: parent.width; text: modelData.sub; elide: Text.ElideRight; color: Style.sub; font { family: Style.font; pixelSize: 11 } }
                        }
                        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: tm.perfSel = modelData.id }
                    }
                }
            }
        }

        // детали
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            visible: pv.cur !== null

            RowLayout {
                Layout.fillWidth: true
                Text { text: pv.cur ? pv.cur.title : ""; color: Style.text; font { family: Style.font; pixelSize: 22; weight: Font.Medium } }
                Item { Layout.fillWidth: true }
                Text {
                    color: Style.sub; font { family: Style.font; pixelSize: 12 }
                    text: !pv.d || !pv.cur ? "" : pv.cur.id === "cpu" ? pv.d.static.cpu_name : pv.cur.id === "gpu" ? pv.d.gpu.name : pv.cur.id === "igpu" ? pv.d.igpu.name : ""
                }
            }
            Text {
                color: Style.dim; font { family: Style.font; pixelSize: 11 }
                text: !pv.cur ? "" : (pv.cur.id === "cpu" ? "Использование за 60 секунд" : pv.cur.id === "mem" ? "Использование памяти" : pv.cur.id.indexOf("disk") === 0 ? "Активное время диска" :
                      pv.cur.id.indexOf("net") === 0 ? "Пропускная способность (↓ приём / ↑ отправка)" : "Загрузка ГП")
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 120; Layout.preferredHeight: 270; radius: 9; color: Qt.rgba(0, 0, 0, 0.22)
                border.width: 1; border.color: pv.cur ? Qt.rgba(pv.cur.color.r, pv.cur.color.g, pv.cur.color.b, 0.6) : "transparent"
                Graph {
                    anchors { fill: parent; margins: 4 }
                    values: { tm.tick; return pv.cur ? (tm.hist[pv.cur.hist] || []).slice() : []; }
                    values2: { tm.tick; return pv.cur && pv.cur.hist2 ? (tm.hist[pv.cur.hist2] || []).slice() : []; }
                    maxValue: pv.cur && pv.cur.max ? pv.cur.max : 100; autoMax: pv.cur ? pv.cur.max === 0 : false
                    tick: tm.tick; lineColor: pv.cur ? pv.cur.color : Style.cpu; lineColor2: pv.cur ? Qt.darker(pv.cur.color, 1.6) : Style.mem
                }
            }
            // ядра ЦП
            Flow {
                Layout.fillWidth: true; spacing: 4
                visible: pv.cur && pv.cur.id === "cpu" && pv.d
                Repeater {
                    model: pv.d ? pv.d.cpu.cores : []
                    delegate: Rectangle {
                        required property real modelData
                        required property int index
                        width: 56; height: 34; radius: 6; color: Qt.rgba(0, 0, 0, 0.22); border.width: 1; border.color: Style.line; clip: true
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: parent.height * modelData / 100; color: Style.cpu; opacity: 0.45
                                    Behavior on height { NumberAnimation { duration: 300 } } }
                        Text { anchors { left: parent.left; top: parent.top; margins: 4 } text: "ядро " + index; color: Style.dim; font { family: Style.font; pixelSize: 9 } }
                        Text { anchors { right: parent.right; bottom: parent.bottom; margins: 4 } text: Math.round(modelData) + "%"; color: Style.text; font { family: Style.font; pixelSize: 11 } }
                    }
                }
            }
            // показатели
            GridLayout {
                Layout.fillWidth: true; columns: 4; columnSpacing: 22; rowSpacing: 10
                Repeater {
                    model: pv.stats
                    delegate: Column {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 2
                        Text { text: modelData.k; color: Style.sub; font { family: Style.font; pixelSize: 11 } }
                        Text { text: modelData.v; color: Style.text; font { family: Style.font; pixelSize: 18 } }
                    }
                }
            }
        }
    }

    readonly property var stats: {
        tm.tick;
        if (!d || !cur) return [];
        var id = cur.id, s = [];
        if (id === "cpu") {
            s = [{ k: "Использование", v: Fmt.pct(d.cpu.total, 0) }, { k: "Скорость", v: d.cpu.freq ? (d.cpu.freq / 1000).toFixed(2).replace(".", ",") + " ГГц" : "—" },
                 { k: "Процессы", v: String(d.cpu.procs) }, { k: "Потоки", v: String(d.cpu.threads) },
                 { k: "Время работы", v: Fmt.uptime(d.uptime) }, { k: "Логических процессоров", v: String(d.static.ncpu) },
                 { k: "Температура", v: dash(d.cpu.temp, function(v) { return v.toFixed(0) + " °C"; }) }, { k: "Нагрузка (1/5/15 мин)", v: d.load.join(" / ") }];
        } else if (id === "mem") {
            s = [{ k: "Используется", v: Fmt.bytes(d.mem.used, 1) }, { k: "Доступно", v: Fmt.bytes(d.mem.avail, 1) },
                 { k: "Кэш и буферы", v: Fmt.bytes(d.mem.cached, 1) }, { k: "Всего", v: Fmt.bytes(d.mem.total, 1) },
                 { k: "Подкачка (swap)", v: Fmt.bytes(d.mem.swap_used, 1) + " / " + Fmt.bytes(d.mem.swap_total, 1) }];
        } else if (id.indexOf("disk:") === 0) {
            var x = d.disk[id.substring(5)];
            s = [{ k: "Активное время", v: Fmt.pct(x.busy, 0) }, { k: "Чтение", v: Fmt.rate(x.read) }, { k: "Запись", v: Fmt.rate(x.write) },
                 { k: "Корневой раздел /", v: Fmt.bytes(d.root.total - d.root.free, 1) + " из " + Fmt.bytes(d.root.total, 1) }];
        } else if (id.indexOf("net:") === 0) {
            var nn = d.net[id.substring(4)];
            s = [{ k: "Приём", v: Fmt.bits(nn.rx) }, { k: "Отправка", v: Fmt.bits(nn.tx) }, { k: "Принято всего", v: Fmt.bytes(nn.rx_total, 1) }, { k: "Отправлено всего", v: Fmt.bytes(nn.tx_total, 1) }];
        } else if (id === "igpu" && d.igpu) {
            var top = d.procs.filter(function(p) { return p.gpu > 0; }).sort(function(a, b) { return b.gpu - a.gpu; }).slice(0, 3)
                       .map(function(p) { return p.name + " " + Fmt.pct0(p.gpu); }).join(", ");
            s = [{ k: "Использование", v: Fmt.pct(d.igpu.util, 0) }, { k: "Больше всего нагружают", v: top || "—" }];
        } else if (id === "gpu" && d.gpu) {
            s = [{ k: "Использование", v: Fmt.pct(d.gpu.util, 0) }, { k: "Видеопамять", v: Fmt.bytes(d.gpu.mem_used, 1) + " / " + Fmt.bytes(d.gpu.mem_total, 1) },
                 { k: "Температура", v: dash(d.gpu.temp, function(v) { return v + " °C"; }) }, { k: "Потребление", v: dash(d.gpu.power, function(v) { return v.toFixed(1) + " Вт"; }) },
                 { k: "Частота ядра", v: dash(d.gpu.clock, function(v) { return v + " МГц"; }) }];
        }
        return s;
    }
}
