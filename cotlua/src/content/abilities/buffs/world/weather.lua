OnInit.final("BuffsWorldWeather", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    ---@class WeatherBuff : Buff
    WeatherBuff = Buff.new()
    do
        local thistype = WeatherBuff
        thistype.DISPEL_TYPE = BUFF_NONE
        thistype.STACK_TYPE = BUFF_STACK_PARTIAL
        -- Weather changes this definition between positive and negative at
        -- runtime. Its lifetime represents the global weather schedule rather
        -- than a resistible debuff applied to one unit.
        thistype.IGNORE_STATUS_RESISTANCE = true
    end
end, Debug and Debug.getLine())
