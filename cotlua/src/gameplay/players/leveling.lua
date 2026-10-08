--[[
    leveling.lua

    Handles the EVENT_PLAYER_HERO_LEVEL event
]]

OnInit.final("Level", function(Require)
    Require('Users')
    Require('Events')
    Require('RewardNotifications')

    local old_set_level = SetHeroLevel
    SetHeroLevel = function(u, lvl, eye_candy)
        old_set_level(u, lvl, eye_candy)
        Unit[u]:syncHeroAttributes()
        SetWidgetLife(u, BlzGetUnitMaxHP(u))
        SetUnitState(u, UNIT_STATE_MANA, BlzGetUnitMaxMana(u))
    end

    local function OnLevel()
        local u     = GetTriggerUnit() ---@type unit 
        local p     = GetOwningPlayer(u)
        local pid   = GetPlayerId(p) + 1 ---@type integer 
        local level = GetHeroLevel(u) ---@type integer 

        if u == Hero[pid] then
            local metrics = RuntimeMetrics.leveling
            local started_at = os.clock()
            metrics.events = metrics.events + 1

            local stage_started_at = os.clock()
            EVENT_HERO_LEVEL_CHANGED:trigger(u, level)
            metrics.hero_event_time = metrics.hero_event_time + os.clock() - stage_started_at

            -- update backpack level but disable XP gain
            stage_started_at = os.clock()
            SuspendHeroXP(Backpack[pid], false)
            SetHeroLevel(Backpack[pid], GetHeroLevel(Hero[pid]),false)
            SuspendHeroXP(Backpack[pid], true)
            metrics.backpack_time = metrics.backpack_time + os.clock() - stage_started_at

            -- update restricted items
            stage_started_at = os.clock()
            for i = BACKPACK_INDEX, MAX_INVENTORY_SLOTS do
                local itm = Profile[pid].hero.items[i]

                if itm then
                    if (GetHeroLevel(Hero[pid])) >= ItemData[itm.id][ITEM_LEVEL_REQUIREMENT] then
                        itm.restricted = false
                    end
                end
            end
            metrics.item_time = metrics.item_time + os.clock() - stage_started_at

            -- update stats TODO: remove built in stat gain?
            stage_started_at = os.clock()
            Unit[u]:syncHeroAttributes()
            metrics.stat_sync_time = metrics.stat_sync_time + os.clock() - stage_started_at

            -- trigger stat change event
            stage_started_at = os.clock()
            EVENT_STAT_CHANGE:trigger(u)
            metrics.stat_event_time = metrics.stat_event_time + os.clock() - stage_started_at

            stage_started_at = os.clock()
            ExperienceControl(pid)
            RewardNotifications.eligibility(pid)
            metrics.finish_time = metrics.finish_time + os.clock() - stage_started_at

            local elapsed = os.clock() - started_at
            metrics.total_time = metrics.total_time + elapsed
            metrics.max_time = math.max(metrics.max_time, elapsed)
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
