OnInit.final("Hints", function(Require)
    Require('MapSetup')
    Require('TimerQueue')
    Require('HintConfig')

    local function display_hint()
        local next_hint = GetRandomInt(2, #HINT_TOOLTIP)

        if LAST_HINT < 2 then
            LAST_HINT = LAST_HINT + 1
        else
            LAST_HINT = next_hint
        end

        DisplayTimedTextToForce(FORCE_HINT, 15., HINT_TOOLTIP[LAST_HINT])
        if next_hint ~= LAST_HINT then
            LAST_HINT = next_hint
        else
            LAST_HINT = LAST_HINT + 1
        end

        if LAST_HINT > #HINT_TOOLTIP then
            LAST_HINT = 1
        end
    end

    TimerQueue:callPeriodically(240., nil, display_hint)
end, Debug and Debug.getLine())
