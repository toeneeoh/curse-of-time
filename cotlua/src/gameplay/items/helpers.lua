OnInit.global("ItemHelpers", function(Require)
    Require('Variables')
    Require('TableHelpers')

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
        local index = 0
        for i = 0, 5 do
            if not UnitItemInSlot(u, i) then
                index = i + 1
                break
            end
        end

        if dummy_items[index] then
            local item = CreateItem(dummy_items[index], 30000, 30000) ---@type item
            UnitAddItem(u, item)
            return item
        end
        return nil
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
        local id = Profile[pid].hero.unit_id
        if not HERO_STATS[id] then return false end
        return BlzBitAnd(HERO_STATS[id].prof, prof) ~= 0
            or prof == 0 or prof == PROF_SHIELD or prof == PROF_POTION
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
        return ItemData[itm.id][ITEM_UPGRADE_MAX] > itm.level
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

    ---@type fun(itm: item, tooltip: string)
    function ParseItemTooltip(itm, tooltip)
        local original = tooltip ~= "" and tooltip or BlzGetItemExtendedTooltip(itm)
        local item_id = GetItemTypeId(itm)
        local gmatch, gsub = string.gmatch, string.gsub

        ItemData[item_id].tooltip = original
        ItemData[item_id].path = BlzGetItemIconPath(itm)
        ItemData[item_id].name = GetItemName(itm)

        original:gsub("(%b[])", function(contents)
            contents = contents:sub(2, -2)
            local tag, suffix, value = contents:match("(%a+)([ %*])(%-?%d+%.?%d*)")
            local index

            for i = 1, #STAT_TAG do
                if STAT_TAG[i].syntax == tag then
                    index = i
                    break
                end
            end

            if index then
                ItemData[item_id][index] = tonumber(value)
                ItemData[item_id][index .. "fixed"] = (suffix == "*") and 1 or 0

                contents = contents:gsub("(#.*)", function(capture)
                    local data = capture:sub(7, #capture)
                    ItemData[item_id][index .. "id"] = FourCC(capture:sub(2, 5))
                    ItemData[item_id][index .. "data"] = data

                    for entry in gmatch(data, "(%S+)") do
                        local args = {}
                        for arg in gmatch(entry, "([^,]+)") do
                            args[#args + 1] = arg
                        end

                        if #args == 4 then
                            args[3] = gsub(args[3], "_", " ")
                            local effects = ItemData[item_id].sfx
                            if type(effects) ~= "table" then
                                effects = {}
                                ItemData[item_id].sfx = effects
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
                            ItemData[item_id][index .. "range"] = tonumber(capture)
                        elseif prefix == "=" then
                            ItemData[item_id][index .. "fpl"] = tonumber(capture)
                        elseif prefix == ">" then
                            ItemData[item_id][index .. "fpr"] = tonumber(capture)
                        elseif prefix == "%" then
                            ItemData[item_id][index .. "percent"] = tonumber(capture)
                        elseif prefix == "@" then
                            ItemData[item_id][index .. "unlock"] = tonumber(capture)
                        end
                    end)
                end
            end
        end)
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

    -- Kept for console/perk compatibility until backpack cosmetics are redesigned.
    function UpdateBackpackTooltips(pid)
        local text = ""
        local user = User[pid - 1]
        local unlocked = 0

        for j = PUBLIC_SKINS + 2, TOTAL_SKINS do
            if CosmeticTable[user.name][j] > 0 then unlocked = unlocked + 1 end
        end

        if unlocked >= 17 then
            text = "Change your backpack's appearance.\n\nUnlocked skins: |c0000ff4017/17"
        else
            text = "Change your backpack's appearance.\n\nUnlocked skins: " .. unlocked .. "/17"
        end

        if GetLocalPlayer() == user.player then
            BlzSetAbilityExtendedTooltip(FourCC('A0KX'), text, 0)
        end
    end
end)
