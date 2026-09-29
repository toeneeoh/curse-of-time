-- Saveable, town-managed item storage.
OnInit.final("StashService", function(Require)
    Require('Profile')
    Require('Currency')
    Require('Items')
    Require('ItemEventRegistry')

    StashService = {}

    local BASE_ROW_PRICE = 250000
    local ROW_PRICE_MULTIPLIER = 4
    local changed_actions = {}

    local function result(ok, code)
        return {ok = ok, code = code}
    end

    local function hero_data(pid)
        local profile = Profile[pid]
        return profile and profile.hero or nil
    end

    local function in_town(pid)
        return Hero[pid] and RectContainsUnit(gg_rct_Town_Main, Hero[pid])
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
        if not in_town(pid) then return result(false, "not_in_town") end
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

    function StashService.canDeposit(pid, inventory_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not in_town(pid) then return result(false, "not_in_town") end
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

        item:drop(30000., 30000., true)
        SetItemVisible(item.obj, false)
        item.stash_index = stash_slot
        hero.stash[stash_slot] = item
        notify(pid)
        return result(true, "deposited")
    end

    function StashService.withdraw(pid, stash_slot)
        local hero = hero_data(pid)
        if not hero then return result(false, "invalid_player") end
        if not in_town(pid) then return result(false, "not_in_town") end
        if stash_slot < 1 or stash_slot > unlocked_slots(hero) or
            stash_slot % 1 ~= 0 then
            return result(false, "locked_slot")
        end
        local item = hero.stash[stash_slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end
        local target = first_empty_backpack(pid, item)
        if not target then return result(false, "no_backpack_slot") end

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
end, Debug and Debug.getLine())
