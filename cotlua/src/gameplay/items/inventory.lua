--[[
    inventory.lua

    Owns synchronized inventory commands. Moves are prepared against the
    complete intended state before a non-fallible slot commit mutates either
    item. UI callers submit slot IDs and render the returned result.
]]

OnInit.final("InventoryService", function(Require)
    Require('Profile')
    Require('Variables')
    Require('Currency')
    Require('ItemEventRegistry')
    Require('Items')

    InventoryService = {}

    ---@class InventoryResult
    ---@field ok boolean
    ---@field code string
    ---@field message? string
    ---@field changed_slots integer[]
    ---@field item? Item
    ---@field holder? unit
    ---@field gold? integer
    ---@field platinum? integer

    ---@class InventoryMovePlan
    ---@field pid integer
    ---@field from integer
    ---@field to integer
    ---@field kind "move"|"swap"|"stack"|"unchanged"
    ---@field source? Item
    ---@field target? Item
    ---@field source_charges? integer
    ---@field target_charges? integer
    ---@field moved_charges? integer

    ---@param ok boolean
    ---@param code string
    ---@param message string?
    ---@param changed_slots integer[]?
    ---@return InventoryResult
    local function result(ok, code, message, changed_slots)
        return {
            ok = ok,
            code = code,
            message = message,
            changed_slots = changed_slots or {},
        }
    end

    ---@param slot any
    ---@return boolean
    local function valid_slot(slot)
        return type(slot) == "number"
            and slot % 1 == 0
            and slot >= 1
            and slot <= MAX_INVENTORY_SLOTS
    end

    ---@param pid integer
    ---@return Item[]?
    local function get_items(pid)
        local profile = Profile[pid]
        local hero = profile and profile.hero
        return hero and hero.items
    end

    ---Validates a complete slot transition without mutating either item.
    ---@param pid integer
    ---@param from integer
    ---@param to integer
    ---@return InventoryMovePlan? plan
    ---@return InventoryResult? failure
    function InventoryService.prepare(pid, from, to)
        if not valid_slot(from) or not valid_slot(to) then
            return nil, result(false, "invalid_slot")
        end

        local items = get_items(pid)
        if not items then
            return nil, result(false, "invalid_player")
        end

        local source = items[from]
        local target = items[to]
        if not source or not source.alive then
            return nil, result(false, "missing_source")
        end
        if from == to then
            return {
                pid = pid,
                from = from,
                to = to,
                kind = "unchanged",
                source = source,
            }
        end
        if source == target then
            return nil, result(false, "missing_source")
        end
        if target and not target.alive then
            return nil, result(false, "missing_target")
        end

        local valid, err = ValidateItemSlot(source, to, target)
        if not valid then
            return nil, result(false, "invalid_target", err)
        end

        local stack_limit = source.cached_stats[ITEM_STACK]
        if target and target.alive and stack_limit > 1
            and source.id == target.id
            and source.level == target.level
            and target.charges < stack_limit
        then
            return {
                pid = pid,
                from = from,
                to = to,
                kind = "stack",
                source = source,
                target = target,
                source_charges = source.charges,
                target_charges = target.charges,
                moved_charges = math.min(source.charges, stack_limit - target.charges),
            }
        end

        if target then
            valid, err = ValidateItemSlot(target, from, source)
            if not valid then
                return nil, result(false, "invalid_source", err)
            end
        end

        return {
            pid = pid,
            from = from,
            to = to,
            kind = target and "swap" or "move",
            source = source,
            target = target,
        }
    end

    ---Commits an immediately preceding prepared move. Identity checks prevent
    ---a stale plan from applying to inventory state that has since changed.
    ---@param plan InventoryMovePlan
    ---@return InventoryResult
    function InventoryService.commit(plan)
        if plan.kind == "unchanged" then
            return result(true, "unchanged")
        end

        local items = get_items(plan.pid)
        local source = plan.source
        local target = plan.target
        if not items or not source or items[plan.from] ~= source
            or items[plan.to] ~= target or not source.alive
        then
            return result(false, "stale")
        end

        if plan.kind == "stack" then
            if not target or not target.alive
                or source.charges ~= plan.source_charges
                or target.charges ~= plan.target_charges
            then
                return result(false, "stale")
            end

            local moved_charges = plan.moved_charges or 0
            target.charges = target.charges + moved_charges
            source.charges = source.charges - moved_charges

            if source.charges <= 0 then
                source:destroy()
            end

            NotifyItemChanged(plan.pid)
            return result(true, "stacked", nil, { plan.from, plan.to })
        end

        -- Both directions are already validated. The internal slot operation
        -- cannot reject either half, so there is no partial-success rollback.
        if target then
            ItemRuntime.commit_slot(target, plan.from, true)
        end
        ItemRuntime.commit_slot(source, plan.to, true)

        NotifyItemChanged(plan.pid)
        return result(true, plan.kind, nil, { plan.from, plan.to })
    end

    ---@param pid integer
    ---@param from integer
    ---@param to integer
    ---@return InventoryResult
    function InventoryService.move(pid, from, to)
        local plan, failure = InventoryService.prepare(pid, from, to)
        if not plan then
            return failure or result(false, "invalid_plan")
        end
        return InventoryService.commit(plan)
    end

    ---@param pid integer
    ---@param from integer
    ---@param first integer
    ---@param last integer
    ---@return integer?
    local function find_empty_target(pid, from, first, last)
        local items = get_items(pid)
        if not items or not items[from] then return nil end

        for slot = first, last do
            if not items[slot] then
                local plan = InventoryService.prepare(pid, from, slot)
                if plan then return slot end
            end
        end
        return nil
    end

    ---@param pid integer
    ---@param from integer
    ---@return integer?
    function InventoryService.findEquipTarget(pid, from)
        if not valid_slot(from) or from < BACKPACK_INDEX then return nil end
        return find_empty_target(pid, from, 1, BACKPACK_INDEX - 1)
    end

    ---@param pid integer
    ---@param from integer
    ---@return integer?
    function InventoryService.findUnequipTarget(pid, from)
        if not valid_slot(from) or from >= BACKPACK_INDEX then return nil end
        return find_empty_target(pid, from, BACKPACK_INDEX, MAX_INVENTORY_SLOTS)
    end

    ---@param pid integer
    ---@param from integer
    ---@return InventoryResult
    function InventoryService.equip(pid, from)
        local to = InventoryService.findEquipTarget(pid, from)
        if not to then return result(false, "no_equip_slot") end
        return InventoryService.move(pid, from, to)
    end

    ---@param pid integer
    ---@param from integer
    ---@return InventoryResult
    function InventoryService.unequip(pid, from)
        local to = InventoryService.findUnequipTarget(pid, from)
        if not to then return result(false, "no_backpack_slot") end
        return InventoryService.move(pid, from, to)
    end

    ---@param pid integer
    ---@param slot integer
    ---@param x number
    ---@param y number
    ---@return InventoryResult
    function InventoryService.drop(pid, slot, x, y)
        local items = get_items(pid)
        local item = valid_slot(slot) and items and items[slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end

        item:drop(x, y)
        local response = result(true, "dropped", nil, { slot })
        response.item = item
        return response
    end

    ---@param pid integer
    ---@param slot integer
    ---@return InventoryResult
    function InventoryService.canSell(pid, slot)
        local items = get_items(pid)
        local item = valid_slot(slot) and items and items[slot]
        if not item or not item.alive then
            return result(false, "missing_source")
        end
        if not RectContainsUnit(gg_rct_Town_Main, Hero[pid]) then
            return result(false, "not_in_town")
        end

        local total, gold, platinum = GetItemSellPrice(item)
        if total <= 0 then
            return result(false, "unsellable")
        end

        local response = result(true, "sellable")
        response.item = item
        response.holder = item.holder
        response.gold = gold
        response.platinum = platinum
        return response
    end

    ---@param pid integer
    ---@param slot integer
    ---@return InventoryResult
    function InventoryService.sell(pid, slot)
        local quote = InventoryService.canSell(pid, slot)
        if not quote.ok then return quote end
        local item = quote.item
        if not item then return result(false, "missing_source") end

        if not item:destroy() then
            return result(false, "destroy_failed")
        end

        AddCurrency(pid, GOLD, quote.gold or 0)
        AddCurrency(pid, PLATINUM, quote.platinum or 0)
        quote.code = "sold"
        quote.changed_slots = { slot }
        return quote
    end
end, Debug and Debug.getLine())
