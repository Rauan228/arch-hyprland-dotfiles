-- Окна «как в Windows»:
--   • все окна плавающие (можно класть одно поверх другого), новые — по центру;
--   • у всех окон заголовок в стиле Windows 11: — □ ✕ (плагин hyprbars с доработкой, scripts/build-plugins.sh);
--   • прилипание при перетаскивании к краям/углам с подсветкой места, Snap Assist, раскладки Win+Z;
--   • перетаскивание за заголовок, изменение размера за край, фокус по клику;
--   • Win+←/→ — половина экрана, Win+↑ — развернуть, Win+↓ — восстановить/свернуть (scripts/bin/serp-snap).

local home = os.getenv("HOME")
local win = home .. "/.config/serpantinum/bin/serp-win"

hl.config({
    general = {
        resize_on_border = true,         -- тянуть за край окна
        extend_border_grab_area = 12,
        hover_icon_on_border = true,
        snap = { enabled = true, window_gap = 8, monitor_gap = 12 },   -- «магнитные» края
    },
    input = {
        follow_mouse = 2,                -- фокус по клику (как в Windows), прокрутка работает и без фокуса
        float_switch_override_focus = 0,
    },
    misc = {
        focus_on_activate = true,
    },
    -- курсор никогда не прыгает сам (как в Windows): Hyprland по умолчанию переносит его в окно/на монитор,
    -- которому скрипты отдают фокус (свернуть/вернуть, Alt+Tab, док), и курсор терялся
    cursor = {
        no_warps = true,
    },
})

-- ---------- заголовки окон (hyprbars) ----------
local bars = home .. "/.local/share/serpantinum/plugins/hyprbars.so"
local f = io.open(bars, "r")
if f then
    f:close()
    hl.plugin.load(bars)

    -- стиль Windows 11: плоские кнопки — □ ✕ справа во всю высоту заголовка, при наведении подсветка
    -- (у ✕ — красная); название слева. button_style и snap_command — доработка Serpantinum
    -- (hypr/plugins/hyprbars-serpantinum.patch)
    hl.config({
        plugin = {
            hyprbars = {
                bar_height = 32,
                bar_color = "rgba(1c1c22f0)",
                bar_blur = true,
                col = { text = "rgba(e6e6ebff)" },
                bar_text_size = 11,
                bar_text_font = "Noto Sans",
                bar_text_align = "left",
                bar_buttons_alignment = "right",
                bar_padding = 14,
                bar_button_padding = 0,
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                inactive_button_color = "rgba(e6e6eb80)",   -- у неактивных окон значки тусклее
                button_style = "windows",
                snap_command = home .. "/.config/serpantinum/bin/serp-snapzone",
                on_double_click = win .. " max",
            },
        },
    })

    -- справа налево: закрыть, развернуть, свернуть; size — ширина кнопки, bg — цвет подсветки при наведении
    local function button(hover, icon, action)
        hl.plugin.hyprbars.add_button({ bg_color = hover, fg_color = "rgb(e6e6eb)", size = 46, icon = icon, action = win .. " " .. action })
    end
    button("rgb(c42b1c)", "✕", "close")
    button("rgba(ffffff1a)", "□", "max")
    button("rgba(ffffff1a)", "─", "min")
end

-- ---------- правила ----------
-- все окна плавающие и появляются по центру
hl.window_rule({ name = "win-float-all", match = { class = ".*" }, float = true })
hl.window_rule({ name = "win-center-new", match = { class = ".*", float = true }, center = true })

-- терминал по умолчанию крупнее
hl.window_rule({ name = "win-kitty-size", match = { class = "^kitty$" }, size = "monitor_w*0.55 monitor_h*0.6" })

-- заголовок рисуется у всех окон; собственные кнопки программ отключены, где это возможно
-- (Chrome/GTK — gsettings button-layout без кнопок, Spotify — без своих декораций Wayland)

-- ---------- клавиши ----------
local snap = home .. "/.config/serpantinum/bin/serp-snap"
hl.bind("SUPER + left",  hl.dsp.exec_cmd(snap .. " left"))
hl.bind("SUPER + right", hl.dsp.exec_cmd(snap .. " right"))
hl.bind("SUPER + up",    hl.dsp.exec_cmd(snap .. " max"))
hl.bind("SUPER + down",  hl.dsp.exec_cmd(snap .. " down"))
hl.bind("SUPER + SHIFT + left",  hl.dsp.exec_cmd(snap .. " monitor prev"))   -- на соседний монитор
hl.bind("SUPER + SHIFT + right", hl.dsp.exec_cmd(snap .. " monitor next"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("quickshell -p " .. home .. "/.local/share/serpantinum/runtime/quickshell/Shell.qml ipc call switcher layouts"))

-- Win+M — свернуть все окна стола, Win+Shift+M — вернуть их, Win+Home — свернуть все, кроме активного
local mini = home .. "/.config/serpantinum/bin/serp-minall"
hl.bind("SUPER + M",         hl.dsp.exec_cmd(mini .. " all"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd(mini .. " restore"))
hl.bind("SUPER + Home",      hl.dsp.exec_cmd(mini .. " others"))
