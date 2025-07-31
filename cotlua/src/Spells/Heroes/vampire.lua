OnInit.final("VampireSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ---@class BLOODBANK : Spell
    ---@field gain function
    ---@field max function
    ---@field set function
    ---@field get function
    ---@field add function
    ---@field bank integer[]
    ---@field refresh function
    BLOODBANK = Spell.define("A07K")
    do
        local thistype = BLOODBANK

        thistype.values = {
            gain = function(pid) return 0.75 * GetHeroStr(Hero[pid], true) end,
            max = function(pid) return 200. * GetHeroInt(Hero[pid], true) end,
            bank = __jarray(0),
        }

        function thistype.refresh(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1

            Unit[u].dr = Unit[u].dr / BLOODLORD.dr[pid]

            -- blood bank visual
            local max = R2I(thistype.max(pid))
            local blood = math.min(thistype.get(pid), max)
            BlzSetUnitMaxMana(u, max)
            SetUnitState(u, UNIT_STATE_MANA, blood)

            local hp = blood / max * 5
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNSimpleHugePotion" .. (R2I(hp)) .. "_5.blp")
            end

            BLOODLORD.dr[pid] = 1
            BlzSetUnitAbilityCooldown(u, BLOODLEECH.id, GetUnitAbilityLevel(u, BLOODLEECH.id) - 1, 6.)
            BlzSetUnitAbilityCooldown(u, BLOODNOVA.id, GetUnitAbilityLevel(u, BLOODNOVA.id) - 1, 5.)
            BlzSetUnitAbilityCooldown(u, BLOODDOMAIN.id, GetUnitAbilityLevel(u, BLOODDOMAIN.id) - 1, 10.)

            if GetUnitAbilityLevel(u, BLOODLORD.id) > 0 then
                if GetHeroStr(u, true) >= GetHeroAgi(u, true) then
                    BLOODLORD.dr[pid] = (1 - 0.01 * (thistype.get(pid) / (GetHeroInt(u, true) * 10.)))

                    Unit[u].dr = Unit[u].dr * BLOODLORD.dr[pid]
                else
                    BlzSetUnitAbilityCooldown(u, BLOODLEECH.id, GetUnitAbilityLevel(u, BLOODLEECH.id) - 1, 3.)
                    BlzSetUnitAbilityCooldown(u, BLOODNOVA.id, GetUnitAbilityLevel(u, BLOODNOVA.id) - 1, 2.5)
                    BlzSetUnitAbilityCooldown(u, BLOODDOMAIN.id, GetUnitAbilityLevel(u, BLOODDOMAIN.id) - 1, 5.)
                end
            end
        end

        function thistype.set(pid, amount)
            thistype.values.bank[pid] = amount

            thistype.refresh(Hero[pid])

            return amount
        end

        function thistype.add(pid, amount)
            return thistype.set(pid, math.min(thistype.bank[pid] + amount, thistype.max(pid)))
        end

        function thistype.get(pid)
            return thistype.bank[pid]
        end

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            thistype.add(pid, thistype.gain(pid))
        end

        local function on_cleanup(pid)
            thistype.set(pid, 0)
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT:register_unit_action(u, on_hit)
            EVENT_STAT_CHANGE:register_unit_action(u, thistype.refresh)
            EVENT_ON_CLEANUP:register_action(Unit[u].pid, on_cleanup)
            Unit[u].nomanaregen = true
        end
    end

    ---@class BLOODLEECH : Spell
    ---@field gain function
    ---@field dmg function
    BLOODLEECH = Spell.define("A07A")
    do
        local thistype = BLOODLEECH

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (2.75 + 0.25 * ablev) * (GetHeroAgi(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            gain = function(pid) return 10. * GetHeroAgi(Hero[pid], true) + 5. * GetHeroStr(Hero[pid], true) end,
        }

        function thistype:onCast()
            DamageTarget(self.caster, self.target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            BLOODBANK.add(self.pid, self.gain)
        end
    end

    ---@class BLOODDOMAIN : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field gain function
    BLOODDOMAIN = Spell.define("A09B")
    do
        local thistype = BLOODDOMAIN

        thistype.values = {
            aoe = 400.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.5 + 0.5 * ablev) * GetHeroAgi(Hero[pid], true) + (1.5 + 0.5 * ablev) * GetHeroStr(Hero[pid], true) end,
            gain = function(pid) return 1. * GetHeroAgi(Hero[pid], true) + 1. * GetHeroStr(Hero[pid], true) end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local ablev = GetUnitAbilityLevel(pt.source, BLOODDOMAIN.id) ---@type integer 

            pt.dur = pt.dur - 1

            if pt.dur > 0. then
                local ug = CreateGroup()
                local ug2 = CreateGroup()
                MakeGroupInRange(pt.pid, ug, GetUnitX(pt.source), GetUnitY(pt.source), pt.aoe, Condition(FilterEnemyDead))
                MakeGroupInRange(pt.pid, ug2, GetUnitX(pt.source), GetUnitY(pt.source), pt.aoe, Condition(FilterEnemy))

                pt.dmg = math.max(thistype.dmg(pt.pid) * 0.2, thistype.dmg(pt.pid) * (1 - (0.17 - 0.02 * ablev) * (BlzGroupGetSize(ug2) - 1)))
                pt.blood = math.max(thistype.gain(pt.pid) * 0.2, thistype.gain(pt.pid) * (1 - (0.17 - 0.02 * ablev) * (BlzGroupGetSize(ug) - 1)))

                for target in each(ug) do
                    BLOODBANK.add(pt.pid, pt.blood)

                    if UnitAlive(target) then
                        DamageTarget(pt.source, target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end

                    local dummy = Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A09D'), 1)
                    dummy:attack(pt.source)
                end

                DestroyGroup(ug)
                DestroyGroup(ug2)

                pt.timer:callDelayed(1., periodic, pt)
            else
                pt:destroy()
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            if GetHeroStr(self.caster, true) > GetHeroAgi(self.caster, true) and GetUnitAbilityLevel(self.caster, BLOODLORD.id) > 0 then
                pt.aoe = thistype.aoe * 2. * LBOOST[self.pid]
            else
                pt.aoe = thistype.aoe * LBOOST[self.pid]
            end

            local ug = CreateGroup()
            local ug2 = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, pt.aoe, Condition(FilterEnemyDead))
            MakeGroupInRange(self.pid, ug2, self.x, self.y, pt.aoe, Condition(FilterEnemy))

            pt.dur = 5.
            pt.dmg = math.max(self.dmg * 0.2, self.dmg * (1 - (0.17 - 0.02 * self.ablev) * (BlzGroupGetSize(ug2) - 1)))
            pt.blood = math.max(self.gain * 0.2, self.gain * (1 - (0.17 - 0.02 * self.ablev) * (BlzGroupGetSize(ug) - 1)))
            pt.source = self.caster

            for target in each(ug) do
                BLOODBANK.add(self.pid, pt.blood)

                if UnitAlive(target) then
                    DamageTarget(self.caster, target, pt.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    if GetHeroStr(self.caster, true) > GetHeroAgi(self.caster, true) and GetUnitAbilityLevel(self.caster, BLOODLORD.id) > 0 then
                        --TODO: blood domain taunt
                    end
                end

                local dummy = Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A09D'), 1)
                dummy:attack(self.caster)
            end

            pt.timer:callDelayed(1., periodic, pt)

            DestroyGroup(ug)
            DestroyGroup(ug2)
        end
    end

    ---@class BLOODMIST : Spell
    ---@field cost function
    ---@field heal function
    BLOODMIST = Spell.define("A093")
    do
        local thistype = BLOODMIST

        thistype.values = {
            cost = function(pid) return 16. * GetHeroInt(Hero[pid], true) end,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.25 + 0.25 * ablev) * GetHeroStr(Hero[pid], true) + thistype.cost(pid) * 0.15 end,
        }

        function thistype:onCast()
            BloodMistBuff:add(self.caster, self.caster)
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_UNIMMOLATION and GetUnitAbilityLevel(source, thistype.id) > 0 and IsUnitPaused(source) == false and IsUnitLoaded(source) == false then
                BloodMistBuff:dispel(source, source)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class BLOODNOVA : Spell
    ---@field cost number
    ---@field dmg number
    ---@field aoe number
    BLOODNOVA = Spell.define("A09A")
    do
        local thistype = BLOODNOVA

        thistype.values = {
            cost = function(pid) return 40. * GetHeroInt(Hero[pid], true) end,
            dmg = function(pid) return 3. * GetHeroAgi(Hero[pid], true) + 2. * GetHeroStr(Hero[pid], true) + thistype.cost(pid) * 0.3 end,
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 225. + 25. * ablev end,
        }

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            if BLOODBANK.get(pid) < thistype.cost(pid) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Not enough blood.")
            end
        end

        function thistype:onCast()
            if BLOODBANK.get(self.pid) >= self.cost then
                BLOODBANK.add(self.pid, -self.cost)

                local ug = CreateGroup()

                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                local dummy = AddSpecialEffect("war3mapImported\\Death Nova.mdx", self.x, self.y)
                BlzSetSpecialEffectScale(dummy, 0.75 + 0.075 * self.ablev)
                DestroyEffect(dummy)

                DestroyGroup(ug)
            end
        end
    end

    ---@class BLOODLORD : Spell
    ---@field bonus function
    ---@field dmg function
    ---@field dur function
    ---@field dr number[]
    BLOODLORD = Spell.define("A097")
    do
        local thistype = BLOODLORD

        thistype.values = {
            bonus = function(pid) return BLOODBANK.get(pid) * 0.01 end,
            dmg = function(pid) return 0.75 * GetHeroAgi(Hero[pid], true) + 1. * GetHeroStr(Hero[pid], true) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 9. + ablev end,
        }
        thistype.dr = __jarray(1) ---@type number[]

        function thistype:onCast()
            BloodLordBuff:add(self.caster, self.caster):duration(self.dur)
        end

        function thistype.onLearn(source)
            BLOODBANK.refresh(source)
        end
    end
end, Debug and Debug.getLine())
