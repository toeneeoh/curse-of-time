-- Offline source-level regression only; Warcraft integration is tested in game.
-- io/load are used by this host test, never by the shipped map.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local function read(file)
    local handle = assert(io.open('cotlua/src/' .. file, 'rb'))
    local text = handle:read('*a'):gsub('\r\n', '\n')
    handle:close()
    return text
end
local function extract(file, first, last, tail)
    local text = read(file)
    local a = assert(text:find(first, 1, true), first)
    local b = assert(text:find(last, a, true), last)
    return assert(load(text:sub(a, b - 1) .. (tail or ''), file, 't', sandbox))()
end
local function require_stub() end
OnInit = {global = function(_, callback) callback(require_stub) end}
enum = function(...)
    local names = {...}
    for index, name in ipairs(names) do sandbox[name] = index end
    return #names
end
__jarray = function(default) return setmetatable({}, {__index = function() return default end}) end
array2d = function(default)
    return setmetatable({}, {__index = function(t, key)
        local value = __jarray(default); rawset(t, key, value); return value
    end})
end
FourCC = function(id) return string.unpack('>I4', id) end
assert(load(read('config/item_schema.lua'), 'schema', 't', sandbox))()
assert(load(read('config/stat_schema.lua'), 'stats', 't', sandbox))()
assert(ITEM_SPELL_POWER == ITEM_SPELLBOOST)
assert(STAT_TAG[ITEM_SPELL_POWER].syntax == 'spellpower')
extract('gameplay/items/helpers.lua', '    function ParseItemDefinition', '    ---@type fun(itm: item')
local set = ParseItemDefinition('Set', '', '[tier 8] [spellboost*20]')
local chaos_set = ParseItemDefinition('Set', '', '[tier 22] [spellboost*20]')
for _, data in ipairs({set, chaos_set}) do
    assert(data[ITEM_SPELL_POWER] == 20)
    assert(data[ITEM_SPELL_AREA] == 0 and data[ITEM_SPELL_DURATION] == 0)
    assert(not rawget(data, 'legacy_spell_utility'))
end
local niche = ParseItemDefinition('Niche', '', '[tier 9] [spellboost*5|15=2@2]')
assert(niche[ITEM_SPELL_AREA] == 2.5)
assert(niche[ITEM_SPELL_DURATION .. 'range'] == 7.5)
assert(niche[ITEM_SPELL_AREA .. 'unlock'] == 2)
local explicit = ParseItemDefinition('New', '', '[spellpower*20] [spellarea*7.5] [spellduration*12.5]')
assert(not rawget(explicit, 'legacy_spell_utility'))
local overridden = ParseItemDefinition('Override', '', '[spellboost*20] [spellarea*3]')
assert(not overridden.legacy_spell_utility[ITEM_SPELL_AREA])
assert(overridden.legacy_spell_utility[ITEM_SPELL_DURATION])

Item = {}; ItemRuntime = {definitions = {}}
floor = math.floor
item_data = function(item) return item.data end
ITEM_STAT_MULTIPLIER = __jarray(0)
extract('gameplay/items/item.lua', '        function Item:calculateValue', '        local function remove_item_ability')
local item = setmetatable({data = niche, level = 1, rarity = 4, quality = {31}}, {__index = Item})
niche.quality_index = {[ITEM_SPELL_POWER] = 1}
assert(item:calculateValue(ITEM_SPELL_AREA, 0) == 0)
item.level = 2
assert(item:calculateValue(ITEM_SPELL_POWER, 0) == 14)
assert(item:calculateValue(ITEM_SPELL_AREA, 0) == 7)
assert(item:calculateValue(ITEM_SPELL_DURATION, 1) == 4.5)
assert(item:calculateValue(ITEM_SPELL_DURATION, 2) == 9.5)
item.data = explicit
assert(item:calculateValue(ITEM_SPELL_AREA, 0) == 7.5)
assert(item:calculateValue(ITEM_SPELL_DURATION, 0) == 12.5)

local unit = {}
Unit = {[unit] = {spellboost = .2, spell_area = .3, spell_duration = .4}}
extract('gameplay/abilities/spells.lua', '    local area_tags', '    -- set by getTooltip')
local spell = {id = FourCC('A098')}
assert(SpellTooltipMultiplier(spell, unit, 'aoe') == 1.3)
assert(SpellTooltipMultiplier(spell, unit, 'dur') == 1.4)
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1.4)
assert(SpellTooltipMultiplier(spell, unit, 'pshield') == 1.1)
spell.id = FourCC('A0os')
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1.1)
spell.tooltip_scaling = {times = 'none'}
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1)

local refresh = read('gameplay/players/hero_refresh.lua')
assert(refresh:find('BOOST[pid] = 1. + unit.spellboost + SpellboostVariance()', 1, true))
assert(refresh:find('ABOOST[pid] = math.max(0., 1. + unit.spell_area)', 1, true))
assert(refresh:find('DBOOST[pid] = math.max(0., 1. + unit.spell_duration)', 1, true))
print('PASS: random cast variance is retained on Spell Power, not area or duration.')

local paginate = extract('ui/hud/stat_view.lua', '    local STATS_PER_PAGE', '    local PROFILE_TAB', '\nreturn stat_page_indices')
local order = {[1] = {}, [2] = {}, [3] = {}}
for i = 1, 22 do order[1][#order[1] + 1] = i end
for i = 23, 35 do order[2][#order[2] + 1] = i end
local first, page, pages = paginate(order, 2, 1)
assert(#first == 28 and page == 1 and pages == 2)
local second = paginate(order, 2, 2)
assert(#second == 7 and second[1] == 29 and second[7] == 35)
local _, clamped = paginate(order, 2, 99)
assert(clamped == 2)
print('PASS: power-only sets, legacy utility shared rolls, fractional utility, independent tooltip scaling, and stat pagination.')

-- Ensure no geometry/duration consumer accidentally still uses half power.
local paths = {'heroes/warrior.lua', 'heroes/arcanist.lua', 'heroes/master_rogue.lua',
    'heroes/dark_summoner.lua', 'heroes/elite_marksman.lua', 'units/summon_abilities.lua'}
for _, path in ipairs(paths) do
    local text = read('content/abilities/' .. path)
    assert(not text:match('%.dur%s*%*%s*LBOOST%['), path)
    assert(not text:match('%.aoe%s*%*%s*LBOOST%['), path)
end
print('PASS: representative spell/summon execution paths use independent area and duration multipliers.')
