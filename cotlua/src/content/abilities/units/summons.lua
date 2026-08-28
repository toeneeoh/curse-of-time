OnInit.final("SummonAbilities", function(Require)
    Require("Spells")

    local TQ = TimerQueue

    UNIT_SPELLS[FourCC('A0KI')] = function(caster) -- meat golem taunt
        Taunt(caster, 800.)
    end

    BORROWED_LIFE = Spell.define('A071')
    do
        local thistype = BORROWED_LIFE

        function thistype:onCast()
            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local time = 120

                if self.ablev > 1 then
                    time = time / ((self.ablev - 1) * 2) --60, 30, 20, 15
                end

                Unit[self.target].borrowed_life = time
            end
        end
    end

    DEVOUR_GOLEM = Spell.define('A06C')
    do
        local thistype = DEVOUR_GOLEM

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            visualZ = 50.,
            speed = 900.,
            arc = 0.5,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                local golem = Unit[self.source]

                golem.borrowed_life = 0
                golem.bonus_str = golem.bonus_str - R2I(golem.str * 0.1 * golem.devour_stacks)
                if golem.devour_stacks > 0 then
                    golem.mr = golem.mr / (0.75 - golem.devour_stacks * 0.1)
                end
                golem.devour_stacks = golem.devour_stacks + 1
                BlzSetHeroProperName(self.source, "Meat Golem (" .. (golem.devour_stacks) .. ")")
                FloatingTextUnit(tostring(golem.devour_stacks), self.source, 1, 60, 50, 13.5, 255, 255, 255, 0, true)
                golem.bonus_str = golem.bonus_str + R2I(golem.str * 0.1 * golem.devour_stacks)
                SetUnitScale(self.source, 1 + golem.devour_stacks * 0.07, 1 + golem.devour_stacks * 0.07, 1 + golem.devour_stacks * 0.07)
                --magnetic
                if golem.devour_stacks == 1 then
                    UnitAddAbility(self.source, BORROWED_LIFE.id)
                elseif golem.devour_stacks == 2 then
                    UnitAddAbility(self.source, MAGNETIC_FORCE.id)
                --thunder clap
                elseif golem.devour_stacks == 3 then
                    UnitAddAbility(self.source, THUNDER_CLAP_GOLEM.id)
                elseif golem.devour_stacks == 5 then
                    golem.bonus_armor = golem.bonus_armor + R2I(BlzGetUnitArmor(self.source) * 0.25 + 0.5)
                end
                if golem.devour_stacks >= GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                    UnitDisableAbility(self.source, thistype.id, true)
                end
                SetUnitAbilityLevel(self.source, BORROWED_LIFE.id, golem.devour_stacks)

                --magic resist -(25-30) percent
                golem.mr = golem.mr * (0.75 - golem.devour_stacks * 0.1)
            end,
        }

        function thistype:onCast()
            local golem = Unit[self.source]

            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) and golem.devour_stacks < GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local missile = setmetatable({}, missile_template)
                missile.x = GetUnitX(self.target)
                missile.y = GetUnitY(self.target)
                missile.z = GetUnitZ(self.target)
                missile.visual = AddSpecialEffect("war3mapImported\\Haunt_v2_Portrait.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.1)
                missile.source = self.caster
                missile.target = self.caster
                missile.collideZ = true
                missile.owner = Player(self.pid - 1)
                missile.pid = self.pid

                ALICE_Create(missile)
            end
        end
    end

    DEVOUR_DESTROYER = Spell.define('A04Z')
    do
        local thistype = DEVOUR_DESTROYER

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            visualZ = 50.,
            speed = 900.,
            arc = 0.5,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                local destroyer = Unit[self.source]

                destroyer.borrowed_life = 0
                destroyer.bonus_int = destroyer.bonus_int - R2I(Unit[self.source].int * 0.15 * destroyer.devour_stacks)
                destroyer.devour_stacks = destroyer.devour_stacks + 1
                destroyer.bonus_int = destroyer.bonus_int + R2I(Unit[self.source].int * 0.15 * destroyer.devour_stacks)
                BlzSetHeroProperName(self.source, "Destroyer (" .. (destroyer.devour_stacks) .. ")")
                FloatingTextUnit(tostring(destroyer.devour_stacks), self.source, 1, 60, 50, 13.5, 255, 255, 255, 0, true)
                if destroyer.devour_stacks == 1 then
                    UnitAddAbility(self.source, BORROWED_LIFE.id)
                    UnitAddAbility(self.source, FourCC('A061')) --blink
                elseif destroyer.devour_stacks == 2 then
                    UnitAddAbility(self.source, FourCC('A03B')) --crit
                    destroyer.cc_flat = destroyer.cc_flat + 25
                    destroyer.cd_flat = destroyer.cd_flat + 200
                elseif destroyer.devour_stacks == 3 then
                    destroyer.agi = 200
                elseif destroyer.devour_stacks == 4 then
                    SetUnitAbilityLevel(self.source, FourCC('A02D'), 2)
                elseif destroyer.devour_stacks == 5 then
                    destroyer.agi = 400
                    destroyer.bonus_int = destroyer.bonus_int + R2I(Unit[self.source].int * 0.25)
                end
                if destroyer.devour_stacks >= GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                    UnitDisableAbility(self.source, thistype.id, true)
                end
                SetUnitAbilityLevel(self.source, BORROWED_LIFE.id, destroyer.devour_stacks)
            end,
        }

        function thistype:onCast()
            local destroyer = Unit[self.caster]
            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) and destroyer.devour_stacks < GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local missile = setmetatable({}, missile_template)
                missile.x = GetUnitX(self.target)
                missile.y = GetUnitY(self.target)
                missile.z = GetUnitZ(self.target)
                missile.visual = AddSpecialEffect("war3mapImported\\Haunt_v2_Portrait.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.1)
                missile.source = self.caster
                missile.target = self.caster
                missile.collideZ = true
                missile.owner = Player(self.pid - 1)
                missile.pid = self.pid

                ALICE_Create(missile)
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

                TQ:callDelayed(0.05, pull, pid, dur)

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
