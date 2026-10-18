-- Execute the real fixture command service, item encoders, and character DTO.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local value = file:read('*a'):gsub('\r\n', '\n'); file:close(); return value
end
local function extract(path, first, last)
    local source = read(path)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return assert(load(source:sub(a, b - 1), path, 't', env))()
end
OnInit = {final = function(_, callback) callback(function() end) end}
OnInit.global = OnInit.final
FourCC = function(id) return string.unpack('>I4', id) end
__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
MAX_INVENTORY_SLOTS, MAX_STASH_SLOTS, STASH_COLUMNS, STASH_MAX_ROWS = 26, 36, 6, 6
BACKPACK_INDEX, POTION_INDEX, MAX_SOCKETS, QUALITY_SAVED = 9, 7, 3, 7
MAX_ITEM_STATE_VALUES, MAX_ITEM_STATE_VALUE = 16, 0x7FFFFFFF
CHARACTER_SAVE_MAGIC, CHARACTER_SAVE_VERSION, SAVE_UNIT_TYPE = 271828, 0x40000004, {[1] = 123}
SAVE_TABLE = {KEY_ITEMS = setmetatable({}, {__index = function(_, id) return id & 0x1FFF end})}
assert(load(read('gameplay/players/stat_allocation_model.lua'), 'allocation model', 't', env))()
extract('gameplay/persistence/profile.lua', '    HeroData = {}', '    ---@type fun(level: integer):integer')
extract('gameplay/items/helpers.lua', '    function ItemIsSaveExcluded', '    ---@type fun(u: unit')
local ItemClass = {}
thistype = ItemClass
extract('gameplay/items/item.lua', '        function thistype:encode_state()', '        function thistype:drop(')
local created, updates, notifications, refreshes, fail_create, fail_validation = {}, 0, 0, 0
function ItemClass:name() return string.pack('>I4', self.id) end
function ItemClass:update() self.updated_sockets = #self.sockets; updates = updates + 1 end
function ItemClass:destroy()
    if not self.alive then return false end
    for _, socket in ipairs(self.sockets) do socket:destroy() end
    if self.index then Profile[self.pid].hero.items[self.index] = nil end
    self.alive = false
    return true
end
ItemRuntime = {create = function(id, x, y)
    assert(x == 30000 and y == 30000)
    if fail_create and #created + 1 == fail_create then return nil end
    local item = setmetatable({id = id, obj = {}, alive = true, level = 0,
        sockets = {}, quality = {1, 2, 3, 4, 5, 6, 7}, extra = {0, 0}, charges = 3}, {__index = ItemClass})
    created[#created + 1] = item
    return item
end}
ItemRuntime.commit_slot = function(item, slot)
    local data = Profile[item.pid].hero
    assert(not data.items[slot], 'Overwrote an existing item')
    assert(item.updated_sockets == #item.sockets, 'Equipped a stale socket cache')
    item.index, item.equipped = slot, slot <= 6
    data.items[slot] = item
    return true
end
ValidateItemSlot = function() return not fail_validation, 'test validation failure' end
PotionService = {GREATER_HEALTH_KEY = 'greater_health_flask', create = function(key, x, y, expiry, affixes)
    assert(key == 'greater_health_flask' and expiry == nil and affixes == false)
    local item = ItemRuntime.create(FourCC('I02F'), x, y)
    if item then item.extra[2], item.persistent_state = 123, {7, 0, 42} end
    return item
end}
Player = function(id) return id end
SetItemVisible = function(obj, visible) obj.visible = visible end
UnitAlive = function(hero) return not hero.dead end
NotifyItemChanged = function() notifications = notifications + 1 end
StashUI = {refresh = function() refreshes = refreshes + 1 end}
Profile, Hero = {}, {}
assert(load(read('devtools/inventory_loadout.lua'), 'inventory test fixtures', 't', env))()
local function reset()
    local data = HeroData.create(); data.id, data.level = 1, 1
    Profile[1], Hero[1] = {hero = data}, {}
    created, updates, notifications, refreshes, fail_create, fail_validation = {}, 0, 0, 0, nil, false
    return data
end
local data = reset()
local ok, report = DevInventoryLoadout.populate(1)
assert(ok and #report == 13 and data.stash_rows == 4)
assert(#created == 16 and data.items[1].equipped and #data.items[1].sockets == 3)
for _, socket in ipairs(data.items[1].sockets) do
    assert(socket.parent == data.items[1] and socket.socketed and socket.pid == 1 and socket.owner == 0)
end
assert(data.items[2] == nil and data.items[10] == nil and data.stash[2] == nil, 'Lost sparse slots')
assert(data.items[7].charges == 1 and data.items[8].charges == 0)
assert(data.items[9].charges == 2 and data.items[11].charges == 0 and data.items[15].charges == 7)
assert(#data.stash[1].sockets == 1 and data.stash[8].charges == 1 and data.stash[18].charges == 2)
assert(data.stash[18].extra[2] == 123 and data.stash[18].persistent_state[3] == 42)
assert(data.items[26]:encode_id() == 0 and data.stash[24]:encode_id() == 0)
assert(data.level == 1 and notifications > 0 and refreshes == 1)
local decoded = HeroData.create()
assert(decoded:propagate(data:values()))
assert(decoded.stash_rows == 4 and not decoded.saved_items[26] and not decoded.saved_stash[24])
assert(#decoded.saved_items[1].sockets == 3 and #decoded.saved_stash[1].sockets == 1)
assert((decoded.saved_items[8].extra >> 16) == 0x8000 and (decoded.saved_items[11].extra >> 16) == 0x8000)
assert((decoded.saved_items[15].extra >> 16) == (0x8000 | 7))
assert(decoded.saved_stash[18].state[3] == 42 and (decoded.saved_stash[18].extra & 0xFFFF) == 123)
-- Existing items, full potion slots, unlocked rows, and other players survive.
data = reset(); data.stash_rows = 6
local existing = setmetatable({id = FourCC('I021'), level = 0, quality = {0, 0, 0, 0, 0, 0, 0},
    extra = {0, 0}, charges = 1, sockets = {}}, {__index = ItemClass})
for _, slot in ipairs({1, 7, 8, 15, 26}) do data.items[slot] = existing end
data.stash[1], data.stash[24] = existing, existing
Profile[2], Hero[2] = {hero = {items = {existing}, stash_rows = 2}}, {}
assert(DevInventoryLoadout.populate(1))
for _, slot in ipairs({1, 7, 8, 15, 26}) do assert(data.items[slot] == existing) end
assert(data.stash[1] == existing and data.stash[24] == existing and data.stash_rows == 6)
assert(Profile[2].hero.items[1] == existing and Profile[2].hero.stash_rows == 2)
-- Reject before allocating handles if there is no hero or enough capacity.
data = reset(); Hero[1].dead = true
assert(not DevInventoryLoadout.populate(1) and #created == 0)
data = reset(); for slot = 1, 26 do data.items[slot] = existing end
assert(not DevInventoryLoadout.populate(1) and #created == 0 and data.stash_rows == 1)
data = reset(); for slot = 1, 24 do data.stash[slot] = existing end
assert(not DevInventoryLoadout.populate(1) and #created == 0 and data.stash_rows == 1)
-- Creation/validation failures clean up only the newly allocated fixtures.
for _, failure in ipairs({'create', 'validate'}) do
    data = reset(); data.items[2], data.stash[2] = existing, existing
    if failure == 'create' then fail_create = 5 else fail_validation = true end
    assert(not DevInventoryLoadout.populate(1))
    assert(data.items[2] == existing and data.stash[2] == existing and data.stash_rows == 1)
    for _, item in ipairs(created) do assert(not item.alive, 'Leaked failed test fixture') end
    for slot, item in pairs(data.items) do assert(slot == 2 and item == existing) end
    for slot, item in pairs(data.stash) do assert(slot == 2 and item == existing) end
end
-- Exercise the actual developer chat command adapter and its player-scoped report.
local dev = read('devtools/dev.lua')
local first = assert(dev:find('        ["invtest"] = function(p, pid)', 1, true))
local last = assert(dev:find('        ["loottest"] =', first, true))
local commands = assert(load('return {\n' .. dev:sub(first, last - 1) .. '\n}', 'invtest chat command', 't', env))()
local messages = {}
DisplayTimedTextToPlayer = function(player, _, _, _, line)
    assert(player == 0); messages[#messages + 1] = line
end
reset(); commands.invtest(0, 1)
assert(#messages == 13 and messages[1]:find('Save normally', 1, true))
Hero[1].dead = true; commands.invtest(0, 1)
assert(#messages == 14 and messages[14] == 'Select a living hero first.')
print('PASS: fixture slot placement, sockets/ownership, charges/zero/stack, runtime state, stash rows, real character serialization, unsaveables, preserved existing items, capacity preflight and failure cleanup.')
