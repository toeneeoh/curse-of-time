OnInit.final("MarksmanSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan
    local active_helicopters = {} ---@type PlayerTimer[]

    local function destroy_lightning(lightning)
        DestroyLightning(lightning)
    end

    ---@class SNIPERSTANCE : Spell
    ---@field enabled boolean[]
    SNIPERSTANCE = Spell.define("A002")
    do
        local thistype = SNIPERSTANCE
        thistype.enabled = {}

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

            local enabled = thistype.enabled[self.pid]
            local u = Unit[self.caster]
            u.overmovespeed = (enabled and 100) or nil
            u.cc_percent = (enabled and u.cc_percent + 1.) or u.cc_percent - 1.
            u.cd_percent = (enabled and u.cd_percent + 1.) or u.cd_percent - 1.
            u.base_bat = (enabled and u.base_bat * 2.) or u.base_bat * 0.5
            u.range = (enabled and 1150) or 650

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
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
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
            TQ:callDelayed(1., CAT_UnitEnableFriction, self.caster, false)
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

        local function cooldown(pt)
            pt.rocket_cd = false
        end

        local function sniper_rocket(pt, target)
            local x, y, z = GetUnitX(pt.source), GetUnitY(pt.source), GetUnitZ(pt.source)

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

            return true
        end

        local function cluster_rocket(pt, target)
            local x, y, z = GetUnitX(pt.source), GetUnitY(pt.source), GetUnitZ(pt.source)

            local missile = setmetatable({}, missile_template)
            missile.x = x
            missile.y = y
            missile.z = z
            missile.visual = AddSpecialEffect("Abilities\\Spells\\Other\\TinkerRocket\\TinkerRocketMissile.mdl", x, y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            missile.speed = 1400
            missile.source = Hero[pt.pid]
            missile.target = target
            missile.owner = Player(pt.pid - 1)
            missile.damage = pt.dmg * pt.boost

            ALICE_Create(missile)

            return true
        end

        local function attack(pt)
            local source = pt.source
            local pid = pt.pid
            local hero_x = GetUnitX(Hero[pid])
            local hero_y = GetUnitY(Hero[pid])
            local x = hero_x + 60. * math.cos(bj_DEGTORAD * (pt.angle + GetUnitFacing(Hero[pid])))
            local y = hero_y + 60. * math.sin(bj_DEGTORAD * (pt.angle + GetUnitFacing(Hero[pid])))

            -- leash
            if UnitDistance(Hero[pid], source) > 700. then
                SetUnitPosition(source, hero_x, hero_y)
            end

            -- follow
            if DistanceCoords(x, y, GetUnitX(source), GetUnitY(source)) > 75. then
                IssuePointOrder(source, "move", x, y)
            end

            -- prioritize facing target hero is attacking
            local target = Unit[Hero[pid]].target
            if target and UnitAlive(target) then
                SetUnitFacing(source, bj_RADTODEG * atan(GetUnitY(target) - GetUnitY(source), GetUnitX(target) - GetUnitX(source)))
            end

            if not pt.rocket_cd then
                local launched = false
                MakeGroupInRange(pid, pt.ug, hero_x, hero_y, 1200., Condition(FilterEnemyAwake))

                if SNIPERSTANCE.enabled[pid] then
                    target = target or FirstOfGroup(pt.ug)
                    if target then
                        launched = sniper_rocket(pt, target)
                    end
                else
                    for enemy in each(pt.ug) do
                        launched = cluster_rocket(pt, enemy)
                    end
                end

                if launched then
                    pt.rocket_cd = true
                    TQ:callDelayed(pt.cd, cooldown, pt)
                end
            end
        end

        local function periodic(pt)
            SetTextTagPosUnit(pt.text_tag, pt.source, -200.)
        end

        local function wander(pt)
            pt.reference.angle = math.random(1, 3) * 120. - 60
        end

        local function on_expire(pt)
            local heli = active_helicopters[pt.pid]
            if heli and heli.source == pt.source then
                active_helicopters[pt.pid] = nil
            end

            TimerList[pt.pid]:stopAllTimers(thistype.id)

            SoundHandler("Units\\Human\\Gyrocopter\\GyrocopterPissed6.flac", true, nil, pt.source)
            IssuePointOrder(pt.source, "move", GetUnitX(Hero[pt.pid]) + 1000. * math.cos(bj_DEGTORAD * GetUnitFacing(Hero[pt.pid])), GetUnitY(Hero[pt.pid]) + 1000. * math.sin(bj_DEGTORAD * GetUnitFacing(Hero[pt.pid])))
            TQ:callDelayed(2., RemoveUnit, pt.source)
            Fade(pt.source, 2., true)
            DestroyTextTag(pt.text_tag)
        end

        function thistype:onCast()
            local tag = CreateTextTag()
            local heli = CreateUnit(Player(self.pid - 1), type[self.ablev], self.x + 75. * math.cos(self.angle), self.y + 75. * math.sin(self.angle), bj_RADTODEG * self.angle)
            local boost = BOOST[self.pid]
            SoundHandler("Units\\Human\\Gyrocopter\\GyrocopterWhat" .. (GetRandomInt(1,5)) .. ".flac", true, nil, heli)
            SetUnitFlyHeight(heli, 1100., 0.)
            SetUnitFlyHeight(heli, 300., 500.)
            UnitAddIndicator(heli, 255, 255, 255, 255)
            SetTextTagText(tag, RealToString(boost * 100) .. "%", 0.024)
            SetTextTagColor(tag, 255, R2I(270 - boost * 150), R2I(270 - boost * 150), 255)

            -- duration
            local pt = TimerList[self.pid]:add()
            pt.source = heli
            pt.text_tag = tag
            pt.onRemove = on_expire
            pt:after(self.dur * LBOOST[self.pid], nil)

            -- text tag loop
            pt = TimerList[self.pid]:add(thistype.id)
            pt.source = heli
            pt.text_tag = tag
            pt:startLoop(FPS_32, periodic)

            -- attack loop
            pt = TimerList[self.pid]:add(thistype.id)
            pt.boost = boost
            pt.dmg = self.dmg
            pt.cd = self.cd * LBOOST[self.pid]
            pt.ug = CreateGroup()
            pt.source = heli
            pt.angle = math.random(1, 3) * 120. - 60
            pt:startLoop(0.25, attack)
            active_helicopters[self.pid] = pt

            -- wander loop
            local pt2 = TimerList[self.pid]:add(thistype.id)
            pt2.reference = pt
            pt2.source = heli
            pt2:startLoop(6, wander)
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

            local end_x = self.x + 1500. * math.cos(self.angle)
            local end_y = self.y + 1500. * math.sin(self.angle)
            local lightning = AddLightningEx("BULL", true, self.x, self.y, GetTerrainZ(self.x, self.y) + 60., end_x, end_y, GetTerrainZ(end_x, end_y) + 60.)
            TQ:callDelayed(2., destroy_lightning, lightning)
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
            friction = 1200,
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
            if heli == active_helicopters[self.pid] and heli.source and UnitAlive(heli.source) then
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
            local heli = active_helicopters[self.pid]

            if heli then
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Flare\\FlareCaster.mdl", self.x, self.y))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Flare\\FlareTarget.mdl", self.targetX, self.targetY))

                TQ:callDelayed(2., rocket, heli, self)
            else
                SoundHandler("war3mapImported\\grenade pin.mp3", true, nil, self.caster)
                local missile = setmetatable({}, grenade_template)
                missile.visual = AddSpecialEffect("war3mapImported\\PotatoMasher.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.5)
                missile.x = self.x
                missile.y = self.y
                missile.z = GetUnitZ(self.caster)
                local vx, vy, vz = CAT_GetBallisticLaunchSpeedFromAngle(missile.x, missile.y, missile.z, self.targetX, self.targetY, GetTerrainZ(self.targetX, self.targetY), 65 * bj_DEGTORAD)
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

        local MAX_CHARGES = 2

        local function cooldown(pt)
            thistype.charges[pt.pid] = math.min(MAX_CHARGES, thistype.charges[pt.pid] + 1)

            if GetLocalPlayer() == Player(pt.pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNFlamingBetty" .. (thistype.charges[pt.pid]) .. ".blp")
            end

            if thistype.charges[pt.pid] < MAX_CHARGES then
                BlzStartUnitAbilityCooldown(pt.source, thistype.id, 0.)
                pt:after(thistype.cd(pt.pid), cooldown)
            else
                pt:destroy()
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
            SoundHandler("Units\\Creeps\\HeroTinkerRobot\\ClockwerkGoblinReady1.flac", true, nil, turret)
            DestroyEffect(AddSpecialEffect("UI\\Feedback\\TargetPreSelected\\TargetPreSelected.mdl", self.targetX, self.targetY))

            BlzSetUnitMaxHP(turret, 8)
            SetWidgetLife(turret, BlzGetUnitMaxHP(turret))
            Unit[turret].hit_based_health = true

            thistype.charges[self.pid] = thistype.charges[self.pid] - 1

            if GetLocalPlayer() == Player(self.pid - 1) then
                BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNFlamingBetty" .. (thistype.charges[self.pid]) .. ".blp")
            end

            -- refresh charge timer
            local pt = TimerList[self.pid]:get(thistype.id, self.caster)
            if not pt then
                pt = TimerList[self.pid]:add(thistype.id)
                pt.source = self.caster
                pt.autoDestroy = false

                pt:after(self.cd, cooldown)
            end

            if thistype.charges[self.pid] <= 0 then
                BlzStartUnitAbilityCooldown(self.caster, thistype.id, TQ:getRemaining(pt.cb))
            end
        end

        function thistype.onLearn(u, ablev, pid)
            if ablev == 1 then
                thistype.charges[pid] = MAX_CHARGES
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzSetAbilityIcon(thistype.id, "ReplaceableTextures\\CommandButtons\\BTNFlamingBetty" .. MAX_CHARGES .. ".blp")
                end
            end
        end
    end
end, Debug and Debug.getLine())
