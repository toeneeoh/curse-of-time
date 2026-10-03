-- Saveable, town-managed item storage.
OnInit.final("StashService", function(Require)
    Require('Profile')
    Require('Currency')
    Require('Items')
    Require('ItemEventRegistry')
    Require('Audio')
    Require('Town')

    StashService = {}

    local BASE_ROW_PRICE = 1000000
    local ROW_PRICE_MULTIPLIER = 5
    local changed_actions = {}

    local function result(ok, code)
        return {ok = ok, code = code}
    end

    local function hero_data(pid)
        local profile = Profile[pid]
        return profile and profile.hero or nil
    end

    local function unlocked_slots(hero)
        return math.max(1, math.min(STASH_MAX_ROWS, hero.stash_rows or 1)) *
                   STASH_COLUMNS
    end

    local function notify(pid)
        for index = 1, #changed_actions do changed_actions[index](pid) end
        NotifyItemChanged(pid)
    end

    function StashService.registerChangedAction(action)
        changed_actions[#changed_actions + 1] = action
    end

    function StashService.isInTown(pid)
        return Town.isPlayerInTown(pid)
    end

    function StashService.getUnlockedSlots(pid)
        local hero = hero_data(pid)
        return hero and unlocked_slots(hero) or 0
    end

    function StashService.getRowPrice(row)
        if row < 2 or row > STASH_MAX_ROWS then return 0 end
        return math.floor(BASE_ROW_PRICE *
                              ROW_PRICE_MULTIPLIER ^ (row - 2))
    end

    function StashService.quoteRow(pid)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        local current = math.max(1,
            math.min(STASH_MAX_ROWS, hero.stash_rows or 1))
        if current >= STASH_MAX_ROWS then return result(false, "maxed") end
        local quote = result(true, "available")
        quote.row = current + 1
        quote.price = StashService.getRowPrice(quote.row)
        if GetCurrency(pid, GOLD) + GetCurrency(pid, PLATINUM) * 1000000 <
            quote.price then
            quote.ok = false
            quote.code = "currency"
        end
        return quote
    end

    function StashService.purchaseRow(pid)
        local quote = StashService.quoteRow(pid)
        if not quote.ok then return quote end
        if not ChargePlayer(pid, quote.price, "Stash row unlocked.") then
            quote.ok = false
            quote.code = "currency"
            return quote
        end
        local hero = hero_data(pid)
        hero.stash_rows = quote.row
        quote.code = "unlocked"
        notify(pid)
        return quote
    end

    local function first_empty_stash(hero)
        for slot = 1, unlocked_slots(hero) do
            if not hero.stash[slot] then return slot end
        end
        return nil
    end

    local function first_empty_backpack(pid, item)
        local items = hero_data(pid).items
        for slot = BACKPACK_INDEX, MAX_INVENTORY_SLOTS do
            if not items[slot] then
                local valid = ValidateItemSlot(item, slot, nil)
                if valid then return slot end
            end
        end
        return nil
    end

    local function valid_stash_slot(hero, slot)
        return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and
                   slot <= unlocked_slots(hero)
    end

    local function valid_inventory_slot(slot)
        return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and
                   slot <= MAX_INVENTORY_SLOTS
    end

    function StashService.canDeposit(pid, inventory_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        local item = hero.items[inventory_slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end
        if not first_empty_stash(hero) then return result(false, "stash_full") end
        return result(true, "available")
    end

    function StashService.deposit(pid, inventory_slot, stash_slot)
        local available = StashService.canDeposit(pid, inventory_slot)
        if not available.ok then return available end
        local hero = hero_data(pid)
        local item = hero.items[inventory_slot]
        stash_slot = stash_slot or first_empty_stash(hero)
        if not stash_slot then return result(false, "stash_full") end
        if stash_slot < 1 or stash_slot > unlocked_slots(hero) or
            stash_slot % 1 ~= 0 then
            return result(false, "locked_slot")
        end
        if hero.stash[stash_slot] then return result(false, "occupied") end

        item:drop(30000., 30000., true, true)
        SetItemVisible(item.obj, false)
        item.stash_index = stash_slot
        hero.stash[stash_slot] = item
        notify(pid)
        return result(true, "deposited")
    end

    function StashService.withdraw(pid, stash_slot, inventory_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        if not valid_stash_slot(hero, stash_slot) then
            return result(false, "locked_slot")
        end
        local item = hero.stash[stash_slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end
        local target = inventory_slot or first_empty_backpack(pid, item)
        if not target then return result(false, "no_backpack_slot") end
        if not valid_inventory_slot(target) or hero.items[target] then
            return result(false, "invalid_target")
        end

        hero.stash[stash_slot] = nil
        item.stash_index = nil
        if not item:equip(target, nil, true) then
            item.stash_index = stash_slot
            hero.stash[stash_slot] = item
            return result(false, "invalid_target")
        end
        notify(pid)
        return result(true, "withdrawn")
    end

    ---Moves or swaps a pair of inventory/stash slots. Either side may be the
    ---source, allowing the UI to use the same synchronized command regardless
    ---of drag direction.
    function StashService.transfer(pid, inventory_slot, stash_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        if not valid_inventory_slot(inventory_slot) then
            return result(false, "invalid_target")
        end
        if not valid_stash_slot(hero, stash_slot) then
            return result(false, "locked_slot")
        end

        local inventory_item = hero.items[inventory_slot]
        local stash_item = hero.stash[stash_slot]
        if not inventory_item and not stash_item then
            return result(false, "missing_source")
        elseif inventory_item and not stash_item then
            return StashService.deposit(pid, inventory_slot, stash_slot)
        elseif stash_item and not inventory_item then
            return StashService.withdraw(pid, stash_slot, inventory_slot)
        end

        local valid, message = ValidateItemSlot(stash_item, inventory_slot,
                                                 inventory_item)
        if not valid then
            local response = result(false, "invalid_target")
            response.message = message
            return response
        end

        inventory_item:drop(30000., 30000., true, true)
        hero.stash[stash_slot] = nil
        stash_item.stash_index = nil
        ItemRuntime.commit_slot(stash_item, inventory_slot, true)

        inventory_item.stash_index = stash_slot
        hero.stash[stash_slot] = inventory_item
        SetItemVisible(inventory_item.obj, false)
        notify(pid)
        return result(true, "swapped")
    end

    function StashService.move(pid, from, to)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        if not valid_stash_slot(hero, from) or
            not valid_stash_slot(hero, to) then
            return result(false, "locked_slot")
        end
        local source = hero.stash[from]
        if not source or not source.alive then
            return result(false, "missing_source")
        end
        if from == to then return result(true, "unchanged") end

        local target = hero.stash[to]
        hero.stash[from], hero.stash[to] = target, source
        source.stash_index = to
        if target then target.stash_index = from end
        notify(pid)
        return result(true, target and "swapped" or "moved")
    end

    function StashService.drop(pid, stash_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        if not valid_stash_slot(hero, stash_slot) then
            return result(false, "locked_slot")
        end
        local item = hero.stash[stash_slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end

        hero.stash[stash_slot] = nil
        item.stash_index = nil
        SetItemPosition(item.obj, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        SetItemVisible(item.obj, true)
        SoundHandler("Sound\\Interface\\HeroDropItem1.flac", true,
                     Player(pid - 1), Hero[pid])
        notify(pid)
        return result(true, "dropped")
    end

    function StashService.sell(pid, stash_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not Town.isPlayerInTown(pid) then
            return result(false, "not_in_town")
        end
        if not valid_stash_slot(hero, stash_slot) then
            return result(false, "locked_slot")
        end
        local item = hero.stash[stash_slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end

        local total, gold, platinum = GetItemSellPrice(item)
        if total <= 0 then return result(false, "unsellable") end

        hero.stash[stash_slot] = nil
        item.stash_index = nil
        if not item:destroy() then
            hero.stash[stash_slot] = item
            item.stash_index = stash_slot
            return result(false, "destroy_failed")
        end
        AddCurrency(pid, GOLD, gold)
        AddCurrency(pid, PLATINUM, platinum)
        local response = result(true, "sold")
        response.gold = gold
        response.platinum = platinum
        notify(pid)
        return response
    end
end, Debug and Debug.getLine())
