OnInit.final("PhoenixRangerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local atan = math.atan
    local distance = MISSILE_DISTANCE

    ---@class MULTISHOT : Spell
    ---@field enabled boolean[]
    MULTISHOT = Spell.define("A05R")
    do
        local thistype = MULTISHOT
        thistype.enabled = setmetatable({}, {__mode = 'k'}) -- weak keys for units

        local multi_shot_ability = FourCC('A0A3')

        local function on_order(source, target, id)
            -- toggle on
            if id == ORDER_ID_IMMOLATION then
                if not thistype.enabled[source] then
                    UnitRemoveAbility(source, multi_shot_ability)
                    UnitAddAbility(source, multi_shot_ability)
                    SetUnitAbilityLevel(source, multi_shot_ability, (GetHeroLevel(source) // 50) + 1)
                    BlzUnitHideAbility(source, multi_shot_ability, true)
                    thistype.enabled[source] = true
                    Unit[source].pm = Unit[source].pm * 0.6
                end
            -- toggle off
            elseif id == ORDER_ID_UNIMMOLATION then
                if thistype.enabled[source] then
                    UnitRemoveAbility(source, multi_shot_ability)
                    thistype.enabled[source] = false
                    Unit[source].pm = Unit[source].pm / 0.6
                end
            end
        end

        local function on_revive(u)
            if MULTISHOT.enabled[u] then
                IssueImmediateOrder(u, "immolation")
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_ORDER:register_unit_action(u, on_order)
            EVENT_ON_REVIVE:register_unit_action(u, on_revive)
        end
    end

    ---@class REINCARNATION : Spell
    ---@field enabled boolean[]
    REINCARNATION = Spell.define("A05T")
    do
        local thistype = REINCARNATION
        thistype.enabled = __jarray(false)

        local function on_death(killed)
            local pid = GetPlayerId(GetOwningPlayer(killed)) + 1

            if BlzGetUnitAbilityCooldownRemaining(killed, thistype.id) <= 0 then
                REINCARNATION.enabled[pid] = true
                UnitAddAbility(HeroGrave[pid], FourCC('A044'))
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, on_death)
        end
    end

    ---@class PHOENIXFLIGHT : Spell
    ---@field range function
    ---@field aoe number
    ---@field dmg function
    PHOENIXFLIGHT = Spell.define("A0FT")
    do
        local thistype = PHOENIXFLIGHT

        thistype.values = {
            range = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 350. + ablev * 150. end,
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 1.5 end,
            aoe = 250.,
        }

        thistype.preCast = function(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)
            local angle = atan(targetY - y, targetX - x)
            local range = math.min(thistype.values.range(pid) * LBOOST[pid], math.max(17., DistanceCoords(x, y, targetX, targetY)))

            targetX = x + range * math.cos(angle)
            targetY = y + range * math.sin(angle)

            if not IsTerrainWalkable(targetX, targetY) or r2 ~= r then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            end
        end

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight,
                CAT_Orient2D,
                distance,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
            },
            identifier = "missile",
            speed = 1000,
            visualZ = 200.,
            friendlyFire = false,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = {
                other = function(self, enemy)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\PhoenixMissile\\Phoenix_Missile.mdl", enemy, "chest"))
                    DamageTarget(self.source, enemy, self.damage * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)

                    local b = BurningDebuff:get(nil, enemy)
                    if b then
                        b:dispel()
                        IgniteDebuff:add(self.source, enemy):duration(5.)
                    end
                end
            },
            destroy = function(self)
                DestroyEffect(self.visual)
                UnitRemoveAbility(self.source, FourCC('Avul'))
                SetUnitXBounded(self.source, self.x)
                SetUnitYBounded(self.source, self.y)
                ShowUnit(self.source, true)
                reselect(self.source)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local range = math.min(self.range * LBOOST[self.pid], math.max(17., DistanceCoords(self.x, self.y, self.targetX, self.targetY)))

            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.visual = AddSpecialEffect("units\\human\\phoenix\\phoenix.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.5)
            missile.source = self.caster
            missile.owner = Player(self.pid - 1)
            missile.collisionRadius = self.aoe * LBOOST[self.pid]
            missile.damage = self.dmg
            missile.pid = self.pid
            missile.dist = range
            BlzSetSpecialEffectTimeScale(missile.visual, 2.)
            BlzPlaySpecialEffect(missile.visual, ANIM_TYPE_BIRTH)

            UnitAddAbility(self.caster, FourCC('Avul'))
            ShowUnit(self.caster, false)

            ALICE_Create(missile)
        end
    end

    ---@class FIERYARROWS : Spell
    FIERYARROWS = Spell.define("A0IB")
    do
        local thistype = FIERYARROWS
        thistype.values = {
            chance = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 2 * ablev end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid], true) * ablev + Unit[Hero[pid]].damage * 0.3 end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local ablev = GetUnitAbilityLevel(source, thistype.id)

            if math.random() * 100. < ablev * 2 * LBOOST[pid] then
                DamageTarget(source, target, (((UnitGetBonus(source, BONUS_DAMAGE) + GetHeroAgi(source, true)) * .3 + GetHeroAgi(source, true) * ablev)) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\PhoenixMissile\\Phoenix_Missile.mdl", GetUnitX(target),GetUnitY(target)))

                local b = BurningDebuff:get(nil, target)
                if b then
                    b:dispel()
                    IgniteDebuff:add(source, target):duration(5.)
                end
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_HIT:register_unit_action(source, on_hit)
        end

    end

    ---@class SEARINGARROWS : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field dot function
    SEARINGARROWS = Spell.define("A090")
    do
        local thistype = SEARINGARROWS

        thistype.values = {
            aoe = 900.,
            dmg = function(pid) return Unit[Hero[pid]].damage end,
            dot = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.05 + ablev * 0.05) * (Unit[Hero[pid]].damage) end,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 10.,
            friendlyFire = false,
            visualZ = 50.,
            speed = 1000,
            arc = 0.65,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                BurningDebuff:add(self.source, enemy):duration(5.)
                DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            for target in each(ug) do
                local missile = setmetatable({}, missile_template)
                missile.x = self.x
                missile.y = self.y
                missile.z = GetUnitZ(self.caster)
                missile.visual = AddSpecialEffect("Abilities\\Weapons\\SearingArrow\\SearingArrowMissile.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.15)
                missile.source = self.caster
                missile.target = target
                missile.owner = Player(self.pid - 1)
                missile.damage = self.dmg * BOOST[self.pid]

                ALICE_Create(missile)
            end

            DestroyGroup(ug)
        end
    end

    ---@class FLAMINGBOW : Spell
    ---@field pierce function
    ---@field bonus function
    ---@field total function
    ---@field dur number
    FLAMINGBOW = Spell.define("A0F6")
    do
        local thistype = FLAMINGBOW
        thistype.values = {
            pierce = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 10. + 1. * ablev end,
            bonus = function(pid)
                local untouched_damage = BlzGetUnitBaseDamage(Hero[pid], 0) + Unit[Hero[pid]].bonus_damage
                return 0.5 * untouched_damage
            end,
            total = function(pid)
                local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id)
                local untouched_damage = BlzGetUnitBaseDamage(Hero[pid], 0) + Unit[Hero[pid]].bonus_damage
                return (0.8 + 0.02 * ablev) * untouched_damage end,
            dur = 15.,
        }

        function thistype:onCast()
            FlamingBowBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                Unit[source].armor_pen_percent = Unit[source].armor_pen_percent + thistype.pierce(pid)
            else
                Unit[source].armor_pen_percent = Unit[source].armor_pen_percent + 1
            end
        end
    end
end, Debug and Debug.getLine())
