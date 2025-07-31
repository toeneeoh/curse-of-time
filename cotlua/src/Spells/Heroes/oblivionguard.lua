OnInit.final("OblivionGuardSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ---@class BODYOFFIRE : Spell
    ---@field dmg function
    ---@field cooldown function
    ---@field charges integer[]
    BODYOFFIRE = Spell.define("A07R")
    do
        local thistype = BODYOFFIRE

        thistype.charges = __jarray(0)
        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroStr(Hero[pid], true) * (0.25 + 0.05 * ablev) end,
        }

        ---@type fun(pt: PlayerTimer)
        function thistype.cooldown(pt)
            local MAX_CHARGES = 5

            BODYOFFIRE.charges[pt.pid] = IMinBJ(MAX_CHARGES, BODYOFFIRE.charges[pt.pid] + 1)
            UnitDisableAbility(pt.source, INFERNALSTRIKE.id, false)
            UnitDisableAbility(pt.source, MAGNETICSTRIKE.id, false)

            if GetLocalPlayer() == Player(pt.pid - 1) then
                BlzSetAbilityIcon(BODYOFFIRE.id, "ReplaceableTextures\\CommandButtons\\BTNBodyOfFire" .. (BODYOFFIRE.charges[pt.pid]) .. ".blp")
            end

            if BODYOFFIRE.charges[pt.pid] >= MAX_CHARGES then
                BlzStartUnitAbilityCooldown(pt.source, BODYOFFIRE.id, 0.)
                pt:destroy()
            else
                BlzStartUnitAbilityCooldown(pt.source, BODYOFFIRE.id, 5.)
                pt.timer:callDelayed(5., thistype.cooldown, pt)
            end
        end

        local function on_hit(target, source, amount, amount_after_red, damage_type)
            local ablev = GetUnitAbilityLevel(target, BODYOFFIRE.id)
            if ablev > 0 and damage_type == PHYSICAL and IsUnitEnemy(target, GetOwningPlayer(source)) then
                local tpid = GetPlayerId(GetOwningPlayer(target)) + 1
                local returnDmg = (amount_after_red * 0.05 * ablev) + BODYOFFIRE.dmg(tpid)
                DamageTarget(target, source, returnDmg * BOOST[tpid], ATTACK_TYPE_NORMAL, MAGIC, BODYOFFIRE.tag)
            end
        end

        function thistype.onSetup(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            thistype.charges[pid] = 5 --default

            if GetLocalPlayer() == Player(pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNBodyOfFire" .. (thistype.charges[pid]) .. ".blp")
            end

            EVENT_ON_STRUCK_AFTER_REDUCTIONS:register_unit_action(u, on_hit)
        end
    end

    ---@class METEOR : Spell
    ---@field dmg function
    ---@field aoe number
    ---@field dur number
    METEOR = Spell.define("A07O")
    do
        local thistype = METEOR
        thistype.preCast = DASH_PRECAST

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroStr(Hero[pid], true) * ablev * 1. end,
            aoe = 300.,
            dur = 1.,
        }

        ---@type fun(pt: PlayerTimer)
        local function expire(pt)
            local ug = CreateGroup()

            DestroyTreesInRange(pt.x, pt.y, 250)
            reselect(Hero[pt.pid])
            BlzPauseUnitEx(Hero[pt.pid], false)

            MakeGroupInRange(pt.pid, ug, pt.x, pt.y, thistype.aoe * LBOOST[pt.pid], Condition(FilterEnemy))

            for target in each(ug) do
                Stun:add(Hero[pt.pid], target):duration(thistype.dur * LBOOST[pt.pid])
                DamageTarget(Hero[pt.pid], target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            if SquareRoot(Pow(GetUnitX(Hero[pt.pid]) - pt.x, 2) + Pow(GetUnitY(Hero[pt.pid]) - pt.y, 2)) < 1000. then
                SetUnitPosition(Hero[pt.pid], pt.x, pt.y)
            end

            SetUnitAnimation(Hero[pt.pid], "birth")
            SetUnitTimeScale(Hero[pt.pid], 1)
            Fade(Hero[pt.pid], 0.8, false)

            DestroyGroup(ug)

            pt:destroy()
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.x = self.targetX
            pt.y = self.targetY

            BlzPauseUnitEx(self.caster, true)
            SetUnitAnimation(self.caster, "death")
            SetUnitTimeScale(self.caster, 2)
            Fade(self.caster, 0.8, true)

            local sfx = AddSpecialEffect("Units\\Demon\\Infernal\\InfernalBirth.mdl", pt.x, pt.y)
            BlzSetSpecialEffectScale(sfx, 2.5)
            TimerQueue:callDelayed(2., DestroyEffect, sfx)
            BlzSetSpecialEffectYaw(sfx, self.angle)

            pt.timer:callDelayed(0.9, expire, pt)
        end
    end

    ---@class MAGNETICSTANCE : Spell
    MAGNETICSTANCE = Spell.define("A076")
    do
        local thistype = MAGNETICSTANCE

        function thistype:onCast()
            MagneticStanceBuff:add(self.caster, self.caster)
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_UNIMMOLATION and IsUnitPaused(source) == false and IsUnitLoaded(source) == false then
                MagneticStanceBuff:dispel(source, source)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            MagneticStanceBuff:refresh(source, source)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class INFERNALSTRIKE : Spell
    ---@field dmg function
    ---@field aoe number
    INFERNALSTRIKE = Spell.define("A05S")
    do
        local thistype = INFERNALSTRIKE

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroStr(Hero[pid], true) * ablev * 1. end,
            aoe = 250.,
        }

        function thistype:onCast()
            MagneticStrikeBuff:dispel(self.caster, self.caster)
            InfernalStrikeBuff:add(self.caster, self.caster)
        end
    end

    ---@class MAGNETICSTRIKE : Spell
    ---@field aoe function
    ---@field dur function
    MAGNETICSTRIKE = Spell.define("A047")
    do
        local thistype = MAGNETICSTRIKE

        thistype.values = {
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 25. * ablev + 200. end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 4 end,
        }

        function thistype:onCast()
            InfernalStrikeBuff:dispel(self.caster, self.caster)
            MagneticStrikeBuff:add(self.caster, self.caster)
        end
    end

    ---@class GATEKEEPERSPACT : Spell
    ---@field dmg function
    ---@field aoe function
    GATEKEEPERSPACT = Spell.define("A0GJ")
    do
        local thistype = GATEKEEPERSPACT

        thistype.values = {
            dmg = function(pid) return GetHeroStr(Hero[pid], true) * 15. end,
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 550. + 50. * ablev end,
        }

        ---@type fun(pt: PlayerTimer)
        local function expire(pt)
            local ug = CreateGroup()
            local sfx = AddSpecialEffect("war3mapImported\\AnnihilationBlast.mdx", GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]))

            BlzSetSpecialEffectColor(sfx, 25, 255, 0)
            DestroyEffect(sfx)

            SetUnitAnimationByIndex(Hero[pt.pid], 2)
            BlzPauseUnitEx(Hero[pt.pid], false)
            MakeGroupInRange(pt.pid, ug, GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]), thistype.aoe(pt.pid) * LBOOST[pt.pid], Condition(FilterEnemy))

            for target in each(ug) do
                StunUnit(pt.pid, target, 5.)
                DamageTarget(Hero[pt.pid], target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            pt:destroy()

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            BlzPauseUnitEx(self.caster, true)
            TimerQueue:callDelayed(2, DestroyEffect, AddSpecialEffect("war3mapImported\\AnnihilationTarget.mdx", self.x, self.y))
            pt.timer:callDelayed(2, expire, pt)
        end
    end
end, Debug and Debug.getLine())
