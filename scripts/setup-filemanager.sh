#!/usr/bin/env bash
# Настройка проводника Dolphin в стиле Serpantinum (запуск от пользователя, без sudo).
# Нужны пакеты: dolphin breeze ark ffmpegthumbs qt6ct
#   sudo pacman -S --needed breeze ark ffmpegthumbs qt6ct
# Что делает (перед изменением файлов кладёт копии в ~/.local/share/serpantinum/backups/<время>/):
#   - тёмная палитра и тема Breeze только для Dolphin (через qt6ct, на остальные Qt-программы не влияет);
#   - kdeglobals: цвета, иконки breeze-dark, терминал kitty для «Открыть терминал здесь»;
#   - dolphinrc: вкладки запоминаются, полный путь, архивы как папки, превью;
#   - Dolphin — программа по умолчанию для папок (вместо kitty-open), в т.ч. «Показать в папке» из браузера.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
for c in dolphin qt6ct; do command -v "$c" >/dev/null || { echo "нет $c — сначала: sudo pacman -S --needed breeze ark ffmpegthumbs qt6ct" >&2; exit 1; }; done
[ -f /usr/share/color-schemes/BreezeDark.colors ] || { echo "нет темы BreezeDark — установите пакет breeze" >&2; exit 1; }

bk="$HOME/.local/share/serpantinum/backups/filemanager-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$bk"
for f in "$HOME/.config/kdeglobals" "$HOME/.config/dolphinrc" "$HOME/.config/qt6ct/qt6ct.conf" \
         "$HOME/.local/share/applications/org.kde.dolphin.desktop" "$HOME/.config/mimeapps.list"; do
  [ -e "$f" ] && cp -a "$f" "$bk/" || true
done
echo "резервные копии: $bk"

# 1) qt6ct: стиль Breeze + палитра Serpantinum (только для Dolphin)
mkdir -p "$HOME/.config/qt6ct/colors"
cp "$root/config/dolphin/serpantinum-palette.conf" "$HOME/.config/qt6ct/colors/serpantinum.conf"
cat > "$HOME/.config/qt6ct/qt6ct.conf" <<EOF
[Appearance]
style=Breeze
icon_theme=breeze-dark
custom_palette=true
color_scheme_path=$HOME/.config/qt6ct/colors/serpantinum.conf
standard_dialogs=default

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

[Interface]
double_click_interval=400
wheel_scroll_lines=3
EOF

# 2) kdeglobals: BreezeDark + фиолетовый акцент + наши фоны
python3 - "$HOME/.config/kdeglobals" <<'PY'
import configparser, sys
dst = sys.argv[1]
cp = configparser.RawConfigParser(); cp.optionxform = str
cp.read("/usr/share/color-schemes/BreezeDark.colors", encoding="utf-8")
old = configparser.RawConfigParser(); old.optionxform = str
old.read(dst, encoding="utf-8")
for s in old.sections():                     # сохранить чужие секции, если были
    if not cp.has_section(s):
        cp.add_section(s)
        for k, v in old.items(s): cp.set(s, k, v)
def put(sec, **kv):
    if not cp.has_section(sec): cp.add_section(sec)
    for k, v in kv.items(): cp.set(sec, k, v)
accent, sel = "111,116,242", "77,81,184"          # как у оболочки: фиолетовый акцент #6f74f2
for grp, bg, alt in [("View", "38,39,52", "43,44,58"), ("Window", "31,32,43", "35,36,48"),
                     ("Button", "48,49,63", "54,55,70"), ("Header", "27,28,38", "31,32,43"),
                     ("Complementary", "24,25,34", "31,32,43"), ("Tooltip", "48,49,63", "54,55,70")]:
    put("Colors:" + grp, BackgroundNormal=bg, BackgroundAlternate=alt, DecorationFocus=accent, DecorationHover=accent,
        ForegroundNormal="238,240,248", ForegroundInactive="160,163,184", ForegroundLink="143,147,255",
        ForegroundVisited="183,131,240")
put("Colors:Selection", BackgroundNormal=sel, BackgroundAlternate="66,69,160", DecorationFocus=accent, DecorationHover=accent,
    ForegroundNormal="255,255,255", ForegroundInactive="220,222,240")
put("General", ColorScheme="Serpantinum", Name="Serpantinum", TerminalApplication="kitty", TerminalService="kitty.desktop",
    font="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1", AccentColor=accent)
put("Icons", Theme="breeze-dark")
put("KDE", widgetStyle="Breeze", SingleClick="false")
with open(dst, "w", encoding="utf-8") as f: cp.write(f, space_around_delimiters=False)
# та же схема отдельным файлом: KDE-программы ищут ColorScheme=Serpantinum по имени,
# а без файла откатываются на светлую Breeze и перебивают палитру qt6ct
import os
sch = configparser.RawConfigParser(); sch.optionxform = str
for sec in [x for x in cp.sections() if x.startswith("Colors:") or x == "WM"]:
    sch.add_section(sec)
    for k, v in cp.items(sec): sch.set(sec, k, v)
sch.add_section("General"); sch.set("General", "Name", "Serpantinum"); sch.set("General", "ColorScheme", "Serpantinum")
d = os.path.expanduser("~/.local/share/color-schemes"); os.makedirs(d, exist_ok=True)
with open(d + "/Serpantinum.colors", "w", encoding="utf-8") as f: sch.write(f, space_around_delimiters=False)
PY

# 3) dolphinrc
python3 - "$HOME/.config/dolphinrc" <<'PY'
import configparser, sys, os
dst = sys.argv[1]
cp = configparser.RawConfigParser(); cp.optionxform = str
if os.path.exists(dst): cp.read(dst, encoding="utf-8")
def put(sec, **kv):
    if not cp.has_section(sec): cp.add_section(sec)
    for k, v in kv.items(): cp.set(sec, k, v)
put("General", RememberOpenedTabs="true", ShowFullPath="true", ShowFullPathInTitlebar="true", BrowseThroughArchives="true",
    ShowSelectionToggle="true", ConfirmClosingMultipleTabs="false", OpenExternallyCalledFolderInNewTab="true",
    ShowStatusBar="FullWidth", ShowZoomSlider="true", GlobalViewProps="true", UseTabForSwitchingSplitView="true")
put("MainWindow", MenuBar="Disabled")
# своя схема окна Dolphin (меню «Цветовая схема»): без неё вне Plasma он ставит светлую Breeze поверх qt6ct
put("UiSettings", ColorScheme="Serpantinum")
put("PreviewSettings", Plugins="appimagethumbnail,audiothumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,svgthumbnail,ffmpegthumbs")
put("DetailsMode", PreviewSize="22", IconSize="22")
put("IconsMode", PreviewSize="80", IconSize="64")
with open(dst, "w", encoding="utf-8") as f: cp.write(f, space_around_delimiters=False)
PY
# вид по умолчанию: таблица «Подробно» с превью (как в File Pilot / Проводнике)
mkdir -p "$HOME/.local/share/dolphin/view_properties/global"
cat > "$HOME/.local/share/dolphin/view_properties/global/.directory" <<'EOF'
[Dolphin]
PreviewsShown=true
ViewMode=1
VisibleRoles=Details_text,Details_size,Details_modificationtime,Details_type
SortFoldersFirst=true
Version=4
EOF

# 4) запуск Dolphin с темой (ярлык, xdg-open и D-Bus «Показать в папке»)
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/dbus-1/services"
sed -e 's|^Exec=dolphin|Exec=env QT_QPA_PLATFORMTHEME=qt6ct dolphin|' -e 's|^Name=Dolphin$|Name=Проводник (Dolphin)|' \
    /usr/share/applications/org.kde.dolphin.desktop > "$HOME/.local/share/applications/org.kde.dolphin.desktop"
if [ -f /usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service ]; then
  sed 's|^Exec=/usr/bin/dolphin|Exec=/usr/bin/env QT_QPA_PLATFORMTHEME=qt6ct /usr/bin/dolphin|' \
    /usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service > "$HOME/.local/share/dbus-1/services/org.kde.dolphin.FileManager1.service"
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# 5) Dolphin — программа для папок по умолчанию
xdg-mime default org.kde.dolphin.desktop inode/directory
xdg-mime default org.kde.dolphin.desktop application/x-directory 2>/dev/null || true
kbuildsycoca6 >/dev/null 2>&1 || true

echo "готово: папки открываются в Dolphin ($(xdg-mime query default inode/directory))"
