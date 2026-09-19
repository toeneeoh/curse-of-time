-- Faction membership, units, quest selection, and quest state.

OnInit.final("Faction", function(Require)
    Require('Events')
    Require('Buffs')
    Require('FactionShop')
    Require('Currency')
    Require('Profile')
    Require('TimerQueue')
    Require('Users')
    Require('Variables')

    local faction_leader_type = FourCC('n000')
    local faction_shop_type = FourCC('n004')
    local player_faction = {}
    local pending_faction = {}
    ---@class FactionViewAdapter
    ---@field onSelected fun(faction: Faction, pid: integer)
    ---@field promptJoin fun(faction: Faction, pid: integer, callback: fun(pid: integer): boolean): boolean
    ---@field display fun(faction: Faction, pid: integer)
    ---@field refreshFaction fun(faction: Faction, pid: integer)
    ---@field refreshQuest fun(pid: integer, index: integer, quest: Quest)
    ---@field promptQuest fun(quest: Quest, pid: integer, callback: fun(pid: integer): boolean): boolean
    ---@field questAccepted fun(pid: integer, accepted: Quest, quests: Quest[])
    ---@field refreshProgress fun(pid: integer, quest: Quest, progress: integer)
    ---@field questCompleted fun(pid: integer, quest: Quest)
    ---@field refreshRotation fun(pid: integer)
    local view ---@type FactionViewAdapter?

    ---@class Faction
    ---@field name string
    ---@field id integer
    ---@field desc string
    ---@field quests Quest[]
    ---@field buff Buff
    ---@field leader unit
    ---@field shop unit
    Faction = {}
    Faction.__index = Faction

    ---@class Quest
    ---@field id integer
    ---@field name string
    ---@field desc string
    ---@field icon string
    ---@field diff integer
    ---@field kind string
    ---@field goal integer
    ---@field faction_points integer
    ---@field reputation integer
    ---@field min_rank integer
    Quest = {}
    Quest.__index = Quest
    Quest.quests = {}

    local quest_count = 1
    local pending_quest = {}
    local active_quest = {}
    local quest_progress = __jarray(0)
    local quest_unique_progress = {}
    local completed_offers = {}
    local quest_refresh_timer = {}
    local reroll_used = {}
    local QUEST_REFRESH_PERIOD = 1800.
    local QUEST_REROLL_COST = 5
    local schedule_quest_refresh

    local FACTION_RANK_THRESHOLDS = { 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200 }

    local function hero_data(pid)
        local profile = Profile[pid]
        return profile and profile.hero
    end

    local function ensure_faction_balances(hero)
        hero.faction_point_balances = hero.faction_point_balances or __jarray(0)
        return hero.faction_point_balances
    end

    ---@param pid integer
    ---@param faction_id? integer
    ---@return integer
    function Faction.getPoints(pid, faction_id)
        local hero = hero_data(pid)
        local faction = player_faction[pid]
        faction_id = faction_id or (faction and faction.id) or 0
        if not hero or faction_id <= 0 then
            return 0
        end
        return ensure_faction_balances(hero)[faction_id] or 0
    end

    ---@param pid integer
    ---@param faction_id integer
    ---@return integer
    function Faction.getReputation(pid, faction_id)
        local hero = hero_data(pid)
        return hero and hero.faction_reputation and hero.faction_reputation[faction_id] or 0
    end

    ---@param reputation integer
    ---@return integer
    function Faction.getRank(reputation)
        local rank = 1
        for index = 2, #FACTION_RANK_THRESHOLDS do
            if reputation < FACTION_RANK_THRESHOLDS[index] then
                break
            end
            rank = index
        end
        return rank
    end

    ---@return integer
    function Faction.getMaxRank()
        return #FACTION_RANK_THRESHOLDS
    end

    ---@param reputation integer
    ---@return integer?
    function Faction.getNextRankThreshold(reputation)
        return FACTION_RANK_THRESHOLDS[Faction.getRank(reputation) + 1]
    end

    ---@param pid integer
    ---@param amount integer
    function Faction.addReputation(pid, amount)
        local faction = player_faction[pid]
        local hero = hero_data(pid)
        if not faction or not hero or amount <= 0 then
            return
        end

        hero.faction_reputation = hero.faction_reputation or __jarray(0)
        local old_reputation = hero.faction_reputation[faction.id] or 0
        local old_rank = Faction.getRank(old_reputation)
        local reputation = math.min(100000, old_reputation + amount)
        hero.faction_reputation[faction.id] = reputation
        local rank = Faction.getRank(reputation)

        if rank > old_rank then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "|cffffcc00Faction rank increased:|r "
                .. faction.name .. " Rank " .. rank)
        end
        if view then
            view.refreshFaction(faction, pid)
        end
    end

    ---Sets a faction's saved reputation, primarily for development tools.
    ---@param pid integer
    ---@param faction_id integer
    ---@param amount integer
    function Faction.setReputation(pid, faction_id, amount)
        local hero = hero_data(pid)
        if not hero or not Faction[faction_id] then return false end
        hero.faction_reputation = hero.faction_reputation or __jarray(0)
        hero.faction_reputation[faction_id] = math.max(0, math.min(100000, amount))
        if player_faction[pid] == Faction[faction_id] and view then
            view.refreshFaction(player_faction[pid], pid)
        end
        return true
    end

    ---@param adapter FactionViewAdapter
    function Faction.bindView(adapter)
        view = adapter
    end

    ---@return boolean
    function Faction.isViewBound()
        return view ~= nil
    end

    ---@param pid integer
    ---@return Faction?
    function Faction.getFaction(pid)
        return player_faction[pid]
    end

    ---@param faction Faction
    ---@param pid integer
    local function display_faction(faction, pid)
        Quest.setup(pid)
        if view then
            view.display(faction, pid)
            view.refreshFaction(faction, pid)
        end
    end

    ---@param pid integer
    ---@return boolean
    local function join_faction(pid)
        local faction = pending_faction[pid]
        if not faction then return false end
        if not CHAOS_MODE then
            pending_faction[pid] = nil
            DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                "Factions become available after the world enters Chaos.")
            return false
        end

        player_faction[pid] = faction
        local hero = hero_data(pid)
        if hero then
            hero.faction_id = faction.id
            hero.faction_reputation = hero.faction_reputation or __jarray(0)
            SetCurrency(pid, FACTION, ensure_faction_balances(hero)[faction.id] or 0)
        end
        pending_faction[pid] = nil
        DisplayTextToForce(
            FORCE_PLAYING,
            User[pid - 1].nameColored .. " has joined the " .. faction.name .. "!"
        )
        schedule_quest_refresh(pid)
        display_faction(faction, pid)
        faction.buff:add(Hero[pid], Hero[pid])
        return false
    end

    ---@param selected unit
    ---@param pid integer
    local function on_faction_selected(selected, pid)
        local faction = Faction[selected]
        if not faction or not Hero[pid]
            or not IsUnitInRange(faction.leader, Hero[pid], 1000.) then
            return
        end

        if view then
            view.onSelected(faction, pid)
        end

        if not CHAOS_MODE then
            DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                "Factions become available after the world enters Chaos.")
            return
        end

        if not player_faction[pid] then
            if view and view.promptJoin(faction, pid, join_faction) then
                pending_faction[pid] = faction
            end
        else
            display_faction(player_faction[pid], pid)
        end
    end

    ---@param id integer
    ---@param name string
    ---@param x number
    ---@param y number
    ---@param buff Buff
    ---@param desc string
    ---@return Faction
    function Faction.create(id, name, x, y, buff, desc)
        local self = setmetatable({
            id = id,
            leader = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), faction_leader_type, x, y, 270.),
            shop = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), faction_shop_type, x + 500., y, 270.),
            name = name,
            quests = {},
            buff = buff,
            desc = desc,
        }, Faction)

        EVENT_ON_UNIT_SELECT:register_unit_action(self.leader, on_faction_selected)
        Faction[self.leader] = self
        Faction[id] = self
        return self
    end

    ---@param quest Quest
    function Faction:addQuest(quest)
        self.quests[#self.quests + 1] = quest
    end

    ---@param difficulty integer
    ---@param pid integer
    ---@param excluded_id? integer
    ---@return Quest
    function Faction:pickQuest(difficulty, pid, excluded_id)
        local potential_quests = {}
        local fallback_quests = {}
        local rank = Faction.getRank(Faction.getReputation(pid, self.id))
        for index = 1, #self.quests do
            local quest = self.quests[index]
            if quest.diff == difficulty and rank >= quest.min_rank then
                fallback_quests[#fallback_quests + 1] = quest
                if quest.id ~= excluded_id then
                    potential_quests[#potential_quests + 1] = quest
                end
            end
        end
        if #potential_quests == 0 then
            potential_quests = fallback_quests
        end
        return potential_quests[math.random(1, #potential_quests)]
    end

    ---@param pid integer
    function Faction:refreshQuests(pid, unlock_reroll)
        if unlock_reroll ~= false then
            reroll_used[pid] = false
        end
        completed_offers[pid] = {}
        for difficulty = 1, 3 do
            local previous = Quest.quests[pid][difficulty]
            local excluded_id = unlock_reroll == false and previous and previous.id or nil
            local quest = self:pickQuest(difficulty, pid, excluded_id)
            Quest.quests[pid][difficulty] = quest
            if view then
                view.refreshQuest(pid, difficulty, quest)
            end
        end
        if active_quest[pid] and view then
            view.refreshProgress(pid, active_quest[pid], quest_progress[pid])
        end
        if view then
            view.refreshRotation(pid)
        end
    end

    ---@param name string
    ---@param desc string
    ---@param icon string
    ---@param difficulty integer
    ---@param kind string
    ---@param goal integer
    ---@param faction_points integer
    ---@param reputation integer
    ---@param min_rank? integer
    ---@return Quest
    function Quest.create(name, desc, icon, difficulty, kind, goal, faction_points, reputation, min_rank)
        local self = setmetatable({
            id = quest_count,
            name = name,
            desc = desc,
            icon = icon,
            diff = difficulty,
            kind = kind,
            goal = goal,
            faction_points = faction_points,
            reputation = reputation,
            min_rank = min_rank or 1,
        }, Quest)
        Quest[quest_count] = self
        quest_count = quest_count + 1
        return self
    end

    ---@param pid integer
    function Quest:on_accept(pid)
        quest_progress[pid] = 0
        quest_unique_progress[pid] = {}
        if view then
            view.refreshProgress(pid, self, 0)
        end
    end

    ---@param pid integer
    function Quest.setup(pid)
        if not Quest.quests[pid] then
            Quest.quests[pid] = {}
            local faction = Faction.getFaction(pid)
            if faction then
                faction:refreshQuests(pid)
            end
        end
    end

    local function refresh_player_quests(pid)
        quest_refresh_timer[pid] = nil
        local faction = Faction.getFaction(pid)
        if faction then
            quest_refresh_timer[pid] = TimerQueue:callDelayed(
                QUEST_REFRESH_PERIOD, refresh_player_quests, pid)
            faction:refreshQuests(pid)
        end
    end

    schedule_quest_refresh = function(pid)
        if quest_refresh_timer[pid] then
            TimerQueue:disableCallback(quest_refresh_timer[pid])
        end
        quest_refresh_timer[pid] = TimerQueue:callDelayed(
            QUEST_REFRESH_PERIOD, refresh_player_quests, pid)
    end

    ---@param pid integer
    ---@return boolean
    local function accept_quest(pid)
        local quest = pending_quest[pid]
        if not quest then return false end

        active_quest[pid] = quest
        pending_quest[pid] = nil
        if view then
            view.questAccepted(pid, quest, Quest.quests[pid])
        end
        quest:on_accept(pid)
        StartSoundForPlayerBJ(Player(pid - 1), bj_questDiscoveredSound)
        if view and player_faction[pid] then
            view.refreshFaction(player_faction[pid], pid)
        end
        return false
    end

    local function complete_quest(pid, quest)
        active_quest[pid] = nil
        quest_progress[pid] = 0
        quest_unique_progress[pid] = nil
        completed_offers[pid] = completed_offers[pid] or {}
        completed_offers[pid][quest.id] = true
        AddCurrency(pid, FACTION, quest.faction_points)
        Faction.addReputation(pid, quest.reputation)
        DisplayTextToPlayer(Player(pid - 1), 0., 0., "|cffffcc00Faction quest complete:|r "
            .. quest.name .. "\n+" .. quest.faction_points .. " Faction Points and +"
            .. quest.reputation .. " Reputation")
        StartSoundForPlayerBJ(Player(pid - 1), bj_questCompletedSound)
        if view then
            view.questCompleted(pid, quest)
            view.refreshFaction(player_faction[pid], pid)
        end
    end

    ---Advances the active quest when an existing game activity reports progress.
    ---@param pid integer
    ---@param kind string
    ---@param amount? integer
    function Quest.progress(pid, kind, amount)
        local quest = active_quest[pid]
        if not quest or quest.kind ~= kind then
            return false
        end

        local progress = math.min(quest.goal, quest_progress[pid] + (amount or 1))
        quest_progress[pid] = progress
        if view then
            view.refreshProgress(pid, quest, progress)
            view.refreshFaction(player_faction[pid], pid)
        end
        if progress >= quest.goal then
            complete_quest(pid, quest)
        end
        return true
    end

    ---Advances a quest only once for each distinct objective key.
    ---@param pid integer
    ---@param kind string
    ---@param key integer|string
    function Quest.progressUnique(pid, kind, key)
        local quest = active_quest[pid]
        if not quest or quest.kind ~= kind then
            return false
        end
        local seen = quest_unique_progress[pid]
        if not seen then
            seen = {}
            quest_unique_progress[pid] = seen
        end
        if seen[key] then
            return false
        end
        seen[key] = true
        return Quest.progress(pid, kind)
    end

    ---@param pid integer
    ---@return Quest?
    ---@return integer
    function Quest.getActive(pid)
        return active_quest[pid], quest_progress[pid]
    end

    ---@param pid integer
    ---@return number
    function Quest.getRotationRemaining(pid)
        local callback = quest_refresh_timer[pid]
        return callback and (TimerQueue:getRemaining(callback) or 0.) or 0.
    end

    ---@param pid integer
    ---@return boolean
    function Quest.canReroll(pid)
        return player_faction[pid] ~= nil
            and reroll_used[pid] ~= true
            and GetCurrency(pid, FACTION) >= QUEST_REROLL_COST
    end

    ---@return integer
    function Quest.getRerollCost()
        return QUEST_REROLL_COST
    end

    ---Cancels the active quest and immediately rolls a new set of offers.
    ---@param pid integer
    ---@return boolean
    function Quest.reroll(pid)
        local faction = player_faction[pid]
        if not faction then
            return false
        end
        if reroll_used[pid] then
            DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                "You have already rerolled this quest rotation.")
            return false
        end
        if GetCurrency(pid, FACTION) < QUEST_REROLL_COST then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "You need "
                .. QUEST_REROLL_COST .. " Faction Points to reroll quests.")
            return false
        end

        AddCurrency(pid, FACTION, -QUEST_REROLL_COST)
        reroll_used[pid] = true
        active_quest[pid] = nil
        pending_quest[pid] = nil
        quest_progress[pid] = 0
        quest_unique_progress[pid] = nil
        -- A reroll changes the current offers without postponing the next
        -- scheduled rotation. That rotation unlocks the button again.
        faction:refreshQuests(pid, false)
        if view then
            view.refreshFaction(faction, pid)
            view.refreshRotation(pid)
        end
        return true
    end

    ---@param pid integer
    ---@param index integer
    function Quest.select(pid, index)
        local quest = Quest.quests[pid] and Quest.quests[pid][index]
        if quest and not active_quest[pid]
            and not (completed_offers[pid] and completed_offers[pid][quest.id])
            and view and view.promptQuest(quest, pid, accept_quest) then
            pending_quest[pid] = quest
        end
    end

    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3
    local miner_guild = Faction.create(
        1,
        "Cave Voyagers",
        15000,
        10500,
        HardHatBuff,
        "The Cave Voyagers are a mining faction that provide access to earth materials and a special defensive buff.|n|n|cffffcc00Membership, reputation, and unspent Faction Points are saved with this character.|r|n|nWill you join us?"
    )
    miner_guild:addQuest(Quest.create(
        "Prospector's Route",
        "Mine 3 ore deposits.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_EASY,
        "mine_any", 3, 5, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Arena Survey",
        "Enter the Colosseum.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp",
        QUEST_DIFF_EASY,
        "colosseum_enter", 1, 5, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Stone Samples",
        "Recover 8 ore samples from deposits. Rich and rare deposits provide more samples.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        QUEST_DIFF_EASY,
        "mine_ore", 8, 5, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Rich Veins",
        "Mine 2 rich ore deposits.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNGem.blp",
        QUEST_DIFF_MEDIUM,
        "mine_rich", 2, 10, 10, 2
    ))
    miner_guild:addQuest(Quest.create(
        "Endless Excavation",
        "Clear 10 waves of the Infinite Struggle.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_MEDIUM,
        "struggle_wave", 10, 10, 10
    ))
    miner_guild:addQuest(Quest.create(
        "Cave-In Cleanup",
        "Defeat 2 golems awakened by mining operations. Nearby Cave Voyagers share credit.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHeroMountainKing.blp",
        QUEST_DIFF_MEDIUM,
        "mining_guardian", 2, 10, 10
    ))
    miner_guild:addQuest(Quest.create(
        "Unbroken Extraction",
        "Complete a rare deposit's 30-second extraction without being interrupted.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHumanBuild.blp",
        QUEST_DIFF_HARD,
        "rare_extraction", 1, 20, 20, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Awakened Colossus",
        "Defeat a golem awakened by a rare deposit.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNStoneGiant.blp",
        QUEST_DIFF_HARD,
        "rare_guardian", 1, 20, 20, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Deep Survey",
        "Mine deposits in 3 distinct Chaos regions.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNSpy.blp",
        QUEST_DIFF_HARD,
        "mining_region", 3, 20, 20
    ))
    miner_guild:addQuest(Quest.create(
        "Champion's Commission",
        "Complete all 20 Colosseum waves.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
        QUEST_DIFF_HARD,
        "colosseum_clear", 1, 20, 20
    ))

    local function restore_faction(pid, hero)
        pending_faction[pid] = nil
        active_quest[pid] = nil
        quest_progress[pid] = 0
        Quest.quests[pid] = nil
        hero.faction_reputation = hero.faction_reputation or __jarray(0)
        local balances = ensure_faction_balances(hero)
        local has_new_balance = false
        for faction_id = 1, 6 do
            if (balances[faction_id] or 0) > 0 then
                has_new_balance = true
                break
            end
        end
        -- Saves created before faction-specific balances used one shared field.
        if not has_new_balance and (hero.faction_points or 0) > 0 then
            local legacy_faction = (hero.faction_id or 0) > 0 and hero.faction_id or 1
            balances[legacy_faction] = hero.faction_points
        end
        player_faction[pid] = Faction[hero.faction_id or 0]
        local faction = player_faction[pid]
        if faction then
            SetCurrency(pid, FACTION, balances[faction.id] or 0)
            schedule_quest_refresh(pid)
            Quest.setup(pid)
            faction.buff:add(Hero[pid], Hero[pid])
        else
            -- The HUD/shop currency represents only the active faction. Keep
            -- saved balances inaccessible until that faction is joined.
            SetCurrency(pid, FACTION, 0)
        end
    end

    local function clear_player(pid)
        player_faction[pid] = nil
        pending_faction[pid] = nil
        pending_quest[pid] = nil
        active_quest[pid] = nil
        quest_progress[pid] = 0
        quest_unique_progress[pid] = nil
        Quest.quests[pid] = nil
        completed_offers[pid] = nil
        reroll_used[pid] = nil
        if quest_refresh_timer[pid] then
            TimerQueue:disableCallback(quest_refresh_timer[pid])
            quest_refresh_timer[pid] = nil
        end
    end

    local function on_currency_changed(pid, currency, amount)
        if currency ~= FACTION then return end
        local faction = player_faction[pid]
        local hero = hero_data(pid)
        if faction and hero then
            ensure_faction_balances(hero)[faction.id] = amount
        end
    end

    HardHatBuff.getFactionReduction = function(target)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        local rank = Faction.getRank(Faction.getReputation(pid, 1))
        if rank >= 7 then return 0.15 end
        if rank >= 4 then return 0.11 end
        return 0.08
    end

    Profile.registerHeroLoadedAction(restore_faction)
    RegisterCurrencyChangedAction(on_currency_changed)
    local user = User.first
    while user do
        EVENT_ON_CLEANUP:register_action(user.id, clear_player)
        user = user.next
    end
end, Debug and Debug.getLine())
