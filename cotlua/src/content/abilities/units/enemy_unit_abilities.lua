OnInit.final("EnemyUnitAbilities", function(Require)
    Require("Spells")

    local random = math.random

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
