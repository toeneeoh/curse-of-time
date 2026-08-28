OnInit.final("EnemyUnitAbilities", function(Require)
    Require("Spells")

    local random = math.random
    local distance = MISSILE_DISTANCE

    local URSA_FROST_NOVA = Spell.define('ACfn')
    do
        local thistype = URSA_FROST_NOVA

        local function onStruck(target, source)
            IssueTargetOrder(target, "frostnova", source)
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TENTACLE = Spell.define('A0AJ')
    do
        local thistype = TENTACLE

        local function onStruck(target, source)
            if random(1, 5) == 1 then
                IssueImmediateOrder(target, "waterelemental")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SHOCKWAVE = Spell.define("A02L")
    do
        local thistype = SHOCKWAVE

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
            collisionRadius = 100.,
            friendlyFire = false,
            visualZ = 75.,
            speed = 1000.,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, 6000., ATTACK_TYPE_NORMAL, MAGIC, "Shockwave")
            end,
        }

        local function onStruck(target, source)
            if UnitDistance(source, target) < 600. then
                if CastSpell(target, thistype.id, 1., 15, 1) then
                    local x, y = GetUnitX(target), GetUnitY(target)
                    local angle = math.atan(GetUnitX(source) - y, GetUnitY(source) - x)
                    local missile = setmetatable({}, missile_template)
                    missile.x = x
                    missile.y = y
                    missile.vx = missile.speed * math.cos(angle)
                    missile.vy = missile.speed * math.sin(angle)
                    missile.visual = AddSpecialEffect("Abilities\\Spells\\Orc\\Shockwave\\ShockwaveMissile.mdl", x, y)
                    BlzSetSpecialEffectScale(missile.visual, 1.1)
                    missile.source = target
                    missile.owner = GetOwningPlayer(target)

                    ALICE_Create(missile)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local RAISE_SKELETON = Spell.define("A01H")
    do
        local thistype = RAISE_SKELETON

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 1.5, 8, 1.) then
                for i = 0, 4 do
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\RaiseSkeletonWarrior\\RaiseSkeleton.mdl", GetUnitX(target) + 80. * math.cos(bj_PI * i * 0.4), GetUnitY(target) + 80. * math.sin(bj_PI * i * 0.4)))
                    local dummy = CreateUnit(PLAYER_BOSS, FourCC('n00E'), GetUnitX(target) + 80. * math.cos(bj_PI * i * 0.4), GetUnitY(target) + 80. * math.sin(bj_PI * i * 0.4), GetUnitFacing(target))
                    CastSpell(dummy, 0, 1.5, 9, 1.)
                    UnitApplyTimedLife(dummy, FourCC('BTLF'), 30.)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())

