-- Виртуальные рабочие столы «как в Windows» (логика — scripts/bin/serp-desk, вид — Win+Tab в оболочке).
-- Рабочий стол N = рабочее пространство N на ноутбуке + 100+N на HDMI (+200+N на DP-1, +300+N на DP-2):
-- при переключении меняются сразу все мониторы.
local home = os.getenv("HOME")
local desk = home .. "/.config/serpantinum/bin/serp-desk"

local bases = { ["eDP-1"] = 0, ["HDMI-A-1"] = 100, ["DP-1"] = 200, ["DP-2"] = 300 }
for mon, base in pairs(bases) do
    for d = 1, 20 do
        hl.workspace_rule({ workspace = tostring(base + d), monitor = mon, default = (d == 1) })
    end
end

-- Win+Ctrl+D — новый стол, Win+Ctrl+←/→ — листать, Win+Ctrl+F4 — закрыть текущий (окна переедут на соседний)
hl.bind("SUPER + CTRL + D",     hl.dsp.exec_cmd(desk .. " new"))
hl.bind("SUPER + CTRL + left",  hl.dsp.exec_cmd(desk .. " prev"))
hl.bind("SUPER + CTRL + right", hl.dsp.exec_cmd(desk .. " next"))
hl.bind("SUPER + CTRL + F4",    hl.dsp.exec_cmd(desk .. " close"))
-- Win+1…9 — перейти на стол N, Win+Shift+1…9 — перенести окно на стол N
for i = 1, 9 do
    hl.bind("SUPER + " .. i,         hl.dsp.exec_cmd(desk .. " go " .. i))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.exec_cmd(desk .. " move " .. i))
end
-- Win+Ctrl+Shift+←/→ — перенести окно на соседний стол и перейти туда
hl.bind("SUPER + CTRL + SHIFT + left",  hl.dsp.exec_cmd(desk .. " carry prev"))
hl.bind("SUPER + CTRL + SHIFT + right", hl.dsp.exec_cmd(desk .. " carry next"))

-- Alt+Tab как в Windows (отпустить Alt — перейти к окну), Win+Tab — «Представление задач»
local sw = "quickshell -p " .. home .. "/.local/share/serpantinum/runtime/quickshell/Shell.qml ipc call switcher "
hl.bind("ALT + Tab",         hl.dsp.exec_cmd(sw .. "next"), { repeating = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(sw .. "prev"), { repeating = true })
hl.bind("ALT + Alt_L",       hl.dsp.exec_cmd(sw .. "commit"), { release = true })
hl.bind("CTRL + ALT + Tab",  hl.dsp.exec_cmd(sw .. "sticky"))   -- Alt+Tab, который не закрывается при отпускании Alt
hl.bind("SUPER + Tab",       hl.dsp.exec_cmd(sw .. "view"))
