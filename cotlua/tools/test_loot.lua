-- Actual loot model/service/UI on isolated native boundaries. This cannot prove
-- current-patch powerup behavior, engine leaks, rendering, or multiplayer sync.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close(); return source
end
local function client(local_player)
    local env = setmetatable({}, {__index = _G})
    local timers, events, sync, native, errors, cleanups = {}, {}, {}, {}, {}, {}
    local now, serial, trigger_player, payload, allocations = 0, 0, 0, '', 0
    env.OnInit = {global = function(_, callback) callback() end,
        final = function(_, callback) callback(function() end) end}
    env.FourCC, env.Player, env.GetPlayerId = function(s) return s end, function(p) return p end, function(p) return p end
    env.GetLocalPlayer, env.GetTriggerPlayer = function() return local_player end, function() return trigger_player end
    env.GetOwningPlayer = function(u) return u.player end
    env.GetUnitX, env.GetUnitY = function(u) return u.x end, function(u) return u.y end
    env.UnitAlive, env.IsUnitPaused = function(u) return not u.dead end, function(u) return u.paused end
    env.GetTerrainCliffLevel, env.GetProtectedAreaFromCoords = function() return 0 end, function() end
    env.PROTECTED_AREAS = {}
    env.IsVisibleToPlayer = function() return true end
    env.PLAYER_CAP, env.PLAYER_NEUTRAL_PASSIVE, env.MAX_INVENTORY_SLOTS = 2, 15, 26
    env.BACKPACK_INDEX = 9
    env.ITEM_STACK, env.ITEM_MODEL = 1, {[1] = 'rare'}
    env.ItemData = {[101] = {path = 'icon', name = 'Reward'}}
    env.IS_ITEM_DROP = {[1] = true, [2] = true}
    env.Hero = {[1] = {player = 0, x = 0, y = 0}, [2] = {player = 1, x = 0, y = 0}}
    env.Profile = {[1] = {playing = true, hero = {items = {}}}, [2] = {playing = true, hero = {items = {}}}}
    env.TimerQueue = {callDelayed = function(_, delay, callback, ...)
        timers[#timers + 1] = {time = now + delay, callback = callback, args = {...}}
    end}
    local function advance(amount)
        local finish = now + amount
        while true do
            local index
            for i, timer in ipairs(timers) do if timer.time <= finish and (not index or timer.time < timers[index].time) then index = i end end
            if not index then break end
            local timer = table.remove(timers, index); now = timer.time
            timer.callback(table.unpack(timer.args))
        end
        now = finish
    end
    local function allocate(kind, id, x, y)
        allocations = allocations + 1
        local object = {kind = kind, id = id, x = x, y = y, handle = local_player * 100000 + allocations, life = 1}
        native[object] = true; return object
    end
    env.CreateUnit = function(player, id, x, y, facing)
        local unit = allocate('unit', id, x, y); unit.player, unit.facing = player, facing; return unit
    end
    env.BlzSetUnitName = function(unit, name) unit.name = name end
    env.SetUnitScale = function(unit, x, y, z) unit.scale = {x, y, z} end
    env.SetUnitVertexColor = function(unit, r, g, b, a) unit.color = {r, g, b, a} end
    env.SetUnitAnimation = function(unit, name) unit.animation = name end
    env.BlzSetItemSkin = function(item, skin)
        item.skin = skin; item.description = '[tier 1] [armor 2] [str 8]'
    end
    env.BlzSetItemName = function(item, name) item.name = name end
    env.BlzSetItemTooltip = function(item, text) item.tooltip = text end
    env.BlzSetItemDescription = function(item, text) item.description = text end
    env.BlzSetItemExtendedTooltip = function(item, text) item.extended_tooltip = text end
    env.RemoveUnit = function(u) assert(native[u]); native[u] = nil; u.removed = true end
    env.GetItemTypeId = function(i) return i.id end
    env.RemoveItem = function(i) assert(native[i] and i.life > .405, 'Leaked/dead or double removal'); native[i] = nil; i.removed = true end
    env.SetWidgetLife = function(i, life) i.life = life end
    for _, name in ipairs({'BlzSetItemIconPath',
        'SetItemInvulnerable','SetUnitPathing','SetUnitInvulnerable','BlzSetSpecialEffectScale','BlzSetSpecialEffectColor'}) do env[name] = function() end end
    env.AddSpecialEffect = function() return allocate('effect', 'pulse') end
    env.HideEffect = function(i) assert(native[i]); native[i] = nil end
    env.DisplayTimedTextToPlayer = function(_, _, _, _, message) errors[#errors + 1] = message end
    env.NotifyItemChanged = function() end
    env.ItemToIndex = function() return 1 end
    env.ITEM_LOOKUP = {}
    env.RuntimeItemDefinitions = {sameIdentity = function(a, b) return a.id == b.id end}
    local recording = false
    local item_methods = {}
    function item_methods:name() return 'Reward ' .. self.sync_id end
    function item_methods:info() return {name = self:name(), icon = 'icon', description = 'details'} end
    function item_methods:destroy()
        if not self.alive then return end
        self.alive = false
        if self.loot_id then env.LootService.detach(self) end
        if self.obj then env.SetWidgetLife(self.obj, 1); env.RemoveItem(self.obj); self.obj = nil end
    end
    env.ItemRuntime = {
        withRecords = function(factory, ...) recording = true; local item = factory(...); recording = false; return item end,
        create = function(id, x, y, lifetime)
            assert(recording, 'Drop created a managed native item')
            serial = serial + 1
            return setmetatable({sync_id = serial, id = id, x = x, y = y, ground_lifetime = lifetime,
                alive = true, data_only = true, charges = 1, level = 0, cached_stats = {[1] = 1},
                tooltip = 'description', data = env.ItemData[101], quality = {17}, persistent_state = {42}}, {__index = item_methods})
        end,
        native_create = function(id, x, y) assert(id == 'I1LP'); return allocate('proxy', id, x, y) end,
        getRarityIndex = function() return 1 end,
        getWorldSkin = function(item)
            return item.runtime_definition and item.runtime_definition.world_skin_id or
                (item.rarity and env.ITEM_MODEL[item.rarity]) or item.id
        end,
        materialize = function(item)
            if item.fail then return false end
            if not item.obj then item.obj = allocate('owned', item.id); item.obj.record = item; item.data_only = false end
            return true
        end,
        dematerialize = function(item)
            if item.obj then env.SetWidgetLife(item.obj, 1); env.RemoveItem(item.obj); item.obj = nil end
            item.data_only = true
        end,
        commit_slot = function(item, slot)
            assert(item.obj and not env.Profile[item.pid].hero.items[slot])
            env.Profile[item.pid].hero.items[slot] = item; item.holder = env.Hero[item.pid]
        end,
    }
    env.ValidateItemSlot = function(item, slot)
        if item.invalid then return false, 'Invalid level or item restriction' end
        return slot >= 9 -- force ordinary backpack rules in this fixture
    end
    env.UnitAddItem = function(_, item)
        -- A real claimed powerup executes its original lookup/consumption path.
        if env.fail_auto then return false end
        item.record.pickup_receipt = (item.record.pickup_receipt or 0) + 1
        env.auto_claimed = (env.auto_claimed or 0) + 1
        item.record:destroy()
        return not env.auto_returns_false
    end
    env.SyncCallback = function(prefix, callback) sync[prefix] = callback end
    env.BlzGetTriggerSyncData = function() return payload end
    env.RegisterPlayerUnitEvent = function(event, callback) events[event] = callback end
    env.EVENT_PLAYER_UNIT_SELECTED = 'select'
    env.EVENT_ON_CLEANUP = {register_action = function(_, pid, callback) cleanups[pid] = cleanups[pid] or {}; table.insert(cleanups[pid], callback) end}
    assert(load(read('gameplay/items/loot_model.lua'), 'real loot model', 't', env))()
    assert(load(read('gameplay/items/loot.lua'), 'real loot service', 't', env))()
    return {env = env, native = native, errors = errors, advance = advance, events = events, cleanups = cleanups,
        synchronize = function(player, data) trigger_player, payload = player, data; sync.loot_action() end,
        act = function(item, pid, action)
            local entry = env.LootService.getEntry(item.sync_id)
            return env.LootService.act(pid, entry.pile.id, entry.id, entry.revision, action or 'take')
        end,
        count = function(kind) local count = 0; for object in pairs(native) do if object.kind == kind then count = count + 1 end end; return count end,
        trigger = function(player) trigger_player = player end}
end
local host, guest = client(0), client(1)
guest.env.IS_ITEM_DROP[2] = false
local records = {{}, {}}
for n, c in ipairs({host, guest}) do
    for i = 1, 7 do records[n][i] = c.env.LootService.create(101, i, 0, 600) end
    assert(c.count('proxy') == 7 and c.count('unit') == 0 and c.count('owned') == 0)
    local proxy = c.env.LootService.getEntry(records[n][1].sync_id).proxy
    assert(proxy.description == records[n][1].tooltip and proxy.extended_tooltip == proxy.description,
        'Native ground description retained unparsed object data')
    records[n][1].tooltip = 'updated parsed description'; c.env.LootService.changed(records[n][1])
    assert(proxy.description == 'updated parsed description' and proxy.tooltip == proxy.name)
    records[n][1].rarity = 1; c.env.LootService.changed(records[n][1])
    assert(proxy.skin == (n == 1 and 'rare' or 'rar0'), 'Ground proxy ignored rarity model/drop preference')
    records[n][8] = c.env.LootService.create(101, 8, 0, 600)
    c.advance(.01)
    assert(c.count('proxy') == 0 and c.count('unit') == 1 and c.count('owned') == 0)
    local pile = c.env.LootService.getPile(1)
    assert(#pile.entries == 8 and pile.bundled and c.env.LootService.getMetrics().expiry == 8)
    assert(pile.unit.player == c.env.PLAYER_NEUTRAL_PASSIVE and pile.unit.name == '8 items dropped')
    assert(math.abs(pile.unit.facing - 137.50776405003785) < .000001)
    assert(pile.unit.scale[1] == 1 and pile.unit.scale[2] == 1 and pile.unit.scale[3] == 1)
    assert(pile.unit.color[4] == 255 and pile.unit.animation == 'stand')
    for _, item in ipairs(records[n]) do assert(not item.obj and item.quality[1] == 17 and item.persistent_state[1] == 42) end
end
local entry = guest.env.LootService.getEntry(records[2][1].sync_id)
local packet = string.format('take:%d:%d:%d', entry.pile.id, entry.id, entry.revision)
host.synchronize(1, packet); guest.synchronize(1, packet)
for _, c in ipairs({host, guest}) do
    assert(c.count('unit') == 1 and c.count('owned') == 1 and #c.env.LootService.getPile(1).entries == 7)
    assert(c.env.LootService.getPile(1).unit.name == '7 items dropped')
    assert(c.env.Profile[2].hero.items[9].sync_id == 1)
end
-- Same expected record cannot be awarded to another player or replayed.
host.synchronize(0, packet); guest.synchronize(0, packet)
assert(#host.errors == 1 and #guest.errors == 1 and not host.env.Profile[1].hero.items[9])
-- A claimed item dropped back into the same surviving pile must not resurrect
-- an old request with the original record revision.
for n, client in ipairs({host, guest}) do
    local owned = client.env.Profile[2].hero.items[9]
    client.env.Profile[2].hero.items[9] = nil; owned.holder = nil
    client.env.LootService.add(owned, 600)
    assert(client.env.LootService.getEntry(owned.sync_id).revision > 1)
    client.synchronize(1, packet)
    assert(not client.env.Profile[2].hero.items[9])
    assert(client.act(owned, 2))
end
-- Additions join a formed pile immediately; pulses are coalesced.
for _, c in ipairs({host, guest}) do
    c.env.LootService.create(101, 0, 0, 600)
    c.env.LootService.create(101, 0, 0, 600)
    assert(c.count('proxy') == 0)
    c.advance(.2); assert(c.count('effect') == 1)
    c.advance(.6); assert(c.count('effect') == 1)
    c.advance(1.3); assert(c.count('effect') == 0)
end
-- Native powerup proxy is explicitly removed even when engine consumption has
-- already set life to zero. Failed claims preserve one collectible record.
local c = client(0)
local item = c.env.LootService.create(101, 0, 0, 600)
local proxy
for obj in pairs(c.native) do if obj.kind == 'proxy' then proxy = obj end end
proxy.life = 0; item.invalid = true
assert(c.env.LootService.consumeProxy(c.env.Hero[1], proxy))
c.advance(.01)
assert(proxy.removed and c.count('proxy') == 1 and c.count('owned') == 0 and c.env.LootService.getEntry(item.sync_id))
item.invalid = false
for obj in pairs(c.native) do if obj.kind == 'proxy' then proxy = obj end end
assert(c.env.LootService.consumeProxy(c.env.Hero[1], proxy))
c.advance(.01)
assert(c.count('proxy') == 0 and c.count('owned') == 1 and not c.env.LootService.getEntry(item.sync_id))
-- Full inventory accepts part of a stack without native materialization.
c = client(0)
item = c.env.LootService.create(101, 0, 0, 600); item.charges = 7; item.cached_stats[1] = 10
local inventory = c.env.Profile[1].hero.items
for i = 1, 26 do inventory[i] = {id = 202, alive = true, level = 0, charges = 10} end
inventory[9] = {id = 101, alive = true, level = 0, charges = 8}
assert(c.act(item, 1)); assert(inventory[9].charges == 10 and item.charges == 5 and not item.obj)
local ok = c.act(item, 1); assert(not ok and item.charges == 5)
inventory[10] = nil
assert(c.act(item, 1) and inventory[10] == item and item.obj)
-- Real powerups are awarded once even if the native's boolean disagrees with
-- its acquisition callback. A failed attempt keeps its original expiry.
c = client(0)
item = c.env.LootService.create(101, 0, 0, 600); item.automatic = true
c.env.auto_returns_false = true
assert(c.act(item, 1) and c.env.auto_claimed == 1 and not c.env.LootService.getEntry(item.sync_id))
c = client(0)
item = c.env.LootService.create(101, 0, 0, 2); item.automatic = true
c.advance(1); c.env.fail_auto = true
assert(not c.act(item, 1) and c.env.LootService.getEntry(item.sync_id))
c.advance(1.1); assert(not item.alive and c.env.LootService.getMetrics().records == 0)
-- Binding, reach, stale revisions and per-record expiry survive grouping.
c = client(0)
local a = c.env.LootService.create(101, 0, 0, 2)
local b = c.env.LootService.create(101, 0, 0, 3)
c.env.Hero[1].x = 1000; assert(not c.act(a, 1, 'bind'))
c.env.Hero[1].x = 0
assert(c.act(a, 1, 'bind')); assert(not c.act(a, 2))
c.advance(4)
assert(a.alive and not b.alive and c.env.LootService.getMetrics().expiry == 0)
for _, callback in ipairs(c.cleanups[1]) do callback() end
c.advance(.01); assert(not a.alive and c.count('proxy') == 0 and c.env.LootService.getMetrics().records == 0)
-- Different ownership and fixed-anchor distance prevent inappropriate merges.
c = client(0)
c.env.LootService.create(101, 0, 0, 600)
for i = 2, 8 do c.env.LootService.create(101, 450, 0, 600) end
c.advance(.01)
assert(c.count('unit') == 1 and #c.env.LootService.getPile(1).entries == 8,
    'Drops at the 450-unit boundary did not bundle')
c.env.LootService.create(101, 450.01, 0, 600)
assert(#c.env.LootService.getPile(1).entries == 8 and c.count('proxy') == 1,
    'Bundling exceeded its 450-unit fixed-anchor radius')
c = client(0)
for i = 1, 8 do c.env.LootService.create(101, i * 200, 0, 600) end
assert(c.count('unit') == 0)
local private = c.env.ItemRuntime.withRecords(c.env.ItemRuntime.create, 101, 200, 0, 600); private.owner = 1
c.env.LootService.add(private, 600)
assert(private.loot_id and c.env.LootService.getEntry(private.loot_id).pile.scope ~= c.env.LootService.getPile(1).scope)
-- Heap cancellation/order remains correct under a large mixed workload.
local M = c.env.LootModel
local nearby = M.create(8, 256)
for i = 1, 8 do M.add(nearby, {sync_id = i}, 0, 0, 'public') end
M.add(nearby, {sync_id = 9}, 400, 0, 'public')
assert(M.add(nearby, {sync_id = 10}, 220, 0, 'public').pile.id == 1,
    'A nearby formed bundle must receive new loot before a closer sparse cluster')
local model = M.create(8, 256)
local scheduled = {}
for i = 1, 3000 do scheduled[i] = M.add(model, {sync_id = i}, 0, 0, 'public', (i * 73) % 601) end
for i = 1, 3000, 3 do M.remove(model, scheduled[i]) end
local last, count = -1, 0
while true do
    local due = M.due(model, 1000)
    if not due then break end
    assert(due.deadline >= last); last = due.deadline; count = count + 1; M.remove(model, due)
end
assert(count == 2000 and not next(model.entries) and not next(model.piles) and not next(model.cells))
print('PASS (offline boundaries): eight-entry formation, data-only contents, direct pickup/rejection and dead-proxy cleanup, atomic host/guest claims/replays, partial stacks in full bags, binding/reach, expiry/cleanup, fixed-anchor grouping, coalesced feedback, and 3,000-record heap lifecycle.')

-- Construct and execute the real UI on a fixed frame pool. No per-record frame
-- allocation, no local item mutation, correct width/anchor and stable IDs.
local function ui(c)
    local env, frames, buttons, simple, packets = c.env, {}, {}, {}, {}
    local current_frame
    local function frame(kind)
        local f = {kind = kind}; frames[#frames + 1] = f; return f
    end
    env.BlzCreateFrame, env.BlzCreateFrameByType = frame, frame
    env.BlzGetFrameByName = function() return {} end
    env.BlzFrameSetPoint = function(f, a, parent, b, x, y) f.anchor = {a, parent, b, x, y} end
    env.BlzFrameSetSize = function(f, w, h) f.width, f.height = w, h end
    env.BlzFrameSetVisible = function(f, value) f.visible = value end
    env.BlzFrameSetText = function(f, value) f.text = value end
    env.BlzFrameSetEnable = function() end
    env.BlzFrameSetAllPoints = function() end
    env.BlzFrameSetLevel = function(f, level) f.level = level end
    env.BlzFrameSetParent = function(f, parent) f.parent = parent end
    env.BlzFrameSetTexture = function(f, value) f.texture = value end
    env.BlzGetTriggerFrame = function() return current_frame end
    env.FRAMEPOINT_TOPRIGHT, env.FRAMEPOINT_TOPLEFT, env.FRAMEPOINT_TOP = 'TR', 'TL', 'T'
    env.FRAMEPOINT_BOTTOM, env.FRAMEPOINT_BOTTOMLEFT = 'B', 'BL'
    env.Button = {create = function()
        local b = {iconFrame = frame('icon'), displayFrame = frame('selection'), chargeFrame = frame('charge'), tooltip = {enableAttachments = function() end, point = function() end, text = function() end}}
        b.visible = function() end; b.available = function() end
        b.display = function(self, model, width, height, scale) self.selection, self.selection_scale = model, scale end
        b.onClick = function(self, callback) self.click = callback end
        b.onDoubleClick = function(self, callback) self.double = callback end
        buttons[#buttons + 1] = b; return b
    end}
    env.SimpleButton = {create = function(_, texture, width, height, _, _, x, y, callback, tooltip)
        local b = {frame = frame('simple'), texture = texture, width = width, x = x, y = y, click = callback, tooltip = tooltip}
        b.enable, b.text = function() end, function() end
        simple[#simple + 1] = b; return b
    end}
    env.INVENTORY = {frame = {}, open = function() end, renderItemButton = function(button, item) button.item = item end}
    env.StashUI = {close = function() end}
    env.AddToEsc = function() end
    env.ItemDetails = {show = function() end}
    env.SelectUnitForPlayerSingle = function() end
    env.BlzSendSyncData = function(prefix, value) packets[#packets + 1] = {prefix, value} end
    assert(load(read('ui/inventory/loot.lua'), 'real loot UI', 't', env))()
    return {frames = frames, buttons = buttons, simple = simple, packets = packets,
        click = function(button, double) current_frame = button.frame; (double and button.double or button.click)() end}
end
c = client(0)
local u = ui(c)
for i = 1, 80 do c.env.LootService.create(101, 0, 0, 600) end
local frame_count = #u.frames
c.trigger(0); c.env.LootUI.open(1, c.env.LootService.getPile(1))
assert(#u.buttons == 72 and u.frames[1].width == .4682 and u.frames[1].height == .232)
assert(u.frames[1].anchor[2] == c.env.INVENTORY.frame and u.frames[1].anchor[4] == -.006)
local tiles, titles = 0, 0
for _, f in ipairs(u.frames) do
    if f.texture == 'inventory_row.tga' then
        tiles = tiles + 1
        assert(f.width == .1981 and f.height == .0312, 'Inventory row was stretched')
        assert(math.abs(f.anchor[4] - (.02 + .1981 * ((tiles - 1) % 2))) < .000001)
    elseif f.kind == 'TitleText' then
        titles = titles + 1; assert(f.text == 'ITEM BUNDLE')
    end
end
assert(tiles == 12 and titles == 1 and #u.simple == 5)
for index = 4, 5 do
    local arrow = u.simple[index]
    assert(arrow.texture:find(index == 4 and 'BTNCycleLeft.blp' or 'BTNCycleRight.blp', 1, true))
    assert(.4682 + arrow.x - arrow.width >= .02 + .1981 * 2, 'Page arrow overlaps loot grid')
end
assert(u.buttons[1].item.sync_id == 1)
u.click(u.buttons[1]); u.click(u.buttons[1]); u.click(u.buttons[1], true)
assert(u.buttons[1].selection == 'blue_energy_sprite.mdx' and math.abs(u.buttons[1].selection_scale - .4788 * 1.04) < .000001)
assert(u.buttons[1].displayFrame.parent == u.buttons[1].iconFrame and
    u.buttons[1].displayFrame.level > u.buttons[1].rarityBorder.level, 'Selection is below rarity')
assert(u.packets[1][1] == 'loot_action' and u.packets[1][2] == 'take:1:1:1')
assert(not c.env.Profile[1].hero.items[9], 'Local UI mutated real inventory')
u.click(u.simple[#u.simple]) -- next page
assert(u.buttons[1].item.sync_id == 73)
assert(not u.buttons[1].selection, 'Selection border remained on a different page')
c.synchronize(0, u.packets[1][2])
assert(c.env.Profile[1].hero.items[9].sync_id == 1 and #u.frames == frame_count)
assert(u.buttons[1].item.sync_id ~= 1, 'Stale page retargeted a claim')
-- A different player taking the first-clicked item between clicks must not
-- turn the second click into a double-click claim of the replacement icon.
c = client(0); u = ui(c)
for i = 1, 8 do c.env.LootService.create(101, 0, 0, 600) end
c.trigger(0); c.env.LootUI.open(1, c.env.LootService.getPile(1))
u.click(u.buttons[1])
c.synchronize(1, 'take:1:1:1')
c.trigger(0); u.click(u.buttons[1]); u.click(u.buttons[1], true)
assert(#u.packets == 0, 'A changed slot received the old double-click action')
print('PASS (mocked frames): real 12x6 paginated panel, stash anchor/width, fixed frame count, stable identity packets, and local input has no item mutations.')
