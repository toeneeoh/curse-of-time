OnInit.final("BuffsBossesHellfireMagi", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class FrostArmorDebuff : Buff
    FrostArmorDebuff = Buff.new()
    do
        local thistype = FrostArmorDebuff
        thistype.NAME            = "Frost Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFrostArmor.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^#bat% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            local u = Unit[self.target]
            u.ms_percent = u.ms_percent + self.ms
            u.bonus_bat = u.bonus_bat / self.bat
        end

        function thistype:onApply()
            local u = Unit[self.target]
            self.ms = 0.25 * (math.min(1, u.ms_percent))
            self.bat = 1.25

            u.ms_percent = u.ms_percent - self.ms
            u.bonus_bat = u.bonus_bat * self.bat
        end
    end

    ---@class FrostArmorBuff : Buff
    FrostArmorBuff = Buff.new()
    do
        local thistype = FrostArmorBuff
        thistype.NAME            = "Frost Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFrostArmor.blp"
        thistype.DESC            = "This unit has +$armor armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(target, source)
            FrostArmorDebuff:add(target, source):duration(3.)
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK:unregister_unit_action(self.target, on_hit)
            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor - self.armor

            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.armor = 100
            EVENT_ON_STRUCK:register_unit_action(self.target, on_hit)
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl", "chest")

            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor + self.armor
        end
    end

end, Debug and Debug.getLine())
