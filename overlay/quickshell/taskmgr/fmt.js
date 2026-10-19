.pragma library

function bytes(b, dec) {
    if (b === null || b === undefined) return "—";
    var u = ["Б", "КБ", "МБ", "ГБ", "ТБ"], i = 0, v = Math.abs(b);
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return String(i === 0 ? Math.round(v) : v.toFixed(dec === undefined ? (v >= 100 ? 0 : 1) : dec)).replace(".", ",") + " " + u[i];
}
function rate(b) {
    if (b === null || b === undefined) return "—";
    return bytes(b) + "/с";
}
function bits(b) {
    if (b === null || b === undefined) return "—";
    var v = b * 8, u = ["бит/с", "Кбит/с", "Мбит/с", "Гбит/с"], i = 0;
    while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
    return String(v >= 100 ? Math.round(v) : v.toFixed(1)).replace(".", ",") + " " + u[i];
}
function pct(v, dec) {
    if (v === null || v === undefined) return "—";
    return String(dec === 0 ? Math.round(v) : v.toFixed(dec === undefined ? 1 : dec)).replace(".", ",") + "%";
}
function pct0(v) { return v === null || v === undefined ? "—" : (v < 0.05 ? "0%" : String(v < 10 ? v.toFixed(1) : Math.round(v)).replace(".", ",") + "%"); }
function uptime(sec) {
    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60), s = Math.floor(sec % 60);
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return d + ":" + p(h) + ":" + p(m) + ":" + p(s);
}
function stateName(s) {
    return ({R: "Выполняется", S: "Ожидает", D: "Ожидает I/O", T: "Остановлен", t: "Отладка", Z: "Зомби", I: "Простаивает", X: "Завершён"})[s] || s;
}
// heat colour overlay (Windows style): 0..1 -> alpha
function heat(frac) { return Math.max(0, Math.min(1, frac)); }
// длительность в секундах -> «ч:мм:сс»
function duration(sec) {
    if (sec === null || sec === undefined || isNaN(sec)) return "—";
    sec = Math.max(0, Math.floor(sec));
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return h + ":" + p(m) + ":" + p(s);
}
