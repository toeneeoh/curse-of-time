-- Run the production payout function with different levels and party contexts.
local file = assert(io.open('cotlua/src/gameplay/world/colosseum.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b - 1)
end
local env = setmetatable({}, {__index = _G})
env.MAX_LEVEL, env.Hero = 500, {[1] = {}}
local level, honor_rank, gold, honor, progress = 50, 0, 0, 0, 0
env.GetUnitLevel = function() return level end
env.AwardGold = function(pid, amount, notify) assert(pid == 1 and notify); gold = gold + amount end
env.Honor = {
    getRank = function(_, key) assert(key == 'colosseum_spoils'); return honor_rank end,
    award = function(_, amount) honor = honor + amount end,
}
env.Quest = {progress = function(_, key) assert(key == 'colosseum_clear'); progress = progress + 1 end}
env.Player, env.DisplayTextToPlayer = function(p) return p end, function() end
local constants = section('    local COIN_BASE_GOLD =', '    local CHAOS_ARMOR_LEVEL =')
local reward = section('    local colo_reward = function(', '    local function colo_on_cleanup(')
-- Keep the production constants/function in one scope; external variables are
-- the same state the encounter accumulates before paying a player.
local chunk = constants .. '\n' .. reward .. '\nreturn colo_reward'
local function reset(own_level, encounter, coins, rank)
    level, honor_rank, gold, honor, progress = own_level, rank or 0, 0, 0, 0
    env.average_level, env.base_coins, env.bonus_coins, env.rewarded = encounter, coins, {[1] = 0}, {}
    return assert(load(chunk, 'colosseum payout', 't', env))()
end
for _, case in ipairs({{50, 11250}, {75, 26250}, {100, 52500}, {150, 153750}, {200, 345000}, {500, 2025000}}) do
    local reward_fn = reset(case[1], case[1], 10)
    reward_fn(1, false)
    assert(gold == case[2] * 10, 'Wrong payout at level ' .. case[1])
    assert(honor == 0 and progress == 0)
    reward_fn(1, true)
    assert(gold == case[2] * 10 and honor == 0 and progress == 0, 'Paid twice')
end
local reward_fn = reset(50, 200, 10, 5)
env.bonus_coins[1] = 2
reward_fn(1, true)
assert(gold == math.floor(12 * 11250 * (50 / 200)^2 * 1.5))
assert(honor == 1 and progress == 1)
local previous = 0
for own_level = 1, 500 do
    reset(own_level, own_level, 1)(1, false)
    assert(gold >= previous, 'Payout drops across a level boundary')
    previous = gold
end
reset(999, 999, 1)(1, false)
assert(gold == 2025000, 'Maximum-level clamp changed')
print('PASS: early payout curve, monotonic levels 1-500, unchanged level-200+ rewards, carry penalty, bonus coins/Honor, failure payouts, duplicate prevention, and clear progression.')
