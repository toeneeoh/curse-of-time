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

-- Execute the actual tooltip body, not just the value formatter.
local item_source = read('gameplay/items/item.lua')
local formatting_start = assert(item_source:find('        local function format_item_stat_value', 1, true))
local formatting_end = assert(item_source:find('        ---Rebuilds calculated stats', formatting_start, true))
local body_start = assert(item_source:find('            local cs = self.cached_stats', formatting_end, true))
local body_end = assert(item_source:find('            -- Runtime logical items can add', body_start, true))
concat = table.concat
DISPLAY_STATS = {ITEM_SPELL_AREA, ITEM_SPELL_DURATION}
local tooltip_body = assert(load(item_source:sub(formatting_start, formatting_end - 1) ..
    '\nreturn function(self, data)\nlocal text, alt_text = {}, {}\n' ..
    item_source:sub(body_start, body_end - 1) ..
    '\nreturn concat(text), concat(alt_text)\nend', 'real item tooltip body', 't', sandbox))()
local tooltip_item = {cached_stats = __jarray(0), cached_base = __jarray(0),
    cached_lower = __jarray(0), cached_upper = __jarray(0)}
tooltip_item.cached_stats[ITEM_SPELL_AREA] = 7.75
tooltip_item.cached_base[ITEM_SPELL_AREA] = 7.5
tooltip_item.cached_lower[ITEM_SPELL_AREA] = 2.5
tooltip_item.cached_upper[ITEM_SPELL_AREA] = 9.5
tooltip_item.cached_stats[ITEM_SPELL_DURATION] = -12.125
tooltip_item.cached_base[ITEM_SPELL_DURATION] = -12.125
local normal, alternate = tooltip_body(tooltip_item, explicit)
assert(normal:find('7.5%', 1, true) and normal:find('0.25%', 1, true))
assert(normal:find('12.125%', 1, true))
assert(alternate:find('7.75%', 1, true) and alternate:find('0.25%', 1, true))
explicit[ITEM_SPELL_AREA .. 'range'] = 7
normal, alternate = tooltip_body(tooltip_item, explicit)
assert(alternate:find('2.5-9.5%', 1, true))
tooltip_item.cached_stats[ITEM_SPELL_AREA], tooltip_item.cached_base[ITEM_SPELL_AREA] = 8, 8
normal = tooltip_body(tooltip_item, explicit)
assert(normal:find('8%', 1, true) and not normal:find('8.000', 1, true))
print('PASS: real normal/Alt item tooltip bodies preserve fractional utility, socket bonuses, negative values, and ranges.')

local unit = {}
Unit = {[unit] = {spellboost = .2, spell_area = .3, spell_duration = .4}}
extract('gameplay/abilities/spells.lua', '    local pattern', '    -- set by getTooltip')
local spell = {id = FourCC('A098')}
assert(SpellTooltipMultiplier(spell, unit, 'aoe') == 1.3)
assert(SpellTooltipMultiplier(spell, unit, 'dur') == 1.4)
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1.4)
assert(SpellTooltipMultiplier(spell, unit, 'pshield') == 1.1)
spell.id = FourCC('A0os')
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1.1)
spell.tooltip_scaling = {times = 'none'}
assert(SpellTooltipMultiplier(spell, unit, 'times') == 1)

local tagged = {id = FourCC('A098'), values = {dmg = 10, aoe = 300, dur = 4, pshield = 20}}
local original = 'Damage [dmg=10], area {aoe=300], shield {pshield=20].\n|c000080c0>{dur=4] second duration.\n10 second cooldown.|r'
local rendered = 'Damage 12, area 390, shield 22.\n|c000080c05.6 second duration.\n10 second cooldown.|r'
local annotated = SpellScalingTooltip(tagged, original, rendered)
assert(annotated:find('Spell Power, Spell Duration, Spell Area', 1, true))
assert(not annotated:find('50%', 1, true))
assert(annotated:find('Improved by:', 1, true) < annotated:find('second duration', 1, true))
assert(annotated:find('|c000080c05.6 second duration.\n10 second cooldown.|r', 1, true))
assert(annotated:find('shield 22.\n|cff40e0d0* Improved by:', 1, true))
assert(annotated:find('Spell Area.|r\n|c000080c0', 1, true))
assert(not annotated:find('\n\n', 1, true))
local crlf = SpellScalingTooltip(tagged, original, rendered:gsub('\n', '\r\n'))
assert(crlf:find('shield 22.\n|cff40e0d0* ', 1, true))
assert(crlf:find('Spell Area.|r\n|c000080c0', 1, true))
tagged.values = {pshield = 20}
assert(SpellScalingTooltip(tagged, original, rendered):find('Improved by: Spell Power.', 1, true))
tagged.tooltip_scaling = {pshield = 'none'}
assert(SpellScalingTooltip(tagged, original, rendered) == rendered)
tagged.scaling_note = 'Improved by: Spell Area (inherited aura radius).'
assert(SpellScalingTooltip(tagged, '', 'Passive aura.'):find(tagged.scaling_note, 1, true))
tagged.scaling_note = ''
assert(SpellScalingTooltip(tagged, original, rendered) == rendered)
assert(SpellScalingTooltip({id = 0, values = {cost = 20}}, '\\cost=20] mana.', '20 mana.') == '20 mana.')
assert(SpellScalingTooltip({id = 0, values = {dmg = 10}}, '[dmg=10]', '10 damage.') ==
    '10 damage.\n|cff40e0d0* Improved by: Spell Power.|r')
print('PASS: scaling notes list applicable stats without vague effectiveness text and preserve blue footers.')

-- Execute the real getTooltip/replacer with normal and Alt contexts.
local spell_source = read('gameplay/abilities/spells.lua')
local helper_start = assert(spell_source:find('    local pattern', 1, true))
local helper_end = assert(spell_source:find('    SONG_WAR', helper_start, true))
local replacer_start = assert(spell_source:find('        local function tooltip_replacer', 1, true))
local replacer_end = assert(spell_source:find('        ---@type fun(self: Spell, u: unit, sid: integer?)', replacer_start, true))
TEST_ALT = {}
TEST_TOOLTIPS = {[123] = {'|cffffcc00Damage [dmg=10]|r, chance {chance=20]%, area {aoe=300], fixed \\cost=20].\n|cff0080c0>{dur=4] second duration.\n10 second cooldown.|r'}}
MIN_SPELLBOOST_VARIANCE, MAX_SPELLBOOST_VARIANCE = 0, 0
HL = function(text, color) return color and ('|cffffcc00' .. text .. '|r') or text end
local real_get_tooltip = assert(load('local real_to_string = function(value) return string.format("%.0f", value) end\n' ..
    'local HL, format = HL, string.format\n' .. spell_source:sub(helper_start, helper_end - 1) ..
    '\nlocal thistype = {TOOLTIPS = TEST_TOOLTIPS}\nlocal alt_down = TEST_ALT\n' ..
    spell_source:sub(replacer_start, replacer_end - 1) .. '\nreturn thistype.getTooltip',
    'real spell tooltip', 't', sandbox))()
local actual_spell = {id = 123, pid = 1, ablev = 1, dmg = 10, chance = 20, aoe = 300, dur = 4, cost = 20,
    values = {dmg = 10, chance = 20, aoe = 300, dur = 4, cost = 20}}
local normal_spell = real_get_tooltip(actual_spell, unit)
assert(normal_spell:find('Damage 10|r|cff40e0d0*|r', 1, true))
assert(normal_spell:find('chance 20%|cff40e0d0*|r', 1, true))
assert(normal_spell:find('4|cff40e0d0*|cff0080c0 second duration', 1, true))
assert(not normal_spell:find('(50%)', 1, true))
assert(normal_spell:find('fixed 20.', 1, true))
TEST_ALT[1] = true
local alt_spell = real_get_tooltip(actual_spell, unit)
assert(alt_spell:find('22.00|r%|cff40e0d0 (50% scaling)|r', 1, true))
assert(alt_spell:find('390.00|r', 1, true))
assert(alt_spell:find('5.60 second duration', 1, true))
local _, half_count = alt_spell:gsub('%(50%% scaling%)', '')
assert(half_count == 1)
local _, alt_stars = alt_spell:gsub('%*', '')
assert(alt_stars == 1, 'Only the explanatory line keeps its star in Alt mode')
assert(not alt_spell:find('[\1\2]'))
assert(not alt_spell:find('10 second cooldown.|cff40e0d0', 1, true))
actual_spell.tooltip_scaling = {chance = 'none'}
assert(not real_get_tooltip(actual_spell, unit):find('(50% scaling)', 1, true))
actual_spell.tooltip_scaling = nil
TEST_TOOLTIPS[123][1] = '|cffffcc00{chance=20]%|r chance on attack.'
local chance_tooltip = real_get_tooltip(actual_spell, unit)
assert(chance_tooltip:find('22.00|r%|r|cff40e0d0 (50% scaling)|r chance on attack.', 1, true))
-- Exact native Bladestorm/Gaia color prefixes: their last hex digit must not
-- become part of the duration number or disappear during the rewrite.
local native_duration = 'Body.\n|c000080c03 second duration.|r\n|c000080c010 second cooldown.|r'
local tagged_duration = TagSpellDurationTooltip(native_duration)
assert(tagged_duration == 'Body.\n|c000080c0>{dur=3] second duration.|r\n|c000080c010 second cooldown.|r')
assert(TagSpellDurationTooltip(tagged_duration) == tagged_duration)
assert(TagSpellDurationTooltip('|c000080c030 second duration.|r\n120 second cooldown.') ==
    '|c000080c0>{dur=30] second duration.|r\n120 second cooldown.')
TEST_TOOLTIPS[123][1] = native_duration
actual_spell.tooltip_rewrite = TagSpellDurationTooltip
actual_spell.dur = 3
TEST_ALT[1] = false
local fixed_normal = real_get_tooltip(actual_spell, unit)
TEST_ALT[1] = true
local fixed_alt = real_get_tooltip(actual_spell, unit)
assert(fixed_normal:find('|c000080c03|cff40e0d0*|c000080c0 second duration.', 1, true))
assert(fixed_alt:find('|c000080c04.20 second duration.', 1, true))
for _, text in ipairs({fixed_normal, fixed_alt}) do
    assert(text:find('* Improved by:', 1, true) < text:find('second duration', 1, true))
    assert(text:find('|c000080c010 second cooldown.|r', 1, true))
end
print('PASS: native duration color codes stay intact; normal/Alt scaling notes stay above duration; calculated duration is correct.')
print('PASS: real normal/Alt tooltips mark scalable values, show half Power only on Alt, leave fixed values alone, and restore surrounding colors.')

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

local real_order = {}
for index = 1, BOSS_DROP_RATE do
    local priority = STAT_TAG[index].priority
    real_order[priority] = real_order[priority] or {}
    table.insert(real_order[priority], index)
end
local combat, _, hero_pages = paginate(real_order, 3, 1)
local rewards = paginate(real_order, 3, 2)
assert(hero_pages == 2)
local seen = {}
for position, index in ipairs(combat) do
    seen[index] = true
    assert(index ~= XP_RATE and index ~= DROP_RATE and index ~= BOSS_DROP_RATE)
    if index == ITEM_SPELLBOOST then
        assert(combat[position + 1] == ITEM_SPELL_AREA)
        assert(combat[position + 2] == ITEM_SPELL_DURATION)
    end
end
assert(seen[ITEM_SPELLBOOST] and seen[ITEM_SPELL_AREA] and seen[ITEM_SPELL_DURATION])
for _, index in ipairs(rewards) do
    assert(not seen[index], 'Stat is repeated across pages')
    seen[index] = true
end
assert(seen[XP_RATE] and seen[DROP_RATE] and seen[BOSS_DROP_RATE])
for priority = 1, 3 do
    for _, index in ipairs(real_order[priority] or {}) do assert(seen[index], 'Stat missing from pages') end
end
local _, _, small_pages = paginate({[1] = {ITEM_SPELLBOOST}, [2] = {ITEM_SPELL_AREA, ITEM_SPELL_DURATION},
    [3] = {XP_RATE, DROP_RATE, BOSS_DROP_RATE}}, 3, 1)
assert(small_pages == 2, 'Reward stats filled empty space on page one')
local nonhero = paginate(real_order, 2, 1)
for _, index in ipairs(nonhero) do
    assert(index ~= XP_RATE and index ~= DROP_RATE and index ~= BOSS_DROP_RATE)
end
print('PASS: spell utility follows power; experience and drop rates stay on page two without missing or duplicated stats.')
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
