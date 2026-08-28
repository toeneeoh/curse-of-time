OnInit.final("BuffsWorldWeather", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    ---@class WeatherBuff : Buff
    WeatherBuff = Buff.new()
    do
        local thistype = WeatherBuff
        thistype.DISPEL_TYPE     = BUFF_NONE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
    end
end, Debug and Debug.getLine())
