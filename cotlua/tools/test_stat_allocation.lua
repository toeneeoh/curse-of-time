-- Real model/service execution with native stubs. No visual or multiplayer claim.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function run(path) assert(loadfile(path, 't', env))() end
OnInit = {global = function(_, f) f() end, final = function(_, f) f(function() end) end}
run('cotlua/src/gameplay/players/stat_allocation_model.lua')
local M = StatAllocationModel
local data = M.create()
assert(M.budget(1, data) == 0 and M.budget(100, data) == 792)
assert(M.pointsPerLevel(100) == 8 and M.pointsPerLevel(109) == 8)
assert(M.pointsPerLevel(110) == 10 and M.pointsPerLevel(120) == 13 and M.pointsPerLevel(500) == 116)
assert(M.earned(500) == 24980 and M.value(10, 100) == 110)
local accumulated = 0
for level = 2, 500 do
    local award = M.pointsPerLevel(level)
    assert(award >= M.pointsPerLevel(level - 1))
    accumulated = accumulated + award
    assert(M.earned(level) == accumulated, 'Cumulative budget disagrees with per-level awards')
end
for _ = 1, 10 do M.distribute(data, 8) end
assert(data.flat[1] == 8 and data.flat[2] == 8 and data.flat[3] == 64)
data.automatic = 1
local saved = {}; M.append(saved, data)
assert(#saved == M.SAVE_FIELDS)
local restored = assert(M.decode(saved, 1, 500))
assert(restored.flat[3] == 64 and restored.automatic == 1 and restored.mastery == nil)
local bad = {}; for i, n in ipairs(saved) do bad[i] = n end
bad[3] = 10000000
assert(select(2, M.decode(bad, 1, 500)))
assert(select(2, M.decode({2}, 1, 500)))
assert(select(2, M.decode({1}, 1, 500)), 'Old allocation format was silently converted')
assert(select(2, M.decode({}, 1, 500)), 'Missing allocation data was silently converted')
-- Execute the actual character values/propagate methods: current data round
-- trips, while older/missing allocation formats are rejected without migration.
local file = assert(io.open('cotlua/src/gameplay/persistence/profile.lua', 'rb'))
local profile_source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local scalar_first = assert(profile_source:find('        local scalar_keys = {', 1, true))
local scalar_last = assert(profile_source:find('        local setter = {', scalar_first, true))
assert(load(profile_source:sub(scalar_first, scalar_last - 1):gsub('local scalar_keys', 'scalar_keys'), 'scalar keys', 't', env))()
HeroData = {}
CHARACTER_SAVE_MAGIC, CHARACTER_SAVE_VERSION = 89123, 4
MAX_INVENTORY_SLOTS, MAX_STASH_SLOTS, STASH_MAX_ROWS = 0, 0, 6
SAVE_UNIT_TYPE = {[1] = 1}
__jarray = function(v) return setmetatable({}, {__index = function() return v end}) end
read_value = function(values, index) return values[index] or 0 end
local function method(first, last)
    local a = assert(profile_source:find(first, 1, true))
    local b = assert(profile_source:find(last, a, true))
    assert(load(profile_source:sub(a, b - 1), first, 't', env))()
end
method('        function HeroData:values()', '        ---@param data integer[]')
method('        function HeroData:propagate(data)', '        ---@return HeroData')
local character = setmetatable({id = 1, level = 500, str = 10, agi = 10, int = 5,
    stat_allocation = data, stash = {}, items = {}}, {__index = HeroData})
local serialized = character:values()
local reconstructed = setmetatable({saved_items = {}}, {__index = HeroData})
assert(reconstructed:propagate(serialized))
assert(reconstructed.stat_allocation.flat[3] == 64 and reconstructed.str == 10)
for _ = 1, M.SAVE_FIELDS do table.remove(serialized) end
local older = setmetatable({saved_items = {}}, {__index = HeroData})
assert(not older:propagate(serialized), 'Missing allocation tail was migrated')
assert(not older:propagate({1, 50, 99999}), 'Legacy character scalars were migrated')
local hero, definition = {level = 1, owner = 0}, {str = 10, agi = 10, int = 5, str_gain = 2, agi_gain = 2, int_gain = 1}
Hero, HERO_STATS, HERO_OBLIVION_GUARD = {[1] = hero}, {[1] = definition}, 999
Unit = {[hero] = {str = 10, agi = 10, int = 5, bonus_str = 1000, bonus_agi = 500, bonus_int = 2000}}
local loaded, cleanup, perk_changed
Profile = {[1] = {playing = true, hero = {unit_id = 1, level = 1, str = 10, agi = 10, int = 5,
    stat_allocation = M.create()}}}
Profile.registerHeroLoadedAction = function(f) loaded = f end
local automation = false
Perks = {getBonuses = function() return {auto_allocation = automation and 1 or 0} end,
    registerChangedAction = function(f) perk_changed = f end}
Town = {isPlayerInServiceArea = function() return true end}
EVENT_STAT_CHANGE = {trigger = function() end}
EVENT_ON_CLEANUP = {register_action = function(_, _, f) cleanup = f end}
PLAYER_CAP = 1
GetHeroLevel = function(u) return u.level end
GOLD, PLATINUM, PLAT_VALUE = 0, 1, 1000000
local money = {[0] = 1000000, [1] = 10}
GetCurrency = function(_, currency) return money[currency] end
SetCurrency = function(_, currency, value) money[currency] = value end
AddCurrency = function(_, currency, delta) money[currency] = money[currency] + delta end
RegisterCurrencyChangedAction = function() end
DisplayTextToPlayer, player_from_pid = function() end, function(pid) return pid - 1 end
file = assert(io.open('cotlua/src/gameplay/economy/currency.lua', 'rb'))
local currency_source = file:read('*a'); file:close()
local charge_first = assert(currency_source:find('    function ChargePlayer(', 1, true))
local charge_last = assert(currency_source:find('    ---@type fun(p: player, flat:', charge_first, true))
assert(load(currency_source:sub(charge_first, charge_last - 1), 'real ChargePlayer', 't', env))()
local effects = 0
AddSpecialEffectTarget = function(_, target) assert(target == hero); effects = effects + 1; return {} end
DestroyEffect = function() end
run('cotlua/src/gameplay/players/stat_allocation.lua')
local A = StatAllocation
loaded(1, Profile[1].hero)
assert(A.available(1) == 0)
hero.level = 110; A.onLevel(1)
assert(A.available(1) == 874)
data = A.get(1)
local generation, revision = A.getGeneration(1), data.revision
assert(A.commit(1, generation, revision, {100, 0, 0}))
assert(effects == 1, 'Successful manual allocation did not play its hero effect')
assert(Unit[hero].str == 110 and Unit[hero].bonus_str == 1000,
    'An allocated point did not grant exactly one base stat')
A.apply(1); A.apply(1)
assert(Unit[hero].str == 110 and Unit[hero].bonus_str == 1000, 'Refresh multiplied assigned stats')
assert(not A.commit(1, generation, revision, {1, 0, 0}), 'Stale draft spent points')
assert(not A.commit(1, generation, data.revision, {9999999, 0, 0}))
assert(not A.commit(1, generation, data.revision, {-1, 0, 0}))
assert(not A.commit(1, generation, data.revision, {1, 0, 0, 1, 0, 0}), 'Retired dual-pool request accepted')
assert(not A.setPlan(1, generation, 1, {1, 1, 8}), 'Automation bypassed the perk')
assert(effects == 1, 'Refresh or rejected allocation played a success effect')
automation = true
assert(A.setPlan(1, generation, 1, {1, 1, 8}))
local bank = A.available(1)
hero.level = 120; A.onLevel(1)
assert(A.available(1) == bank,
    'Automatic plan spent old bank or failed to allocate newly earned points')
local before = data.flat[1] + data.flat[2] + data.flat[3]
assert(before == 203, 'Multi-level automation did not award the full increasing point budget')
A.onLevel(1)
assert(data.flat[1] + data.flat[2] + data.flat[3] == before, 'Duplicate level granted points')
assert(A.addPurchased(1, 50) and data.purchased == 50 and A.available(1) == bank)
local total_budget = M.budget(120, data)
local reset_gold = money[0]
assert(A.resetCost(1) == 12000)
assert(not A.reset(1, generation, 11000) and money[0] == reset_gold,
    'A stale confirmation charged a different reset cost')
money[0], money[1] = 11999, 0
assert(not A.reset(1, generation) and M.available(120, data) ~= total_budget
    and money[0] == 11999, 'Insufficient funds changed allocations or charged gold')
money[0], money[1] = reset_gold, 10
assert(A.reset(1, generation))
assert(money[0] == reset_gold - 12000 and money[1] == 10, 'Reset did not charge exactly the level-scaled fee')
assert(not A.reset(1, generation) and money[0] == reset_gold - 12000, 'Duplicate reset charged twice')
assert(A.available(1) == total_budget and data.automatic == 0 and Unit[hero].bonus_str == 1000)
assert(data.ratio[1] == 0 and data.ratio[2] == 0 and data.ratio[3] == 0, 'Reset retained old ratio weights')
local reset_saved = {}; M.append(reset_saved, data)
assert(M.decode(reset_saved, 1, 120), 'Cleared ratio could not be saved and loaded')
assert(A.setPlan(1, generation, 0, {0, 0, 0}), 'Disabled zero ratio was rejected')
assert(not A.setPlan(1, generation, 1, {0, 0, 0}), 'Empty ratio was enabled')
assert(Unit[hero].str == 10, 'Reset multiplied starting attributes')
Town.isPlayerInServiceArea = function() return false end
assert(not A.reset(1, generation))
-- A replacement character starts with its own ledger. Former scalar totals
-- are never inspected to infer purchases or generate refunded level stats.
hero.level = 50
Profile[1].hero = {unit_id = 1, level = 50, str = 128, agi = 118, int = 64,
    stat_allocation = M.create()}
loaded(1, Profile[1].hero)
assert(A.get(1).purchased == 0 and A.available(1) == 392)
assert(Unit[hero].str == 10 and Unit[hero].agi == 10 and Unit[hero].int == 5)
assert(not A.commit(1, generation, 0, {1, 0, 0}), 'Old hero request applied to a replacement hero')
automation = false; perk_changed(1)
assert(not A.hasAutomation(1))
-- Shop purchases retain the existing quote curve, but award a common point
-- pool. Quotes count unspent raw points and exclude percentage bonuses.
FourCC = function(id) return id end
Player = function(pid) return pid end
GetItem = function(id) return nil, id end
money[0], money[1] = 1000000, 10
TomeCap = function(l) return math.floor(.000003*l^4 + 10*l + .0005*l^3) end
DisplayTextToPlayer = function() end
run('cotlua/src/gameplay/economy/tomes.lua')
data = A.get(1)
local quote = TomeService.quote(1, 'I0TS', 1)
assert(quote.can_buy and quote.gain > 0)
assert(A.commit(1, A.getGeneration(1), data.revision, {100,0,0}))
assert(TomeService.quote(1, 'I0TS', 1).gain == quote.gain, 'Unspent points bypassed diminishing returns')
local bought, gold = data.purchased, money[0]
local purchase = TomeService.commit(1, 'I0TS', 1)
assert(data.purchased == bought + purchase.gain and money[0] == gold - 10000)
assert(TomeService.quote(1, 'I0TT', 1).tome_type == 1, 'Legacy tome entry bypassed the shared pool')
money[0] = 0
bought = data.purchased
assert(not TomeService.commit(1, 'I0TS', 1).can_buy and data.purchased == bought)
hero.level = 110; A.onLevel(1)
money[0] = 1000000
quote = TomeService.quote(1, 'I0TS', 1)
A.apply(1)
assert(TomeService.quote(1, 'I0TS', 1).gain == quote.gain, 'Effective stat refresh changed point pricing')
Town.isPlayerInServiceArea = function() return true end
money[0], money[1] = 0, 1
assert(A.resetCost(1) == 11000 and A.reset(1, A.getGeneration(1)))
assert(money[0] == 989000 and money[1] == 0, 'Reset did not make correct platinum change')
assert(A.commit(1, A.getGeneration(1), data.revision, {1, 0, 0}))
local services_file = assert(io.open('cotlua/src/gameplay/shops/services.lua', 'rb'))
local services_source = services_file:read('*a'); services_file:close()
local focus_first = assert(services_source:find('    function FocusService.quote', 1, true))
local focus_last = assert(services_source:find('    function RetrainingService.quote', focus_first, true))
FocusService = {}
result = function(available, reason) return {available = available, reason = reason} end
assert(load(services_source:sub(focus_first, focus_last - 1), 'real FocusService', 't', env))()
assert(FocusService.quote(1).price == 11000)
local focus_gold = money[0]
assert(FocusService.commit(1).available and money[0] == focus_gold - 11000,
    'Shop reset bypassed the panel reset fee')
cleanup(); assert(A.get(1) == nil)
print('PASS: one point per base stat, 24,980 leveling points, multi-level awards, paid reset, ratio rounding, perk gating, current-format persistence and rejection of old saves.')
