OnInit.final("SummonAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("BuffsSummons")

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan
    local valid_pull_target = VALID_PULL_TARGET

    ---@class REAVER_WAR_CRY : Spell
    REAVER_WAR_CRY = Spell.define('A01M')
    do
        local thistype = REAVER_WAR_CRY
        local MOVE_SPEED_PERCENT_BY_LEVEL = { 15, 18, 21, 25 }
        local ARMOR_PERCENT_BY_LEVEL = { 20, 23, 26, 30 }

        thistype.values = {
            aoe = 800.,
            dur = 8.,
        }

        for level = 1, 4 do
            local tier = level + 1
            BlzSetAbilityTooltip(thistype.id, "War Cry (Tier " .. tier .. ")", level - 1)
            Spell.TOOLTIPS[thistype.id][level] =
                "Rallies nearby allies, granting them increased movespeed and armor for ~{dur=8] seconds."
                .. "|n|n|cffffcc00Movespeed:|r " .. MOVE_SPEED_PERCENT_BY_LEVEL[level] .. "%"
                .. "|n|cffffcc00Armor:|r " .. ARMOR_PERCENT_BY_LEVEL[level] .. "%"
                .. "|n|cffffcc00Area:|r ~{aoe=800]"
        end

        function thistype:onCast()
            local ms = MOVE_SPEED_PERCENT_BY_LEVEL[self.ablev]
            local armor = ARMOR_PERCENT_BY_LEVEL[self.ablev]
            if not ms or not armor then return end

            local radius = self.aoe * LBOOST[self.pid]
            local duration = self.dur * LBOOST[self.pid]
            local group = CreateGroup()
            MakeGroupInRange(self.pid, group, GetUnitX(self.caster), GetUnitY(self.caster),
                radius, Condition(FilterAlly))

            for ally in each(group) do
                if not IsUnitType(ally, UNIT_TYPE_STRUCTURE) then
                    ReaverWarCryBuff:add(self.caster, ally):update(ms * 0.01, armor * 0.01, duration)
                end
            end
            DestroyGroup(group)

            DestroyEffect(AddSpecialEffectTarget(
                "Abilities\\Spells\\NightElf\\BattleRoar\\RoarCaster.mdl", self.caster, "origin"))
        end
    end

    ---@class DREAD_CLEAVE_INFO : Spell
    DREAD_CLEAVE_INFO = Spell.define('A01O')
    do
        local thistype = DREAD_CLEAVE_INFO

        thistype.values = {
            length = 650.,
            startwidth = 150.,
            endwidth = function(pid)
                return 225. + SummonEssence.getTier(pid, SUMMON_REAVER) * 15.
            end,
        }

        for level = 1, 6 do
            local tier = level - 1
            local tooltip = "Attacks deal " .. (20 + tier * 6)
                .. "% of their pre-armor damage as Physical damage to enemies in a widening cone behind the primary target."
                .. "|n|n|cffffcc00Range:|r ~{length=650]"
                .. "|n|cffffcc00Start Width:|r ~{startwidth=150]"
                .. "|n|cffffcc00End Width:|r ~{endwidth=" .. (225 + tier * 15) .. "]"

            if tier >= 5 then
                tooltip = tooltip
                    .. "|n|nDamage dealt by Dread Cleave heals the Reaver for 10%, up to 3% of its Max Health per attack."
            end

            Spell.TOOLTIPS[thistype.id][level] = tooltip
        end
    end

    ---@class DREADFUL_WOUNDS_INFO : Spell
    DREADFUL_WOUNDS_INFO = Spell.define('A01K')
    do
        local thistype = DREADFUL_WOUNDS_INFO

        thistype.values = {
            dur = 4.,
        }

        for level = 1, 6 do
            local tier = level - 1
            local reduction = tier >= 4 and 10 or 5
            Spell.TOOLTIPS[thistype.id][level] = "The Reaver's attacks apply Dreadful Wounds to the primary target"
                .. " and every enemy struck by Dread Cleave, reducing their damage by " .. reduction
                .. "%.|n|c000080c0~>{dur=4] second duration.|r"
        end
    end

    UNIT_SPELLS[FourCC('A0KI')] = function(caster) -- meat golem taunt
        Taunt(caster, 800.)
    end

    ---@class RECLAIM_ESSENCE : Spell
    RECLAIM_ESSENCE = Spell.define('A071')
    do
        local thistype = RECLAIM_ESSENCE

        Spell.TOOLTIPS[thistype.id][1] =
            "Reclaim one Essence point from the target summon. At tier 0, dismiss the summon and refund its 2 bound Essence. Both the Dark Summoner and the target summon must be in town, the church, or the tavern."
        BlzSetAbilityTooltip(thistype.id, "Reclaim Essence (-)", 0)

        function thistype:onCast()
            BlzEndUnitAbilityCooldown(self.caster, thistype.id)

            if SummonEssence then
                SummonEssence.reclaim(self.pid, self.target)
            end
        end
    end

    ---@class INFUSE_ESSENCE : Spell
    INFUSE_ESSENCE = Spell.define('A06C')
    do
        local thistype = INFUSE_ESSENCE

        Spell.TOOLTIPS[thistype.id][1] =
            "Spend one unallocated Essence point to increase the target summon's tier, up to tier 5."
        BlzSetAbilityTooltip(thistype.id, "Infuse Essence (+)", 0)

        function thistype:onCast()
            BlzEndUnitAbilityCooldown(self.caster, thistype.id)

            if SummonEssence then
                SummonEssence.infuse(self.pid, self.target)
            end
        end
    end

    MAGNETIC_FORCE = Spell.define('A06O')
    do
        local thistype = MAGNETIC_FORCE
        local PULL_RADIUS = 600.
        local MIN_DISTANCE = 200.
        local PULL_FORCE = 500000.
        local DURATION = 10.

        local function pull_force(target, _, x, y)
            local target_x, target_y = GetUnitX(target), GetUnitY(target)
            local distance = DistanceCoords(x, y, target_x, target_y)

            if distance > MIN_DISTANCE then
                local angle = atan(y - target_y, x - target_x)
                local strength = math.min(PULL_FORCE / (distance ^ 2), distance - MIN_DISTANCE)
                SetUnitXBounded(target, target_x + strength * math.cos(angle))
                SetUnitYBounded(target, target_y + strength * math.sin(angle))
            end
        end

        local function pull(caster, pid, remaining)
            if remaining <= 0. or not UnitAlive(caster) then return end

            local x, y = GetUnitX(caster), GetUnitY(caster)
            ALICE_ForAllObjectsInRangeDo(pull_force, x, y,
                PULL_RADIUS * LBOOST[pid], "nonhero", valid_pull_target, caster, x, y)

            TQ:callDelayed(FPS_32, pull, caster, pid, remaining - FPS_32)
        end

        function thistype:onCast()
            pull(self.caster, self.pid, DURATION)
        end
    end

    THUNDER_CLAP_GOLEM = Spell.define('A0B0')
    do
        local thistype = THUNDER_CLAP_GOLEM

        function thistype:onCast()
            local ug = CreateGroup()
            MakeGroupInRange(self.pid, ug, self.x, self.y, 300., Condition(FilterEnemy))

            for target in each(ug) do
                MeatGolemThunderClap:add(self.caster, target):duration(3.)
            end

            DestroyGroup(ug)
        end
    end
end, Debug and Debug.getLine())
