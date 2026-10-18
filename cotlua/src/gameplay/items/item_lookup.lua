--[[
    item_lookup.lua

    A library that handles item events (buying / picking up)
]]

OnInit.final("ItemLookup", function(Require)
    Require('Variables')
    Require('UnitEvent')
    Require('ItemEventRegistry')
    Require('Items')

    ItemLookup = {}

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

    ---Shared native acquisition path, including the secondary inventory slot.
    ---Never call from local UI code; the engine validates pickup range.
    ---@param u unit
    ---@param orig_itm item
    ---@param native_pickup boolean
    ---@return boolean
    function ItemLookup.collect(u, orig_itm, native_pickup)
        if LootService and native_pickup and LootService.consumeProxy(u, orig_itm) then return true end
        local itemid = GetItemTypeId(orig_itm)
        local p = GetOwningPlayer(u)
        local pid = GetPlayerId(p) + 1 ---@type integer

        -- ignore non-player inventories / dummy cast items
        if IsDummyCastItem(itemid) then
            if native_pickup then ItemRuntime.guardNativeItem(orig_itm, u) end
            return false
        end
        if pid > PLAYER_CAP or not Profile[pid] or not Profile[pid].hero then
            return false
        end

        local automatic = BlzGetItemBooleanField(orig_itm, ITEM_BF_USE_AUTOMATICALLY_WHEN_ACQUIRED)
        if automatic and not native_pickup then return false end
        local itm = ItemRuntime.wrap(orig_itm) ---@type Item
        if native_pickup then itm.pickup_receipt = (itm.pickup_receipt or 0) + 1 end

        -- Hidden inventories are not exposed by the unit-slot API. Positioning
        -- the item itself releases it from either inventory, before validation
        -- or equip creates a visible carrier. Rejected items stay at the hero.
        if native_pickup then
            SetItemPosition(itm.obj, GetUnitX(u), GetUnitY(u))
        end

        if not automatic then
            local previous_pid = itm.pid
            itm.pid = pid
            if not itm:equip(nil, u) then
                -- equip already explains invalid level/binding/type; explain
                -- a lack of compatible free slots here as well.
                local available = false
                for slot = 1, MAX_INVENTORY_SLOTS do
                    if not Profile[pid].hero.items[slot] and VerifySlotForType(slot, itm.type) then
                        available = true
                        break
                    end
                end
                if not available then
                    DisplayTimedTextToPlayer(p, 0, 0, 5., "|cffff5555Your inventory is full.|r")
                end
                itm.pid = previous_pid
                return false
            end
        end

        -- check item lookup table
        if ITEM_LOOKUP[itemid] then
            ITEM_LOOKUP[itemid](p, pid, u, itm)
        end

        return true
    end

    local function PickItem()
        ItemLookup.collect(GetTriggerUnit(), GetManipulatedItem(), true)
        return false
    end

    local function DropItem()
        local item = GetManipulatedItem()
        if IsDummyCastItem(GetItemTypeId(item)) then
            ItemRuntime.guardNativeItem(item, GetTriggerUnit())
        end
        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_PICKUP_ITEM, PickItem)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DROP_ITEM, DropItem)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SELL_ITEM, BuyItem)
end, Debug and Debug.getLine())
