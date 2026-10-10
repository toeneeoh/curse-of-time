-- Actual reward functions with mocked Warcraft natives; no gameplay simulation.
local env = setmetatable({MAX_LEVEL = 500}, {__index = _G})
local _ENV = env
OnInit = {global = function(_, callback) callback(function() end) end, final = function() end}
__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
    return source
end
local function run(path) assert(load(read(path), path, 't', env))() end
run('cotlua/src/gameplay/players/reward_scaling.lua')
run('cotlua/src/gameplay/players/reward_notifications.lua')
run('cotlua/src/gameplay/players/progression.lua')
local scale = RewardScaling.overlevelMultiplier
local function close(actual, expected) assert(math.abs(actual - expected) < 0.0000001) end
for _, enemy in ipairs({3, 29, 100, 160}) do
    for _, gap in ipairs({1, 15, 27, 47, 100}) do
        close(scale(enemy + gap, enemy), 5 / (4 + 1.15 ^ gap))
    end
end
for _, enemy in ipairs({180, 220, 400}) do
    for _, gap in ipairs({1, 15, 30, 50, 100}) do
        close(scale(enemy + gap, enemy), 5 / (4 + 1.08 ^ gap))
    end
end
close(scale(200, 170), 5 / (4 + 1.115 ^ 30))
for enemy = 1, 500 do
    local previous = 1
    for hero = enemy, 500 do
        local multiplier = scale(hero, enemy)
        assert(multiplier >= 0 and multiplier <= 1 and multiplier <= previous)
        close(RewardNotifications.questLevelMultiplier(hero, enemy), multiplier)
        close(Progression.getLevelDifferenceMultiplier(hero, enemy), multiplier)
        previous = multiplier
    end
    assert(scale(enemy, enemy) == 1 and scale(enemy - 1, enemy) == 1)
end
close(Progression.getLevelDifferenceMultiplier(100, 120), 1.5)
assert(scale(200, 3) < scale(179, 3), 'Reaching chaos levels revived obsolete targets')
for _, boundary in ipairs({160, 180}) do
    local before, after = scale(250, boundary - 0.00001), scale(250, boundary + 0.00001)
    assert(math.abs(before - after) < 0.00001, 'Transition is discontinuous')
end
local function xp(hero, enemy)
    return math.floor(EXPERIENCE_TABLE[enemy] * 1.2 * Progression.getLevelDifferenceMultiplier(hero, enemy))
end
assert(xp(30, 3) == 104 and xp(30, 29) == 867 and xp(50, 3) == 6 and xp(50, 50) == 822)
assert(xp(250, 220) == 157 and xp(250, 200) == 46, 'Chaos falloff does not match the stronger curve')
assert(xp(250, 250) == 400, 'Equal-level chaos XP changed')

-- Exercise the actual in-game architecture regression, not just this fixture.
local source = read('cotlua/src/devtools/architecture_tests.lua')
local first = assert(source:find('    ArchitectureTests.register(\n        "overlevel rewards tighten prechaos', 1, true))
local last = assert(source:find('    ArchitectureTests.register(', first + 30, true))
ArchitectureTests = {register = function(_, callback)
    local success, message = callback(); assert(success, message)
end}
assert(load(source:sub(first, last - 1), 'reward architecture regression', 't', env))()
print('PASS: sharper prechaos/chaos XP and quest rewards, unchanged equal-level XP, smooth enemy-level transition, monotonic falloff, and in-game architecture regression.')
print('Solo examples: level 30 vs troll 3 = 104 XP; vs ogre 29 = 867 XP; level 50 vs troll 3 = 6 XP; vs level 50 = 822 XP.')
