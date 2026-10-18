-- A visible, saveable fixture for manual character save/reload testing.
OnInit.final("DevInventoryLoadout", function(Require)
    Require('Profile')
    Require('Items')
    Require('ItemHelpers')
    Require('ItemEventRegistry')
    Require('PotionService')
    Require('StashUI')

    DevInventoryLoadout = {}

    local inventory = {
        {slot = 1, id = 'I01V', kind = 'equipment', sockets = {'I0O1', 'I0OB', 'I0CH'}},
        {slot = 3, id = 'I021', kind = 'equipment'},
        {slot = 7, id = 'I02F', kind = 'potion', charges = 1},
        {slot = 8, id = 'I00E', kind = 'potion', charges = 0},
        {slot = 9, id = 'I01X', charges = 2},
        {slot = 11, id = 'I01X', charges = 0},
        {slot = 15, id = 'I04X', charges = 7},
        {slot = 26, id = 'I008'},
    }
    local stash = {
        {slot = 1, id = 'I01V', sockets = {'I0OB'}},
        {slot = 8, id = 'I01X', charges = 1},
        {slot = 18, potion = true, charges = 2},
        {slot = 24, id = 'I008'},
    }

    local function reserve(used, preferred, first, last)
        if not used[preferred] then used[preferred] = true; return preferred end
        for slot = first, last do
            if not used[slot] then used[slot] = true; return slot end
        end
    end

    ---Adds fixtures in free slots; existing equipment and stash contents stay put.
    ---@param pid integer
    ---@return boolean, string[]|string
    function DevInventoryLoadout.populate(pid)
        local profile, hero = Profile[pid], Hero[pid]
        if not profile or not profile.hero or not hero or not UnitAlive(hero) then
            return false, "Select a living hero first."
        end
        local data = profile.hero
        local used, stored, plan = {}, {}, {}
        local old_rows = data.stash_rows
        local rows = math.max(old_rows or 1, 4)
        for slot = 1, MAX_INVENTORY_SLOTS do used[slot] = data.items[slot] ~= nil end
        for slot = 1, rows * STASH_COLUMNS do stored[slot] = data.stash[slot] ~= nil end
        for _, spec in ipairs(inventory) do
            local first = spec.kind == 'equipment' and 1 or spec.kind == 'potion' and POTION_INDEX or BACKPACK_INDEX
            local last = spec.kind == 'equipment' and 6 or spec.kind == 'potion' and POTION_INDEX + 1 or MAX_INVENTORY_SLOTS
            local slot = reserve(used, spec.slot, first, last)
            if not slot and spec.kind == 'potion' then
                slot = reserve(used, BACKPACK_INDEX, BACKPACK_INDEX, MAX_INVENTORY_SLOTS)
            end
            if not slot then return false, "Free some inventory slots before using -invtest." end
            plan[#plan + 1] = {spec = spec, slot = slot}
        end
        for _, spec in ipairs(stash) do
            local slot = reserve(stored, spec.slot, 1, rows * STASH_COLUMNS)
            if not slot then return false, "Free some stash slots before using -invtest." end
            plan[#plan + 1] = {spec = spec, slot = slot, stash = true}
        end

        local owner, created = Player(pid - 1), {}
        local function make(spec)
            local item
            if spec.potion then
                item = PotionService.create(PotionService.GREATER_HEALTH_KEY, 30000., 30000., nil, false)
            else
                item = ItemRuntime.create(FourCC(spec.id), 30000., 30000.)
            end
            assert(item, "Could not create a test item.")
            created[#created + 1] = item
            item.pid, item.owner = pid, owner
            if spec.charges ~= nil then item.charges = spec.charges end
            -- Construct sockets before equipping the parent, as character load
            -- does. High-level gems can be inspected on any test hero this way.
            for _, id in ipairs(spec.sockets or {}) do
                local socket = make({id = id})
                socket.parent, socket.socketed = item, true
                item.sockets[#item.sockets + 1] = socket
            end
            item:update()
            SetItemVisible(item.obj, false)
            if not ItemIsSaveExcluded(item.id) then
                assert(item:encode_id() ~= 0, "A test item is missing from the save catalog.")
            end
            return item
        end

        local ok, err = pcall(function()
            for _, entry in ipairs(plan) do entry.item = make(entry.spec) end
            data.stash_rows = rows
            for _, entry in ipairs(plan) do
                local item = entry.item
                if entry.stash then
                    item.stash_index = entry.slot
                    data.stash[entry.slot] = item
                else
                    local valid, reason = ValidateItemSlot(item, entry.slot)
                    assert(valid, reason or "A test item cannot use its planned slot.")
                    -- Explicit placement keeps the stack separate from any
                    -- existing stack, and preserves sparse physical slots.
                    assert(ItemRuntime.commit_slot(item, entry.slot), "Could not place a test item.")
                end
            end
        end)
        if not ok then
            for _, entry in ipairs(plan) do
                if entry.stash and data.stash[entry.slot] == entry.item then data.stash[entry.slot] = nil end
            end
            for index = #created, 1, -1 do
                if created[index].alive then created[index]:destroy() end
            end
            data.stash_rows = old_rows
            NotifyItemChanged(pid)
            StashUI.refresh(pid)
            return false, "Inventory test setup failed: " .. tostring(err)
        end

        data:update_saved_items()
        NotifyItemChanged(pid)
        StashUI.refresh(pid)
        local report = {"Inventory test loadout added; " .. rows .. " stash rows unlocked. Save normally, then reload this character."}
        for _, entry in ipairs(plan) do
            local item = entry.item
            local detail = ItemIsSaveExcluded(item.id) and " — unsaveable; should disappear after reload" or
                entry.spec.charges ~= nil and " — charges/stack " .. item.charges or ""
            if #item.sockets > 0 then detail = detail .. " — " .. #item.sockets .. " sockets" end
            report[#report + 1] = (entry.stash and "Stash " or "Inventory ") .. entry.slot .. ": " .. item:name() .. detail
        end
        return true, report
    end
end, Debug and Debug.getLine())
