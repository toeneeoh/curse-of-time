--[[
    itemlookup.lua

    A library that handles item events (buying / picking up)
]]

OnInit.final("ItemLookup", function(Require)
    Require('Variables')
    Require('UnitEvent')

    ON_BUY_LOOKUP = {}
    ITEM_LOOKUP   = {}

    local function BuyItem()
        local u   = GetTriggerUnit() ---@type unit 
        local b   = GetBuyingUnit() ---@type unit 
        local pid = GetPlayerId(GetOwningPlayer(b)) + 1 ---@type integer 
        local itm = CreateItem(GetSoldItem()) ---@type Item 

        itm.owner = Player(pid - 1)

        if ON_BUY_LOOKUP[itm.id] then
            ON_BUY_LOOKUP[itm.id](u, b, pid, itm)
        end

        INVENTORY.refresh(pid)

        return false
    end

    local function PickItem()
        local u = GetTriggerUnit() ---@type unit 
        local orig_itm = GetManipulatedItem()
        local itm = Item[orig_itm] ---@type Item
        local itemid = GetItemTypeId(orig_itm)
        local itemtype = GetItemType(orig_itm)
        local p = GetOwningPlayer(u)
        local pid = GetPlayerId(p) + 1 ---@type integer 
        local U = User.first ---@type User 

        -- ignore non-player inventories / dummy cast items
        if pid > PLAYER_CAP or IsDummyCastItem(itemid) then
            return false
        end

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

        -- kill quests
        if KillQuest[itemid][0] ~= 0 and itemtype == ITEM_TYPE_CAMPAIGN then
            KillQuestHandler(pid, itemid)

        -- Buyables / Shops
        -- church donation
        elseif itemid == FourCC('I07Q') and not CHURCH_DONATION[pid] then
            ChargeNetworth(p, 0, 0.01, 100, "")
            CHURCH_DONATION[pid] = true
            donation = donation - donationrate
            DisplayTextToPlayer(p, 0, 0, "|c00408080The Goddesses bestow their blessings.")
            DisplayTextToForce(FORCE_PLAYING, "Reduced bad weather chance: " .. (R2I((1 - donation) * 100)) .. "\x25")
        -- upgrade teleports & reveal
        elseif itemid == FourCC('I101') or itemid == FourCC('I102') then
            local lvl = (itemid == FourCC('I101') and GetUnitAbilityLevel(Backpack[pid], TELEPORT.id)) or GetUnitAbilityLevel(Backpack[pid], FourCC('A0FK'))

            if lvl < 10 then -- 10 upgrade limit
                local dw ---@type DialogWindow
                local index = R2I(400. * Pow(5., lvl - 1.))

                if index > 1000000 then
                    dw = DialogWindow.create(pid, "Upgrade cost: |n|cffffffff" .. (index // 1000000) .. " |cffe3e2e2Platinum|r |cffffffffand " .. ModuloInteger(index, 1000000) .. " |cffffcc00Gold|r", BackpackUpgrades)
                else
                    dw = DialogWindow.create(pid, "Upgrade cost: |n|cffffffff" .. (index) .. " |cffffcc00Gold|r", BackpackUpgrades)
                end

                if GetCurrency(pid, GOLD) >= ModuloInteger(index, 1000000) and GetCurrency(pid, PLATINUM) >= R2I(index / 1000000) then
                    dw.data[0] = itemid
                    dw.data[1] = index
                    dw:addButton("Upgrade")
                end

                dw:display()
            end
        -- upgrade (boss) items
        elseif itemid == FourCC('I100') then
            local dw = DialogWindow.create(pid, "Choose an item to upgrade.", UpgradeItem) ---@type DialogWindow

            for index = 1, MAX_INVENTORY_SLOTS do
                local it = Profile[pid].hero.items[index]

                if it and ItemData[it.id][ITEM_UPGRADE_MAX] > it.level then
                    dw:addButton(it:name(), it)
                end
            end

            dw:display()
        end

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_PICKUP_ITEM, PickItem)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SELL_ITEM, BuyItem)
end, Debug and Debug.getLine())
