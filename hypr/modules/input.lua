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
