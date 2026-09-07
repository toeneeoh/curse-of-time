OnInit.final("BuffsBossesAzazoth", function(Require)
    Require('BossSchema')
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan

    local DEMON_SHIELD_MODEL = "war3mapImported\\DemonShieldTarget3A.mdx"

    ---@class AstralShieldBuff : Buff
    AstralShieldBuff = Buff.new()
    do
        local thistype = AstralShieldBuff
        thistype.NAME            = "Astral Shield"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSnakeShield.blp"
        thistype.DESC            = "This unit has +^#mr% magic resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.mr = 0.333
            Unit[self.target].mr = Unit[self.target].mr * self.mr
            self.sfx = Unit[self.target]:addEffect(DEMON_SHIELD_MODEL, "origin")
            self.sfx.anim = ANIM_TYPE_STAND
        end
    end

    ---@class AstralPrisonDebuff : Buff
    AstralPrisonDebuff = Buff.new()
    do
        local thistype = AstralPrisonDebuff
        thistype.NAME            = "Astral Prison"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNShadowCapture.blp"
        thistype.DESC            = "This unit has -^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
                CAT_Decay,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            visualZ = 100.,
            speed = 600.,
            arc = 0.5,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, target)
                HP(self.source, target, self.heal, thistype.tag)
            end
        }
        missile_template.__index = missile_template

        local function delay(self, x, y, z, heal)
            PauseUnit(self.target, false)

            if not UnitAlive(self.target) then
                return
            end

            local missile = setmetatable({}, missile_template)
            missile.x = x
            missile.y = y
            missile.z = z
            missile.visual = AddSpecialEffect("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonMissile.mdl", x, y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            missile.source = self.spire
            missile.target = self.target
            missile.collideZ = true
            missile.owner = Player(self.pid - 1)
            missile.heal = heal
            missile.lifetime = 4.

            ALICE_Create(missile)
        end

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr * self.dr

            -- heal sequence
            if UnitAlive(self.spire) then
                if UnitAlive(self.target) then
                    local heal = GetWidgetLife(self.spire) * BlzGetUnitMaxHP(self.target) * 0.01
                    local x, y, z = GetUnitX(self.spire), GetUnitY(self.spire), GetUnitZ(self.spire)

                    BlzSetUnitFacingEx(self.target, bj_RADTODEG * math.atan(y - GetUnitY(self.target), x - GetUnitX(self.target)))
                    PauseUnit(self.target, true)
                    SetUnitAnimationByIndex(self.target, 21)
                    TQ:callDelayed(1.1, delay, self, x, y, z, heal)
                    TQ:callDelayed(1.1, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", x, y))

                    KillUnit(self.spire)
                else
                    RemoveUnit(self.spire)
                end
            end
        end

        function thistype:onApply()
            self.dr = 0.65
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end
    end

    ---@class AstralChainsDebuff : Buff
    AstralChainsDebuff = Buff.new()
    do
        local thistype = AstralChainsDebuff
        thistype.NAME            = "Astral Chains"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNShadowCapture.blp"
        thistype.DESC            = "This unit cannot move $dist units away from the spire"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function soul_death(target)
            RemoveUnit(target)
        end

        local function soul_periodic(self)
            local chain = self.chain:get_source_unit()
            if UnitAlive(self.soul) and UnitAlive(chain) then
                local x, y = GetUnitX(chain), GetUnitY(chain)
                IssuePointOrder(self.soul, "move", x, y)

                if IsUnitInRange(self.soul, chain, 25.) then
                    BlzSetUnitMaxHP(chain, BlzGetUnitMaxHP(chain) + 10)
                    SetWidgetLife(chain, GetWidgetLife(chain) + 20.)
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl", x, y))
                    RemoveUnit(self.soul)
                    self.soul = nil

                    return
                end

                self.timer2 = TQ:callDelayed(0.5, soul_periodic, self)
            end
        end

        function thistype:spawn_soul()
            if not UnitAlive(self.soul) then
                local chain_source = self.chain:get_source_unit()
                if not UnitAlive(chain_source) then
                    return
                end

                local x, y = GetUnitX(chain_source), GetUnitY(chain_source)
                local x2, y2 = GetUnitX(self.target), GetUnitY(self.target)
                local angle = math.atan(y2 - y, x2 - x)
                self.soul = CreateUnit(PLAYER_BOSS, FourCC('n002'), x2, y2, bj_RADTODEG * angle)
                local unit = Unit[self.soul]
                unit.hit_based_health = true
                unit.ms_flat = 150
                unit.attack = false
                BlzSetUnitMaxHP(self.soul, 15)
                SetWidgetLife(self.soul, 15)
                UnitAddAbility(self.soul, FourCC('A094'))
                IssueImmediateOrder(self.soul, "windwalk")
                SetUnitX(self.soul, x2)
                SetUnitY(self.soul, y2)
                BlzSetUnitSkin(self.soul, Profile[self.tpid].hero.unit_id)
                local name = User[self.tpid - 1].nameTrimmed
                BlzSetUnitName(self.soul, "Soul of " .. name)
                BlzSetHeroProperName(self.soul, "Soul of " .. name)
                SetUnitVertexColor(self.soul, 0, 168, 107, 120)
                SetUnitColor(self.soul, PLAYER_COLOR_EMERALD)
                SetUnitScale(self.soul, 0.85, 0.85, 0.85)
                unit:addEffect("Abilities\\Spells\\Human\\Banish\\BanishTarget.mdl", "origin")

                IssuePointOrder(self.soul, "move", x, y)

                EVENT_ON_UNIT_DEATH:register_unit_action(self.soul, soul_death)

                self.timer2 = TQ:callDelayed(0.5, soul_periodic, self)
            end
        end

        local function periodic(self)
            if self.chain:update() then
                self.timer = TQ:callDelayed(FPS_32, periodic, self)
            else
                self.timer = nil
            end
        end

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)
            self.chain:destroy()
            RemoveUnit(self.soul)
            TQ:disableCallback(self.timer)
            TQ:disableCallback(self.timer2)
        end

        function thistype:onApply()
            local spire = AstralPrisonDebuff:get(nil, Boss[BOSS_AZAZOTH].unit).spire
            self.dist = 1000.

            local chain = Chain.create{
                source = Chain.unit(spire, 50.),
                target = Chain.unit(self.target, 50.),
                length = 1000.,
                segments = 14,
                color = {0.24, 0.80, 0.50, 1.},
            }

            self.sfx = Unit[self.target]:addEffect("Bondage Teal SD.mdx", "chest")
            self.chain = chain
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

end, Debug and Debug.getLine())
