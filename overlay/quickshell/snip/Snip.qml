import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Скриншотер в стиле Lightshot: экран замораживается (кадры делает serp-shot через grim),
// выделяем область, рисуем поверх (карандаш, линия, стрелка, прямоугольник, маркер, текст),
// затем копируем в буфер (Ctrl+C) или сохраняем в ~/Pictures/Screenshots (Ctrl+S).
Scope {
    id: snip
    property bool active: false
    property string dir: ""
    property string stamp: ""
    property string selScreen: ""          // монитор, на котором выделение
    property string focusScreen: ""        // монитор с фокусом на момент запуска
    // клавиатура у оверлея под курсором (чтобы на любом мониторе можно было выделять);
    // во время перетаскивания и ввода текста — у монитора с выделением
    readonly property string cursorScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    property bool holdFocus: false
    readonly property string keyScreen: (holdFocus && selScreen !== "") ? selScreen : (cursorScreen !== "" ? cursorScreen : focusScreen)

    property string tool: "none"           // none | pen | line | arrow | rect | marker | text
    property color penColor: "#ff3b30"
    property real penSize: 3
    property var shapes: []                // в координатах экрана (логических)
    property int rev: 0
    property bool busy: false
    readonly property var swatches: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#00c7be", "#0a84ff", "#bf5af2", "#ffffff", "#1c1c1e"]
    readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    IpcHandler {
        target: "snip"
        function start(dir: string): void { snip.begin(dir) }
        function cancel(): void { snip.finish() }
    }

    function begin(d) {
        dir = d; stamp = String(Date.now()); shapes = []; rev++; tool = "none"; selScreen = ""; busy = false;
        focusScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        active = true;
    }
    function finish() { active = false; selScreen = ""; shapes = []; tool = "none"; busy = false; holdFocus = false }
    function addShape(s) { var a = shapes.slice(); a.push(s); shapes = a; rev++ }
    function undo() { if (shapes.length) { var a = shapes.slice(); a.pop(); shapes = a; rev++ } }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function fileName() {
        var d = new Date();
        return "Скриншот " + d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + " " + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".png";
    }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function selWin() {
        for (var i = 0; i < wins.instances.length; i++) if (wins.instances[i].sname === selScreen) return wins.instances[i];
        return null;
    }
    function winFor(name) {
        for (var i = 0; i < wins.instances.length; i++) if (wins.instances[i].sname === name) return wins.instances[i];
        return null;
    }
    // горячие клавиши работают с выделением, на каком бы мониторе ни был курсор
    function key(e, fromWin) {
        var ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        var sw = selWin();
        if (e.key === Qt.Key_Escape) { finish(); return true; }
        if (ctrl && e.key === Qt.Key_A) { var t = winFor(fromWin); if (t) { selScreen = t.sname; t.sx = 0; t.sy = 0; t.sw = t.width; t.sh = t.height; } return true; }
        if (!sw) return false;
        if (ctrl && e.key === Qt.Key_C) { sw.copy(); return true; }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { sw.copy(); return true; }
        if (ctrl && e.key === Qt.Key_S) { sw.save(); return true; }
        if (ctrl && e.key === Qt.Key_Z) { undo(); return true; }
        return false;
    }

    // служебное (проверка без мыши): выделить область на мониторе
    function selectArea(screenName, x, y, wd, ht) {
        for (var i = 0; i < wins.instances.length; i++) {
            var o = wins.instances[i];
            if (o.sname === screenName) { selScreen = screenName; o.sx = x; o.sy = y; o.sw = wd; o.sh = ht; return o; }
        }
        return null;
    }

    Variants {
        id: wins
        model: snip.active ? Quickshell.screens : []

        PanelWindow {
            id: w
            required property var modelData
            screen: modelData
            readonly property string sname: modelData.name
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "serp-snip"
            WlrLayershell.keyboardFocus: snip.keyScreen === sname ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "black"

            // выделение (логические px)
            property real sx: 0; property real sy: 0; property real sw: 0; property real sh: 0
            readonly property bool hasSel: snip.selScreen === sname && sw >= 3 && sh >= 3
            readonly property real k: frozen.sourceSize.width > 0 ? frozen.sourceSize.width / width : 1

            Connections {
                target: snip
                function onSelScreenChanged() { if (snip.selScreen !== w.sname) { w.sw = 0; w.sh = 0 } }
            }

            Image {
                id: frozen
                anchors.fill: parent
                source: snip.dir ? "file://" + snip.dir + "/" + w.sname + ".png?" + snip.stamp : ""
                cache: false; smooth: true; mipmap: true
            }

            // затемнение вне выделения
            readonly property color dimColor: Qt.rgba(0, 0, 0, 0.45)
            Rectangle { visible: !w.hasSel; anchors.fill: parent; color: w.dimColor }
            Rectangle { visible: w.hasSel; x: 0; y: 0; width: parent.width; height: w.sy; color: w.dimColor }
            Rectangle { visible: w.hasSel; x: 0; y: w.sy + w.sh; width: parent.width; height: parent.height - w.sy - w.sh; color: w.dimColor }
            Rectangle { visible: w.hasSel; x: 0; y: w.sy; width: w.sx; height: w.sh; color: w.dimColor }
            Rectangle { visible: w.hasSel; x: w.sx + w.sw; y: w.sy; width: parent.width - w.sx - w.sw; height: w.sh; color: w.dimColor }

            // то, что попадёт в файл: фрагмент кадра + рисунки
            Item {
                id: composite
                visible: w.hasSel
                x: w.sx; y: w.sy; width: w.sw; height: w.sh
                clip: true
                Image {
                    x: -w.sx; y: -w.sy; width: w.width; height: w.height
                    source: frozen.source; cache: false; smooth: true; mipmap: true
                }
                Canvas {
                    id: ink
                    anchors.fill: parent
                    property int rev: snip.rev
                    property var cur: null
                    onRevChanged: requestPaint()
                    onCurChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.setTransform(1, 0, 0, 1, 0, 0);
                        ctx.translate(-w.sx, -w.sy);
                        var list = snip.shapes.filter(function(s) { return s.screen === w.sname; });
                        if (cur) list = list.concat([cur]);
                        for (var i = 0; i < list.length; i++) w.drawShape(ctx, list[i]);
                    }
                }
            }

            function drawShape(ctx, s) {
                ctx.save();
                ctx.lineCap = "round"; ctx.lineJoin = "round";
                ctx.strokeStyle = s.color; ctx.fillStyle = s.color;
                ctx.lineWidth = s.type === "marker" ? s.size * 5 : s.size;
                ctx.globalAlpha = s.type === "marker" ? 0.4 : 1.0;
                if (s.type === "pen" || s.type === "marker") {
                    ctx.beginPath();
                    ctx.moveTo(s.pts[0].x, s.pts[0].y);
                    for (var i = 1; i < s.pts.length; i++) ctx.lineTo(s.pts[i].x, s.pts[i].y);
                    if (s.pts.length === 1) ctx.lineTo(s.pts[0].x + 0.1, s.pts[0].y);
                    ctx.stroke();
                } else if (s.type === "line" || s.type === "arrow") {
                    ctx.beginPath(); ctx.moveTo(s.x1, s.y1); ctx.lineTo(s.x2, s.y2); ctx.stroke();
                    if (s.type === "arrow") {
                        var a = Math.atan2(s.y2 - s.y1, s.x2 - s.x1), L = 10 + s.size * 3;
                        ctx.beginPath();
                        ctx.moveTo(s.x2, s.y2);
                        ctx.lineTo(s.x2 - L * Math.cos(a - 0.45), s.y2 - L * Math.sin(a - 0.45));
                        ctx.lineTo(s.x2 - L * Math.cos(a + 0.45), s.y2 - L * Math.sin(a + 0.45));
                        ctx.closePath(); ctx.fill();
                    }
                } else if (s.type === "rect") {
                    ctx.strokeRect(Math.min(s.x1, s.x2), Math.min(s.y1, s.y2), Math.abs(s.x2 - s.x1), Math.abs(s.y2 - s.y1));
                } else if (s.type === "text") {
                    ctx.font = "600 " + s.fsize + "px 'Noto Sans'";
                    ctx.textBaseline = "top";
                    var lines = String(s.text).split("\n");
                    for (var j = 0; j < lines.length; j++) ctx.fillText(lines[j], s.x, s.y + j * s.fsize * 1.25);
                }
                ctx.restore();
            }

            // рамка и ручки
            Rectangle {
                visible: w.hasSel
                x: w.sx - 1; y: w.sy - 1; width: w.sw + 2; height: w.sh + 2
                color: "transparent"; border.width: 1; border.color: "#ffffff"
                Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5) }
            }
            Repeater {
                model: w.hasSel ? ["tl", "t", "tr", "r", "br", "b", "bl", "l"] : []
                Rectangle {
                    required property string modelData
                    width: 9; height: 9; radius: 2
                    color: "#ffffff"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.6)
                    x: (modelData.indexOf("l") >= 0 ? w.sx : modelData.indexOf("r") >= 0 ? w.sx + w.sw : w.sx + w.sw / 2) - 4.5
                    y: (modelData.indexOf("t") >= 0 ? w.sy : modelData.indexOf("b") >= 0 ? w.sy + w.sh : w.sy + w.sh / 2) - 4.5
                }
            }
            // размер в пикселях
            Rectangle {
                visible: w.hasSel
                x: w.sx; y: w.sy > 30 ? w.sy - 28 : w.sy + 6
                width: sizeText.implicitWidth + 14; height: 22; radius: 5
                color: Qt.rgba(0, 0, 0, 0.7)
                Text { id: sizeText; anchors.centerIn: parent; color: "white"; font { family: "Noto Sans"; pixelSize: 12 }
                       text: Math.round(w.sw * w.k) + " × " + Math.round(w.sh * w.k) }
            }
            // подсказка до выделения
            Rectangle {
                visible: !w.hasSel && snip.selScreen === ""
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 40 }
                width: hint.implicitWidth + 32; height: 38; radius: 10
                color: Qt.rgba(0.05, 0.07, 0.08, 0.85); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                Text { id: hint; anchors.centerIn: parent; color: "#e8eef0"; font { family: "Noto Sans"; pixelSize: 13 }
                       text: "Выделите область  ·  Ctrl+A — весь экран  ·  Esc — отмена" }
            }

            // ----- мышь -----
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property string mode: ""        // new | move | resize | draw
                property string handle: ""
                property real px: 0; property real py: 0
                property real ox: 0; property real oy: 0; property real ow: 0; property real oh: 0

                function handleAt(x, y) {
                    if (!w.hasSel) return "";
                    var r = 8, l = Math.abs(x - w.sx) < r, rr = Math.abs(x - (w.sx + w.sw)) < r, t = Math.abs(y - w.sy) < r, b = Math.abs(y - (w.sy + w.sh)) < r;
                    var inX = x > w.sx - r && x < w.sx + w.sw + r, inY = y > w.sy - r && y < w.sy + w.sh + r;
                    if (t && l) return "tl"; if (t && rr) return "tr"; if (b && l) return "bl"; if (b && rr) return "br";
                    if (t && inX) return "t"; if (b && inX) return "b"; if (l && inY) return "l"; if (rr && inY) return "r";
                    return "";
                }
                function inside(x, y) { return w.hasSel && x >= w.sx && x <= w.sx + w.sw && y >= w.sy && y <= w.sy + w.sh; }

                cursorShape: {
                    var h = handleAt(mouseX, mouseY);
                    if (h === "tl" || h === "br") return Qt.SizeFDiagCursor;
                    if (h === "tr" || h === "bl") return Qt.SizeBDiagCursor;
                    if (h === "t" || h === "b") return Qt.SizeVerCursor;
                    if (h === "l" || h === "r") return Qt.SizeHorCursor;
                    if (inside(mouseX, mouseY)) return snip.tool === "none" ? Qt.SizeAllCursor : (snip.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor);
                    return Qt.CrossCursor;
                }

                onPressed: (m) => {
                    snip.holdFocus = true;
                    w.commitText();
                    if (m.button === Qt.RightButton) { snip.finish(); return; }
                    px = m.x; py = m.y; ox = w.sx; oy = w.sy; ow = w.sw; oh = w.sh;
                    var h = handleAt(m.x, m.y);
                    if (h !== "") { mode = "resize"; handle = h; return; }
                    if (inside(m.x, m.y) && snip.tool === "text") { w.startText(m.x, m.y); mode = ""; return; }
                    if (inside(m.x, m.y) && snip.tool !== "none") {
                        mode = "draw";
                        var base = { screen: w.sname, type: snip.tool, color: snip.penColor.toString(), size: snip.penSize };
                        if (snip.tool === "pen" || snip.tool === "marker") base.pts = [{ x: m.x, y: m.y }];
                        else { base.x1 = m.x; base.y1 = m.y; base.x2 = m.x; base.y2 = m.y; }
                        ink.cur = base;
                        return;
                    }
                    if (inside(m.x, m.y)) { mode = "move"; return; }
                    // новое выделение (рисунки сбрасываются)
                    mode = "new";
                    snip.selScreen = w.sname; snip.shapes = []; snip.rev++;
                    w.sx = m.x; w.sy = m.y; w.sw = 0; w.sh = 0;
                }
                onPositionChanged: (m) => {
                    if (!pressed) return;
                    var X = Math.max(0, Math.min(w.width, m.x)), Y = Math.max(0, Math.min(w.height, m.y));
                    if (mode === "new") {
                        w.sx = Math.min(px, X); w.sy = Math.min(py, Y); w.sw = Math.abs(X - px); w.sh = Math.abs(Y - py);
                    } else if (mode === "move") {
                        w.sx = Math.max(0, Math.min(w.width - ow, ox + X - px)); w.sy = Math.max(0, Math.min(w.height - oh, oy + Y - py));
                    } else if (mode === "resize") {
                        var x1 = ox, y1 = oy, x2 = ox + ow, y2 = oy + oh;
                        if (handle.indexOf("l") >= 0) x1 = X; if (handle.indexOf("r") >= 0) x2 = X;
                        if (handle.indexOf("t") >= 0) y1 = Y; if (handle.indexOf("b") >= 0) y2 = Y;
                        w.sx = Math.min(x1, x2); w.sy = Math.min(y1, y2); w.sw = Math.abs(x2 - x1); w.sh = Math.abs(y2 - y1);
                    } else if (mode === "draw" && ink.cur) {
                        var c = ink.cur;
                        if (c.pts) { c.pts.push({ x: m.x, y: m.y }); } else { c.x2 = m.x; c.y2 = m.y; }
                        ink.cur = null; ink.cur = c;
                    }
                }
                onReleased: {
                    if (!w.editing) snip.holdFocus = false;
                    if (mode === "draw" && ink.cur) { var c = ink.cur; ink.cur = null; snip.addShape(c); }
                    if (mode === "new" && !w.hasSel) { w.sw = 0; w.sh = 0; }
                    mode = "";
                }
                onWheel: (wh) => { snip.penSize = Math.max(1, Math.min(24, snip.penSize + (wh.angleDelta.y > 0 ? 1 : -1))); }
            }

            // ----- текст -----
            property bool editing: false
            function startText(x, y) {
                snip.holdFocus = true;
                textEdit.x = x; textEdit.y = y; textEdit.text = "";
                editing = true; textEdit.forceActiveFocus();
            }
            function commitText() {
                if (!editing) return;
                editing = false;
                if (textEdit.text.trim() !== "")
                    snip.addShape({ screen: w.sname, type: "text", x: textEdit.x, y: textEdit.y, text: textEdit.text, color: snip.penColor.toString(), fsize: 12 + snip.penSize * 2 });
                textEdit.text = "";
                snip.holdFocus = false;
                keys.forceActiveFocus();
            }
            TextEdit {
                id: textEdit
                visible: w.editing
                width: Math.max(40, w.sx + w.sw - x); height: Math.max(contentHeight, font.pixelSize * 1.3)
                color: snip.penColor; font { family: "Noto Sans"; pixelSize: 12 + snip.penSize * 2; weight: Font.DemiBold }
                wrapMode: TextEdit.NoWrap
                Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.6); z: -1 }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape) { textEdit.text = ""; w.commitText(); e.accepted = true; }
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) { w.commitText(); e.accepted = true; }
                }
            }

            // ----- клавиатура -----
            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => { e.accepted = snip.key(e, w.sname); }
            }

            // ----- экспорт -----
            function exportTo(path, after) {
                if (!w.hasSel || snip.busy) return;
                w.commitText();
                snip.busy = true;
                composite.grabToImage(function(res) {
                    res.saveToFile(path);
                    after(path);
                });   // grabToImage сам учитывает масштаб экрана -> размер в физических пикселях
            }
            function copy() {
                exportTo(snip.dir + "/out.png", function(p) {
                    Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + snip.q(p) + " && notify-send -a 'Скриншот' -i " + snip.q(p) + " 'Скриншот скопирован' 'Вставьте его через Ctrl+V'"]);
                    snip.finish();
                });
            }
            function save() {
                var f = snip.saveDir + "/" + snip.fileName();
                Quickshell.execDetached(["mkdir", "-p", snip.saveDir]);
                exportTo(f, function(p) {
                    Quickshell.execDetached(["sh", "-c", "sleep 0.2; notify-send -a 'Скриншот' -i " + snip.q(p) + " 'Скриншот сохранён' " + snip.q(p.substring(p.lastIndexOf("/") + 1) + " — папка «Изображения/Screenshots»")]);
                    snip.finish();
                });
            }

            // ----- панели инструментов -----
            component ToolBtn: Rectangle {
                id: tb
                property string icon: ""
                property string tip: ""
                property bool checked: false
                signal clicked()
                width: 36; height: 36; radius: 8
                color: checked ? Qt.rgba(0.37, 0.83, 0.9, 0.28) : (tma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                border.width: checked ? 1 : 0; border.color: Qt.rgba(0.37, 0.83, 0.9, 0.6)
                SnipIcon { anchors.centerIn: parent; width: 20; height: 20; name: tb.icon; color: "#e8eef0" }
                MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: tb.clicked() }
                Rectangle {
                    visible: tma.containsMouse && tb.tip !== ""
                    x: -width - 8; anchors.verticalCenter: parent.verticalCenter
                    width: tipText.implicitWidth + 14; height: 24; radius: 5; color: Qt.rgba(0, 0, 0, 0.82)
                    Text { id: tipText; anchors.centerIn: parent; text: tb.tip; color: "white"; font { family: "Noto Sans"; pixelSize: 11 } }
                }
            }

            // вертикальная: инструменты (справа от выделения)
            Rectangle {
                id: vbar
                visible: w.hasSel && ma.mode !== "new"
                width: 46; height: vcol.implicitHeight + 10; radius: 10
                color: Qt.rgba(0.05, 0.07, 0.08, 0.92); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                x: (w.sx + w.sw + 8 + width <= w.width) ? w.sx + w.sw + 8 : Math.max(4, w.sx - width - 8 >= 0 ? w.sx - width - 8 : w.sx + w.sw - width - 6)
                y: Math.max(4, Math.min(w.height - height - 4, w.sy + w.sh - height))
                Column {
                    id: vcol
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                    spacing: 2
                    Repeater {
                        model: [["pen", "Карандаш"], ["line", "Линия"], ["arrow", "Стрелка"], ["rect", "Прямоугольник"], ["marker", "Маркер"], ["text", "Текст"]]
                        ToolBtn {
                            required property var modelData
                            icon: modelData[0]; tip: modelData[1]
                            checked: snip.tool === modelData[0]
                            onClicked: { w.commitText(); snip.tool = snip.tool === modelData[0] ? "none" : modelData[0] }
                        }
                    }
                    // цвет
                    Rectangle {
                        width: 36; height: 36; radius: 8
                        color: cma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Rectangle { anchors.centerIn: parent; width: 18; height: 18; radius: 9; color: snip.penColor; border.width: 2; border.color: "white" }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: palettePop.visible = !palettePop.visible }
                    }
                    ToolBtn { icon: "undo"; tip: "Отменить (Ctrl+Z)"; onClicked: snip.undo() }
                }
                // палитра
                Rectangle {
                    id: palettePop
                    visible: false
                    x: -width - 8; y: parent.height - height
                    width: 3 * 30 + 16; height: 3 * 30 + 16 + 22; radius: 10
                    color: Qt.rgba(0.05, 0.07, 0.08, 0.95); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                    Grid {
                        x: 8; y: 8; columns: 3; spacing: 4
                        Repeater {
                            model: snip.swatches
                            Rectangle {
                                required property string modelData
                                width: 26; height: 26; radius: 13; color: modelData
                                border.width: snip.penColor.toString() === Qt.color(modelData).toString() ? 3 : 1
                                border.color: snip.penColor.toString() === Qt.color(modelData).toString() ? "white" : Qt.rgba(1, 1, 1, 0.3)
                                MouseArea { anchors.fill: parent; onClicked: { snip.penColor = modelData; palettePop.visible = false } }
                            }
                        }
                    }
                    Text { x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: "Толщина: " + snip.penSize + " (колесо)"; color: "#a9b6ba"; font { family: "Noto Sans"; pixelSize: 10 } }
                }
            }

            // горизонтальная: действия (под выделением)
            Rectangle {
                id: hbar
                visible: w.hasSel && ma.mode !== "new"
                height: 46; width: hrow.implicitWidth + 10; radius: 10
                color: Qt.rgba(0.05, 0.07, 0.08, 0.92); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                x: Math.max(4, Math.min(w.width - width - 4, w.sx + w.sw - width))
                y: (w.sy + w.sh + 8 + height <= w.height) ? w.sy + w.sh + 8 : (w.sy - height - 8 >= 0 ? w.sy - height - 8 : w.sy + w.sh - height - 6)
                Row {
                    id: hrow
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 5 }
                    spacing: 2
                    ToolBtn { icon: "copy"; tip: "Копировать (Ctrl+C)"; onClicked: w.copy() }
                    ToolBtn { icon: "save"; tip: "Сохранить (Ctrl+S)"; onClicked: w.save() }
                    ToolBtn { icon: "close"; tip: "Закрыть (Esc)"; onClicked: snip.finish() }
                }
            }
        }
    }
}
