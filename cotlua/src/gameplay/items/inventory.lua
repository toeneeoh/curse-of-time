--[[
    inventoryservice.lua

    Owns synchronized inventory slot transactions. UI code may preview a move,
    but this service performs the authoritative validation and mutation.
]]

OnInit.final("InventoryService", function(Require)
    Require('Profile')
    Require('Variables')
    Require('ItemEventRegistry')
    Require('Items')

    InventoryService = {}

    local function result(ok, code, message, from, to)
        return {
            ok = ok,
            code = code,
            message = message,
            changed_slots = ok and { from, to } or {},
        }
    end

    local function equip(itm, slot, ignore)
        return itm:equip(slot, ignore, true)
    end

    ---Moves or swaps two inventory slots as one domain operation.
    ---@param pid integer
    ---@param from integer
    ---@param to integer
    ---@return table result
    function InventoryService.move(pid, from, to)
        if type(from) ~= "number" or type(to) ~= "number"
            or from < 1 or from > MAX_INVENTORY_SLOTS
            or to < 1 or to > MAX_INVENTORY_SLOTS then
            return result(false, "invalid_slot", nil, from, to)
        end

        if from == to then
            return result(true, "unchanged", nil, from, to)
        end

        local profile = Profile[pid]
        local hero = profile and profile.hero
        local items = hero and hero.items
        local source = items and items[from]
        local target = items and items[to]

        if not source or source == target then
            return result(false, "missing_source", nil, from, to)
        end

        local valid, err = ValidateItemSlot(source, to, target)
        if not valid then
            return result(false, "invalid_target", err, from, to)
        end

        if target then
            valid, err = ValidateItemSlot(target, from, source)
            if not valid then
                return result(false, "invalid_source", err, from, to)
            end
        end

        local stack_limit = source.cached_stats[ITEM_STACK]
        if target and stack_limit > 1 and source.id == target.id
            and source.level == target.level and target.charges < stack_limit then
            local moved_charges = math.min(source.charges, stack_limit - target.charges)
            target.charges = target.charges + moved_charges
            source.charges = source.charges - moved_charges

            if source.charges <= 0 then
                source:destroy()
            end

            NotifyItemChanged(pid)
            return result(true, "stacked", nil, from, to)
        end

        -- Move the occupant first. Both Item:equip calls ignore the item that is
        -- leaving, so limits are evaluated against the intended final state.
        if target then
            local moved, move_err = equip(target, from, source)
            if not moved then
                return result(false, "first_move_failed", move_err, from, to)
            end
        end

        local moved, move_err = equip(source, to, target)
        if not moved then
            -- Restore the occupant if the second step fails. This rollback uses
            -- the same prevalidated state and keeps the original item references.
            if target then
                equip(target, to, source)
                items[from] = source
            end
            return result(false, "second_move_failed", move_err, from, to)
        end

        NotifyItemChanged(pid)

        return result(true, "ok", nil, from, to)
    end
end, Debug and Debug.getLine())
