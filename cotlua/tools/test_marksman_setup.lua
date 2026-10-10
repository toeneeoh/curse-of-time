-- Offline callbacks/field writes only; native Channel movement and command-card
-- visibility still need to be checked in Warcraft.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local f = assert(io.open('cotlua/src/content/abilities/heroes/elite_marksman.lua', 'rb'))
local text = f:read('*a'):gsub('\r\n', '\n'); f:close()
local last = assert(text:find('    ---@class ASSAULTHELICOPTER', 1, true))
local indexed, queued, missiles, death = {}, {}, {}, {}
OnInit = {final = function(_, callback) callback(function() end) end}
Spell = {define = function(id) return {id = id} end}
Unit = {onIndex = function(callback) indexed[#indexed + 1] = callback end}
TimerQueue = {callDelayed = function(_, delay, callback, ...)
    queued[#queued + 1] = {delay = delay, callback = callback, args = {...}}
end}
local function flush(delay)
    local old = queued; queued = {}
    for _, entry in ipairs(old) do
        if entry.delay == delay then entry.callback(table.unpack(entry.args))
        else queued[#queued + 1] = entry end
    end
end
HERO_MARKSMAN, FPS_32, bj_PI = 'E008', 1 / 32, math.pi
for _, field in ipairs({'ABILITY_IF_LEVELS', 'ABILITY_BF_ITEM_ABILITY', 'ABILITY_SLF_TOOLTIP_NORMAL',
    'ABILITY_RLF_FOLLOW_THROUGH_TIME', 'ABILITY_RLF_ART_DURATION', 'ABILITY_BLF_DISABLE_OTHER_ABILITIES'}) do
    env[field] = field
end
GetUnitTypeId = function(u) return u.id end
GetOwningPlayer, GetPlayerId = function(u) return u.owner end, function(p) return p end
Player = function(p) return p end
BlzGetUnitAbility = function(u, id) return u.abilities[id] end
BlzGetAbilityIntegerField = function(a) return a.levels end
local function set_field(a, field, level, value)
    assert(a and level >= 0 and level < a.levels, 'Invalid native ability level')
    a[field] = a[field] or {}; a[field][level] = value
end
BlzSetAbilityStringLevelField = set_field
BlzSetAbilityRealLevelField = function() error('Tri-Rocket rewrote native Channel level data') end
BlzSetAbilityBooleanLevelField = function() error('Tri-Rocket rewrote native Channel level data') end
BlzSetAbilityBooleanField = function(a, field, value) a[field] = value end
BlzSetUnitAbilityCooldown = function(u, id, level, value) set_field(u.abilities[id], 'cooldown', level, value) end
UnitMakeAbilityPermanent = function(u, value, id) assert(value); u.permanent = id end
BlzUnitDisableAbility = function(u, id, disabled, hidden) assert(not disabled and not hidden); u.visible = id end
SetPlayerAbilityAvailable = function(_, id, available) assert(id == 'A01Q' and available) end
local added = 0
UnitAddAbility = function(u, id)
    if u.abilities[id] then return false end
    assert(id == 'A01Q'); added = added + 1
    u.abilities[id] = {levels = 1, ABILITY_BF_ITEM_ABILITY = true}
    return true
end
EVENT_ON_UNIT_DEATH = {register_unit_action = function(_, u, callback) death[u] = callback end}
EVENT_ON_CLEANUP = {register_action = function() end, unregister_action = function() end}
AddSpecialEffectTarget, DestroyEffect = function() return {} end, function() end
SoundHandler = function() end
GetUnitZ = function() return 0 end
OrderId = function(order) return order end
ORDER_ID_STOP = 'stop'
GetUnitCurrentOrder = function(u) return u.order end
local stops = 0
IssueImmediateOrderById = function(u, order)
    assert(order == ORDER_ID_STOP)
    stops = stops + 1; u.order = order
end
BOOST, LBOOST = {[1] = 1}, {[1] = 1}
-- This legacy fixture grants equal area/duration bonuses; independent scaling
-- is covered separately by test_spell_scaling.lua.
ABOOST, DBOOST = LBOOST, LBOOST
CAT_Knockback = function(u, x, y, z) u.knockback = {x, y, z} end
local friction = 0
CAT_UnitEnableFriction = function(_, enabled) friction = friction + (enabled and 1 or -1) end
ALICE_Create = function(missile) missiles[#missiles + 1] = missile end
AddSpecialEffect, BlzSetSpecialEffectScale = function() return {} end, function() end
assert(load(text:sub(1, last - 1) .. '\nend)', 'Marksman setup', 't', env))()
local hero = {id = HERO_MARKSMAN, owner = 0, abilities = {
    A01Q = {levels = 1, ABILITY_BF_ITEM_ABILITY = true}, A06I = {levels = 5},
}}
Unit[hero] = {pid = 1, cc_percent = 1, cd_percent = 1, base_bat = 1.8, range = 650}
SNIPERSTANCE.onSetup(hero); SNIPERSTANCE.onSetup(hero)
assert(not hero.abilities.A01Q.ABILITY_BF_ITEM_ABILITY and hero.visible == 'A01Q' and hero.permanent == 'A01Q')
assert(not SNIPERSTANCE.enabled[1] and hero.abilities.A01Q.ABILITY_SLF_TOOLTIP_NORMAL[0]:find('Enable Sniper', 1, true))
assert(TRIROCKET.onLearn == nil and TRIROCKET.onSetup == nil,
    'Learning Tri-Rocket must not execute native field writes')
SNIPERSTANCE.onCast({pid = 1, caster = hero})
assert(SNIPERSTANCE.enabled[1] and Unit[hero].overmovespeed == 100 and Unit[hero].range == 1150)
assert(Unit[hero].cc_percent == 2 and Unit[hero].cd_percent == 2 and Unit[hero].base_bat == 3.6)
for level = 0, 4 do assert(hero.abilities.A06I.cooldown[level] == 3) end
death[hero](hero); death[hero](hero)
assert(not SNIPERSTANCE.enabled[1] and Unit[hero].overmovespeed == nil and Unit[hero].range == 650)
assert(Unit[hero].cc_percent == 1 and Unit[hero].cd_percent == 1 and Unit[hero].base_bat == 1.8)
for rank = 1, 5 do
    hero.order = 'carrionscarabson'
    local before = #missiles
    TRIROCKET.onCast({pid = 1, caster = hero, ablev = rank, angle = 0, dmg = 100, x = 0, y = 0})
    assert(#missiles == before + 3 and friction == 1 and hero.knockback[1] == -500)
    assert(hero.order == 'carrionscarabson', 'Interrupted the cast inside its native effect event')
    flush(0); assert(stops == rank and hero.order == 'stop', 'Lingering Tri-Rocket Channel was not stopped')
    flush(1); assert(friction == 0, 'Tri-Rocket friction was not released')
end
TRIROCKET.onCast({pid = 1, caster = hero, angle = 0, dmg = 100, x = 0, y = 0})
hero.order = 'move'
flush(0); assert(stops == 5 and hero.order == 'move', 'Interrupted a newer movement order')
flush(1)
TRIROCKET.onCast({pid = 1, caster = hero, angle = 0, dmg = 100, x = 0, y = 0})
hero.order = 'another_spell'
flush(0); assert(stops == 5 and hero.order == 'another_spell', 'Interrupted a newer spell order')
flush(1)
hero.abilities.A01Q = nil
for _, callback in ipairs(indexed) do callback(hero) end
assert(added == 0, 'Added an ability during native index enumeration')
flush(0); assert(added == 1)
local missing = {id = HERO_MARKSMAN, owner = 1, abilities = {}}
Unit[missing] = {pid = 2, cc_percent = 1, cd_percent = 1, base_bat = 1.8, range = 650}
for _, callback in ipairs(indexed) do callback(missing) end
flush(0)
assert(added == 2 and missing.visible == 'A01Q' and not missing.abilities.A01Q.ABILITY_BF_ITEM_ABILITY)
print('PASS (mocked callbacks): no Tri-Rocket native learn/setup writes; deferred Channel release at all five ranks preserves newer orders; three rockets and recoil cleanup; innate stance setup and death cleanup.')
