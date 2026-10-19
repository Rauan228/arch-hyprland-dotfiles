.pragma library
// Категории и русские подписи для карточек меню приложений.

var categories = [
    { id: "dev", label: "Разработка", icon: "dev" },
    { id: "design", label: "Дизайн", icon: "design" },
    { id: "office", label: "Офис", icon: "office" },
    { id: "web", label: "Интернет", icon: "web" },
    { id: "media", label: "Мультимедиа", icon: "media" },
    { id: "games", label: "Игры", icon: "games" },
    { id: "utils", label: "Утилиты", icon: "utils" },
    { id: "system", label: "Система", icon: "system" }
];

// категория по freedesktop Categories (первое совпадение по приоритету)
function categoryOf(cats) {
    var c = {};
    for (var i = 0; i < cats.length; i++) c[cats[i]] = true;
    if (c.Game) return "games";
    if (c.Development || c.IDE) return "dev";
    if (c.Graphics || c["2DGraphics"] || c["3DGraphics"] || c.VectorGraphics || c.RasterGraphics) return "design";
    if (c.Office || c.WordProcessor || c.Spreadsheet || c.Presentation) return "office";
    if (c.Network || c.WebBrowser || c.Chat || c.InstantMessaging || c.Email) return "web";
    if (c.AudioVideo || c.Audio || c.Video || c.Player || c.Recorder) return "media";
    if (c.Settings || c.System || c.Monitor || c.TerminalEmulator || c.FileManager) return "system";
    return "utils";
}

// подписи для известных программ (по id .desktop без расширения)
var byId = {
    "google-chrome": "Веб-браузер",
    "firefox": "Веб-браузер",
    "chromium": "Веб-браузер",
    "com.microsoft.VSCode": "Редактор кода",
    "code": "Редактор кода",
    "kitty": "Терминал",
    "org.kde.dolphin": "Проводник KDE",
    "serp-files": "Проводник",
    "thunar": "Файловый менеджер",
    "thunar-bulk-rename": "Массовое переименование",
    "thunar-settings": "Настройки Thunar",
    "org.kde.ark": "Архиватор",
    "org.pulseaudio.pavucontrol": "Громкость и звуковые устройства",
    "nm-connection-editor": "Настройки сети",
    "htop": "Процессы в терминале",
    "vim": "Текстовый редактор",
    "qt6ct": "Оформление Qt-программ",
    "uuctl": "Пользовательские службы systemd",
    "xfce4-about": "О рабочем окружении Xfce",
    "avahi-discover": "Службы в локальной сети",
    "bssh": "SSH-серверы в локальной сети",
    "bvnc": "VNC-серверы в локальной сети",
    "qv4l2": "Тест видеоустройств",
    "qvidcap": "Просмотр видеозахвата",
    "org.telegram.desktop": "Мессенджер",
    "discord": "Общение",
    "steam": "Игры",
    "spotify": "Музыка",
    "com.obsproject.Studio": "Запись и стриминг",
    "obs": "Запись и стриминг",
    "blender": "3D моделирование",
    "gimp": "Графический редактор",
    "org.gimp.GIMP": "Графический редактор",
    "org.inkscape.Inkscape": "Векторная графика",
    "krita": "Цифровое рисование",
    "libreoffice-writer": "Текстовые документы",
    "libreoffice-calc": "Таблицы",
    "libreoffice-impress": "Презентации",
    "vlc": "Видеоплеер",
    "mpv": "Видеоплеер",
    "org.kde.kdenlive": "Видеомонтаж",
    "postman": "API тестирование",
    "github-desktop": "Git клиент",
    "obsidian": "Заметки и планы",
    "notion-app": "Заметки и планы"
};

// перевод типовых GenericName
var generic = {
    "Web Browser": "Веб-браузер", "File Manager": "Файловый менеджер", "Text Editor": "Текстовый редактор",
    "Terminal emulator": "Терминал", "Terminal Emulator": "Терминал", "Archiving Tool": "Архиватор",
    "Volume Control": "Громкость", "Process Viewer": "Диспетчер процессов", "Image Viewer": "Просмотр изображений",
    "Media Player": "Медиаплеер", "Video Player": "Видеоплеер", "Music Player": "Музыкальный плеер",
    "Image Editor": "Графический редактор", "Email Client": "Почта", "Office Suite": "Офисный пакет",
    "Document Viewer": "Просмотр документов", "Calculator": "Калькулятор", "Screenshot Tool": "Скриншоты",
    "Bulk Rename": "Массовое переименование", "User unit manager": "Пользовательские службы systemd",
    "Internet Messenger": "Мессенджер", "Game": "Игра", "Integrated Development Environment": "Среда разработки"
};

function describe(e) {
    if (byId.hasOwnProperty(e.id)) return byId[e.id];
    if (e.genericName && generic.hasOwnProperty(e.genericName)) return generic[e.genericName];
    return e.genericName || e.comment || "";
}
