import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "filetypes.js" as FT

// «Диспетчер файлов» Serpantinum — проводник в стиле Windows, оформленный под систему.
// Список папки — Qt FolderListModel (асинхронно, следит за изменениями); операции — fileops.py.
// Настройки и закреплённые папки: ~/.config/serpantinum/files.json. Теги и примечания — xattr (user.xdg.*).
Scope {
    id: fm
    property bool shown: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string ops: Quickshell.shellPath("files/fileops.py")
    readonly property string winSel: "title:^(Диспетчер файлов)$"

    // где мы
    property string page: "quick"          // folder | quick | computer | trash | search
    property string path: home
    property var backStack: []
    property var fwdStack: []
    property string searchText: ""
    property string searchQuery: ""

    // настройки
    property string view: "list"           // list | grid
    property string sortKey: "name"        // name | modified | type | size
    property bool sortDesc: false
    property bool showHidden: false
    property bool showDetails: true
    property var pinned: []

    // строки текущего вида
    property var rows: []
    property var extRows: []               // для quick/search/trash/computer — из fileops
    property var drives: []
    property var sel: ({})
    property int cur: -1
    property int anchor: -1
    property var clip: ({ mode: "", paths: [] })
    property string toast: ""

    // палитра (как меню приложений)
    readonly property color accent: "#6f74f2"
    readonly property color textMain: "#eef0f8"
    readonly property color textSub: Qt.rgba(0.92, 0.93, 0.98, 0.62)
    readonly property color line: Qt.rgba(1, 1, 1, 0.09)
    readonly property color panelBg: Qt.rgba(1, 1, 1, 0.04)
    readonly property color folderYellow: "#f5b73b"
    readonly property string font: "Noto Sans"
    readonly property var tagColors: ["#7b5cf0", "#3e7bf0", "#4b5fd6", "#c056c9", "#2fa3a0", "#d0743a"]

    // ---------- окно / IPC ----------
    function open(p) {
        if (p && p !== "") {
            if (p.indexOf("file://") === 0) p = decodeURIComponent(p.substring(7));
            go("folder", p.replace(/\/+$/, "") || "/", true);
        } else if (!shown) {
            go("quick", home, true);
        }
        var wasShown = shown;
        shown = true;
        if (wasShown) focusTimer.restart();
    }
    Timer { id: focusTimer; interval: 60; onTriggered: Hyprland.dispatch('hl.dsp.focus({ window = "' + fm.winSel + '" })') }
    IpcHandler {
        target: "files"
        function open(path: string): void { fm.open(path) }
        function toggle(): void { if (fm.shown) fm.shown = false; else fm.open("") }
        function close(): void { fm.shown = false }
        // показать файл в папке (для «Показать в папке» из браузера)
        function reveal(path: string): void {
            var d = path.substring(0, path.lastIndexOf("/")) || "/";
            fm.open(d); fm.pendingSelect = path;
        }
    }
    property string pendingSelect: ""

    // ---------- настройки ----------
    FileView {
        id: cfg
        path: fm.home + "/.config/serpantinum/files.json"
        printErrors: false
        onLoaded: {
            try {
                var o = JSON.parse(text());
                if (o.view) fm.view = o.view;
                if (o.sortKey) fm.sortKey = o.sortKey;
                if (o.sortDesc !== undefined) fm.sortDesc = o.sortDesc;
                if (o.showHidden !== undefined) fm.showHidden = o.showHidden;
                if (o.showDetails !== undefined) fm.showDetails = o.showDetails;
                if (o.pinned) fm.pinned = o.pinned;
            } catch (e) {}
        }
        onLoadFailed: fm.pinned = ["Downloads", "Pictures", "Projects", "Documents"].map(function(d) { return fm.home + "/" + d; })
    }
    function saveCfg() {
        cfg.setText(JSON.stringify({ view: view, sortKey: sortKey, sortDesc: sortDesc, showHidden: showHidden, showDetails: showDetails, pinned: pinned }, null, 2) + "\n");
    }

    // ---------- иконки темы (breeze) ----------
    property var iconIndex: ({})
    Process {
        id: iconScan
        property var found: ({})
        running: true
        command: ["bash", "-c", "find /usr/share/icons/breeze-dark /usr/share/icons/breeze \\( -path '*/mimetypes/64/*' -o -path '*/places/64/*' -o -path '*/devices/64/*' \\) -name '*.svg' 2>/dev/null"]
        stdout: SplitParser { onRead: line => {
            var b = line.substring(line.lastIndexOf("/") + 1).replace(/\.svg$/, "");
            var sc = line.indexOf("/breeze-dark/") >= 0 ? 2 : 1;
            if (!iconScan.found[b] || iconScan.found[b].sc < sc) iconScan.found[b] = { p: line, sc: sc };
        } }
        onExited: { var idx = {}; for (var k in found) idx[k] = found[k].p; fm.iconIndex = idx; found = ({}); }
    }
    function mimeIcon(name, isDir) {
        if (isDir) return "";
        var n = FT.iconName(name, false);
        var p = iconIndex[n] || iconIndex[n.split("-")[0] + "-x-generic"] || iconIndex["text-x-generic"] || iconIndex["unknown"];
        return p ? "file://" + p : "";
    }

    // ---------- навигация ----------
    function go(pg, p, noHistory) {
        if (!noHistory && (pg !== page || p !== path)) { var b = backStack.slice(); b.push({ page: page, path: path, q: searchQuery }); backStack = b; fwdStack = []; }
        page = pg;
        if (pg === "folder") path = p;
        sel = ({}); cur = -1; anchor = -1;
        if (pg !== "search") { searchText = ""; }
        if (pg === "quick") loadQuick();
        else if (pg === "computer") loadDrives();
        else if (pg === "trash") loadTrash();
        rebuild();
    }
    function back() { if (!backStack.length) return; var b = backStack.slice(), t = b.pop(); backStack = b; var f = fwdStack.slice(); f.push({ page: page, path: path, q: searchQuery }); fwdStack = f; if (t.page === "search") runSearch(t.q, true); else go(t.page, t.path, true); }
    function forward() { if (!fwdStack.length) return; var f = fwdStack.slice(), t = f.pop(); fwdStack = f; var b = backStack.slice(); b.push({ page: page, path: path, q: searchQuery }); backStack = b; if (t.page === "search") runSearch(t.q, true); else go(t.page, t.path, true); }
    function up() { if (page !== "folder") { go("folder", home); return; } if (path === "/") return; go("folder", path.substring(0, path.lastIndexOf("/")) || "/"); }
    function refresh() {
        if (page === "folder") { var f = fsm.folder; fsm.folder = ""; fsm.folder = f; }
        else if (page === "quick") loadQuick(); else if (page === "computer") loadDrives(); else if (page === "trash") loadTrash();
        else if (page === "search") runSearch(searchQuery, true);
    }
    function standard(dir) {     // стандартная папка: создать, если её ещё нет (как в Windows)
        var p = home + "/" + dir;
        Quickshell.execDetached(["mkdir", "-p", p]);
        go("folder", p);
    }

    FolderListModel {
        id: fsm
        folder: fm.page === "folder" ? "file://" + fm.path : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: fm.showHidden
        sortCaseSensitive: false
        onStatusChanged: if (status === FolderListModel.Ready) rebuildTimer.restart()
        onCountChanged: rebuildTimer.restart()
    }
    Timer { id: rebuildTimer; interval: 15; onTriggered: fm.rebuild() }

    function rebuild() {
        var src = [];
        if (page === "folder") {
            for (var i = 0; i < fsm.count; i++) {
                var n = fsm.get(i, "fileName"), d = fsm.get(i, "fileIsDir");
                src.push({ name: n, path: fsm.get(i, "filePath"), isdir: d, size: d ? -1 : fsm.get(i, "fileSize"), modified: fsm.get(i, "fileModified") });
            }
        } else {
            src = extRows.slice();
        }
        var q = searchText.trim().toLowerCase();
        if (q !== "" && page !== "search") src = src.filter(function(r) { return r.name.toLowerCase().indexOf(q) >= 0; });
        var k = sortKey, desc = sortDesc;
        src.sort(function(a, b) {
            if (a.isdir !== b.isdir) return a.isdir ? -1 : 1;
            var r = 0;
            if (k === "modified") r = (a.modified ? +new Date(a.modified) : 0) - (b.modified ? +new Date(b.modified) : 0);
            else if (k === "size") r = (a.size || 0) - (b.size || 0);
            else if (k === "type") r = FT.typeName(a.name, a.isdir).localeCompare(FT.typeName(b.name, b.isdir), "ru");
            if (r === 0) r = a.name.localeCompare(b.name, "ru", { numeric: true, sensitivity: "base" });
            return desc ? -r : r;
        });
        rows = src;
        if (pendingSelect !== "") {
            for (var j = 0; j < src.length; j++) if (src[j].path === pendingSelect) { var s = {}; s[src[j].path] = true; sel = s; cur = j; anchor = j; break; }
            pendingSelect = "";
        }
    }
    onSearchTextChanged: rebuild()
    onSortKeyChanged: { rebuild(); saveCfg() }
    onSortDescChanged: { rebuild(); saveCfg() }

    // ---------- данные спецстраниц (fileops) ----------
    Process {
        id: opsProc
        property var queue: []
        property var cb: null
        property string buf: ""
        stdout: SplitParser { onRead: line => opsProc.buf += line }
        onExited: {
            var o = null; try { o = JSON.parse(buf); } catch (e) {}
            var c = cb; cb = null; buf = "";
            if (c) c(o || { ok: false, error: "нет ответа" });
            if (queue.length) { var n = queue.shift(); cb = n.cb; command = n.cmd; running = true; }
        }
    }
    function runOp(args, cb) {
        var cmd = ["python3", "-I", ops].concat(args);
        if (opsProc.running) { var q = opsProc.queue.slice(); q.push({ cmd: cmd, cb: cb }); opsProc.queue = q; return; }
        opsProc.cb = cb; opsProc.command = cmd; opsProc.running = true;
    }
    function toRows(items) { return (items || []).map(function(it) { return { name: it.name, path: it.path, isdir: it.isdir, size: it.isdir ? -1 : it.size, modified: new Date(it.modified * 1000) }; }); }
    function loadQuick() { runOp(["recent", "40"], function(o) { if (page === "quick") { extRows = toRows(o.items); rebuild(); } }); }
    function loadDrives() { extRows = []; runOp(["drives"], function(o) { if (JSON.stringify(o.drives || []) !== JSON.stringify(drives)) drives = o.drives || []; rebuild(); }); }
    function openDrive(d) {
        if (d.mount) { go("folder", d.mount); return; }
        say("Подключение «" + (d.label || d.dev) + "»…");
        runOp(["mount", d.dev], function(o) { if (o.ok) { loadDrives(); go("folder", o.mount); } else say("Не удалось подключить: " + (o.error || "ошибка")); });
    }
    function ejectDrive(d) {
        if (page === "folder" && d.mount && (path === d.mount || path.indexOf(d.mount + "/") === 0)) go("computer", home);
        runOp(["eject", d.dev], function(o) { say(o.ok ? "Диск можно извлечь" : o.error); loadDrives(); });
    }
    // новые флешки появляются без перезахода на страницу
    Timer { interval: 2500; repeat: true; running: fm.shown && fm.page === "computer"; onTriggered: fm.loadDrives() }
    function loadTrash() {
        runOp(["trashlist"], function(o) {
            if (page !== "trash") return;
            extRows = (o.items || []).map(function(it) { return { name: it.name, path: it.path, isdir: it.isdir, size: it.isdir ? -1 : it.size, modified: new Date(it.modified * 1000), orig: it.orig, deleted: it.deleted }; });
            rebuild();
        });
    }
    function runSearch(q, noHistory) {
        q = q.trim(); if (q === "") return;
        var root = page === "folder" ? path : home;
        if (!noHistory) { var b = backStack.slice(); b.push({ page: page, path: path, q: searchQuery }); backStack = b; fwdStack = []; }
        searchQuery = q; page = "search"; extRows = []; sel = ({}); cur = -1; rebuild();
        searching = true;
        runOp(["search", root, q], function(o) { searching = false; if (page === "search") { extRows = toRows(o.items); rebuild(); } });
    }
    property bool searching: false

    // ---------- выделение ----------
    readonly property var selPaths: { var a = []; for (var k in sel) if (sel[k]) a.push(k); return a; }
    readonly property var focusRow: {
        if (selPaths.length !== 1) return null;
        for (var i = 0; i < rows.length; i++) if (rows[i].path === selPaths[0]) return rows[i];
        return null;
    }
    function clickRow(i, mods) {
        var r = rows[i]; if (!r) return;
        var s = {};
        if (mods & Qt.ShiftModifier && anchor >= 0) {
            if (mods & Qt.ControlModifier) s = Object.assign({}, sel);
            for (var j = Math.min(anchor, i); j <= Math.max(anchor, i); j++) s[rows[j].path] = true;
        } else if (mods & Qt.ControlModifier) {
            s = Object.assign({}, sel); s[r.path] = !s[r.path]; anchor = i;
        } else { s[r.path] = true; anchor = i; }
        sel = s; cur = i;
    }
    function selectAll() { var s = {}; rows.forEach(function(r) { s[r.path] = true; }); sel = s; }
    function moveCur(d, mods) {
        if (!rows.length) return;
        var i = Math.max(0, Math.min(rows.length - 1, (cur < 0 ? 0 : cur + d)));
        if (mods & Qt.ShiftModifier) { clickRow(i, Qt.ShiftModifier); } else { clickRow(i, 0); }
    }

    // ---------- действия ----------
    function say(t) { toast = t; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 2600; onTriggered: fm.toast = "" }

    function openRow(r) {
        if (!r) return;
        if (page === "trash") { say("Сначала восстановите объект из корзины"); return; }
        if (r.isdir) go("folder", r.path);
        else Quickshell.execDetached(["gio", "open", r.path]);
    }
    function uriList(paths) { return paths.map(function(p) { return "file://" + encodeURI(p); }).join("\n"); }
    function setClip(mode) {
        if (!selPaths.length || page === "trash") return;
        clip = { mode: mode, paths: selPaths.slice() };
        Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", uriList(selPaths)]);
        say((mode === "move" ? "Вырезано: " : "Скопировано: ") + selPaths.length);
    }
    function paste() {
        if (page !== "folder") { say("Откройте папку, чтобы вставить"); return; }
        if (clip.paths.length) { doPaste(clip.mode, clip.paths); if (clip.mode === "move") clip = { mode: "", paths: [] }; return; }
        sysPaste.buf = []; sysPaste.running = true;    // файлы, скопированные в другой программе
    }
    Process {
        id: sysPaste
        property var buf: []
        command: ["wl-paste", "--no-newline", "--type", "text/uri-list"]
        stdout: SplitParser { onRead: line => { line = line.trim(); if (line.indexOf("file://") === 0) sysPaste.buf.push(decodeURIComponent(line.substring(7))); } }
        onExited: if (buf.length) fm.doPaste("copy", buf.slice()); else fm.say("В буфере обмена нет файлов")
    }
    function doPaste(mode, paths) {
        var dest = path;
        say(mode === "move" ? "Перемещение…" : "Копирование…");
        runOp(["paste", mode, dest].concat(paths), function(o) {
            if (!o.ok) { say("Ошибка: " + o.error); return; }
            say((mode === "move" ? "Перемещено: " : "Скопировано: ") + o.paths.length);
            refresh();
        });
    }
    function trashSel() {
        if (!selPaths.length) return;
        if (page === "trash") { askDelete(true); return; }
        var n = selPaths.length;
        runOp(["trash"].concat(selPaths), function(o) { say(o.ok ? "В корзину: " + n : "Ошибка: " + o.error); sel = ({}); refresh(); });
    }
    function askDelete(permanent) {
        if (!selPaths.length) return;
        var paths = selPaths.slice();
        dialog.show("Удалить навсегда?", paths.length === 1 ? "«" + paths[0].substring(paths[0].lastIndexOf("/") + 1) + "» будет удалён без возможности восстановления."
                                                              : "Объектов: " + paths.length + ". Их нельзя будет восстановить.", "", "Удалить", true,
                    function() { runOp(["delete"].concat(paths), function(o) { say(o.ok ? "Удалено" : "Ошибка: " + o.error); sel = ({}); refresh(); }); });
    }
    function create(kind) {
        if (page !== "folder") { say("Откройте папку"); return; }
        var def = kind === "mkdir" ? "Новая папка" : (kind === "txt" ? "Новый текстовый документ.txt" : "Новый файл");
        dialog.show(kind === "mkdir" ? "Создать папку" : "Создать файл", "Имя:", def, "Создать", false, function(v) {
            if (!v.trim()) return;
            runOp([kind === "mkdir" ? "mkdir" : "touch", path, v.trim()], function(o) { if (o.ok) { pendingSelect = o.path; refresh(); } else say("Ошибка: " + o.error); });
        });
    }
    // ---------- архивы ----------
    function isArchive(n) { return /\.(zip|7z|rar|tar|tgz|txz|tbz2|gz|xz|bz2|zst|cab|iso|jar|apk)$/i.test(n); }
    function archive(fmt) {
        var ps = selPaths.slice(); if (!ps.length) return;
        say("Архивирование…");
        runOp(["archive", fmt].concat(ps), function(o) { if (o.ok) { pendingSelect = o.path; refresh(); say("Архив создан"); } else say("Ошибка: " + o.error); });
    }
    function extract(p) {
        say("Распаковка…");
        runOp(["extract", p], function(o) { if (o.ok) { pendingSelect = o.path; refresh(); say("Распаковано"); } else say("Ошибка: " + o.error); });
    }
    function rename() {
        var r = focusRow; if (!r || page === "trash") return;
        dialog.show("Переименовать", "Новое имя:", r.name, "Переименовать", false, function(v) {
            if (!v.trim() || v === r.name) return;
            runOp(["rename", r.path, v.trim()], function(o) { if (o.ok) { pendingSelect = o.path; refresh(); } else say("Ошибка: " + o.error); });
        });
    }
    function restoreSel() {
        if (!selPaths.length) return;
        var names = rows.filter(function(r) { return sel[r.path]; }).map(function(r) { return r.name; });
        runOp(["restore"].concat(names), function(o) { say(o.ok ? "Восстановлено: " + names.length : "Ошибка: " + o.error); loadTrash(); });
    }
    function emptyTrash() {
        dialog.show("Очистить корзину?", "Все объекты в корзине будут удалены навсегда.", "", "Очистить", true,
                    function() { runOp(["emptytrash"], function(o) { say(o.ok ? "Корзина очищена" : "Ошибка: " + o.error); loadTrash(); }); });
    }
    function copyPath() {
        var p = selPaths.length ? selPaths.join("\n") : path;
        Quickshell.execDetached(["wl-copy", p]); say("Путь скопирован");
    }
    function terminalHere() { Quickshell.execDetached(["kitty", "--directory", focusRow && focusRow.isdir ? focusRow.path : path]); }
    function togglePin(p) {
        var a = pinned.slice(), i = a.indexOf(p);
        if (i >= 0) a.splice(i, 1); else a.push(p);
        pinned = a; saveCfg(); if (page === "quick") rebuild();
        say(i >= 0 ? "Откреплено" : "Закреплено в быстром доступе");
    }

    // ---------- сведения о выбранном ----------
    property var info: null
    property string infoFor: ""
    readonly property string detailPath: focusRow ? focusRow.path : (page === "folder" ? path : "")
    onDetailPathChanged: infoTimer.restart()
    Timer {
        id: infoTimer; interval: 120
        onTriggered: {
            var p = fm.detailPath; fm.info = null; fm.infoFor = p;
            if (!p || fm.page === "trash") return;
            fm.runOp(["info", p], function(o) { if (fm.infoFor === p) fm.info = o; });
        }
    }
    function setTags(tags) { var p = detailPath; runOp(["settags", p, tags.join(",")], function(o) { if (fm.infoFor === p && o.ok) { var i = Object.assign({}, info); i.tags = tags; info = i; } }); }
    function setNote(t) { var p = detailPath; if (info && info.note === t) return; runOp(["setnote", p, t], function(o) { if (fm.infoFor === p && o.ok) { var i = Object.assign({}, info); i.note = t; info = i; say("Примечание сохранено"); } }); }

    onShownChanged: if (!shown) { menu.visible = false; dialog.visible = false }

    // ---------- окно ----------
    FloatingWindow {
        id: win
        visible: fm.shown
        title: "Диспетчер файлов"
        implicitWidth: 1290
        implicitHeight: 890
        color: "transparent"
        onVisibleChanged: if (!visible) fm.shown = false

        component Btn: Rectangle {
            id: b
            property string icon: ""
            property string label: ""
            property bool enabledState: true
            property bool hasMenu: false
            property real iconSize: 20
            property color iconColor: fm.textMain
            signal clicked(real gx, real gy)
            implicitWidth: label === "" ? (hasMenu ? 54 : 40) : bl.implicitWidth + (icon !== "" ? 48 : 22) + (hasMenu ? 22 : 0)
            implicitHeight: 40
            radius: 9
            opacity: enabledState ? 1 : 0.4
            color: bma.containsMouse && enabledState ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            FIcon { id: bi; visible: b.icon !== ""; name: b.icon; width: b.iconSize; height: b.iconSize; color: b.iconColor; stroke: 1.5
                    anchors { left: parent.left; leftMargin: b.label === "" && !b.hasMenu ? (parent.width - width) / 2 : 12; verticalCenter: parent.verticalCenter } }
            Text { id: bl; visible: b.label !== ""; text: b.label; color: fm.textMain; font { family: fm.font; pixelSize: 13 }
                   anchors { left: b.icon !== "" ? bi.right : parent.left; leftMargin: b.icon !== "" ? 12 : 11; verticalCenter: parent.verticalCenter } }
            FIcon { visible: b.hasMenu; name: "down"; width: 14; height: 14; color: fm.textSub; stroke: 1.8
                    anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter } }
            MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; enabled: b.enabledState; cursorShape: Qt.PointingHandCursor
                        onClicked: { var p = mapToItem(frame, 0, height + 6); b.clicked(p.x, p.y) } }
        }
        component Sep: Rectangle { width: 1; height: 26; color: Qt.rgba(1, 1, 1, 0.14) }

        component NavItem: Rectangle {
            id: ni
            property string icon: ""
            property color iconColor: fm.textMain
            property color iconFill: "transparent"
            property string label: ""
            property bool on: false
            signal clicked()
            width: parent ? parent.width : 200; height: 44; radius: 9
            color: on ? Qt.rgba(0.42, 0.44, 0.95, 0.45) : (nma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.width: on ? 1 : 0; border.color: Qt.rgba(0.65, 0.67, 1, 0.5)
            FIcon { name: ni.icon; color: ni.iconColor; fill: ni.iconFill; width: 22; height: 22; stroke: 1.6
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } }
            Text { text: ni.label; color: fm.textMain; font { family: fm.font; pixelSize: 14 }
                   anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter } }
            MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ni.clicked() }
        }

        Rectangle {
            id: frame
            // на маленьком экране весь интерфейс пропорционально уменьшается (макет 1250×860)
            readonly property real sc: Math.min(1, win.width / 1250, win.height / 860)
            width: win.width / sc; height: win.height / sc
            scale: sc; transformOrigin: Item.TopLeft
            color: Qt.rgba(0.12, 0.12, 0.22, 0.62)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
            focus: true
            Keys.onPressed: (e) => fm.key(e)

            // --- заголовок ---
            Item {
                id: titleBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 52
                MouseArea { anchors.fill: parent; onPressed: { try { titleBar.Window.window.startSystemMove(); } catch (e) {} }
                            onDoubleClicked: Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", window = "' + fm.winSel + '" })') }
                Row {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter } spacing: 12
                    Rectangle { width: 28; height: 28; radius: 7; color: Qt.rgba(0.42, 0.44, 0.95, 0.35); anchors.verticalCenter: parent.verticalCenter
                                FIcon { anchors.centerIn: parent; name: "folder"; width: 18; height: 18; color: "#c9cbff"; stroke: 1.7 } }
                    Text { text: "Диспетчер файлов"; color: fm.textMain; font { family: fm.font; pixelSize: 15 } anchors.verticalCenter: parent.verticalCenter }
                }
                // кнопки окна — в общем заголовке (hyprbars, стиль macOS)
            }

            // --- навигация: назад/вперёд/вверх/обновить, путь, поиск ---
            Rectangle {
                id: navBar
                anchors { left: parent.left; right: parent.right; top: titleBar.bottom; leftMargin: 14; rightMargin: 14 }
                height: 66; radius: 14; color: fm.panelBg; border.width: 1; border.color: fm.line
                Row {
                    id: navBtns
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 6
                    Btn { icon: "back"; iconSize: 24; enabledState: fm.backStack.length > 0; onClicked: fm.back() }
                    Btn { icon: "forward"; iconSize: 24; enabledState: fm.fwdStack.length > 0; onClicked: fm.forward() }
                    Btn { icon: "up"; iconSize: 24; enabledState: !(fm.page === "folder" && fm.path === "/"); onClicked: fm.up() }
                    Btn { icon: "refresh"; iconSize: 22; onClicked: fm.refresh() }
                }
                // путь (хлебные крошки; клик по пустому месту — ввод пути)
                Rectangle {
                    id: crumbBox
                    anchors { left: navBtns.right; leftMargin: 14; right: searchBox.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    height: 46; radius: 10; color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: pathEdit.visible ? Qt.rgba(0.6, 0.62, 1, 0.7) : Qt.rgba(1, 1, 1, 0.13)
                    clip: true
                    MouseArea { anchors.fill: parent; onClicked: fm.editPath() }
                    Row {
                        id: crumbs
                        visible: !pathEdit.visible
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: fm.crumbs
                            Row {
                                required property var modelData
                                required property int index
                                spacing: 4
                                FIcon { visible: index > 0; name: "chevron"; width: 14; height: 14; color: fm.textSub; stroke: 1.8; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: cr.implicitWidth + (modelData.icon ? 40 : 16); height: 32; radius: 7
                                    color: crm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                    FIcon { visible: !!modelData.icon; name: modelData.icon || ""; fill: fm.textMain; color: fm.textMain; width: 20; height: 20; x: 8; anchors.verticalCenter: parent.verticalCenter; stroke: 1.2 }
                                    Text { id: cr; x: modelData.icon ? 34 : 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.label
                                           color: index === fm.crumbs.length - 1 ? fm.textMain : fm.textSub; font { family: fm.font; pixelSize: 14 } }
                                    MouseArea { id: crm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                                }
                            }
                        }
                    }
                    TextInput {
                        id: pathEdit
                        visible: false
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: fm.textMain; font { family: fm.font; pixelSize: 14 } selectionColor: Qt.rgba(0.44, 0.45, 0.95, 0.5)
                        onAccepted: { var p = text.trim().replace(/^~/, fm.home); visible = false; frame.forceActiveFocus(); if (p) fm.go("folder", p.replace(/\/+$/, "") || "/"); }
                        onActiveFocusChanged: if (!activeFocus) visible = false
                        Keys.onEscapePressed: { visible = false; frame.forceActiveFocus() }
                    }
                }
                Rectangle {
                    id: searchBox
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: Math.min(300, navBar.width * 0.24); height: 46; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: searchIn.activeFocus ? Qt.rgba(0.6, 0.62, 1, 0.8) : Qt.rgba(0.55, 0.58, 1, 0.35)
                    FIcon { name: "search"; width: 22; height: 22; color: fm.textMain; stroke: 1.6; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } }
                    TextInput {
                        id: searchIn
                        anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        color: fm.textMain; font { family: fm.font; pixelSize: 14 } selectionColor: Qt.rgba(0.44, 0.45, 0.95, 0.5); clip: true
                        text: fm.searchText
                        onTextEdited: fm.searchText = text
                        onAccepted: fm.runSearch(text)
                        Keys.onEscapePressed: { fm.searchText = ""; text = ""; frame.forceActiveFocus() }
                        Text { visible: parent.text === ""; text: "Поиск файлов..."; color: fm.textSub; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            // --- панель команд ---
            Row {
                id: toolBar
                anchors { left: parent.left; leftMargin: 14; top: navBar.bottom; topMargin: 10 }
                height: 52
                spacing: 6
                Rectangle {
                    width: cl.implicitWidth + 96; height: 46; radius: 10; anchors.verticalCenter: parent.verticalCenter
                    color: cma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                    opacity: fm.page === "folder" ? 1 : 0.45
                    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 7; color: fm.accent
                                FIcon { anchors.centerIn: parent; name: "plus"; width: 18; height: 18; color: "white"; stroke: 2 } }
                    Text { id: cl; x: 52; anchors.verticalCenter: parent.verticalCenter; text: "Создать"; color: fm.textMain; font { family: fm.font; pixelSize: 14 } }
                    FIcon { name: "down"; width: 14; height: 14; color: fm.textSub; stroke: 1.8; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; enabled: fm.page === "folder"; cursorShape: Qt.PointingHandCursor
                                onClicked: { var p = mapToItem(frame, 0, height + 6); menu.show([
                                    { label: "Папку", icon: "folder", act: function() { fm.create("mkdir") } },
                                    { label: "Текстовый документ", icon: "document", act: function() { fm.create("txt") } },
                                    { label: "Пустой файл", icon: "document", act: function() { fm.create("file") } }], p.x, p.y) } }
                }
                Item { width: 14; height: 1 }
                Btn { icon: "cut"; label: "Вырезать"; enabledState: fm.selPaths.length > 0 && fm.page !== "trash"; onClicked: fm.setClip("move") }
                Btn { icon: "copy"; label: "Копировать"; enabledState: fm.selPaths.length > 0 && fm.page !== "trash"; onClicked: fm.setClip("copy") }
                Btn { icon: "paste"; label: "Вставить"; enabledState: fm.page === "folder"; onClicked: fm.paste() }
                Btn { visible: fm.page !== "trash"; icon: "trash"; label: "Удалить"; enabledState: fm.selPaths.length > 0 && fm.page !== "computer"; onClicked: fm.trashSel() }
                Btn { visible: fm.page === "trash"; icon: "restore"; label: "Восстановить"; enabledState: fm.selPaths.length > 0; onClicked: fm.restoreSel() }
                Btn { visible: fm.page === "trash"; icon: "trash"; label: "Удалить навсегда"; enabledState: fm.selPaths.length > 0; onClicked: fm.askDelete(true) }
                Btn { visible: fm.page === "trash"; icon: "trash"; label: "Очистить корзину"; enabledState: fm.rows.length > 0; onClicked: fm.emptyTrash() }
                Item { width: 4; height: 1 }
                Sep { anchors.verticalCenter: parent.verticalCenter }
                Item { width: 4; height: 1 }
                Btn {
                    icon: "sort"; label: "Сортировать"; hasMenu: true
                    onClicked: (gx, gy) => menu.show([
                        { label: "Имя", check: fm.sortKey === "name", act: function() { fm.sortKey = "name" } },
                        { label: "Дата изменения", check: fm.sortKey === "modified", act: function() { fm.sortKey = "modified" } },
                        { label: "Тип", check: fm.sortKey === "type", act: function() { fm.sortKey = "type" } },
                        { label: "Размер", check: fm.sortKey === "size", act: function() { fm.sortKey = "size" } },
                        { sep: true },
                        { label: "По возрастанию", check: !fm.sortDesc, act: function() { fm.sortDesc = false } },
                        { label: "По убыванию", check: fm.sortDesc, act: function() { fm.sortDesc = true } }], gx, gy)
                }
                Btn {
                    icon: fm.view === "grid" ? "grid" : "list"; label: "Вид"; hasMenu: true
                    onClicked: (gx, gy) => menu.show([
                        { label: "Таблица", icon: "list", check: fm.view === "list", act: function() { fm.view = "list"; fm.saveCfg() } },
                        { label: "Плитки", icon: "grid", check: fm.view === "grid", act: function() { fm.view = "grid"; fm.saveCfg() } },
                        { sep: true },
                        { label: "Панель сведений", check: fm.showDetails, act: function() { fm.showDetails = !fm.showDetails; fm.saveCfg() } },
                        { label: "Скрытые файлы", check: fm.showHidden, act: function() { fm.showHidden = !fm.showHidden; fm.saveCfg() } }], gx, gy)
                }
                Item { width: 4; height: 1 }
                Sep { anchors.verticalCenter: parent.verticalCenter }
                Item { width: 4; height: 1 }
                Btn {
                    icon: "more"; iconSize: 22
                    onClicked: (gx, gy) => menu.show(fm.moreItems(), gx, gy)
                }
            }

            // --- боковая панель ---
            Column {
                id: side
                anchors { left: parent.left; leftMargin: 18; top: toolBar.bottom; topMargin: 12 }
                width: 214
                spacing: 3
                NavItem { icon: "star"; label: "Быстрый доступ"; on: fm.page === "quick"; onClicked: fm.go("quick", fm.home) }
                NavItem { icon: "desktop"; iconColor: "#4fa3f7"; label: "Рабочий стол"; on: fm.page === "folder" && fm.path === fm.home + "/Desktop"; onClicked: fm.standard("Desktop") }
                NavItem { icon: "download"; iconColor: "#4cc38a"; label: "Загрузки"; on: fm.page === "folder" && fm.path === fm.home + "/Downloads"; onClicked: fm.standard("Downloads") }
                NavItem { icon: "document"; iconColor: "#c9cfdc"; label: "Документы"; on: fm.page === "folder" && fm.path === fm.home + "/Documents"; onClicked: fm.standard("Documents") }
                NavItem { icon: "image"; iconColor: "#55a7f2"; label: "Изображения"; on: fm.page === "folder" && fm.path === fm.home + "/Pictures"; onClicked: fm.standard("Pictures") }
                NavItem { icon: "video"; iconColor: "#ffffff"; iconFill: "#8b5cf6"; label: "Видео"; on: fm.page === "folder" && fm.path === fm.home + "/Videos"; onClicked: fm.standard("Videos") }
                NavItem { icon: "music"; iconColor: "#f472b6"; label: "Музыка"; on: fm.page === "folder" && fm.path === fm.home + "/Music"; onClicked: fm.standard("Music") }
                NavItem { icon: "folder"; iconColor: fm.folderYellow; iconFill: fm.folderYellow; label: "Проекты"; on: fm.page === "folder" && fm.path === fm.home + "/Projects"; onClicked: fm.standard("Projects") }
                Item { width: parent.width; height: 22; Rectangle { anchors.centerIn: parent; width: parent.width - 30; height: 1; color: Qt.rgba(1, 1, 1, 0.13) } }
                NavItem { icon: "computer"; label: "Этот компьютер"; on: fm.page === "computer"; onClicked: fm.go("computer", fm.home) }
                NavItem { icon: "folder"; label: "Домашняя папка"; on: fm.page === "folder" && fm.path === fm.home; onClicked: fm.go("folder", fm.home) }
                NavItem { icon: "trash"; label: "Корзина"; on: fm.page === "trash"; onClicked: fm.go("trash", fm.home) }
            }
            Rectangle { anchors { left: side.right; leftMargin: 12; top: side.top; bottom: parent.bottom; bottomMargin: 14 } width: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            // --- содержимое ---
            Rectangle {
                id: content
                anchors { left: side.right; leftMargin: 26; top: toolBar.bottom; topMargin: 10; bottom: parent.bottom; bottomMargin: 14
                          right: details.visible ? details.left : parent.right; rightMargin: details.visible ? 12 : 14 }
                radius: 12; color: fm.panelBg; border.width: 1; border.color: fm.line
                clip: true
                MouseArea {   // клик по пустому месту — снять выделение; правая кнопка — меню папки
                    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => { fm.sel = ({}); fm.cur = -1; frame.forceActiveFocus(); if (m.button === Qt.RightButton) { var p = mapToItem(frame, m.x, m.y); menu.show(fm.bgItems(), p.x, p.y) } }
                }

                // заголовок страницы для спецразделов
                Text {
                    id: pageTitle
                    visible: fm.page === "computer" || fm.page === "search" || fm.page === "trash"
                    x: 18; y: 14; height: visible ? implicitHeight : 0
                    text: fm.page === "quick" ? "Недавние файлы" : fm.page === "computer" ? "Устройства и диски" : fm.page === "trash" ? "Корзина"
                          : (fm.searching ? "Поиск «" + fm.searchQuery + "»…" : "Результаты поиска «" + fm.searchQuery + "»: " + fm.rows.length)
                    color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium }
                }

                // закреплённые папки (Быстрый доступ)
                Flow {
                    id: pins
                    visible: fm.page === "quick"
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10
                    Text { width: parent.width; text: "Закреплённые"; color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium } }
                    Repeater {
                        model: fm.page === "quick" ? fm.pinned : []
                        Rectangle {
                            required property string modelData
                            width: 210; height: 64; radius: 10
                            color: pma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: fm.line
                            FIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "folder"; width: 34; height: 34; color: fm.folderYellow; fill: fm.folderYellow; stroke: 1 }
                            Column { x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; spacing: 2
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.substring(modelData.lastIndexOf("/") + 1); color: fm.textMain; font { family: fm.font; pixelSize: 14 } }
                                Text { width: parent.width; elide: Text.ElideMiddle; text: modelData.replace(fm.home, "~"); color: fm.textSub; font { family: fm.font; pixelSize: 11 } } }
                            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                        onClicked: (m) => { if (m.button === Qt.RightButton) { var p = mapToItem(frame, m.x, m.y); var d = modelData;
                                                       menu.show([{ label: "Открыть", icon: "open", act: function() { fm.go("folder", d) } }, { label: "Открепить", icon: "pin", act: function() { fm.togglePin(d) } }], p.x, p.y) }
                                                   else fm.go("folder", modelData) } }
                        }
                    }
                    Text { width: parent.width; topPadding: 8; text: "Недавние файлы"; color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium } }
                }

                // диски (Этот компьютер)
                Flow {
                    visible: fm.page === "computer"
                    anchors { left: parent.left; right: parent.right; top: pageTitle.bottom; margins: 14 }
                    spacing: 12
                    Repeater {
                        model: fm.page === "computer" ? fm.drives : []
                        Rectangle {
                            required property var modelData
                            width: 320; height: 96; radius: 12
                            color: dma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: fm.line
                            FIcon { x: 16; y: 18; name: modelData.removable ? "usb" : "drive"; width: 40; height: 40; color: modelData.removable ? "#9be7c4" : "#c9cbff"; stroke: 1.4 }
                            Column {
                                x: 70; y: 16; width: parent.width - 86 - (modelData.removable ? 30 : 0); spacing: 6
                                Text { width: parent.width; elide: Text.ElideRight
                                       text: modelData.mount === "/" ? "Системный диск  (/)"
                                           : modelData.removable ? (modelData.label || "Съёмный диск") + "  (" + modelData.dev.replace("/dev/", "") + ")"
                                           : modelData.mount.substring(modelData.mount.lastIndexOf("/") + 1) + "  (" + modelData.mount + ")"
                                       color: fm.textMain; font { family: fm.font; pixelSize: 14 } }
                                Rectangle { width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1)
                                    Rectangle { visible: !!modelData.mount; width: parent.width * modelData.used / Math.max(1, modelData.size); height: parent.height; radius: 4; color: modelData.used / modelData.size > 0.9 ? "#e5484d" : fm.accent } }
                                Text { text: modelData.mount ? "Свободно " + FT.size(modelData.avail) + " из " + FT.size(modelData.size) + " · " + modelData.fs
                                                             : "Не подключён · " + FT.size(modelData.size) + " · нажмите, чтобы открыть"
                                       color: fm.textSub; font { family: fm.font; pixelSize: 12 } }
                            }
                            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fm.openDrive(modelData) }
                            Rectangle {
                                visible: !!modelData.removable && !!modelData.mount
                                anchors { right: parent.right; top: parent.top; margins: 10 }
                                width: 28; height: 28; radius: 7; color: ema.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                FIcon { anchors.centerIn: parent; name: "eject"; width: 16; height: 16; color: fm.textSub }
                                MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fm.ejectDrive(modelData) }
                            }
                        }
                    }
                }

                // таблица
                Item {
                    id: table
                    visible: fm.view === "list" && fm.page !== "computer"
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: fm.page === "quick" ? pins.bottom : (pageTitle.visible ? pageTitle.bottom : parent.top)
                              topMargin: fm.page === "quick" ? 4 : (pageTitle.visible ? 8 : 0); leftMargin: 6; rightMargin: 6 }
                    readonly property var cols: fm.page === "trash"
                        ? [{ k: "name", t: "Имя", w: 0 }, { k: "orig", t: "Исходное расположение", w: 260 }, { k: "modified", t: "Дата удаления", w: 170 }, { k: "size", t: "Размер", w: 100 }]
                        : (fm.page === "search" || fm.page === "quick")
                            ? [{ k: "name", t: "Имя", w: 0 }, { k: "where", t: "Папка", w: 230 }, { k: "modified", t: "Дата изменения", w: 170 }, { k: "size", t: "Размер", w: 100 }]
                            : [{ k: "name", t: "Имя", w: 0 }, { k: "modified", t: "Дата изменения", w: 180 }, { k: "type", t: "Тип", w: 170 }, { k: "size", t: "Размер", w: 100 }]
                    readonly property real fixed: { var s = 0; cols.forEach(function(c) { s += c.w; }); return s; }
                    function cw(c) { return c.w > 0 ? c.w : Math.max(180, width - fixed - 8); }

                    Row {
                        id: head
                        y: 8; height: 44
                        Repeater {
                            model: table.cols
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool sorted: fm.sortKey === modelData.k
                                width: table.cw(modelData); height: 44; radius: 8
                                color: hm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                Rectangle { visible: index > 0; width: 1; height: 28; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.1) }
                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 8
                                    Text { text: modelData.t; color: parent.parent.sorted ? "#b9bcff" : fm.textSub; font { family: fm.font; pixelSize: 14 } }
                                    FIcon { visible: parent.parent.sorted; name: fm.sortDesc ? "down" : "upsmall"; width: 15; height: 15; color: "#b9bcff"; stroke: 1.8; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { var k = modelData.k === "where" || modelData.k === "orig" ? "name" : modelData.k;
                                                         if (fm.sortKey === k) fm.sortDesc = !fm.sortDesc; else { fm.sortKey = k; fm.sortDesc = k === "modified" || k === "size"; } } }
                            }
                        }
                    }
                    ListView {
                        id: list
                        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 2 }
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: fm.rows
                        currentIndex: fm.cur
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                        highlightFollowsCurrentItem: false
                        cacheBuffer: 600
                        delegate: Item {
                            id: rowItem
                            required property var modelData
                            required property int index
                            width: list.width; height: 46
                            readonly property bool selected: fm.sel[modelData.path] === true
                            Rectangle {
                                anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                                radius: 9
                                color: rowItem.selected ? Qt.rgba(0.40, 0.42, 0.95, 0.42) : (rma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.width: rowItem.selected ? 1 : 0; border.color: Qt.rgba(0.62, 0.65, 1, 0.75)
                            }
                            Rectangle { visible: !rowItem.selected; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6 } height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: table.cols
                                    Item {
                                        required property var modelData
                                        required property int index
                                        width: table.cw(modelData); height: rowItem.height
                                        readonly property var r: rowItem.modelData
                                        Item {
                                            visible: index === 0
                                            anchors.fill: parent
                                            FIcon { visible: r.isdir; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; name: "folder"; color: fm.folderYellow; fill: fm.folderYellow; stroke: 1 }
                                            Image { visible: !r.isdir; x: 13; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; sourceSize: Qt.size(52, 52)
                                                    asynchronous: true; source: r.isdir ? "" : fm.mimeIcon(r.name, false) }
                                            Text { x: 52; width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                                   text: r.name; color: fm.textMain; font { family: fm.font; pixelSize: 14 } opacity: r.name.charAt(0) === "." ? 0.6 : 1 }
                                        }
                                        Text {
                                            visible: index > 0
                                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: modelData.k === "size" ? Text.AlignRight : Text.AlignLeft
                                            elide: modelData.k === "orig" || modelData.k === "where" ? Text.ElideMiddle : Text.ElideRight
                                            color: fm.textSub; font { family: fm.font; pixelSize: 13 }
                                            text: modelData.k === "modified" ? (fm.page === "trash" && r.deleted ? FT.date(new Date(r.deleted)) : FT.date(r.modified))
                                                : modelData.k === "type" ? FT.typeName(r.name, r.isdir)
                                                : modelData.k === "size" ? (r.isdir ? "—" : FT.size(r.size))
                                                : modelData.k === "orig" ? String(r.orig || "").replace(fm.home, "~")
                                                : modelData.k === "where" ? r.path.substring(0, r.path.lastIndexOf("/")).replace(fm.home, "~") : ""
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
                                    frame.forceActiveFocus();
                                    if (m.button === Qt.RightButton) { if (!rowItem.selected) fm.clickRow(rowItem.index, 0); var p = mapToItem(frame, m.x, m.y); menu.show(fm.itemItems(), p.x, p.y); }
                                    else fm.clickRow(rowItem.index, m.modifiers);
                                }
                                onDoubleClicked: fm.openRow(rowItem.modelData)
                            }
                        }
                    }
                }

                // плитки
                GridView {
                    id: tiles
                    visible: fm.view === "grid" && fm.page !== "computer"
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: fm.page === "quick" ? pins.bottom : (pageTitle.visible ? pageTitle.bottom : parent.top); margins: 10 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 150))); cellHeight: 150
                    model: fm.rows
                    currentIndex: fm.cur
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        width: tiles.cellWidth; height: tiles.cellHeight
                        readonly property bool selected: fm.sel[modelData.path] === true
                        Rectangle {
                            anchors { fill: parent; margins: 5 }
                            radius: 10
                            color: tile.selected ? Qt.rgba(0.40, 0.42, 0.95, 0.42) : (tma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.width: tile.selected ? 1 : 0; border.color: Qt.rgba(0.62, 0.65, 1, 0.75)
                            FIcon { visible: tile.modelData.isdir; anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 76; height: 76; name: "folder"; color: fm.folderYellow; fill: fm.folderYellow; stroke: 0.8 }
                            Image {
                                visible: !tile.modelData.isdir
                                anchors.horizontalCenter: parent.horizontalCenter; y: 14; width: 80; height: 72
                                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                sourceSize: Qt.size(160, 144)
                                source: tile.modelData.isdir ? "" : (FT.isImage(tile.modelData.name) ? "file://" + tile.modelData.path : fm.mimeIcon(tile.modelData.name, false))
                            }
                            Text { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 } height: 36
                                   text: tile.modelData.name; color: fm.textMain; font { family: fm.font; pixelSize: 12 }
                                   horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: tma
                            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (m) => { frame.forceActiveFocus();
                                if (m.button === Qt.RightButton) { if (!tile.selected) fm.clickRow(tile.index, 0); var p = mapToItem(frame, m.x, m.y); menu.show(fm.itemItems(), p.x, p.y); }
                                else fm.clickRow(tile.index, m.modifiers); }
                            onDoubleClicked: fm.openRow(tile.modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: fm.rows.length === 0 && fm.page !== "computer" && !(fm.page === "quick")
                    text: fm.searching ? "Поиск…" : (fm.page === "trash" ? "Корзина пуста" : (fm.page === "search" ? "Ничего не найдено" : (fm.searchText !== "" ? "Ничего не найдено" : "Папка пуста")))
                    color: fm.textSub; font { family: fm.font; pixelSize: 15 }
                }
                // всплывающее сообщение
                Rectangle {
                    visible: fm.toast !== ""
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
                    width: tt.implicitWidth + 32; height: 38; radius: 10
                    color: Qt.rgba(0.08, 0.08, 0.16, 0.92); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                    Text { id: tt; anchors.centerIn: parent; text: fm.toast; color: fm.textMain; font { family: fm.font; pixelSize: 13 } }
                }
            }

            // --- панель сведений ---
            Rectangle {
                id: details
                visible: fm.showDetails && frame.width > 1100 && fm.page !== "computer"
                anchors { right: parent.right; rightMargin: 14; top: toolBar.bottom; topMargin: 10; bottom: parent.bottom; bottomMargin: 14 }
                width: 300; radius: 12; color: fm.panelBg; border.width: 1; border.color: fm.line
                clip: true
                readonly property var r: fm.focusRow
                readonly property string dname: r ? r.name : (fm.page === "folder" ? (fm.path === "/" ? "/" : fm.path.substring(fm.path.lastIndexOf("/") + 1)) : "")
                readonly property bool isdir: r ? r.isdir : true
                readonly property string dpath: fm.detailPath

                Flickable {
                    anchors.fill: parent
                    contentHeight: dcol.implicitHeight + 24
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: dcol
                        x: 18; y: 18; width: parent.width - 36
                        spacing: 12
                        visible: details.dpath !== "" || fm.selPaths.length > 1

                        Rectangle {   // превью
                            width: parent.width; height: 170; radius: 12; color: Qt.rgba(1, 1, 1, 0.03)
                            Rectangle {
                                anchors.centerIn: parent; width: 104; height: 104; radius: 22
                                visible: !prev.visible
                                color: Qt.rgba(0.05, 0.05, 0.1, 0.55); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                FIcon { visible: details.isdir; anchors.centerIn: parent; width: 62; height: 62; name: "folder"; color: fm.folderYellow; fill: fm.folderYellow; stroke: 0.8 }
                                Image { visible: !details.isdir; anchors.centerIn: parent; width: 60; height: 60; sourceSize: Qt.size(120, 120); source: details.isdir ? "" : fm.mimeIcon(details.dname, false) }
                            }
                            Image {
                                id: prev
                                anchors { fill: parent; margins: 8 }
                                visible: !details.isdir && FT.isImage(details.dname) && status === Image.Ready
                                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                sourceSize: Qt.size(560, 320)
                                source: !details.isdir && FT.isImage(details.dname) ? "file://" + details.dpath : ""
                            }
                        }
                        Column {
                            width: parent.width; spacing: 4
                            Text { width: parent.width; text: fm.selPaths.length > 1 ? "Выбрано объектов: " + fm.selPaths.length : details.dname; elide: Text.ElideMiddle
                                   color: fm.textMain; font { family: fm.font; pixelSize: 18; weight: Font.Medium } }
                            Text { visible: fm.selPaths.length <= 1; text: FT.typeName(details.dname, details.isdir).replace("Папка с файлами", "Папка") + (fm.info ? " · " + FT.size(fm.info.size) + (fm.info.partial ? "+" : "") : "")
                                   color: fm.textSub; font { family: fm.font; pixelSize: 13 } }
                        }
                        Row {
                            visible: fm.selPaths.length <= 1 && fm.page !== "trash"
                            spacing: 10
                            Rectangle {
                                width: 186; height: 44; radius: 10
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "#5b5ff0" } GradientStop { position: 1; color: "#6f74f2" } }
                                border.width: 1; border.color: Qt.rgba(0.7, 0.72, 1, 0.6)
                                opacity: oma.containsMouse ? 0.88 : 1
                                Row { anchors.centerIn: parent; spacing: 10
                                    FIcon { name: "open"; width: 19; height: 19; color: "white"; stroke: 1.7; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Открыть"; color: "white"; font { family: fm.font; pixelSize: 14 } } }
                                MouseArea { id: oma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (details.r) fm.openRow(details.r); else Quickshell.execDetached(["gio", "open", details.dpath]) }
                            }
                            Rectangle {
                                width: 44; height: 44; radius: 10; color: dmm.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: fm.line
                                FIcon { anchors.centerIn: parent; name: "more"; width: 20; height: 20; color: fm.textMain }
                                MouseArea { id: dmm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { var p = mapToItem(frame, 0, height + 6); menu.show(details.r ? fm.itemItems() : fm.bgItems(), p.x - 160, p.y) } }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                        Text { text: "Сведения"; color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium } }
                        Repeater {
                            model: fm.selPaths.length > 1 ? [] : [
                                ["Тип", FT.typeName(details.dname, details.isdir)],
                                ["Размер", fm.info ? FT.size(fm.info.size) + (fm.info.partial ? " и больше" : "") : "…"],
                                ["Расположение", (function() { var p = details.dpath; var d = p.substring(0, p.lastIndexOf("/")); return d === "" ? "/" : (d === fm.home ? "Домашняя папка" : d.substring(d.lastIndexOf("/") + 1)); })()],
                                ["Дата изменения", fm.info ? FT.date(fm.info.modified * 1000) : "…"],
                                ["Дата создания", fm.info ? (fm.info.created ? FT.date(fm.info.created * 1000) : "—") : "…"]
                            ]
                            Item {
                                required property var modelData
                                width: dcol.width; height: 24
                                Text { text: modelData[0]; color: fm.textSub; font { family: fm.font; pixelSize: 13 } anchors.verticalCenter: parent.verticalCenter }
                                Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: parent.width * 0.58; horizontalAlignment: Text.AlignRight
                                       elide: Text.ElideLeft; text: modelData[1]; color: fm.textMain; font { family: fm.font; pixelSize: 13 } }
                            }
                        }

                        Column {
                            visible: fm.selPaths.length <= 1 && fm.page !== "trash" && fm.info !== null
                            width: parent.width; spacing: 10
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }
                            Text { text: "Теги"; color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium } }
                            Flow {
                                width: parent.width; spacing: 8
                                Repeater {
                                    model: fm.info ? fm.info.tags : []
                                    Rectangle {
                                        required property string modelData
                                        required property int index
                                        width: tg.implicitWidth + 28; height: 30; radius: 15
                                        color: Qt.alpha(fm.tagColors[index % fm.tagColors.length], tgm.containsMouse ? 0.6 : 0.42)
                                        border.width: 1; border.color: Qt.alpha(fm.tagColors[index % fm.tagColors.length], 0.9)
                                        Text { id: tg; anchors.centerIn: parent; text: tgm.containsMouse ? modelData + "  ×" : modelData; color: "white"; font { family: fm.font; pixelSize: 13 } }
                                        MouseArea { id: tgm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: fm.setTags(fm.info.tags.filter(function(t) { return t !== modelData; })) }
                                    }
                                }
                                Rectangle {
                                    width: tagIn.visible ? 120 : 36; height: 30; radius: 15; color: Qt.rgba(1, 1, 1, 0.06); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                                    FIcon { visible: !tagIn.visible; anchors.centerIn: parent; name: "plus"; width: 16; height: 16; color: fm.textMain; stroke: 1.8 }
                                    MouseArea { anchors.fill: parent; visible: !tagIn.visible; cursorShape: Qt.PointingHandCursor; onClicked: { tagIn.visible = true; tagIn.text = ""; tagIn.forceActiveFocus() } }
                                    TextInput {
                                        id: tagIn; visible: false
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter
                                        color: fm.textMain; font { family: fm.font; pixelSize: 13 } clip: true
                                        onAccepted: { var t = text.trim().replace(/,/g, " "); visible = false; frame.forceActiveFocus();
                                                      if (t && fm.info.tags.indexOf(t) < 0) fm.setTags(fm.info.tags.concat([t])); }
                                        onActiveFocusChanged: if (!activeFocus) visible = false
                                        Keys.onEscapePressed: { visible = false; frame.forceActiveFocus() }
                                    }
                                }
                            }
                            Text { text: "Примечание"; color: fm.textMain; font { family: fm.font; pixelSize: 15; weight: Font.Medium } }
                            Rectangle {
                                width: parent.width; height: Math.max(84, noteEdit.contentHeight + 22); radius: 10
                                color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: noteEdit.activeFocus ? Qt.rgba(0.6, 0.62, 1, 0.7) : Qt.rgba(1, 1, 1, 0.14)
                                TextEdit {
                                    id: noteEdit
                                    anchors { fill: parent; margins: 11 }
                                    wrapMode: TextEdit.Wrap
                                    color: fm.textSub; font { family: fm.font; pixelSize: 13 } selectionColor: Qt.rgba(0.44, 0.45, 0.95, 0.5)
                                    text: fm.info ? fm.info.note : ""
                                    onActiveFocusChanged: if (!activeFocus && fm.info) fm.setNote(text)
                                    Keys.onEscapePressed: frame.forceActiveFocus()
                                    Text { visible: parent.text === "" && !parent.activeFocus; text: "Добавьте примечание…"; color: Qt.rgba(1, 1, 1, 0.35); font: parent.font }
                                }
                            }
                        }
                    }
                }
            }

            // --- меню ---
            MouseArea { anchors.fill: parent; visible: menu.visible; z: 49; acceptedButtons: Qt.AllButtons; onPressed: menu.visible = false }
            Rectangle {
                id: menu
                visible: false; z: 50
                width: 250; height: mcol.implicitHeight + 12
                radius: 12; color: Qt.rgba(0.10, 0.10, 0.19, 0.97)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                property var items: []
                function show(it, gx, gy) {
                    items = it;
                    var h = 12; it.forEach(function(i) { h += i.sep ? 9 : 38; });
                    x = Math.max(8, Math.min(gx, frame.width - width - 8));
                    y = Math.max(8, Math.min(gy, frame.height - h - 8));
                    visible = true;
                }
                Column {
                    id: mcol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    Repeater {
                        model: menu.items
                        Item {
                            required property var modelData
                            width: mcol.width; height: modelData.sep ? 9 : 38
                            Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                            Rectangle {
                                visible: !modelData.sep
                                anchors.fill: parent; radius: 8
                                color: mi.containsMouse ? Qt.rgba(0.42, 0.44, 0.95, 0.4) : "transparent"
                                FIcon { visible: !!modelData.icon; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; name: modelData.icon || ""; color: modelData.danger ? "#ff8a8d" : fm.textMain; stroke: 1.5 }
                                Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: modelData.label || ""; color: modelData.danger ? "#ff8a8d" : fm.textMain; font { family: fm.font; pixelSize: 13 } }
                                Text { visible: modelData.check !== undefined && modelData.check; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✓"; color: "#b9bcff"; font.pixelSize: 14 }
                                Text { visible: !!modelData.key; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: modelData.key || ""; color: fm.textSub; font { family: fm.font; pixelSize: 11 } }
                                MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; onClicked: { menu.visible = false; if (modelData.act) modelData.act(); } }
                            }
                        }
                    }
                }
            }

            // --- диалог ---
            Rectangle {
                id: dialog
                visible: false; z: 100; anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45)
                property string title: ""; property string text: ""; property string confirm: "OK"; property bool danger: false
                property bool hasInput: false
                property var action: null
                function show(t, tx, input, conf, dang, act) {
                    title = t; text = tx; confirm = conf; danger = dang; action = act;
                    hasInput = input !== ""; dlgIn.text = input; visible = true;
                    if (hasInput) { dlgIn.forceActiveFocus(); var dot = input.lastIndexOf("."); dlgIn.select(0, dot > 0 ? dot : input.length); }
                    else dlgBox.forceActiveFocus();
                }
                function accept() { visible = false; frame.forceActiveFocus(); if (action) action(dlgIn.text); }
                function cancel() { visible = false; frame.forceActiveFocus(); }
                MouseArea { anchors.fill: parent; onClicked: dialog.cancel() }
                Rectangle {
                    id: dlgBox
                    anchors.centerIn: parent; width: 440; height: dc.implicitHeight + 44; radius: 14
                    color: Qt.rgba(0.10, 0.10, 0.19, 0.98); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                    Keys.onReturnPressed: dialog.accept(); Keys.onEscapePressed: dialog.cancel()
                    MouseArea { anchors.fill: parent }
                    Column {
                        id: dc
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                        spacing: 14
                        Text { width: parent.width; text: dialog.title; wrapMode: Text.Wrap; color: fm.textMain; font { family: fm.font; pixelSize: 17; weight: Font.Medium } }
                        Text { width: parent.width; text: dialog.text; wrapMode: Text.Wrap; color: fm.textSub; font { family: fm.font; pixelSize: 13 } }
                        Rectangle {
                            visible: dialog.hasInput; width: parent.width; height: 40; radius: 9; color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Qt.rgba(0.6, 0.62, 1, 0.7)
                            TextInput { id: dlgIn; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; clip: true
                                        color: fm.textMain; font { family: fm.font; pixelSize: 14 } selectionColor: Qt.rgba(0.44, 0.45, 0.95, 0.5)
                                        onAccepted: dialog.accept(); Keys.onEscapePressed: dialog.cancel() }
                        }
                        Row {
                            spacing: 10; layoutDirection: Qt.RightToLeft; width: parent.width
                            Rectangle { width: dok.implicitWidth + 34; height: 38; radius: 9; color: dialog.danger ? "#d9474c" : fm.accent
                                        Text { id: dok; anchors.centerIn: parent; text: dialog.confirm; color: "white"; font { family: fm.font; pixelSize: 13 } }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dialog.accept() } }
                            Rectangle { width: dno.implicitWidth + 34; height: 38; radius: 9; color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: fm.line
                                        Text { id: dno; anchors.centerIn: parent; text: "Отмена"; color: fm.textMain; font { family: fm.font; pixelSize: 13 } }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dialog.cancel() } }
                        }
                    }
                }
            }
        }
    }

    // ---------- хлебные крошки ----------
    readonly property var crumbs: {
        if (page === "quick") return [{ label: "Быстрый доступ", icon: "star", act: function() { fm.go("quick", fm.home) } }];
        if (page === "computer") return [{ label: "Этот компьютер", icon: "computer", act: function() {} }];
        if (page === "trash") return [{ label: "Корзина", icon: "trash", act: function() {} }];
        if (page === "search") return [{ label: "Поиск: " + searchQuery, icon: "search", act: function() {} }];
        var out = [], p = path, base = "", rest = p;
        if (p === home || p.indexOf(home + "/") === 0) { out.push({ label: "Домой", icon: "homefill", p: home }); base = home; rest = p.substring(home.length); }
        else { out.push({ label: "Компьютер", icon: "computer", p: "/" }); base = ""; }
        rest.split("/").filter(function(x) { return x !== ""; }).forEach(function(seg) { base += "/" + seg; out.push({ label: seg, p: base }); });
        if (out.length > 6) out = [out[0], { label: "…", p: out[out.length - 5].p }].concat(out.slice(out.length - 4));
        return out.map(function(c) { var t = c.p; return { label: c.label, icon: c.icon, act: function() { fm.go("folder", t) } }; });
    }
    function editPath() { pathEdit.text = page === "folder" ? path : home; pathEdit.visible = true; pathEdit.selectAll(); pathEdit.forceActiveFocus(); }

    // ---------- меню ----------
    function itemItems() {
        var it = [], r = focusRow, n = selPaths.length;
        if (page === "trash") {
            return [{ label: "Восстановить", icon: "restore", act: restoreSel }, { label: "Удалить навсегда", icon: "trash", danger: true, act: function() { askDelete(true) } }];
        }
        if (r) it.push({ label: "Открыть", icon: "open", key: "Enter", act: function() { openRow(r) } });
        if ((page === "search" || page === "quick") && r) it.push({ label: "Показать в папке", icon: "folder", act: function() { fm.pendingSelect = r.path; go("folder", r.path.substring(0, r.path.lastIndexOf("/")) || "/") } });
        if (r && !r.isdir && isArchive(r.name)) it.push({ label: "Извлечь сюда", icon: "archive", act: function() { extract(r.path) } });
        if (n) it.push({ label: "Добавить в архив ZIP", icon: "archive", act: function() { archive("zip") } });
        if (n) it.push({ label: "Добавить в архив 7z", icon: "archive", act: function() { archive("7z") } });
        it.push({ sep: true });
        it.push({ label: "Вырезать", icon: "cut", key: "Ctrl+X", act: function() { setClip("move") } });
        it.push({ label: "Копировать", icon: "copy", key: "Ctrl+C", act: function() { setClip("copy") } });
        if (r && r.isdir && clip.paths.length) it.push({ label: "Вставить в папку", icon: "paste", act: function() { var keep = path; path = r.path; paste(); path = keep; } });
        if (n === 1) it.push({ label: "Переименовать", icon: "rename", key: "F2", act: rename });
        it.push({ label: "Копировать путь", icon: "link", act: copyPath });
        if (r && r.isdir) it.push({ label: pinned.indexOf(r.path) >= 0 ? "Открепить из быстрого доступа" : "Закрепить в быстром доступе", icon: "pin", act: function() { togglePin(r.path) } });
        if (r && r.isdir) it.push({ label: "Открыть в терминале", icon: "terminal", act: terminalHere });
        it.push({ sep: true });
        it.push({ label: "Удалить", icon: "trash", key: "Del", danger: true, act: trashSel });
        return it;
    }
    function bgItems() {
        var it = [];
        if (page === "folder") {
            it.push({ label: "Создать папку", icon: "folder", key: "Ctrl+Shift+N", act: function() { create("mkdir") } });
            it.push({ label: "Создать текстовый документ", icon: "document", act: function() { create("txt") } });
            it.push({ label: "Вставить", icon: "paste", key: "Ctrl+V", act: paste });
            it.push({ sep: true });
            it.push({ label: pinned.indexOf(path) >= 0 ? "Открепить папку" : "Закрепить папку в быстром доступе", icon: "pin", act: function() { togglePin(path) } });
            it.push({ label: "Открыть терминал здесь", icon: "terminal", act: terminalHere });
        }
        it.push({ label: "Обновить", icon: "refresh", key: "F5", act: refresh });
        return it;
    }
    function moreItems() {
        var it = bgItems();
        it.push({ sep: true });
        it.push({ label: "Выделить всё", key: "Ctrl+A", act: selectAll });
        it.push({ label: "Копировать путь", icon: "link", act: copyPath });
        it.push({ label: "Скрытые файлы", icon: "eye", check: showHidden, key: "Ctrl+H", act: function() { showHidden = !showHidden; saveCfg() } });
        return it;
    }

    // ---------- клавиатура ----------
    function key(e) {
        var ctrl = (e.modifiers & Qt.ControlModifier) !== 0, alt = (e.modifiers & Qt.AltModifier) !== 0, shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        var cols = view === "grid" ? Math.max(1, Math.floor(tiles.width / tiles.cellWidth)) : 1;
        if (e.key === Qt.Key_Escape) { if (menu.visible) menu.visible = false; else if (searchText !== "") searchText = ""; else sel = ({}); }
        else if (alt && e.key === Qt.Key_Left) back();
        else if (alt && e.key === Qt.Key_Right) forward();
        else if (alt && e.key === Qt.Key_Up) up();
        else if (e.key === Qt.Key_Backspace) back();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (focusRow) openRow(focusRow); }
        else if (e.key === Qt.Key_Down) moveCur(cols, e.modifiers);
        else if (e.key === Qt.Key_Up) moveCur(-cols, e.modifiers);
        else if (e.key === Qt.Key_Right && view === "grid") moveCur(1, e.modifiers);
        else if (e.key === Qt.Key_Left && view === "grid") moveCur(-1, e.modifiers);
        else if (e.key === Qt.Key_Home) moveCur(-100000, e.modifiers);
        else if (e.key === Qt.Key_End) moveCur(100000, e.modifiers);
        else if (e.key === Qt.Key_F2) rename();
        else if (e.key === Qt.Key_F5) refresh();
        else if (e.key === Qt.Key_Delete) { if (shift) askDelete(true); else trashSel(); }
        else if (ctrl && shift && e.key === Qt.Key_N) create("mkdir");
        else if (ctrl && e.key === Qt.Key_A) selectAll();
        else if (ctrl && e.key === Qt.Key_C) setClip("copy");
        else if (ctrl && e.key === Qt.Key_X) setClip("move");
        else if (ctrl && e.key === Qt.Key_V) paste();
        else if (ctrl && e.key === Qt.Key_H) { showHidden = !showHidden; saveCfg(); }
        else if (ctrl && e.key === Qt.Key_L) editPath();
        else if (ctrl && (e.key === Qt.Key_F || e.key === Qt.Key_E)) { searchIn.forceActiveFocus(); searchIn.selectAll(); }
        else if (ctrl && e.key === Qt.Key_W) shown = false;
        else if (!ctrl && !alt && e.text.length === 1 && e.text.trim() !== "") {   // как в Проводнике: переход к имени по первой букве
            var ch = e.text.toLowerCase();
            for (var k = 1; k <= rows.length; k++) { var i = (cur + k) % rows.length; if (rows[i].name.toLowerCase().indexOf(ch) === 0) { clickRow(i, 0); break; } }
        }
        else return;
        e.accepted = true;
    }
}
