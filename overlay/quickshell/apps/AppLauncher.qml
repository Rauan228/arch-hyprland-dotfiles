import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "catalog.js" as Catalog

// Меню приложений Serpantinum (Win+D): стеклянная панель, поиск, категории слева, карточки в три колонки.
// Избранное и недавние сохраняются в ~/.config/serpantinum/apps.json.
Scope {
    id: root
    property bool shown: false
    property string screenName: ""
    property string cat: "all"            // all | recent | fav | <категория>
    property string query: ""
    property int current: 0
    property var favorites: []
    property var recent: []

    // палитра с макета
    readonly property color accent: "#6f74f2"
    readonly property color textMain: "#f2f3f8"
    readonly property color textSub: Qt.rgba(0.92, 0.93, 0.98, 0.62)
    readonly property color star: "#f6a23c"
    readonly property string font: "Noto Sans"

    function open() {
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        query = ""; cat = "all"; current = 0;
        shown = true;
    }
    function close() { shown = false }
    function toggle() { if (shown) close(); else open(); }

    IpcHandler {
        target: "apps"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
    }

    // ---------- избранное / недавние ----------
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/serpantinum/apps.json"
        printErrors: false
        onLoaded: {
            try { var o = JSON.parse(text()); root.favorites = o.favorites || []; root.recent = o.recent || []; } catch (e) {}
        }
    }
    function persist() { store.setText(JSON.stringify({ favorites: favorites, recent: recent }, null, 2) + "\n"); }
    function isFav(id) { return favorites.indexOf(id) >= 0 }
    function toggleFav(id) {
        var f = favorites.slice(), i = f.indexOf(id);
        if (i >= 0) f.splice(i, 1); else f.push(id);
        favorites = f; persist();
    }

    // ---------- данные ----------
    readonly property var entries: DesktopEntries.applications.values
    readonly property var apps: {
        var list = [], seen = {};
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (!e || e.noDisplay || seen[e.id] || hidden.indexOf(e.id) >= 0) continue;
            seen[e.id] = true;
            list.push({ id: e.id, name: e.name, desc: Catalog.describe(e), cat: Catalog.categoryOf(e.categories || []),
                        icon: e.icon, entry: e,
                        hay: (e.name + " " + (e.genericName || "") + " " + (e.comment || "") + " " + e.id + " " + Catalog.describe(e) + " " + (e.keywords || []).join(" ")).toLowerCase() });
        }
        list.sort(function(a, b) { return a.name.localeCompare(b.name, "ru"); });
        return list;
    }
    readonly property var counts: {
        var c = { all: apps.length, recent: 0, fav: 0 };
        var ids = {};
        for (var i = 0; i < apps.length; i++) { ids[apps[i].id] = true; c[apps[i].cat] = (c[apps[i].cat] || 0) + 1; }
        c.recent = recent.filter(function(r) { return ids[r]; }).length;
        c.fav = favorites.filter(function(r) { return ids[r]; }).length;
        return c;
    }
    readonly property var shownApps: {
        var q = query.trim().toLowerCase();
        if (q !== "") {
            var res = [];
            for (var i = 0; i < apps.length; i++) {
                var a = apps[i], n = a.name.toLowerCase(), score = -1;
                if (n.indexOf(q) === 0) score = 0;
                else if (n.indexOf(q) > 0) score = 1;
                else if (a.hay.indexOf(q) >= 0) score = 2;
                if (score >= 0) res.push({ a: a, s: score });
            }
            res.sort(function(x, y) { return x.s - y.s || x.a.name.localeCompare(y.a.name, "ru"); });
            return res.map(function(r) { return r.a; });
        }
        if (cat === "all") return apps;
        if (cat === "recent") return recent.map(function(id) { return apps.find(function(a) { return a.id === id; }); }).filter(function(a) { return !!a; });
        if (cat === "fav") return apps.filter(function(a) { return root.isFav(a.id); });
        return apps.filter(function(a) { return a.cat === cat; });
    }
    onShownAppsChanged: current = Math.min(current, Math.max(0, shownApps.length - 1))

    // иконка: тема оболочки, затем файлы breeze/hicolor (как в диспетчере задач)
    property var iconIndex: ({})
    function iconFor(n) {
        if (!n) return "";
        if (n.charAt(0) === "/") return "file://" + n;
        var p = Quickshell.iconPath(n, true);
        if (p) return p;
        return iconIndex[n] ? "file://" + iconIndex[n] : "";
    }
    Process {
        id: iconScan
        property var found: ({})
        running: true
        command: ["bash", "-c", "find /usr/share/icons/breeze-dark /usr/share/icons/breeze /usr/share/icons/hicolor /usr/share/icons/Adwaita /usr/share/pixmaps \\( -path '*/48/*' -o -path '*/48x48/*' -o -path '*/scalable/*' -o -path '/usr/share/pixmaps/*' \\) \\( -name '*.svg' -o -name '*.png' \\) 2>/dev/null"]
        stdout: SplitParser { onRead: line => {
            var b = line.substring(line.lastIndexOf("/") + 1).replace(/\.(svg|png)$/, "");
            var sc = line.indexOf("/breeze-dark/") >= 0 ? 4 : line.indexOf("/breeze/") >= 0 ? 3 : line.indexOf("/hicolor/") >= 0 ? 2 : 1;
            var f = iconScan.found;
            if (!f[b] || f[b].sc < sc) f[b] = { p: line, sc: sc };
        } }
        onExited: { var idx = {}; for (var k in found) idx[k] = found[k].p; root.iconIndex = idx; found = ({}); }
    }

    // служебные пункты, которые только засоряют меню
    readonly property var hidden: ["avahi-discover", "bssh", "bvnc", "qv4l2", "qvidcap", "xfce4-about", "thunar-settings", "uuctl", "thunar-bulk-rename", "thunar"]

    function launch(a) {
        if (!a) return;
        var r = recent.filter(function(id) { return id !== a.id; });
        r.unshift(a.id); recent = r.slice(0, 20); persist();
        if (a.entry.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(a.entry.command));
        else a.entry.execute();
        close();
    }

    // ---------- окно ----------
    Variants {
        model: root.shown ? Quickshell.screens.filter(function(s) { return root.screenName === "" || s.name === root.screenName; }).slice(0, 1) : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "serp-apps"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            // масштаб под размер экрана (макет рассчитан на 1240×800)
            readonly property real sc: Math.min(1, width / 1340, height / 880)
            function s(v) { return Math.round(v * sc) }

            MouseArea { anchors.fill: parent; onClicked: root.close() }   // клик мимо панели — закрыть

            Rectangle {
                id: panel
                width: win.s(1240); height: win.s(800)
                anchors.centerIn: parent
                radius: win.s(28)
                color: Qt.rgba(0.16, 0.16, 0.27, 0.42)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                opacity: 0; scale: 0.97
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent }   // не закрывать при клике внутри

                // лёгкий градиент сверху, как на макете
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.06) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.10) }
                    }
                }

                // --- поиск ---
                Rectangle {
                    id: searchBox
                    x: win.s(28); y: win.s(26); width: panel.width - win.s(56); height: win.s(66)
                    radius: win.s(16)
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1.5; border.color: Qt.rgba(0.55, 0.58, 1.0, search.activeFocus ? 0.75 : 0.45)
                    AppIcon { name: "search"; color: Qt.rgba(1, 1, 1, 0.8); width: win.s(28); height: win.s(28); stroke: 1.7
                              anchors { left: parent.left; leftMargin: win.s(28); verticalCenter: parent.verticalCenter } }
                    TextInput {
                        id: search
                        anchors { left: parent.left; leftMargin: win.s(78); right: badge.left; rightMargin: win.s(14); verticalCenter: parent.verticalCenter }
                        color: root.textMain; font { family: root.font; pixelSize: win.s(21) }
                        selectionColor: Qt.rgba(0.44, 0.45, 0.95, 0.5)
                        focus: true
                        onTextChanged: { root.query = text; root.current = 0 }
                        Text { visible: parent.text === ""; text: "Поиск приложений..."; color: Qt.rgba(1, 1, 1, 0.55); font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                        Keys.onPressed: (e) => win.handleKey(e)
                        Component.onCompleted: forceActiveFocus()
                    }
                    Rectangle {
                        id: badge
                        anchors { right: parent.right; rightMargin: win.s(18); verticalCenter: parent.verticalCenter }
                        width: bt.implicitWidth + win.s(22); height: win.s(34); radius: win.s(8)
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Text { id: bt; anchors.centerIn: parent; text: "Ctrl + K"; color: Qt.rgba(1, 1, 1, 0.75); font { family: root.font; pixelSize: win.s(15) } }
                    }
                }

                // --- категории ---
                Column {
                    id: side
                    x: win.s(28); y: searchBox.y + searchBox.height + win.s(38)
                    width: win.s(262)
                    spacing: win.s(4)
                    Repeater {
                        model: [{ id: "all", label: "Все приложения", icon: "all" }, { id: "recent", label: "Недавние", icon: "recent" }, { id: "fav", label: "Избранные", icon: "star" }, { id: "-" }].concat(Catalog.categories)
                        delegate: Item {
                            id: ci
                            required property var modelData
                            width: side.width
                            height: modelData.id === "-" ? win.s(17) : win.s(52)
                            readonly property bool on: root.query === "" && root.cat === modelData.id
                            Rectangle {   // разделитель
                                visible: ci.modelData.id === "-"
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12)
                            }
                            Rectangle {
                                visible: ci.modelData.id !== "-"
                                anchors.fill: parent
                                radius: win.s(10)
                                color: ci.on ? Qt.rgba(0.42, 0.44, 0.95, 0.55) : (cma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.width: ci.on ? 1 : 0; border.color: Qt.rgba(0.65, 0.67, 1, 0.55)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                AppIcon { name: ci.modelData.icon || ""; color: root.textMain; width: win.s(25); height: win.s(25); stroke: 1.6
                                          anchors { left: parent.left; leftMargin: win.s(20); verticalCenter: parent.verticalCenter } }
                                Text { text: ci.modelData.label || ""; color: root.textMain; font { family: root.font; pixelSize: win.s(16) }
                                       anchors { left: parent.left; leftMargin: win.s(65); verticalCenter: parent.verticalCenter } }
                                Rectangle {
                                    anchors { right: parent.right; rightMargin: win.s(10); verticalCenter: parent.verticalCenter }
                                    width: Math.max(win.s(38), cnt.implicitWidth + win.s(16)); height: win.s(30); radius: win.s(7)
                                    color: ci.on ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                                    Text { id: cnt; anchors.centerIn: parent; text: String(root.counts[ci.modelData.id] || 0); color: Qt.rgba(1, 1, 1, 0.82); font { family: root.font; pixelSize: win.s(14) } }
                                }
                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { search.text = ""; root.cat = ci.modelData.id; root.current = 0; grid.positionViewAtBeginning(); search.forceActiveFocus() } }
                            }
                        }
                    }
                }
                Rectangle { x: side.x + side.width + win.s(18); y: side.y - win.s(8); width: 1; height: panel.height - y - win.s(32); color: Qt.rgba(1, 1, 1, 0.12) }

                // --- карточки ---
                GridView {
                    id: grid
                    x: side.x + side.width + win.s(36); y: side.y - win.s(4)
                    width: panel.width - x - win.s(26); height: panel.height - y - win.s(26)
                    cellWidth: Math.floor(width / 3); cellHeight: win.s(94)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.shownApps
                    currentIndex: root.current
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        width: grid.cellWidth; height: grid.cellHeight
                        readonly property bool sel: root.current === index
                        Rectangle {
                            anchors { fill: parent; rightMargin: win.s(12); bottomMargin: win.s(12) }
                            radius: win.s(10)
                            color: card.sel ? Qt.rgba(1, 1, 1, 0.12) : (kma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05))
                            border.width: 1; border.color: card.sel ? Qt.rgba(0.65, 0.67, 1, 0.6) : Qt.rgba(1, 1, 1, 0.09)
                            Behavior on color { ColorAnimation { duration: 110 } }
                            MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.launch(card.modelData) }
                            Item {
                                id: appIcon
                                anchors { left: parent.left; leftMargin: win.s(14); verticalCenter: parent.verticalCenter }
                                width: win.s(50); height: win.s(50)
                                Image {
                                    id: img
                                    anchors.fill: parent; sourceSize: Qt.size(win.s(50) * 2, win.s(50) * 2)
                                    smooth: true; asynchronous: true
                                    source: root.iconFor(card.modelData.icon)
                                }
                                // нет иконки в теме — своя заглушка
                                Rectangle {
                                    visible: img.source == "" || img.status === Image.Error
                                    anchors.fill: parent; radius: win.s(12)
                                    color: Qt.rgba(0.42, 0.44, 0.95, 0.35); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.15)
                                    Text { anchors.centerIn: parent; text: card.modelData.name.charAt(0).toUpperCase(); color: "white"; font { family: root.font; pixelSize: win.s(22); weight: Font.DemiBold } }
                                }
                            }
                            Column {
                                anchors { left: appIcon.right; leftMargin: win.s(18); right: starBtn.left; rightMargin: win.s(6); verticalCenter: parent.verticalCenter }
                                spacing: win.s(4)
                                Text { width: parent.width; text: card.modelData.name; elide: Text.ElideRight; color: root.textMain; font { family: root.font; pixelSize: win.s(16) } }
                                Text { width: parent.width; text: card.modelData.desc; elide: Text.ElideRight; color: root.textSub; font { family: root.font; pixelSize: win.s(14) } }
                            }
                            Item {
                                id: starBtn
                                anchors { right: parent.right; rightMargin: win.s(14); verticalCenter: parent.verticalCenter }
                                width: win.s(30); height: win.s(30)
                                readonly property bool fav: root.favorites.indexOf(card.modelData.id) >= 0
                                AppIcon { anchors.centerIn: parent; width: win.s(24); height: win.s(24); name: "star"; stroke: 1.5
                                          color: starBtn.fav ? root.star : (sma.containsMouse ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.6))
                                          fill: starBtn.fav ? root.star : "transparent" }
                                MouseArea { id: sma; anchors.fill: parent; anchors.margins: -win.s(6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleFav(card.modelData.id) }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.shownApps.length === 0
                        text: root.query !== "" ? "Ничего не найдено" : (root.cat === "fav" ? "Нажмите ☆ на карточке, чтобы добавить в избранное" : "Здесь пока пусто")
                        color: root.textSub; font { family: root.font; pixelSize: win.s(16) }
                    }
                }
            }

            function handleKey(e) {
                var n = root.shownApps.length, ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                if (e.key === Qt.Key_Escape) { if (search.text !== "") search.text = ""; else root.close(); }
                else if (ctrl && e.key === Qt.Key_K) { search.selectAll(); search.forceActiveFocus(); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launch(root.shownApps[root.current]); }
                else if (e.key === Qt.Key_Right) { if (search.text === "" || search.cursorPosition === search.text.length) root.current = Math.min(n - 1, root.current + 1); else return; }
                else if (e.key === Qt.Key_Left) { if (search.text === "" || search.cursorPosition === 0) root.current = Math.max(0, root.current - 1); else return; }
                else if (e.key === Qt.Key_Down) { root.current = Math.min(n - 1, root.current + 3); }
                else if (e.key === Qt.Key_Up) { root.current = Math.max(0, root.current - 3); }
                else if (e.key === Qt.Key_Tab) {
                    var order = ["all", "recent", "fav"].concat(Catalog.categories.map(function(c) { return c.id; }));
                    var i = order.indexOf(root.cat); search.text = "";
                    root.cat = order[(i + ((e.modifiers & Qt.ShiftModifier) ? order.length - 1 : 1)) % order.length]; root.current = 0;
                }
                else return;
                e.accepted = true;
            }
        }
    }
}
