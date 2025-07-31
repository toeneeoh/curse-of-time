OnInit.final("BloodzerkerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32

    ---@class BLOODFRENZY : Spell
    BLOODFRENZY = Spell.define("A05Y")
    do
        local thistype = BLOODFRENZY

        function thistype:onCast()
            BloodFrenzyBuff:add(self.caster, self.caster):duration(5.)
        end
    end

    ---@class BLOODLEAP : Spell
    ---@field dmg function
    ---@field aoe number
    BLOODLEAP = Spell.define("A05Z")
    do
        local thistype = BLOODLEAP
        thistype.preCast = DASH_PRECAST

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.4 + 0.4 * ablev) * (Unit[Hero[pid]].damage) end,
            aoe = 300.,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            if pt.dur > 0. and IsUnitInRangeXY(pt.target, pt.x, pt.y, pt.dur) then
                local x = GetUnitX(pt.target)
                local y = GetUnitY(pt.target)
                local accel = pt.dur / pt.dist
                --movement
                SetUnitXBounded(pt.target, x + (pt.speed / (1 + accel)) * math.cos(pt.angle))
                SetUnitYBounded(pt.target, y + (pt.speed / (1 + accel)) * math.sin(pt.angle))
                pt.dur = pt.dur - (pt.speed / (1 + accel))

                if pt.dur <= pt.dist - 120 and pt.dur >= pt.dist - 160 then -- sick animation
                    SetUnitTimeScale(pt.target, 0)
                end

                accel = pt.dur / pt.dist

                SetUnitFlyHeight(pt.target, 20 + pt.dist * (1. - accel) * accel * 1.3, 0)

                if pt.dur <= 0 then
                    local ug = CreateGroup()
                    if DistanceCoords(x, y, pt.x, pt.y) < 25. then
                        SetUnitXBounded(pt.target, pt.x)
                        SetUnitYBounded(pt.target, pt.y)
                    end

                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y))
                    MakeGroupInRange(pt.pid, ug, pt.x, pt.y, thistype.aoe * LBOOST[pt.pid], Condition(FilterEnemy))

                    for target in each(ug) do
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Devour\\DevourEffectArt.mdl", target, "chest"))
                        DamageTarget(pt.target, target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end

                    DestroyGroup(ug)
                end

                pt.timer:callDelayed(FPS_32, periodic, pt)
            else
                SetUnitFlyHeight(pt.target, 0, 0)
                reselect(pt.target)
                SetUnitTimeScale(pt.target, 1.)
                SetUnitPropWindow(pt.target, bj_DEGTORAD * 60.)
                SetUnitPathing(pt.target, true)
                pt:destroy()
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            --minimum distance
            local dur = math.max(DistanceCoords(self.x, self.y, self.targetX, self.targetY), 400.) ---@type number 

            self.x = self.x + dur * math.cos(self.angle)
            self.y = self.y + dur * math.sin(self.angle)

            pt.angle = self.angle
            pt.dur = dur
            pt.dist = dur
            pt.speed = 40.
            pt.target = self.caster
            pt.x = self.x
            pt.y = self.y

            if UnitAddAbility(self.caster, FourCC('Amrf')) then
                UnitRemoveAbility(self.caster, FourCC('Amrf'))
            end

            SetUnitTimeScale(self.caster, 0.75)
            SetUnitPathing(self.caster, false)
            SetUnitPropWindow(self.caster, 0)
            DelayAnimation(self.pid, self.caster, (pt.dur / 30. * FPS_32) + 0.5, 1, 0, false)

            pt.timer:callDelayed(FPS_32, periodic, pt)
        end
    end

    ---@class BLOODCURDLINGSCREAM : Spell
    ---@field aoe number
    ---@field dur function
    BLOODCURDLINGSCREAM = Spell.define("A06H")
    do
        local thistype = BLOODCURDLINGSCREAM

        thistype.values = {
            aoe = 500.,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 6 end,
        }

        function thistype:onCast()
            local ug = CreateGroup()

            DamageTarget(self.caster, self.caster, 0.1 * BlzGetUnitMaxHP(self.caster), ATTACK_TYPE_NORMAL, PURE, thistype.tag)
            MakeGroupInRange(self.pid, ug, self.x, self.y, thistype.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            for target in each(ug) do
                BloodCurdlingScreamDebuff:add(self.caster, target):duration(self.dur * LBOOST[self.pid])
            end

            DestroyGroup(ug)
        end
    end

    ---@class BLOODCLEAVE : Spell
    ---@field chance number
    ---@field aoe function
    ---@field dmg function
    BLOODCLEAVE = Spell.define("A05X")
    do
        local thistype = BLOODCLEAVE

        thistype.values = {
            chance = 20.,
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 195. + 5. * ablev end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.45 + 0.05 * ablev) * (Unit[Hero[pid]].damage) end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local chance = BLOODCLEAVE.chance
            local double = 1

            if RampageBuff:has(source, source) then
                chance = chance + 5
            end

            if UndyingRageBuff:has(source, source) then
                chance = chance * 2
                double = 2
            end

            if math.random() * 100. < chance * LBOOST[pid] then
                local heal = 0
                local ug = CreateGroup()
                MakeGroupInRange(pid, ug, GetUnitX(source), GetUnitY(source), BLOODCLEAVE.aoe(pid) * LBOOST[pid], Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Reapers Claws Red.mdx", source, "chest"))

                for u in each(ug) do
                    local cd = (math.random() * 100. < Unit[source].cc and (1. + Unit[source].cd * 0.01)) or 1
                    DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Coup de Grace.mdx", u, "chest"))
                    heal = heal + BLOODCLEAVE.dmg(pid) * BOOST[pid] * ApplyArmorMult(source, target, PHYSICAL) * cd * Unit[source].pm
                    DamageTarget(source, u, BLOODCLEAVE.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, PHYSICAL, BLOODCLEAVE.tag)
                end

                DestroyGroup(ug)

                --leech health
                HP(source, source, heal * double, BLOODCLEAVE.tag)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                EVENT_ON_HIT:register_unit_action(source, on_hit)
            end
        end
    end

    ---@class RAMPAGE : Spell
    ---@field pen function
    RAMPAGE = Spell.define("A0GZ")
    do
        local thistype = RAMPAGE
        thistype.pen = function(pid) return (5 * GetUnitAbilityLevel(Hero[pid], RAMPAGE.id)) end

        local function on_order(source, target, id)
            if id == ORDER_ID_UNIMMOLATION then
                if IsUnitPaused(source) == false and IsUnitLoaded(source) == false then
                    RampageBuff:dispel(source, source)
                end
            end
        end

        function thistype:onCast()
            RampageBuff:add(self.caster, self.caster)
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class UNDYINGRAGE : Spell
    ---@field dur number
    ---@field regen number[]
    ---@field attack number[]
    ---@field timer TimerQueue[]
    ---@field onHit function
    UNDYINGRAGE = Spell.define("A0AD")
    do
        local thistype = UNDYINGRAGE

        thistype.values = {
            dur = 10.,
            regen = __jarray(0),
            attack = __jarray(0),
        }
        thistype.timer = {}

        function thistype.onHit(target, source, amount, amount_after_red, damage_type)
            --undying rage delayed damage
            buff = UndyingRageBuff:get(nil, target)

            if buff then
                amount.value = 0.
                buff:addRegen(-amount_after_red)
            end
        end

        local function regen(pid)
            local hp = GetWidgetLife(Hero[pid])
            local maxhp = BlzGetUnitMaxHP(Hero[pid])
            thistype.values.regen[pid] = R2I(GetHeroStr(Hero[pid], true) - (hp / maxhp) * GetHeroStr(Hero[pid], true))
            return thistype.values.regen[pid]
        end

        -- updates bonus attack and regen periodically
        local function refresh(pid, ratio)
            local u = Unit[Hero[pid]]
            local untouched_damage = BlzGetUnitBaseDamage(Hero[pid], 0) + Unit[Hero[pid]].bonus_damage

            u.damage_percent = u.damage_percent - ratio
            u.regen_flat = u.regen_flat - thistype.values.regen[pid]

            local maxhp = BlzGetUnitMaxHP(Hero[pid])
            local hp = GetWidgetLife(Hero[pid])
            ratio = 1. - (hp / maxhp)

            thistype.attack[pid] = untouched_damage * ratio

            u.damage_percent = u.damage_percent + ratio
            u.regen_flat = u.regen_flat + regen(pid)

            thistype.timer[pid] = TimerQueue:callDelayed(0.25, refresh, pid, ratio)
        end

        function thistype:onCast()
            UndyingRageBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
        end

        local function on_cleanup(pid)
            if thistype.timer[pid] then
                TimerQueue:disableCallback(thistype.timer[pid])
            end
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
                refresh(pid, 0)
            end
        end
    end
end, Debug and Debug.getLine())
