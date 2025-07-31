OnInit.final("WarriorSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32
    local atan = math.atan

    ---@class PARRY : Spell
    ---@field dmg function
    PARRY = Spell.define("A0AI")
    do
        local thistype = PARRY

        thistype.values = {
            dmg = function(pid, u) return 1. * (Unit[u].damage) end,
        }

        local function on_order(source, target, id)
            if id == ORDER_ID_MANA_SHIELD and GetUnitAbilityLevel(source, thistype.id) > 0 then
                local pid = GetPlayerId(GetOwningPlayer(source)) + 1
                UnitDisableAbility(source, thistype.id, true)
                UnitDisableAbility(source, thistype.id, false)
                BlzStartUnitAbilityCooldown(source, thistype.id, 4.)
                LAST_CAST[pid] = thistype.id

                local pt = TimerList[pid]:get(ADAPTIVESTRIKE.id)
                UnitDisableAbility(source, ADAPTIVESTRIKE.id, false)

                if LIMITBREAK.flag[pid] & 0x10 > 0 and not pt then
                    ADAPTIVESTRIKE.effect(source, GetUnitX(source), GetUnitY(source))
                    UnitDisableAbility(source, ADAPTIVESTRIKE.id, true)
                    BlzUnitHideAbility(source, ADAPTIVESTRIKE.id, false)
                elseif pt then
                    BlzStartUnitAbilityCooldown(source, ADAPTIVESTRIKE.id, TimerGetRemaining(pt.timer.timer))
                end

                if LIMITBREAK.flag[pid] & 0x1 > 0 then
                    ParryBuff:add(source, source):duration(1.)
                else
                    ParryBuff:add(source, source):duration(0.5)
                end
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class SPINDASH : Spell
    ---@field dmg function
    SPINDASH = Spell.define("A0EE")
    do
        local thistype = SPINDASH
        thistype.preCast = function(pid, tpid, caster, target, x, y, targetX, targetY)
            local pt = TimerList[pid]:get('recast', caster)
            --recast
            if pt then
                targetX = pt.x
                targetY = pt.y
            end

            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if not IsTerrainWalkable(targetX, targetY) or r2 ~= r then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            end
        end

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.7 + 0.2 * ablev) * (Unit[Hero[pid]].damage) end,
        }

        ---@type fun(pt: PlayerTimer)
        local function recastExpire(pt)
            BlzStartUnitAbilityCooldown(pt.source, thistype.id, 3.)
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(pt.source, thistype.id), ABILITY_ILF_TARGET_TYPE, GetUnitAbilityLevel(pt.source, thistype.id) - 1, 2)

            pt:destroy()
        end

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.dur = pt.dur - pt.speed

            if pt.dur > 0. and IsUnitInRangeXY(pt.source, pt.x, pt.y, pt.dur + 50.) then
                local x = GetUnitX(pt.source)
                local y = GetUnitY(pt.source)
                SetUnitXBounded(pt.source, x + pt.speed * math.cos(pt.angle))
                SetUnitYBounded(pt.source, y + pt.speed * math.sin(pt.angle))

                local ug = CreateGroup()

                MakeGroupInRange(pt.pid, ug, x, y, 225. * LBOOST[pt.pid], Condition(FilterEnemy))

                for target in each(ug) do
                    if not IsUnitInGroup(target, pt.ug) then
                        GroupAddUnit(pt.ug, target)
                        if LIMITBREAK.flag[pt.pid] & 0x2 > 0 then
                            DamageTarget(pt.source, target, thistype.dmg(pt.pid) * 4. * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                            SpinDashDebuff:add(pt.source, target):duration(2.)
                        else
                            DamageTarget(pt.source, target, thistype.dmg(pt.pid) * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                        end
                    end
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(FPS_32, periodic, pt)
            else
                SetUnitPropWindow(pt.source, bj_DEGTORAD * 60.)
                SetUnitTimeScale(pt.source, 1.)
                AddUnitAnimationProperties(pt.source, "spin", false)
                SetUnitPathing(pt.source, true)
                --IssueImmediateOrderById(pt.source, ORDER_ID_STOP)
                pt:destroy()
            end
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(ADAPTIVESTRIKE.id)
            local sfx
            UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, false)

            if LIMITBREAK.flag[self.pid] & 0x10 > 0 and not pt then
                ADAPTIVESTRIKE.effect(self.caster, self.x, self.y)
                UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, true)
                BlzUnitHideAbility(self.caster, ADAPTIVESTRIKE.id, false)
            elseif pt then
                BlzStartUnitAbilityCooldown(self.caster, ADAPTIVESTRIKE.id, TimerGetRemaining(pt.timer.timer))
            end

            pt = TimerList[self.pid]:get('recast', self.caster)

            --recast
            if pt then
                self.targetX = pt.x
                self.targetY = pt.y
                self.angle = atan(pt.y - self.y, pt.x - self.x)
                SetUnitPropWindow(pt.source, bj_DEGTORAD * 60.)
                SetUnitTimeScale(pt.source, 1.)
                AddUnitAnimationProperties(pt.source, "spin", false)
                SetUnitPathing(pt.source, true)
                --IssueImmediateOrderById(pt.source, ORDER_ID_STOP)

                BlzStartUnitAbilityCooldown(pt.source, thistype.id, 3. + TimerGetRemaining(pt.timer.timer))
                BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(pt.source, thistype.id), ABILITY_ILF_TARGET_TYPE, GetUnitAbilityLevel(pt.source, thistype.id) - 1, 2)

                pt:destroy()

                --if still moving
                pt = TimerList[self.pid]:get(thistype.id, self.caster)
                if pt then
                    pt:destroy()
                end
            --first cast
            else
                pt = TimerList[self.pid]:add()
                pt.x = self.x
                pt.y = self.y
                pt.source = self.caster
                pt.tag = 'recast'

                BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(pt.source, thistype.id), ABILITY_ILF_TARGET_TYPE, GetUnitAbilityLevel(pt.source, thistype.id) - 1, 0)

                pt.timer:callDelayed(3., recastExpire, pt)
            end

            pt = TimerList[self.pid]:add()
            pt.x = self.targetX
            pt.y = self.targetY
            pt.angle = self.angle
            pt.dur = math.min(1000., DistanceCoords(self.x, self.y, pt.x, pt.y))
            pt.speed = 40.
            pt.source = self.caster
            pt.ug = CreateGroup()
            pt.tag = thistype.id

            SetUnitPropWindow(self.caster, 0)
            SetUnitTimeScale(self.caster, 2.)
            AddUnitAnimationProperties(self.caster, "spin", true)
            SetUnitPathing(self.caster, false)

            if LIMITBREAK.flag[self.pid] & 0x2 > 0 then
                pt.sfx = AddSpecialEffectTarget("war3mapImported\\Red White Tornado.mdx", self.caster, "origin")
                BlzPlaySpecialEffectWithTimeScale(pt.sfx, ANIM_TYPE_STAND, 2.)
            end

            pt.timer:callDelayed(FPS_32, periodic, pt)
        end
    end

    ---@class INTIMIDATINGSHOUT : Spell
    ---@field aoe number
    ---@field dur number
    INTIMIDATINGSHOUT = Spell.define("A00L")
    do
        local thistype = INTIMIDATINGSHOUT

        thistype.values = {
            aoe = 500.,
            dur = 3.,
        }

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(ADAPTIVESTRIKE.id)
            UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, false)

            if LIMITBREAK.flag[self.pid] & 0x10 > 0 and not pt then
                ADAPTIVESTRIKE.effect(self.caster, self.x, self.y)
                UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, true)
                BlzUnitHideAbility(self.caster, ADAPTIVESTRIKE.id, false)
            elseif pt then
                BlzStartUnitAbilityCooldown(self.caster, ADAPTIVESTRIKE.id, TimerGetRemaining(pt.timer.timer))
            end

            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            local effect

            if LIMITBREAK.flag[self.pid] & 0x4 > 0 then
                effect = AddSpecialEffectTarget("war3mapImported\\BattleCryCaster.mdx", self.caster, "origin")
                BlzSetSpecialEffectColor(effect, 255, 255, 0)
            else
                effect = AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlCaster.mdl", self.caster, "origin")
            end

            DestroyEffect(effect)

            for target in each(ug) do
                IntimidatingShoutDebuff:add(self.caster, target):duration(self.dur * LBOOST[self.pid])
            end

            DestroyGroup(ug)
        end
    end

    ---@class WINDSCAR : Spell
    ---@field dmg function
    WINDSCAR = Spell.define("A001")
    do
        local thistype = WINDSCAR

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.7 + 0.1 * ablev) * (Unit[Hero[pid]].damage) end,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            local x = GetUnitX(pt.target) ---@type number 
            local y = GetUnitY(pt.target) ---@type number 

            pt.dur = pt.dur + 0.05

            if (pt.dur > 1. and not pt.limitbreak) or (pt.dur > 5. and pt.limitbreak) then
                SetUnitAnimation(pt.target, "death")
                pt:destroy()
            else
                local ug = CreateGroup()

                MakeGroupInRange(pt.pid, ug, x, y, pt.aoe, Condition(FilterEnemy))

                for target in each(ug) do
                    if not IsUnitInGroup(target, pt.ug) then
                        GroupAddUnit(pt.ug, target)
                        TimerQueue:callDelayed(1., GroupRemoveUnit, pt.ug, target)
                        DamageTarget(Hero[pt.pid], target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                if pt.limitbreak then
                    pt.angle = pt.angle + bj_PI * 0.045
                    SetUnitXBounded(pt.target, GetUnitX(pt.source) + 150. * math.cos(pt.angle))
                    SetUnitYBounded(pt.target, GetUnitY(pt.source) + 150. * math.sin(pt.angle))
                    BlzSetUnitFacingEx(pt.target, bj_RADTODEG * (pt.angle + bj_PI * 0.5))
                else
                    pt.curve:calcT(pt.dur)
                    SetUnitXBounded(pt.target, pt.curve.X)
                    SetUnitYBounded(pt.target, pt.curve.Y)
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(FPS_32, periodic, pt)
            end
        end

        ---@type fun(pt: PlayerTimer)
        local function delay(pt)
            local angle      = 0. ---@type number 
            local pt2

            if LIMITBREAK.flag[pt.pid] & 0x8 > 0 then
                for i = 0, 3 do
                    pt2 = TimerList[pt.pid]:add()
                    pt2.ug = CreateGroup()
                    pt2.aoe = 120.
                    pt2.angle = 2. * bj_PI / 3. * i
                    pt2.source = pt.source
                    pt2.target = Dummy.create(GetUnitX(pt.source) + 150. * math.cos(pt2.angle), GetUnitY(pt.source) + 150. * math.sin(pt2.angle), 0, 0).unit
                    pt2.dmg = thistype.dmg(pt.pid)
                    pt2.limitbreak = true

                    BlzSetUnitSkin(pt2.target, FourCC('h044'))
                    SetUnitScale(pt2.target, 0.6, 0.6, 0.6)
                    UnitAddAbility(pt2.target, FourCC('Amrf'))
                    SetUnitFlyHeight(pt2.target, 30.00, 0.00)
                    BlzSetUnitFacingEx(pt2.target, bj_RADTODEG * (pt2.angle + bj_PI * 0.5))
                    SetUnitVertexColor(pt2.target, 255, 255, 0, 255)

                    pt2.timer:callDelayed(FPS_32, periodic, pt2)
                end
            else
                SoundHandler("Abilities\\Spells\\Orc\\Shockwave\\Shockwave.flac", true, nil, pt.source)

                angle = pt.angle

                for i = -1, 1 do
                    pt2 = TimerList[pt.pid]:add()
                    pt2.ug = CreateGroup()
                    pt2.aoe = 150.
                    pt2.angle = angle + i / 4. * bj_PI
                    pt2.target = Dummy.create(GetUnitX(pt.source) + 100. * math.cos(pt2.angle), GetUnitY(pt.source) + 100. * math.sin(pt2.angle), 0, 0).unit
                    pt2.x = GetUnitX(pt2.target)
                    pt2.y = GetUnitY(pt2.target)
                    pt2.speed = 700.
                    pt2.dmg = thistype.dmg(pt.pid)
                    pt2.curve = BezierCurve.create()
                    pt2.limitbreak = false
                    --add bezier points
                    pt2.curve:addPoint(pt2.x, pt2.y)
                    pt2.curve:addPoint(pt2.x + pt2.speed * 0.6 * math.cos(pt2.angle), pt2.y + pt2.speed * 0.6 * math.sin(pt2.angle))
                    pt2.curve:addPoint(pt2.x + pt2.speed * math.cos(angle), pt2.y + pt2.speed * math.sin(angle))

                    BlzSetUnitSkin(pt2.target, FourCC('h044'))
                    SetUnitScale(pt2.target, 1., 1., 1.)
                    UnitAddAbility(pt2.target, FourCC('Amrf'))
                    SetUnitFlyHeight(pt2.target, 10.00, 0.00)
                    BlzSetUnitFacingEx(pt2.target, bj_RADTODEG * pt2.angle)

                    pt2.timer:callDelayed(FPS_32, periodic, pt2)
                end

                SetUnitTimeScale(pt.source, 1.)
            end

            pt:destroy()
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(ADAPTIVESTRIKE.id)
            UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, false)

            if LIMITBREAK.flag[self.pid] & 0x10 > 0 and not pt then
                ADAPTIVESTRIKE.effect(self.caster, self.x, self.y)
                UnitDisableAbility(self.caster, ADAPTIVESTRIKE.id, true)
                BlzUnitHideAbility(self.caster, ADAPTIVESTRIKE.id, false)
            elseif pt then
                BlzStartUnitAbilityCooldown(self.caster, ADAPTIVESTRIKE.id, TimerGetRemaining(pt.timer.timer))
            end

            TimerQueue:callDelayed(1., DestroyEffect, AddSpecialEffectTarget("war3mapImported\\Sweep_Wind_Medium.mdx", self.caster, "Weapon"))

            pt = TimerList[self.pid]:add()
            pt.source = self.caster

            if LIMITBREAK.flag[self.pid] & 0x8 > 0 then
                BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(Hero[self.pid], WINDSCAR.id), ABILITY_ILF_TARGET_TYPE, self.ablev - 1, 0)

                pt.timer:callDelayed(0., delay, pt)
                SetUnitAnimation(self.caster, "stand")
            else
                SetUnitAnimation(self.caster, "attack slam")
                SetUnitTimeScale(self.caster, 1.5)
                pt.angle = self.angle
                pt.timer:callDelayed(0.4, delay, pt)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            if LIMITBREAK.flag[pid] & 0x8 > 0 then
                BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(source, thistype.id), ABILITY_ILF_TARGET_TYPE, ablev - 1, 0)
            end
        end
    end

    ---@class ADAPTIVESTRIKE : Spell
    ---@field spindmg function
    ---@field spinaoe number
    ---@field spinheal function
    ---@field knockaoe number
    ---@field knockdur number
    ---@field shoutaoe number
    ---@field shoutdur number
    ---@field tornadodmg function
    ---@field tornadodur number
    ---@field effect function
    ADAPTIVESTRIKE = Spell.define("A0AH")
    do
        local thistype = ADAPTIVESTRIKE

        thistype.values = {
            spindmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (1. + 0.2 * ablev) * (Unit[Hero[pid]].damage) end,
            spinaoe = 400.,
            spinheal = function(pid) return 10. * Unit[Hero[pid]].regen end,

            knockaoe = 300.,
            knockdur = 1.5,
            shoutaoe = 900.,
            shoutdur = 4.,

            tornadodmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.35 + 0.05 * ablev) * (Unit[Hero[pid]].damage) end,
            tornadodur = 3.,
        }

        ---@type fun(pt: PlayerTimer)
        local function tornado(pt)
            pt.time = pt.time + 0.5

            if pt.time >= pt.dur then
                IssueImmediateOrderById(pt.target, ORDER_ID_STOP)
                SetUnitAnimation(pt.target, "death")
                pt:destroy()
            else
                local x = GetUnitX(pt.target)
                local y = GetUnitY(pt.target)

                IssuePointOrder(pt.target, "move", x + 75. * math.cos(pt.angle), y + 75. * math.sin(pt.angle))

                if ModuloReal(pt.time + 0.5, 1.) == 0. then
                    local ug = CreateGroup()
                    MakeGroupInRange(pt.pid, ug, x, y, 200., Condition(FilterEnemy))

                    for target in each(ug) do
                        DamageTarget(Hero[pt.pid], target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end

                    DestroyGroup(ug)
                end

                pt.timer:callDelayed(0.5, tornado, pt)
            end
        end

        ---@type fun(caster: unit, x: number, y: number)
        function thistype.effect(caster, x, y)
            local pid = GetPlayerId(GetOwningPlayer(caster)) + 1
            local pt
            local ug = CreateGroup()

            if LAST_CAST[pid] == PARRY.id then --spin heal
                SetUnitAnimation(caster, "spell")
                MakeGroupInRange(pid, ug, x, y, thistype.spinaoe * LBOOST[pid], Condition(FilterEnemy))

                local dummy = Dummy.create(x, y, 0, 0, 1.).unit
                BlzSetUnitSkin(dummy, FourCC('h074'))
                SetUnitTimeScale(dummy, 1.)
                SetUnitScale(dummy, 1.25, 1.25, 1.25)
                SetUnitAnimationByIndex(dummy, 0)
                SetUnitFlyHeight(dummy, 100., 0)
                BlzSetUnitFacingEx(dummy, GetUnitFacing(caster))

                dummy = Dummy.create(x, y, 0, 0, 1.).unit
                BlzSetUnitSkin(dummy, FourCC('h074'))
                SetUnitTimeScale(dummy, 1.)
                SetUnitScale(dummy, 1.25, 1.25, 1.25)
                SetUnitAnimationByIndex(dummy, 0)
                SetUnitFlyHeight(dummy, 100., 0)
                BlzSetUnitFacingEx(dummy, GetUnitFacing(caster) + 180.)

                for target in each(ug) do
                    DamageTarget(caster, target, thistype.spindmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                HP(caster, caster, thistype.spinheal(pid) * BOOST[pid], thistype.tag)
            elseif LAST_CAST[pid] == SPINDASH.id then --knock up
                SetUnitAnimationByIndex(caster, 4)
                DelayAnimation(pid, caster, 0.6, 0, 1., false)
                MakeGroupInRange(pid, ug, x, y, thistype.knockaoe * LBOOST[pid], Condition(FilterEnemy))

                for target in each(ug) do
                    KnockUp:add(caster, target):duration(thistype.knockdur * LBOOST[pid])
                end

                local sfx = AddSpecialEffect("war3mapImported\\DustWindFaster3.mdx", x - 110., y)
                BlzSetSpecialEffectPitch(sfx, bj_PI * 0.5)

                SoundHandler("Abilities\\Spells\\NightElf\\Cyclone\\CycloneBirth1.flac", true, nil, caster)

                DestroyEffect(sfx)
            elseif LAST_CAST[pid] == INTIMIDATINGSHOUT.id then --ally attack damage buff
                MakeGroupInRange(pid, ug, x, y, thistype.shoutaoe * LBOOST[pid], Condition(FilterAlly))

                for target in each(ug) do
                    IntimidatingShoutBuff:add(caster, target):duration(thistype.shoutdur * LBOOST[pid])
                end

                DestroyEffect(AddSpecialEffectTarget("war3mapImported\\BattleCryCaster.mdx", caster, "origin"))
            elseif LAST_CAST[pid] == WINDSCAR.id then --5 tornadoes
                for i = 0, 4 do
                    pt = TimerList[pid]:add()
                    pt.angle = bj_PI * 0.4 * i
                    pt.target = Dummy.create(x + 75. * math.cos(pt.angle), y + 75 * math.sin(pt.angle), 0, 0).unit
                    pt.dmg = thistype.tornadodmg(pid)
                    pt.dur = thistype.tornadodur * LBOOST[pid]

                    SetUnitPathing(pt.target, false)
                    BlzSetUnitSkin(pt.target, FourCC('n001'))
                    SetUnitMoveSpeed(pt.target, 100.)
                    SetUnitScale(pt.target, 0.5, 0.5, 0.5)
                    UnitAddAbility(pt.target, FourCC('Amrf'))
                    IssuePointOrder(pt.target, "move", x + 225. * math.cos(pt.angle), y + 225. * math.sin(pt.angle))

                    pt.timer:callDelayed(0.5, tornado, pt)
                end
            end

            UnitDisableAbility(caster, thistype.id, true)
            BlzUnitHideAbility(caster, thistype.id, false)

            --adaptive strike cooldown reset
            local rand = math.random() ---@type number

            --empowered adaptive strike 50 percent
            if LIMITBREAK.flag[pid] & 0x10 > 0 then
                rand = rand * 1.5
            end

            if rand < 0.75 then
                pt = TimerList[pid]:add()
                pt.tag = thistype.id
                pt.timer:callDelayed(4., PlayerTimer.destroy, pt)
            end
            DestroyGroup(ug)
        end

        function thistype:onCast()
            thistype.effect(self.caster, self.x, self.y)
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                UnitDisableAbility(source, thistype.id, true)
                BlzUnitHideAbility(source, thistype.id, false)
            end
        end
    end

    ---@class LIMITBREAK : Spell
    ---@field flag integer[]
    ---@field max integer[]
    ---@field points integer[]
    LIMITBREAK = Spell.define("A02R")
    do
        local thistype = LIMITBREAK
        thistype.flag = __jarray(0)
        thistype.max = __jarray(0)
        thistype.points = __jarray(0)

        function thistype:onCast()
            if GetLocalPlayer() == Player(self.pid - 1) then
                if BlzFrameIsVisible(LimitBreakBackdrop) then
                    BlzFrameSetVisible(LimitBreakBackdrop, false)
                else
                    BlzFrameSetVisible(LimitBreakBackdrop, true)
                end
            end
        end

        -- upgrade UI
        LimitBreakBackdrop = BlzCreateFrame("QuestButtonDisabledBackdropTemplate", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(LimitBreakBackdrop, FRAMEPOINT_TOPLEFT, 0.61 - 0.0434, 0.212)
        BlzFrameSetAbsPoint(LimitBreakBackdrop, FRAMEPOINT_BOTTOMRIGHT, 0.795, 0.158)

        local buttons = {
            SimpleButton.create(LimitBreakBackdrop, "ReplaceableTextures\\CommandButtons\\BTNParryLimitBreak.blp", 0.036, 0.036, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.01, -0.008, nil, "|cffffcc00Parry|r|n|nDamage is doubled and immunity window is extended to |cffffcc001|r second.", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
            SimpleButton.create(LimitBreakBackdrop, "ReplaceableTextures\\CommandButtons\\BTNSpinDashLimitBreak.blp", 0.036, 0.036, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.052, -0.008, nil, "|cffffcc00Spin Dash|r|n|nDamage is quadrupled and enemies struck have their attack speed slowed by |cffffcc0025\x25|r for |cffffcc002|r seconds.", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
            SimpleButton.create(LimitBreakBackdrop, "ReplaceableTextures\\CommandButtons\\BTNIntimidatingShoutLimitBreak.blp", 0.036, 0.036, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.094, -0.008, nil, "|cffffcc00Intimidating Shout|r|n|nAlso reduces the spell damage of enemies by |cffffcc0040\x25|r.", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
            SimpleButton.create(LimitBreakBackdrop, "ReplaceableTextures\\CommandButtons\\BTNWindScarLimitBreak.blp", 0.036, 0.036, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.136, -0.008, nil, "|cffffcc00Wind Scar|r|n|nWind projectiles instead orbit around you for |cffffcc003|r seconds.", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
            SimpleButton.create(LimitBreakBackdrop, "ReplaceableTextures\\CommandButtons\\BTNAdaptiveStrikeLimitBreak.blp", 0.036, 0.036, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.178, -0.008, nil, "|cffffcc00Adaptive Strike|r|n|nPassive cooldown reset chance increased to |cffffcc0050\x25|r.|nNow automatically casts after using a skill when available.", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        }

        local function on_cleanup(pid)
            thistype.flag[pid] = 0
            thistype.max[pid] = 0
            thistype.points[pid] = 0
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(LimitBreakBackdrop, false)
                BlzSetAbilityIcon(PARRY.id, "ReplaceableTextures\\CommandButtons\\BTNReflex.blp")
                BlzSetAbilityIcon(SPINDASH.id, "ReplaceableTextures\\CommandButtons\\BTNComed Fall.blp")
                BlzSetAbilityIcon(INTIMIDATINGSHOUT.id, "ReplaceableTextures\\CommandButtons\\BTNBattleShout.blp")
                BlzSetAbilityIcon(WINDSCAR.id, "ReplaceableTextures\\CommandButtons\\BTNimpaledflameswordfinal.blp")
            end
        end

        function thistype.onLearn(source, ablev, pid)
            if thistype.max[pid] < 2 then
                thistype.points[pid] = thistype.points[pid] + 1
                if GetLocalPlayer() == GetOwningPlayer(source) then
                    for i = 1, #buttons do
                        buttons[i]:enable(true)
                    end
                end
            end
            if GetLocalPlayer() == GetOwningPlayer(source) then
                BlzFrameSetVisible(LimitBreakBackdrop, true)
            end

            EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
        end

        local skill_enum = {
            PARRY.id,
            SPINDASH.id,
            INTIMIDATINGSHOUT.id,
            WINDSCAR.id,
            ADAPTIVESTRIKE.id,
        }

        local function on_click()
            local f = BlzGetTriggerFrame()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
            local index = 1
            for i = 1, #buttons do
                if f == buttons[i].frame then
                    index = i
                    break
                end
            end

            if GetLocalPlayer() == GetTriggerPlayer() then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
            end

            if thistype.flag[pid] & 2 ^ (tonumber(index) - 1) == 0 and thistype.points[pid] > 0 then
                thistype.flag[pid] = thistype.flag[pid] | 2 ^ (tonumber(index) - 1)
                thistype.points[pid] = thistype.points[pid] - 1
                thistype.max[pid] = thistype.max[pid] + 1

                if GetLocalPlayer() == GetTriggerPlayer() then
                    if thistype.points[pid] <= 0 then
                        for i = 1, #buttons do
                            buttons[i]:enable(false)
                        end
                    end
                    BlzSetAbilityIcon(skill_enum[index], buttons[index].texture)
                end

                if skill_enum[index] == WINDSCAR.id then
                    local a = BlzGetUnitAbility(Hero[pid], skill_enum[index])
                    BlzSetAbilityIntegerLevelField(a, ABILITY_ILF_TARGET_TYPE, 0, 0)
                    BlzSetAbilityIntegerLevelField(a, ABILITY_ILF_TARGET_TYPE, 1, 0)
                    BlzSetAbilityIntegerLevelField(a, ABILITY_ILF_TARGET_TYPE, 2, 0)
                    BlzSetAbilityIntegerLevelField(a, ABILITY_ILF_TARGET_TYPE, 3, 0)
                    BlzSetAbilityIntegerLevelField(a, ABILITY_ILF_TARGET_TYPE, 4, 0)
                end
            end

            return false
        end

        for i = 1, #buttons do
            buttons[i]:onClick(on_click)
        end

        BlzFrameSetVisible(LimitBreakBackdrop, false)
    end
end, Debug and Debug.getLine())
