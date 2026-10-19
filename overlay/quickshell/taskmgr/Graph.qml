import QtQuick

// Линейный график с заливкой (стиль «Производительности» Windows).
Canvas {
    id: g
    property var values: []
    property var values2: []          // необязательная вторая линия
    property real maxValue: 100
    property bool autoMax: false
    property color lineColor: Style.accent
    property color lineColor2: Style.mem
    property real fillAlpha: 0.38
    property real autoFloor: 1      // минимальная шкала при автомасштабе
    property int points: 60
    property int tick: 0
    property bool grid: true

    onTickChanged: requestPaint()
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function draw(ctx, vals, col, max, fill) {
        if (!vals || vals.length < 2) return;
        var w = width, h = height, n = points, step = w / (n - 1);
        var off = n - vals.length;
        ctx.beginPath();
        for (var i = 0; i < vals.length; i++) {
            var x = (off + i) * step, y = h - Math.min(1, vals[i] / max) * (h - 2) - 1;
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = col; ctx.lineWidth = 1.4; ctx.stroke();
        if (fill) {
            ctx.lineTo((off + vals.length - 1) * step, h); ctx.lineTo(off * step, h); ctx.closePath();
            var gr = ctx.createLinearGradient(0, 0, 0, h);
            gr.addColorStop(0, Qt.rgba(col.r, col.g, col.b, g.fillAlpha)); gr.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.05));
            ctx.fillStyle = gr; ctx.fill();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height;
        if (grid) {
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
            ctx.lineWidth = 1;
            for (var i = 1; i < 10; i++) { var gx = Math.round(w * i / 10) + 0.5; ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke(); }
            for (var j = 1; j < 4; j++) { var gy = Math.round(h * j / 4) + 0.5; ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke(); }
        }
        var max = maxValue;
        if (autoMax) {
            max = g.autoFloor;
            for (var a = 0; a < values.length; a++) max = Math.max(max, values[a]);
            for (var b = 0; b < values2.length; b++) max = Math.max(max, values2[b]);
            max *= 1.2;
        }
        draw(ctx, values, lineColor, max, true);
        draw(ctx, values2, lineColor2, max, false);
    }
}
