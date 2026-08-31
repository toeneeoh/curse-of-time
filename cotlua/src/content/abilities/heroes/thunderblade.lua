OnInit.final("ThunderbladeSpells", function(Require)
    Require('Spells')
    Require('SpellTools')
    Require('Events')

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local distance = MISSILE_DISTANCE

    ---@class OVERLOAD : Spell
    ---@field mult function
    OVERLOAD = Spell.define("A096")
    do
        local thistype = OVERLOAD

        thistype.values = {
            mult = function(pid) return 1. + (0.5 + 0.1 * R2I(GetHeroLevel(Hero[pid]) / 75.)) end,
        }

        function thistype:onCast()
            OverloadBuff:add(self.caster, self.caster)
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.02))
            end
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_UNIMMOLATION and not IsUnitPaused(source) and not IsUnitLoaded(source) then
                OverloadBuff:dispel(source, source)
            end
        end

        local function update_level(u, level)
            SetUnitAbilityLevel(u, thistype.id, level // 75 + 1)
        end

        function thistype.onLearn(source, ablev, pid)
            local b = OverloadBuff:get(nil, source)

            if b then
                b.ablev = ablev
                b:refresh(source, source)
            end
        end

        function thistype.onSetup(u)
            EVENT_STAT_CHANGE:register_unit_action(u, manacost)
            EVENT_ON_ORDER:register_unit_action(u, on_order)
            EVENT_HERO_LEVEL_CHANGED:register_unit_action(u, update_level)
            update_level(u, GetHeroLevel(u))
        end
    end

    ---@class THUNDERDASH : Spell
    ---@field range function
    ---@field dmg function
    ---@field aoe number
    THUNDERDASH = Spell.define("A095")
    do
        local thistype = THUNDERDASH

        thistype.values = {
            range = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (ablev + 3) * 150. end,
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 2. end,
            aoe = 260.,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight, CAT_Orient2D, distance
            },
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
            },
            identifier = "missile",
            visualZ = 15.,
            speed = 1120,
            collisionRadius = 75,
            friendlyFire = false,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = {
                other = function(self, enemy, cx, cy, perpSpeed, parSpeed, totalSpeed, comVx, comVy)
                    if self.range - self.dist > 200 then
                        ALICE_Kill(self)
                    end
                end
            },
            destroy = function(self)
                for i = -1, 1 do
                    for j = -1, 1 do
                        if (i == 0 and j == 0) or (i ~= 0 and j ~= 0) then
                            DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\Bolt\\BoltImpact.mdl", self.x + 140 * i, self.y + 140 * j))
                            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", self.x + 100 * i, self.y + 100 * j))
                        end
                    end
                end

                local ug = CreateGroup()
                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe, Condition(FilterEnemy))

                for target in each(ug) do
                    DamageTarget(self.source, target, self.damage, ATTACK_TYPE_NORMAL, MAGIC, THUNDERDASH.tag)
                end

                UnitRemoveAbility(self.source, ABIL_AVUL)
                ShowUnit(self.source, true)
                reselect(self.source)
                SetUnitPathing(self.source, true)
                BlzUnitClearOrders(self.source, false)
                SetUnitXBounded(self.source, self.x)
                SetUnitYBounded(self.source, self.y)

                DestroyEffect(self.visual)
                DestroyGroup(ug)
            end
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            OmnislashBuff:dispel(self.caster, self.caster)

            ShowUnit(self.caster, false)
            UnitAddAbility(self.caster, ABIL_AVUL)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\FarseerMissile\\FarseerMissile.mdl", self.caster, "chest"))

            local range = self.range * LBOOST[self.pid]
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.visual = AddSpecialEffect("war3mapImported\\blue electric orb.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 0.9)
            missile.source = self.caster
            missile.owner = Player(self.pid - 1)
            missile.damage = self.dmg * BOOST[self.pid]
            missile.aoe = self.aoe * LBOOST[self.pid]
            missile.pid = self.pid
            missile.dist = range
            missile.range = range

            ALICE_Create(missile)
        end
    end

    ---@class MONSOON : Spell
    ---@field times function
    ---@field aoe function
    ---@field dmg function
    MONSOON = Spell.define("A0MN")
    do
        local thistype = MONSOON

        thistype.values = {
            times = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 1. end,
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 275 + 25. * ablev end,
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 1.8 end,
        }

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - 1

            if pt.dur >= -0.5 then
                MakeGroupInRange(pt.pid, pt.ug, pt.x, pt.y, thistype.aoe(pt.pid) * LBOOST[pt.pid], Condition(FilterEnemy))

                for target in each(pt.ug) do
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl", GetUnitX(target), GetUnitY(target)))
                    DamageTarget(Hero[pt.pid], target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.x = self.targetX
            pt.y = self.targetY
            pt.dur = self.times * LBOOST[self.pid]
            pt.ug = CreateGroup()

            local sfx = AddSpecialEffect("war3mapImported\\AnimatedEnviromentalEffectRainBv005", self.targetX, self.targetY)
            BlzSetSpecialEffectScale(sfx, 0.4)
            TQ:callDelayed(pt.dur, DestroyEffect, sfx)
            pt:startLoop(1., periodic)
        end
    end

    ---@class BLADESTORM : Spell
    ---@field aoe number
    ---@field dot function
    ---@field chance number
    ---@field dmg function
    BLADESTORM = Spell.define("A03O")
    do
        local thistype = BLADESTORM

        thistype.values = {
            aoe = 400.,
            dot = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid],true) * ablev * 0.2 end,
            chance = 15.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid],true) * (ablev + 2.) end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            DamageTarget(source, target, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - 1

            if UnitAlive(Hero[pt.pid]) and pt.dur >= 0 then
                MakeGroupInRange(pt.pid, pt.ug, GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]), thistype.aoe * LBOOST[pt.pid], Condition(FilterEnemy))

                if math.random() * 100 < thistype.chance * LBOOST[pt.pid] and BlzGroupGetSize(pt.ug) > 0 then
                    local enemy = BlzGroupUnitAt(pt.ug, GetRandomInt(0, BlzGroupGetSize(pt.ug) - 1))
                    local dummy = Dummy.create(GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]), FourCC('A01Y'), 1, 2.)
                    dummy:attack(enemy, Hero[pt.pid], on_hit)
                end

                for target in each(pt.ug) do
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\Bolt\\BoltImpact.mdl", target, "origin"))
                    DamageTarget(Hero[pt.pid], target, pt.dot * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                return true
            end

            AddUnitAnimationProperties(Hero[pt.pid], "spin", false)

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.dur = 9.
            pt.dmg = self.dmg
            pt.dot = self.dot
            pt.ug = CreateGroup()

            IssueImmediateOrderById(self.caster, ORDER_ID_STOP)
            AddUnitAnimationProperties(Hero[self.pid], "spin", true)
            pt:startLoop(0.33, periodic)
        end
    end

    ---@class OMNISLASH : Spell
    ---@field times function
    ---@field dmg function
    OMNISLASH = Spell.define("A0os")
    do
        local thistype = OMNISLASH

        thistype.values = {
            times = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 3. end,
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 1.5 end,
        }

        function thistype:onCast()
            local buff = OmnislashBuff:create(self.caster, self.caster)
            buff.override = self.target
            buff.dmg = self.dmg
            buff.charges = R2I(self.times * LBOOST[self.pid])
            buff:check(self.caster, self.caster)
        end
    end

    ---@class RAILGUN : Spell
    ---@field range number
    ---@field aoe number
    ---@field dmg function
    RAILGUN = Spell.define("A01L")
    do
        local thistype = RAILGUN

        thistype.values = {
            range = 3000.,
            aoe = 800.,
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * (15 + 5 * GetUnitAbilityLevel(Hero[pid], thistype.id)) end,
        }

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.time = pt.time + FPS_32

            if pt.time >= pt.dur then
                local x = GetUnitX(pt.target)
                local y = GetUnitY(pt.target)
                local dist = 0.
                local sfx

                repeat
                    MakeGroupInRange(pt.pid, pt.ug, x, y, 125., Condition(FilterEnemy))

                    x = x + 50. * math.cos(pt.angle)
                    y = y + 50. * math.sin(pt.angle)

                    dist = dist + 50.
                    if ModuloReal(dist, 750.) == 0. then
                        sfx = AddSpecialEffect("war3mapImported\\DustWindFaster3.mdx", x, y)
                        BlzSetSpecialEffectScale(sfx, 0.5)
                        BlzSetSpecialEffectYaw(sfx, pt.angle)
                        BlzSetSpecialEffectRoll(sfx, bj_PI)
                        BlzSetSpecialEffectZ(sfx, BlzGetLocalSpecialEffectZ(sfx) + 300.)
                        DestroyEffect(sfx)
                    end
                until BlzGroupGetSize(pt.ug) > 0 or dist >= thistype.range

                --laser shot
                local dummy = Dummy.create(x, y, 0, 0).unit
                SetUnitFlyHeight(dummy, 135., 0.)
                UnitRemoveAbility(dummy, ABIL_AVUL)
                UnitRemoveAbility(dummy, ABIL_ALOC)
                local dummy2 = Dummy.create(GetUnitX(pt.target), GetUnitY(pt.target), FourCC('A010'), 1)
                SetUnitFlyHeight(dummy2.unit, 135., 0.)
                dummy2:attack(dummy)

                SetUnitScale(pt.target, 1., 1., 1.)
                SetUnitAnimation(pt.target, "death")

                sfx = AddSpecialEffect("war3mapImported\\SuperLightningBall.mdl", x, y)
                BlzSetSpecialEffectScale(sfx, 3.0)
                BlzPlaySpecialEffect(sfx, ANIM_TYPE_DEATH)
                TQ:callDelayed(0.5, DestroyEffect, sfx)
                sfx = AddSpecialEffect("war3mapImported\\EMPBubble.mdx", x, y)
                BlzSetSpecialEffectScale(sfx, thistype.aoe * 0.01)
                BlzPlaySpecialEffectWithTimeScale(sfx, ANIM_TYPE_DEATH, 1.5)
                TQ:callDelayed(1.5, DestroyEffect, sfx)

                MakeGroupInRange(pt.pid, pt.ug, x, y, thistype.aoe, Condition(FilterEnemy))

                for target in each(pt.ug) do
                    DamageTarget(pt.source, target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                return false
            else
                SetUnitScale(pt.target, pt.time / 3., pt.time / 3., pt.time / 3.)
                BlzSetUnitFacingEx(pt.target, GetUnitFacing(pt.target) + 10 * pt.time)

                return true
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.angle = self.angle
            pt.source = self.caster
            pt.target = Dummy.create(self.x + 65. * math.cos(pt.angle), self.y + 65. * math.sin(pt.angle), 0, 0).unit
            pt.dur = 4.
            pt.ug = CreateGroup()

            BlzSetUnitSkin(pt.target, FourCC('h072'))
            SetUnitScale(pt.target, 0., 0., 0.)
            SoundHandler("war3mapImported\\railgun.mp3", true, nil, pt.target)

            pt:startLoop(FPS_32, periodic)
        end
    end
end, Debug and Debug.getLine())
