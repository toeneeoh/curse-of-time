OnInit.final("Xallarath", function(Require)
    Require('BossSchema')
    Require("Spells")
    Require("SpellTools")

    local TQ = TimerQueue
    local distance = MISSILE_DISTANCE
    local FOCUS_FIRE_ID = FourCC('A02G')
    local FIREBALL_ID = FourCC('A02V')

    local REINFORCEMENTS = Spell.define("A01I")
    do
        local thistype = REINFORCEMENTS

        local function summon(angle, x, y)
            UnitApplyTimedLife(CreateUnit(PLAYER_BOSS, FourCC('o034'), x + 400 * math.cos((angle + 90) * bj_DEGTORAD), y + 400 * math.sin((angle + 90) * bj_DEGTORAD), angle), FourCC('BTLF'), 120.)
            UnitApplyTimedLife(CreateUnit(PLAYER_BOSS, FourCC('o034'), x + 400 * math.cos((angle - 90) * bj_DEGTORAD), y + 400 * math.sin((angle - 90) * bj_DEGTORAD), angle), FourCC('BTLF'), 120.)
        end

        local function onStruck(target)
            if GetWidgetLife(target) <= BlzGetUnitMaxHP(target) * 0.5 then
                if CastSpell(target, thistype.id, 0., 3, 1.) then
                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 0, 0, 0, true)
                    local angle, x, y = GetUnitFacing(target), GetUnitX(target), GetUnitY(target)
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", x + 400. * math.cos((angle + 90) * bj_DEGTORAD), y + 400. * math.sin((angle + 90) * bj_DEGTORAD)))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", x + 400. * math.cos((angle - 90) * bj_DEGTORAD), y + 400. * math.sin((angle - 90) * bj_DEGTORAD)))
                    TQ:callDelayed(2., summon, angle, x, y)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local UNSTOPPABLE_FORCE = Spell.define("A01J")
    do
        local thistype = UNSTOPPABLE_FORCE

        local function periodic(pt)
            local ug = CreateGroup()

            GroupEnumUnitsInRange(ug, GetUnitX(pt.source), GetUnitY(pt.source), 400., Condition(isplayerunit))

            for target in each(ug) do
                if IsUnitInGroup(target, pt.ug) == false then
                    GroupAddUnit(pt.ug, target)
                    DamageTarget(pt.source, target, 50000000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            end

            DestroyGroup(ug)

            pt.angle = math.atan(pt.y - GetUnitY(pt.source), pt.x - GetUnitX(pt.source))

            if IsUnitInRangeXY(pt.source, pt.x, pt.y, 125.) or DistanceCoords(pt.x, pt.y, GetUnitX(pt.source), GetUnitY(pt.source)) > 2500. then
                SetUnitPathing(pt.source, true)
                PauseUnit(pt.source, false)
                IssueImmediateOrder(pt.source, "stand")
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x + 200, pt.y))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x - 200, pt.y))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y + 200))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y - 200))

                return false
            else
                SetUnitPathing(pt.source, false)
                SetUnitXBounded(pt.source, GetUnitX(pt.source) + 55 * math.cos(pt.angle))
                SetUnitYBounded(pt.source, GetUnitY(pt.source) + 55 * math.sin(pt.angle))

                return true
            end
        end

        local function onStruck(target)
            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, GetUnitX(target), GetUnitY(target), 1500., Condition(isplayerAlly))

            if BlzGroupGetSize(ug) > 0 then
                if CastSpell(target, thistype.id, 2.5, 1, 1.) then
                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 0, 0, 0, true)
                    local u = BlzGroupUnitAt(ug, GetRandomInt(0, BlzGroupGetSize(ug) - 1))
                    local dummy = Dummy.create(GetUnitX(u), GetUnitY(u), 0, 0, 4.).unit
                    SetUnitScale(dummy, 10., 10., 10.)
                    BlzSetUnitFacingEx(dummy, 270.)
                    BlzSetUnitSkin(dummy, FourCC('e01F'))
                    SetUnitVertexColor(dummy, 200, 200, 0, 255)
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.x = GetUnitX(u)
                    pt.y = GetUnitY(u)
                    pt.ug = CreateGroup()
                    pt.angle = math.atan(GetUnitY(u) - GetUnitY(target), GetUnitX(u) - GetUnitX(target))
                    pt.source = target
                    BlzSetUnitFacingEx(target, pt.angle * bj_RADTODEG)
                    TQ:callDelayed(2.5, pt.startLoop, pt, FPS_32, periodic)
                end
            end

            DestroyGroup(ug)
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local AMBUSH = Spell.define("A02B")
    do
        local thistype = AMBUSH

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
            friendlyFire = false,
            collisionRadius = 90.,
            visualZ = 65.,
            onUnitCollision = CAT_UnitImpact2D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, "Fireball")
            end,
        }
        missile_template.__index = missile_template

        ---@type fun(pt: PlayerTimer): boolean
        local function fireball(pt)
            if UnitAlive(pt.source) then
                local x = GetUnitX(pt.source)
                local y = GetUnitY(pt.source)

                MakeGroupInRange(BOSS_ID, pt.ug, x, y, 4000., Condition(FilterEnemy))

                local size = BlzGroupGetSize(pt.ug)

                if size > 0 then
                    if CastSpell(pt.source, FIREBALL_ID, 0.75, 5, 1.) then
                        local target = BlzGroupUnitAt(pt.ug, GetRandomInt(0, size - 1))
                        local x2, y2 = GetUnitX(target), GetUnitY(target)
                        local angle = math.atan(y2 - y, x2 - x)
                        local dist = DistanceCoords(x2, y2, x, y) + 500.

                        local missile = setmetatable({}, missile_template)
                        missile.x = x
                        missile.y = y
                        missile.visual = AddSpecialEffect("Abilities\\Weapons\\RedDragonBreath\\RedDragonMissile.mdl", x, y)
                        BlzSetSpecialEffectScale(missile.visual, 1.8)
                        missile.speed = 225.
                        missile.vx = missile.speed * math.cos(angle)
                        missile.vy = missile.speed * math.sin(angle)
                        missile.source = pt.source
                        missile.owner = PLAYER_BOSS
                        missile.damage = 3000000.
                        missile.dist = dist

                        ALICE_Create(missile)
                    end
                end

                return true
            end

            return false
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function focus_fire(pt)
            local x = GetUnitX(pt.source)
            local y = GetUnitY(pt.source)

            if UnitAlive(pt.source) then
                if pt.target == nil then
                    local ug = CreateGroup()
                    MakeGroupInRange(BOSS_ID, ug, x, y, 4000., Condition(FilterEnemy))

                    local size = BlzGroupGetSize(ug)

                    if size > 0 then
                        pt.target = BlzGroupUnitAt(ug, GetRandomInt(0, size - 1))
                        IssueTargetOrder(pt.source, "attack", pt.target)

                        if not pt.lfx then
                            pt.lfx = AddLightning("RLAS", false, x, y, GetUnitX(pt.target), GetUnitY(pt.target))
                        else
                            MoveLightningEx(pt.lfx, false, x, y, BlzGetUnitZ(pt.source) + GetUnitFlyHeight(pt.source) + 50., GetUnitX(pt.target), GetUnitY(pt.target), BlzGetUnitZ(pt.target) + 50.)
                        end
                    end

                    DestroyGroup(ug)

                    return true
                else
                    if not IsUnitVisible(pt.target, PLAYER_BOSS) or UnitDistance(pt.source, pt.target) > 4000. then
                        pt.target = nil
                        pt.time = 0.
                        pt.agi = 0
                        MoveLightningEx(pt.lfx, false, 30000., 30000., 0., 30000., 30000., 0.)
                        IssueImmediateOrderById(pt.source, ORDER_ID_STOP)
                        UnitSetBonus(pt.source, BONUS_ATTACK_SPEED, -8.)
                        BlzStartUnitAbilityCooldown(pt.source, FOCUS_FIRE_ID, 0.001)
                    else
                        pt.time = pt.time + FPS_32
                        MoveLightningEx(pt.lfx, false, x, y, BlzGetUnitZ(pt.source) + GetUnitFlyHeight(pt.source) + 50., GetUnitX(pt.target), GetUnitY(pt.target), BlzGetUnitZ(pt.target) + 50.)

                        CastSpell(pt.source, FOCUS_FIRE_ID, 5., 0, 1.)

                        if pt.time >= 5 then
                            DamageTarget(pt.source, pt.target, 0.001, ATTACK_TYPE_NORMAL, PHYSICAL, "Focus Fire")
                            IssueTargetOrder(pt.source, "attack", pt.target)
                            UnitSetBonus(pt.source, BONUS_ATTACK_SPEED, 8.)
                            BlzSetUnitFacingEx(pt.source, bj_RADTODEG * math.atan(GetUnitY(pt.target) - y, GetUnitX(pt.target) - x))
                        end
                    end

                    return true
                end
            end

            return false
        end

        local function spawn_archer(x, y, height)
            local pt = TimerList[BOSS_ID]:add()
            pt.source = CreateUnit(PLAYER_BOSS, FourCC('o001'), x, y, 0.)
            if UnitAddAbility(pt.source, FourCC('Amrf')) then
                UnitRemoveAbility(pt.source, FourCC('Amrf'))
            end
            SetUnitFlyHeight(pt.source, height, 0.)
            ShowUnit(pt.source, false)
            ShowUnit(pt.source, true)
            UnitApplyTimedLife(pt.source, FourCC('BTLF'), 300.)
            pt:startLoop(FPS_32, focus_fire)
        end

        local function spawn_mage(x, y, height)
            local pt = TimerList[BOSS_ID]:add()
            pt.source = CreateUnit(PLAYER_BOSS, FourCC('o000'), x, y, 0.)
            pt.ug = CreateGroup()
            if UnitAddAbility(pt.source, FourCC('Amrf')) then
                UnitRemoveAbility(pt.source, FourCC('Amrf'))
            end
            SetUnitFlyHeight(pt.source, height, 0.)
            ShowUnit(pt.source, false)
            ShowUnit(pt.source, true)
            UnitApplyTimedLife(pt.source, FourCC('BTLF'), 300.)
            pt:startLoop(1., fireball)
        end

        local function onStruck(target)
            if GetWidgetLife(target) <= BlzGetUnitMaxHP(target) * 0.9 then
                if CastSpell(target, thistype.id, 0., 3, 1.) then
                    spawn_archer(12349., -15307., 770.)
                    spawn_archer(13500., -12300., 575.)
                    spawn_archer(14079., -11550., 575.)
                    spawn_mage(14315., -12863., 770.)
                    spawn_mage(11788., -14279., 575.)
                    spawn_mage(11214., -15133., 575.)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
