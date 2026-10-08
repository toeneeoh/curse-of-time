OnInit.final("HeroRefresh", function(Require)
    Require('AbilityCasting')
    Require('Profile')
    Require('TimerQueue')
    Require('UnitTable')
    Require('Users')

    local function refresh_heroes()
        local user = User.first

        while user do
            local pid = user.id
            local profile = Profile[pid]

            if profile and profile.playing then
                local hero = Hero[pid]
                local unit = Unit[hero]
                local backpack = Backpack[pid]
                local x, y = GetUnitX(hero), GetUnitY(hero)

                BOOST[pid] = 1. + unit.spellboost + SpellboostVariance()
                LBOOST[pid] = 1. + 0.5 * unit.spellboost
                unit.proxy.x = x
                unit.proxy.y = y

                local hp = GetWidgetLife(hero) / BlzGetUnitMaxHP(hero)
                if hp >= 0.01 then
                    SetWidgetLife(backpack, BlzGetUnitMaxHP(backpack) * hp)

                    local mana = GetUnitState(hero, UNIT_STATE_MANA)
                        / GetUnitState(hero, UNIT_STATE_MAX_MANA)
                    SetUnitState(backpack, UNIT_STATE_MANA,
                        GetUnitState(backpack, UNIT_STATE_MAX_MANA) * mana)
                end
            end

            user = user.next
        end
    end

    TimerQueue:callPeriodically(1., nil, refresh_heroes)
end, Debug and Debug.getLine())
