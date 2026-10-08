OnInit.global("EconomyEffects", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local conversion_cd = {}
    local cos, sin = math.cos, math.sin

    local function reset_conversion_cooldown(pid)
        conversion_cd[pid] = nil
    end

    ---@param pid integer
    function ConversionEffect(pid)
        if conversion_cd[pid] then
            return
        end

        conversion_cd[pid] = true
        TimerQueue:callDelayed(1., reset_conversion_cooldown, pid)

        local x = GetUnitX(Hero[pid])
        local y = GetUnitY(Hero[pid])

        for ring = 1, 3 do
            for point = 1, ring * 4 do
                local distance = ring * 40
                local angle = 2. * bj_PI / (ring * 4) * point
                local effect = AddSpecialEffect(
                    "Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl",
                    x + distance * cos(angle),
                    y + distance * sin(angle)
                )

                BlzSetSpecialEffectColor(effect, 50, 50, 255)
                DestroyEffect(effect)
            end
        end
    end
end, Debug and Debug.getLine())
