OnInit.final("SummonAbilities", function(Require)
    Require("Spells")

    local TQ = TimerQueue

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
            if self.target then UnitRemoveAbility(self.target, FourCC('Basl')) end
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
            if self.target then UnitRemoveAbility(self.target, FourCC('Bfae')) end
            BlzEndUnitAbilityCooldown(self.caster, thistype.id)

            if SummonEssence then
                SummonEssence.infuse(self.pid, self.target)
            end
        end
    end

    MAGNETIC_FORCE = Spell.define('A06O')
    do
        local thistype = MAGNETIC_FORCE

        ---@type fun(pid: integer, caster: unit, dur: number)
        local function pull(pid, caster, dur)
            dur = dur - 0.05

            if dur > 0 then
                local ug = CreateGroup()

                MakeGroupInRange(pid, ug, GetUnitX(caster), GetUnitY(caster), 600. * LBOOST[pid], Condition(FilterEnemy))

                for target in each(ug) do
                    local angle = math.atan(GetUnitY(caster) - GetUnitY(target), GetUnitX(caster) - GetUnitX(target))
                    if GetUnitMoveSpeed(target) > 0 and IsTerrainWalkable(GetUnitX(target) + (7. * math.cos(angle)), GetUnitY(target) + (7. * math.sin(angle))) then
                        SetUnitXBounded(target, GetUnitX(target) + (7. * math.cos(angle)))
                        SetUnitYBounded(target, GetUnitY(target) + (7. * math.sin(angle)))
                    end
                end

                TQ:callDelayed(0.05, pull, pid, caster, dur)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            TQ:callDelayed(0.05, pull, self.pid, self.caster, 10)
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
