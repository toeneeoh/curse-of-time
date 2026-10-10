OnInit.global("ItemHelpers", function(Require)
    Require('HeroDefinitions')
    Require('Variables')
    Require('TableHelpers')
    Require('Users')

    local dummy_items = {
        FourCC('I00D'),
        FourCC('I00M'),
        FourCC('I028'),
        FourCC('I02K'),
        FourCC('I01B'),
        FourCC('I027'),
    }

    ---@type fun(pid: integer, id: integer): boolean
    function PlayerHasItemType(pid, id)
        for i = 1, MAX_INVENTORY_SLOTS do
            local item = Profile[pid].hero.items[i]
            if item and item.id == id then return true end
        end
        return false
    end

    ---@param id integer
    ---@return integer|false
    function IsDummyCastItem(id)
        return TableHas(dummy_items, id)
    end

    ---@param u unit
    ---@return item?
    function MakeDummyCastItem(u)
        local used_ids = {}
        local has_space = false
        for i = 0, 5 do
            local existing = UnitItemInSlot(u, i)
            if existing then
                used_ids[GetItemTypeId(existing)] = true
            else
                has_space = true
            end
        end

        if has_space then
            -- Position and cooldown identity are independent. A rearranged
            -- carrier must not cause another copy of its dummy ID to spawn.
            for _, id in ipairs(dummy_items) do
                if not used_ids[id] then
                    local item = CreateItem(id, 30000, 30000) ---@type item
                    LockDummyCastItem(item)
                    if UnitAddItem(u, item) then return item end
                    RemoveItem(item)
                    return nil
                end
            end
        end
        return nil
    end

    ---Reapply both gameplay flags and object boolean fields after setup.
    ---@param item item
    function LockDummyCastItem(item)
        SetItemDroppable(item, false)
        SetItemPawnable(item, false)
        SetItemDropOnDeath(item, false)
        BlzSetItemBooleanField(item, ITEM_BF_CAN_BE_DROPPED, false)
        BlzSetItemBooleanField(item, ITEM_BF_DROPPED_WHEN_CARRIER_DIES, false)
    end

    ---@param pid integer
    ---@param charge boolean
    ---@return Item?
    function GetResurrectionItem(pid, charge)
        local items = Profile[pid].hero.items

        for i = 1, 6 do
            local item = items[i]
            if item and (item.abil == FourCC('Arrv') or item.abil == FourCC('Anrv')) then
                if charge and item.abil == FourCC('Arrv') then
                    return item
                elseif not charge and item.charges > 0 then
                    return item
                end
            end
        end

        if charge then
            for i = 1, 6 do
                local item = items[i]
                if item and (item.abil == FourCC('Arrv') or item.abil == FourCC('Anrv')) then
                    if charge and item.abil == FourCC('Arrv') then
                        return item
                    elseif not charge and item.charges > 0 then
                        return item
                    end
                end
            end
        end
        return nil
    end

    ---@type fun(pid: integer, prof: integer): boolean
    function HasProficiency(pid, prof)
        -- Prefer the live hero type. Persisted unit_id is a load-time DTO field
        -- and may be stale while a character is being created or replaced.
        local hero = Hero[pid]
        local id = hero and GetUnitTypeId(hero)
            or (Profile[pid] and Profile[pid].hero and Profile[pid].hero.unit_id)
        if not HERO_STATS[id] then return false end
        return BlzBitAnd(HERO_STATS[id].prof, prof) ~= 0
            or prof == 0 or prof == PROF_SHIELD or prof == PROF_POTION or
                   prof == PROF_CONSUMABLE
    end

    ---@type fun(id: integer, pid: integer): number
    function ItemProfMod(id, pid)
        local prof = ItemData[id][ITEM_TYPE]
        return (HasProficiency(pid, PROF[prof]) and 1) or 0.75
    end

    ---@type fun(itemid: integer): integer|nil
    function ItemToIndex(itemid)
        return SAVE_TABLE.KEY_ITEMS[itemid]
    end

    ---@type fun(u: unit, id: integer): Item
    function UnitAddItemById(u, id)
        local item = ItemRuntime.create(id, GetUnitX(u), GetUnitY(u))
        UnitAddItem(u, item.obj)
        return item
    end

    ---@type fun(pid: integer, itm: Item)
    function PlayerAddItem(pid, itm)
        itm.owner = Player(pid - 1)
        itm.pid = pid

        if GetItemType(itm.obj) == ITEM_TYPE_POWERUP then
            UnitAddItem(Hero[pid], itm.obj)
        elseif not itm:equip() then
            SetItemPosition(itm.obj, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        end
    end

    ---@type fun(itm: Item): boolean
    function ItemIsUpgradeable(itm)
        return (itm.data or ItemData[itm.id])[ITEM_UPGRADE_MAX] > itm.level
    end

    ---@type fun(pid: integer, id: string|integer): Item
    function PlayerAddItemById(pid, id)
        local _, rawcode, level = GetItem(id)
        local item = ItemRuntime.create(rawcode, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        item.owner = Player(pid - 1)
        item.pid = pid

        if GetItemType(item.obj) == ITEM_TYPE_POWERUP then
            UnitAddItem(Hero[pid], item.obj)
        else
            if level > 0 then item:lvl(level) end
            item:equip()
        end
        return item
    end

    ---Parses the standard bracket-formula format into an item data table.
    ---Runtime definitions use this same path as object-editor items so their
    ---stats and generated tooltips cannot drift into a separate format.
    ---@param name string
    ---@param path string
    ---@param tooltip string
    ---@return table data
    function ParseItemDefinition(name, path, tooltip)
        local data = __jarray(0)
        local original = tooltip or ""
        local gmatch, gsub = string.gmatch, string.gsub

        data.tooltip = original
        data.path = path
        data.name = name
        local legacy_spellboost = false

        original:gsub("(%b[])", function(contents)
            contents = contents:sub(2, -2)
            local tag, suffix, value = contents:match("(%a+)([ %*])(%-?%d+%.?%d*)")
            if tag == "spellboost" then
                legacy_spellboost = true
                tag = "spellpower"
            end
            local index

            for i = 1, #STAT_TAG do
                if STAT_TAG[i].syntax == tag then
                    index = i
                    break
                end
            end

            if index then
                data[index] = tonumber(value)
                data[index .. "fixed"] = (suffix == "*") and 1 or 0

                contents = contents:gsub("(#.*)", function(capture)
                    local arguments = capture:sub(7, #capture)
                    data[index .. "id"] = FourCC(capture:sub(2, 5))
                    data[index .. "data"] = arguments

                    for entry in gmatch(arguments, "(%S+)") do
                        local args = {}
                        for arg in gmatch(entry, "([^,]+)") do
                            args[#args + 1] = arg
                        end

                        if #args == 4 then
                            args[3] = gsub(args[3], "_", " ")
                            local effects = data.sfx
                            if type(effects) ~= "table" then
                                effects = {}
                                data.sfx = effects
                            end
                            effects[#effects + 1] = {
                                level = args[2],
                                attach = args[3],
                                path = args[4],
                            }
                        end
                    end
                    return ""
                end)

                local affix = "([|=>%@])(%-?%d+%.?%d*)"
                local start = contents:find(affix)
                if start then
                    contents = contents:sub(start)
                    gsub(contents, affix, function(prefix, capture)
                        if prefix == "|" then
                            data[index .. "range"] = tonumber(capture)
                        elseif prefix == "=" then
                            data[index .. "fpl"] = tonumber(capture)
                        elseif prefix == ">" then
                            data[index .. "fpr"] = tonumber(capture)
                        elseif prefix == "%" then
                            data[index .. "percent"] = tonumber(capture)
                        elseif prefix == "@" then
                            data[index .. "unlock"] = tonumber(capture)
                        end
                    end)
                end
            end
        end)

        -- Old generic sets now grant power only. Other existing Spellboost
        -- items retain their utility until individually redesigned. New
        -- spellpower formulas never implicitly grant area or duration.
        if legacy_spellboost and data[ITEM_TIER] ~= 8 and
            data[ITEM_TIER] ~= 22 then
            data.legacy_spell_utility = {}
            for _, stat in ipairs({ITEM_SPELL_AREA, ITEM_SPELL_DURATION}) do
                local syntax = STAT_TAG[stat].syntax
                if not original:find("[" .. syntax, 1, true) then
                    data.legacy_spell_utility[stat] = true
                    data[stat] = data[ITEM_SPELLBOOST] * 0.5
                    for _, property in ipairs({"range", "fpl", "fpr"}) do
                        data[stat .. property] = data[ITEM_SPELLBOOST .. property] * 0.5
                    end
                    for _, property in ipairs({"fixed", "percent", "unlock"}) do
                        data[stat .. property] = data[ITEM_SPELLBOOST .. property]
                    end
                end
            end
        end
        return data
    end

    ---@type fun(itm: item, tooltip: string)
    function ParseItemTooltip(itm, tooltip)
        local original = tooltip ~= "" and tooltip or BlzGetItemExtendedTooltip(itm)
        local item_id = GetItemTypeId(itm)
        ItemData[item_id] = ParseItemDefinition(
            GetItemName(itm), BlzGetItemIconPath(itm), original)
    end

    ---Handles `I000:0` item keys and legacy integer rawcodes.
    ---@type fun(id: string|integer): string, integer, integer
    function GetItem(id)
        local variation = 0
        local rawcode = id

        if type(id) == "string" then
            variation = tonumber(id:sub(6)) or 0
            rawcode = FourCC(id:sub(1, 4))
        end

        ---@cast rawcode integer
        return string.pack(">I4", rawcode) .. ":" .. variation, rawcode, variation
    end

    ---@type fun(pid: integer, id: string|integer, count: integer?): Item|nil
    function GetItemFromPlayer(pid, id, count)
        local _, rawcode, level = GetItem(id)
        count = count or 1

        for i = 1, MAX_INVENTORY_SLOTS do
            local item = Profile[pid].hero.items[i]
            if item and item.id == rawcode and (item.level == level or level == -1) then
                if count <= 1 then return item end
                count = count - 1
            end
        end
        return nil
    end

    -- Kept as a global because the backpack ability tooltip may be refreshed by
    -- console commands and future reward screens.
    function UpdateBackpackTooltips(pid)
        local user = User[pid - 1]
        local unlocked, total = Cosmetics.getBackpackProgress(pid)
        local count = unlocked >= total and "|c0000ff40" .. unlocked .. "/" .. total .. "|r"
            or unlocked .. "/" .. total
        local text = "Change your backpack's appearance.\n\nHonor skins unlocked: " .. count

        if GetLocalPlayer() == user.player then
            BlzSetAbilityExtendedTooltip(FourCC('A0KX'), text, 0)
        end
    end
end)
