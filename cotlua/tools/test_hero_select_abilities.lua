-- Offline check: hero-select catalog must match Dark Savior's runtime kit.
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
local expected = {'A013', 'A0GO', 'A019', 'A074', 'A00A', 'A00C'}
local skills = env.HERO_STATS[env.HERO_DARK_SAVIOR].skills
assert(#skills == #expected)
local runtime = read('content/abilities/heroes/dark_savior.lua')
for index, id in ipairs(expected) do
    assert(skills[index] == id, 'Incorrect Dark Savior hero-select slot ' .. index)
    assert(runtime:find('Spell.define("' .. id .. '")', 1, true), 'Unregistered displayed skill ' .. id)
end
print('PASS: Dark Savior selection shows both innates and all four current learned abilities.')
