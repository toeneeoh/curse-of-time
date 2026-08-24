--[[
    itemlookup.lua

    A library that handles item events (buying / picking up)
]]

OnInit.final("ItemLookup", function(Require)
    Require('Variables')
    Require('UnitEvent')
    Require('ItemEventRegistry')
    Require('Items')

    local function BuyItem()
        local u   = GetTriggerUnit() ---@type unit
        local b   = GetBuyingUnit() ---@type unit
        local pid = GetPlayerId(GetOwningPlayer(b)) + 1 ---@type integer
        local itm = ItemRuntime.wrap(GetSoldItem()) ---@type Item

        itm.owner = Player(pid - 1)

        if ON_BUY_LOOKUP[itm.id] then
            ON_BUY_LOOKUP[itm.id](u, b, pid, itm)
        end

        NotifyItemChanged(pid)

        return false
    end

    local function PickItem()
        local u = GetTriggerUnit() ---@type unit
        local orig_itm = GetManipulatedItem()
        local itemid = GetItemTypeId(orig_itm)
        local p = GetOwningPlayer(u)
        local pid = GetPlayerId(p) + 1 ---@type integer

        -- ignore non-player inventories / dummy cast items
        if pid > PLAYER_CAP or IsDummyCastItem(itemid) then
            return false
        end

        local itm = ItemRuntime.wrap(orig_itm) ---@type Item

        -- items are always dropped now
        UnitRemoveItem(u, itm.obj)

        if BlzGetItemBooleanField(itm.obj, ITEM_BF_USE_AUTOMATICALLY_WHEN_ACQUIRED) == false then
            itm.pid = pid
            itm:equip(nil, u)
        end

        -- check item lookup table
        if ITEM_LOOKUP[itemid] then
            ITEM_LOOKUP[itemid](p, pid, u, itm)
        end

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_PICKUP_ITEM, PickItem)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SELL_ITEM, BuyItem)
end, Debug and Debug.getLine())
