-- Faction membership, units, quest selection, and quest state.

OnInit.final("Faction", function(Require)
    Require('Events')
    Require('Buffs')
    Require('FactionShop')
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
    local view ---@type FactionViewAdapter?

    ---@class Faction
    ---@field name string
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
    Quest = {}
    Quest.__index = Quest
    Quest.quests = {}

    local quest_count = 1
    local pending_quest = {}
    local active_quest = {}

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
        pending_faction[pid] = nil
        DisplayTextToForce(
            FORCE_PLAYING,
            User[pid - 1].nameColored .. " has joined the " .. faction.name .. "!"
        )
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

        if not player_faction[pid] then
            if view and view.promptJoin(faction, pid, join_faction) then
                pending_faction[pid] = faction
            end
        else
            display_faction(player_faction[pid], pid)
        end
    end

    ---@param name string
    ---@param x number
    ---@param y number
    ---@param buff Buff
    ---@param desc string
    ---@return Faction
    function Faction.create(name, x, y, buff, desc)
        local self = setmetatable({
            leader = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), faction_leader_type, x, y, 270.),
            shop = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), faction_shop_type, x + 500., y, 270.),
            name = name,
            quests = {},
            buff = buff,
            desc = desc,
        }, Faction)

        EVENT_ON_UNIT_SELECT:register_unit_action(self.leader, on_faction_selected)
        Faction[self.leader] = self
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
        for difficulty = 1, 3 do
            local quest = self:pickQuest(difficulty)
            Quest.quests[pid][difficulty] = quest
            if view then
                view.refreshQuest(pid, difficulty, quest)
            end
        end
    end

    ---@param name string
    ---@param desc string
    ---@param icon string
    ---@param difficulty integer
    ---@return Quest
    function Quest.create(name, desc, icon, difficulty)
        local self = setmetatable({
            id = quest_count,
            name = name,
            desc = desc,
            icon = icon,
            diff = difficulty,
        }, Quest)
        Quest[quest_count] = self
        quest_count = quest_count + 1
        return self
    end

    ---@param pid integer
    function Quest:on_accept(pid)
        print("quest accepted:", self.name, pid)
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

    ---@param pid integer
    ---@param index integer
    function Quest.select(pid, index)
        local quest = Quest.quests[pid] and Quest.quests[pid][index]
        if quest and not active_quest[pid]
            and view and view.promptQuest(quest, pid, accept_quest) then
            pending_quest[pid] = quest
        end
    end

    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3
    local miner_guild = Faction.create(
        "Cave Voyagers",
        15000,
        10500,
        HardHatBuff,
        "The Cave Voyagers are a mining faction that provide access to earth materials and a special defensive buff.|n|n|cffff0000All faction progress is saved and you may leave after 60 minutes.|r|n|nWill you join us?"
    )
    miner_guild:addQuest(Quest.create(
        "Enter Colosseum",
        "Your task is complete upon entering the Colosseum located in town.",
        "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp",
        QUEST_DIFF_EASY
    ))
    miner_guild:addQuest(Quest.create(
        "Temp medium",
        "Your task is blablablablablablablal",
        "ReplaceableTextures\\CommandButtons\\BTNTemp.blp",
        QUEST_DIFF_MEDIUM
    ))
    miner_guild:addQuest(Quest.create(
        "Temp hard",
        "Your task is blbalbalbalbalbalbalbal",
        "ReplaceableTextures\\CommandButtons\\BTNTemp.blp",
        QUEST_DIFF_HARD
    ))
end, Debug and Debug.getLine())
