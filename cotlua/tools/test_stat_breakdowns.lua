-- Isolated regression for the real stat getters, breakdowns, and refresh mapping.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local source = read("cotlua/src/ui/hud/stat_values.lua")
local function extract(first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    assert(load(source:sub(first, last - 1), "stat values", "t", sandbox))()
end
ITEM_CRIT_CHANCE, ITEM_CRIT_DAMAGE = "crit", "crit_damage"
ITEM_CRIT_CHANCE_MULT, ITEM_CRIT_DAMAGE_MULT = "crit_mult", "crit_damage_mult"
TOTAL_ATTACK_SPEED = "total_speed"
COOLDOWN_ACCELERATION, DROP_RATE = "cooldown_acceleration", "drop_rate"
ITEM_SPELLBOOST, ITEM_SPELL_AREA, ITEM_SPELL_DURATION = "spell_power", "spell_area", "spell_duration"
STAT_TAG = setmetatable({}, {__index = function(tags, key)
    local tag = {}
    rawset(tags, key, tag)
    return tag
end})
local format = string.format
sandbox.format = format
local hero = {agi = 50, attacks = true}
GetType = function() return "hero" end
HERO_STATS = {hero = {crit_chance = 5}}
Unit = {[hero] = {cc_flat = 5, cc_percent = 1.2, cc = 6, base_bat = 2, bonus_bat = 0.5, bat = 1}}
GetHeroAgi = function(u, bonuses) assert(bonuses); return u.agi end
UNIT_WEAPON_BF_ATTACKS_ENABLED = "enabled"
BlzGetUnitWeaponBooleanField = function(u, field, weapon)
    assert(field == "enabled" and weapon == 0)
    return u.attacks
end
extract("    STAT_TAG[ITEM_CRIT_CHANCE].getter", "    STAT_TAG[ITEM_BASE_ATTACK_SPEED].getter")
extract("    STAT_TAG[TOTAL_ATTACK_SPEED].getter", "    STAT_TAG[XP_RATE].getter")
extract("    STAT_TAG[COOLDOWN_ACCELERATION].getter", "    STAT_TAG[DROP_RATE].getter")
for _, value in ipairs({0., -0., -1e-12, 1e-12}) do
    Unit[hero].cooldown_acceleration = value
    assert(STAT_TAG[COOLDOWN_ACCELERATION].getter(hero) == "0.00")
end
Unit[hero].cooldown_acceleration = .07
assert(STAT_TAG[COOLDOWN_ACCELERATION].getter(hero) == "0.07")
local function contains(text, fragment) assert(text:find(fragment, 1, true), fragment .. " missing from " .. text) end
extract("    STAT_TAG[ITEM_SPELLBOOST].getter", "    STAT_TAG[ITEM_CRIT_CHANCE].getter")
Unit[hero].spellboost = .2
local spell_power = STAT_TAG[ITEM_SPELLBOOST]
assert(spell_power.getter(hero) == "20.000")
contains(spell_power.breakdown(hero), "|cff999999Increases supported spell damage, healing,")
contains(spell_power.breakdown(hero), "shield strength, and other spell bonuses.")
contains(spell_power.breakdown(hero), "Area and duration have no random variance.|r")
print("PASS: Spell Power breakdown explains its effects in gray text and distinguishes utility from random variance.")
local crit = STAT_TAG[ITEM_CRIT_CHANCE]
assert(crit.getter(hero) == "6.00")
contains(crit.breakdown(hero), "Base Chance:|r 5.00%")
contains(crit.breakdown(hero), "Spell/Item Flat Bonus:|r 0.00%")
contains(crit.breakdown(hero), "x1.20 (120.00%)")
contains(crit.breakdown(hero), "Total Critical Chance:|r 6.00%")
assert(not crit.breakdown(hero):find("|cff999999", 1, true), "Crit breakdown still has gray notes")
assert(STAT_TAG[ITEM_CRIT_CHANCE_MULT].getter(hero) == "120.00")
Unit[hero].cc_flat, Unit[hero].cc = 15, 18
contains(crit.breakdown(hero), "Base Chance:|r 5.00%")
contains(crit.breakdown(hero), "Spell/Item Flat Bonus:|r 10.00%")
contains(crit.breakdown(hero), "Total Critical Chance:|r 18.00%")
Unit[hero].cc_flat, Unit[hero].cc = 100, 120
contains(crit.breakdown(hero), "Effective Roll Chance:|r 100.00% (cap)")
local speed = STAT_TAG[TOTAL_ATTACK_SPEED]
assert(speed.getter(hero) == "1.50 attacks per second")
local tooltip = speed.breakdown(hero)
contains(tooltip, "Base Attack Time:|r 2.000 seconds")
contains(tooltip, "Attack Time Multiplier:|r x0.500")
contains(tooltip, "Effective Attack Time:|r 1.000 seconds")
contains(tooltip, "Agility Bonus:|r +50.00% (cap +400%)")
contains(tooltip, "Total Attack Speed:|r 1.50 attacks per second")
assert(not tooltip:find("|cff999999", 1, true), "Attack speed breakdown still has gray notes")
hero.agi = 1000
assert(speed.getter(hero) == "5.00 attacks per second")
contains(speed.breakdown(hero), "Agility Bonus:|r +400.00% (cap +400%)")
hero.attacks = false
assert(speed.getter(hero) == "0.00 attacks per second")
contains(speed.breakdown(hero), "Attacks are currently disabled.")
print("PASS: crit multiplier, effective crit cap, attack time formula, agility cap, and disabled attacks.")

source = read("cotlua/src/ui/hud/stat_view.lua")
local first = assert(source:find("    local STAT_LOOKUP = {", 1, true))
local last = assert(source:find("    local function owner_pid", first, true))
local mapping_source = source:sub(first, last - 1)
for name in mapping_source:gmatch("[A-Z][A-Z_]+") do
    if name ~= "STAT_LOOKUP" and not sandbox[name] then sandbox[name] = name end
end
local lookup = assert(load(mapping_source .. "\nreturn STAT_LOOKUP", "refresh mapping", "t", sandbox))()
assert(lookup.cc_flat == ITEM_CRIT_CHANCE and lookup.cc_percent == ITEM_CRIT_CHANCE)
for _, key in ipairs({"agi", "bonus_agi", "base_bat", "bonus_bat"}) do
    local found = false
    for _, index in ipairs(lookup[key]) do found = found or index == TOTAL_ATTACK_SPEED end
    assert(found, "Total attack speed is not refreshed by " .. key)
end
print("PASS: crit and total attack speed refresh when their component stats change.")

-- Question marks should follow the real text edge, not a scaled estimate.
FRAMEPOINT_TOPLEFT, FRAMEPOINT_LEFT, FRAMEPOINT_RIGHT = "top_left", "left", "right"
FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_TOPRIGHT = "bottom_left", "top_right"
TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT = "center", "left"
BlzCreateFrameByType = function(kind, _, parent) return {kind = kind, parent = parent} end
BlzFrameSetPoint = function(frame, point, relative, relative_point, x, y)
    frame.anchor = {point = point, relative = relative, relative_point = relative_point, x = x, y = y}
end
BlzFrameSetSize = function(frame, width, height) frame.width, frame.height = width, height end
BlzFrameSetScale = function() error("Question mark anchor offsets must not be scaled") end
BlzFrameSetAllPoints = function(frame, relative) frame.all_points = relative end
BlzFrameSetTextAlignment, BlzFrameSetTexture = function() end, function() end
BlzFrameSetEnable = function(frame, enabled) frame.enabled = enabled end
BlzFrameSetVisible = function(frame, visible) frame.visible = visible end
FrameAddSimpleTooltip = function() return {tooltip = {}, frame = {}} end
first = assert(source:find("    local function set_breakdown_visible", 1, true))
last = assert(source:find("    -- separate breakdowns per tab", first, true))
local make_slot, set_visible = assert(load(source:sub(first, last - 1) ..
    "\nreturn make_slot, set_breakdown_visible", "stat slot", "t", sandbox))()
sandbox.set_breakdown_visible = set_visible
local slot = make_slot({}, {}, -0.075)
assert(slot.icon.width == 0.0096 and slot.icon.height == 0.0096)
assert(slot.icon.anchor.point == "left" and slot.icon.anchor.relative == slot.val)
assert(slot.icon.anchor.relative_point == "right" and slot.icon.anchor.x == 0.004 and slot.icon.anchor.y == 0)
assert(slot.icon_frame.parent == slot.icon, "Tooltip hitbox is not a child of the icon")
assert(not slot.icon.visible and not slot.icon_frame.visible and not slot.icon_frame.enabled and not slot.tip.frame.visible,
    "Unused row retained an active tooltip")
print("PASS: question marks retain their size and anchor directly beside the vertically centered value text.")

-- Execute the real row render and tab-clear paths, including empty breakdowns.
tab_tags, MAX_ROWS, tab_ui = {1, 2, 3}, 1, {}
for page = 1, #tab_tags do
    tab_ui[page] = {entries = {{getter = function() return "5" end}}, rows = {make_slot({}, {}, -0.075)}}
end
set_if_changed = function(row, field, frame, text) row[field] = text; frame.text = text end
set_tip_if_changed = function(row, text) row.last_tip = text; row.tip.tooltip.text = text end
first = assert(source:find("    -- Shared row rendering", 1, true))
last = assert(source:find("    -- Full refresh:", first, true))
local render, clear = assert(load(source:sub(first, last - 1) ..
    "\nreturn render_stat_row, clear_all_rows", "tooltip visibility", "t", sandbox))()
for page = 1, #tab_tags do
    local row = tab_ui[page].rows[1]
    render(hero, page, 1, 1)
    assert(not row.icon_frame.visible and not row.icon_frame.enabled)
    tab_ui[page].entries[1].breakdown = function() return "" end
    render(hero, page, 1, 1)
    assert(not row.icon_frame.visible and not row.icon_frame.enabled, "Empty breakdown enabled its hitbox")
    tab_ui[page].entries[1].breakdown = function() return "Actual breakdown" end
    render(hero, page, 1, 1)
    assert(row.icon.visible and row.icon_frame.visible and row.icon_frame.enabled and row.has_breakdown)
    assert(row.last_tip == "Actual breakdown")
    row.tip.frame.visible = true -- model a tooltip currently being hovered
end
clear()
for page = 1, #tab_tags do
    local row = tab_ui[page].rows[1]
    assert(not row.icon.visible and not row.icon_frame.visible and not row.icon_frame.enabled)
    assert(not row.tip.frame.visible and not row.has_breakdown and row.last_tip == nil,
        "Changing tabs retained a tooltip")
end
tab_ui[1].entries[1].breakdown = nil
render(hero, 1, 1, 1)
assert(not tab_ui[1].rows[1].icon_frame.enabled)
print("PASS: missing/empty breakdowns have no hitbox; populated breakdowns enable it; tab clearing hides active tooltips.")

-- Exercise the actual pagination helper: repeated metadata, bounded rows,
-- complete bonus coverage, and clamped first/last page navigation.
local perk_source_file = assert(io.open('cotlua/src/ui/hud/stat_view.lua', 'rb'))
local perk_source = perk_source_file:read('*a'); perk_source_file:close()
first = assert(perk_source:find('    local PERK_HEADER_ROWS', 1, true))
last = assert(perk_source:find('    local HONOR_TAB', first, true))
local paginate = assert(load(perk_source:sub(first, last - 1) .. '\nreturn perk_page_indices', 'perk pages', 't', sandbox))()
for total = 4, 100 do
    local _, _, pages = paginate(total, 1)
    local seen = {}
    for page = 1, pages do
        local indices, clamped = paginate(total, page)
        assert(clamped == page and #indices <= 22)
        for index = 1, 4 do assert(indices[index] == index) end
        for row = 5, #indices do
            local index = indices[row]
            assert(not seen[index]); seen[index] = true
        end
    end
    for index = 5, total do assert(seen[index], 'Perk bonus omitted by pagination') end
    local _, clamped = paginate(total, -100); assert(clamped == 1)
    _, clamped = paginate(total, 100); assert(clamped == pages)
end
print('PASS: perk summary pages repeat point/reset metadata and display every bonus within 22 rows.')
