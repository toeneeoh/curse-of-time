--[[
    save_schema.lua

    Stable rawcode/index schema shared by item runtime and persistence. Indexes
    in SAVE_UNIT_TYPE are serialized and must only change through a save-version
    migration; reordering entries would reinterpret existing character data.
]]

OnInit.global("SaveSchema", function(Require)
    Require('Variables')

    MAX_SLOTS = 40

    SaveWire = {}

    ---@param slot integer
    ---@param payload string
    ---@return string
    function SaveWire.encodeCharacter(slot, payload)
        return tostring(slot) .. ":" .. payload
    end

    ---@param payload string
    ---@return integer?, string?
    function SaveWire.decodeCharacter(payload)
        local slot_string, character = payload:match("^(%d+):(.*)$")
        local slot = tonumber(slot_string)

        if not slot or slot < 1 or slot > MAX_SLOTS then
            return nil, nil
        end

        return slot, character
    end

    SAVE_TABLE = {
        KEY_ITEMS = {},
        KEY_UNITS = {},
    }

    SAVE_UNIT_TYPE = {
        HERO_ARCANIST,
        HERO_ASSASSIN,
        HERO_MARKSMAN,
        HERO_HYDROMANCER,
        HERO_PHOENIX_RANGER,
        HERO_ELEMENTALIST,
        HERO_HIGH_PRIEST,
        HERO_MASTER_ROGUE,
        HERO_SAVIOR,
        HERO_BARD,
        HERO_CRUSADER,
        HERO_BLOODZERKER,
        HERO_DARK_SAVIOR,
        HERO_DARK_SUMMONER,
        HERO_OBLIVION_GUARD,
        HERO_ROYAL_GUARDIAN,
        HERO_THUNDERBLADE,
        HERO_WARRIOR,
        FourCC('H00H'),
        HERO_DRUID,
        HERO_VAMPIRE,
    }

    for index = 1, #SAVE_UNIT_TYPE do
        SAVE_TABLE.KEY_UNITS[SAVE_UNIT_TYPE[index]] = index
    end
end, Debug and Debug.getLine())
