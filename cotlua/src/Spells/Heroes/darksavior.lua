OnInit.final("DarkSaviorSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ---@class SOULSTEAL : Spell
    SOULSTEAL = Spell.define("A08Z")
    do
        local thistype = SOULSTEAL

        local function on_death(pid, killed, killer)
            local U = User.first
            while U do
                if UnitAlive(Hero[U.id]) and IsUnitInRange(Hero[U.id], killed, 1000. * LBOOST[U.id]) and GetUnitAbilityLevel(Hero[U.id], thistype.id) > 0 then
                    HP(Hero[U.id], Hero[U.id], BlzGetUnitMaxHP(Hero[U.id]) * 0.04, thistype.tag)
                    MP(Hero[U.id], BlzGetUnitMaxMana(Hero[U.id]) * 0.04)
                end
                U = U.next
            end
        end

        EVENT_ON_DEATH:register_action(BOSS_ID, on_death)
        EVENT_ON_DEATH:register_action(CREEP_ID, on_death)
    end

    ---@class DARKSEAL : Spell
    ---@field dur number
    DARKSEAL = Spell.define("A0GO")
    do
        local thistype = DARKSEAL

        thistype.values = {
            dur = 12.,
        }

        function thistype:onCast()
            local b = DarkSealBuff:add(self.caster, self.caster)

            b:duration(self.dur * LBOOST[self.pid])
            b.x = self.targetX
            b.y = self.targetY
            SetUnitXBounded(b.sfx, b.x)
            SetUnitYBounded(b.sfx, b.y)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.2))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class MEDEANLIGHTNING : Spell
    ---@field targets function
    ---@field dmg function
    ---@field aoe number
    ---@field dur number
    MEDEANLIGHTNING = Spell.define("A019")
    do
        local thistype = MEDEANLIGHTNING

        thistype.values = {
            targets = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 1.5 end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (1.5 + 0.5 * ablev) * GetHeroInt(Hero[pid], true) end,
            aoe = 900.,
            dur = 3.,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            DamageTarget(source, target, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local x = GetUnitX(pt.source) ---@type number 
            local y = GetUnitY(pt.source) ---@type number 

            pt.dur = pt.dur - 1
            DestroyEffect(pt.sfx)

            if pt.dur < 0 then
                pt:destroy()
            else
                local ug = CreateGroup()

                MakeGroupInRange(pt.pid, ug, x, y, pt.aoe, Condition(FilterEnemy))

                local target
                for i = 0, pt.time - 1 do
                    target = BlzGroupUnitAt(ug, i)
                    if not target then break end
                    local dummy = Dummy.create(x, y, FourCC('A01Y'), 1, 2.5)
                    dummy:attack(target, pt.source, on_hit)
                end

                --dark seal augment
                local b = DarkSealBuff:get(pt.source, pt.source)

                if b then
                    BlzGroupAddGroupFast(ug, b.ug)
                    local count = BlzGroupGetSize(ug)

                    if count > 0 then
                        for index = 0, count - 1 do
                            target = BlzGroupUnitAt(ug, index)

                            if GetUnitAbilityLevel(target, FourCC('A06W')) > 0 then
                                local angle = 360. / count * (index + 1) * bj_DEGTORAD
                                x = b.x + 380 * math.cos(angle)
                                y = b.y + 380 * math.sin(angle)

                                local dummy = Dummy.create(x, y, FourCC('A01Y'), 1, 2.5)
                                dummy:attack(target, pt.source, on_hit)
                            end
                        end
                    end
                end

                if pt.dur > 0. then
                    pt.sfx = AddSpecialEffectTarget("war3mapImported\\LightningShield" .. IMinBJ(3, R2I(pt.dur)) .. ".mdx", Hero[pt.pid], "origin")
                    BlzSetSpecialEffectTimeScale(pt.sfx, 1.5)
                    BlzPlaySpecialEffect(pt.sfx, ANIM_TYPE_STAND)
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(1., periodic, pt)
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.time = R2I(self.targets * LBOOST[self.pid])
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.dur = self.dur * LBOOST[self.pid]
            pt.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\LightningShield\\LightningShieldTarget.mdl", self.caster, "origin")
            pt.source = self.caster
            BlzSetSpecialEffectTimeScale(pt.sfx, 1.5)

            pt.timer:callDelayed(1., periodic, pt)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.1))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class FREEZINGBLAST : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field slow number
    ---@field freeze number
    FREEZINGBLAST = Spell.define("A074")
    do
        local thistype = FREEZINGBLAST

        thistype.values = {
            aoe = 250.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (ablev + 2.) end,
            slow = 3.,
            freeze = 1.5,
        }

        function thistype:onCast()
            local b = DarkSealBuff:get(self.caster, self.caster)
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            --dark seal
            if b then
                BlzGroupAddGroupFast(ug, b.ug)

                local sfx = AddSpecialEffect("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", b.x, b.y)
                BlzSetSpecialEffectScale(sfx, 5)
                TimerQueue:callDelayed(3, DestroyEffect, sfx)
            end

            DestroyEffect(AddSpecialEffect("war3mapImported\\AquaSpikeVersion2.mdx", self.targetX, self.targetY))

            for target in each(ug) do
                Freeze:add(self.caster, target):duration(self.freeze * LBOOST[self.pid])
                if IsUnitInRangeXY(target, self.targetX, self.targetY, self.aoe * LBOOST[self.pid]) == true and b then
                    DamageTarget(self.caster, target, self.dmg * 2 * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                else
                    DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
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

    ---@class DARKBLADE : Spell
    ---@field dmg function
    ---@field cost function
    DARKBLADE = Spell.define("AEim")
    do
        local thistype = DARKBLADE

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.6 + 0.1 * ablev) * GetHeroInt(Hero[pid], true) end,
        }

        local function on_hit(source, target)
            if GetUnitAbilityLevel(source, FourCC('B01A')) > 0 then
                local pid = GetPlayerId(GetOwningPlayer(source)) + 1
                local maxmp = BlzGetUnitMaxMana(source)
                local pmana = GetUnitState(source, UNIT_STATE_MANA) / maxmp * 100.
                local pgain = (MetamorphosisBuff:has(source, source) and 0.5) or -1.0

                if pmana >= 0.5 or pgain > 0 then
                    SetUnitState(source, UNIT_STATE_MANA, (pmana + pgain) * maxmp * 0.01)
                    DamageTarget(source, target, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                else
                    IssueImmediateOrder(source, "unimmolation")
                end
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_HIT:register_unit_action(source, on_hit)
        end
    end

    ---@class METAMORPHOSIS : Spell
    ---@field dur function
    METAMORPHOSIS = Spell.define("A02S")
    do
        local thistype = METAMORPHOSIS

        thistype.values = {
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 5. + 5. * ablev end,
        }

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local ablev = GetUnitAbilityLevel(caster, thistype.id)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(caster, METAMORPHOSIS.id), ABILITY_RLF_DURATION_HERO, ablev - 1, thistype.dur(pid) * LBOOST[pid])
        end

        function thistype:onCast()
            if GetUnitTypeId(self.caster) == HERO_DARK_SAVIOR then
                MetamorphosisBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
            end
        end
    end
end, Debug and Debug.getLine())
