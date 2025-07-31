OnInit.final("HighPriestessSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ResurrectionRevival = __jarray(0) ---@type integer[] 

    ---@class INVIGORATION : Spell
    ---@field aoe number
    ---@field heal function
    ---@field mana function
    INVIGORATION = Spell.define("A0DU")
    do
        local thistype = INVIGORATION

        thistype.values = {
            aoe = 850.,
            heal = function(pid) return 0.15 * GetHeroInt(Hero[pid], true) end,
            mana = function(pid) return 0.02 * BlzGetUnitMaxMana(Hero[pid]) end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local heal = thistype.heal(pt.pid) ---@type number 
            local mana = thistype.mana(pt.pid) ---@type number 
            local ug = CreateGroup()
            local ftarget = nil ---@type unit 
            local percent = 100. ---@type number 

            pt.dur = pt.dur + 1

            MakeGroupInRange(pt.pid, ug, pt.x, pt.y, pt.aoe, Condition(FilterAllyHero))

            for target in each(ug) do
                if percent > GetUnitLifePercent(target) then
                    percent = GetUnitLifePercent(target)
                    ftarget = target
                end
            end

            if pt.dur > 10. then
                mana = mana * 2.
            end

            if GetUnitCurrentOrder(Hero[pt.pid]) == OrderId("clusterrockets") and UnitAlive(Hero[pt.pid]) then
                if ModuloReal(pt.dur, 2.) == 0 then
                    MP(Hero[pt.pid], mana)
                end
                if ftarget then
                    heal = (heal + BlzGetUnitMaxHP(ftarget) * 0.01) * BOOST[pt.pid]
                    HP(Hero[pt.pid], ftarget, heal, thistype.tag)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", ftarget, "origin"))
                end

                pt.timer:callDelayed(0.5, periodic, pt)
            else
                pt:destroy()
            end

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.x = self.x
            pt.y = self.y
            pt.aoe = self.aoe * LBOOST[self.pid]

            pt.timer:callDelayed(0.5, periodic, pt)
        end
    end

    ---@class DIVINELIGHT : Spell
    ---@field heal function
    DIVINELIGHT = Spell.define("A0JE")
    do
        local thistype = DIVINELIGHT

        thistype.values = {
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.25 + 0.25 * ablev) * GetHeroInt(Hero[pid], true) end,
        }

        function thistype:onCast()
            BlzStartUnitAbilityCooldown(self.caster, RESURRECTION.id, math.max(0.01, BlzGetUnitAbilityCooldownRemaining(self.caster, RESURRECTION.id) - 2.))

            --because backpack is a valid target
            if GetUnitTypeId(self.target) == BACKPACK then
                self.target = Hero[self.pid]
            end

            HP(self.caster, self.target, (self.heal + BlzGetUnitMaxHP(self.target) * 0.05) * BOOST[self.pid], thistype.tag)
            DivineLightBuff:add(self.caster, self.target):duration(3.)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.05))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class SANCTIFIEDGROUND : Spell
    ---@field ms number
    ---@field regen number
    ---@field aoe number
    ---@field dur function
    SANCTIFIEDGROUND = Spell.define("A0JG")
    do
        local thistype = SANCTIFIEDGROUND

        thistype.values = {
            ms = 20.,
            regen = 100.,
            aoe = 400.,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 11. + ablev end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.dur = pt.dur - 1

            if pt.dur > 0. then
                local ug = CreateGroup()

                MakeGroupInRange(pt.pid, ug, pt.x, pt.y, pt.aoe, Condition(FilterEnemy))

                for target in each(ug) do
                    SanctifiedGroundDebuff:add(Hero[pt.pid], target):duration(1.)
                end

                if pt.dur == 2 then
                    FadeSFX(pt.sfx, true)
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(0.5, periodic, pt)
            else
                pt:destroy()
            end
        end

        function thistype:onCast()
            BlzStartUnitAbilityCooldown(self.caster, RESURRECTION.id, math.max(0.01, BlzGetUnitAbilityCooldownRemaining(self.caster, RESURRECTION.id) - 2.))

            local pt = TimerList[self.pid]:add()
            pt.x = self.targetX
            pt.y = self.targetY
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.dur = self.dur * 2. * LBOOST[self.pid]

            pt.sfx = AddSpecialEffect("war3mapImported\\Heaven's Gate Channel.mdl", pt.x, pt.y)
            BlzSetSpecialEffectScale(pt.sfx, LBOOST[self.pid])
            BlzPlaySpecialEffect(pt.sfx, ANIM_TYPE_BIRTH)
            local loc = Location(pt.x, pt.y)
            BlzSetSpecialEffectZ(pt.sfx, GetLocationZ(loc))
            RemoveLocation(loc)

            pt.timer:callDelayed(0.5, periodic, pt)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.1))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class HOLYRAYS : Spell
    ---@field aoe number
    ---@field heal function
    ---@field dmg function
    HOLYRAYS = Spell.define("A0JD")
    do
        local thistype = HOLYRAYS

        thistype.values = {
            aoe = 600.,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.5 * ablev * GetHeroInt(Hero[pid], true) end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 2. * ablev * GetHeroInt(Hero[pid], true) end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            DamageTarget(source, target, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end
        function thistype:onCast()
            local ug = CreateGroup()

            BlzStartUnitAbilityCooldown(self.caster, RESURRECTION.id, math.max(0.01, BlzGetUnitAbilityCooldownRemaining(self.caster, RESURRECTION.id) - 2.))

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(isalive))

            for target in each(ug) do
                local dummy = Dummy.create(self.x, self.y, FourCC('A09Q'), 1)
                if IsUnitAlly(target, Player(self.pid - 1)) then
                    dummy:attack(target)
                    HP(self.caster, target, self.heal * BOOST[self.pid], thistype.tag)
                else
                    dummy:attack(target, self.caster, on_hit)
                end
            end
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.1))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class PROTECTION : Spell
    ---@field shield function
    ---@field aoe number
    PROTECTION = Spell.define("A0J3")
    do
        local thistype = PROTECTION

        thistype.values = {
            shield = function(pid) return 3. * GetHeroInt(Hero[pid], true) end,
            aoe = 650.,
        }

        function thistype:onCast()
            local ug = CreateGroup()

            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\RighteousGuard.mdx", self.caster, "chest"))
            BlzStartUnitAbilityCooldown(self.caster, RESURRECTION.id, math.max(0.01, BlzGetUnitAbilityCooldownRemaining(self.caster, RESURRECTION.id) - 2.))

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterAllyHero))

            for target in each(ug) do
                ProtectionBuff:add(self.caster, target)
                shield.add(target, self.shield * BOOST[self.pid], 20 + 10 * self.ablev):color(4)
            end
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.5))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class RESURRECTION : Spell
    ---@field restore number
    ---@field spell integer
    RESURRECTION = Spell.define("A048")
    do
        local thistype = RESURRECTION
        thistype.spell = FourCC('A045')

        thistype.values = {
            restore = function(pid) return 40. + 20.* GetUnitAbilityLevel(Hero[pid], thistype.id) end,
        }

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            if target ~= HeroGrave[tpid] then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You must target a tombstone!")
            elseif GetUnitAbilityLevel(HeroGrave[tpid], thistype.spell) > 0 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "This player is already being revived!")
            end
        end

        function thistype:onCast()
            HideEffect(REVIVE_INDICATOR[self.tpid])

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl", self.targetX, self.targetY))
            ResurrectionRevival[self.tpid] = self.pid
            UnitAddAbility(HeroGrave[self.tpid], thistype.spell)
            REVIVE_INDICATOR[self.tpid] = AddSpecialEffect("UI\\Feedback\\Target\\Target.mdx", self.targetX, self.targetY)

            local size = 0.

            if GetLocalPlayer() == Player(self.tpid - 1) then
                size = 15.
            end

            BlzSetSpecialEffectTimeScale(REVIVE_INDICATOR[self.tpid], 0.)
            BlzSetSpecialEffectScale(REVIVE_INDICATOR[self.tpid], size)
            BlzSetSpecialEffectZ(REVIVE_INDICATOR[self.tpid], BlzGetLocalSpecialEffectZ(REVIVE_INDICATOR[self.tpid]) - 100)
            TimerQueue:callDelayed(12.8, DestroyEffect, REVIVE_INDICATOR[self.tpid])
        end

        local function on_death(killed)
            local pid = GetPlayerId(GetOwningPlayer(killed)) + 1
            -- self resurrection
            if BlzGetUnitAbilityCooldownRemaining(killed, thistype.id) <= 0 then
                UnitAddAbility(HeroGrave[pid], thistype.spell)
                BlzStartUnitAbilityCooldown(killed, thistype.id, 450. - 50. * GetUnitAbilityLevel(killed, thistype.id))
                ResurrectionRevival[pid] = pid
            end
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(GetUnitState(u, UNIT_STATE_MANA)))
        end

        function thistype.onLearn(source)
            EVENT_ON_UNIT_DEATH:register_unit_action(source, on_death)
            EVENT_ON_CAST:register_unit_action(source, manacost)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end
end, Debug and Debug.getLine())
