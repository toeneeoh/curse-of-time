-- Execute the real learn handler, mana-cost callbacks, and event registry.
-- Native skill levels/mana fields are mocked; no cast/stat change is needed
-- between learning a skill and checking its initial cost.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close(); return source
end
OnInit = {final = function(_, callback) callback(function() end) end}
Debug = {try = function(callback, ...) return callback(...) end, getLine = function() return 0 end}
TableHas = function(values, target)
    for _, value in ipairs(values) do if value == target then return true end end
    return false
end
TableRemove = function(values, target)
    for index, value in ipairs(values) do if value == target then table.remove(values, index); return end end
end
assert(load(read('framework/events/events.lua'), 'real events', 't', env))()
local current_unit, learned_id, tooltip_updates
Spells = {}
GetTriggerUnit, GetLearnedSkill = function() return current_unit end, function() return learned_id end
GetOwningPlayer, GetPlayerId = function(u) return u.owner end, function(player) return player end
GetUnitAbilityLevel = function(u, id) return u.abilities[id] and u.abilities[id].level or 0 end
BlzGetUnitAbilityByIndex = function(u, index) return u.abilities[u.order[index + 1]] end
BlzGetAbilityId = function(ability) return ability.id end
BlzGetUnitMaxMana, R2I = function(u) return u.max_mana end, math.floor
BlzSetUnitAbilityManaCost = function(u, id, index, value)
    local ability = assert(u.abilities[id], 'Wrote a cost to an absent ability')
    assert(index == ability.level - 1, 'Wrote the cost to the wrong rank')
    ability.cost, ability.writes = value, (ability.writes or 0) + 1
end
UpdateSpellTooltips = function(u)
    tooltip_updates = (tooltip_updates or 0) + 1
    u.tooltip_cost = u.abilities[learned_id].cost
end
local spells = read('gameplay/abilities/spells.lua')
local a = assert(spells:find('    local function SpellLearn()', 1, true))
local b = assert(spells:find('    local function SpellEffect()', a, true))
local learn = assert(load(spells:sub(a, b - 1) .. '\nreturn SpellLearn', 'real spell learn', 't', env))()
local function mana_spell(file, name)
    local source = read('content/abilities/heroes/' .. file .. '.lua')
    local first = assert(source:find('    ---@class ' .. name .. ' : Spell', 1, true))
    local finish = source:find('\n    ---@class ', first + 1, true) or #source
    local block = source:sub(first, finish - 1)
    local id = assert(block:match('Spell%.define%("(%w+)"'))
    local start = assert(block:find('        local manacost = function', 1, true))
    local stop = assert(block:find('\n        end\n', start, true)) + #'\n        end\n'
    local callback = block:sub(start, stop - 1)
    local hook_start = assert(block:find('        function thistype.onLearn(', stop, true))
    local hook_stop = assert(block:find('\n        end\n', hook_start, true)) + #'\n        end\n'
    local result = assert(load('local thistype = {id = "' .. id .. '"}\n' .. callback ..
        block:sub(hook_start, hook_stop - 1) .. '\nreturn thistype', name, 't', env))()
    Spells[id] = result
    return id
end
-- Inspire registers another listener too; its behavior is outside this test.
on_order = function() end
local cases = {
    {'elementalist', 'BALLOFLIGHTNING', .05},
    {'elementalist', 'FROZENORB', .15},
    {'elementalist', 'FLAMEBREATH', .03},
    {'elementalist', 'ELEMENTALSTORM', .25},
    {'assassin', 'SHADOWSHURIKEN', .05},
    {'bard', 'INSPIRE', .02},
    {'dark_savior', 'DARKSEAL', .20},
    {'high_priestess', 'DIVINELIGHT', .05},
}
for _, case in ipairs(cases) do case.id = mana_spell(case[1], case[2]) end
local function unit(owner, maximum)
    return {owner = owner, max_mana = maximum, mana = 777, abilities = {}, order = {}}
end
local function learn_skill(u, id, level)
    if not u.abilities[id] then u.order[#u.order + 1] = id end
    u.abilities[id] = {id = id, level = level, cost = -999}
    current_unit, learned_id, tooltip_updates = u, id, 0
    assert(learn() == false)
end
local hero, other = unit(0, 1001), unit(1, 9000)
for _, case in ipairs(cases) do
    learn_skill(hero, case.id, 1)
    local expected = math.floor(1001 * case[3])
    assert(hero.abilities[case.id].cost == expected, case[2] .. ': cost not initialized when learned')
    assert(hero.tooltip_cost == expected, case[2] .. ': tooltip refreshed before the cost was initialized')
end
learn_skill(other, cases[1].id, 1)
assert(other.abilities[cases[1].id].cost == 450)
local registered = #EVENT_STAT_CHANGE.unit_actions[hero]
hero.max_mana = 2479
for _, case in ipairs(cases) do
    learn_skill(hero, case.id, 3)
    assert(hero.abilities[case.id].cost == math.floor(2479 * case[3]), case[2] .. ': wrong upgraded cost')
    assert(#EVENT_STAT_CHANGE.unit_actions[hero] == registered, 'Upgrade duplicated a stat listener')
end
hero.max_mana = 4097
EVENT_STAT_CHANGE:trigger(hero, 'bonus_mana')
for _, case in ipairs(cases) do
    assert(hero.abilities[case.id].cost == math.floor(4097 * case[3]), case[2] .. ': later stat changes stopped updating cost')
end
assert(other.abilities[cases[1].id].cost == 450 and hero.mana == 777 and other.mana == 777)
-- A learn hook can change maximum mana itself. Its listeners and the final
-- tooltip refresh must observe that new maximum, after the hook completes.
Spells.synthetic = {onLearn = function(u)
    u.max_mana = 2003
    EVENT_STAT_CHANGE:register_unit_action(u, function(target, key)
        if key == 'int' then BlzSetUnitAbilityManaCost(target, 'synthetic', 0, math.floor(target.max_mana * .1)) end
    end)
end}
learn_skill(hero, 'synthetic', 1)
assert(hero.abilities.synthetic.cost == 200 and hero.tooltip_cost == 200)
assert(tooltip_updates >= 1 and hero.mana == 777)
print('PASS: immediate Ball Lightning/Frozen Orb and six other spell costs, upgrade ranks/rounding, post-hook tooltip order, deduplicated listeners, later max-mana changes, and per-unit isolation without consuming mana.')
