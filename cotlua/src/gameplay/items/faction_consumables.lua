-- Saveable one-use faction tools activated through the inventory context menu.
OnInit.final("FactionConsumables", function(Require)
    Require('ItemUse')
    Require('RuntimeItemDefinitions')

    FactionConsumables = {}
    local STORMWISE_BEACON_KEY = "stormwise_beacon"
    local GOBLIN_SPACE_LASER_KEY = "goblin_space_laser"
    local REINFORCED_PIT_PROP_KEY = "reinforced_pit_prop"
    local SEISMIC_SURVEY_CHARGE_KEY = "seismic_survey_charge"
    local CAMPAIGN_STANDARD_KEY = "campaign_standard"

    FactionConsumables.STORMWISE_BEACON_KEY = STORMWISE_BEACON_KEY
    FactionConsumables.GOBLIN_SPACE_LASER_KEY = GOBLIN_SPACE_LASER_KEY
    FactionConsumables.REINFORCED_PIT_PROP_KEY = REINFORCED_PIT_PROP_KEY
    FactionConsumables.SEISMIC_SURVEY_CHARGE_KEY =
        SEISMIC_SURVEY_CHARGE_KEY
    FactionConsumables.CAMPAIGN_STANDARD_KEY = CAMPAIGN_STANDARD_KEY
    local definitions = {}

    local function define(key, id, name, icon, world_skin, description, flavor)
        definitions[key] = RuntimeItemDefinitions.define(key, {
            id = id,
            carrier = FourCC('I00K'),
            world_skin = world_skin,
            name = name,
            icon = icon,
            tooltip = "|cff0080c0Use:|r " .. description ..
                "|n|cff808080" .. flavor .. "|r",
            item_type = TYPE_CONSUMABLE_INDEX,
            prepare_data = function(data)
                data[ITEM_NOCRAFT] = 1
                data[ITEM_NOCRAFT .. "fixed"] = 1
                data[ITEM_LIMIT] = 1
                data[ITEM_LIMIT .. "fixed"] = 1
            end
        })
    end

    define(STORMWISE_BEACON_KEY, 100, "Stormwise Beacon",
           "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp",
           FourCC('tels'),
           "Shares your current Stormwatch blessing with allied heroes for |cffffcc005 minutes|r.",
           "Its needle turns toward favorable skies, however distant they may be.")
    define(GOBLIN_SPACE_LASER_KEY, 101, "Goblin Space Laser",
           "ReplaceableTextures\\CommandButtons\\BTNClusterRockets.blp",
           FourCC('gobm'),
           "Rerolls the current weather.",
           "The warranty insists that weather is a perfectly valid target.")
    define(REINFORCED_PIT_PROP_KEY, 102, "Reinforced Pit Prop",
           "ReplaceableTextures\\CommandButtons\\BTNBundleOfLumber.blp",
           FourCC('lmbr'),
           "Shares your current Cave Voyagers blessing with allied heroes for |cffffcc005 minutes|r.",
           "Tested underground under conditions best described as excessive.")
    define(SEISMIC_SURVEY_CHARGE_KEY, 103, "Seismic Survey Charge",
           "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp",
           FourCC('gobm'),
           "Relocates every unclaimed ore deposit currently in the world.",
           "A precise instrument, provided nobody asks precise questions.")
    define(CAMPAIGN_STANDARD_KEY, 104, "Campaign Standard",
           "ReplaceableTextures\\CommandButtons\\BTNHumanCaptureFlag.blp",
           FourCC('flag'),
           "Shares your current Ashen Vanguard blessing with allied heroes for |cffffcc005 minutes|r.",
           "Its scars recount victories more faithfully than any ledger.")

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

    function FactionConsumables.create(key, pid)
        local hero = Hero[pid]
        if not hero then return false end
        local item = RuntimeItemDefinitions.create(
                         key, GetUnitX(hero), GetUnitY(hero))
        if not item then return false end
        PlayerAddItem(pid, item)
        return true
    end

    ---Returns the same name, icon, and base tooltip used by the actual item.
    function FactionConsumables.getCatalogPresentation(key)
        local definition = definitions[key]
        if not definition then return nil, nil, nil end
        return definition.name, definition.icon, definition.tooltip
    end
end, Debug and Debug.getLine())
