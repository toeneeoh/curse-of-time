-- Real record creation, roll calculation, tooltip update, native attachment and
-- destruction. Native handles are mocked; this is not an engine leak test.
local file = assert(io.open('cotlua/src/gameplay/items/item.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local function section(first, last)
    local a = assert(source:find(first, 1, true), first)
    local b = assert(source:find(last, a + #first, true), last)
    return source:sub(a, b - 1)
end
local env = setmetatable({}, {__index = _G})
local _ENV = env
local objects, handles, triggers, rolls, calls = {}, {}, {}, 0, 0
__jarray = function(default) return setmetatable({}, {__index = function() return default end}) end
ITEM_RARITY, ITEM_LIMIT, ITEM_TYPE, ITEM_ABILITY, ITEM_NOCRAFT = 1, 2, 3, 4, 5
ITEM_ABILITY2 = 5
ITEM_CHARGES, ITEM_TIER, ITEM_UPGRADE_MAX, ITEM_LEVEL_REQUIREMENT = 6, 7, 8, 9
TOTAL_STATS, QUALITY_SAVED, CUSTOM_ITEM_OFFSET, MAX_ITEM_RARITY_INDEX = 10, 5, 0, 7
ITEM_STAT_MULTIPLIER, DISPLAY_STATS, ITEM_EXTRA_INFO = __jarray(0), {}, {}
ITEM_SPELL_AREA, ITEM_SPELL_DURATION = 11, 12
ITEM_MODEL, RARITY_NAME, TIER_NAME, TYPE_NAME = __jarray('model'), __jarray('Rare'), __jarray('Tier'), __jarray('Equipment')
ITEM_MODEL[3] = 'epic-world-model'
concat, floor = table.concat, math.floor
local data = __jarray(0)
data.name, data.path, data.tooltip = 'Reward', 'icon', 'flavor text'
data[ITEM_RARITY], data[ITEM_TYPE], data[ITEM_TIER], data[ITEM_UPGRADE_MAX], data[ITEM_CHARGES] = 4, 2, 1, 10, 2
data[10], data['10range'] = 100, 200
ItemData = {[101] = data}
SAVE_TABLE, IS_ITEM_DROP = {KEY_ITEMS = {}}, __jarray(true)
item_data = function(item) return item.data or ItemData[item.id] end
GetRandomInt = function() rolls = rolls + 1; return rolls % 64 end
GetLocalPlayer, GetPlayerId = function() return 0 end, function(p) return p end
CreateItem = function(id)
    calls = calls + 1
    local object = assert(io.open('cotlua/src/gameplay/items/item.lua', 'rb'))
    handles[#handles + 1] = object
    objects[object] = {id = id, life = 1}; return object
end
BlzSetItemSkin = function(object, skin) assert(objects[object]); objects[object].skin = skin end
GetItemTypeId = function(object) return assert(objects[object]).id end
GetItemCharges, GetItemX, GetItemY = function() return 2 end, function() return 0 end, function() return 0 end
BlzGetItemBooleanField = function() return false end
RemoveItem = function(object) assert(objects[object] and objects[object].life > .405); objects[object] = nil end
CreateTrigger = function() local t = {}; triggers[t] = true; return t end
DestroyTrigger = function(t) assert(triggers[t]); triggers[t] = nil end
TriggerRegisterDeathEvent, TriggerAddCondition = function() end, function() end
set_widget_life = function(object, life) objects[object].life = life end
SetWidgetLife = set_widget_life
for _, name in ipairs({'BlzSetItemName','BlzSetItemIconPath','BlzSetItemTooltip',
    'BlzSetItemDescription','BlzSetItemExtendedTooltip','SetItemCharges','SetItemVisible'}) do
    env[name] = function(object) assert(object and objects[object], name .. ' touched a nil/dead handle') end
end
NotifyItemChanged = function() end
local delayed = 0
TQ = {callDelayed = function() delayed = delayed + 1; return delayed end, disableCallback = function() end}
RuntimeMetrics = {items = {created = 0, destroyed = 0, live = 0, peak = 0}}
Item, ItemRuntime = {}, {definitions = {}}
thistype, mt = Item, {__index = Item}
assert(load(section('        local NativeCreateItem = CreateItem', '        ---Returns the rarity') ..
    section('        function ItemRuntime.getRarityIndex', '        ---Chooses the more punitive') ..
    section('        function ItemRuntime.applyData', '        local backpack_allowed'), 'real creation/materialization', 't', env))()
assert(load(section('        function Item:cache_stats()', '        local function remove_item_ability'), 'real calculation', 't', env))()
assert(load(section('        function thistype:update', '        ---@type fun(id: integer, stats:'), 'real presentation', 't', env))()
assert(load(section('        function thistype:onDestroy()', '\n    end\n\nend, Debug'), 'real destruction', 't', env))()
Item.drop = function() end
local a = ItemRuntime.withRecords(ItemRuntime.create, 101, 25, 50, 600)
local b = ItemRuntime.withRecords(ItemRuntime.create, 101, 25, 50, 600)
assert(calls == 1 and not next(objects) and not next(triggers), 'Data records retained native items or triggers')
assert(delayed == 0 and rolls == 2 and a.sync_id ~= b.sync_id)
assert(a.x == 25 and a.y == 50 and a.ground_lifetime == 600)
a.level, a.extra[2], a.persistent_state[1] = 5, 77, 1234
a:update(true)
local value, quality, text = a.cached_stats[10], a.quality[1], a.tooltip
local before_rolls, identity = rolls, a.sync_id
assert(ItemRuntime.materialize(a))
assert(a.obj and a.trig and a.sync_id == identity and a.cached_stats[10] == value)
assert(a.quality[1] == quality and a.tooltip == text and rolls == before_rolls)
assert(a.extra[2] == 77 and a.persistent_state[1] == 1234)
-- A socket's own handle also disappears when the dropped parent becomes data.
a.sockets[1] = b
assert(ItemRuntime.materialize(b))
ItemRuntime.dematerialize(a)
assert(not a.obj and not b.obj and not next(objects) and not next(triggers))
assert(ItemRuntime.materialize(a) and b.obj and rolls == before_rolls)
a:destroy()
assert(not a.alive and not b.alive and not next(objects) and not next(triggers))
assert(RuntimeMetrics.items.live == 0)
-- Execute the real logical-definition apply/initialize/restore path too; a
-- shared carrier must retain custom identity, seeds and calculated properties.
OnInit = {final = function(_, callback) callback(function() end) end}
ParseItemDefinition = function(name, icon, tooltip)
    local copy = __jarray(0)
    for k, v in pairs(data) do copy[k] = v end
    copy.name, copy.path, copy.tooltip = name, icon, tooltip
    return copy
end
assert(loadfile('cotlua/src/gameplay/items/runtime_item_definitions.lua', 't', env))()
local definition = RuntimeItemDefinitions.define('test_record', {
    id = 77, carrier = 101, name = 'Logical reward', icon = 'logical', tooltip = 'Logical flavor', world_skin = 303,
    initialize_item = function(item) item.persistent_state[1] = GetRandomInt(1, 100); item.quality[2] = 42 end,
    append_stats = function(item, text) text[#text + 1] = ' seed=' .. item.persistent_state[1] end,
    restore_item = function(item) item.display_name = 'Restored logical reward' end,
})
local logical = ItemRuntime.withRecords(RuntimeItemDefinitions.create, definition, 0, 0, 600)
local logical_seed, logical_rolls, logical_text = logical.persistent_state[1], rolls, logical.tooltip
assert(not logical.obj and logical.extra[2] == 77 and logical.runtime_definition == definition)
assert(ItemRuntime.materialize(logical))
assert(logical.persistent_state[1] == logical_seed and logical.quality[2] == 42 and rolls == logical_rolls)
assert(logical.tooltip == logical_text and logical.display_name == 'Restored logical reward')
assert(objects[logical.obj].skin == 303, 'Explicit logical model override was lost')
logical:destroy(); assert(RuntimeMetrics.items.live == 0 and not next(objects))
local potion_definition = RuntimeItemDefinitions.define('rarity_flask', {
    id = 78, carrier = 101, name = 'Rarity flask', icon = 'flask', tooltip = 'Flask flavor', display_rarity = 3,
})
local potion = ItemRuntime.withRecords(RuntimeItemDefinitions.create, potion_definition, 0, 0, 600)
assert(potion.level == 0 and ItemRuntime.getRarityIndex(potion) == 3)
assert(ItemRuntime.getWorldSkin(potion) == ITEM_MODEL[3], 'Level-zero logical rarity ignored by world model')
assert(ItemRuntime.materialize(potion) and objects[potion.obj].skin == ITEM_MODEL[3])
ItemRuntime.dematerialize(potion)
assert(ItemRuntime.materialize(potion) and objects[potion.obj].skin == ITEM_MODEL[3])
potion:destroy(); assert(RuntimeMetrics.items.live == 0 and not next(objects))
-- Factory failure must not leave the global creation mode in record scope.
assert(not pcall(ItemRuntime.withRecords, function() error('factory failure') end))
local owned = ItemRuntime.create(101)
assert(owned.obj and owned.trig and not owned.data_only)
owned:destroy()
for _, handle in ipairs(handles) do handle:close() end
print('PASS (actual Item runtime): one-time OE priming, no native handles/triggers/expiry per ground record, exact roll/state/tooltip preservation through materialization, recursive socket disposal, and error-safe factory scope.')
