OnInit.final("DarkSaviorSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local TQ = TimerQueue

    ---@class DARKSEAL : Spell
    ---@field dur number
    DARKSEAL = Spell.define("A0GO")
    do
        local thistype = DARKSEAL

        thistype.values = {
            dur = 12.,
        }

        function thistype:onCast()
            local b = DarkSealBuff:create(self.caster, self.caster)
            b.x = self.targetX
            b.y = self.targetY

            b:check(self.caster, self.caster)
            b:duration(self.dur * LBOOST[self.pid])
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.2))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class DARKBLADE : Spell
    ---@field dmg function
    ---@field cost function
    DARKBLADE = Spell.define("A013")
    do
        local thistype = DARKBLADE

        thistype.values = {
            dmg = function(pid) return 1.5 * GetHeroInt(Hero[pid], true) end,
            dur = function(pid) return 10. end,
        }

        function thistype:onCast()
            DarkBladeBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
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

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            local x = GetUnitX(pt.source) ---@type number 
            local y = GetUnitY(pt.source) ---@type number 

            pt.dur = pt.dur - 1
            DestroyEffect(pt.sfx)

            if pt.dur >= 0 then
                MakeGroupInRange(pt.pid, pt.ug, x, y, pt.aoe, Condition(FilterEnemy))

                local target
                for i = 0, pt.time - 1 do
                    target = BlzGroupUnitAt(pt.ug, i)
                    if not target then break end
                    local dummy = Dummy.create(x, y, FourCC('A01Y'), 1, 2.5)
                    dummy:attack(target, pt.source, on_hit)
                end

                -- dark seal augment
                local b = DarkSealBuff:get(pt.source, pt.source)

                if b then
                    BlzGroupAddGroupFast(pt.ug, b.ug)
                    local count = BlzGroupGetSize(pt.ug)

                    if count > 0 then
                        for index = 0, count - 1 do
                            target = BlzGroupUnitAt(pt.ug, index)

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

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.time = R2I(self.targets * LBOOST[self.pid])
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.dur = self.dur * LBOOST[self.pid]
            pt.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\LightningShield\\LightningShieldTarget.mdl", self.caster, "origin")
            pt.source = self.caster
            pt.ug = CreateGroup()
            BlzSetSpecialEffectTimeScale(pt.sfx, 1.5)

            pt:startLoop(1., periodic)
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.1))
            end
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

        local function slow(self)
            FreezingBlastDebuff:add(self.source, self.target):duration(FREEZINGBLAST.freeze * LBOOST[self.pid])
        end

        function thistype:onCast()
            local b = DarkSealBuff:get(self.caster, self.caster)
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            -- dark seal
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

                -- apply slow after
                TQ:callDelayed(self.freeze * LBOOST[self.pid], slow, self)
            end
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.1))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class DARKSHIELD : Spell
    DARKSHIELD = Spell.define("A00A")
    do
        local thistype = DARKSHIELD

        thistype.values = {
        }

        local function on_order(source, target, id)
            if id == ORDER_ID_MANA_SHIELD and GetUnitAbilityLevel(source, thistype.id) > 0 then
                UnitDisableAbility(source, thistype.id, true)
                UnitDisableAbility(source, thistype.id, false)
                BlzStartUnitAbilityCooldown(source, thistype.id, 2.)

                local buff = DarkShieldBuff:get(nil, source)

                if buff then
                    DarkShieldBuff:dispel(nil, source)
                    if GetLocalPlayer() == GetOwningPlayer(source) then
                        BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNShieldOfDark.dds")
                    end
                else
                    DarkShieldBuff:add(source, source)
                    if GetLocalPlayer() == GetOwningPlayer(source) then
                        BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNShieldOfDarkOn.dds")
                    end
                end
            end
        end

        function thistype.onLearn(source)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class DARKASCENSION : Spell
    ---@field dur function
    DARKASCENSION = Spell.define("A00C")
    do
        local thistype = DARKASCENSION

        thistype.values = {
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 5. + 5. * ablev end,
        }

        local function delay(self)
            DarkAscensionBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
        end

        function thistype.preCast(pid, tpid, caster)
            DestroyEffect(AddSpecialEffectTarget("Blood Wing.mdx", caster, "chest"))
            SoundHandler("Units\\NightElf\\HeroDemonHunter\\DemonHunterMorph1.flac", true, nil, caster)
        end

        function thistype:onCast()
            TQ:callDelayed(0.5, delay, self)
        end
    end
end, Debug and Debug.getLine())
