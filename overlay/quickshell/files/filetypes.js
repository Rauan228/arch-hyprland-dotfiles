.pragma library
// Русские названия типов и иконки (имена из темы breeze) по расширению.

var types = {
    pdf: ["Документ PDF", "application-pdf"],
    txt: ["Текстовый документ", "text-plain"], log: ["Журнал", "text-x-log"], md: ["Документ Markdown", "text-markdown"],
    doc: ["Документ Word", "x-office-document"], docx: ["Документ Word", "x-office-document"], odt: ["Документ ODT", "x-office-document"], rtf: ["Документ RTF", "x-office-document"],
    xls: ["Таблица XLS", "x-office-spreadsheet"], xlsx: ["Таблица XLSX", "x-office-spreadsheet"], ods: ["Таблица ODS", "x-office-spreadsheet"], csv: ["Таблица CSV", "text-csv"],
    ppt: ["Презентация PPT", "x-office-presentation"], pptx: ["Презентация PPTX", "x-office-presentation"], odp: ["Презентация ODP", "x-office-presentation"],
    png: ["Изображение PNG", "image-png"], jpg: ["Изображение JPEG", "image-jpeg"], jpeg: ["Изображение JPEG", "image-jpeg"], gif: ["Изображение GIF", "image-gif"],
    webp: ["Изображение WEBP", "image-webp"], svg: ["Изображение SVG", "image-svg+xml"], bmp: ["Изображение BMP", "image-bmp"], ico: ["Значок ICO", "image-x-ico"],
    heic: ["Изображение HEIC", "image-x-generic"], avif: ["Изображение AVIF", "image-x-generic"], tiff: ["Изображение TIFF", "image-tiff"], psd: ["Файл Photoshop", "image-vnd.adobe.photoshop"],
    fig: ["Файл FIG", "image-x-generic"], blend: ["Сцена Blender", "application-x-blender"],
    mp4: ["Видео MP4", "video-mp4"], mkv: ["Видео MKV", "video-x-matroska"], webm: ["Видео WEBM", "video-webm"], avi: ["Видео AVI", "video-x-msvideo"], mov: ["Видео MOV", "video-quicktime"],
    mp3: ["Аудио MP3", "audio-mpeg"], flac: ["Аудио FLAC", "audio-flac"], wav: ["Аудио WAV", "audio-x-wav"], ogg: ["Аудио OGG", "audio-ogg"], m4a: ["Аудио M4A", "audio-mp4"], opus: ["Аудио OPUS", "audio-x-opus+ogg"],
    zip: ["Архив ZIP", "application-zip"], rar: ["Архив RAR", "application-vnd.rar"], "7z": ["Архив 7Z", "application-x-7z-compressed"], tar: ["Архив TAR", "application-x-tar"],
    gz: ["Архив GZ", "application-gzip"], xz: ["Архив XZ", "application-x-xz"], zst: ["Архив ZST", "application-x-zstd-compressed-tar"], iso: ["Образ диска ISO", "application-x-cd-image"],
    exe: ["Программа Windows", "application-x-ms-dos-executable"], msi: ["Установщик Windows", "application-x-msi"], appimage: ["Программа AppImage", "application-x-executable"],
    deb: ["Пакет DEB", "application-vnd.debian.binary-package"], sh: ["Скрипт Bash", "application-x-shellscript"], py: ["Скрипт Python", "text-x-python"],
    js: ["Файл JavaScript", "application-javascript"], ts: ["Файл TypeScript", "text-x-typescript"], json: ["Файл JSON", "application-json"], html: ["Страница HTML", "text-html"],
    css: ["Стили CSS", "text-css"], qml: ["Файл QML", "text-x-qml"], lua: ["Скрипт Lua", "text-x-lua"], c: ["Исходник C", "text-x-csrc"], cpp: ["Исходник C++", "text-x-c++src"],
    h: ["Заголовок C", "text-x-chdr"], rs: ["Исходник Rust", "text-rust"], go: ["Исходник Go", "text-x-go"], java: ["Исходник Java", "text-x-java"],
    conf: ["Файл настроек", "text-x-generic"], ini: ["Файл настроек", "text-x-generic"], toml: ["Файл настроек TOML", "text-x-generic"], yaml: ["Файл YAML", "text-x-generic"], yml: ["Файл YAML", "text-x-generic"],
    desktop: ["Ярлык приложения", "application-x-desktop"], ttf: ["Шрифт TTF", "font-ttf"], otf: ["Шрифт OTF", "font-otf"], torrent: ["Торрент", "application-x-bittorrent"]
};

var imageExt = { png: 1, jpg: 1, jpeg: 1, gif: 1, webp: 1, svg: 1, bmp: 1, ico: 1, avif: 1 };

function ext(name) {
    var i = name.lastIndexOf(".");
    return i > 0 ? name.substring(i + 1).toLowerCase() : "";
}
function typeName(name, isDir) {
    if (isDir) return "Папка с файлами";
    var e = ext(name);
    if (types.hasOwnProperty(e)) return types[e][0];
    return e ? "Файл " + e.toUpperCase() : "Файл";
}
function iconName(name, isDir) {
    if (isDir) return "folder";
    var e = ext(name);
    if (types.hasOwnProperty(e)) return types[e][1];
    return "text-x-generic";
}
function isImage(name) { return imageExt.hasOwnProperty(ext(name)); }

// размер «48,2 МБ»
function size(b) {
    if (b === null || b === undefined || b < 0) return "—";
    var u = ["Б", "КБ", "МБ", "ГБ", "ТБ"], i = 0, v = b;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return (i === 0 ? String(Math.round(v)) : v.toFixed(v >= 100 ? 0 : 1).replace(".", ",")) + " " + u[i];
}
function pad(n) { return (n < 10 ? "0" : "") + n; }
// «28.04.2025  21:17»
function date(d) {
    if (!d) return "—";
    if (!(d instanceof Date)) d = new Date(d);
    if (isNaN(d.getTime())) return "—";
    return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear() + "  " + pad(d.getHours()) + ":" + pad(d.getMinutes());
}
