-- Shared ground-loot authority. World markers never own native item contents.
OnInit.final("LootService", function(Require)
    Require('LootModel')
    Require('Items')
    Require('ItemLookup')
    Require('RuntimeItemDefinitions')
    Require('WorldAreas')
    Require('PlayerSync')
    Require('Events')
    Require('UnitEvent')
    Require('TimerQueue')
    Require('Effects')

    LootService = {THRESHOLD = 8, RADIUS = 450., REACH = 450., UNIT_ID = FourCC('nLTP'), PROXY_ID = FourCC('I1LP')}
    local S = LootService
    local state = LootModel.create(S.THRESHOLD, S.RADIUS)
    local proxies, markers, listeners = {}, {}, {}
    local clock, scheduled, tick_scheduled = 0., false, false
    local retired, pulse_pending = {}, {}
    local reconcile, notify, tick

    function S.getPile(id) return state.piles[id] end
    function S.getEntry(id) return state.entries[id] end
    function S.forUnit(unit) return markers[unit] end
    function S.registerChanged(callback) listeners[#listeners + 1] = callback end
    function S.getMetrics()
        local result = {records = 0, piles = 0, proxies = 0, expiry = #state.heap}
        for _ in pairs(state.entries) do result.records = result.records + 1 end
        for _, pile in pairs(state.piles) do if pile.unit then result.piles = result.piles + 1 end end
        for _ in pairs(proxies) do result.proxies = result.proxies + 1 end
        return result
    end
    notify = function(pile)
        for _, callback in ipairs(listeners) do callback(pile.id) end
    end

    local function remove_proxy(entry)
        local proxy = entry.proxy
        if not proxy then return end
        proxies[proxy], entry.proxy = nil, nil
        retired[#retired + 1] = proxy
        if scheduled then return end
        scheduled = true
        -- One post-event cleanup batch, including consumed powerups. Restore
        -- life immediately before removal for the historical dead-item bug.
        TimerQueue:callDelayed(0., function()
            local batch = retired; retired = {}; scheduled = false
            for _, item in ipairs(batch) do SetWidgetLife(item, 1.); RemoveItem(item) end
        end)
    end
    local function present_proxy(entry)
        local item = entry.item
        local proxy = entry.proxy
        local data = item.data or ItemData[item.id]
        local skin = ItemRuntime.getWorldSkin(item)
        -- Same local appearance preference as ordinary drops, no shared branch.
        if not IS_ITEM_DROP[GetPlayerId(GetLocalPlayer()) + 1] then skin = FourCC('rar0') end
        BlzSetItemSkin(proxy, skin)
        BlzSetItemName(proxy, item.display_name or item:name())
        BlzSetItemTooltip(proxy, item.display_name or item:name())
        BlzSetItemIconPath(proxy, item.display_icon or data.path)
        -- The native ground-selection panel reads Description, whereas bag
        -- hover reads ExtendedTooltip. Skinning restores the raw OE text.
        BlzSetItemDescription(proxy, item.tooltip or "")
        BlzSetItemExtendedTooltip(proxy, item.tooltip or "")
        SetItemInvulnerable(proxy, true)
    end
    local function make_proxy(entry)
        local proxy = ItemRuntime.native_create(S.PROXY_ID, entry.item.x, entry.item.y)
        entry.proxy, proxies[proxy] = proxy, entry
        present_proxy(entry)
    end
    reconcile = function(pile)
        if #pile.entries == 0 then
            if pile.unit then markers[pile.unit] = nil; RemoveUnit(pile.unit); pile.unit = nil end
            return
        end
        if pile.bundled then
            for _, entry in ipairs(pile.entries) do remove_proxy(entry) end
            if not pile.unit then
                -- Cosmetic variation from the shared pile ID avoids advancing
                -- the gameplay RNG. Building status is set in object data.
                local facing = (pile.id * 137.50776405003785) % 360.
                pile.unit = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), S.UNIT_ID, pile.x, pile.y, facing)
                markers[pile.unit] = pile
                SetUnitPathing(pile.unit, false)
                SetUnitInvulnerable(pile.unit, true)
                SetUnitScale(pile.unit, 1., 1., 1.)
                SetUnitVertexColor(pile.unit, 255, 255, 255, 255)
                SetUnitAnimation(pile.unit, "stand")
            end
            BlzSetUnitName(pile.unit, #pile.entries .. " items dropped")
        else
            for _, entry in ipairs(pile.entries) do if not entry.proxy then make_proxy(entry) end end
        end
    end
    local function pulse(pile)
        if pulse_pending[pile.id] then return end
        pulse_pending[pile.id] = true
        TimerQueue:callDelayed(.2, function()
            pulse_pending[pile.id] = nil
            if not pile.unit then return end
            local effect = AddSpecialEffect("Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl", pile.x, pile.y)
            BlzSetSpecialEffectScale(effect, .975)
            BlzSetSpecialEffectColor(effect, 255, 210, 100)
            TimerQueue:callDelayed(1.8, HideEffect, effect)
        end)
    end
    local function ensure_tick()
        if tick_scheduled or #state.heap == 0 then return end
        tick_scheduled = true; TimerQueue:callDelayed(1., tick)
    end
    tick = function()
        tick_scheduled = false; clock = clock + 1.
        -- Deterministic work bound. Expiry does not depend on local wall time.
        for _ = 1, 128 do
            local entry = LootModel.due(state, clock)
            if not entry then break end
            if not entry.item.owner then entry.item:destroy() end
        end
        ensure_tick()
    end
    function S.add(item, lifetime)
        if not item or not item.alive or item.loot_id then return item end
        if item.holder or item.stash_index then return nil end
        if item.obj then ItemRuntime.dematerialize(item) end
        item.data_only = true
        local owner = item.owner and GetPlayerId(item.owner) + 1 or 0
        local protected = GetProtectedAreaFromCoords(item.x, item.y)
        local area_id = 0
        for index, area in ipairs(PROTECTED_AREAS) do if area == protected then area_id = index; break end end
        local scope = owner .. ":" .. GetTerrainCliffLevel(item.x, item.y) .. ":" ..
            area_id
        local entry = LootModel.add(state, item, item.x, item.y, scope,
            lifetime and clock + lifetime or nil)
        item.loot_id = entry.id
        reconcile(entry.pile)
        if entry.pile.bundled then pulse(entry.pile) end
        notify(entry.pile); ensure_tick()
        return item
    end
    function S.from(factory, ...)
        local item = ItemRuntime.withRecords(factory, ...)
        return item and S.add(item, item.ground_lifetime)
    end
    function S.create(id, x, y, lifetime)
        return S.from(ItemRuntime.create, id, x, y, lifetime)
    end
    function S.changed(item)
        local entry = item.loot_id and state.entries[item.loot_id]
        if entry then
            entry.revision = entry.revision + 1
            item.loot_revision = entry.revision
            if entry.proxy then present_proxy(entry) end
            notify(entry.pile)
        end
    end
    function S.detach(item)
        local entry = item.loot_id and state.entries[item.loot_id]
        item.loot_id = nil
        if not entry then return end
        remove_proxy(entry)
        local pile = LootModel.remove(state, entry)
        reconcile(pile); notify(pile)
    end
    local function access(pid, entry)
        local hero = Hero[pid]
        if not hero or not Profile[pid] or not Profile[pid].playing or not UnitAlive(hero) or IsUnitPaused(hero) then
            return nil, "Your hero cannot collect loot right now."
        end
        local pile, player = entry.pile, Player(pid - 1)
        if (GetUnitX(hero) - pile.x)^2 + (GetUnitY(hero) - pile.y)^2 > S.REACH^2 or
            not IsVisibleToPlayer(pile.x, pile.y, player) then
            return nil, "Move closer to collect or bind this loot."
        end
        if entry.item.owner and entry.item.owner ~= player then return nil, "This item is bound to another player." end
        return hero
    end
    function S.act(pid, pile_id, loot_id, revision, action)
        local entry = state.entries[loot_id]
        if not entry or entry.pile.id ~= pile_id or entry.revision ~= revision or not entry.item.alive then
            return false, "That loot has changed or is no longer available."
        end
        local hero, message = access(pid, entry)
        if not hero then return false, message end
        local item = entry.item
        if action == "bind" then
            if not ItemToIndex(item.id) then return false, "This item cannot be bound." end
            local old_pid = item.pid
            item.pid = pid
            local valid, reason = ValidateItemSlot(item, BACKPACK_INDEX)
            item.pid = old_pid
            if not valid then return false, reason or "This item cannot be bound by this hero." end
            item.owner = Player(pid - 1); entry.revision = entry.revision + 1
            item.loot_revision = entry.revision
            LootModel.unschedule(state, entry)
            notify(entry.pile); return true
        end
        if action ~= "take" then return false, "Unknown loot action." end
        if item.automatic then
            -- Real native powerups (quests/resources/tomes) retain their exact
            -- lookup behavior. Only a successful claim creates their real item.
            if not ItemRuntime.materialize(item) then return false, "Unable to create this item." end
            local lifetime = entry.deadline and math.max(0., entry.deadline - clock) or nil
            S.detach(item)
            local receipt, native = item.pickup_receipt or 0, item.obj
            UnitAddItem(hero, native)
            -- Observe actual acquisition, rather than relying on the native's
            -- boolean alone (notably unreliable for paused powerup grants).
            if (item.pickup_receipt or 0) == receipt and item.alive and GetItemTypeId(native) ~= 0 then
                S.add(item, lifetime)
                return false, "Unable to collect this powerup."
            end
            return true
        end
        local items, old_pid = Profile[pid].hero.items, item.pid
        item.pid = pid
        local slot, failure, merges = nil, nil, {}
        local remaining, limit = item.charges, item.cached_stats[ITEM_STACK]
        -- Plan first. A full bag can still accept a partial compatible stack.
        if limit > 1 then
            for index = 1, MAX_INVENTORY_SLOTS do
                local target = items[index]
                if target and target.alive and target.level == item.level and target.charges < limit and
                    RuntimeItemDefinitions.sameIdentity(item, target) then
                    local valid, err = ValidateItemSlot(item, index, target)
                    if valid then
                        local amount = math.min(remaining, limit - target.charges)
                        if amount > 0 then merges[#merges + 1] = {item = target, amount = amount}; remaining = remaining - amount end
                    else failure = err end
                end
                if remaining <= 0 then break end
            end
        end
        if remaining > 0 or limit <= 1 then
            for index = 1, MAX_INVENTORY_SLOTS do
                if not items[index] then
                    local valid, err = ValidateItemSlot(item, index)
                    if valid then slot = index; break else failure = err or failure end
                end
            end
        end
        if not slot and #merges == 0 then item.pid = old_pid; return false, failure or "Your inventory is full." end
        if slot and not ItemRuntime.materialize(item) then item.pid = old_pid; return false, "Unable to create this item." end
        for _, merge in ipairs(merges) do merge.item.charges = merge.item.charges + merge.amount end
        item.charges = remaining
        if limit > 1 and remaining <= 0 then
            item:destroy()
        elseif slot then
            S.detach(item)
            ItemRuntime.commit_slot(item, slot, true)
        else
            item.pid = old_pid; entry.revision = entry.revision + 1; item.loot_revision = entry.revision; notify(entry.pile)
        end
        NotifyItemChanged(pid)
        if ITEM_LOOKUP[item.id] then ITEM_LOOKUP[item.id](Player(pid - 1), pid, hero, item) end
        return true
    end
    function S.consumeProxy(unit, proxy)
        local entry = proxies[proxy]
        if not entry and GetItemTypeId(proxy) ~= S.PROXY_ID then return false end
        if not entry then return true end -- retired/converted stale native order
        remove_proxy(entry)
        local pid = GetPlayerId(GetOwningPlayer(unit)) + 1
        local ok, message = false, "Only your hero can collect this loot."
        if pid <= PLAYER_CAP and Hero[pid] == unit then ok, message = S.act(pid, entry.pile.id, entry.id, entry.revision, "take") end
        if not ok and pid <= PLAYER_CAP then DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., message) end
        if state.entries[entry.id] then reconcile(entry.pile) end
        return true
    end
    SyncCallback("loot_action", function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local action, pile, entry, revision = BlzGetTriggerSyncData():match("^(%a+):(%d+):(%d+):(%d+)$")
        if action ~= "take" and action ~= "bind" then return end
        local ok, message = S.act(pid, tonumber(pile), tonumber(entry), tonumber(revision), action)
        if not ok then DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., message) end
        if LootUI then LootUI.refresh(pid) end
    end)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid, function()
            local pending = {}
            for _, entry in pairs(state.entries) do if entry.item.owner == Player(pid - 1) then pending[#pending + 1] = entry.item end end
            for _, item in ipairs(pending) do item:destroy() end
        end)
    end
end, Debug and Debug.getLine())
