OnInit.final("TeleportAbilities", function(Require)
    Require('MainMap')
    Require("Spells")

    local TQ = TimerQueue
    local FPS_32 = FPS_32

    TELEPORT = Spell.define('A02J')
    do
        local thistype = TELEPORT

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= MAIN_MAP.rect or r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't teleport there.")
            end
        end

        local function on_expire(pt)
            local x, y = GetUnitX(pt.source), GetUnitY(pt.source)
            Unit[pt.source].busy = false
            BlzPauseUnitEx(Backpack[pt.pid], false)

            if UnitAlive(pt.source) then
                SetUnitPosition(pt.source, pt.x, pt.y)
                SetUnitPosition(Backpack[pt.pid], pt.x, pt.y)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", pt.x, pt.y))
            end
        end

        ---@type fun(pid: integer, u: unit, dur: number)
        local function teleport(pid, u, dur)
            local pt = TimerList[pid]:add()
            local x, y = GetUnitX(u), GetUnitY(u)
            pt.source = Hero[pid]
            pt.x = x
            pt.y = y

            Unit[Hero[pid]].busy = true
            BlzPauseUnitEx(Backpack[pid], true)
            TQ:callDelayed(dur, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl", x, y))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", Backpack[pid], "origin"))

            pt:after(dur, on_expire)
        end

        function thistype:onCast()
            if self.ablev > 1 then
                teleport(self.pid, self.target, 3 - self.ablev * .25)
            else
                teleport(self.pid, self.target, 3)
            end
        end
    end

    TELEPORT_HOME = Spell.define('A0FV')
    do
        local thistype = TELEPORT_HOME

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)

            if not (r == MAIN_MAP.rect or r == gg_rct_Cave or r == gg_rct_Gods_Arena or r == gg_rct_Tavern) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't teleport here.")
            end
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - FPS_32

            BlzSetSpecialEffectTime(pt.sfx, math.max(0, 1. - pt.dur / pt.time))

            if pt.dur >= 0 then
                return true
            end

            Unit[pt.source].busy = false
            PauseUnit(pt.source, false)
            PauseUnit(Backpack[pt.pid], false)
            MoveHero(pt.pid, TOWN_CENTER_X, TOWN_CENTER_Y)
            BlzSetSpecialEffectTimeScale(pt.sfx, 5.)
            BlzPlaySpecialEffect(pt.sfx, ANIM_TYPE_DEATH)

            return false
        end

        ---@param pid integer
        ---@param dur integer
        local function teleport(pid, caster, dur)
            local pt = TimerList[pid]:add()

            Unit[caster].busy = true
            PauseUnit(Backpack[pid], true)
            PauseUnit(caster, true)

            pt.source = caster
            pt.dur = dur
            pt.time = dur
            pt.sfx = AddSpecialEffect("war3mapImported\\Progressbar.mdl", GetUnitX(caster), GetUnitY(caster))

            BlzSetSpecialEffectZ(pt.sfx, BlzGetUnitZ(caster) + 200.0)
            BlzSetSpecialEffectTimeScale(pt.sfx, 0.001)
            BlzSetSpecialEffectColorByPlayer(pt.sfx, Player(4))
            pt:startLoop(FPS_32, periodic)
        end

        function thistype:onCast()
            if self.ablev > 1 then
                teleport(self.pid, self.caster, 11 - self.ablev)
            else
                teleport(self.pid, self.caster, 12)
            end
        end
    end
end, Debug and Debug.getLine())


