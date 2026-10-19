-- Serpantinum — точка входа Hyprland. Модули лежат в modules/.
-- Порядок важен: сначала окружение и ввод, затем внешний вид, затем бинды.
require("modules.env")
require("modules.monitors")
require("modules.input")
require("modules.look")
require("modules.animations")
require("modules.binds")
require("modules.rules")
require("modules.windows")
require("modules.desktops")
require("modules.autostart")
