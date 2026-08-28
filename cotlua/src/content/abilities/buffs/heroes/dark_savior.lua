OnInit.final("BuffsHeroesDarkSavior", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local valid_damage_target = VALID_DAMAGE_TARGET

    ---@class FreezingBlastDebuff : Buff
    FreezingBlastDebuff = Buff.new()
    do
        local thistype = FreezingBlastDebuff
        thistype.NAME            = "Freezing Blast"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFreezingBlast2.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class DarkSealDebuff : Buff
    DarkSealDebuff = Buff.new()
    do
        local thistype = DarkSealDebuff
        thistype.NAME            = "Dark Seal"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower.BLP"
        thistype.DESC            = "This unit is under a Dark Seal"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
    end

    ---@class DarkSealBuff : Buff
    ---@field x number
    ---@field y number
    ---@field count number
    ---@field sfx unit
    DarkSealBuff = Buff.new()
    do
        local thistype = DarkSealBuff
        thistype.NAME            = "Dark Seal"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower.BLP"
        thistype.DESC            = "This unit has +$charges% spellboost and base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function count(object, target, self)
            self.charges = self.charges + ((IsUnitType(object, UNIT_TYPE_HERO) and 10) or 1)
            DarkSealDebuff:add(target, object):duration(1.)
        end

        local function periodic(self)
            self.charges = 0

            -- count units in seal
            ALICE_ForAllObjectsInRangeDo(count, self.x, self.y, 450. * LBOOST[self.pid], "unit", valid_damage_target, self.target, self)

            self.charges = math.min(5 + (GetHeroLevel(self.source) // 100) * 10, self.charges)

            self:refresh()
            self.callback = TQ:callDelayed(0.5, periodic, self)
        end

        -- reapplies spellboost and bat bonus
        function thistype:refresh()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat

            self.spellboost = self.charges * 0.01
            self.bat = (1. + self.charges * 0.01)
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat

            HideEffect(self.sfx)

            TQ:disableCallback(self.callback)
        end

        function thistype:onApply()
            self.spellboost = 0
            self.bat = 1
            self.charges = 0

            self.sfx = AddSpecialEffect("war3mapImported\\newrunetest.mdl", self.x, self.y)
            BlzSetSpecialEffectZ(self.sfx, GetLocZ(self.x, self.y))
            BlzSetSpecialEffectScale(self.sfx, 6.1)
            BlzSetSpecialEffectYaw(self.sfx, 270. * bj_DEGTORAD)
            BlzSetSpecialEffectTimeScale(self.sfx, 0.8)

            periodic(self)
        end
    end

    ---@class DarkAscensionBuff : Buff
    DarkAscensionBuff = Buff.new()
    do
        local thistype = DarkAscensionBuff
        thistype.NAME            = "Dark Ascension"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNhelmofdomination.blp"
        thistype.DESC            = "This unit has splash attacks, !$bat base attack time, and +^#dm% total damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local DB = DARKBLADE

        function thistype:onRemove()
            local u = Unit[self.target]

            u:morph(HERO_DARK_SAVIOR)
            u.dm = u.dm / self.dm
            u.base_bat = 2.0

            UnitDisableAbility(self.target, DB.id, false)
        end

        function thistype:onApply()
            self.bat = 1.0
            local hp = GetWidgetLife(self.target) * 0.5 ---@type number
            local u = Unit[self.target]

            u:morph(HERO_DARK_SAVIOR_DEMON)
            SetWidgetLife(self.target, hp)
            self.dm = 1 + math.max(0.01, hp / (BlzGetUnitMaxHP(self.target) * 1.))
            u.dm = u.dm * self.dm
            u.base_bat = self.bat

            UnitDisableAbility(self.target, DB.id, true)
            BlzUnitHideAbility(self.target, DB.id, false)
            DarkBladeBuff:add(self.target, self.target):duration(DARKASCENSION.dur(self.pid) * LBOOST[self.pid])
        end
    end

    ---@class DarkBladeBuff : Buff
    DarkBladeBuff = Buff.new()
    do
        local thistype = DarkBladeBuff
        thistype.NAME            = "Dark Blade"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSoulBlade.blp"
        thistype.DESC            = "This unit deals $int extra magic damage, restores !$maxmana% max mana on attacks, and has +$str strength"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local DB = DARKBLADE
        local GetWidgetLife, SetWidgetLife, SetUnitState, GetUnitState, BlzGetUnitMaxMana = GetWidgetLife, SetWidgetLife, SetUnitState, GetUnitState, BlzGetUnitMaxMana
        local GetHeroStr, DamageTarget, UnitRefreshBuff = GetHeroStr, DamageTarget, UnitRefreshBuff

        local function damage(target, source, amount)
            DamageTarget(source, target, amount, ATTACK_TYPE_NORMAL, MAGIC, DB.tag)
        end

        local function on_hit(source, target)
            local maxmp = BlzGetUnitMaxMana(source)
            local buff = thistype:get(nil, source)
            local u = Unit[source]

            if buff then
                local prev_hp = GetWidgetLife(source)
                u.bonus_str = u.bonus_str - buff.str
                buff.charges = buff.charges + 1
                local bonus = GetHeroStr(source, true) * 0.02
                buff.str = buff.charges * bonus
                u.bonus_str = u.bonus_str + buff.str
                -- "heal"
                SetWidgetLife(source, prev_hp + bonus * 25)

                UnitRefreshBuff(source, buff)
            end

            SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MANA) + maxmp * 0.005)

            -- splash effect if morphed
            if u.morphed then
                ALICE_ForAllObjectsInRangeDo(damage, GetUnitX(target), GetUnitY(target), 300., "unit", valid_damage_target, source, DB.dmg(u.pid) * BOOST[u.pid])
            else
                DamageTarget(source, target, DB.dmg(u.pid) * BOOST[u.pid], ATTACK_TYPE_NORMAL, MAGIC, DB.tag)
            end
        end

        function thistype:onRemove()
            local u = Unit[self.target]
            u:removeEffect(self.sfx)
            TQ:disableCallback(self.timer)

            -- keep health gains
            local hp = GetWidgetLife(self.target)
            u.bonus_str = u.bonus_str - self.str
            SetWidgetLife(self.target, hp)

            EVENT_ON_HIT:unregister_unit_action(self.target, on_hit)
        end

        local function periodic(self)
            self.int = DB.dmg(self.pid)

            self.timer = TQ:callDelayed(1., periodic, self)

            UnitRefreshBuff(self.target, self)
        end

        function thistype:onApply()
            self.int = DB.dmg(self.pid)
            self.maxmana = 0.5
            self.str = 0
            self.charges = 0

            self.timer = TQ:callDelayed(1., periodic, self)
            self.sfx = Unit[self.target]:addEffect("DarkSword.mdx", "weapon")

            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
        end
    end

    ---@class DarkShieldBuff : Buff
    DarkShieldBuff = Buff.new()
    do
        local thistype = DarkShieldBuff
        thistype.NAME            = "Dark Shield"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNShieldOfDarkOn.dds"
        thistype.DESC            = "This unit has +^#dr% damage resist and drains |cffffcc002|r mana per |cffffcc001|r damage taken"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_struck(target, source, amount, amount_after_red, damage_type)
            local mana = GetUnitState(target, UNIT_STATE_MANA) - amount_after_red * 2

            SetUnitState(target, UNIT_STATE_MANA, math.max(0, mana))

            if mana < 2 then
                thistype:dispel(nil, target)
            end
        end

        function thistype:onRemove()
            local u = Unit[self.target]

            u:removeEffect(self.sfx)

            if GetLocalPlayer() == u.owner then
                BlzSetAbilityIcon(DARKSHIELD.id, "ReplaceableTextures\\CommandButtons\\BTNShieldOfDark.dds")
            end

            u.dr = u.dr / self.dr

            EVENT_ON_STRUCK_FINAL:unregister_unit_action(self.target, on_struck)
        end

        function thistype:onApply()
            local u = Unit[self.target]

            self.dr = (0.45 - 0.05 * self.ablev)
            self.sfx = u:addEffect("DarkShield2.mdx", "right hand", "left hand")

            u.dr = u.dr * self.dr

            if GetLocalPlayer() == u.owner then
                BlzSetAbilityIcon(DARKSHIELD.id, "ReplaceableTextures\\CommandButtons\\BTNShieldOfDarkOn.dds")
            end

            EVENT_ON_STRUCK_FINAL:register_unit_action(self.target, on_struck)
        end
    end

end, Debug and Debug.getLine())
