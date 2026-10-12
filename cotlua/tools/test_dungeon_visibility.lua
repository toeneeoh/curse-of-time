-- Offline test of the actual dev loadout command: it must not reveal the map.
local file = assert(io.open('cotlua/src/devtools/dev.lua', 'rb'))
local source = file:read('*a'); file:close()
local first = assert(source:find('["test"] = function', 1, true))
local last = assert(source:find('["balance"] = function', first, true))
local env = setmetatable({}, {__index = _G})
env.Hero = {[1] = {}}
env.GOLD, env.PLATINUM, env.CRYSTAL, env.FACTION = 0, 1, 2, 3
local currencies, level, honor, experience, loadout = {}, nil, nil, false, false
env.SetCurrency = function(pid, kind, amount) assert(pid == 1); currencies[kind] = amount end
env.Honor = {setTotal = function(pid, value) assert(pid == 1); honor = value end}
env.SetHeroLevel = function(hero, value) assert(hero == env.Hero[1]); level = value end
env.ExperienceControl = function(pid) assert(pid == 1); experience = true end
env.grant_vampire_colosseum_loadout = function(pid) assert(pid == 1); loadout = true end
env.FogEnable, env.FogMaskEnable = function() error('-test must not change fog') end,
    function() error('-test must not change fog mask') end
local commands = assert(load('return {' .. source:sub(first, last - 1) .. '}', 'dev-test-command', 't', env))()
commands.test(0, 1, {})
assert(level == 400 and honor == 9999 and experience and loadout and currencies[0] == 9999999)
print('PASS: dev loadout retains rewards/level setup without disabling dungeon visibility.')
