--[[
    leveling.lua

    Handles the EVENT_PLAYER_HERO_LEVEL event
]]

OnInit.final("Level", function(Require)
    Require('Users')
    Require('Events')

    local old_set_level = SetHeroLevel
    SetHeroLevel = function(u, lvl, eye_candy)
        old_set_level(u, lvl, eye_candy)
        Unit[u].str = GetHeroStr(u, false)
        Unit[u].agi = GetHeroAgi(u, false)
        Unit[u].int = GetHeroInt(u, false)
        SetWidgetLife(u, BlzGetUnitMaxHP(u))
        SetUnitState(u, UNIT_STATE_MANA, BlzGetUnitMaxMana(u))
    end

    local function OnLevel()
        local u     = GetTriggerUnit() ---@type unit 
        local p     = GetOwningPlayer(u)
        local pid   = GetPlayerId(p) + 1 ---@type integer 
        local level = GetHeroLevel(u) ---@type integer 

        if u == Hero[pid] then
            EVENT_HERO_LEVEL_CHANGED:trigger(u, level)

            -- update backpack level but disable XP gain
            SuspendHeroXP(Backpack[pid], false)
            SetHeroLevel(Backpack[pid], GetHeroLevel(Hero[pid]),false)
            SuspendHeroXP(Backpack[pid], true)

            -- update restricted items
            for i = BACKPACK_INDEX, MAX_INVENTORY_SLOTS do
                local itm = Profile[pid].hero.items[i]

                if itm then
                    if (GetHeroLevel(Hero[pid])) >= ItemData[itm.id][ITEM_LEVEL_REQUIREMENT] then
                        itm.restricted = false
                    end
                end
            end

            -- update stats TODO: remove built in stat gain?
            Unit[u].str = GetHeroStr(u, false)
            Unit[u].agi = GetHeroAgi(u, false)
            Unit[u].int = GetHeroInt(u, false)

            -- trigger stat change event
            EVENT_STAT_CHANGE:trigger(u)

            ExperienceControl(pid)
        end

        return false
    end

    local level = CreateTrigger()
    local u = User.first ---@type User 

    while u do
        TriggerRegisterPlayerUnitEvent(level, u.player, EVENT_PLAYER_HERO_LEVEL, nil)
        u = u.next
    end

    TriggerAddCondition(level, Condition(OnLevel))
end, Debug and Debug.getLine())
