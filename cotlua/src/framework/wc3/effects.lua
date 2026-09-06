OnInit.global("Effects", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local min, max = math.min, math.max

    ---@type fun(sfx: effect)
    function HideEffect(sfx)
        BlzSetSpecialEffectScale(sfx, 0.)
        BlzSetSpecialEffectPosition(sfx, 30000., 30000., 0.)
        DestroyEffect(sfx)
    end

    local function apply_fade(u, dur, fade, amount)
        local r = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_RED)
        local g = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_BLUE)
        local b = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_GREEN)

        if GetUnitAbilityLevel(u, FourCC('Bmag')) > 0 then
            r = 255
            g = 25
            b = 25
        end

        amount = amount + 255 / (dur * 32)

        if fade then
            SetUnitVertexColor(u, r, g, b, math.floor(max(255 - amount, 0)))
        else
            SetUnitVertexColor(u, r, g, b, math.floor(min(255, amount)))
        end

        if amount < 255 and UnitAlive(u) then
            TQ:callDelayed(FPS_32, apply_fade, u, dur, fade, amount)
        end
    end

    ---@type fun(u: unit, dur: number, fade: boolean)
    function Fade(u, dur, fade)
        TQ:callDelayed(0, apply_fade, u, dur, fade, 0)
    end

    local function apply_sfx_fade(sfx, fade, count)
        count = count - 1

        if count > 0 then
            if fade then
                BlzSetSpecialEffectAlpha(sfx, count * 7)
            else
                BlzSetSpecialEffectAlpha(sfx, 255 - count * 7)
            end

            TQ:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
        end
    end

    ---@type fun(sfx: effect, fade: boolean)
    function FadeSFX(sfx, fade)
        local count = 40

        if not fade then
            BlzSetSpecialEffectAlpha(sfx, 0)
        end

        TQ:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
    end
end)
