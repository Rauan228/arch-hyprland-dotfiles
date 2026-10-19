import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Переключение окон и рабочих столов как в Windows:
//   Alt+Tab / Alt+Shift+Tab — окна текущего рабочего стола (по последнему использованию), отпустить Alt — перейти;
//   Win+Tab — «Представление задач»: окна стола + полоса рабочих столов (создать / перейти / закрыть / перенести окно);
//   при переключении столов — подсказка «Рабочий стол N».
Scope {
    id: sw
    readonly property string desk: Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-desk"
    readonly property string font: "Noto Sans"
    readonly property color accent: "#6f74f2"
    readonly property color textMain: "#eef0f8"
    readonly property color textSub: Qt.rgba(0.92, 0.93, 0.98, 0.62)

    property string mode: ""               // "" | alttab | view
    property string screenName: ""
    property var wins: []                  // окна текущего стола (MRU)
    property var desks: ({ count: 1, current: 1, desktops: [] })
    property int sel: 0
    property bool shown: false             // для Alt+Tab окно показывается с задержкой (быстрый Alt+Tab без мигания)
    property bool pendingCommit: false
    property bool sticky: false            // Ctrl+Alt+Tab: окно не закрывается при отпускании Alt
    property int pendingStep: 0

    function curDesk() { var w = Hyprland.focusedWorkspace; return w && w.id > 0 ? w.id % 100 : 1; }
    function norm(a) { return String(a).replace(/^0x/, ""); }
    function toplevelFor(addr) {
        var l = Hyprland.toplevels.values, n = norm(addr);
        for (var i = 0; i < l.length; i++) if (norm(l[i].address) === n) return l[i].wayland;
        return null;
    }
    function iconFor(cls) {
        var e = null; try { e = DesktopEntries.heuristicLookup(cls); } catch (x) {}
        return Quickshell.iconPath(e && e.icon ? e.icon : cls, true) || Quickshell.iconPath(String(cls).toLowerCase(), true) || "";
    }
    function nameFor(cls) { var e = null; try { e = DesktopEntries.heuristicLookup(cls); } catch (x) {} return e && e.name ? e.name : cls; }

    // ---------- данные ----------
    Process {
        id: clientsProc
        property string buf: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser { splitMarker: ""; onRead: d => clientsProc.buf += d }
        onExited: {
            var list = []; try { list = JSON.parse(buf); } catch (e) {}
            buf = "";
            var c = sw.curDesk();
            sw.wins = list.filter(function(w) {
                return w.mapped !== false && ((w.workspace.id > 0 && w.workspace.id % 100 === c) || w.workspace.name === "special:minimized");
            }).sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID; }).map(function(w) {
                return { address: w.address, cls: w["class"], title: w.title, minimized: w.workspace.name === "special:minimized", monitor: w.monitor,
                         ww: Math.max(1, w.size[0]), wh: Math.max(1, w.size[1]) };
            });
            if (sw.mode === "alttab") {
                var n = sw.wins.length;
                if (n === 0) { sw.close(); return; }
                sw.sel = n > 1 ? (sw.pendingStep < 0 ? n - 1 : 1) : 0;
                if (sw.pendingCommit) { sw.commit(); return; }
                showTimer.restart();
            }
        }
    }
    Process {
        id: deskProc
        property string buf: ""
        command: [sw.desk, "list"]
        stdout: SplitParser { splitMarker: ""; onRead: d => deskProc.buf += d }
        onExited: { try { sw.desks = JSON.parse(buf); } catch (e) {} buf = ""; }
    }
    function load() { clientsProc.buf = ""; clientsProc.running = true; deskProc.buf = ""; deskProc.running = true; }
    Timer { id: showTimer; interval: 110; onTriggered: if (sw.mode === "alttab") sw.shown = true }

    // ---------- действия ----------
    function altTab(step) {
        if (mode === "alttab") {
            var n = wins.length; if (!n) return;
            sel = (sel + step + n) % n;
            return;
        }
        mode = "alttab"; shown = false; pendingCommit = false; pendingStep = step; sticky = false;
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        load();
    }
    function activate(w) {
        if (!w) return;
        if (w.minimized) {   // вернуть туда, откуда свернули (scripts/bin/serp-win)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-win", "restore", w.address]);
            return;
        }
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + w.address + '" })');
        Hyprland.dispatch('hl.dsp.window.alter_zorder({ mode = "top", window = "address:' + w.address + '" })');
    }
    function commit() {
        if (mode !== "alttab") return;
        if (clientsProc.running) { pendingCommit = true; return; }
        var w = wins[sel];
        close();
        activateLater(w);
    }
    // фокус переводим после того, как оверлей исчез (иначе Hyprland вернёт фокус прежнему окну)
    property var pendingWin: null
    function activateLater(w) { pendingWin = w; actTimer.restart(); }
    Timer { id: actTimer; interval: 60; onTriggered: { sw.activate(sw.pendingWin); sw.pendingWin = null } }
    function closeSelected() {   // Delete в Alt+Tab — закрыть выбранное окно, как в Windows
        var w = wins[sel]; if (!w) return;
        Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + w.address + '" })');
        var a = wins.slice(); a.splice(sel, 1); wins = a;
        if (!wins.length) close(); else sel = Math.min(sel, wins.length - 1);
    }
    function close() { sticky = false; mode = ""; shown = false; pendingCommit = false; showTimer.stop(); swipeTimer.stop(); assistZones = []; assistUsed = []; }
    // Alt+Tab жестом тачпада (3 пальца, scripts/bin/serp-cycle): окно со всеми окнами показывается сразу,
    // каждый свайп двигает выбор, а через паузу выбранное открывается — как отпустить Alt
    function swipe(step) {
        altTab(step);
        sticky = true; shown = true;
        swipeTimer.restart();
    }
    Timer { id: swipeTimer; interval: 800; onTriggered: if (sw.mode === "alttab") { if (sw.wins.length || clientsProc.running) sw.commit(); else sw.close(); } }
    function openView() {
        if (mode === "view") { close(); return; }
        mode = "view"; shown = true; sel = 0;
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        load();
    }
    function deskCmd(args, reopen) {
        Quickshell.execDetached([desk].concat(args));
        if (reopen) reloadTimer.restart();
    }
    Timer { id: reloadTimer; interval: 350; onTriggered: if (sw.mode === "view") sw.load() }

    // ---------- раскладка окон (Aero Snap, Snap Assist, Snap Layouts) ----------
    readonly property string snapCmd: Quickshell.env("HOME") + "/.config/serpantinum/bin/serp-snap"
    property string previewZone: ""        // подсветка места при перетаскивании
    property string previewMon: ""
    property var assistZones: []           // оставшиеся места для Snap Assist
    property var assistUsed: []            // окна, которые уже поставлены
    property string layoutTarget: ""       // окно для Win+Z
    readonly property var layouts: [
        [[0, 0, .5, 1], [.5, 0, .5, 1]],
        [[0, 0, .66, 1], [.66, 0, .34, 1]],
        [[0, 0, .33, 1], [.33, 0, .34, 1], [.67, 0, .33, 1]],
        [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]],
        [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]],
        [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]]
    ]
    function zoneFrac(z) {
        var m = { left: [0, 0, .5, 1], right: [.5, 0, .5, 1], max: [0, 0, 1, 1], tl: [0, 0, .5, .5], tr: [.5, 0, .5, .5], bl: [0, .5, .5, .5], br: [.5, .5, .5, .5] };
        if (m[z]) return m[z];
        if (String(z).indexOf("frac:") === 0) return String(z).substring(5).split(",").map(Number);
        return null;
    }
    function fracZone(f) { return "frac:" + f.join(","); }
    function startAssist(zones, mon, placed) {
        assistZones = zones; assistUsed = placed ? [placed] : []; screenName = mon;
        mode = "assist"; shown = true; sel = 0;
        load();
    }
    function assistPick(w) {
        if (!w || !assistZones.length) return;
        var z = assistZones[0];
        Quickshell.execDetached([snapCmd, "zone", z, w.address, screenName]);
        assistUsed = assistUsed.concat([w.address]);
        assistZones = assistZones.slice(1);
        sel = 0;
        if (!assistZones.length || !assistWins.length) { close(); activateLater(w); }
    }
    readonly property var assistWins: wins.filter(function(w) { return assistUsed.indexOf(w.address) < 0 && !w.minimized; })
    function openLayouts() {
        var a = Hyprland.activeToplevel;
        layoutTarget = a ? "0x" + norm(a.address) : "";
        if (!layoutTarget) return;
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        mode = "layouts"; shown = true;
        load();
    }
    function layoutPick(li, zi) {
        var L = layouts[li], z = fracZone(L[zi]);
        Quickshell.execDetached([snapCmd, "zone", z, layoutTarget, screenName]);
        var rest = [];
        for (var i = 0; i < L.length; i++) if (i !== zi) rest.push(fracZone(L[i]));
        var placed = layoutTarget;
        close();
        if (rest.length) assistTimer.start(rest, placed);
    }
    Timer { id: assistTimer; interval: 250; property var zs: []; property string placed: ""
            function start(z, p) { zs = z; placed = p; restart(); }
            onTriggered: sw.startAssist(zs, sw.screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""), placed) }

    // подсказка «Рабочий стол N»
    property int indicatorDesk: 0
    Timer { id: indTimer; interval: 1100; onTriggered: sw.indicatorDesk = 0 }

    IpcHandler {
        target: "switcher"
        function next(): void { sw.altTab(1) }
        function prev(): void { sw.altTab(-1) }
        function swipe(step: int): void { sw.swipe(step) }
        function sticky(): void { if (sw.mode === "alttab") { sw.altTab(1); return; } sw.altTab(1); sw.sticky = true; sw.shown = true }
        function commit(): void { if (sw.mode === "alttab") { if (sw.wins.length || clientsProc.running) sw.commit(); else sw.close(); } }
        function view(): void { sw.openView() }
        function desk(): void { sw.indicatorDesk = sw.curDesk(); deskProc.buf = ""; deskProc.running = true; indTimer.restart() }
        function snapPreview(zone: string, mon: string): void { sw.previewZone = zone === "none" ? "" : zone; if (mon !== "-") sw.previewMon = mon }
        function assist(zones: string, mon: string, placed: string): void { sw.startAssist(zones.split(" ").filter(function(z) { return z !== ""; }), mon, placed) }
        function close(): void { sw.close() }
        function layouts(): void { if (sw.mode === "layouts") sw.close(); else sw.openLayouts() }
    }

    // ---------- окна ----------
    Variants {
        model: Quickshell.screens.filter(function(s) {
            var main = sw.screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
            if (s.name === main && ((sw.mode !== "" && sw.shown) || sw.indicatorDesk > 0)) return true;
            return sw.previewZone !== "" && s.name === sw.previewMon;
        })

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "serp-switcher"
            readonly property bool isMain: modelData.name === (sw.screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""))
            readonly property bool interactive: sw.mode !== "" && sw.shown && isMain
            WlrLayershell.keyboardFocus: interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"
            mask: Region { item: win.interactive ? fullArea : null }

            Item { id: fullArea; anchors.fill: parent }

            readonly property real sc: Math.min(1, width / 1500, height / 900)
            function s(v) { return Math.round(v * sc) }

            // ===== подсказка «Рабочий стол N» =====
            Rectangle {
                visible: sw.mode === "" && sw.indicatorDesk > 0
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: win.s(70) }
                width: indRow.implicitWidth + win.s(40); height: win.s(56); radius: win.s(16)
                color: Qt.rgba(0.12, 0.12, 0.22, 0.86); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                Row {
                    id: indRow
                    anchors.centerIn: parent; spacing: win.s(14)
                    Text { text: "Рабочий стол " + sw.indicatorDesk; color: sw.textMain; font { family: sw.font; pixelSize: win.s(17); weight: Font.Medium } anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: win.s(6); anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: Math.max(sw.desks.count || 1, sw.indicatorDesk)
                            Rectangle { required property int index; width: index + 1 === sw.indicatorDesk ? win.s(22) : win.s(8); height: win.s(8); radius: height / 2
                                        color: index + 1 === sw.indicatorDesk ? sw.accent : Qt.rgba(1, 1, 1, 0.3)
                                        Behavior on width { NumberAnimation { duration: 160 } } }
                        }
                    }
                }
            }

            function zoneRect(z) {
                var f = sw.zoneFrac(z); if (!f) return { x: 0, y: 0, w: 0, h: 0 };
                var g = 8;
                return { x: f[0] * width + g, y: f[1] * height + g, w: f[2] * width - 2 * g, h: f[3] * height - 2 * g };
            }

            // ===== подсветка будущего места при перетаскивании (Aero Snap) =====
            Rectangle {
                id: pv
                readonly property var r: win.zoneRect(sw.previewZone)
                visible: sw.previewZone !== "" && win.modelData.name === sw.previewMon
                x: r.x; y: r.y; width: r.w; height: r.h; radius: 12
                color: Qt.rgba(0.55, 0.57, 1.0, 0.18); border.width: 2; border.color: Qt.rgba(0.70, 0.72, 1.0, 0.75)
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            // ===== Snap Assist: в свободном месте — остальные окна =====
            Rectangle {
                id: assistBox
                z: 5
                readonly property var r: win.zoneRect(sw.assistZones.length ? sw.assistZones[0] : "")
                visible: sw.mode === "assist" && win.isMain && sw.assistZones.length > 0
                x: r.x; y: r.y; width: r.w; height: r.h; radius: 16
                color: Qt.rgba(0.12, 0.12, 0.22, 0.82); border.width: 1; border.color: Qt.rgba(0.70, 0.72, 1.0, 0.55)
                MouseArea { anchors.fill: parent }
                Text {
                    x: 18; y: 14; text: sw.assistWins.length ? "Выберите окно для этого места" : "Других окон нет"
                    color: sw.textMain; font { family: sw.font; pixelSize: 14; weight: Font.Medium }
                }
                Flickable {
                    anchors { fill: parent; topMargin: 44; margins: 12 }
                    contentHeight: assistFlow.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                    Flow {
                        id: assistFlow
                        width: parent.width; spacing: 6
                        Repeater {
                            model: sw.mode === "assist" ? sw.assistWins : []
                            WinCard {
                                required property var modelData
                                required property int index
                                w: modelData; selected: index === sw.sel
                                width: Math.min(260, Math.max(170, (assistBox.width - 36) / 2)); height: width * 0.78
                                onPicked: sw.assistPick(modelData)
                                onHovered: sw.sel = index
                            }
                        }
                    }
                }
            }

            // ===== Win+Z: раскладки (Snap Layouts) =====
            Rectangle {
                id: layoutsBox
                z: 5
                visible: sw.mode === "layouts" && win.isMain
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 60 }
                width: lgrid.implicitWidth + 32; height: lgrid.implicitHeight + 56; radius: 16
                color: Qt.rgba(0.12, 0.12, 0.22, 0.88); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                MouseArea { anchors.fill: parent }
                Text { x: 16; y: 12; text: "Раскладки — выберите место для окна"; color: sw.textSub; font { family: sw.font; pixelSize: 12 } }
                Grid {
                    id: lgrid
                    x: 16; y: 38; columns: 3; spacing: 12
                    Repeater {
                        model: sw.layouts
                        Rectangle {
                            id: lay
                            required property var modelData
                            required property int index
                            width: 132; height: 82; radius: 10; color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                            Repeater {
                                model: lay.modelData
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    x: 5 + modelData[0] * (lay.width - 10) + 2; y: 5 + modelData[1] * (lay.height - 10) + 2
                                    width: modelData[2] * (lay.width - 10) - 4; height: modelData[3] * (lay.height - 10) - 4; radius: 5
                                    color: zma.containsMouse ? sw.accent : Qt.rgba(1, 1, 1, 0.16)
                                    MouseArea { id: zma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: sw.layoutPick(lay.index, parent.index) }
                                }
                            }
                        }
                    }
                }
            }

            // ===== общий фон =====
            Rectangle {
                anchors.fill: parent
                visible: sw.mode === "view"
                color: Qt.rgba(0.04, 0.04, 0.09, 0.55)
            }
            MouseArea { anchors.fill: parent; enabled: sw.mode !== ""; onClicked: sw.close() }

            // ===== Alt+Tab =====
            Rectangle {
                id: atPanel
                visible: sw.mode === "alttab"
                anchors.centerIn: parent
                width: Math.min(win.width * 0.92, atFlow.implicitW + 24)
                height: atFlow.implicitHeight + 24
                radius: 10
                color: Qt.rgba(0.125, 0.125, 0.135, 0.88); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                MouseArea { anchors.fill: parent }
                Flow {
                    id: atFlow
                    // ширина всех карточек в одну строку (для центрирования), иначе — перенос
                    readonly property real implicitW: { var t = 0; for (var i = 0; i < atRep.count; i++) { var it = atRep.itemAt(i); if (it) t += it.width + spacing; } return Math.max(0, t - spacing); }
                    x: 12; y: 12; width: parent.width - 24
                    spacing: 4
                    Repeater {
                        id: atRep
                        model: sw.mode === "alttab" ? sw.wins : []
                        AltCard {
                            required property var modelData
                            required property int index
                            w: modelData; selected: index === sw.sel
                            thumbH: win.s(150)
                            onPicked: { var w = modelData; sw.sel = index; sw.activateLater(w); sw.close() }
                            onCloseRequested: { sw.sel = index; sw.closeSelected() }
                        }
                    }
                }
            }

            // ===== Представление задач (Win+Tab) =====
            Item {
                visible: sw.mode === "view"
                anchors.fill: parent

                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: win.s(56) }
                    text: "Рабочий стол " + sw.curDesk() + (sw.wins.length ? "" : " — окон нет")
                    color: sw.textMain; font { family: sw.font; pixelSize: win.s(20); weight: Font.Medium }
                }
                Flickable {
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: deskStrip.top; topMargin: win.s(110); bottomMargin: win.s(24); leftMargin: win.s(60); rightMargin: win.s(60) }
                    contentHeight: viewFlow.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                    Flow {
                        id: viewFlow
                        // карточки по центру, как в Windows
                        readonly property int perRow: Math.max(1, Math.floor((parent.width + spacing) / (win.s(340) + spacing)))
                        width: Math.min(parent.width, Math.min(sw.wins.length, perRow) * (win.s(340) + spacing) - spacing)
                        x: (parent.width - width) / 2
                        spacing: win.s(18)
                        Repeater {
                            model: sw.mode === "view" ? sw.wins : []
                            WinCard {
                                required property var modelData
                                required property int index
                                w: modelData; selected: index === sw.sel; big: true; closable: true
                                width: win.s(340); height: win.s(260)
                                onPicked: { var w = modelData; sw.activateLater(w); sw.close() }
                                onHovered: sw.sel = index
                                onCloseRequested: { Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + modelData.address + '" })'); reloadTimer.restart() }
                                onMenuRequested: (gx, gy) => { menu.target = modelData; menu.x = Math.min(gx, win.width - menu.width - 10); menu.y = Math.min(gy, win.height - menu.height - 10); menu.visible = true }
                            }
                        }
                    }
                }

                // полоса рабочих столов
                Rectangle {
                    id: deskStrip
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: win.s(40) }
                    width: Math.min(parent.width - win.s(80), deskRow.implicitWidth + win.s(32)); height: win.s(170)
                    radius: win.s(20)
                    color: Qt.rgba(0.12, 0.12, 0.22, 0.78); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                    MouseArea { anchors.fill: parent }
                    Row {
                        id: deskRow
                        anchors.centerIn: parent
                        spacing: win.s(14)
                        Repeater {
                            model: sw.desks.desktops || []
                            Rectangle {
                                id: dc
                                required property var modelData
                                readonly property bool cur: modelData.n === sw.curDesk()
                                width: win.s(220); height: win.s(134); radius: win.s(14)
                                color: dma.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: cur ? 2 : 1; border.color: cur ? Qt.rgba(0.6, 0.62, 1, 0.9) : Qt.rgba(1, 1, 1, 0.12)
                                // значки окон стола
                                Flow {
                                    x: win.s(14); y: win.s(14); width: parent.width - win.s(28); height: win.s(70); spacing: win.s(6); clip: true
                                    Repeater {
                                        model: dc.modelData.windows
                                        Image { required property var modelData; width: win.s(30); height: win.s(30); sourceSize: Qt.size(60, 60); source: sw.iconFor(modelData["class"]) }
                                    }
                                }
                                Text { visible: dc.modelData.windows.length === 0; x: win.s(14); y: win.s(24); text: "Пусто"; color: sw.textSub; font { family: sw.font; pixelSize: win.s(13) } }
                                Text { x: win.s(14); anchors { bottom: parent.bottom; bottomMargin: win.s(14) } text: "Рабочий стол " + dc.modelData.n; color: sw.textMain; font { family: sw.font; pixelSize: win.s(14) } }
                                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { sw.deskCmd(["go", String(dc.modelData.n)], true) } }
                                Rectangle {
                                    visible: dma.containsMouse && (sw.desks.count || 1) > 1
                                    anchors { right: parent.right; top: parent.top; margins: win.s(8) }
                                    width: win.s(28); height: win.s(28); radius: win.s(14); color: xma.containsMouse ? "#e5484d" : Qt.rgba(0, 0, 0, 0.45)
                                    Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: win.s(13) }
                                    MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: sw.deskCmd(["close", String(dc.modelData.n)], true) }
                                }
                            }
                        }
                        Rectangle {
                            width: win.s(160); height: win.s(134); radius: win.s(14)
                            color: nma.containsMouse ? Qt.rgba(0.42, 0.44, 0.95, 0.35) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1; border.color: Qt.rgba(0.6, 0.62, 1, 0.5)
                            Column {
                                anchors.centerIn: parent; spacing: win.s(8)
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: sw.textMain; font { family: sw.font; pixelSize: win.s(34); weight: Font.Light } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Создать\nрабочий стол"; horizontalAlignment: Text.AlignHCenter; color: sw.textMain; font { family: sw.font; pixelSize: win.s(13) } }
                            }
                            MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.deskCmd(["new"], true) }
                        }
                    }
                }
            }

            // меню окна в представлении задач: перенести на другой стол
            Rectangle {
                id: menu
                visible: false; z: 10
                property var target: null
                width: win.s(270); height: mcol.implicitHeight + win.s(12); radius: win.s(12)
                color: Qt.rgba(0.10, 0.10, 0.19, 0.97); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                Column {
                    id: mcol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: win.s(6) }
                    Repeater {
                        model: menu.visible ? (function() {
                            var it = [], n = sw.desks.count || 1;
                            for (var i = 1; i <= n; i++) if (i !== sw.curDesk()) it.push({ label: "Перенести на рабочий стол " + i, d: i });
                            it.push({ label: "Перенести на новый рабочий стол", d: n + 1 });
                            it.push({ label: "Закрыть окно", d: -1 });
                            return it;
                        })() : []
                        Rectangle {
                            required property var modelData
                            width: mcol.width; height: win.s(36); radius: win.s(8)
                            color: mia.containsMouse ? Qt.rgba(0.42, 0.44, 0.95, 0.4) : "transparent"
                            Text { x: win.s(12); anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: modelData.d < 0 ? "#ff8a8d" : sw.textMain; font { family: sw.font; pixelSize: win.s(13) } }
                            MouseArea { id: mia; anchors.fill: parent; hoverEnabled: true; onClicked: {
                                menu.visible = false;
                                if (modelData.d < 0) Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + menu.target.address + '" })');
                                else sw.deskCmd(["move", String(modelData.d), menu.target.address], false);
                                reloadTimer.restart();
                            } }
                        }
                    }
                }
            }

            // ----- клавиатура -----
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => {
                    var n = sw.wins.length;
                    if (e.key === Qt.Key_Escape) { if (menu.visible) menu.visible = false; else sw.close(); }
                    else if (e.key === Qt.Key_Right || (sw.mode === "view" && e.key === Qt.Key_Tab)) { if (n) sw.sel = (sw.sel + 1) % n; }
                    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { if (n) sw.sel = (sw.sel - 1 + n) % n; }
                    else if (sw.mode === "assist" && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { sw.assistPick(sw.assistWins[sw.sel]); }
                    else if (sw.mode === "assist" && (e.key === Qt.Key_Right || e.key === Qt.Key_Down)) { if (sw.assistWins.length) sw.sel = (sw.sel + 1) % sw.assistWins.length; }
                    else if (sw.mode === "assist" && (e.key === Qt.Key_Left || e.key === Qt.Key_Up)) { if (sw.assistWins.length) sw.sel = (sw.sel - 1 + sw.assistWins.length) % sw.assistWins.length; }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (sw.mode === "alttab") sw.commit(); else if (n) { var w = sw.wins[sw.sel]; sw.activateLater(w); sw.close(); } }
                    else if (e.key === Qt.Key_Delete && sw.mode === "alttab" && n) { sw.closeSelected(); }
                    else if (e.key === Qt.Key_Delete && sw.mode === "view" && n) { Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + sw.wins[sw.sel].address + '" })'); reloadTimer.restart(); }
                    else return;
                    e.accepted = true;
                }
                Keys.onReleased: (e) => { if (sw.mode === "alttab" && !sw.sticky && (e.key === Qt.Key_Alt || e.key === Qt.Key_AltGr)) { sw.commit(); e.accepted = true; } }
            }
        }
    }

    // ---------- карточка Alt+Tab в стиле Windows 11: значок + заголовок над миниатюрой в пропорциях окна ----------
    component AltCard: Item {
        id: ac
        property var w: null
        property bool selected: false
        property real thumbH: 150
        signal picked()
        signal closeRequested()
        readonly property real thumbW: w ? Math.max(thumbH * 0.6, Math.min(thumbH * 2.0, thumbH * w.ww / w.wh)) : thumbH
        width: thumbW + 16; height: thumbH + 46

        Rectangle {
            anchors.fill: parent; radius: 8
            color: ac.selected ? Qt.rgba(1, 1, 1, 0.07) : (am.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent")
            border.width: ac.selected ? 2 : 0; border.color: "#ffffff"
        }
        Row {
            x: 10; y: 9; spacing: 8; width: parent.width - 20 - (closeBtn.visible ? 26 : 0)
            Image { width: 16; height: 16; sourceSize: Qt.size(32, 32); source: ac.w ? sw.iconFor(ac.w.cls) : ""; anchors.verticalCenter: parent.verticalCenter }
            Text { width: parent.width - 24; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                   text: ac.w ? (ac.w.title || sw.nameFor(ac.w.cls)) : ""; color: "#ffffff"; font { family: "Noto Sans"; pixelSize: 12 } }
        }
        Rectangle {
            id: closeBtn
            visible: ac.selected || am.containsMouse
            anchors { right: parent.right; top: parent.top; margins: 6 }
            width: 24; height: 24; radius: 5; color: cbm.containsMouse ? "#c42b1c" : "transparent"
            Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 11 }
            z: 2
            MouseArea { id: cbm; anchors.fill: parent; hoverEnabled: true; onClicked: ac.closeRequested() }
        }
        Item {
            x: 8; y: 36; width: ac.thumbW; height: ac.thumbH
            clip: true
            Rectangle { anchors.fill: parent; radius: 4; color: Qt.rgba(0, 0, 0, 0.35) }
            Image { anchors.centerIn: parent; width: 48; height: 48; sourceSize: Qt.size(96, 96); source: ac.w ? sw.iconFor(ac.w.cls) : ""; opacity: 0.8 }
            ScreencopyView {
                anchors.fill: parent
                captureSource: ac.w && !ac.w.minimized ? sw.toplevelFor(ac.w.address) : null
                live: true
                constraintSize: Qt.size(width, height)
            }
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; z: 1; onClicked: ac.picked()
                    // кнопка ✕ должна получать клики
                    propagateComposedEvents: true }
    }

    // ---------- карточка окна (миниатюра + значок + заголовок) ----------
    component WinCard: Item {
        id: card
        property var w: null
        property bool selected: false
        property bool big: false
        property bool closable: false
        signal picked()
        signal hovered()
        signal closeRequested()
        signal menuRequested(real gx, real gy)

        Rectangle {
            anchors { fill: parent; margins: 6 }
            radius: 14
            color: card.selected ? Qt.rgba(0.42, 0.44, 0.95, 0.38) : (cma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
            border.width: card.selected ? 2 : 1; border.color: card.selected ? Qt.rgba(0.65, 0.67, 1, 0.9) : Qt.rgba(1, 1, 1, 0.10)

            Row {
                x: 12; y: 10; spacing: 8; width: parent.width - 24
                Image { width: 22; height: 22; sourceSize: Qt.size(44, 44); source: card.w ? sw.iconFor(card.w.cls) : ""; anchors.verticalCenter: parent.verticalCenter }
                Text { width: parent.width - 30 - (card.closable ? 28 : 0); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                       text: card.w ? (card.w.title || sw.nameFor(card.w.cls)) : ""; color: sw.textMain; font { family: sw.font; pixelSize: 13 } }
            }
            Rectangle {
                id: thumbBox
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 42; leftMargin: 12; rightMargin: 12; bottomMargin: 12 }
                radius: 8; color: Qt.rgba(0, 0, 0, 0.25); clip: true
                Image { anchors.centerIn: parent; width: 64; height: 64; sourceSize: Qt.size(128, 128); source: card.w ? sw.iconFor(card.w.cls) : ""; opacity: 0.85 }
                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: card.w && !card.w.minimized ? sw.toplevelFor(card.w.address) : null
                    live: true
                    constraintSize: Qt.size(thumbBox.width, thumbBox.height)
                }
                Rectangle { visible: card.w && card.w.minimized; anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                            width: mt.implicitWidth + 14; height: 22; radius: 6; color: Qt.rgba(0, 0, 0, 0.6)
                            Text { id: mt; anchors.centerIn: parent; text: "свёрнуто"; color: sw.textSub; font { family: sw.font; pixelSize: 11 } } }
            }
            MouseArea {
                id: cma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: card.hovered()
                onClicked: (m) => { if (m.button === Qt.RightButton) { var p = mapToItem(null, m.x, m.y); card.menuRequested(p.x, p.y); } else card.picked(); }
            }
            Rectangle {
                visible: card.closable && (cma.containsMouse || xm.containsMouse)
                anchors { right: parent.right; top: parent.top; margins: 8 }
                width: 26; height: 26; radius: 13; color: xm.containsMouse ? "#e5484d" : Qt.rgba(0, 0, 0, 0.5)
                Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 12 }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; onClicked: card.closeRequested() }
            }
        }
    }
}
