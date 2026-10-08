OnInit.global("UnitAnimation", function(Require)
    Require('PlayerTimer')

    ---@type fun(pt: PlayerTimer)
    function DelayAnimationExpire(pt)
        if pt.pause then
            BlzPauseUnitEx(pt.target, false)
        end

        if pt.dur > 0. then
            SetUnitTimeScale(pt.target, pt.dur)
        end

        if UnitAlive(pt.target) then
            SetUnitAnimationByIndex(pt.target, pt.index)
        end
    end

    ---@type fun(pid: integer, u: unit, delay: number, index: integer, timescale: number, pause: boolean)
    function DelayAnimation(pid, u, delay, index, timescale, pause)
        local timer = TimerList[pid]:add()
        timer.target = u
        timer.index = index
        timer.pause = false
        timer.dur = timescale

        if pause then
            BlzPauseUnitEx(u, true)
            timer.pause = true
        end

        timer:after(delay, DelayAnimationExpire)
    end
end)
