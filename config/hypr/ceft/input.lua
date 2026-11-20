-- Teclado, ratón, touchpad y gestos.
return function(S)
    local I = S.input
    hl.config({
        input = {
            kb_layout  = I.kb_layout,
            kb_variant = I.kb_variant,
            kb_model   = "",
            kb_options = I.kb_options,
            kb_rules   = "",
            follow_mouse = I.follow_mouse,
            sensitivity  = I.sensitivity,
            repeat_delay = I.repeat_delay,
            repeat_rate  = I.repeat_rate,
            numlock_by_default = I.numlock_by_default,
            touchpad = { natural_scroll = I.natural_scroll },
        },
    })

    if I.workspace_swipe_fingers and I.workspace_swipe_fingers > 0 then
        hl.gesture({ fingers = I.workspace_swipe_fingers, direction = "horizontal", action = "workspace" })
    end
end
