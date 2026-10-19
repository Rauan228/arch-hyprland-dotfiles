-- Раскладки: английская (по умолчанию) + русская, переключение Alt+Shift.
hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 .. 1.0, 0 = без изменений

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- ---------- мышь как в Windows ----------
-- В Linux (libinput) своя кривая ускорения «adaptive», поэтому мышь ощущается иначе.
-- Здесь — кривая Windows «Повышенная точность установки указателя» (включена в Windows по умолчанию),
-- взятая из реестра Windows: HKCU\Control Panel\Mouse\SmoothMouseXCurve / SmoothMouseYCurve.
-- Медленно — точнее (чуть медленнее), быстро — дальше, как на винде.
--   MOUSE_SPEED     — общая скорость (1.0 ≈ ползунок 10 из 20 в Windows); больше — быстрее
--   MOUSE_WIN_ACCEL — false: без ускорения, 1:1 (как в Windows с выключенной «повышенной точностью»)
local MOUSE_SPEED     = 1.0
local MOUSE_WIN_ACCEL = true
local MICE = { "xctech-wireless-receiver" }   -- имена из `hyprctl devices` (раздел mice)

local function windows_curve(speed)
    -- точки Windows: X — скорость движения мыши, Y — путь курсора
    local X = { 0, 0.43, 1.25, 3.86, 40 }
    local Y = { 0, 1.37, 5.30, 24.30, 568 }
    local norm = speed * 1.25 / 5.30            -- усиление 1:1 на средней скорости
    local step, pts = 0.5, {}
    for i = 0, 16 do                            -- 0 … 8 ед./мс; дальше libinput продолжает последний отрезок
        local v, y = i * step, 0
        for k = 2, #X do
            if v <= X[k] then y = Y[k-1] + (Y[k] - Y[k-1]) * (v - X[k-1]) / (X[k] - X[k-1]); break end
        end
        pts[#pts + 1] = string.format("%.4f", y * norm)
    end
    return "custom " .. step .. " " .. table.concat(pts, " ")
end

for _, name in ipairs(MICE) do
    if MOUSE_WIN_ACCEL then
        hl.device({ name = name, accel_profile = windows_curve(MOUSE_SPEED) })
    else
        hl.device({ name = name, accel_profile = "flat", sensitivity = MOUSE_SPEED - 1 })
    end
end

-- ---------- жесты тачпада как в Windows ----------
-- 3 пальца влево/вправо — Alt+Tab: появляется окно со всеми окнами, каждый свайп двигает выбор,
--   через ~0,8 с после последнего свайпа выбранное окно открывается (overlay/quickshell/switcher)
-- 4 пальца влево/вправо — соседний рабочий стол сразу на всех мониторах — scripts/bin/serp-desk
local home = os.getenv("HOME")
local bin = home .. "/.config/serpantinum/bin/"
local switcher = "quickshell -p " .. home .. "/.local/share/serpantinum/runtime/quickshell/Shell.qml ipc call switcher swipe "
hl.gesture({ fingers = 3, direction = "left",  action = function() hl.exec_cmd(switcher .. "1") end })
hl.gesture({ fingers = 3, direction = "right", action = function() hl.exec_cmd(switcher .. "-1") end })
hl.gesture({ fingers = 4, direction = "left",  action = function() hl.exec_cmd(bin .. "serp-desk next") end })
hl.gesture({ fingers = 4, direction = "right", action = function() hl.exec_cmd(bin .. "serp-desk prev") end })
