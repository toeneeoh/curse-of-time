--[[
    save_schema.lua

    Stable rawcode/index schema shared by item runtime and persistence. Indexes
    in SAVE_UNIT_TYPE are serialized and must only change through a save-version
    migration; reordering entries would reinterpret existing character data.
]]

OnInit.global("SaveSchema", function(Require)
    Require('Variables')

    MAX_SLOTS = 40
    PROFILE_PERK_SLOTS = 8
    -- Thirty allocation bits per word keeps profile values within a safe
    -- positive integer range. Extra words are appended to the profile tail;
    -- earlier profiles load absent words as zero without shifting old fields.
    PROFILE_PERK_NODE_WORDS = 8
    -- Keep native sync messages comfortably below the engine's small payload
    -- ceiling. FileIO itself may contain much larger character codes.
    local SYNC_CHUNK_DATA_SIZE = 200
    local MAX_SYNC_CHUNKS = 256

    SaveWire = {}

    local function split_payload(payload)
        payload = payload or ""
        local total = math.max(1,
            math.ceil(payload:len() / SYNC_CHUNK_DATA_SIZE))
        if total > MAX_SYNC_CHUNKS then return nil end

        local chunks = {}
        for index = 1, total do
            local first = (index - 1) * SYNC_CHUNK_DATA_SIZE + 1
            chunks[index] = payload:sub(first,
                first + SYNC_CHUNK_DATA_SIZE - 1)
        end
        return chunks
    end

    ---Splits a profile code into independently safe native-sync messages.
    ---@param payload string
    ---@return string[]?
    function SaveWire.encodeProfile(payload)
        local parts = split_payload(payload)
        if not parts then return nil end
        local messages = {}
        for index = 1, #parts do
            messages[index] = index .. ":" .. #parts .. ":" .. parts[index]
        end
        return messages
    end

    ---@param message string
    ---@return integer?, integer?, string?
    function SaveWire.decodeProfile(message)
        local index, total, payload =
            message:match("^(%d+):(%d+):(.*)$")
        index, total = tonumber(index), tonumber(total)
        if not index or not total or total < 1 or total > MAX_SYNC_CHUNKS or
            index < 1 or index > total or payload:len() >
            SYNC_CHUNK_DATA_SIZE then
            return nil, nil, nil
        end
        return index, total, payload
    end

    ---@param slot integer
    ---@param payload string
    ---@return string[]?
    function SaveWire.encodeCharacter(slot, payload)
        if slot < 1 or slot > MAX_SLOTS then return nil end
        local parts = split_payload(payload)
        if not parts then return nil end
        local messages = {}
        for index = 1, #parts do
            messages[index] = slot .. ":" .. index .. ":" .. #parts .. ":" ..
                                  parts[index]
        end
        return messages
    end

    ---@param payload string
    ---@return integer?, integer?, integer?, string?
    function SaveWire.decodeCharacter(payload)
        local slot, index, total, character =
            payload:match("^(%d+):(%d+):(%d+):(.*)$")
        slot, index, total = tonumber(slot), tonumber(index), tonumber(total)

        if not slot or slot < 1 or slot > MAX_SLOTS or not index or not total or
            total < 1 or total > MAX_SYNC_CHUNKS or index < 1 or index > total or
            character:len() > SYNC_CHUNK_DATA_SIZE then
            return nil, nil, nil, nil
        end

        return slot, index, total, character
    end

    ---Adds one decoded chunk to an assembly table. Chunks may arrive in any
    ---order; duplicates are harmless. A conflicting stream is rejected.
    ---@param assemblies table
    ---@param key integer|string
    ---@param index integer
    ---@param total integer
    ---@param payload string
    ---@return string?, boolean
    function SaveWire.accept(assemblies, key, index, total, payload)
        local assembly = assemblies[key]
        if not assembly then
            assembly = {total = total, count = 0, parts = {}}
            assemblies[key] = assembly
        elseif assembly.total ~= total then
            assemblies[key] = nil
            return nil, false
        end

        local previous = assembly.parts[index]
        if previous and previous ~= payload then
            assemblies[key] = nil
            return nil, false
        elseif not previous then
            assembly.parts[index] = payload
            assembly.count = assembly.count + 1
        end

        if assembly.count ~= total then return nil, true end
        local result = table.concat(assembly.parts)
        assemblies[key] = nil
        return result, true
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
