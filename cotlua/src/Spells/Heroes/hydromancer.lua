OnInit.final("HydromancerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32
    local atan = math.atan
    local valid_pull_target = VALID_PULL_TARGET
    local valid_damage_target = VALID_DAMAGE_TARGET

    ---@class INFUSEDWATER : Spell
    INFUSEDWATER = Spell.define("A0DY")
    do
        local thistype = INFUSEDWATER

        function thistype:onCast()
            InfusedWaterBuff:add(self.caster, self.caster):duration(5)
        end
    end

    ---@class FROSTBLAST : Spell
    ---@field dmg function
    ---@field aoe number
    ---@field dur number
    FROSTBLAST = Spell.define("A0GI")
    do
        local thistype = FROSTBLAST

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 1. * ablev * GetHeroInt(Hero[pid], true) end,
            aoe = 250.,
            dur = 4.,
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
            onlyTarget = true,
            friendlyFire = false,
            speed = 1200.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                local ug = CreateGroup()
                MakeGroupInRange(self.pid, ug, GetUnitX(enemy), GetUnitY(enemy), FROSTBLAST.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                local b = InfusedWaterBuff:get(nil, self.source)
                if b then
                    b:dispel()
                    self.damage = self.damage * 2
                end

                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", GetUnitX(enemy), GetUnitY(enemy)))

                for target in each(ug) do
                    if enemy == target then
                        Freeze:add(self.source, enemy):duration(FROSTBLAST.dur * LBOOST[self.pid])
                        DamageTarget(self.source, target, self.damage * (GetUnitAbilityLevel(target, FourCC('B01G')) + 1.), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    else
                        Freeze:add(self.source, enemy):duration(FROSTBLAST.dur * 0.5 * LBOOST[self.pid])
                        DamageTarget(self.source, target, self.damage / (2. - (GetUnitAbilityLevel(target, FourCC('B01G')))), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                DestroyGroup(ug)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.z = GetUnitZ(self.caster) + 50.
            missile.visual = AddSpecialEffect("Abilities\\Spells\\Other\\FrostBolt\\FrostBoltMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            missile.source = self.caster
            missile.target = self.target
            missile.owner = Player(self.pid - 1)
            missile.damage = self.dmg * BOOST[self.pid]
            missile.collideZ = true
            missile.pid = self.pid

            ALICE_Create(missile)
        end
    end

    ---@class WHIRLPOOL : Spell
    ---@field dmg function
    ---@field aoe number
    ---@field dur number
    WHIRLPOOL = Spell.define("A03X")
    do
        local thistype = WHIRLPOOL
        thistype.preCast = TERRAIN_PRECAST

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.25 * ablev * GetHeroInt(Hero[pid], true) end,
            aoe = 330.,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 2. + 2. * ablev end,
        }

        local SWIRL_RADIUS  = 130    -- distance at which swirling starts
        local MAX_SWIRL_FORCE = 20   -- max tangential speed when right on top

        local function pull_force(target, self)
            local x, y = GetUnitX(target), GetUnitY(target)
            local dx, dy = self.targetX - x, self.targetY - y
            local dist  = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan(dy, dx)

            -- count up to 20 units
            self.count = math.min(self.count + 1, 20)

            -- radial pull strength
            local pull
            if dist > 80 then
                pull = 5000.0 / dist
            else
                pull = 2.0
            end

            -- compute pull vector
            local fx = pull * math.cos(angle)
            local fy = pull * math.sin(angle)

            if dist < SWIRL_RADIUS then
                local swirl_strength = MAX_SWIRL_FORCE * (1 - dist / SWIRL_RADIUS)
                local perp = angle + (math.pi * 0.5)
                fx = fx + swirl_strength * math.cos(perp)
                fy = fy + swirl_strength * math.sin(perp)
            end

            -- apply movement if walkable
            local nx, ny = x + fx, y + fy
            if IsTerrainWalkable(nx, ny) then
                SetUnitXBounded(target, nx)
                SetUnitYBounded(target, ny)
            end
        end

        local function pull(self)
            if self.dur > 0. then
                self.dur = self.dur - FPS_32
                self.count = 0
                ALICE_ForAllObjectsInRangeDo(pull_force, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], "nonhero", valid_pull_target, self)
                self.dur = self.dur - (self.count * FPS_32 * 0.05)
                TimerQueue:callDelayed(FPS_32, pull, self)
            else
                DestroyEffect(self.sfx)
                DestroyEffect(self.sfx2)
            end
        end

        local function do_damage(object, self)
            if self.dur > 0. then
                DamageTarget(self.caster, object, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                SoakedDebuff:add(self.caster, object):duration(5.)
            end
        end

        local function damage(self)
            if self.dur > 0. then
                ALICE_ForAllObjectsInRangeDo(do_damage, self.targetX, self.targetY, self.aoe * LBOOST[self.pid], "unit", valid_damage_target, self)
                TimerQueue:callDelayed(1., damage, self)
            end
        end

        function thistype:onCast()
            local b = InfusedWaterBuff:get(nil, self.caster)

            if b then
                b:dispel()
                self.dur = self.dur + 3
            end

            self.sfx = AddSpecialEffect("war3mapImported\\Whirlpool4.mdl", self.targetX, self.targetY)
            BlzSetSpecialEffectTimeScale(self.sfx, 1.3)
            BlzSetSpecialEffectScale(self.sfx, 0.6)
            BlzSetSpecialEffectZ(self.sfx, GetLocZ(self.targetX, self.targetY) + 50.)

            self.sfx2 = AddSpecialEffect("war3mapImported\\Whirlpool4.mdl", self.targetX, self.targetY)
            BlzSetSpecialEffectTimeScale(self.sfx2, 1.1)
            BlzSetSpecialEffectScale(self.sfx2, 0.35)
            BlzSetSpecialEffectZ(self.sfx2, GetLocZ(self.targetX, self.targetY) + 50.)
            BlzSetSpecialEffectAlpha(self.sfx2, 100)

            pull(self)
            TimerQueue:callDelayed(0.5, damage, self)
        end
    end

    ---@class TIDALWAVE : Spell
    ---@field range function
    TIDALWAVE = Spell.define("A077")
    do
        local thistype = TIDALWAVE

        thistype.values = {
            range = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 500. + 100. * ablev end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local Ax = pt.x + 250. * math.cos(pt.angle + bj_PI * 5. / 8.)
            local Bx = pt.x + 250. * math.cos(pt.angle + bj_PI * 3. / 8.)
            local Cx = pt.x + 250. * math.cos(pt.angle - bj_PI * 3. / 8.)
            local Dx = pt.x + 250. * math.cos(pt.angle - bj_PI * 5. / 8.)

            local Ay = pt.y + 250. * math.sin(pt.angle + bj_PI * 5. / 8.)
            local By = pt.y + 250. * math.sin(pt.angle + bj_PI * 3. / 8.)
            local Cy = pt.y + 250. * math.sin(pt.angle - bj_PI * 3. / 8.)
            local Dy = pt.y + 250. * math.sin(pt.angle - bj_PI * 5. / 8.)

            local AB = 0.
            local BC = 0.
            local CD = 0.
            local DA = 0.

            pt.dist = pt.dist - 20
            pt.time = pt.time + FPS_32

            if pt.time <= FPS_32 then
                SetUnitAnimation(pt.target, "stand")
            elseif pt.time >= 1. then
                SetUnitTimeScale(pt.target, 0.)
            end

            if pt.dist > 0. then
                local ug = CreateGroup()
                MakeGroupInRange(pt.pid, ug, pt.x, pt.y, 600., Condition(FilterEnemy))

                pt.x = pt.x + 20 * math.cos(pt.angle)
                pt.y = pt.y + 20 * math.sin(pt.angle)
                SetUnitXBounded(pt.target, pt.x)
                SetUnitYBounded(pt.target, pt.y)

                local x = 0.
                local y = 0.

                for target in each(ug) do
                    x = GetUnitX(target)
                    y = GetUnitY(target)

                    AB = (y - By) * (Ax - Bx) - (x - Bx) * (Ay - By)
                    BC = (y - Cy) * (Bx - Cx) - (x - Cx) * (By - Cy)
                    CD = (y - Dy) * (Cx - Dx) - (x - Dx) * (Cy - Dy)
                    DA = (y - Ay) * (Dx - Ax) - (x - Ax) * (Dy - Ay)

                    if (AB >= 0 and BC >= 0 and CD >= 0 and DA >= 0) or (AB <= 0 and BC <= 0 and CD <= 0 and DA <= 0) then
                        if IsUnitType(target, UNIT_TYPE_STRUCTURE) == false and GetUnitMoveSpeed(target) > 0 and IsTerrainWalkable(x, y) then
                            DestroyEffect(AddSpecialEffect("war3mapImported\\SlideWater.mdx", GetUnitX(target), GetUnitY(target)))
                            SetUnitXBounded(target, x + 17. * math.cos(pt.angle))
                            SetUnitYBounded(target, y + 17. * math.sin(pt.angle))
                        end

                        SoakedDebuff:add(Hero[pt.pid], target):duration(5.)
                        local b = TidalWaveDebuff:get(nil, target)

                        if not b then
                            b = TidalWaveDebuff:create(Hero[pt.pid], target)

                            if pt.infused then
                                b.percent = .20
                            end

                            b:check(Hero[pt.pid], target)

                            if IsUnitType(target, UNIT_TYPE_HERO) == true then
                                b:duration(5.)
                            else
                                b:duration(10.)
                            end
                        end
                    end
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(FPS_32, periodic, pt)
            else
                SetUnitTimeScale(pt.target, 2.)
                SetUnitAnimation(pt.target, "death")
                pt:destroy()
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.angle = self.angle
            pt.dist = self.range * LBOOST[self.pid]
            pt.target = Dummy.create(self.x, self.y, 0, 0).unit
            pt.x = self.x
            pt.y = self.y
            pt.infused = false

            local b = InfusedWaterBuff:get(nil, self.caster)
            if b then
                b:dispel()
                pt.infused = true
            end

            BlzSetUnitSkin(pt.target, FourCC('h04X'))
            SetUnitAnimation(pt.target, "birth")
            SetUnitScale(pt.target, 0.8, 0.8, 0.8)
            BlzSetUnitFacingEx(pt.target, pt.angle * bj_RADTODEG)

            pt.timer:callDelayed(FPS_32, periodic, pt)
        end
    end

    ---@class BLIZZARD : Spell
    ---@field aoe function
    ---@field dmg function
    ---@field dur function
    BLIZZARD = Spell.define("A08E")
    do
        local thistype = BLIZZARD

        thistype.values = {
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 175. + 25. * ablev end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.25 * ablev * GetHeroInt(Hero[pid], true) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev + 3 end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local pt = TimerList[pid]:get(BLIZZARD.id, source)

            if pt then
                local dmg = pt.dmg
                if pt.infused then
                    dmg = dmg * 1.3
                end
                DamageTarget(source, target, dmg * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, BLIZZARD.tag)
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.dur = self.dur * LBOOST[self.pid]

            local dummy = Dummy.create(self.x, self.y, FourCC('A02O'), 1, pt.dur + 3.)
            dummy.source = self.caster
            pt.source = dummy.unit
            pt.aoe = self.aoe * LBOOST[self.pid]
            pt.dmg = self.dmg
            pt.tag = thistype.id
            pt.infused = false

            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(pt.source, FourCC('A02O')), ABILITY_ILF_NUMBER_OF_WAVES, 0, pt.dur // 0.6)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(pt.source, FourCC('A02O')), ABILITY_RLF_AREA_OF_EFFECT, 0, pt.aoe)
            IncUnitAbilityLevel(pt.source, FourCC('A02O'))
            DecUnitAbilityLevel(pt.source, FourCC('A02O'))
            SetUnitOwner(pt.source, Player(self.pid - 1), true)

            local b = InfusedWaterBuff:get(nil, self.caster)
            if b then
                b:dispel()
                pt.infused = true
            end

            IssuePointOrder(pt.source, "blizzard", self.targetX, self.targetY)
            EVENT_DUMMY_ON_HIT:register_unit_action(pt.source, on_hit)

            pt.timer:callDelayed(pt.dur, PlayerTimer.destroy, pt)
        end
    end

    ---@class ICEBARRAGE : Spell
    ---@field times function
    ---@field dmg function
    ICEBARRAGE = Spell.define("A098")
    do
        local thistype = ICEBARRAGE

        thistype.values = {
            times = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 12. + 4. * ablev end,
            dmg = function(pid) return GetHeroInt(Hero[pid], true) * 0.5 end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.time = (pt.time + 0.01) * 1.1 --acceleration

            if pt.time < 1. then
                pt.curve:calcT(pt.time)
                SetUnitXBounded(pt.source, pt.curve.X)
                SetUnitYBounded(pt.source, pt.curve.Y)
                pt.curve:calcT(pt.time + 0.01)
                local angle = atan(pt.curve.Y - GetUnitY(pt.source), pt.curve.X - GetUnitX(pt.source))
                BlzSetUnitFacingEx(pt.source, bj_RADTODEG * angle)

                if pt.time < 0.28 then
                    SetUnitFlyHeight(pt.source, GetUnitFlyHeight(pt.source) + GetRandomReal(15., 20.), 0.)
                elseif pt.time > 0.35 then
                    SetUnitFlyHeight(pt.source, GetUnitFlyHeight(pt.source) - pt.time * 40, 0.)
                end

                pt.timer:callDelayed(FPS_32, periodic, pt)
            else
                SetUnitXBounded(pt.source, GetUnitX(pt.target))
                SetUnitYBounded(pt.source, GetUnitY(pt.target))
                SetUnitAnimation(pt.source, "death")
                if pt.infused then
                    Stun:add(Hero[pt.pid], pt.target):duration(0.25)
                end

                if SoakedDebuff:has(nil, pt.target) then
                    DamageTarget(Hero[pt.pid], pt.target, pt.dmg * 2. * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                else
                    DamageTarget(Hero[pt.pid], pt.target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
                pt:destroy()
            end
        end

        ---@type fun(pt: PlayerTimer)
        function thistype.onSpawn(pt)
            pt.time = pt.time + 1

            if pt.time <= pt.dur then
                local x = GetUnitX(pt.source)
                local y = GetUnitY(pt.source)
                local angle = atan(GetUnitY(pt.target) - y, GetUnitX(pt.target) - x) + bj_DEGTORAD * (180 + GetRandomInt(-60, 60))

                local pt2 = TimerList[pt.pid]:add()
                pt2.source = Dummy.create(x + 100. * math.cos(angle), y + 100. * math.sin(angle), 0, 0).unit
                pt2.target = pt.target
                pt2.dmg = thistype.dmg(pt.pid)
                pt2.infused = pt.infused

                BlzSetUnitSkin(pt2.source, FourCC('h071'))
                SetUnitScale(pt2.source, 0.6, 0.6, 0.6)
                SetUnitFlyHeight(pt2.source, 150.00, 0.00)

                pt2.curve = BezierCurve.create()
                --add bezier points
                pt2.curve:addPoint(x + 100. * math.cos(angle), y + 100. * math.sin(angle))
                pt2.curve:addPoint(x + 600. * math.cos(angle), y + 600. * math.sin(angle))
                pt2.curve:addPoint(GetUnitX(pt.target), GetUnitY(pt.target))

                pt.timer:callDelayed(0.05, thistype.onSpawn, pt)
                pt2.timer:callDelayed(FPS_32, periodic, pt2)
            else
                pt:destroy()
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.source = self.caster
            pt.target = self.target
            pt.dur = self.times * LBOOST[self.pid]
            pt.infused = false
            pt.time = 0

            local b = InfusedWaterBuff:get(nil, self.caster)
            if b then
                b:dispel()
                pt.infused = true
            end

            pt.timer:callDelayed(0.05, thistype.onSpawn, pt)
        end
    end
end, Debug and Debug.getLine())
