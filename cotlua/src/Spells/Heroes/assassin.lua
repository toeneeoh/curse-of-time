OnInit.final("AssassinSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32
    local atan = math.atan
    local distance = MISSILE_DISTANCE

    ---@class SHADOWSHURIKEN : Spell
    ---@field dmg function
    SHADOWSHURIKEN = Spell.define("A0BG")
    do
        local thistype = SHADOWSHURIKEN

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (GetHeroAgi(Hero[pid], true) + Unit[Hero[pid]].damage) * (ablev + 5.) * 0.25 end,
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
            visualZ = 75.,
            identifier = "missile",
            friendlyFire = false,
            collisionRadius = 100.,
            speed = 1800.,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = function(self, enemy)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", enemy, "chest"))
                local debuff = MarkedForDeathDebuff:get(nil, enemy) ---@type Buff

                if debuff and self.mana < 50 then
                    local mana = 6  ---@type integer --percent mana restored per unit hit
                    local percentcap = 50 ---@type integer 

                    --mana restore from bosses
                    if IsUnitType(enemy, UNIT_TYPE_HERO) then
                        mana = 25
                    end

                    debuff:dispel()

                    self.mana = self.mana + mana
                    if self.mana > percentcap then
                        mana = ModuloInteger(self.mana, percentcap)
                    end

                    SetUnitState(self.source, UNIT_STATE_MANA, GetUnitState(self.source, UNIT_STATE_MANA) + BlzGetUnitMaxMana(self.source) * mana * 0.01)
                    SetUnitPathing(enemy, true)

                    if not self.mana_effect then
                        self.mana_effect = true
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIma\\AImaTarget.mdl", self.source, "origin"))
                    end
                end
                DamageTarget(self.source, enemy, self.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            --change blade spin to active
            UnitAddAbility(self.caster, BLADESPIN.id)
            UnitDisableAbility(self.caster, BLADESPIN.id2, true)

            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.visual = AddSpecialEffect("Abilities\\Weapons\\GlaiveMissile\\GlaiveMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            BlzSetSpecialEffectColor(missile.visual, 100, 100, 100)
            missile.source = self.caster
            missile.owner = Player(self.pid - 1)
            missile.dmg = self.dmg * BOOST[self.pid]
            missile.dist = 750
            missile.mana = 0

            ALICE_Create(missile)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.05))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class BLINKSTRIKE : Spell
    ---@field dmg function
    ---@field aoe number
    BLINKSTRIKE = Spell.define("A00T")
    do
        local thistype = BLINKSTRIKE
        thistype.preCast = DASH_PRECAST

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev * (0.5 * GetHeroAgi(Hero[pid], true) + 0.25 * (Unit[Hero[pid]].damage)) end,
            aoe = 200.,
        }

        function thistype:onCast()
            local ug = CreateGroup()

            --change blade spin to active
            UnitAddAbility(self.caster, BLADESPIN.id)
            UnitDisableAbility(self.caster, BLADESPIN.id2, true)

            for i = 0, 11 do
                self.angle = 0.1666 * bj_PI * i
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Orc\\FeralSpirit\\feralspiritdone.mdl", self.targetX + 190. * math.cos(self.angle), self.targetY + 190. * math.sin(self.angle)))
            end

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Orc\\FeralSpirit\\feralspiritdone.mdl", self.targetX, self.targetY))
            MakeGroupInRange(self.pid, ug, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            for target in each(ug) do
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", target, "origin"))

                local debuff = MarkedForDeathDebuff:get(nil, target)

                if debuff then
                    SetUnitPathing(target, true)
                    debuff:remove()
                    BlinkStrikeBuff:add(Hero[self.pid], Hero[self.pid]):duration(6.)
                end

                DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            SetUnitXBounded(self.caster, self.targetX)
            SetUnitYBounded(self.caster, self.targetY)

            DestroyGroup(ug)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.15))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class SMOKEBOMB : Spell
    ---@field aoe number
    ---@field dur number
    SMOKEBOMB = Spell.define("A01E")
    do
        local thistype = SMOKEBOMB

        thistype.values = {
            aoe = 300.,
            dur = 8.,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.dur = pt.dur - 0.5

            if pt.dur > 0. then
                local ug = CreateGroup()
                MakeGroupInRange(pt.pid, ug, pt.x, pt.y, pt.aoe, Condition(isalive))

                for target in each(ug) do
                    if IsUnitAlly(target, Player(pt.pid - 1)) then
                        SmokebombBuff:add(Hero[pt.pid], target):duration(1.)
                    else
                        SmokebombDebuff:add(Hero[pt.pid], target):duration(1.)
                    end
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(0.5, periodic, pt)
            else
                pt:destroy()
            end
        end

        function thistype:onCast()
            --change blade spin to active
            UnitAddAbility(self.caster, BLADESPIN.id)
            UnitDisableAbility(self.caster, BLADESPIN.id2, true)

            local pt = TimerList[self.pid]:add()
            pt.x = self.targetX
            pt.y = self.targetY
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.dur = self.dur * LBOOST[self.pid]

            pt.sfx = AddSpecialEffect("war3mapImported\\GreySmoke.mdx", self.targetX, self.targetY)
            BlzSetSpecialEffectScale(pt.sfx, LBOOST[self.pid])
            pt.timer:callDelayed(0.5, periodic, pt)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.2))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class DAGGERSTORM : Spell
    ---@field dmg function
    ---@field num number
    DAGGERSTORM = Spell.define("A00P")
    do
        local thistype = DAGGERSTORM

        thistype.values = {
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 2. end,
            num = 30.,
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
            visualZ = 70.,
            identifier = "missile",
            friendlyFire = false,
            collisionRadius = 50.,
            speed = 1500.,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = function(self, enemy)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", enemy, "origin"))
                DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                self.damage = self.damage - (self.damage * 0.05)
            end,
        }
        missile_template.__index = missile_template

        local function periodic(self)
            if self.count > 0 then
                self.count = self.count - 3

                for _ = 0, 2 do
                    local spawnangle = self.angle + bj_PI + GetRandomReal(bj_PI * -0.15, bj_PI * 0.15) ---@type number
                    local x = self.x + GetRandomReal(70., 200.) * math.cos(spawnangle) ---@type number
                    local y = self.y + GetRandomReal(70., 200.) * math.sin(spawnangle) ---@type number
                    local moveangle = atan(self.targetY - y, self.targetX - x)
                    local missile = setmetatable({}, missile_template)
                    missile.x = x
                    missile.y = y
                    missile.vx = missile.speed * math.cos(moveangle)
                    missile.vy = missile.speed * math.sin(moveangle)
                    missile.visual = AddSpecialEffect("Abilities\\Weapons\\WardenMissile\\WardenMissile.mdl", x, y)
                    BlzSetSpecialEffectScale(missile.visual, 1.15)
                    missile.source = self.caster
                    missile.owner = Player(self.pid - 1)
                    missile.damage = self.dmg * BOOST[self.pid]
                    missile.dist = 1000 + DistanceCoords(self.x, self.y, x, y)

                    ALICE_Create(missile)
                end

                TimerQueue:callDelayed(FPS_32, periodic, self)
            end
        end

        function thistype:onCast()
            --change blade spin to active
            UnitAddAbility(self.caster, BLADESPIN.id)
            UnitDisableAbility(self.caster, BLADESPIN.id2, true)

            self.count = self.num

            periodic(self)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.25))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end

    ---@class BLADESPIN : Spell
    ---@field id2 integer
    ---@field times function
    ---@field amdg function
    ---@field aoe number
    ---@field pdmg function
    ---@field count number[]
    ---@field admg function
    BLADESPIN = Spell.define("A0AS", "A0AQ")
    do
        local thistype = BLADESPIN
        thistype.id2 = FourCC("A0AQ")

        thistype.values = {
            times = function(pid, u) return math.max(8 - GetHeroLevel(u) // 100, 5) end,
            pdmg = function(pid, u) return 8. * GetHeroAgi(u, true) end,
            aoe = 250.,
            admg = function(pid, u) return 4. * GetHeroAgi(u, true) end,
        }
        thistype.count = __jarray(0)

        ---@type fun(caster: unit, active: boolean)
        local function spin(caster, active)
            local ug = CreateGroup()
            local pid = GetPlayerId(GetOwningPlayer(caster)) + 1

            DelayAnimation(pid, caster, 0.5, 0, 1., true)
            SetUnitTimeScale(caster, 1.75)
            SetUnitAnimationByIndex(caster, 5)

            local x, y = GetUnitX(caster), GetUnitY(caster)

            for i = 0, 1 do
                local sfx = AddSpecialEffect("war3mapImported\\Ephemeral Slash Jade.mdl", x, y)
                BlzSetSpecialEffectZ(sfx, GetUnitZ(caster) + 75.)
                BlzSetSpecialEffectScale(sfx, 1.35)
                BlzSetSpecialEffectTimeScale(sfx, 0.5)
                BlzSetSpecialEffectYaw(sfx, (GetUnitFacing(caster) + 180 * i) * bj_DEGTORAD)
                DestroyEffect(sfx)
            end

            MakeGroupInRange(pid, ug, x, y, thistype.aoe * LBOOST[pid], Condition(FilterEnemy))

            for target in each(ug) do
                DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Critters\\Albatross\\CritterBloodAlbatross.mdl", target, "chest"))
                if active then
                    DamageTarget(caster, target, thistype.admg(pid, caster) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                else
                    DamageTarget(caster, target, thistype.pdmg(pid, caster) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            end

            DestroyGroup(ug)
        end

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            thistype.count[pid] = thistype.count[pid] + 1
        end

        local function on_attack(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            if thistype.count[pid] >= thistype.times(pid) - 1 then
                thistype.count[pid] = 0

                spin(source, false)
            end
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_MANA_SHIELD and GetUnitAbilityLevel(source, thistype.id) > 0 then
                if GetUnitState(source, UNIT_STATE_MANA) >= BlzGetUnitMaxMana(source) * 0.075 then
                    SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MANA) - BlzGetUnitMaxMana(source) * 0.075)

                    UnitRemoveAbility(source, thistype.id)
                    UnitDisableAbility(source, thistype.id2, false)
                    spin(source, true)
                else
                    UnitRemoveAbility(source, thistype.id)
                    UnitAddAbility(source, thistype.id)
                end
            end
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.075))
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT:register_unit_action(u, on_hit)
            EVENT_ON_ATTACK:register_unit_action(u, on_attack)
            EVENT_ON_ORDER:register_unit_action(u, on_order)
            EVENT_STAT_CHANGE:register_unit_action(u, manacost)

            TimerQueue:callDelayed(0.01, UnitRemoveAbility, u, thistype.id)
        end
    end

    ---@class PHANTOMSLASH : Spell
    ---@field dmg function
    ---@field slashing boolean[]
    PHANTOMSLASH = Spell.define("A07Y")
    do
        local thistype = PHANTOMSLASH
        thistype.slashing = {}

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid], true) * 1.5 * ablev end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local x = GetUnitX(pt.source) ---@type number 
            local y = GetUnitY(pt.source) ---@type number 

            pt.dur = pt.dur - pt.speed

            if pt.dur > 0. then
                --movement
                if IsTerrainWalkable(x + pt.speed * math.cos(pt.angle), y + pt.speed * math.sin(pt.angle)) then
                    SetUnitXBounded(pt.source, x + pt.speed * math.cos(pt.angle))
                    SetUnitYBounded(pt.source, y + pt.speed * math.sin(pt.angle))
                else
                    pt.dur = 0.
                end

                local ug = CreateGroup()
                MakeGroupInRange(pt.pid, ug, x, y, 200., Condition(FilterEnemy))

                for target in each(ug) do
                    if not IsUnitInGroup(target, pt.ug) then
                        GroupAddUnit(pt.ug, target)
                        MarkedForDeathDebuff:add(pt.source, target):duration(4.)
                        DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(FPS_32, periodic, pt)
            else
                pt:destroy()
            end
        end

        local function onRemove(self)
            BlzUnitClearOrders(self.source, true)
            BlzUnitDisableAbility(self.source, thistype.id, false, false)

            thistype.slashing[self.pid] = false
            Unit[self.source].evasion = Unit[self.source].evasion - 100
            SetUnitTimeScale(self.source, 1.)
            SetUnitAnimationByIndex(self.source, 4)
        end

        function thistype:onCast()
            thistype.slashing[self.pid] = true
            Unit[self.caster].evasion = Unit[self.caster].evasion + 100

            BlzUnitDisableAbility(self.caster, thistype.id, true, false)
            SetUnitState(self.caster, UNIT_STATE_MANA, GetUnitState(self.caster, UNIT_STATE_MANA) - BlzGetUnitMaxMana(self.caster) * (.1 - 0.025 * self.ablev))

            local pt = TimerList[self.pid]:add()
            pt.dur = math.min(750., SquareRoot(Pow(self.targetX - self.x, 2) + Pow(self.targetY - self.y, 2)))
            pt.speed = 60.
            pt.dmg = self.dmg * BOOST[self.pid]
            pt.angle = atan(self.targetY - self.y, self.targetX - self.x)
            pt.source = self.caster
            pt.ug = CreateGroup()
            pt.onRemove = onRemove

            TimerQueue:callDelayed(FPS_32, IssueImmediateOrderById, pt.source, ORDER_ID_UNIMMOLATION)
            pt.timer:callDelayed(FPS_32, periodic, pt)

            SetUnitTimeScale(self.caster, 1.5)
            SetUnitAnimationByIndex(self.caster, 5)
            BlzSetUnitFacingEx(self.caster, pt.angle * bj_RADTODEG)

            local sfx = AddSpecialEffect("war3mapImported\\ShadowWarrior.mdl", self.x, self.y)
            BlzSetSpecialEffectColorByPlayer(sfx, Player(self.pid - 1))
            BlzSetSpecialEffectYaw(sfx, pt.angle)
            FadeSFX(sfx, true)
            TimerQueue:callDelayed(2., HideEffect, sfx)
            BlzPlaySpecialEffectWithTimeScale(sfx, ANIM_TYPE_ATTACK, 1.5)
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_IMMOLATION and GetUnitAbilityLevel(source, thistype.id) > 0 and not IsUnitStunned(source) then
                local pid = GetPlayerId(GetOwningPlayer(source)) + 1
                local x, y = GetMouseX(pid), GetMouseY(pid)

                if x ~= 0 and y ~= 0 and not thistype.slashing[pid] then
                    local spell = thistype:create(source)
                    spell.targetX = x
                    spell.targetY = y
                    spell.x = GetUnitX(source)
                    spell.y = GetUnitY(source)

                    spell:onCast()
                end
            end
        end

        local manacost = function(u)
            local ablev = GetUnitAbilityLevel(u, thistype.id)
            BlzSetUnitAbilityManaCost(u, thistype.id, ablev - 1, R2I(BlzGetUnitMaxMana(u) * (.1 - 0.025 * ablev)))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end
end, Debug and Debug.getLine())
