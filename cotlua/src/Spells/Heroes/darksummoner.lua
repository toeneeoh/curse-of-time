OnInit.final("DarkSummonerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    ---@class SUMMONINGIMPROVEMENT : Spell
    ---@field apply function
    SUMMONINGIMPROVEMENT = Spell.define("A022")
    do
        local thistype = SUMMONINGIMPROVEMENT

        ---@type fun(pid: integer, summon: unit, str: integer, agi: integer, int: integer)
        function thistype.apply(pid, summon, str, agi, int)
            local ablev = GetUnitAbilityLevel(Hero[pid], SUMMONINGIMPROVEMENT.id) - 1  ---@type integer --summoning improvement
            local uid = GetUnitTypeId(summon) ---@type integer 

            --stat ratios
            Unit[summon].str = str
            if uid ~= SUMMON_DESTROYER then
                Unit[summon].agi = agi
            else
                BlzSetUnitArmor(summon, agi)
            end
            Unit[summon].int = int

            local armor = 0

            if ablev > 0 then
                SetUnitMoveSpeed(summon, GetUnitDefaultMoveSpeed(summon) + ablev * 10.)

                --armor bonus
                armor = armor + R2I((Pow(ablev, 1.2) + (Pow(ablev, 4.) - Pow(ablev, 3.9)) / 90.) / 2. + ablev + 6.5)

                --status bar buff
                UnitAddAbility(summon, FourCC('A06Q'))
                SetUnitAbilityLevel(summon, FourCC('A06Q'), ablev)
            end

            if uid == SUMMON_GOLEM then --golem
                if GetUnitAbilityLevel(Hero[pid], DEVOUR.id) > 0 then --golem devour ability
                    UnitAddAbility(summon, DEVOUR_GOLEM.id)
                    SetUnitAbilityLevel(summon, DEVOUR_GOLEM.id, GetUnitAbilityLevel(Hero[pid], DEVOUR.id))
                end
                if ablev >= 20 then
                    UnitAddAbility(summon, FourCC('A0IQ'))
                end
            elseif uid == SUMMON_DESTROYER then --destroyer
                if GetUnitAbilityLevel(Hero[pid], DEVOUR.id) > 0 then --destroyer devour ability
                    UnitAddAbility(summon, FourCC('A04Z'))
                    SetUnitAbilityLevel(summon, FourCC('A04Z'), GetUnitAbilityLevel(Hero[pid], DEVOUR.id))
                end
                if ablev >= 30 then
                    UnitAddAbility(summon, FourCC('A0IQ'))
                end
            elseif uid == SUMMON_HOUND then --demon hound
            end

            UnitSetBonus(summon, BONUS_ARMOR, armor)
        end

        function thistype:onCast()
            RecallSummons(self.pid)
        end
    end

    local is_destroyer_sacrificed = {} ---@type boolean[] 

    ---@class SUMMONDEMONHOUND : Spell
    ---@field hounds function
    ---@field str function
    ---@field agi function
    ---@field int function
    SUMMONDEMONHOUND = Spell.define("A0KF")
    do
        local thistype = SUMMONDEMONHOUND
        local hounds = {} ---@type unit[][]

        thistype.values = {
            hounds = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 2 + ablev end,
            str = function(pid) return 0.2 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.075 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) return 0.25 * GetHeroInt(Hero[pid], true) end,
        }

        local function hound_duration(pt)
            local summons = hounds[pt.pid]
            pt.dur = pt.dur - 0.5

            if pt.dur > 0 then
                for _, hound in ipairs(summons) do
                    SetUnitState(hound, UNIT_STATE_MANA, BlzGetUnitMaxMana(hound) * pt.dur / pt.time)
                end
                pt.timer:callDelayed(0.5, hound_duration, pt)
            else
                for _, hound in ipairs(summons) do
                    SummonExpire(hound)
                end
                pt:destroy()
            end
        end

        local function on_cleanup(pid)
            for i = 1, 6 do
                TableRemove(SummonGroup, hounds[pid * PLAYER_CAP + i])
                hounds[pid * PLAYER_CAP + i] = nil
            end
        end

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            --deadly bite
            if GetRandomInt(0, 99) < 25 then
                if is_destroyer_sacrificed[pid] then
                    --aoe attack
                    local ug = CreateGroup()
                    MakeGroupInRange(pid, ug, GetUnitX(target), GetUnitY(target), 400. * LBOOST[pid], Condition(FilterEnemy))

                    for u in each(ug) do
                        DamageTarget(source, u, GetHeroInt(source, true) * 1.25 * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, "Deadly Bite")
                    end

                    DestroyGroup(ug)
                else
                    DamageTarget(source, target, GetHeroInt(source, true) * LBOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, "Deadly Bite")
                end
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", GetUnitX(target), GetUnitY(target)))
            end
        end

        function thistype:onCast()
            if not hounds[self.pid] then
                hounds[self.pid] = {}
            end

            self.angle = GetUnitFacing(self.caster)
            self.x = self.x + 150 * math.cos(bj_DEGTORAD * self.angle)
            self.y = self.y + 150 * math.sin(bj_DEGTORAD * self.angle)

            for i = 1, self.hounds do
                local summon = hounds[self.pid][i]

                if summon then
                    TimerList[self.pid]:stopAllTimers(SUMMON_HOUND)
                    ShowUnit(summon, true)
                    ReviveHero(summon, self.x, self.y, false)
                    SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
                    SetUnitState(summon, UNIT_STATE_MANA, BlzGetUnitMaxMana(summon))
                    SetUnitScale(summon, 0.85, 0.85, 0.85)
                    SetUnitPosition(summon, self.x, self.y)
                    BlzSetUnitFacingEx(summon, self.angle)
                    SetUnitVertexColor(summon, 120, 60, 60, 255)
                    UnitSetBonus(summon, BONUS_ARMOR, 0)
                    SetUnitAbilityLevel(summon, FourCC('A06F'), 1)
                else
                    summon = CreateUnit(Player(self.pid - 1), SUMMON_HOUND, self.x, self.y, self.angle)
                    hounds[self.pid][i] = summon
                    Unit[summon].nomanaregen = true
                end

                TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", summon, "origin"))

                Buff.dispelAll(summon)
                SUMMONINGIMPROVEMENT.apply(self.pid, summon, R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), R2I(self.int * BOOST[self.pid]))
                EVENT_ON_HIT:register_unit_action(summon, on_hit)

                if is_destroyer_sacrificed[self.pid] then
                    SetUnitVertexColor(summon, 90, 90, 230, 255)
                    SetUnitScale(summon, 1.15, 1.15, 1.15)
                    SetUnitAbilityLevel(summon, FourCC('A06F'), 2)
                end

                Unit[summon].borrowed_life = 0
                if GetUnitAbilityLevel(summon, FourCC('A06Q')) > 9 then
                    Unit[summon].regen_max = (0.02 + 0.0005 * GetUnitAbilityLevel(summon, FourCC('A06Q')))
                end
                SummonGroup[#SummonGroup + 1] = summon
                EVENT_ON_FATAL_DAMAGE:register_unit_action(summon, SummonExpire)
                EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
                SetHeroLevel(summon, GetHeroLevel(self.caster), false)

                -- heal fully
                SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
            end

            local pt = TimerList[self.pid]:add()
            pt.dur = 60.
            pt.time = 60.
            pt.tag = SUMMON_HOUND
            pt.count = self.hounds
            pt.timer:callDelayed(0.5, hound_duration, pt)
        end
    end

    ---@class SUMMONMEATGOLEM : Spell
    ---@field str function
    ---@field agi function
    SUMMONMEATGOLEM = Spell.define("A0KH")
    do
        local thistype = SUMMONMEATGOLEM
        local meatgolem = {} ---@type unit[] 

        thistype.values = {
            str = function(pid) return 0.4 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.6 * GetHeroInt(Hero[pid], true) end,
        }

        local function on_cleanup(pid)
            TableRemove(SummonGroup, meatgolem[pid])
            meatgolem[pid] = nil
        end

        function thistype:onCast()
            local summon = meatgolem[self.pid]

            TimerList[self.pid]:stopAllTimers('dvou')
            self.angle = GetUnitFacing(self.caster)
            self.x = self.x + 150 * math.cos(bj_DEGTORAD * self.angle)
            self.y = self.y + 150 * math.sin(bj_DEGTORAD * self.angle)

            if summon then
                TimerList[self.pid]:stopAllTimers(summon)
                ShowUnit(summon, true)
                ReviveHero(summon, self.x, self.y, false)
                SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
                SetUnitState(summon, UNIT_STATE_MANA, BlzGetUnitMaxMana(summon))
                SetUnitScale(summon, 1., 1., 1.)
                SetUnitPosition(summon, self.x, self.y)
                BlzSetUnitFacingEx(summon, self.angle)
                UnitRemoveAbility(summon, BORROWED_LIFE.id) -- borrowed life
                UnitRemoveAbility(summon, THUNDER_CLAP_GOLEM.id) -- thunder clap
                UnitRemoveAbility(summon, MAGNETIC_FORCE.id) -- magnetic force
                UnitRemoveAbility(summon, DEVOUR_GOLEM.id) -- devour
                UnitSetBonus(summon, BONUS_ARMOR, 0)
                Unit[summon].bonus_str = 0
            else
                summon = CreateUnit(Player(self.pid - 1), SUMMON_GOLEM, self.x, self.y, self.angle)
                meatgolem[self.pid] = summon
            end

            Buff.dispelAll(summon)
            Unit[summon].devour_stacks = 0
            Unit[summon].borrowed_life = 0
            SUMMONINGIMPROVEMENT.apply(self.pid, summon, R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), 0)
            Unit[summon].regen_max = (0.02 + 0.00025 * GetUnitAbilityLevel(summon, FourCC('A06Q')))

            BlzSetHeroProperName(summon, "Meat Golem")
            TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", summon, "origin"))
            SummonGroup[#SummonGroup + 1] = summon
            EVENT_ON_FATAL_DAMAGE:register_unit_action(summon, SummonExpire)
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            SetHeroLevel(summon, GetHeroLevel(self.caster), false)

            -- heal fully
            SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
        end
    end

    ---@class SUMMONDESTROYER : Spell
    ---@field periodic function
    ---@field str function
    ---@field agi function
    ---@field int function
    SUMMONDESTROYER = Spell.define("A0KG")
    do
        local thistype = SUMMONDESTROYER
        local destroyer = {} ---@type unit[] 

        thistype.values = {
            str = function(pid) return 0.0666 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.005 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.5 * GetHeroInt(Hero[pid], true) * ablev end,
        }

        local function on_attack(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local pt = TimerList[pid]:get('datk')

            if not pt or pt.target ~= target then
                TimerList[pid]:stopAllTimers('datk')
                pt = TimerList[pid]:add()
                pt.x = x
                pt.y = y
                pt.target = target
                pt.tag = 'datk'

                Unit[source].agi = 0
                if Unit[source].devour_stacks == 5 then
                    Unit[source].agi = 400
                elseif Unit[source].devour_stacks >= 3 then
                    Unit[source].agi = 200
                end

                pt.timer:callDelayed(1., SUMMONDESTROYER.periodic, pt)
            end
        end

        local function on_cleanup(pid)
            TableRemove(SummonGroup, destroyer[pid])
            destroyer[pid] = nil
        end

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local chance = (15 and Unit[source].devour_stacks >= 4) or 10

            --annihilation strike
            if GetRandomInt(0, 99) < chance then
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", GetUnitX(target), GetUnitY(target)))
                DamageTarget(source, target, GetHeroInt(source, true) * LBOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, "Annihilation Strike")
            end
        end

        ---@type fun(pt: PlayerTimer)
        function thistype.periodic(pt)
            local base = 0 ---@type integer 

            if Unit[destroyer[pt.pid]].devour_stacks == 5 then
                base = 400
            elseif Unit[destroyer[pt.pid]].devour_stacks >= 3 then
                base = 200
            end

            Unit[destroyer[pt.pid]].agi = IMinBJ(GetHeroAgi(destroyer[pt.pid], false) + 50, 400)

            if pt.x == GetUnitX(destroyer[pt.pid]) and pt.y == GetUnitY(destroyer[pt.pid]) then
                pt.timer:callDelayed(1., thistype.periodic, pt)
            else
                Unit[destroyer[pt.pid]].agi = base
                pt:destroy()
            end
        end

        function thistype:onCast()
            local summon = destroyer[self.pid]

            TimerList[self.pid]:stopAllTimers('blif')
            self.angle = GetUnitFacing(self.caster) + 180
            self.x = self.x + 150 * math.cos(bj_DEGTORAD * self.angle)
            self.y = self.y + 150 * math.sin(bj_DEGTORAD * self.angle)

            if summon then
                TimerList[self.pid]:stopAllTimers(summon)
                ShowUnit(summon, true)
                ReviveHero(summon, self.x, self.y, false)
                SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
                SetUnitState(summon, UNIT_STATE_MANA, BlzGetUnitMaxMana(summon))
                SetUnitPosition(summon, self.x, self.y)
                BlzSetUnitFacingEx(summon, self.angle + 180)
                SetUnitAbilityLevel(summon, FourCC('A02D'), 1)
                SetUnitAbilityLevel(summon, FourCC('A06J'), 1)
                UnitRemoveAbility(summon, FourCC('A061')) -- blink
                UnitRemoveAbility(summon, FourCC('A03B')) -- crit
                UnitRemoveAbility(summon, BORROWED_LIFE.id) -- borrowed life
                UnitRemoveAbility(summon, FourCC('A04Z')) -- devour
                UnitSetBonus(summon, BONUS_ARMOR, 0)
                Unit[summon].bonus_str = 0
                Unit[summon].bonus_agi = 0
                Unit[summon].bonus_int = 0
                Unit[summon].agi = 0
            else
                summon = CreateUnit(Player(self.pid - 1), SUMMON_DESTROYER, self.x, self.y, self.angle + 180)
                destroyer[self.pid] = summon
            end

            Buff.dispelAll(summon)
            Unit[summon].borrowed_life = 0
            Unit[summon].devour_stacks = 0
            is_destroyer_sacrificed[self.pid] = false

            BlzSetHeroProperName(summon, "Destroyer")
            TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", summon, "origin"))
            SUMMONINGIMPROVEMENT.apply(self.pid, summon, R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), R2I(self.int * BOOST[self.pid]))
            Unit[summon].regen_max = (0.02 + 0.0005 * GetUnitAbilityLevel(summon, FourCC('A06Q')))

            -- revert hounds to normal
            for i = 1, #SummonGroup do
                local target = SummonGroup[i]
                if GetOwningPlayer(target) == Player(self.pid - 1) and GetUnitTypeId(target) == SUMMON_HOUND then
                    SetUnitVertexColor(target, 120, 60, 60, 255)
                    SetUnitScale(target, 0.85, 0.85, 0.85)
                    SetUnitAbilityLevel(target, FourCC('A06F'), 1)
                end
            end

            SummonGroup[#SummonGroup + 1] = summon
            EVENT_ON_FATAL_DAMAGE:register_unit_action(summon, SummonExpire)
            EVENT_ON_HIT:register_unit_action(summon, on_hit)
            EVENT_ON_ATTACK:register_unit_action(summon, on_attack)
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            SetHeroLevel(summon, GetHeroLevel(self.caster), false)

            -- heal fully
            SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
        end
    end

    ---@class DEVOUR : Spell
    ---@field autocast function
    DEVOUR = Spell.define("A063")
    do
        local thistype = DEVOUR

        ---@type fun(pt: PlayerTimer, order: string)
        function thistype.autocast(pt, order)
            local ug = CreateGroup()

            MakeGroupInRange(pt.pid, ug, GetUnitX(pt.target), GetUnitY(pt.target), 1250., Condition(FilterHound))

            local target = FirstOfGroup(ug)

            if target then
                IssueTargetOrder(pt.target, order, target)
            end

            DestroyGroup(ug)

            pt.timer:callDelayed(1., thistype.autocast, pt, order)
        end
    end

    ---@class DEMONICSACRIFICE : Spell
    ---@field pheal number
    ---@field dur number
    DEMONICSACRIFICE = Spell.define("A0K1")
    do
        local thistype = DEMONICSACRIFICE

        thistype.values = {
            pheal = 30.,
            dur = 15.,
        }

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            if GetOwningPlayer(target) ~= Player(pid - 1) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You must target your own summons!")
            end
        end

        function thistype:onCast()
            -- demon hound
            if GetUnitTypeId(self.target) == SUMMON_HOUND then
                SummonExpire(self.target)

                for i = 1, #SummonGroup do
                    local target = SummonGroup[i]
                    if GetOwningPlayer(target) == Player(self.pid - 1) then
                        local heal = BlzGetUnitMaxHP(target) * self.pheal * 0.01 * BOOST[self.pid]
                        HP(self.caster, target, heal, thistype.tag)
                    end
                end
            -- meat golem
            elseif GetUnitTypeId(self.target) == SUMMON_GOLEM then
                if Unit[self.target].devour_stacks < 4 then
                    SummonExpire(self.target)
                end

                DemonicSacrificeBuff:add(self.caster, self.caster):duration(thistype.dur * LBOOST[self.pid])

                TimerQueue:callDelayed(3., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Orc\\AncestralSpirit\\AncestralSpiritCaster.mdl", self.target, "origin"))
            -- destroyer
            elseif GetUnitTypeId(self.target) == SUMMON_DESTROYER then
                SummonExpire(self.target)
                is_destroyer_sacrificed[self.pid] = true

                for i = 1, #SummonGroup do
                    local target = SummonGroup[i]
                    if GetOwningPlayer(target) == Player(self.pid - 1) and GetUnitTypeId(target) == SUMMON_HOUND then
                        SetUnitVertexColor(target, 90, 90, 230, 255)
                        SetUnitScale(target, 1.15, 1.15, 1.15)
                        DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Call of Dread Purple.mdx", target, "origin"))
                        SetUnitAbilityLevel(target, FourCC('A06F'), 2)
                    end
                end
            end
        end
    end
end, Debug and Debug.getLine())
