OnInit.final("RogueSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local atan = math.atan

    ---@class INSTANTDEATH : Spell
    ---@field mult function
    ---@field apply function
    INSTANTDEATH = Spell.define("A0QQ")
    do
        local thistype = INSTANTDEATH

        thistype.bonus = __jarray(0)
        thistype.values = {
            mult = function(pid) return 400. + GetHeroLevel(Hero[pid]) // 50 * 100. end,
        }

        function thistype.apply(u, pid)
            Unit[u].cd_flat = Unit[u].cd_flat - thistype.bonus[u]
            thistype.bonus[u] = thistype.mult(pid)
            Unit[u].cd_flat = Unit[u].cd_flat + thistype.bonus[u]
        end

        function thistype.onSetup(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            Unit[u].cc_percent = 1.2
            thistype.apply(u, pid)
        end
    end

    ---@class DEATHSTRIKE : Spell
    ---@field dmg function
    ---@field dur function
    DEATHSTRIKE = Spell.define("A0QV")
    do
        local thistype = DEATHSTRIKE

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid], true) * (0.5 + 0.5 * ablev) end,
            dur = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 0.6 * ablev end,
        }

        ---@type fun(pt: PlayerTimer)
        local function expire(pt)
            UnitRemoveAbility(pt.target, FourCC('S00I'))
            SetUnitTurnSpeed(pt.target, GetUnitDefaultTurnSpeed(pt.target))

            pt:destroy()
        end

        function thistype:onCast()
            local x = GetUnitX(self.target) - 60 * math.cos(GetUnitFacing(self.target) * bj_DEGTORAD) ---@type number 
            local y = GetUnitY(self.target) - 60 * math.sin(GetUnitFacing(self.target) * bj_DEGTORAD) ---@type number 

            AddUnitAnimationProperties(self.caster, "alternate", false)

            UnitAddAbility(self.target, FourCC('S00I'))
            SetUnitTurnSpeed(self.target, 0)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", self.caster, "chest"))

            if IsTerrainWalkable(x, y) then
                SetUnitPathing(self.caster, false)
                SetUnitXBounded(self.caster, x)
                SetUnitYBounded(self.caster, y)
                SetUnitPathing(self.caster, true)
                BlzSetUnitFacingEx(self.caster, atan(GetUnitY(self.target) - y, GetUnitX(self.target) - x))
            end

            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Coup de Grace.mdx", self.target, "origin"))
            DamageTarget(self.caster, self.target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            TimerQueue:callDelayed(0., IssueTargetOrder, self.caster, "smart", self.target)

            local pt = TimerList[self.pid]:add()
            pt.target = self.target
            pt.timer:callDelayed(self.dur * LBOOST[self.pid], expire, pt)
        end
    end

    ---@class HIDDENGUISE : Spell
    ---@field expire function
    HIDDENGUISE = Spell.define("A0F5")
    do
        local thistype = HIDDENGUISE

        ---@type fun(pt: PlayerTimer)
        function thistype.expire(pt)
            PlayerAddItemById(pt.pid, FourCC('I0OW'))
            SetUnitVertexColor(pt.source, 255, 255, 255, 255)
            ToggleCommandCard(pt.source, true)
            UnitRemoveAbility(pt.source, FourCC('Avul'))
            Unit[pt.source].attack = true
            pt:destroy()
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()

            pt.dur = 2.
            pt.source = self.caster
            pt.tag = thistype.id

            local sfx = AddSpecialEffect("Abilities\\Spells\\Orc\\MirrorImage\\MirrorImageCaster.mdl", self.x, self.y)
            BlzSetSpecialEffectYaw(sfx, GetUnitFacing(self.caster) * bj_DEGTORAD)
            TimerQueue:callDelayed(2., DestroyEffect, sfx)

            UnitRemoveAbility(self.caster, FourCC('BOwk'))
            UnitAddAbility(self.caster, FourCC('Avul'))
            ToggleCommandCard(self.caster, false)
            SetUnitVertexColor(self.caster, 50, 50, 50, 50)
            Unit[self.caster].attack = false
            pt.timer:callDelayed(pt.dur, thistype.expire, pt)
        end
    end

    ---@class NERVEGAS : Spell
    ---@field aoe function
    ---@field dmg function
    ---@field dur number
    NERVEGAS = Spell.define("A0F7")
    do
        local thistype = NERVEGAS

        thistype.values = {
            aoe = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return 190 + 10. * ablev end,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroAgi(Hero[pid], true) * 3. * ablev end,
            dur = 10.,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveBallistic,
                CAT_Orient3D,
                CAT_CheckTerrainCollision,
            },
            identifier = "missile",
            collisionRadius = 10.,
            destroy = function(self)
                local ug = CreateGroup()

                MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(FilterEnemy))

                for enemy in each(ug) do
                    NerveGasDebuff:add(self.source, enemy):duration(self.dur * LBOOST[self.pid])
                end

                local sfx = AddSpecialEffect("war3mapImported\\Radioactivecloud.mdx", self.x, self.y)
                BlzSetSpecialEffectScale(sfx, 0.8)
                TimerQueue:callDelayed(1., DestroyEffect, sfx)
                DestroyEffect(self.visual)
                DestroyGroup(ug)
            end
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            AddUnitAnimationProperties(self.caster, "alternate", false)

            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.z = GetUnitZ(self.caster) + 50.
            missile.visual = AddSpecialEffect("Abilities\\Spells\\Other\\AcidBomb\\BottleMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            local vx, vy, vz = CAT_GetBallisticLaunchSpeedFromVelocity(missile.x, missile.y, missile.z, self.targetX, self.targetY, GetTerrainZ(self.targetX, self.targetY), 1200., true)
            if not vx then
                vx, vy, vz = CAT_GetBallisticLaunchSpeedFromAngle(missile.x, missile.y, missile.z, self.targetX, self.targetY, GetTerrainZ(self.targetX, self.targetY), 65 * bj_DEGTORAD)
            end
            missile.vx = vx
            missile.vy = vy
            missile.vz = vz
            missile.source = self.caster
            missile.owner = Player(self.pid - 1)
            missile.pid = self.pid
            missile.dur = self.dur
            missile.aoe = self.aoe

            ALICE_Create(missile)
        end
    end

    ---@class BACKSTAB : Spell
    ---@field dmg function
    BACKSTAB = Spell.define("A0QP")
    do
        local thistype = BACKSTAB

        thistype.values = {
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (GetHeroAgi(Hero[pid], true) * 0.16 + (Unit[Hero[pid]].damage) * .03) * ablev end,
        }

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local angle = atan(GetUnitY(source) - GetUnitY(target), GetUnitX(source) - GetUnitX(target)) - (bj_DEGTORAD * (GetUnitFacing(target) - 180))

            if angle > bj_PI then
                angle = angle - 2 * bj_PI
            elseif angle < -bj_PI then
                angle = angle + 2 * bj_PI
            end

            if RAbsBJ(angle) <= (0.25 * bj_PI) and (IsUnitType(target, UNIT_TYPE_STRUCTURE) == false) then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", target, "chest"))
                DamageTarget(source, target, thistype.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end
        end

        function thistype.onLearn(source, ablev, pid)
            if ablev == 1 then
                EVENT_ON_HIT:register_unit_action(source, on_hit)
            end
        end
    end

    ---@class PIERCINGSTRIKE : Spell
    ---@field pen function
    PIERCINGSTRIKE = Spell.define("A0QU")
    do
        local thistype = PIERCINGSTRIKE
        thistype.pen = function(pid) return (30 + GetUnitAbilityLevel(Hero[pid], PIERCINGSTRIKE.id)) end

        local function on_hit(source)
            if math.random(0, 99) < 20 then
                PiercingStrikeBuff:add(source, source):duration(3.)
                SetUnitAnimation(source, "spell slam")
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_HIT:register_unit_action(source, on_hit)
        end
    end
end, Debug and Debug.getLine())
