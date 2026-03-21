OnInit.final("RoyalGuardianSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local valid_target = VALID_DAMAGE_TARGET

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

        local function knockback(object, self)
            if not self.g[object] then
                self.g[object] = true

                Stun:add(self.caster, object):duration(1.)
                DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Undead\\ImpaleTargetDust\\ImpaleTargetDust.mdl", object, "origin"))

                -- valid pull target
                if IsUnitType(object, UNIT_TYPE_HERO) == false and GetUnitMoveSpeed(object) > 0 then
                    local caster = self.caster
                    local cx = GetUnitX(caster)
                    local cy = GetUnitY(caster)
                    local ox = GetUnitX(object)
                    local oy = GetUnitY(object)

                    local facing = GetUnitFacing(caster) * bj_DEGTORAD
                    local fx = math.cos(facing)
                    local fy = math.sin(facing)

                    local dx = ox - cx
                    local dy = oy - cy

                    -- 2d cross product: F x E
                    local cross = fx * dy - fy * dx

                    local angle
                    if cross >= 0 then
                        -- enemy is to the "left" of facing, knock them left
                        angle = facing + bj_PI * 0.5
                    else
                        -- enemy is to the "right", knock them right
                        angle = facing - bj_PI * 0.5
                    end

                    CAT_Knockback(object, 400 * math.cos(angle), 400 * math.sin(angle), 0)
                    CAT_UnitEnableFriction(object, true)
                    TimerQueue:callDelayed(1., CAT_UnitEnableFriction, object, false)
                end
            end
        end

        local function charge(self)
            local speed = Unit[self.caster].movespeed * 0.045

            SetUnitPathing(self.caster, false)
            SetUnitPropWindow(self.caster, 0)

            if not UnitAlive(self.caster) or IsUnitLoaded(self.caster) or IsUnitInRangeXY(self.caster, self.x, self.y, speed + 5.) or IsUnitInRangeXY(self.caster, self.x, self.y, 1000.) == false then
                SetUnitPropWindow(self.caster, bj_DEGTORAD * 60.)
                SetUnitPathing(self.caster, true)
                SetUnitAnimationByIndex(self.caster, 1)
            else
                local x = GetUnitX(self.caster)
                local y = GetUnitY(self.caster)
                BlzSetUnitFacingEx(self.caster, bj_RADTODEG * self.angle)
                SetUnitXBounded(self.caster, x + speed * math.cos(self.angle))
                SetUnitYBounded(self.caster, y + speed * math.sin(self.angle))
                SetUnitAnimationByIndex(self.caster, 0)

                ALICE_ForAllObjectsInRangeDo(knockback, x, y, 150., "unit", valid_target, self)

                TQ:callDelayed(FPS_32, charge, self)
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
            self.g = {}
            self.x = self.targetX
            self.y = self.targetY

            TQ:callDelayed(0.05, charge, self)
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

            if Unit[self.caster].shield_count > 0 then
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

        local function buff(object, source, ablev)
            ProtectedBuff:add(source, object, ablev):duration(2.)
        end

        local function valid_ally(object, source)
            return IsUnitAlly(object, GetOwningPlayer(source))
        end

        local function periodic(pt)
            local source = pt.source
            local x, y = GetUnitX(source), GetUnitY(source)
            ALICE_ForAllObjectsInRangeDo(buff, x, y, 900. * LBOOST[pt.pid], "unit", valid_ally, pt.source, pt.ablev)

            return true
        end

        function thistype.onLearn(source, ablev, pid)
            TimerList[pid]:stopAllTimers(thistype.id)
            local pt = TimerList[pid]:add(thistype.id)
            pt.source = source
            pt.ablev = ablev

            pt:startLoop(1., periodic)
        end
    end
end, Debug and Debug.getLine())
