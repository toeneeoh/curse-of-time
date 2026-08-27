OnInit.final("Thanatos", function(Require)
    Require("Spells")
    Require("SpellTools")

    local SWIFT_HUNT = Spell.define("A023")
    do
        local thistype = SWIFT_HUNT

        ---@param pt PlayerTimer
        local function resolve(pt)
            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, pt.x, pt.y, 200., Condition(ishostileEnemy))

            SetUnitXBounded(pt.source, pt.x)
            SetUnitYBounded(pt.source, pt.y)
            SetUnitAnimation(pt.source, "attack")

            for target in each(ug) do
                DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Coup de Grace.mdx", target, "chest"))
                DamageTarget(pt.source, target, 1500000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        ---@param target unit
        ---@param source unit
        local function onStruck(target, source)
            if math.random(0, 99) < 10 and UnitDistance(source, target) > 250. then
                if CastSpell(target, thistype.id, 0., -1, 1.) then
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.x = GetUnitX(source)
                    pt.y = GetUnitY(source)
                    pt.source = target
                    pt:after(1.5, resolve)

                    FloatingTextUnit(thistype.tag, target, 1., 70, 0, 10, 255, 255, 255, 0, true)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DEATH_BECKONS = Spell.define("A02P")
    do
        local thistype = DEATH_BECKONS
        local MAX_DISTANCE = 750.

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight,
                CAT_Orient2D,
                MISSILE_DISTANCE,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
            },
            identifier = "missile",
            visualZ = 75.,
            speed = 1100.,
            collisionRadius = 90.,
            friendlyFire = false,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = {
                other = function(self, enemy)
                    local damage = self.damage * (self.dist / MAX_DISTANCE)
                    DamageTarget(self.source, enemy, damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end,
            },
        }
        missile_template.__index = missile_template

        ---@param pt PlayerTimer
        local function releaseProjectiles(pt)
            for i = 1, 10 do
                local angle = i / 5. * bj_PI
                local missile = setmetatable({
                    source = pt.source,
                    owner = GetOwningPlayer(pt.source),
                    x = pt.x,
                    y = pt.y,
                    dist = MAX_DISTANCE,
                    damage = 1000000.,
                    vx = missile_template.speed * math.cos(angle),
                    vy = missile_template.speed * math.sin(angle),
                    visual = AddSpecialEffect("Abilities\\Spells\\Undead\\CarrionSwarm\\CarrionSwarmMissile.mdl", pt.x, pt.y),
                }, missile_template)

                BlzSetSpecialEffectScale(missile.visual, 1.2)
                ALICE_Create(missile)
            end
        end

        ---@param target unit
        local function onStruck(target)
            if math.random(0, 99) < 10 and CastSpell(target, thistype.id, 2., 12, 1.) then
                local pt = TimerList[BOSS_ID]:add(target)
                pt.x = GetUnitX(target)
                pt.y = GetUnitY(target)
                pt.source = target
                pt:after(2.5, releaseProjectiles)

                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", target, "origin"))
                FloatingTextUnit(thistype.tag, target, 2., 70, 0, 10, 255, 255, 255, 0, true)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
