-- Execute the current character DTO and its real architecture assertions.
-- Host Lua only: no Warcraft item creation, file saves or multiplayer claim.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close(); return source
end
OnInit = {global = function(_, callback) callback(function() end) end}
assert(load(read('cotlua/src/gameplay/players/stat_allocation_model.lua'), 'model', 't', env))()
__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
MAX_INVENTORY_SLOTS, MAX_STASH_SLOTS, STASH_MAX_ROWS = 26, 36, 6
MAX_SOCKETS, MAX_ITEM_STATE_VALUES, MAX_ITEM_STATE_VALUE = 3, 16, 0x7FFFFFFF
local beta_version = assert(read('cotlua/src/devtools/dev.lua'):match('CHARACTER_SAVE_VERSION%s*=%s*(0x%x+)'))
CHARACTER_SAVE_MAGIC, CHARACTER_SAVE_VERSION = 271828, assert(tonumber(beta_version))
SAVE_UNIT_TYPE = {[1] = 1}
local profile = read('cotlua/src/gameplay/persistence/profile.lua')
local first = assert(profile:find('    HeroData = {}', 1, true))
local last = assert(profile:find('    ---@type fun(level: integer):integer', first, true))
assert(load(profile:sub(first, last - 1), 'real HeroData DTO', 't', env))()
local architecture = read('cotlua/src/devtools/architecture_tests.lua')
local passed = 0
ArchitectureTests = {register = function(name, test)
    local ok, reason = test()
    assert(ok, name .. ': ' .. tostring(reason))
    passed = passed + 1
end}
local function run(name)
    local marker = architecture:find('"' .. name .. '"', 1, true)
    assert(marker, name)
    local start, cursor = nil, 1
    while true do
        local found = architecture:find('    ArchitectureTests.register(', cursor, true)
        if not found or found > marker then break end
        start, cursor = found, found + 1
    end
    local finish = assert(architecture:find('    ArchitectureTests.register(', marker, true))
    assert(load(architecture:sub(start, finish - 1), name, 't', env))()
end
run('unknown character version is rejected')
run('oversized item state is rejected')
run('character saves round-trip and reject incompatible formats')
run('character inventory DTO preserves sparse slots and sockets')
assert(passed == 4)
-- A previous beta version must fail at the header before its item layout is read.
local old = HeroData.create(); old.id, old.level = 1, 1
local values = old:values()
values[2] = 0x40000002
values[19], values[20], values[21], values[22], values[23] = 1, 0, 0, 0, 999
local ok, reason = HeroData.create():propagate(values)
assert(not ok and reason:find('Unsupported character save version', 1, true),
    'Old beta data reached item parsing before version rejection')
values[2] = CHARACTER_SAVE_VERSION
ok, reason = HeroData.create():propagate(values)
assert(not ok and reason:find('Invalid item socket count: 999', 1, true),
    'Current-format invalid socket data was not rejected')
print('PASS (real DTO/architecture callbacks): current saves, sparse inventory/stash sockets, reset ratios, and early rejection of incompatible beta versions.')

-- Tickets must encode as empty slots in both inventory and stash, even though
-- their custom rawcode was registered normally. Exercise the real encoder and
-- ItemToIndex policy, then the actual character serializer and DTO snapshot.
FourCC = function(id) return string.unpack('>I4', id) end
SAVE_TABLE = {KEY_ITEMS = {[FourCC('I008')] = 8, [FourCC('I01V')] = 100}}
local helpers = read('cotlua/src/gameplay/items/helpers.lua')
first = assert(helpers:find('    function ItemIsSaveExcluded', 1, true))
last = assert(helpers:find('    ---@type fun(u: unit', first, true))
assert(load(helpers:sub(first, last - 1), 'real item save policy', 't', env))()
local items = read('cotlua/src/gameplay/items/item.lua')
first = assert(items:find('        function thistype:encode_id()', 1, true))
last = assert(items:find('        function thistype:drop(', first, true))
thistype = {}
assert(load(items:sub(first, last - 1), 'real item id encoder', 't', env))()
local item_class = thistype
local function saved_item(code)
    return setmetatable({id = FourCC(code), level = 0, quality = {0, 0},
        encode_stats = function() return 0 end, encode_extra = function() return 0 end}, {__index = item_class})
end
local admission, equipment = saved_item('I008'), saved_item('I01V')
assert(admission:encode_id() == 0 and equipment:encode_id() == 100)
local character = HeroData.create(); character.id, character.level = 1, 1
character.items[9], character.items[10] = admission, equipment
character.stash[1], character.stash[2] = admission, equipment
character:update_saved_items()
assert(not character.saved_items[9] and not character.saved_stash[1])
assert(character.saved_items[10].id == 100 and character.saved_stash[2].id == 100)
local restored = HeroData.create()
assert(restored:propagate(character:values()))
assert(not restored.saved_items[9] and not restored.saved_stash[1])
assert(restored.saved_items[10].id == 100 and restored.saved_stash[2].id == 100)
print('PASS: Colosseum tickets are omitted from inventory/stash saves and snapshots; adjacent equipment remains intact.')

-- The normal save gate must also omit explicitly excluded items, while still
-- rejecting unsupported inventory, stash, and socket encodings.
local live_hero = {id = 123}
Hero, Backpack, Unit = {[1] = live_hero}, {[1] = {}}, {[live_hero] = {str = 10, agi = 10, int = 15}}
SAVE_TABLE.KEY_UNITS = {[123] = 1}
GetUnitTypeId = function(unit) return unit.id end
GetHeroLevel, GetCurrency, GetUnitAbilityLevel = function() return 1 end, function() return 0 end, function() return 1 end
Progression = {getXPIntoLevel = function() return 0 end}
TELEPORT_HOME = {id = 456}
MAX_STATS, MAX_GOLD, MAX_PLAT_CRYS, MAX_HONOR, MAX_FACTION, MAX_TIME_PLAYED = 255000, 10000000, 100000, 10000, 10000, 100000
Player, GetLocalPlayer = function(id) return id end, function() return -1 end
DisplayTimedTextToPlayer = function() end
GetObjectName = tostring
GAME_STATE = 0
local compiled
Compile = function(_, values) compiled = values; return 'test-code' end
thistype = {}
first = assert(profile:find('        function thistype:save_character()', 1, true))
last = assert(profile:find('        function thistype:skin(', first, true))
assert(load(profile:sub(first, last - 1), 'real normal character save', 't', env))()
character.time = 10
local owner_profile = {pid = 1, hero = character, current_slot = 1, character_code = {},
    save_profile = function(self) self.profile_saved = true end}
assert(thistype.save_character(owner_profile), 'Explicit unsaveables blocked normal saving')
assert(compiled and owner_profile.profile_saved and owner_profile.character_code[1] == 'test-code')
restored = HeroData.create(); assert(restored:propagate(compiled))
assert(not restored.saved_items[9] and not restored.saved_stash[1] and restored.saved_items[10].id == 100)
local unsupported = saved_item('I999')
character.items[11] = unsupported
assert(not thistype.save_character(owner_profile), 'Unsupported inventory item was silently omitted')
character.items[11] = nil; character.stash[3] = unsupported
assert(not thistype.save_character(owner_profile), 'Unsupported stash item was silently omitted')
character.stash[3] = nil; equipment.sockets = {unsupported}
assert(not thistype.save_character(owner_profile), 'Unsupported socket was silently omitted')
equipment.sockets = {}
print('PASS: normal save accepts explicit exclusions in inventory/stash and rejects unsupported items/sockets.')
