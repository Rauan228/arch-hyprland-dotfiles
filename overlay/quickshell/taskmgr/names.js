.pragma library
// Понятные названия и иконки для системных процессов (как «Диспетчер окон рабочего стола» в Windows).
// Ключ — имя процесса (comm / имя исполняемого файла), значение — [название, иконка темы].
var map = {
    "Hyprland": ["Диспетчер окон рабочего стола", "preferences-desktop-display"],
    "start-hyprland": ["Запуск сеанса Hyprland", "preferences-desktop-display"],
    "Xwayland": ["Совместимость с X11 (Xwayland)", "video-display"],
    "quickshell": ["Оболочка Serpantinum", "preferences-desktop"],
    "serp-info": ["Терминал (сведения о системе)", "utilities-terminal"],
    "uwsm": ["Менеджер сеанса Wayland (uwsm)", "preferences-desktop"],
    "pipewire": ["Звуковая служба PipeWire", "audio-card"],
    "pipewire-pulse": ["Звуковая служба PipeWire", "audio-card"],
    "wireplumber": ["Звуковая служба PipeWire", "audio-card"],
    "rtkit-daemon": ["Приоритеты звука (RealtimeKit)", "audio-card"],
    "NetworkManager": ["Сетевая служба NetworkManager", "network-wired"],
    "nm-applet": ["Значок сети в трее", "network-wired"],
    "wpa_supplicant": ["Wi-Fi (wpa_supplicant)", "network-wireless"],
    "iwd": ["Wi-Fi (iwd)", "network-wireless"],
    "bluetoothd": ["Служба Bluetooth", "bluetooth"],
    "upowerd": ["Питание и батарея (UPower)", "battery"],
    "systemd": ["Системный менеджер systemd", "applications-system"],
    "systemd-journald": ["Журнал системы (journald)", "applications-system"],
    "systemd-logind": ["Сеансы входа (logind)", "applications-system"],
    "systemd-udevd": ["Подключение устройств (udev)", "applications-system"],
    "systemd-resolved": ["Разрешение имён (resolved)", "network-workgroup"],
    "systemd-timesyncd": ["Синхронизация времени", "applications-system"],
    "systemd-oomd": ["Защита от нехватки памяти", "applications-system"],
    "systemd-userdbd": ["База пользователей (userdbd)", "applications-system"],
    "(sd-pam)": ["Сеанс пользователя (PAM)", "dialog-password"],
    "dbus-broker": ["Шина сообщений D-Bus", "network-workgroup"],
    "dbus-broker-launch": ["Шина сообщений D-Bus", "network-workgroup"],
    "dbus-daemon": ["Шина сообщений D-Bus", "network-workgroup"],
    "polkitd": ["Служба прав доступа (polkit)", "security-high"],
    "polkit-kde-authentication-agent-1": ["Агент авторизации polkit", "dialog-password"],
    "gnome-keyring-daemon": ["Связка ключей", "dialog-password"],
    "sddm": ["Экран входа SDDM", "system-users"],
    "sddm-helper": ["Экран входа SDDM", "system-users"],
    "bash": ["Командная оболочка bash", "utilities-terminal"],
    "zsh": ["Командная оболочка zsh", "utilities-terminal"],
    "fish": ["Командная оболочка fish", "utilities-terminal"],
    "sh": ["Командная оболочка sh", "utilities-terminal"],
    "kitty": ["Терминал", "kitty"],
    "thunar": ["Проводник", "org.xfce.thunar"],
    "Thunar": ["Проводник", "org.xfce.thunar"],
    "tumblerd": ["Миниатюры файлов (tumbler)", "image-x-generic"],
    "gvfsd": ["Виртуальные файловые системы (GVfs)", "drive-harddisk"],
    "at-spi-bus-launcher": ["Специальные возможности (AT-SPI)", "preferences-desktop-accessibility"],
    "at-spi2-registryd": ["Специальные возможности (AT-SPI)", "preferences-desktop-accessibility"],
    "bwrap": ["Песочница приложений (bubblewrap)", "security-high"],
    "chrome_crashpad_handler": ["Google Chrome: отчёты о сбоях", "google-chrome"],
    "xdg-desktop-portal": ["Порталы рабочего стола", "preferences-system"],
    "xdg-desktop-portal-gtk": ["Порталы рабочего стола", "preferences-system"],
    "xdg-desktop-portal-hyprland": ["Порталы рабочего стола", "preferences-system"],
    "xdg-document-portal": ["Порталы рабочего стола", "preferences-system"],
    "xdg-permission-store": ["Порталы рабочего стола", "preferences-system"],
    "hypridle": ["Автоблокировка экрана (hypridle)", "preferences-desktop-screensaver"],
    "hyprlock": ["Экран блокировки (hyprlock)", "system-lock-screen"],
    "inotifywait": ["Наблюдение за файлами (inotify)", "folder"],
    "cliphist": ["История буфера обмена", "edit-paste"],
    "wl-paste": ["История буфера обмена", "edit-paste"],
    "dconf-service": ["Хранилище настроек (dconf)", "preferences-system"],
    "glycin-image-rs": ["Загрузчик изображений (glycin)", "image-x-generic"],
    "cava": ["Визуализатор звука (cava)", "audio-x-generic"],
    "python3": ["Python", "text-x-python"],
    "python": ["Python", "text-x-python"],
    "fusermount3": ["Подключение FUSE", "drive-harddisk"],
    "nvidia-powerd": ["NVIDIA: управление питанием", "nvidia"],
    "nvidia-persistenced": ["NVIDIA: служба драйвера", "nvidia"],
    "cupsd": ["Служба печати (CUPS)", "printer"],
    "sshd": ["Удалённый доступ (SSH)", "network-server"],
    "crond": ["Планировщик задач (cron)", "appointment-new"],
    "agetty": ["Текстовая консоль (agetty)", "utilities-terminal"],
    "login": ["Вход в консоль", "utilities-terminal"]
};

// все иконки, которые нужно найти в темах breeze/Adwaita
function iconNames() {
    var seen = {}, out = [];
    for (var k in map) if (!seen[map[k][1]]) { seen[map[k][1]] = true; out.push(map[k][1]); }
    ["drive-harddisk", "applications-system", "preferences-system"].forEach(function(n) { if (!seen[n]) out.push(n); });
    return out;
}

function friendly(name) {
    if (map.hasOwnProperty(name)) return { label: map[name][0], icon: map[name][1] };
    if (name.indexOf("gvfsd") === 0 || name.indexOf("gvfs-") === 0) return { label: "Виртуальные файловые системы (GVfs)", icon: "drive-harddisk" };
    if (name.indexOf("systemd-") === 0) return { label: "Служба systemd: " + name.substring(8), icon: "applications-system" };
    if (name.indexOf("xdg-") === 0) return { label: "Порталы рабочего стола", icon: "preferences-system" };
    return null;
}
