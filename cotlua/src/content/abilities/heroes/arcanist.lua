OnInit.final("ArcanistSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32
    local TQ = TimerQueue
    local distance = MISSILE_DISTANCE

    ---@class CONTROLTIME : Spell
    ---@field dur number
    CONTROLTIME = Spell.define("A00W")
    do
        local thistype = CONTROLTIME
        thistype.values = {
            dur = 10.,
        }

        local function delay(source, sid, ablev, cd)
            BlzSetUnitAbilityCooldown(source, sid, ablev - 1, cd)
        end

        local function on_cast(source, sid, ablev)
            if math.random(0, 99) < 15 and (sid == ARCANECOMETS.id or sid == ARCANEBARRAGE.id or sid == STASISFIELD.id or sid == ARCANEBOLTS.id or sid == ARCANOSPHERE.id or sid == ARCANESHIFT.id) then
                local pid = GetPlayerId(GetOwningPlayer(source)) + 1
                local cd = Spells[sid].cooldown
                cd = (type(cd) == "function" and cd(pid)) or cd
                BlzSetUnitAbilityCooldown(source, sid, ablev - 1, math.max(0.01, cd - 20))
                TQ:callDelayed(0., delay, source, sid, ablev, cd)
                SoundHandler("Abilities\\Spells\\NightElf\\FaerieDragonInvis\\PhaseShift1.flac", false, GetOwningPlayer(source))
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_CAST:register_unit_action(u, on_cast)
        end
    end

    ---@class ARCANECOMETS : Spell
    ---@field dmg function
    ---@field aoe number
    ARCANECOMETS = Spell.define("A00U")
    do
        local thistype = ARCANECOMETS

        thistype.values = {
            dmg = function(pid) return 2. * GetHeroInt(Hero[pid], true) end,
            aoe = 250.,
        }
        thistype.cooldown = 3.

        local function comet_land(self, x, y, aoe)
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, x, y, aoe, Condition(FilterEnemy))

            for target in each(ug) do
                DamageTarget(self.caster, target, self.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function spawn(self, count)
            local pt = TimerList[self.pid]:get(ARCANOSPHERE.id)

            if pt then
                count = count - 1

                if count >= 0 then
                    MakeGroupInRange(self.pid, self.ug, pt.x, pt.y, 800., Condition(FilterEnemy))

                    for enemy in each(pt.ug) do
                        local x = GetUnitX(enemy)
                        local y = GetUnitY(enemy)

                        local sfx = AddSpecialEffect("war3mapImported\\Voidfall Medium.mdx", x, y)
                        BlzPlaySpecialEffectWithTimeScale(sfx, ANIM_TYPE_STAND, 1.5)
                        TQ:callDelayed(2., DestroyEffect, sfx)
                        TQ:callDelayed(0.6, comet_land, self, x, y, pt.aoe)
                    end

                    TQ:callDelayed(0.2, spawn, self, count)
                end
            end
        end

        function thistype:onCast()
            self.ug = CreateGroup()
            spawn(self, self.ablev + 2)
        end
    end

    ---@class ARCANEBOLTS : Spell
    ---@field dmg function
    ---@field aoe number
    ARCANEBOLTS = Spell.define("A05Q")
    do
        local thistype = ARCANEBOLTS

        thistype.values = {
            dmg = function(pid) return 2. * GetHeroInt(Hero[pid], true) end,
            aoe = 250.,
        }
        thistype.cooldown = 5.

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
            speed = 1400.,
            visualZ = 60.,
            onUnitCollision = CAT_UnitImpact2D,
            onUnitCallback = function(self, enemy)
                local ug = CreateGroup()
                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe, Condition(FilterEnemy))

                for target in each(ug) do
                    DamageTarget(self.source, target, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", self.x, self.y))
                DestroyGroup(ug)
            end,
        }
        missile_template.__index = missile_template

        local function spawn(self, dur)
            dur = dur - 1

            if dur >= 0 then
                local missile = setmetatable({}, missile_template)
                missile.x = GetUnitX(self.caster)
                missile.y = GetUnitY(self.caster)
                missile.vx = missile.speed * math.cos(self.angle)
                missile.vy = missile.speed * math.sin(self.angle)
                missile.visual = AddSpecialEffect("ArcaneRocketProjectile.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.4)
                missile.source = self.caster
                missile.owner = Player(self.pid - 1)
                missile.damage = self.dmg * BOOST[self.pid]
                missile.dist = 1000.
                missile.aoe = self.aoe * LBOOST[self.pid]
                missile.pid = self.pid

                ALICE_Create(missile)

                TQ:callDelayed(0.2, spawn, self, dur)
            end
        end

        function thistype:onCast()
            spawn(self, self.ablev + 2)
        end
    end

    ---@class ARCANEBARRAGE : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field cooldown function
    ARCANEBARRAGE = Spell.define("A02N")
    do
        local thistype = ARCANEBARRAGE

        thistype.values = {
            aoe = 750.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (ablev + 1.) end,
            cooldown = function(pid) return TimerList[pid]:has(ARCANOSPHERE.id) and 3. or 5. end,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveHoming3D,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 10.,
            friendlyFire = false,
            onlyTarget = true,
            speed = 750.,
            visualZ = 50.,
            launchOffset = 20.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            ArcaneBarrageBuff:add(self.caster, self.caster):duration(3.)

            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            local size = BlzGroupGetSize(ug) ---@type integer
            local target = FirstOfGroup(ug)
            local singletarget = false

            if target then
                if size == 1 then
                    singletarget = true
                    size = 3
                end

                for i = 0, size - 1 do
                    if not singletarget then
                        target = BlzGroupUnitAt(ug, i)
                    end

                    local missile = setmetatable({}, missile_template)
                    missile.x = self.x
                    missile.y = self.y
                    missile.z = GetUnitZ(self.caster)
                    missile.visual = AddSpecialEffect("war3mapImported\\TinkerRocketMissileModified2.mdl", self.x, self.y)
                    BlzSetSpecialEffectScale(missile.visual, 1.1)
                    missile.source = self.caster
                    missile.owner = Player(self.pid - 1)
                    missile.target = target
                    missile.damage = self.dmg * BOOST[self.pid]

                    ALICE_Create(missile)
                end
            end

            DestroyGroup(ug)
        end
    end

    ---@class ARCANOSPHERE : Spell
    ---@field dur function
    ARCANOSPHERE = Spell.define("A079")
    do
        local thistype = ARCANOSPHERE

        thistype.values = {
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 8. + 4. * ablev end,
        }
        thistype.cooldown = 60.

        local function periodic(self)
            MakeGroupInRange(self.pid, self.ug, self.x, self.y, self.aoe, Condition(FilterEnemy))

            for target in each(self.ug) do
                ArcanosphereDebuff:add(self.source, target):duration(1.)
            end

            if IsUnitInRangeXY(self.source, self.x, self.y, self.aoe) then
                ArcanosphereBuff:add(self.source, self.source):duration(1.)
            end

            self.callback = TQ:callDelayed(0.5, periodic, self)
        end

        local function on_expire(self)
            TQ:disableCallback(self.callback)

            BlzPlaySpecialEffectWithTimeScale(self.sfx, ANIM_TYPE_DEATH, 1.5)
            TQ:callDelayed(1.5, HideEffect, self.sfx)

            UnitRemoveAbility(self.source, ARCANECOMETS.id)
            BlzUnitHideAbility(self.source, ARCANEBOLTS.id, false)
            BlzSetUnitAbilityCooldown(self.source, ARCANEBARRAGE.id, GetUnitAbilityLevel(self.source, ARCANEBARRAGE.id) - 1, 5.)

            DestroyGroup(self.ug)
        end

        function thistype:onCast()
            self.aoe = 800.
            self.x = self.targetX
            self.y = self.targetY
            self.source = self.caster
            self.tag = thistype.id
            self.ug = CreateGroup()

            self.sfx = AddSpecialEffect("war3mapImported\\Ubershield Void.mdl", self.targetX, self.targetY)
            BlzSetSpecialEffectZ(self.sfx, GetTerrainZ(self.targetX, self.targetY) - 50.)
            BlzSetSpecialEffectScale(self.sfx, 10.)
            BlzPlaySpecialEffectWithTimeScale(self.sfx, ANIM_TYPE_BIRTH, 0.4)

            --swap to comets
            UnitAddAbility(self.caster, ARCANECOMETS.id)
            SetUnitAbilityLevel(self.caster, ARCANECOMETS.id, GetUnitAbilityLevel(self.caster, ARCANEBOLTS.id))
            BlzUnitHideAbility(self.caster, ARCANEBOLTS.id, true)

            --barrage cooldown
            BlzEndUnitAbilityCooldown(self.caster, ARCANEBARRAGE.id)
            BlzSetUnitAbilityCooldown(self.caster, ARCANEBARRAGE.id, GetUnitAbilityLevel(self.caster, ARCANEBARRAGE.id) - 1, 3.)

            periodic(self)
            TQ:callDelayed(self.dur * LBOOST[self.pid], on_expire, self)
        end
    end

    ---@class STASISFIELD : Spell
    ---@field aoe number
    ---@field dur number
    STASISFIELD = Spell.define("A075")
    do
        local thistype = STASISFIELD

        thistype.values = {
            aoe = 250.,
            dur = 6.,
        }
        thistype.cooldown = 20.

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - 0.25

            if pt.dur > 0. then
                MakeGroupInRange(pt.pid, pt.ug, pt.x, pt.y, pt.aoe, Condition(FilterEnemy))

                for target in each(pt.ug) do
                    StasisFieldDebuff:add(pt.source, target):duration(0.5)
                end

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.x = self.targetX
            pt.y = self.targetY
            pt.dur = self.dur * LBOOST[self.pid]
            pt.source = self.caster
            pt.ug = CreateGroup()

            pt.target = Dummy.create(pt.x, pt.y, 0, 0, 6.).unit
            BlzSetUnitSkin(pt.target, FourCC('h02B'))
            SetUnitScale(pt.target, 1.05 * LBOOST[self.pid], 1.05 * LBOOST[self.pid], 1.05 * LBOOST[self.pid])
            UnitDisableAbility(pt.target, FourCC('Amov'), true)
            SetUnitFlyHeight(pt.target, 0., 0.)
            SetUnitAnimation(pt.target, "birth")

            pt:startLoop(0.25, periodic)
        end
    end

    ---@class ARCANESHIFT : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field dur number
    ARCANESHIFT = Spell.define("A078")
    do
        local thistype = ARCANESHIFT

        thistype.values = {
            aoe = 350.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (5. + 3. * ablev) * GetHeroInt(Hero[pid], true) end,
            dur = 4.,
        }
        thistype.cooldown = 30.

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local pt = TimerList[pid]:get(thistype.id, caster)

            if not IsTerrainWalkable(targetX, targetY) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            elseif pt then
                if DistanceCoords(targetX, targetY, pt.x, pt.y) > 1500. then
                    IssueImmediateOrderById(caster, ORDER_ID_STOP)
                    DisplayTextToPlayer(Player(pid - 1), 0, 0, "|cffff0000Target point is too far away!")
                end
            end
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.time = pt.time + FPS_32

            if pt.time >= pt.dur then
                for target in each(pt.ug) do
                    SetUnitFlyHeight(target, 0.00, 0.00)
                    if GetUnitMoveSpeed(target) > 0 then
                        SetUnitPathing(target, false)
                        SetUnitXBounded(target, pt.x)
                        SetUnitYBounded(target, pt.y)
                        TQ:callDelayed(2., SetUnitPathing, target, true)
                    end
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(target), GetUnitY(target)))
                    DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                BlzStartUnitAbilityCooldown(pt.source, thistype.id, pt.cooldown - pt.time)

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(thistype.id, self.caster)

            --second cast
            if pt then
                pt.x = self.targetX
                pt.y = self.targetY
                pt.dur = 0.
            else
                local ug = CreateGroup()

                MakeGroupInRange(self.pid, ug, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                if FirstOfGroup(ug) then
                    pt = TimerList[self.pid]:add()
                    pt.ug = CreateGroup()
                    pt.dmg = self.dmg * BOOST[self.pid]
                    pt.dur = self.dur * LBOOST[self.pid]
                    pt.cooldown = BlzGetUnitAbilityCooldown(self.caster, self.sid, self.ablev - 1)
                    pt.source = self.caster
                    pt.tag = thistype.id
                    pt.x = self.targetX
                    pt.y = self.targetY

                    for target in each(ug) do
                        GroupAddUnit(pt.ug, target)
                        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", GetUnitX(target), GetUnitY(target)))
                        if UnitAddAbility(target, FourCC('Amrf')) then
                            UnitRemoveAbility(target, FourCC('Amrf'))
                        end
                        Stun:add(self.caster, target):duration(pt.dur)
                        SetUnitFlyHeight(target, 500.00, 0.00)
                    end

                    TQ:callDelayed(FPS_32, BlzEndUnitAbilityCooldown, pt.source, thistype.id)
                    pt:startLoop(FPS_32, periodic)
                end

                DestroyGroup(ug)
            end
        end
    end
end, Debug and Debug.getLine())
