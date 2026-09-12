--[[
    struggle.lua

    Buff Bar presentation for hazards used by the Infinite Struggle.
]]

OnInit.final("BuffsWorldStruggle", function(Require)
    Require('BuffSystem')

    ---@class StruggleFuryDebuff : Buff
    StruggleFuryDebuff = Buff.new()
    do
        local thistype = StruggleFuryDebuff
        thistype.NAME        = "Fury Swipes"
        thistype.DESC        = "The next Fury Swipes attack against this unit deals +^$damage damage. The highest active stack is shown"
        thistype.ICON        = BlzGetAbilityIcon(FourCC('A036'))
        thistype.DISPEL_TYPE = BUFF_NEGATIVE
        thistype.STACK_TYPE  = BUFF_STACK_NONE

        ---@param charges integer
        ---@param damage number
        ---@param duration number
        function thistype:update(charges, damage, duration)
            self.charges = charges
            self.damage = damage
            self:duration(duration)
            UnitRefreshBuff(self.target, self)
            return self
        end
    end

    ---@class CorrosiveMiasmaDebuff : Buff
    CorrosiveMiasmaDebuff = Buff.new()
    do
        local thistype = CorrosiveMiasmaDebuff
        thistype.NAME        = "Corrosive Miasma"
        thistype.DESC        = "This unit is standing in Corrosive Miasma and suffers damage every second"
        thistype.ICON        = BlzGetAbilityIcon(FourCC('A03J'))
        thistype.AURA        = true
        thistype.DISPEL_TYPE = BUFF_NEGATIVE
        thistype.STACK_TYPE  = BUFF_STACK_NONE
    end
end, Debug and Debug.getLine())
