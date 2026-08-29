OnInit.final("ElementalistSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    masterElement = __jarray(0) ---@type integer[] 

    local TQ = TimerQueue
    local distance = MISSILE_DISTANCE

    local MASTEROFELEMENTS = Spell.define('A0J5')

    ---@class ELEMENTFIRE : Spell
    ---@field value integer
    ---@field reset function
    ELEMENTFIRE = Spell.define("A0J8")
    do
        local thistype = ELEMENTFIRE
        thistype.value = 1 ---@type integer 

        function thistype:onCast()
            IceElementBuff:dispel(self.caster, self.caster)
            LightningElementBuff:dispel(self.caster, self.caster)
            EarthElementBuff:dispel(self.caster, self.caster)
            FireElementBuff:add(self.caster, self.caster)
        end
    end

    ---@class ELEMENTICE : Spell
    ---@field value integer
    ELEMENTICE = Spell.define("A0J6")
    do
        local thistype = ELEMENTICE
        thistype.value = 2 ---@type integer 

        local function periodic(pid)
            if masterElement[pid] == thistype.value then
                local ug = CreateGroup()
                MakeGroupInRange(pid, ug, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), 900. * LBOOST[pid], Filter(FilterEnemy))

                for enemy in each(ug) do
                    if not UnitIsSleeping(enemy) then
                        IceElementDebuff:add(Hero[pid], enemy):duration(1.1)
                    end
                end

                DestroyGroup(ug)

                TQ:callDelayed(1., periodic, pid)
            end
        end

        function thistype:onCast()
            FireElementBuff:dispel(self.caster, self.caster)
            LightningElementBuff:dispel(self.caster, self.caster)
            EarthElementBuff:dispel(self.caster, self.caster)
            IceElementBuff:add(self.caster, self.caster)
            TQ:callDelayed(0., periodic, self.pid)
        end
    end

    ---@class ELEMENTLIGHTNING : Spell
    ---@field value integer
    ELEMENTLIGHTNING = Spell.define("A0J9")
    do
        local thistype = ELEMENTLIGHTNING
        thistype.value = 3 ---@type integer 

        function thistype:onCast()
            FireElementBuff:dispel(self.caster, self.caster)
            EarthElementBuff:dispel(self.caster, self.caster)
            IceElementBuff:dispel(self.caster, self.caster)
            LightningElementBuff:add(self.caster, self.caster)
        end
    end

    ---@class ELEMENTEARTH : Spell
    ---@field value integer
    ---@field reset function
    ELEMENTEARTH = Spell.define("A0JA")
    do
        local thistype = ELEMENTEARTH
        thistype.value = 4 ---@type integer 

        function thistype:onCast()
            FireElementBuff:dispel(self.caster, self.caster)
            IceElementBuff:dispel(self.caster, self.caster)
            LightningElementBuff:dispel(self.caster, self.caster)
            EarthElementBuff:add(self.caster, self.caster)
        end
    end

    ---@class BALLOFLIGHTNING : Spell
    ---@field range function
    ---@field dmg function
    BALLOFLIGHTNING = Spell.define("A0GV")
    do
        local thistype = BALLOFLIGHTNING

        thistype.values = {
            range = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 650. + 200. * ablev end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (5. + ablev) * GetHeroInt(Hero[pid], true) end,
        }

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
            collisionRadius = 100.,
            visualZ = 60.,
            onUnitCollision = CAT_UnitImpact2D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.visual = AddSpecialEffect("Abilities\\Weapons\\FarseerMissile\\FarseerMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1. + .2 * self.ablev)
            missile.speed = 900. + 100. * self.ablev
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.source = self.caster
            missile.owner = Player(self.pid - 1)
            missile.damage = self.dmg * BOOST[self.pid]
            missile.dist = self.range

            ALICE_Create(missile)
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.05))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class FROZENORB : Spell
    ---@field id2 integer
    ---@field iceaoe number
    ---@field icedmg function
    ---@field orbrange number
    ---@field orbdmg function
    ---@field orbaoe number
    ---@field freeze number
    ---@field missile table[]
    FROZENORB = Spell.define("A011", "A01W")
    do
        local thistype = FROZENORB
        thistype.id2 = FourCC("A01W") ---@type integer 

        thistype.values = {
            iceaoe = 750.,
            icedmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (0.5 + 0.5 * ablev) end,
            orbrange = 1000.,
            orbdmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * 3. * ablev end,
            orbaoe = 400.,
            freeze = 3.,
        }
        thistype.missile = {}

        local icicle_template = {
            selfInteractions = {
                CAT_MoveHoming3D,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D
            },
            identifier = "missile",
            onlyTarget = true,
            friendlyFire = false,
            collisionRadius = 5.,
            speed = 1000,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, thistype.icedmg(self.pid) * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        icicle_template.__index = icicle_template

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight,
                CAT_Orient2D,
                distance,
            },
            identifier = "missile",
            speed = 200.,
            visualZ = 75.,

            destroy = function(self)
                -- show original cast
                UnitRemoveAbility(self.source, thistype.id2)
                BlzUnitHideAbility(self.source, thistype.id, false)

                -- orb shatter
                local ug = CreateGroup()
                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    Freeze:add(self.source, target):duration(self.freeze * LBOOST[self.pid])
                    DamageTarget(self.source, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)

                DestroyEffect(self.visual)
                DestroyEffect(AddSpecialEffect("war3mapImported\\FrostNova.mdx", self.x, self.y))
                thistype.missile[self.pid] = nil
            end
        }
        missile_template.__index = missile_template

        ---@type fun(pid: number, self: table)
        local function spawn_icicle(pid, missile)
            if thistype.missile[pid] then
                local ug = CreateGroup()

                MakeGroupInRange(pid, ug, missile.x, missile.y, thistype.iceaoe * LBOOST[pid], Condition(FilterEnemy))

                for target in each(ug) do
                    local icicle = setmetatable({}, icicle_template)
                    icicle.x = missile.x
                    icicle.y = missile.y
                    icicle.z = missile.z
                    icicle.visual = AddSpecialEffect("war3mapImported\\BlizMissile.mdl", missile.x, missile.y)
                    BlzSetSpecialEffectScale(icicle.visual, 0.6)
                    icicle.source = missile.source
                    icicle.owner = missile.owner
                    icicle.target = target
                    icicle.pid = pid

                    ALICE_Create(icicle)
                end

                DestroyGroup(ug)

                TQ:callDelayed(1., spawn_icicle, pid, missile)
            end
        end

        function thistype:onCast()
            local missile = thistype.missile[self.pid]

            --recast
            if missile then
                ALICE_Kill(missile)
            else
                missile = setmetatable({}, missile_template)
                missile.x = self.x
                missile.y = self.y
                missile.vx = missile.speed * math.cos(self.angle)
                missile.vy = missile.speed * math.sin(self.angle)
                missile.launchOffset = 75.
                missile.visual = AddSpecialEffect("war3mapImported\\FrostOrb.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.3)
                missile.source = self.caster
                missile.owner = Player(self.pid - 1)
                missile.dist = self.orbrange
                missile.freeze = self.freeze
                missile.aoe = self.orbaoe
                missile.dmg = self.orbdmg
                missile.pid = self.pid

                ALICE_Create(missile)

                thistype.missile[self.pid] = missile
                TQ:callDelayed(0.5, spawn_icicle, self.pid, missile)

                -- show second cast
                BlzUnitHideAbility(self.caster, thistype.id, true)
                UnitAddAbility(self.caster, thistype.id2)
                SetUnitAbilityLevel(self.caster, thistype.id2, self.ablev)
            end
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.15))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class GAIAARMOR : Spell
    ---@field shield function
    GAIAARMOR = Spell.define("A032")
    do
        local thistype = GAIAARMOR

        thistype.values = {
            shield = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (0.5 + 0.5 * ablev) end,
        }
        thistype.sfx = {}

        local function on_expire(source)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local sfx = thistype.sfx[pid]

            if sfx then
                Unit[source]:removeEffect(sfx)
                thistype.sfx[pid] = nil
            end
            EVENT_ON_SHIELD_EXPIRE:unregister_unit_action(source, on_expire)
        end

        function thistype:onCast()
            local sfx = thistype.sfx[self.pid]

            if sfx then
                Unit[self.caster]:removeEffect(sfx)
            end
            thistype.sfx[self.pid] = Unit[self.caster]:addEffect("war3mapImported\\Archnathid Armor.mdx", "chest")
            thistype.sfx[self.pid].color = {160, 255, 160}

            if masterElement[self.pid] == ELEMENTEARTH.value then -- earth element bonus
                Shield.add(self.caster, self.shield * 2.5 * BOOST[self.pid], 31.)
            else
                Shield.add(self.caster, self.shield * BOOST[self.pid], 31.)
            end

            EVENT_ON_SHIELD_EXPIRE:register_unit_action(self.caster, on_expire)
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                GaiaArmorBuff:add(source, source)
            end
        end
    end

    ---@class FLAMEBREATH : Spell
    ---@field aoe number
    ---@field dmg function
    FLAMEBREATH = Spell.define("A01U")
    do
        local thistype = FLAMEBREATH

        thistype.values = {
            aoe = 750.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (0.5 + 0.5 * ablev) end,
        }

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur + 1

            local mp     = GetUnitState(Hero[pt.pid], UNIT_STATE_MANA) ---@type number 
            local x      = GetUnitX(Hero[pt.pid]) ---@type number 
            local y      = GetUnitY(Hero[pt.pid]) ---@type number 

            -- trapezoid
            local Ax     = x + 50 * math.cos(pt.angle + bj_PI * 0.5) ---@type number 
            local Ay     = y + 50 * math.sin(pt.angle + bj_PI * 0.5) ---@type number 
            local Bx     = x + 50 * math.cos(pt.angle - bj_PI * 0.5) ---@type number 
            local By     = y + 50 * math.sin(pt.angle - bj_PI * 0.5) ---@type number 
            local Cx     = Bx + pt.aoe * math.cos(pt.angle - bj_PI * 0.125) * LBOOST[pt.pid] ---@type number 
            local Cy     = By + pt.aoe * math.sin(pt.angle - bj_PI * 0.125) * LBOOST[pt.pid] ---@type number 
            local Dx     = Ax + pt.aoe * math.cos(pt.angle + bj_PI * 0.125) * LBOOST[pt.pid] ---@type number 
            local Dy     = Ay + pt.aoe * math.sin(pt.angle + bj_PI * 0.125) * LBOOST[pt.pid] ---@type number 
            local AB ---@type number 
            local BC ---@type number 
            local CD ---@type number 
            local DA ---@type number 

            if GetUnitCurrentOrder(Hero[pt.pid]) == OrderId("clusterrockets") and UnitAlive(Hero[pt.pid]) and mp >= BlzGetUnitMaxMana(Hero[pt.pid]) * 0.03 then
                if ModuloReal(pt.dur, 2.) == 0 then
                    SetUnitState(Hero[pt.pid], UNIT_STATE_MANA, mp - BlzGetUnitMaxMana(Hero[pt.pid]) * 0.03)
                end
                if ModuloReal(pt.dur, 5.) == 0 then
                    SoundHandler("Abilities\\Spells\\Other\\BreathOfFire\\BreathOfFire1.flac", true, nil, Hero[pt.pid])
                end

                MakeGroupInRange(pt.pid, pt.ug, x, y, pt.aoe * LBOOST[pt.pid], Condition(FilterEnemy))

                for target in each(pt.ug) do
                    x = GetUnitX(target)
                    y = GetUnitY(target)

                    AB = (y - By) * (Ax - Bx) - (x - Bx) * (Ay - By)
                    BC = (y - Cy) * (Bx - Cx) - (x - Cx) * (By - Cy)
                    CD = (y - Dy) * (Cx - Dx) - (x - Dx) * (Cy - Dy)
                    DA = (y - Ay) * (Dx - Ax) - (x - Ax) * (Dy - Ay)

                    if (AB >= 0 and BC >= 0 and CD >= 0 and DA >= 0) or (AB <= 0 and BC <= 0 and CD <= 0 and DA <= 0) then
                        DamageTarget(Hero[pt.pid], target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                return true
            end

            return false
        end

        function thistype:onCast()
            TimerList[self.pid]:stopAllTimers(thistype.id)

            local pt = TimerList[self.pid]:add()
            pt.angle = self.angle
            pt.sfx = AddSpecialEffect("war3mapImported\\flamebreath.mdx", self.x + 75 * math.cos(pt.angle), self.y + 75 * math.sin(pt.angle))
            pt.tag = thistype.id
            pt.aoe = self.aoe
            pt.dmg = self.dmg
            pt.ug = CreateGroup()
            BlzSetSpecialEffectScale(pt.sfx, 1.3 * LBOOST[self.pid])
            BlzSetSpecialEffectTimeScale(pt.sfx, 1.5)
            BlzSetSpecialEffectYaw(pt.sfx, pt.angle)

            pt:startLoop(0.5, periodic)
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.03))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class ELEMENTALSTORM : Spell
    ---@field times number
    ---@field dmg function
    ---@field aoe number
    ELEMENTALSTORM = Spell.define("A04H")
    do
        local thistype = ELEMENTALSTORM

        thistype.values = {
            times = 12.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (1.5 + 0.5 * ablev) end,
            aoe = 400.,
        }

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - 1

            local rand = GetRandomInt(1, 4) ---@type integer 
            local angle = GetRandomInt(0, 359) * bj_DEGTORAD ---@type number 
            local dist = GetRandomInt(50, 200) ---@type integer 
            local x2 = pt.x + dist * math.cos(angle) ---@type number 
            local y2 = pt.y + dist * math.sin(angle) ---@type number 

            -- guarantee the first 6 strikes are your chosen element
            if pt.dur >= 6 then
                rand = pt.element
            else
                while not ((rand ~= pt.element and rand ~= pt.str and rand ~= pt.int)) do
                    rand = GetRandomInt(1, 4)
                end
            end

            -- alternate elements
            if pt.str == 0 then
                pt.str = rand
            elseif pt.int == 0 then
                pt.int = rand
            else
                pt.str = 0
                pt.int = 0
            end

            if pt.dur >= 0 then
                TQ:callDelayed(1., DestroyEffect, AddSpecialEffect("war3mapImported\\Lightnings Long.mdx", x2, y2))

                -- fire aoe
                if rand == ELEMENTFIRE.value then
                    MakeGroupInRange(pt.pid, pt.ug, pt.x, pt.y, pt.aoe * 1.5, Condition(FilterEnemy))
                    TQ:callDelayed(2., DestroyEffect, AddSpecialEffect("war3mapImported\\Flame Burst.mdx", x2, y2))
                else
                    MakeGroupInRange(pt.pid, pt.ug, pt.x, pt.y, pt.aoe, Condition(FilterEnemy))
                end

                local target = FirstOfGroup(pt.ug)

                -- sfx
                if rand == ELEMENTICE.value then
                    TQ:callDelayed(2., DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", x2, y2))
                    MP(Hero[pt.pid], BlzGetUnitMaxMana(Hero[pt.pid]) * 0.15)
                elseif rand == ELEMENTLIGHTNING.value then
                    DamageTarget(Hero[pt.pid], target, GetWidgetLife(target) * 0.015, ATTACK_TYPE_NORMAL, PURE, thistype.tag)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\Bolt\\BoltImpact.mdl", target, "origin"))
                elseif rand == ELEMENTEARTH.value then
                    TQ:callDelayed(2., DestroyEffect, AddSpecialEffect("war3mapImported\\Earth NovaTarget.mdx", x2, y2))
                end

                -- unique effects
                for enemy in each(pt.ug) do
                    -- fire
                    if rand == ELEMENTFIRE.value then
                        DamageTarget(Hero[pt.pid], enemy, pt.dmg * 1.5, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    else
                        DamageTarget(Hero[pt.pid], enemy, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                        -- ice
                        if rand == ELEMENTICE.value then
                            Freeze:add(Hero[pt.pid], enemy):duration(2.)
                        -- earth
                        elseif rand == ELEMENTEARTH.value then
                            local b = EarthDebuff:get(nil, enemy)
                            if b then
                                b.level = b.level + 1
                                b:refresh()
                            end
                            EarthDebuff:add(Hero[pt.pid], enemy):duration(10.)
                        end
                    end
                end

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.x = self.targetX
            pt.y = self.targetY
            pt.dur = self.times
            pt.dmg = self.dmg * BOOST[self.pid]
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.ug = CreateGroup()

            if masterElement[self.pid] == 0 then
                pt.element = GetRandomInt(1, 4)
            else
                pt.element = masterElement[self.pid]
            end

            pt:startLoop(0.4, periodic)
        end

        local manacost = function(u, key)
            if key == "int" or key == "bonus_mana" or key == "bonus_int" then
                BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.25))
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end
end, Debug and Debug.getLine())
