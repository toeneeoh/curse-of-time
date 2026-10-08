-- Mocked presentation regression; run from the repository root with Lua.
-- Does not simulate Warcraft's tooltip layout or native aura effects.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load, native_loadfile = load, loadfile
local function load(chunk, name, mode) return native_load(chunk, name, mode or "t", sandbox) end
local function loadfile(path) return native_loadfile(path, "t", sandbox) end

local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end

function FourCC(value)
    local result = 0
    for index = 1, 4 do result = result * 256 + value:byte(index) end
    return result
end
OnInit = {final = function(_, callback) callback(function() end) end}
Spells = {}
Spell = {define = function(...)
    local spell = {}
    for _, id in ipairs({...}) do Spells[FourCC(id)] = spell end
    return spell
end}
ItemRuntime = {define = function() end, syncAbilitySlots = function() end}
ItemUse = {register = function() end, registerRuntime = function() end}
RuntimeItemDefinitions = {define = function(_, specification) return specification end}
BlzSetAbilityExtendedTooltip = function() end
BOSS_LEGION = 1
BOSS_DEATH_KNIGHT = 2

for _, module in ipairs({"equipment_procs", "equipment_mobility",
    "item_active_abilities", "item_aura_abilities", "socketing"}) do
    assert(loadfile("cotlua/src/content/abilities/items/" .. module .. ".lua"))()
end
assert(loadfile("cotlua/src/gameplay/items/faction_consumables.lua"))()

-- Execute the actual in-game regression without the other game initializers.
ArchitectureTests = {register = function(name, callback)
    local ok, reason = callback()
    assert(ok, name .. ": " .. tostring(reason))
end}
local tests = read("cotlua/src/devtools/architecture_tests.lua")
local first = assert(tests:find('    ArchitectureTests.register("item abilities have active or passive classification",', 1, true))
local last = assert(tests:find('    ArchitectureTests.register("unit and item abilities are registered",', first, true))
assert(load(tests:sub(first, last - 1)))()

-- Exercise the real dummy assignment path, replacing only its native/game
-- dependencies and onEquip callbacks (gameplay is outside this mock's scope).
local source = read("cotlua/src/gameplay/items/item.lua")
first = assert(source:find("        add_item_abilities = function(itm, suppress_sync)", 1, true))
last = assert(source:find("        function thistype:lvl(lvl)", first, true))
local add_item_abilities = assert(load(source:sub(first, last - 1) .. "\nreturn add_item_abilities"))()
ITEM_ABILITY = 1
ITEM_ABILITY2 = 2
ITEM_BF_ACTIVELY_USED, ITEM_BF_CAN_BE_DROPPED, ITEM_BF_DROPPED_WHEN_CARRIER_DIES = 1, 2, 3
BACKPACK = 99
Hero = {[1] = {}}
backpack_allowed = {}
item_data = function(item) return item.data end
ItemProfMod = function() return 1 end
GetUnitTypeId = function() return 0 end
ParseItemAbilityTooltip = function() return "Ability description" end
retained_cooldown = function() return 0 end
LockDummyCastItem = function() end
MakeDummyCastItem = function() return {} end
BlzSetItemBooleanField = function(item, field, value)
    item.fields = item.fields or {}
    item.fields[field] = value
    if field == ITEM_BF_ACTIVELY_USED then item.active = value end
    return true
end
BlzItemAddAbility = function(item, id) item.attached = id return true end
BlzSetItemIconPath = function() end
BlzGetAbilityIcon = function() return "icon" end
BlzSetItemExtendedTooltip = function() end
BlzSetItemName = function() end
GetObjectName = function() return "Ability" end

local count = 0
for id, spell in pairs(Spells) do
    assert(type(spell.ACTIVE) == "boolean", "Implicit activation classification")
    spell.onEquip = function() end
    local item = {id = 0, pid = 1, holder = Hero[1], level = 0,
        data = {["1id"] = id, ["1unlock"] = 0, ["2id"] = 0},
        cached_stats = {[1] = 1}}
    add_item_abilities(item)
    local dummy = assert(item.abilities[1].obj)
    assert(dummy.active == spell.ACTIVE, "Wrong instance activation flag")
    assert((dummy.attached == id) == (spell.ACTIVE or spell.ITEM_NATIVE_ABILITY == true),
        "Wrong native ability attachment")
    count = count + 1
end
assert(count == 41, "Unexpected registered item ability count: " .. count)
print("PASS: 41 item ability classifications and their dummy flags/native attachment.")

-- Test allocation independently of physical slots, then exercise the actual
-- slot-sync function with sparse equipment, a swap, and a rejected move.
local helpers = read("cotlua/src/gameplay/items/helpers.lua")
local ids_first = assert(helpers:find("    local dummy_items = {", 1, true))
local ids_last = assert(helpers:find("\n    }", ids_first, true)) + #"\n    }"
first = assert(helpers:find("    function MakeDummyCastItem(u)", 1, true))
last = assert(helpers:find("    ---@param pid integer", first, true))
MakeDummyCastItem = assert(load(helpers:sub(ids_first, ids_last) .. "\n" ..
    helpers:sub(first, last - 1) .. "\nreturn MakeDummyCastItem"))()
first = assert(source:find("        local add_item_abilities\n", 1, true))
last = assert(source:find("        RegisterItemChangedAction(ItemRuntime.syncAbilitySlots)", first, true))
local slot_source = source:sub(first, last - 1)
local add_first = assert(source:find("        add_item_abilities = function(itm, suppress_sync)", 1, true))
local add_last = assert(source:find("        function thistype:lvl(lvl)", add_first, true))
local remove_first = assert(source:find("        local function remove_item_ability", 1, true))
local remove_last = assert(source:find("        ---Boss-pool membership", remove_first, true))
local commit_first = assert(source:find("        function ItemRuntime.commit_slot", 1, true))
local commit_last = assert(source:find("        -- Main equip function", commit_first, true))
local guard_first = assert(source:find("        local pending_native_restore", 1, true))
local guard_last = assert(source:find("        -- Called on equip", guard_first, true))
local attach, detach = assert(load(slot_source .. source:sub(add_first, add_last - 1) ..
    source:sub(remove_first, remove_last - 1) ..
    source:sub(commit_first, commit_last - 1) ..
    source:sub(guard_first, guard_last - 1) ..
    "\nreturn add_item_abilities, refresh_item_abilities"))()

local hero = {inventory = {}}
Hero[1] = hero
Backpack = {[1] = {inventory = {}}}
GetUnitTypeId = function(unit) return unit == Backpack[1] and BACKPACK or 0 end
MAX_INVENTORY_SLOTS = 24
PLAYER_CAP = 1
Profile = {[1] = {hero = {items = {}}}}
UnitItemInSlot = function(unit, slot) return unit.inventory[slot] end
GetItemTypeId = function(item) return item.id end
CreateItem = function(id) return {id = id} end
SetItemDroppable = function(item, flag) item.droppable = flag end
SetItemPawnable = function(item, flag) item.pawnable = flag end
SetItemDropOnDeath = function(item, flag) item.drop_on_death = flag end
RemoveItem = function(item)
    item.removed = true
    for _, unit in ipairs({hero, Backpack[1]}) do
        for slot = 0, 5 do
            if unit.inventory[slot] == item then
                unit.inventory[slot] = nil
                if unit.cooldowns and item.attached then unit.cooldowns[item.attached] = nil end
            end
        end
    end
end
set_widget_life = function() end
BlzSetItemIconPath = function(item, path) item.icon = path end
BlzSetItemName = function(item, name) item.name = name end
BlzSetItemTooltip = function(item, text) item.short_tooltip = text end
BlzSetItemDescription = function(item, text) item.description = text end
BlzSetItemExtendedTooltip = function(item, text) item.tooltip = text end
SetItemCharges = function(item, value) item.charges = value end
BlzGetUnitAbilityCooldownRemaining = function(unit, id)
    return unit.cooldowns and unit.cooldowns[id] or 0
end
BlzStartUnitAbilityCooldown = function(unit, id, remaining)
    unit.cooldowns = unit.cooldowns or {}
    unit.cooldowns[id] = remaining
end
local now, queued = 0, {}
TQ = {
    callDelayed = function(_, duration, callback, ...)
        local id = #queued + 1
        queued[id] = {expires = now + duration, callback = callback, args = {...}}
        return id
    end,
    getRemaining = function(_, id)
        return math.max(0, queued[id].expires - now)
    end
}
UnitAddItem = function(unit, item)
    for slot = 0, 5 do
        if not unit.inventory[slot] then unit.inventory[slot] = item return true end
    end
    return false
end
local fail_move = false
UnitDropItemSlot = function(unit, item, target)
    assert(item.droppable, "Internal relocation must be explicitly unlocked")
    if fail_move then return false end
    for slot = 0, 5 do
        if unit.inventory[slot] == item then
            unit.inventory[slot], unit.inventory[target] = unit.inventory[target], item
            return true
        end
    end
    return false
end
local a = assert(MakeDummyCastItem(hero))
local b = assert(MakeDummyCastItem(hero))
local function equipment(dummy)
    return {alive = true, holder = hero, pid = 1, native_display = dummy,
        name = function() return "Rare Shield +5" end,
        tooltip = "Rare\nLevel Requirement: 40\n+ 100 Armor\nFlavor text",
        data = {path = "shield.blp", ['1id'] = 0, ['2id'] = 0},
        level = 0, cached_stats = {}, charges = 0,
        abilities = {[1] = {obj = dummy, id = FourCC('A055')}}}
end
local items = Profile[1].hero.items
items[5], items[2] = equipment(a), equipment(b)
assert(ItemRuntime.syncAbilitySlots(1))
assert(hero.inventory[4] == a and hero.inventory[1] == b)
assert(a.icon == "shield.blp" and a.name == items[5]:name() and
    a.tooltip == items[5].tooltip and a.description == items[5].tooltip,
    "Native item did not mirror the full gear presentation")
local c = assert(MakeDummyCastItem(hero))
assert(c.id ~= a.id and c.id ~= b.id, "Repositioning reused a cooldown ID")
items[5], items[2] = items[2], items[5]
assert(ItemRuntime.syncAbilitySlots(1))
assert(hero.inventory[4] == b and hero.inventory[1] == a)
items[3], items[2] = items[2], nil
fail_move = true
assert(not ItemRuntime.syncAbilitySlots(1))
for _, dummy in ipairs({a, b, c}) do
    assert(dummy.droppable == false and dummy.pawnable == false and
        dummy.drop_on_death == false and not dummy.removed,
        "Carrier escaped its safety lock or was recreated")
end
local backpack_dummy = {}
items[3].abilities = {[1] = {obj = backpack_dummy, id = FourCC('AIta')}}
backpack_allowed[FourCC('AIta')] = 1
fail_move = false
assert(ItemRuntime.syncAbilitySlots(1), "Backpack carrier was moved on the hero")
assert(items[3].native_display.active == false)
assert(backpack_dummy.name == nil, "Hero presentation overwrote the backpack ability")
print("PASS: locked carriers, unique cooldown IDs, full tooltips, swaps, and backpack isolation.")

-- All six equipped items, including items with no registered abilities.
hero.inventory = {}
Profile[1].hero.items = {}
items = Profile[1].hero.items
for slot = 1, 6 do
    items[slot] = equipment(nil)
    items[slot].abilities = nil
    items[slot].tooltip = "Full tooltip for equipment " .. slot
end
assert(ItemRuntime.syncAbilitySlots(1))
local seen = {}
for slot = 1, 6 do
    local dummy = assert(hero.inventory[slot - 1])
    assert(dummy == items[slot].native_display and not dummy.active)
    assert(dummy.tooltip == items[slot].tooltip)
    assert(not seen[dummy.id], "Full inventory shared a cooldown ID")
    seen[dummy.id] = true
end

-- Equip an active item into a full inventory using the real deferred attach
-- path, then unequip/re-equip during cooldown without a ghost or reset.
local active_id = FourCC('A055')
local active = equipment(nil)
active.data['1id'] = active_id
active.data['1unlock'] = 0
active.abilities = nil
active.pending_abilities = true
local outgoing = items[4]
outgoing.holder = Backpack[1]
detach(outgoing, false, hero)
items[4] = active
assert(ItemRuntime.syncAbilitySlots(1))
assert(active.abilities[1].obj == active.native_display)
assert(hero.inventory[3] == active.native_display and active.native_display.active)
assert(active.native_display.tooltip == active.tooltip)
Spells[active_id].onUnequip = function() end
BlzStartUnitAbilityCooldown(hero, active_id, 12)
local old = active.native_display
active.holder = Backpack[1]
detach(active, false, hero)
assert(old.removed and active.native_display == nil and active.abilities[1] == nil)
items[4] = outgoing
outgoing.holder = hero
assert(ItemRuntime.syncAbilitySlots(1), "Cooldown ghost blocked an ordinary item")
now = 5
detach(outgoing, false, hero)
items[4] = active
active.holder = hero
active.pending_abilities = true
assert(ItemRuntime.syncAbilitySlots(1))
assert(BlzGetUnitAbilityCooldownRemaining(hero, active_id) == 7,
    "Re-equipping reset the remaining cooldown")
BlzStartUnitAbilityCooldown(hero, active_id, 15)
attach(active, true)
assert(BlzGetUnitAbilityCooldownRemaining(hero, active_id) == 15,
    "Refreshing an equipped effect restored an older cooldown")

-- Dynamic upgrades/charges refresh the full native tooltip in place.
local display = active.native_display
active.tooltip, active.charges = "Upgraded stats and socket effects", 3
assert(ItemRuntime.syncAbilitySlots(1))
assert(display == active.native_display and display.tooltip == active.tooltip and display.charges == 3)

-- Exercise the actual two commit_slot calls used for backpack/equipment swaps:
-- the incoming item commits first while all six old carriers still exist.
SAVE_TABLE = {KEY_ITEMS = {}}
TYPE_POTION_INDEX, POTION_INDEX = 13, 7
apply_item_stats = function() end
SetItemPosition = function() end
SetItemVisible = function() end
local incoming = equipment(nil)
incoming.holder, incoming.index, incoming.equipped = Backpack[1], 7, false
incoming.abilities = nil
incoming.data['1id'], incoming.data['1unlock'] = active_id, 0
items[7] = incoming
active.index, active.equipped = 4, true
ItemRuntime.commit_slot(incoming, 4, true)
assert(incoming.pending_abilities and incoming.native_display == nil,
    "Swap attached the incoming ability before freeing the outgoing carrier")
ItemRuntime.commit_slot(active, 7, true)
assert(ItemRuntime.syncAbilitySlots(1))
for slot = 1, 6 do
    assert(hero.inventory[slot - 1] == items[slot].native_display)
end
assert(incoming.abilities[1].obj == incoming.native_display and incoming.native_display.active)
assert(active.native_display == nil and active.abilities[1] == nil)
assert(BlzGetUnitAbilityCooldownRemaining(hero, active_id) == 15)
print("PASS: six-item mirroring, deferred active attachment, ghost-free replacement, retained cooldowns, and live tooltip refresh.")

UnitRemoveItem = function(unit, dummy)
    for slot = 0, 5 do
        if unit.inventory[slot] == dummy then
            unit.inventory[slot] = nil
            if unit.cooldowns and dummy.attached then unit.cooldowns[dummy.attached] = nil end
        end
    end
end
local native_add = UnitAddItem
UnitAddItem = function(unit, dummy)
    local added = native_add(unit, dummy)
    if added then ItemRuntime.guardNativeItem(dummy, unit) end
    return added
end
local escaped = incoming.native_display
local function force_drop()
    local before = #queued
    assert(ItemRuntime.guardNativeItem(escaped, hero))
    UnitRemoveItem(hero, escaped)
    assert(#queued == before + 1)
    return queued[#queued].callback
end
local restore = force_drop()
restore()
assert(hero.inventory[3] == escaped and not escaped.removed and escaped.active)
assert(BlzGetUnitAbilityCooldownRemaining(hero, active_id) == 15)
assert(escaped.droppable == false and escaped.fields[ITEM_BF_CAN_BE_DROPPED] == false)

-- A transfer between the drop event and recovery must be removed from the
-- latest carrier, without scheduling recursive pickup/drop recoveries.
local stranger = {inventory = {}}
restore = force_drop()
local count_before = #queued
assert(UnitAddItem(stranger, escaped))
assert(#queued == count_before)
restore()
assert(hero.inventory[3] == escaped and stranger.inventory[0] == nil)
assert(BlzGetUnitAbilityCooldownRemaining(hero, active_id) == 15)

-- Intentional logical unequip must not be undone by a deferred drop guard.
restore = force_drop()
incoming.native_display = nil
incoming.abilities[1] = nil
items[4] = nil
incoming.holder = Backpack[1]
RemoveItem(escaped)
restore()
assert(escaped.removed and hero.inventory[3] == nil)
assert(not ItemRuntime.guardNativeItem({id = 1}, hero), "Unowned items must not be intercepted")

local backpack_carrier = assert(MakeDummyCastItem(Backpack[1]))
local backpack_id = FourCC('AIta')
backpack_carrier.attached = backpack_id
items[2].abilities = {[1] = {obj = backpack_carrier, id = backpack_id}}
BlzStartUnitAbilityCooldown(Backpack[1], backpack_id, 8)
assert(ItemRuntime.guardNativeItem(backpack_carrier, Backpack[1]))
local restore_backpack = queued[#queued].callback
UnitRemoveItem(Backpack[1], backpack_carrier)
restore_backpack()
assert(Backpack[1].inventory[0] == backpack_carrier)
assert(BlzGetUnitAbilityCooldownRemaining(Backpack[1], backpack_id) == 8)
print("PASS: native drop/transfer recovery, explicit field locks, cooldown preservation, recursion guard, and intentional removal.")
