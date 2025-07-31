OnInit.final("SaviorSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local distance = MISSILE_DISTANCE

    ---@class LIGHTSEAL : Spell
    ---@field dur number
    ---@field aoe number
    LIGHTSEAL = Spell.define('A07C')
    do
        local thistype = LIGHTSEAL
        thistype.aoe = 450.
        thistype.values = {
            dur = 12.,
        }

        ---@type fun(pt: PlayerTimer)
        function thistype.onExpire(pt)
            pt:destroy()
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.dur = self.dur * LBOOST[self.pid]
            pt.x = self.targetX
            pt.y = self.targetY
            pt.source = self.caster
            pt.target = Dummy.create(pt.x, pt.y, 0, 0, pt.dur).unit
            pt.aoe = self.aoe
            pt.tag = self.id
            pt.ug = CreateGroup()

            BlzSetUnitSkin(pt.target, FourCC('h046'))
            UnitDisableAbility(pt.target, FourCC('Amov'), true)
            SetUnitScale(pt.target, 6.1, 6.1, 6.1)
            BlzSetUnitFacingEx(pt.target, 270)
            SetUnitVertexColor(pt.target, 255, 255, 200, 200)
            SetUnitAnimation(pt.target, "birth")
            SetUnitTimeScale(pt.target, 0.9)
            DelayAnimation(self.pid, pt.target, 1., 0, 1., false)

            pt.timer:callDelayed(pt.dur, thistype.onExpire, pt)
        end
    end

    ---@class DIVINEJUDGEMENT : Spell
    ---@field dmg function
    DIVINEJUDGEMENT = Spell.define('A038')
    do
        local thistype = DIVINEJUDGEMENT
        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.2 + 0.3 * ablev) * (GetHeroStr(Hero[pid], true) + Unit[Hero[pid]].damage) end,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight, CAT_Orient2D, distance
            },
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
            },
            identifier = "missile",
            visualZ = 25.,
            speed = 1300,
            collisionRadius = 90,
            friendlyFire = false,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = {
                other = function(self, enemy, cx, cy, perpSpeed, parSpeed, totalSpeed, comVx, comVy)
                    local pt = TimerList[self.pid]:get(LIGHTSEAL.id, self.source)

                    if pt and IsUnitInRangeXY(enemy, pt.x, pt.y, 450.) then
                        local b = LightSealBuff:add(self.source, self.source)
                        b:addStack((IsBoss(enemy) and 5) or 1)
                    end

                    DamageTarget(self.source, enemy, self.damage, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            },
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.source = self.caster
            missile.pid = self.pid
            missile.owner = Player(self.pid - 1)
            missile.x = self.x
            missile.y = self.y
            missile.dist = 1000
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.damage = self.dmg * BOOST[self.pid]
            missile.visual = AddSpecialEffect("war3mapImported\\Valiant Charge Holy.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)

            ALICE_Create(missile)
        end
    end

    ---@class SAVIORSGUIDANCE : Spell
    ---@field shield function
    ---@field dur function
    SAVIORSGUIDANCE = Spell.define('A0KU')
    do
        local thistype = SAVIORSGUIDANCE
        thistype.values = {
            shield = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroStr(Hero[pid], true) * (2.25 + .25 * ablev) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 9. + ablev end,
        }

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(LIGHTSEAL.id, self.caster)

            --light seal augment
            if pt then
                MakeGroupInRange(self.pid, pt.ug, pt.x, pt.y, pt.aoe, Condition(FilterAllyHero))

                if self.caster ~= self.target and UnitAlive(self.target) then
                    GroupAddUnit(pt.ug, self.target)
                end

                GroupAddUnit(pt.ug, self.caster)

                for target in each(pt.ug) do
                    shield.add(target, self.shield * BOOST[self.pid], self.dur)
                end
            --normal cast
            else
                if self.caster ~= self.target and self.target ~= nil then
                    shield.add(self.target, self.shield * BOOST[self.pid], self.dur)
                end

                shield.add(self.caster, self.shield * BOOST[self.pid], self.dur)
            end


        end
    end

    ---@class HOLYBASH : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field heal function
    ---@field count number[]
    HOLYBASH = Spell.define('A0GG')
    do
        local thistype = HOLYBASH
        thistype.stundur = 2.
        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev * (GetHeroStr(Hero[pid], true) + Unit[Hero[pid]].damage * .4) end,
            aoe = 600.,
            heal = function(pid) return 25 + 0.5 * GetHeroStr(Hero[pid], true) end,
        }
        thistype.count = __jarray(0)

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            thistype.count[pid] = thistype.count[pid] + 1
            if thistype.count[pid] > 10 then
                local dmg = thistype.values.dmg(pid) * BOOST[pid]
                local heal = thistype.values.heal(pid) * BOOST[pid]
                DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                thistype.count[pid] = 0

                local pt = TimerList[pid]:get(LIGHTSEAL.id, source)

                --light seal augment
                if pt then
                    MakeGroupInRange(pid, pt.ug, pt.x, pt.y, pt.aoe, Condition(FilterEnemy))

                    for u in each(pt.ug) do
                        if u ~= target then
                            StunUnit(pid, u, thistype.stundur)
                            DamageTarget(source, u, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                        end
                    end
                end

                StunUnit(pid, target, thistype.stundur)

                --aoe heal
                local ug = CreateGroup()
                MakeGroupInRange(pid, ug, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), thistype.aoe * LBOOST[pid], Condition(FilterAlly))

                for u in each(ug) do
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", u, "origin")) --change effect
                    HP(source, u, heal, thistype.tag)
                end

                DestroyGroup(ug)
            end
        end

        local function on_attack(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1

            if GetUnitAbilityLevel(source, thistype.id) > 0 and thistype.count[pid] == 9 then
                local targetX = GetUnitX(target)
                local targetY = GetUnitY(target)
                local pt = TimerList[pid]:get(LIGHTSEAL.id, source)
                local sfx

                if pt then
                    sfx = AddSpecialEffect("war3mapImported\\Judgement NoHive.mdx", pt.x, pt.y)
                    BlzSetSpecialEffectScale(sfx, 1.8)
                else
                    sfx = AddSpecialEffect("war3mapImported\\Judgement NoHive.mdx", targetX, targetY)
                    BlzSetSpecialEffectScale(sfx, 0.8)
                end

                thistype.count[pid] = 10
                BlzSetSpecialEffectTimeScale(sfx, 1.5)
                BlzSetSpecialEffectTime(sfx, 0.7)
                TimerQueue:callDelayed(1.5, DestroyEffect, sfx)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_HIT:register_unit_action(source, on_hit)
            EVENT_ON_ATTACK:register_unit_action(source, on_attack)
        end

    end

    ---@class THUNDERCLAP : Spell
    ---@field dmg function
    ---@field aoe function
    THUNDERCLAP = Spell.define("A0AT")
    do
        local thistype = THUNDERCLAP

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.25 * (ablev + 1) * (GetHeroStr(Hero[pid], true) + Unit[Hero[pid]].damage) end,
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (200. + 50 * ablev) end,
        }

        function thistype:onCast()
            local pt = TimerList[self.pid]:get(LIGHTSEAL.id, self.caster)
            local ug = CreateGroup()

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

            if pt then
                LightSealBuff:add(self.caster, self.caster)
                GroupEnumUnitsInRangeEx(self.pid, ug, pt.x, pt.y, 450., Condition(FilterEnemy))
            end

            for target in each(ug) do
                SaviorThunderClap:add(self.caster, target):duration(5.)
                if pt and IsUnitInRangeXY(target, pt.x, pt.y, 450.) then
                    LightSealBuff:get(self.caster, self.caster):addStack((IsBoss(target) and 5) or 1)
                end
                DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            Taunt(self.caster, 800.)

            DestroyGroup(ug)
        end
    end

    ---@class RIGHTEOUSMIGHT : Spell
    ---@field attack function
    ---@field armor function
    ---@field heal function
    ---@field dmg function
    ---@field dur function
    RIGHTEOUSMIGHT = Spell.define("A08R")
    do
        local thistype = RIGHTEOUSMIGHT

        thistype.values = {
            attack = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (UnitGetBonus(Hero[pid], BONUS_DAMAGE) + BlzGetUnitBaseDamage(Hero[pid], 0)) * (.2 + .2 * ablev) end,
            armor = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return BlzGetUnitArmor(Hero[pid]) * (.4 + (.2 * ablev)) end,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return BlzGetUnitMaxHP(Hero[pid]) * (0.10 + 0.05 * ablev) end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (ablev + 1) * 2. * GetHeroStr(Hero[pid],true) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (ablev + 1) * 5. end,
        }

        function thistype:onCast()
            local b = RighteousMightBuff:create(self.caster, self.caster)
            local ug = CreateGroup()
            local angle = 0. ---@type number 

            b.dmg = 0.2 + 0.2 * self.ablev
            b.armor = self.armor
            b = b:check(self.caster, self.caster)
            b:duration(self.dur * LBOOST[self.pid])

            HP(self.caster, self.caster, self.heal * LBOOST[self.pid], thistype.tag)

            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\HolyAwakening.mdx", self.caster, "origin"))

            local pt = TimerList[self.pid]:get(LIGHTSEAL.id, self.caster)
            if pt then
                LightSealBuff:add(self.caster, self.caster)
                GroupEnumUnitsInRangeEx(self.pid, ug, pt.x, pt.y, 450., Condition(FilterEnemy))
            end

            for i = 1, 24 do
                angle = 2 * bj_PI * i / 24.
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrect\\ResurrectCaster.mdl", self.x + 500 * math.cos(angle), self.y + 500 * math.sin(angle)))
            end

            MakeGroupInRange(self.pid, ug, self.x, self.y, 500 * LBOOST[self.pid], Condition(FilterEnemy))

            for target in each(ug) do
                DamageTarget(self.caster, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                if pt and IsUnitInRangeXY(target, pt.x, pt.y, 450.) then
                    LightSealBuff:get(self.caster, self.caster):addStack((IsBoss(target) and 5) or 1)
                end
            end

            DestroyGroup(ug)
        end
    end
end, Debug and Debug.getLine())
