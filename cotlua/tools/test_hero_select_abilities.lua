-- Offline checks for selectable-hero stats and the current Dark Savior kit.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a')
    file:close()
    return source
end
local source = read('config/hero_definitions.lua')
local env = setmetatable({}, {__index = _G})
for key in source:gmatch('HERO_[A-Z_]+') do env[key] = key end
for key in source:gmatch('PROF_[A-Z_]+') do env[key] = 0 end
env.FourCC = function(id) return id end
env.OnInit = {global = function(_, callback) callback(function() end) end}
assert(load(source, 'hero definitions', 't', env))()
local count = 0
for id, definition in pairs(env.HERO_STATS) do
    count = count + 1
    local total = 0
    for _, stat in ipairs({'str', 'agi', 'int'}) do
        local value = definition[stat]
        assert(type(value) == 'number' and value % 1 == 0 and value >= 0, id .. ': invalid starting ' .. stat)
        total = total + value
        assert(definition[definition.main] >= value, id .. ': primary attribute is not a largest starting stat')
    end
    assert(total == 35, id .. ': starting budget is ' .. total .. ', expected 35')
    assert(definition.str >= 8, id .. ': starting health allocation is too low')
    if id ~= env.HERO_BLOODZERKER then assert(definition.int >= 5, id .. ': missing resource allocation') end
end
assert(count == env.HERO_TOTAL and count == 19)
assert(env.HERO_STATS[env.HERO_BLOODZERKER].int == 0)
assert(env.HERO_STATS[env.HERO_ELEMENTALIST].int == 22)
local vampire = env.HERO_STATS[env.HERO_VAMPIRE]
assert(vampire.str == vampire.agi and vampire.int > 0, 'Vampire lost build symmetry or blood capacity')
print('PASS: all 19 heroes start with 35 nonnegative integer stats, a suitable primary stat and role/resource allocations.')
local expected = {'A013', 'A0GO', 'A019', 'A074', 'A00A', 'A00C'}
local skills = env.HERO_STATS[env.HERO_DARK_SAVIOR].skills
assert(#skills == #expected)
local runtime = read('content/abilities/heroes/dark_savior.lua')
for index, id in ipairs(expected) do
    assert(skills[index] == id, 'Incorrect Dark Savior hero-select slot ' .. index)
    assert(runtime:find('Spell.define("' .. id .. '")', 1, true), 'Unregistered displayed skill ' .. id)
end
print('PASS: Dark Savior selection shows both innates and all four current learned abilities.')
