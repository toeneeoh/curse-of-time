OnInit.final("SummonAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan
    local valid_pull_target = VALID_PULL_TARGET

    UNIT_SPELLS[FourCC('A0KI')] = function(caster) -- meat golem taunt
        Taunt(caster, 800.)
    end

    ---@class RECLAIM_ESSENCE : Spell
    RECLAIM_ESSENCE = Spell.define('A071')
    do
        local thistype = RECLAIM_ESSENCE

        Spell.TOOLTIPS[thistype.id][1] =
            "Reclaim one Essence point from the target summon. This can only be done in town, the church, or the tavern."
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
