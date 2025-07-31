OnInit.final("MarksmanSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32
    local atan = math.atan

    ---@class SNIPERSTANCE : Spell
    ---@field enabled boolean[]
    SNIPERSTANCE = Spell.define("A049")
    do
        local thistype = SNIPERSTANCE
        thistype.enabled = {}

        ---@type fun(self: SNIPERSTANCE)
        local function delay(self)
            UnitRemoveAbility(self.caster, FourCC('Avul'))
            UnitRemoveAbility(self.caster, FourCC('A03C'))
            UnitAddAbility(self.caster, FourCC('A03C'))

            local enabled = thistype.enabled[self.pid]
            local u = Unit[self.caster]
            u.overmovespeed = (enabled and 100) or nil
            u.cc_percent = (enabled and u.cc_percent + 1.) or u.cc_percent - 1.
            u.cd_percent = (enabled and u.cd_percent + 1.) or u.cd_percent - 1.
            u.base_bat = (enabled and u.base_bat * 2.) or u.base_bat * 0.5
        end

        local function toggle(pid, caster)
            local cooldown = 3.
            local s = "Disable"

            if thistype.enabled[pid] then
                cooldown = 6.
                s = "Enable"
            end

            for i = 0, 9 do
                BlzSetUnitAbilityCooldown(caster, TRIROCKET.id, i, cooldown)
                BlzSetAbilityStringLevelField(BlzGetUnitAbility(caster, thistype.id), ABILITY_SLF_TOOLTIP_NORMAL, i, s .. " Sniper Stance - [|cffffcc00D|r]")
            end

            thistype.enabled[pid] = not thistype.enabled[pid]
        end

        function thistype:onCast()
            toggle(self.pid, self.caster)

            UnitAddAbility(self.caster, FourCC('Avul'))
            TimerQueue:callDelayed(FPS_32, delay, self)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Defend\\DefendCaster.mdl", self.caster, "origin"))
        end

        local function on_death(killed)
            local pid = GetPlayerId(GetOwningPlayer(killed)) + 1

            if thistype.enabled[pid] then
                toggle(pid, killed)
            end
        end

        local function on_cleanup(pid)
            thistype.enabled[pid] = false
        end

        function thistype.onSetup(u)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, on_death)
            EVENT_ON_CLEANUP:register_action(Unit[u].pid, on_cleanup)
        end
    end

    ---@class TRIROCKET : Spell
    ---@field dmg function
    ---@field cooldown function
    TRIROCKET = Spell.define("A06I")
    do
        local thistype = TRIROCKET

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (ablev * GetHeroAgi(Hero[pid], true) + Unit[Hero[pid]].damage * ablev * .1) end,
            cooldown = function(pid) return SNIPERSTANCE.enabled[pid] and 3. or 6. end,
        }

        local missile_template = {
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
                self = {
                    CAT_Orient3D,
                    CAT_MoveBallistic,
                    CAT_CheckTerrainCollision
                }
            },
            identifier = "missile",
            speed = 1600,
            collisionRadius = 75,
            friendlyFire = false,
            onUnitCollision = CAT_UnitImpact3D,
            destroy = function(self)
                local ug = CreateGroup()

                MakeGroupInRange(self.pid, ug, self.x, self.y, 175. * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    DamageTarget(self.source, target, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyEffect(self.visual)
                DestroyGroup(ug)
            end
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            SoundHandler("Units\\Human\\SteamTank\\SteamTankAttack1.flac", true, Player(self.pid - 1), self.caster)

            for i = 0, 2 do
                local angle = self.angle + 0.175 * i - 0.175
                local missile = setmetatable({}, missile_template)
                missile.source = self.caster
                missile.pid = self.pid
                missile.owner = Player(self.pid - 1)
                missile.damage = self.dmg * BOOST[self.pid]
                missile.x = self.x
                missile.y = self.y
                missile.z = GetUnitZ(self.caster) + 80.
                missile.vx = missile.speed * math.cos(angle)
                missile.vy = missile.speed * math.sin(angle)
                missile.vz = 180
                missile.damage = self.dmg * BOOST[self.pid]
                missile.visual = AddSpecialEffect("Abilities\\Weapons\\GyroCopter\\GyroCopterMissile.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.2)

                ALICE_Create(missile)
            end

            CAT_Knockback(self.caster, 500 * math.cos(self.angle + bj_PI), 500 * math.sin(self.angle + bj_PI), 0)
            CAT_UnitEnableFriction(self.caster, true)
            TimerQueue:callDelayed(1., CAT_UnitEnableFriction, self.caster, false)
        end
    end

    ---@class ASSAULTHELICOPTER : Spell
    ---@field cd function
    ---@field dmg function
    ---@field dur number
    ASSAULTHELICOPTER = Spell.define("A06U")
    do
        local thistype = ASSAULTHELICOPTER
        local type = {FourCC('h03W'), FourCC('h03V'), FourCC('h03H'),}

        thistype.values = {
            cd = function(pid) return (1.25 - (0.25 * GetUnitAbilityLevel(Hero[pid], thistype.id))) / (LBOOST[pid] ^ 2) end,
            dmg = function(pid) return 0.35 * (Unit[Hero[pid]].damage + GetHeroAgi(Hero[pid], true)) end,
            dur = 30.,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming, CAT_Orient3D
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            onlyTarget = true,
            collisionRadius = 10.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = {
                other = function(self, enemy, cx, cy, perpSpeed, parSpeed, totalSpeed, comVx, comVy)
                    DamageTarget(self.source, self.target, self.damage, ATTACK_TYPE_NORMAL, MAGIC, "Cluster Rockets")
                end
            },
            arc = 0.2,
        }
        missile_template.__index = missile_template

        local function cluster_rocket(pt)
            local to_remove = {}

            for target in each(pt.ug) do
                if UnitAlive(target) == false or UnitDistance(target, pt.source) > 1500. or IsUnitAlly(target, Player(pt.pid - 1)) then
                    to_remove[#to_remove + 1] = target
                end
            end

            --clean helitargets
            for i = 1, #to_remove do
                GroupRemoveUnit(pt.ug, to_remove[i])
            end

            local x, y, z = GetUnitX(pt.source), GetUnitY(pt.source), GetUnitZ(pt.source)

            --single shot
            if SNIPERSTANCE.enabled[pt.pid] then
                local target = FirstOfGroup(pt.ug)

                if UnitAlive(Unit[Hero[pt.pid]].target) then
                    target = Unit[Hero[pt.pid]].target
                end

                local missile = setmetatable({}, missile_template)
                missile.x = x
                missile.y = y
                missile.z = z
                missile.visual = AddSpecialEffect("war3mapImported\\HighSpeedProjectile_ByEpsilon.mdx", x, y)
                BlzSetSpecialEffectScale(missile.visual, 1.1)
                missile.speed = 1800
                missile.source = Hero[pt.pid]
                missile.target = target
                missile.owner = Player(pt.pid - 1)
                missile.damage = pt.dmg * 2.5 * pt.boost

                ALICE_Create(missile)
            --multi shot
            else
                for enemy in each(pt.ug) do
                    local missile = setmetatable({}, missile_template)
                    missile.x = x
                    missile.y = y
                    missile.z = z
                    missile.visual = AddSpecialEffect("Abilities\\Spells\\Other\\TinkerRocket\\TinkerRocketMissile.mdl", x, y)
                    BlzSetSpecialEffectScale(missile.visual, 1.1)
                    missile.speed = 1400
                    missile.source = Hero[pt.pid]
                    missile.target = enemy
                    missile.owner = Player(pt.pid - 1)
                    missile.damage = pt.dmg * pt.boost

                    ALICE_Create(missile)
                end
            end
        end

        local function cooldown(pt)
            pt.rocket_cd = false
        end

        local function attack(pt)
            local x = GetUnitX(Hero[pt.pid]) + 60. * math.cos(bj_DEGTORAD * (pt.angle + GetUnitFacing(Hero[pt.pid])))
            local y = GetUnitY(Hero[pt.pid]) + 60. * math.sin(bj_DEGTORAD * (pt.angle + GetUnitFacing(Hero[pt.pid])))

            -- leash
            if UnitDistance(Hero[pt.pid], pt.source) > 700. then
                SetUnitPosition(pt.source, GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]))
            end

            -- follow
            if DistanceCoords(x, y, GetUnitX(pt.source), GetUnitY(pt.source)) > 75. then
                IssuePointOrder(pt.source, "move", x, y)
            end

            -- prioritize facing target hero is attacking
            local target = Unit[Hero[pt.pid]].target
            if target and UnitAlive(target) then
                SetUnitFacing(pt.source, bj_RADTODEG * atan(GetUnitY(target) - GetUnitY(pt.source), GetUnitX(target) - GetUnitX(pt.source)))
            end

            -- acquire helicopter targets near hero
            GroupEnumUnitsInRangeEx(pt.pid, pt.ug, GetUnitX(Hero[pt.pid]), GetUnitY(Hero[pt.pid]), 1200., Condition(FilterEnemyAwake))

            if BlzGroupGetSize(pt.ug) > 0 and not pt.rocket_cd then
                pt.rocket_cd = true
                TimerQueue:callDelayed(pt.cd, cooldown, pt)
                cluster_rocket(pt)
            end
        end

        local function periodic(pt, tag)
            SetTextTagPosUnit(tag, pt.source, -200.)
        end

        local function wander(pt)
            pt.angle = math.random(1, 3) * 120. - 60
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            local tag = CreateTextTag()
            pt.source = CreateUnit(Player(self.pid - 1), type[self.ablev], self.x + 75. * math.cos(self.angle), self.y + 75. * math.sin(self.angle), bj_RADTODEG * self.angle)
            SoundHandler("Units\\Human\\Gyrocopter\\GyrocopterWhat" .. (GetRandomInt(1,5)) .. ".flac", true, nil, pt.source)
            SetUnitFlyHeight(pt.source, 1100., 0.)
            SetUnitFlyHeight(pt.source, 300., 500.)
            UnitAddIndicator(pt.source, 255, 255, 255, 255)

            pt.boost = BOOST[self.pid]
            pt.dmg = self.dmg
            SetTextTagText(tag, RealToString(pt.boost * 100) .. "\x25", 0.024)
            SetTextTagColor(tag, 255, R2I(270 - pt.boost * 150), R2I(270 - pt.boost * 150), 255)
            pt.cd = self.cd * LBOOST[self.pid]
            pt.ug = CreateGroup()
            wander(pt)
            pt.timer:callPeriodically(FPS_32, nil, periodic, pt, tag)
            pt.timer:callPeriodically(0.25, nil, attack, pt)
            pt.timer:callPeriodically(6., nil, wander, pt)
            pt.timer:callDelayed(self.dur * LBOOST[self.pid], PlayerTimer.destroy, pt)
            pt.onRemove = function()
                SoundHandler("Units\\Human\\Gyrocopter\\GyrocopterPissed6.flac", true, nil, pt.source)
                IssuePointOrder(pt.source, "move", GetUnitX(Hero[pt.pid]) + 1000. * math.cos(bj_DEGTORAD * GetUnitFacing(Hero[pt.pid])), GetUnitY(Hero[pt.pid]) + 1000. * math.sin(bj_DEGTORAD * GetUnitFacing(Hero[pt.pid])))
                TimerQueue:callDelayed(2., RemoveUnit, pt.source)
                Fade(pt.source, 2., true)
                DestroyTextTag(tag)
            end
            pt.tag = thistype.id
        end

    end

    ---@class SINGLESHOT : Spell
    ---@field dmg function
    SINGLESHOT = Spell.define("A05D")
    do
        local thistype = SINGLESHOT
        thistype.values = {
            dmg = function(pid) return GetHeroAgi(Hero[pid], true) * 5. end,
        }

        function thistype:onCast()
            self.x = self.x + 80. * math.cos(GetUnitFacing(self.caster) * bj_DEGTORAD)
            self.y = self.y + 80. * math.sin(GetUnitFacing(self.caster) * bj_DEGTORAD)
            self.angle = atan(GetMouseY(self.pid) - self.y, GetMouseX(self.pid) - self.x) * bj_RADTODEG
            local newangle = (180. - RAbsBJ(RAbsBJ(self.angle - GetUnitFacing(self.caster)) - 180.)) * 0.5
            self.angle = bj_DEGTORAD * (self.angle + GetRandomReal(-(newangle), newangle))

            Dummy.create(self.x, self.y, FourCC('A05J'), 1, 1.):lightning(self.x + 1500. * math.cos(self.angle), self.y + 1500. * math.sin(self.angle))
            SoundHandler("war3mapImported\\xm1014-3.wav", false, Player(self.pid - 1))

            local ug = CreateGroup()

            for _ = 1, 30 do
                MakeGroupInRange(self.pid, ug, self.x, self.y, 150. * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    if SingleShotDebuff:has(self.caster, target) == false then
                        DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                    SingleShotDebuff:add(self.caster, target):duration(3.)
                end

                self.x = self.x + 50 * math.cos(self.angle)
                self.y = self.y + 50 * math.sin(self.angle)
            end

            DestroyGroup(ug)
        end
    end

    ---@class HANDGRENADE : Spell
    ---@field dmg function
    ---@field aoe number
    ---@field dmg2 function
    ---@field aoe2 number
    HANDGRENADE = Spell.define("A0J4")
    do
        local thistype = HANDGRENADE

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (Unit[Hero[pid]].damage) * (0.4 + 0.1 * ablev) end,
            aoe = 300,
            dmg2 = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (Unit[Hero[pid]].damage) * (0.9 + 0.1 * ablev) end,
            aoe2 = 400.,
        }

        local grenade_template = {
            interactions = {
                self = {
                    CAT_OrientProjectile,
                    CAT_MoveBallistic,
                    CAT_CheckTerrainCollision,
                    CAT_Decay
                }
            },
            identifier = "missile",
            speed = 800,
            collisionRadius = 20,
            onTerrainCollision = CAT_TerrainBounce,
            elasticity = 0.3,
            friction = 950,
            lifetime = 4.,
            onExpire = function(self)
                local ug = CreateGroup()

                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    StunUnit(self.pid, target, 3.)
                    DamageTarget(self.source, target, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                local sfx = AddSpecialEffect("war3mapImported\\Eto_Boom.mdx", self.x, self.y)
                BlzSetSpecialEffectScale(sfx, 1.2)
                DestroyEffect(sfx)
                DestroyGroup(ug)
            end,
        }
        grenade_template.__index = grenade_template

        local rocket_template = {
            selfInteractions = {
                CAT_MoveArced,
                CAT_Orient3D,
                CAT_CheckTerrainCollision,
            },
            identifier = "missile",
            collisionRadius = 10.,
            speed = 1500,
            destroy = function(self)
                local ug = CreateGroup()
                --explode
                DestroyEffect(AddSpecialEffect("war3mapImported\\NewMassiveEX.mdx", self.x, self.y))
                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    StunUnit(self.pid, target, 4.)
                    DamageTarget(self.source, target, self.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyEffect(self.visual)
                DestroyGroup(ug)
            end,
            arc = 0.2,
        }
        rocket_template.__index = rocket_template

        local function rocket(heli, self)
            if heli and heli.source then
                local missile = setmetatable({}, rocket_template)
                missile.x = GetUnitX(heli.source)
                missile.y = GetUnitY(heli.source)
                missile.z = GetUnitZ(heli.source)
                missile.visual = AddSpecialEffect("war3mapImported\\Rocket.mdx", missile.x, missile.y)
                BlzSetSpecialEffectScale(missile.visual, 1.2)
                missile.targetX = self.targetX
                missile.targetY = self.targetY
                missile.source = Hero[self.pid]
                missile.owner = Player(self.pid - 1)
                missile.dmg = self.dmg2 * heli.boost
                missile.aoe = self.aoe2
                missile.pid = self.pid

                SoundHandler("Units\\Human\\Gyrocopter\\GyrocopterPissed1.flac", true, nil, self.source)

                ALICE_Create(missile)
            end
        end

        function thistype:onCast()
            local heli = TimerList[self.pid]:get(ASSAULTHELICOPTER.id)

            if heli then
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Flare\\FlareCaster.mdl", self.x, self.y))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Flare\\FlareTarget.mdl", self.targetX, self.targetY))

                TimerQueue:callDelayed(2., rocket, heli, self)
            else
                SoundHandler("war3mapImported\\grenade pin.mp3", true, nil, self.caster)
                local missile = setmetatable({}, grenade_template)
                missile.visual = AddSpecialEffect("war3mapImported\\PotatoMasher.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.5)
                missile.x = self.x
                missile.y = self.y
                missile.z = GetUnitZ(self.caster)
                local vx, vy, vz = CAT_GetBallisticLaunchSpeedFromAngle(missile.x, missile.y, missile.z, self.targetX, self.targetY, GetTerrainZ(self.targetX, self.targetY), 70 * bj_DEGTORAD)
                missile.vx = vx * 0.85
                missile.vy = vy * 0.85
                missile.vz = vz * 0.85
                missile.source = self.caster
                missile.owner = Player(self.pid - 1)
                missile.damage = self.dmg * BOOST[self.pid]
                missile.pid = self.pid
                missile.aoe = self.aoe

                ALICE_Create(missile)
            end
        end
    end

    ---@class FLAMINGBETTY : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field dur number
    ---@field cd function
    ---@field charges integer[]
    FLAMINGBETTY = Spell.define("A06V")
    do
        local thistype = FLAMINGBETTY

        thistype.charges = __jarray(0)
        thistype.values = {
            aoe = 300.,
            dmg = function(pid) return 0.2 * (Unit[Hero[pid]].damage) end,
            dur = 15.,
            cd = function(pid) return 42. - 2 * GetUnitAbilityLevel(Hero[pid], thistype.id) end,
        }

        local function cooldown(pt)
            local MAX_CHARGES = 2

            thistype.charges[pt.pid] = IMinBJ(MAX_CHARGES, thistype.charges[pt.pid] + 1)

            if GetLocalPlayer() == Player(pt.pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNFlamingBetty" .. (thistype.charges[pt.pid]) .. ".blp")
            end

            if thistype.charges[pt.pid] >= MAX_CHARGES then
                pt:destroy()
            else
                BlzStartUnitAbilityCooldown(pt.source, thistype.id, 0.)
                pt.timer:callDelayed(thistype.cd(pt.pid), cooldown, pt)
            end
        end

        local function on_hit(source, target, amount)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local ug = CreateGroup()

            amount.value = 0
            MakeGroupInRange(pid, ug, GetUnitX(target), GetUnitY(target), thistype.aoe * LBOOST[pid], Condition(FilterEnemy))

            for enemy in each(ug) do
                DamageTarget(source, enemy, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local turret = CreateUnit(Player(self.pid - 1), FourCC("o003"), self.targetX, self.targetY, GetUnitFacing(self.caster))
            UnitApplyTimedLife(turret, FourCC('Bhwd'), self.dur * LBOOST[self.pid])
            EVENT_ON_HIT_MULTIPLIER:register_unit_action(turret, on_hit)
            Unit[turret].attackCount = 8
            SoundHandler("Units\\Creeps\\HeroTinkerRobot\\ClockwerkGoblinReady1.flac", true, nil, turret)
            DestroyEffect(AddSpecialEffect("UI\\Feedback\\TargetPreSelected\\TargetPreSelected.mdl", self.targetX, self.targetY))

            -- force heal?
            SetWidgetLife(turret, BlzGetUnitMaxHP(turret))

            thistype.charges[self.pid] = thistype.charges[self.pid] - 1

            if GetLocalPlayer() == Player(self.pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNFlamingBetty" .. (thistype.charges[self.pid]) .. ".blp")
            end

            --refresh charge timer
            local pt = TimerList[self.pid]:get(thistype.id, self.caster)
            if not pt then
                pt = TimerList[self.pid]:add()
                pt.source = self.caster
                pt.tag = thistype.id

                pt.timer:callDelayed(self.cd, cooldown, pt)
            end

            if thistype.charges[self.pid] <= 0 then
                BlzStartUnitAbilityCooldown(self.caster, thistype.id, TimerGetRemaining(pt.timer.timer))
            end
        end

        function thistype.onLearn(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            thistype.charges[pid] = 2
        end
    end
end, Debug and Debug.getLine())
