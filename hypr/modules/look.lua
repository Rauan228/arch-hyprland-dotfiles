-- Внешний вид (базовый, как в исходном конфиге; полный дизайн — этап 2).
hl.config({
    general = {
        -- окна на всю площадь экрана: панели скрываются и появляются при наведении
        gaps_in  = 3,
        gaps_out = 0,
        border_size = 2,
        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled  = true,
            size     = 7,
            passes   = 3,
            vibrancy = 0.1696,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})
