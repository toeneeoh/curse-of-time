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
    Quest = {}
    Quest.__index = Quest
    Quest.quests = {}

    local quest_count = 1
    local pending_quest = {}
    local active_quest = {}
    local quest_progress = __jarray(0)
    local completed_offers = {}
    local quest_refresh_timer = {}
    local QUEST_REFRESH_PERIOD = 1800.
    local QUEST_REROLL_COST = 5
    local schedule_quest_refresh

    local FACTION_RANK_THRESHOLDS = { 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200 }

    local function hero_data(pid)
        local profile = Profile[pid]
        return profile and profile.hero
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

        player_faction[pid] = faction
        local hero = hero_data(pid)
        if hero then
            hero.faction_id = faction.id
            hero.faction_reputation = hero.faction_reputation or __jarray(0)
        end
        pending_faction[pid] = nil
        DisplayTextToForce(
            FORCE_PLAYING,
            User[pid - 1].nameColored .. " has joined the " .. faction.name .. "!"
        )
        display_faction(faction, pid)
        schedule_quest_refresh(pid)
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
    ---@return Quest
    function Faction:pickQuest(difficulty)
        local potential_quests = {}
        for index = 1, #self.quests do
            local quest = self.quests[index]
            if quest.diff == difficulty then
                potential_quests[#potential_quests + 1] = quest
            end
        end
        return potential_quests[math.random(1, #potential_quests)]
    end

    ---@param pid integer
    function Faction:refreshQuests(pid)
        completed_offers[pid] = {}
        for difficulty = 1, 3 do
            local quest = self:pickQuest(difficulty)
            Quest.quests[pid][difficulty] = quest
            if view then
                view.refreshQuest(pid, difficulty, quest)
            end
        end
        if active_quest[pid] and view then
            view.refreshProgress(pid, active_quest[pid], quest_progress[pid])
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
    ---@return Quest
    function Quest.create(name, desc, icon, difficulty, kind, goal, faction_points, reputation)
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
        }, Quest)
        Quest[quest_count] = self
        quest_count = quest_count + 1
        return self
    end

    ---@param pid integer
    function Quest:on_accept(pid)
        quest_progress[pid] = 0
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
            faction:refreshQuests(pid)
            quest_refresh_timer[pid] = TimerQueue:callDelayed(
                QUEST_REFRESH_PERIOD, refresh_player_quests, pid)
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
        return false
    end

    local function complete_quest(pid, quest)
        active_quest[pid] = nil
        quest_progress[pid] = 0
        completed_offers[pid] = completed_offers[pid] or {}
        completed_offers[pid][quest.id] = true
        AddCurrency(pid, FACTION, quest.faction_points)
        Faction.addReputation(pid, quest.reputation)
        DisplayTextToPlayer(Player(pid - 1), 0., 0., "|cffffcc00Faction quest complete:|r "
            .. quest.name .. "\n+" .. quest.faction_points .. " Faction Points and +"
            .. quest.reputation .. " Reputation")
        if view then
            view.questCompleted(pid, quest)
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
        end
        if progress >= quest.goal then
            complete_quest(pid, quest)
        end
        return true
    end

    ---@param pid integer
    ---@return Quest?
    ---@return integer
    function Quest.getActive(pid)
        return active_quest[pid], quest_progress[pid]
    end

    ---Cancels the active contract and immediately rolls a new set of offers.
    ---@param pid integer
    ---@return boolean
    function Quest.reroll(pid)
        local faction = player_faction[pid]
        if not faction then
            return false
        end
        if GetCurrency(pid, FACTION) < QUEST_REROLL_COST then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "You need "
                .. QUEST_REROLL_COST .. " Faction Points to reroll contracts.")
            return false
        end

        AddCurrency(pid, FACTION, -QUEST_REROLL_COST)
        active_quest[pid] = nil
        pending_quest[pid] = nil
        quest_progress[pid] = 0
        faction:refreshQuests(pid)
        schedule_quest_refresh(pid)
        if view then
            view.refreshFaction(faction, pid)
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
        "Arena Survey",
        "Enter the Colosseum and survey the mineral formations exposed by its battles.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp",
        QUEST_DIFF_EASY,
        "colosseum_enter", 1, 5, 5
    ))
    miner_guild:addQuest(Quest.create(
        "Endless Excavation",
        "Clear 10 waves of the Infinite Struggle while this contract is active.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_MEDIUM,
        "struggle_wave", 10, 10, 10
    ))
    miner_guild:addQuest(Quest.create(
        "Champion's Commission",
        "Complete all 20 Colosseum waves while this contract is active.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
        QUEST_DIFF_HARD,
        "colosseum_clear", 1, 20, 20
    ))

    local function restore_faction(pid, hero)
        pending_faction[pid] = nil
        active_quest[pid] = nil
        quest_progress[pid] = 0
        Quest.quests[pid] = nil
        player_faction[pid] = Faction[hero.faction_id or 0]
        local faction = player_faction[pid]
        if faction then
            Quest.setup(pid)
            schedule_quest_refresh(pid)
            faction.buff:add(Hero[pid], Hero[pid])
        end
    end

    local function clear_player(pid)
        player_faction[pid] = nil
        pending_faction[pid] = nil
        pending_quest[pid] = nil
        active_quest[pid] = nil
        quest_progress[pid] = 0
        Quest.quests[pid] = nil
        completed_offers[pid] = nil
        if quest_refresh_timer[pid] then
            TimerQueue:disableCallback(quest_refresh_timer[pid])
            quest_refresh_timer[pid] = nil
        end
    end

    Profile.registerHeroLoadedAction(restore_faction)
    local user = User.first
    while user do
        EVENT_ON_CLEANUP:register_action(user.id, clear_player)
        user = user.next
    end
end, Debug and Debug.getLine())
