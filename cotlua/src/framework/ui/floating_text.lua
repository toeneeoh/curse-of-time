OnInit.global("FloatingText", function()
    ---@type fun(s: string, u: unit, dur: number, speed: number, z: number, size: number, r: integer, g: integer, b: integer, alpha: integer, shared: boolean)
    function FloatingTextUnit(s, u, dur, speed, z, size, r, g, b, alpha, shared)
        local text_tag
        if shared or GetLocalPlayer() == GetOwningPlayer(u) then
            text_tag = CreateTextTag()
        end

        if text_tag then
            SetTextTagText(text_tag, s, size * 0.0023)
            SetTextTagPos(text_tag, GetUnitX(u), GetUnitY(u), z)
            SetTextTagColor(text_tag, r, g, b, 255 - alpha)
            SetTextTagPermanent(text_tag, false)
            SetTextTagVelocity(text_tag, 0, speed / 1803.)
            SetTextTagLifespan(text_tag, dur)
            SetTextTagFadepoint(text_tag, dur - .4)
        end
    end
end)
