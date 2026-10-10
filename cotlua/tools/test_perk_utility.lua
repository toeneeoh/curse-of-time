-- Offline checks of real domain functions; no claim about native WC3 UI.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close(); return source
end
local function extract(path, first_marker, last_marker, prefix, suffix)
    local source = read(path)
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first + #first_marker, true))
    assert(load((prefix or '') .. source:sub(first, last - 1) .. (suffix or ''), path, 't', env))()
end
local bonuses = {potion_restoration = .09, potion_duration = .10,
    potion_refill_discount = .12, recharge_discount = .09, reincarnation_capacity = 1, home_channel = .25}
Perks = {getBonuses = function() return bonuses end}
local potion = {pid = 1, charges = 5, cached_stats = {200, 10, 50, 20}}
PotionService = {getProperties = function() return {level_requirement = 10, flat_health = 100, flat_mana = 50} end}
extract('cotlua/src/gameplay/items/potions.lua', '    function PotionService.getRefillCost', '    ---Refills one potion')
assert(PotionService.getRefillCost(potion, 1) == 154)
assert(PotionService.getRefillCost({}) == 175, 'Unowned item acquired a profile discount')
local hero = {life = 100}
Hero, Unit = {[1] = hero}, {[hero] = {hp = 1000, mana = 100, regen_percent = 1}}
ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL, ITEM_FLAT_MANA, ITEM_PERCENT_MANA = 1, 2, 3, 4
potion_at, potion_behavior = function() return potion end, function() return nil end
UnitAlive, GetWidgetLife = function() return true end, function(u) return u.life end
local mana_received, context
HP = function(_, u, value) u.life = u.life + value end
MP = function(_, value) mana_received = value end
UndyingRageBuff = {has = function() return false end}
PotionService.getCooldown, PotionService.getUseCooldown = function() return 0 end, function() return 5 end
PotionService.getCustomization = function()
    return {catalyst = {duration_multiplier = 1.5}, infusion = {on_use = function(value) context = value end}}
end
PotionService.getInfusionMultiplier, PotionService.describe = function() return 1 end, function() return 'Test Flask' end
local cooldowns = {}
cooldown_table = function() return cooldowns end
TQ = {callDelayed = function() return {} end}
clear_cooldown, NotifyItemChanged = function() end, function() end
extract('cotlua/src/gameplay/items/potions.lua', '    function PotionService.use', '    local function prepare_vampire_flask')
assert(PotionService.use(1, 1).success and potion.charges == 4)
assert(math.abs(context.heal - 327) < 1e-9 and math.abs(mana_received - 76.3) < 1e-9)
assert(math.abs(context.duration_multiplier - 1.65) < 1e-9)
assert(context.item.cached_stats[1] == 200, 'Perk rewrote the saved potion roll')

Profile = {[1] = {hero = {hardcore = 1}}}
RechargeService = {}
result = function(available, reason) return {available = available, reason = reason} end
local resurrection = {id = 1, charges = 2}
GetResurrectionItem = function() return resurrection end
MAX_REINCARNATION_CHARGES, RECHARGE_COOLDOWN = 3, {[1] = 0}
GOLD, PLATINUM, ITEM_COST = 1, 2, 1
ItemData = {[1] = {[1] = 100}}
GetCurrency, R2I = function(_, currency) return currency == GOLD and 1000000 or 100 end, math.floor
extract('cotlua/src/gameplay/shops/services.lua', '    function RechargeService.quote', '    function RechargeService.commit')
local quote = RechargeService.quote(1)
assert(quote.available and quote.maximum_charges == 4)
assert(quote.gold == math.floor(30300 * .91) and quote.platinum == 3)
resurrection.charges = 3; assert(RechargeService.quote(1).available)
resurrection.charges = 4; assert(RechargeService.quote(1).reason == 'FULL')
RECHARGE_COOLDOWN[1] = 1; resurrection.charges = 2
assert(RechargeService.quote(1).reason == 'COOLDOWN', 'Capacity perk bypassed recharge cooldown')
RECHARGE_COOLDOWN[1] = 0
local saved_bonuses = bonuses; bonuses = {}
resurrection.charges = 3; assert(RechargeService.quote(1).reason == 'FULL')
resurrection.charges = 2; quote = RechargeService.quote(1)
assert(quote.available and quote.gold + quote.platinum * 1000000 == 3030300)
bonuses = saved_bonuses

OnInit = {final = function(_, callback) callback(function() end) end}
Spell = {define = function(id) return {id = id} end}
TimerQueue, FPS_32 = TQ, 1 / 32
local channel
TimerList = {[1] = {add = function() return {startLoop = function(self) channel = self.time end} end}}
Backpack = {[1] = {}}
PauseUnit, BlzSetSpecialEffectTimeScale, BlzSetSpecialEffectColorByPlayer, BlzSetSpecialEffectZ = function() end, function() end, function() end, function() end
GetUnitX, GetUnitY, BlzGetUnitZ = function() return 0 end, function() return 0 end, function() return 0 end
AddSpecialEffect, Player = function() return {} end, function(pid) return pid end
assert(load(read('cotlua/src/gameplay/players/teleport_abilities.lua'), 'teleport', 't', env))()
local cast = setmetatable({pid = 1, caster = hero, ablev = 1}, {__index = TELEPORT_HOME})
cast:onCast(); assert(channel == 9)
cast.ablev = 2; cast:onCast(); assert(channel == 6.75)
cast.ablev = 10; cast:onCast(); assert(channel == 1)

-- Run actual profile loaders against old and expanded allocation tails.
PROFILE_SAVE_VERSION, PROFILE_PERK_NODE_WORDS, PROFILE_PERK_SLOTS, MAX_SLOTS = 123, 8, 8, 40
__jarray = function(v) return setmetatable({}, {__index = function() return v end}) end
Profile.create = function(pid)
    return setmetatable({pid = pid, checksums = {}, perk_ranks = __jarray(0), perk_node_words = __jarray(0)}, {__index = Profile})
end
GetHotkeyTable, LoadHotkey = function() return {1, 2} end, function() end
DisplayTimedTextToPlayer = function() end
local data = {123}
for slot = 1, 40 do data[#data + 1] = slot end
for _, value in ipairs({11, 12, 999, 0, 0, 0, 0, 0, 0, 0, 0, 72, 1, 123, 456, 789}) do data[#data + 1] = value end
Decompile = function() return data end
extract('cotlua/src/gameplay/persistence/profile.lua', '        function thistype.load', '        ---@return integer', 'local thistype = Profile\n')
assert(Profile.load('old', 1))
assert(Profile[1].total_time == 999 and Profile[1].perk_budget_seen == 72)
assert(Profile[1].perk_node_words[3] == 789 and Profile[1].perk_node_words[8] == 0)
for word = 4, 8 do data[#data + 1] = word * 100 end
assert(Profile.load('expanded', 1))
assert(Profile[1].checksums[40] == 40 and Profile[1].perk_node_words[8] == 800)
SaveHotkey = function(_, index) return index + 10 end
Compile = function(_, generated) data = generated; return 'roundtrip' end
extract('cotlua/src/gameplay/persistence/profile.lua', '        function thistype:save_profile()',
    '            if GAME_STATE == 2 then', 'local thistype = Profile\n', '\nend\n')
Profile[1]:save_profile()
assert(Profile.load('roundtrip', 1))
assert(Profile[1].perk_node_words[3] == 789 and Profile[1].perk_node_words[8] == 800)

-- Exercise the actual wire codec too, with only native name/hash calls mocked.
OnInit.global = OnInit.final
SAVE_SCRAMBLE_VERSION = 12345
GetPlayerName = function() return 'PerkTester' end
StringChecksum = function(value)
    local hash = 5381
    for index = 1, #value do hash = (hash * 33 + value:byte(index)) % 2147483647 end
    return hash
end
assert(load(read('cotlua/src/gameplay/persistence/code_gen.lua'), 'code_gen', 't', env))()
for word = 1, 8 do Profile[1].perk_node_words[word] = 0x3fffffff end
Profile[1]:save_profile()
local wire = Profile[1].profile_code
assert(Profile.load(wire, 1))
for word = 1, 8 do assert(Profile[1].perk_node_words[word] == 0x3fffffff) end
local old_data = {}
for index = 1, #data - 5 do old_data[index] = data[index] end
assert(Profile.load(Compile(1, old_data), 1))
assert(Profile[1].perk_node_words[3] == 789 and Profile[1].perk_node_words[8] == 0)
print('PASS: potion restoration/duration/refill hooks, reincarnation capacity/price/cooldown, Return Home channel, and old/expanded profile tails.')
