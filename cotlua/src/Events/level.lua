--[[
    level.lua

    Handles the EVENT_PLAYER_HERO_LEVEL event
]]

OnInit.final("Level", function(Require)
    Require('Users')

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
        local uid   = GetUnitTypeId(u) ---@type integer 

        if u == Hero[pid] then
            if uid == HERO_DARK_SUMMONER then -- summoning improvement level
                SetUnitAbilityLevel(u, SUMMONINGIMPROVEMENT.id, level // 10 + 1)
            elseif uid == HERO_DARK_SAVIOR then -- dark seal level
                SetUnitAbilityLevel(u, DARKSEAL.id, level // 100 + 1)
            elseif uid == HERO_SAVIOR then -- light seal level
                SetUnitAbilityLevel(u, LIGHTSEAL.id, level // 100 + 1)
            elseif uid == HERO_OBLIVION_GUARD then -- body of fire level
                SetUnitAbilityLevel(u, BODYOFFIRE.id, level // 100 + 1)
            elseif uid == HERO_PHOENIX_RANGER then -- multishot level
                SetUnitAbilityLevel(u, FourCC('A05R'), math.min(level // 50 + 1, 5))
            elseif uid == HERO_THUNDERBLADE then -- overload level
                SetUnitAbilityLevel(u, OVERLOAD.id, level // 75 + 1)
            elseif uid == HERO_ASSASSIN then -- blade spin level
                SetUnitAbilityLevel(u, BLADESPIN.id, IMinBJ(4, level // 100 + 1))
                SetUnitAbilityLevel(u, BLADESPIN.id2, IMinBJ(4, level // 100 + 1))
            elseif uid == HERO_MASTER_ROGUE then -- instant death level
                SetUnitAbilityLevel(u, INSTANTDEATH.id, level // 50 + 1)
                INSTANTDEATH.apply(u, pid)
            end

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
