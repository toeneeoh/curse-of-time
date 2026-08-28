OnInit.final("BuffsCommon", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan

    ---@class Disarm : Buff
    Disarm = Buff.new()
    do
        local thistype = Disarm
        thistype.NAME            = "Disarmed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEmptyHand.BLP"
        thistype.DESC            = "This unit cannot attack"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].attack = true
        end

        function thistype:onApply()
            Unit[self.target].attack = false
        end
    end

    ---@class Silence : Buff
    Silence = Buff.new()
    do
        local thistype = Silence
        thistype.NAME            = "Silenced"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSilence.blp"
        thistype.DESC            = "This unit cannot cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)
            ToggleCommandCard(self.target, true)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\Silence\\SilenceTarget.mdl", "overhead")
            ToggleCommandCard(self.target, false)
        end
    end

    ---@class Fear : Buff
    Fear = Buff.new()
    do
        local thistype = Fear
        thistype.NAME            = "Feared"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGuldanSkull.blp"
        thistype.DESC            = "This unit is moving uncontrollably"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_order(source, target, id)
            local b = Fear:get(nil, source)

            -- reissue movement order to feared units
            if b then
                IssuePointOrder(source, "move", b.x, b.y)
            end
        end

        function thistype:onRemove()
            UnitRemoveAbility(self.target, FourCC('ARal'))
            ToggleCommandCard(self.target, true)
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(self.target, FourCC("AInv")), ConvertAbilityIntegerLevelField(FourCC('inv5')), 0, 1)

            Unit[self.target].attack = true
            EVENT_ON_ORDER:unregister_unit_action(self.target, on_order)
        end

        function thistype:onApply()
            local angle = atan(GetUnitY(self.target) - GetUnitY(self.source), GetUnitX(self.target) - GetUnitX(self.source)) ---@type number
            self.x = GetUnitX(self.target) + 2000. * math.cos(angle)
            self.y = GetUnitY(self.target) + 2000. * math.sin(angle)

            IssuePointOrder(self.target, "move", self.x, self.y)
            ToggleCommandCard(self.target, false)
            UnitAddAbility(self.target, FourCC('ARal'))
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(self.target, FourCC("AInv")), ConvertAbilityIntegerLevelField(FourCC('inv5')), 0, 0)
            EVENT_ON_ORDER:register_unit_action(self.target, on_order)
        end
    end

    ---@class KnockUp : Buff
    KnockUp = Buff.new()
    do
        local thistype = KnockUp
        thistype.NAME            = "Mid-air"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNStun.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local SPEED = 1500.
        local DEBUFF_TIME = 1.

        ---@param deltaTime number
        ---@return number
        local function calcHeight(deltaTime)
            local g = 9.81 ---@type number
            local h = 0. ---@type number

            deltaTime = deltaTime * 1.2

            if deltaTime <= DEBUFF_TIME * 0.5 then
                h = SPEED * deltaTime - 0.5 * g * deltaTime * deltaTime
            else
                deltaTime = deltaTime * 1.2
                h = SPEED * (DEBUFF_TIME - deltaTime) - 0.5 * g * (DEBUFF_TIME - deltaTime) * (DEBUFF_TIME - deltaTime)
            end

            return math.max(0, h)
        end

        local function periodic(self)
            self.time = self.time + FPS_32
            SetUnitFlyHeight(self.target, calcHeight(self.time), 0.)

            if self.time > DEBUFF_TIME then
                self:remove()
            else
                self.timer = TQ:callDelayed(FPS_32, periodic, self)
            end
        end

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            SetUnitFlyHeight(self.target, 0., 0.)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)

            if UnitAddAbility(self.target, FourCC('Amrf')) then
                UnitRemoveAbility(self.target, FourCC('Amrf'))
            end

            self.time = 0
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

    ---@class Freeze : Buff
    Freeze = Buff.new()
    do
        local thistype = Freeze
        thistype.NAME            = "Frozen"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGlacier.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Undead\\FreezingBreath\\FreezingBreathTargetArt.mdl", "chest")

            local boss = IsBoss(self.target)
            if boss and boss.stun_anim then
                SetUnitAnimationByIndex(self.target, boss.stun_anim)
            end
        end
    end

    ---@class Stun : Buff
    Stun = Buff.new()
    do
        local thistype = Stun
        thistype.NAME            = "Stunned"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNStun.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", "overhead")

            local boss = IsBoss(self.target)
            if boss and boss.stun_anim then
                SetUnitAnimationByIndex(self.target, boss.stun_anim)
            end
        end
    end

end, Debug and Debug.getLine())
