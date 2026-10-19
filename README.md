# arch-hyprland-dotfiles

Мои настройки Arch Linux + Hyprland: рабочий стол, который ведёт себя как Windows, — заголовки окон
с кнопками **— □ ✕**, панель задач, Alt+Tab с миниатюрами, сворачивание в док, прилипание окон к краям,
мышь с кривой ускорения Windows. Оболочка — [Serpantinum](https://github.com/ilyamiro/serpantinum)
на Quickshell с моими доработками поверх.

> Настроено под конкретный ноутбук (Gigabyte G5 KF: Intel Iris Xe + RTX 4060, второй монитор по HDMI,
> Windows 11 на отдельном SSD). На другом железе почти всё заработает, но загрузчик и пути стоит проверить.

## Что внутри

### Окна как в Windows
- **Заголовок как в Windows 11** — плоские кнопки свернуть / развернуть / закрыть во всю высоту,
  подсветка при наведении (у ✕ красная), двойной клик — развернуть. Плагин hyprbars с моим патчем на C++.
- **Свернуть** — окно с ускорением уезжает в док и растворяется, возвращается на то же место и в том же размере;
  фокус переходит на окно под ним. Работает и с кнопками самих программ (Telegram, VS Code, Chrome).
- **Развернуть** — окно остаётся плавающим и запоминает прежний размер; потянули за заголовок — вернулся прежний.
- **Aero Snap** — к краю половина экрана, в угол четверть, к верху развернуть; **Snap Assist** с живыми миниатюрами;
  **Win+Z** — раскладки (половины, трети, четверти).
- Программы открываются там, где были в прошлый раз; окна не улетают за край монитора.
- Курсор сам никуда не прыгает, программы не выскакивают поверх при уведомлениях (Telegram).

### Оболочка
- **Верхняя панель** — рабочие столы, музыка, время, погода, трей, раскладка, сеть, Bluetooth, звук, батарея;
  кнопки — □ ✕ для выбранного окна. Выдвигается, когда курсор упирается в край.
- **Док как панель задач** — клик по активному приложению сворачивает его, при наведении миниатюры окон.
- **Alt+Tab / Win+Tab** с миниатюрами, **меню приложений** (Win+D / Win+R) с категориями и поиском.
- **Диспетчер задач** (Ctrl+Tab) — процессы, графики ЦП/памяти/дисков/сети/видеокарт, автозагрузка.
- **Буфер обмена** (Win+V) — выбранная запись сразу вставляется; **скриншоты** области и экрана.
- **Окно музыки** — плеер, текст песни, визуализатор, 10-полосный эквалайзер с пресетами (EasyEffects).
- **Экран блокировки** — часы, погода, состояние системы, плеер; автоблокировка через 10 минут.

### Система
- Hyprland на Lua-конфиге, модулями: мониторы, ввод, вид, анимации, клавиши, правила, автозапуск.
- Все мониторы на максимальной частоте (ноутбук 144 Гц, внешний 120 Гц).
- Мышь — кривая Windows «Повышенная точность установки указателя» (`hypr/modules/input.lua`).
- Курсор Windows 10, проводник Dolphin в фиолетовой теме оболочки.
- Тема входа SDDM с автовходом, тема загрузчика GRUB с пунктами Arch и Windows.

## Горячие клавиши

| Клавиши | Действие |
|---|---|
| Win+E | Проводник (Dolphin) |
| Win+D, Win+R | Меню приложений |
| Win+Return | Терминал (kitty) |
| Win+C | VS Code |
| Win+V | История буфера обмена |
| PrtSc, Win+Shift+S | Скриншот области |
| Shift+PrtSc, Win+PrtSc | Скриншот всего экрана |
| Win+L | Заблокировать |
| Alt+Tab, Win+Tab | Переключение окон |
| Ctrl+Tab | Диспетчер задач |
| Ctrl+Shift+Esc | Терминал с fastfetch |
| Alt+F4 | Закрыть окно |
| Win+← / → | Половина экрана (у края — на соседний монитор) |
| Win+↑ / ↓ | Развернуть / восстановить или свернуть |
| Win+Shift+← / → | Окно на другой монитор |
| Win+Z | Раскладки окон |
| Win+M, Win+Shift+M | Свернуть все / вернуть |
| Win+Home | Свернуть все, кроме активного |
| Win+Ctrl+D, Win+Ctrl+F4 | Новый рабочий стол / закрыть текущий |
| Win+Ctrl+← / →, Win+колесо мыши | Соседний рабочий стол |
| Win+Ctrl+Shift+← / → | Перенести окно на соседний рабочий стол |
| Win+1…9 | Рабочий стол по номеру |
| Alt+Shift | Раскладка us / ru |

## Установка

Нужны Arch Linux и Hyprland 0.56 с Lua-конфигом. Основные пакеты:

```bash
sudo pacman -S --needed hyprland quickshell hyprlock hypridle hyprpaper kitty \
  jq socat python brightnessctl playerctl wl-clipboard cliphist cava \
  polkit-kde-agent dolphin breeze ark ffmpegthumbs qt6ct
```

Дальше — из папки репозитория:

```bash
git clone https://github.com/Rauan228/arch-hyprland-dotfiles ~/Projects/Serpantinum
cd ~/Projects/Serpantinum

scripts/link.sh              # ссылки в ~/.config (перед этим резервная копия)
scripts/build-plugins.sh     # заголовки окон: собрать hyprbars под установленный Hyprland
scripts/assemble-shell.sh    # собрать оболочку: оригинал + мои правки + патчи
scripts/install-cursor.sh    # курсор Windows 10
scripts/setup-filemanager.sh # Dolphin в теме оболочки
scripts/install-apps.sh      # Telegram, Steam, Spotify, Discord, архиваторы, эквалайзер…
scripts/setup-equalizer.sh   # EasyEffects в фоне для окна музыки
```

Настройки оболочки: скопировать `config/serpantinum/settings.json` в `~/.config/serpantinum/` и перезайти
(или `scripts/restart-shell.sh`). Проверить, всё ли на месте, — `scripts/doctor.sh`.

Экран входа и загрузчик меняют системные файлы, поэтому ставятся отдельно и через sudo:
`sddm/build-theme.sh && sudo sddm/install.sh`, `bootloader/build-theme.sh && sudo bootloader/apply.sh`
(у загрузчика в скрипте указан UUID раздела Windows — проверьте свой; откат — `bootloader/rollback.sh`).

> **После обновления Hyprland** снова запустите `scripts/build-plugins.sh`, иначе Hyprland не загрузит
> старый плагин и заголовки окон пропадут.

## Как устроено

| Папка | Что внутри |
|---|---|
| `hypr/` | конфиг Hyprland по модулям и патч плагина заголовков |
| `third_party/serpantinum/` | неизменённая копия оригинальной оболочки Serpantinum |
| `overlay/` | мои правки поверх оригинала: точка входа, диспетчер задач, Alt+Tab, скриншоты, меню приложений, патчи |
| `scripts/` | установка и сборка; `scripts/bin/` — окна (свернуть, развернуть, прилипание, место окон) и запуск оболочки |
| `config/` | настройки оболочки, тема Dolphin, служба эквалайзера, обои |
| `shell/`, `lock/` | экран блокировки и запасной hyprlock |
| `sddm/`, `bootloader/` | тема входа и тема GRUB |
| `docs/STATUS.md` | подробное описание всего, что настроено, и почему сделано именно так |

Оригинал оболочки не правится напрямую: `scripts/assemble-shell.sh` берёт `third_party/serpantinum/src`,
кладёт сверху `overlay/quickshell` и применяет патчи из `overlay/patches` — результат в
`~/.local/share/serpantinum/runtime`.

## Авторы и лицензии

- Оболочка [Serpantinum](https://github.com/ilyamiro/serpantinum) — © авторы Serpantinum, лицензия GNU AGPL-3.0
  (`third_party/serpantinum/LICENSE.md`); в репозитории копия версии 2.2.12 (коммит 86c3ee2).
- Обои «туманный лес» — Wikimedia Commons, CC0 1.0 (`config/wallpapers/CREDITS.md`).
- Курсор Windows 10 — [red-magic/cursor-themes](https://github.com/red-magic/cursor-themes), скачивается при установке.
