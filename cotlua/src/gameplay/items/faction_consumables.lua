-- Saveable one-use faction tools activated through native or context actions.
OnInit.final("FactionConsumables", function(Require)
    Require('ItemUse')
    Require('RuntimeItemDefinitions')
    Require('Spells')

    FactionConsumables = {}
    local STORMWISE_BEACON_KEY = "stormwise_beacon"
    local GOBLIN_SPACE_LASER_KEY = "goblin_space_laser"
    local REINFORCED_PIT_PROP_KEY = "reinforced_pit_prop"
    local SEISMIC_SURVEY_CHARGE_KEY = "seismic_survey_charge"
    local CAMPAIGN_STANDARD_KEY = "campaign_standard"
    local VANGUARD_BOUNTY_KEY = "vanguard_bounty"
    local VANGUARD_BOUNTY_ABILITY_ID = FourCC('A1VB')

    FactionConsumables.STORMWISE_BEACON_KEY = STORMWISE_BEACON_KEY
    FactionConsumables.GOBLIN_SPACE_LASER_KEY = GOBLIN_SPACE_LASER_KEY
    FactionConsumables.REINFORCED_PIT_PROP_KEY = REINFORCED_PIT_PROP_KEY
    FactionConsumables.SEISMIC_SURVEY_CHARGE_KEY =
        SEISMIC_SURVEY_CHARGE_KEY
    FactionConsumables.CAMPAIGN_STANDARD_KEY = CAMPAIGN_STANDARD_KEY
    FactionConsumables.VANGUARD_BOUNTY_KEY = VANGUARD_BOUNTY_KEY
    FactionConsumables.VANGUARD_BOUNTY_ABILITY_ID =
        VANGUARD_BOUNTY_ABILITY_ID
    local definitions = {}

    local function define(key, id, name, icon, world_skin, required_rank,
                          skill_name, description, flavor, ability_id)
        if ability_id then
            BlzSetAbilityExtendedTooltip(
                ability_id,
                "|cff0080c0" .. skill_name .. ":|r " .. description, 0)
        end
        definitions[key] = RuntimeItemDefinitions.define(key, {
            id = id,
            carrier = FourCC('I00K'),
            world_skin = world_skin,
            name = name,
            icon = icon,
            tooltip = ability_id and "|cff808080" .. flavor .. "|r" or
                "|cff0080c0" .. skill_name .. ":|r " .. description ..
                    "|n|cff808080" .. flavor .. "|r",
            item_type = TYPE_CONSUMABLE_INDEX,
            faction_rank_requirement = required_rank,
            prepare_data = function(data)
                data[ITEM_TIER] = 1
                data[ITEM_TIER .. "fixed"] = 1
                data[ITEM_NOCRAFT] = 1
                data[ITEM_NOCRAFT .. "fixed"] = 1
                data[ITEM_LIMIT] = 1
                data[ITEM_LIMIT .. "fixed"] = 1
                if ability_id then
                    data[ITEM_ABILITY] = 1
                    data[ITEM_ABILITY .. "fixed"] = 1
                    data[ITEM_ABILITY .. "id"] = ability_id
                    data[ITEM_ABILITY .. "data"] = ""
                    data[ITEM_ABILITY .. "unlock"] = 0
                end
            end
        })
    end

    define(STORMWISE_BEACON_KEY, 100, "Stormwise Beacon",
           "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp",
           FourCC('tels'),
           4, "Stormwise Beacon",
           "Shares your current Stormwatch blessing with allied heroes for |cffffcc005 minutes|r.",
           "Its needle turns toward favorable skies, however distant they may be.")
    define(GOBLIN_SPACE_LASER_KEY, 101, "Goblin Space Laser",
           "ReplaceableTextures\\CommandButtons\\BTNClusterRockets.blp",
           FourCC('gobm'),
           2, "Atmospheric Correction",
           "Rerolls the current weather.",
           "The warranty insists that weather is a perfectly valid target.")
    define(REINFORCED_PIT_PROP_KEY, 102, "Reinforced Pit Prop",
           "ReplaceableTextures\\CommandButtons\\BTNBundleOfLumber.blp",
           FourCC('lmbr'),
           4, "Reinforced Support",
           "Shares your current Cave Voyagers blessing with allied heroes for |cffffcc005 minutes|r.",
           "Tested underground under conditions best described as excessive.")
    define(SEISMIC_SURVEY_CHARGE_KEY, 103, "Seismic Survey Charge",
           "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp",
           FourCC('gobm'),
           2, "Seismic Survey",
           "Relocates every unclaimed ore deposit currently in the world.",
           "A precise instrument, provided nobody asks precise questions.")
    define(CAMPAIGN_STANDARD_KEY, 104, "Campaign Standard",
           "ReplaceableTextures\\CommandButtons\\BTNHumanCaptureFlag.blp",
           FourCC('flag'),
           4, "Rallying Standard",
           "Shares your current Ashen Vanguard blessing with allied heroes for |cffffcc005 minutes|r.",
           "Its scars recount victories more faithfully than any ledger.")
    define(VANGUARD_BOUNTY_KEY, 105, "Vanguard Bounty",
           "ReplaceableTextures\\CommandButtons\\BTNMarkOfFire.blp",
           FourCC('flag'),
           4, "Marked Bounty",
           "Marks a boss above |cffffcc0090% Health|r, increasing its |cffff8040Boss Drop Rate|r by |cffffcc0025%|r until it dies or retreats.",
           "The Vanguard's seal promises richer spoils to whoever claims its mark.",
           VANGUARD_BOUNTY_ABILITY_ID)

    local function register(key, action)
        ItemUse.registerRuntime(key, {
            use = function(pid, item)
                if not action(pid) then return false end
                item:destroy()
                return true
            end
        })
    end

    register(STORMWISE_BEACON_KEY, function(pid)
        return StormwatchServices and StormwatchServices.shareBlessing(pid)
    end)
    register(GOBLIN_SPACE_LASER_KEY, function(pid)
        return StormwatchServices and StormwatchServices.rerollWeather(pid)
    end)
    register(REINFORCED_PIT_PROP_KEY, function(pid)
        return CaveVoyagersServices and
                   CaveVoyagersServices.shareBlessing(pid)
    end)
    register(SEISMIC_SURVEY_CHARGE_KEY, function(pid)
        return CaveVoyagersServices and
                   CaveVoyagersServices.rerollDeposits(pid)
    end)
    register(CAMPAIGN_STANDARD_KEY, function(pid)
        return AshenVanguardServices and
                   AshenVanguardServices.shareBlessing(pid)
    end)
    local MARK_BOUNTY = Spell.define('A1VB')
    MARK_BOUNTY.ACTIVE = true
    do
        local thistype = MARK_BOUNTY

        local function find_bounty(pid)
            local profile = Profile[pid]
            local items = profile and profile.hero and profile.hero.items
            if not items then return nil end
            for slot = 1, MAX_INVENTORY_SLOTS do
                local item = items[slot]
                if RuntimeItemDefinitions.is(item, VANGUARD_BOUNTY_KEY) then
                    return item
                end
            end
            return nil
        end

        function thistype:onCast()
            local item = find_bounty(self.pid)
            if not item then
                DisplayTextToPlayer(self.owner, 0., 0.,
                                    "|cffff0000You no longer possess a Vanguard Bounty.|r")
                return
            end
            if AshenVanguardServices and
                AshenVanguardServices.markBoss(self.pid, self.target) then
                item:destroy()
            end
        end
    end

    function FactionConsumables.create(key, pid)
        local hero = Hero[pid]
        if not hero then return false end
        local item = RuntimeItemDefinitions.create(
                         key, GetUnitX(hero), GetUnitY(hero))
        if not item then return false end
        PlayerAddItem(pid, item)
        return true
    end

    ---Checks both carried inventory and stash so a unique faction tool cannot
    ---be hidden in storage to bypass its purchase restriction.
    ---@param pid integer
    ---@param key string
    ---@return boolean
    function FactionConsumables.has(pid, key)
        local profile = Profile[pid]
        local hero = profile and profile.hero
        if not hero then return false end
        for slot = 1, MAX_INVENTORY_SLOTS do
            if RuntimeItemDefinitions.is(hero.items[slot], key) then
                return true
            end
        end
        local stash = hero.stash
        for slot = 1, MAX_STASH_SLOTS do
            if stash and RuntimeItemDefinitions.is(stash[slot], key) then
                return true
            end
        end
        return false
    end

    ---Returns the same name, icon, and base tooltip used by the actual item.
    function FactionConsumables.getCatalogPresentation(key)
        local definition = definitions[key]
        if not definition then return nil, nil, nil end
        local item = RuntimeItemDefinitions.create(key, 30000., 30000.)
        if not item then return nil, nil, nil end
        local name = GetItemName(item.obj)
        local icon = BlzGetItemIconPath(item.obj)
        local tooltip = item.tooltip or BlzGetItemDescription(item.obj)
        item:destroy()
        return name, icon, tooltip
    end
end, Debug and Debug.getLine())
