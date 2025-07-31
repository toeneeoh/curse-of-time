OnInit.final("CrusaderSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ---@class SOULLINK : Spell
    ---@field dur number
    ---@field onHit function
    SOULLINK = Spell.define("A06A")
    do
        local thistype = SOULLINK

        thistype.values = {
            dur = 5.,
        }

        function thistype:onCast()
            SoulLinkBuff:add(self.caster, self.target):duration(self.dur * LBOOST[self.pid])
        end

        function thistype.onHit(target, source, amount, damage_type)
            --soul link
            buff = SoulLinkBuff:get(nil, target)

            if buff then
                amount.value = 0.
                buff:remove()
            end
        end
    end

    ---@class LAWOFRESONANCE : Spell
    ---@field echo function
    ---@field dur number
    LAWOFRESONANCE = Spell.define("A0KD")
    do
        local thistype = LAWOFRESONANCE

        thistype.values = {
            echo = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 20. + 5. * ablev end,
            dur = 5.,
        }

        function thistype:onCast()
            LawOfResonanceBuff:add(self.caster, self.target):duration(self.dur * LBOOST[self.pid])
        end
    end

    ---@class LAWOFVALOR : Spell
    ---@field regen function
    ---@field amp function
    ---@field dur number
    LAWOFVALOR = Spell.define("A06D")
    do
        local thistype = LAWOFVALOR
        thistype.values = {
            regen = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.08 + 0.02 * ablev) * GetHeroStr(Hero[pid], true) end,
            amp = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 8. + 2. * ablev end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 14. + ablev end,
        }

        function thistype:onCast()
            LawOfValorBuff:add(self.caster, self.target):duration(self.dur * LBOOST[self.pid])
        end
    end

    ---@class LAWOFMIGHT : Spell
    ---@field pbonus function
    ---@field fbonus function
    ---@field dur number
    LAWOFMIGHT = Spell.define("A07D")
    do
        local thistype = LAWOFMIGHT

        thistype.values = {
            pbonus = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 10. + 5. * ablev end,
            fbonus = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.04 + 0.01 * ablev) * GetHeroInt(Hero[pid], true) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 14. + ablev end,
        }

        function thistype:onCast()
            LawOfMightBuff:add(self.caster, self.target):duration(self.dur * LBOOST[self.pid])
        end
    end

    ---@class AURAOFJUSTICE : Spell
    ---@field pshield function
    ---@field dur number
    AURAOFJUSTICE = Spell.define("A06E")
    do
        local thistype = AURAOFJUSTICE

        thistype.values = {
            pshield = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 20. + 5. * ablev end,
            dur = 5.,
        }

        function thistype:onCast()
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, 900., Condition(FilterAlly))
            DestroyEffect(AddSpecialEffect("war3mapImported\\BlessedField.mdx", self.x, self.y))

            for target in each(ug) do
                shield.add(target, BlzGetUnitMaxHP(target) * self.pshield * 0.01 * LBOOST[self.pid], self.dur * LBOOST[self.pid])
            end

            DestroyGroup(ug)
        end

        function thistype.onLearn(source, ablev, pid)
            if JusticeAuraBuff:has(source, source) then
                JusticeAuraBuff:dispel(source, source)
            end
        end
    end

    ---@class DIVINERADIANCE : Spell
    ---@field heal function
    ---@field dmg function
    ---@field aoe number
    ---@field dur number
    DIVINERADIANCE = Spell.define("A07P")
    do
        local thistype = DIVINERADIANCE

        thistype.values = {
            heal = function(pid) return 2. * GetHeroStr(Hero[pid], true) end,
            dmg = function(pid) return 2. * GetHeroInt(Hero[pid], true) end,
            aoe = 750,
            dur = 10.,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.dur = pt.dur - 2.

            local ug = CreateGroup()

            MakeGroupInRange(pt.pid, ug, GetUnitX(pt.source), GetUnitY(pt.source), thistype.aoe * LBOOST[pt.pid], Condition(FilterAlive))

            for target in each(ug) do
                if IsUnitEnemy(target, Player(pt.pid - 1)) then
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", GetUnitX(target), GetUnitY(target)))
                    DamageTarget(pt.source, target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                elseif GetUnitTypeId(target) ~= BACKPACK and IsUnitAlly(target, Player(pt.pid - 1)) and GetUnitAbilityLevel(target, FourCC('Aloc')) == 0 then
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", GetUnitX(target), GetUnitY(target)))
                    HP(pt.source, target, thistype.heal(pt.pid) * BOOST[pt.pid], thistype.tag)
                end
            end

            if pt.dur - 1 <= 0 then
                pt:destroy()
            else
                pt.timer:callDelayed(2., periodic, pt)
            end

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.dur = self.dur * LBOOST[self.pid]
            pt.source = self.caster

            TimerQueue:callDelayed(pt.dur, HideEffect, AddSpecialEffectTarget("war3mapImported\\HolyAurora.MDX", self.caster, "origin"))

            pt.timer:callDelayed(1., periodic, pt)
        end
    end
end, Debug and Debug.getLine())
