OnInit.final("RoyalGuardianSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local FPS_32 = FPS_32

    ---@class STEEDCHARGE : Spell
    ---@field charge function
    ---@field dur number
    STEEDCHARGE = Spell.define("A06B")
    do
        local thistype = STEEDCHARGE
        thistype.preCast = DASH_PRECAST
        thistype.values = {
            dur = 10.,
        }

        ---@type fun(pid: integer, angle: number, x: number, y: number)
        local function charge(pid, angle, x, y)
            local speed = Unit[Hero[pid]].movespeed * 0.045

            SetUnitPathing(Hero[pid], false)
            SetUnitPropWindow(Hero[pid], 0)

            if not UnitAlive(Hero[pid]) or IsUnitLoaded(Hero[pid]) or IsUnitInRangeXY(Hero[pid], x, y, speed + 5.) or IsUnitInRangeXY(Hero[pid], x, y, 1000.) == false then
                SetUnitPropWindow(Hero[pid], bj_DEGTORAD * 60.)
                SetUnitPathing(Hero[pid], true)
                SetUnitAnimationByIndex(Hero[pid], 1)
            else
                local ug = CreateGroup()

                BlzSetUnitFacingEx(Hero[pid], bj_RADTODEG * angle)
                SetUnitXBounded(Hero[pid], GetUnitX(Hero[pid]) + speed * math.cos(angle))
                SetUnitYBounded(Hero[pid], GetUnitY(Hero[pid]) + speed * math.sin(angle))
                SetUnitAnimationByIndex(Hero[pid], 0)

                MakeGroupInRange(pid, ug, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), 150., Condition(FilterEnemy))

                for target in each(ug) do
                    if SteedChargeStun:has(Hero[pid], target) == false then
                        Stun:add(Hero[pid], target):duration(1.)
                        SteedChargeStun:add(Hero[pid], target):duration(2.)
                        DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Undead\\ImpaleTargetDust\\ImpaleTargetDust.mdl", target, "origin"))
                    end
                end

                TimerQueue:callDelayed(FPS_32, charge, pid, angle, x, y)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            SoundHandler("Units\\Human\\Knight\\KnightYesAttack3.flac", true, nil, self.caster)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Polymorph\\PolyMorphDoneGround.mdl", self.x, self.y))

            BlzUnitHideAbility(self.caster, FourCC('A06K'), false)
            IssueImmediateOrderById(self.caster, 852180) --avatar
            BlzUnitHideAbility(self.caster, FourCC('A06K'), true)
            BlzStartUnitAbilityCooldown(self.caster, thistype.id, 30.)
            SteedChargeBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])

            TimerQueue:callDelayed(0.05, charge, self.pid, self.angle, self.targetX, self.targetY)
        end

        function thistype.onSetup(u)
            BlzUnitHideAbility(u, FourCC('A06K'), true)
        end
    end

    ---@class SHIELDSLAM : Spell
    ---@field dmg function
    SHIELDSLAM = Spell.define("A0HT")
    do
        local thistype = SHIELDSLAM

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return ablev * (GetHeroStr(Hero[pid], true) + 6. * BlzGetUnitArmor(Hero[pid])) end,
        }

        function thistype:onCast()
            local dmg = self.dmg * BOOST[self.pid] ---@type number 

            StunUnit(self.pid, self.target, 3.)
            DamageTarget(self.caster, self.target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)

            local sfx = AddSpecialEffect("war3mapImported\\DetroitSmash_Effect_CasterArt.mdx", self.x, self.y)
            BlzSetSpecialEffectYaw(sfx, bj_DEGTORAD * GetUnitFacing(self.caster))
            DestroyEffect(sfx)

            if ShieldCount[self.pid] > 0 then
                local ug = CreateGroup()
                MakeGroupInRange(self.pid, ug, GetUnitX(self.target), GetUnitY(self.target), 300 * LBOOST[self.pid], Condition(FilterEnemy))
                GroupRemoveUnit(ug, self.target)

                for target in each(ug) do
                    DamageTarget(self.caster, target, dmg * .5, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    StunUnit(self.pid, target, 1.5)
                end

                DestroyGroup(ug)
            end
        end
    end

    ---@class ROYALPLATE : Spell
    ---@field armor function
    ---@field dur number
    ROYALPLATE = Spell.define("A0EG")
    do
        local thistype = ROYALPLATE

        thistype.values = {
            armor = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.006 * Pow(ablev, 5.) + 10. * Pow(ablev, 2.) + 25. * ablev end,
            dur = 15.,
        }

        function thistype:onCast()
            RoyalPlateBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
        end
    end

    ---@class PROVOKE : Spell
    ---@field heal function
    ---@field aoe function
    ---@field dur number
    PROVOKE = Spell.define("A04Y")
    do
        local thistype = PROVOKE

        thistype.values = {
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 450. + 50. * ablev end,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (BlzGetUnitMaxHP(Hero[pid]) - GetWidgetLife(Hero[pid])) * (0.2 + 0.01 * ablev) end,
            dur = 10.,
        }

        function thistype:onCast()
            local ug = CreateGroup()

            HP(self.caster, self.caster, self.heal * BOOST[self.pid], thistype.tag)
            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Taunt\\TauntCaster.mdl", self.caster, "origin"))

            for target in each(ug) do
                ProvokeDebuff:add(self.caster, target):duration(self.dur * LBOOST[self.pid])
            end

            Taunt(self.caster, 800.)

            DestroyGroup(ug)
        end
    end

    ---@class FIGHTME : Spell
    ---@field dur function
    FIGHTME = Spell.define("A09E")
    do
        local thistype = FIGHTME

        thistype.values = {
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (4. + ablev) end,
        }

        function thistype:onCast()
            FightMeCasterBuff:add(self.caster, self.caster):duration(self.dur * LBOOST[self.pid])
        end
    end

    ---@class PROTECTOR : Spell
    PROTECTOR = Spell.define("A0HS")
    do
        local thistype = PROTECTOR

        local function periodic(u, pid, ug)
            if Profile[pid].playing then
                MakeGroupInRange(pid, ug, x, y, 900. * LBOOST[pid], Condition(FilterAlly))

                for target in each(ug) do
                    ProtectedBuff:add(u, target):duration(2.)
                end

                TimerQueue:callDelayed(1., periodic, pid, ug)
            else
                DestroyGroup(ug)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            local ug = CreateGroup()

            TimerQueue:callDelayed(1., periodic, source, pid, ug)
        end
    end
end, Debug and Debug.getLine())
