-- Offline regression for Bard song lifecycle and Railgun's explicit beam.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load = load
local function load(chunk) return native_load(chunk, "hero visuals", "t", sandbox) end
local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
SONG_FATIGUE, SONG_HARMONY, SONG_PEACE, SONG_WAR = "fatigue", "harmony", "peace", "war"
BARD_SONG = {}
local setup_callbacks = {}
TQ = {callDelayed = function(_, delay, callback, unit)
    assert(delay == 0)
    setup_callbacks[#setup_callbacks + 1] = function() callback(unit) end
end}
local spells = {}
Spell = {define = function(id) local spell = {} spells[id] = spell return spell end}
local active_timer
TimerList = {[1] = {
    get = function() return active_timer end,
    add = function()
        active_timer = {pid = 1, startLoop = function() end}
        return active_timer
    end,
}}
CreateGroup = function() return {} end
Player = function(id) return id end
SetPlayerAbilityAvailable = function(_, _, enabled)
    assert(not enabled, "Song re-enabled a native status aura")
end
UnitRemoveAbility = function(unit, id) unit.auras[id] = nil end
local effects = {}
AddSpecialEffectTarget = function(path, unit, attachment)
    assert(path == "war3mapImported\\Music effect01.mdx" and attachment == "overhead")
    local effect = {unit = unit}
    effects[#effects + 1] = effect
    return effect
end
DestroyEffect = function(effect) assert(not effect.destroyed) effect.destroyed = true end
BlzSetSpecialEffectColorByPlayer = function(effect, color)
    assert(not effect.destroyed, "Song tried to recolor a destroyed effect")
    effect.color = color
end
local source = read("cotlua/src/content/abilities/heroes/bard.lua")
local first = assert(source:find("    local song_color", 1, true))
local last = assert(source:find("    ---@class ENCORE", first, true))
assert(load(source:sub(first, last - 1)))()
local caster = {auras = {[SONG_WAR] = true, [SONG_HARMONY] = true, [SONG_PEACE] = true}}
spells.A02F.onSetup(caster)
assert(next(caster.auras) ~= nil, "Setup removed abilities during native enumeration")
for _, callback in ipairs(setup_callbacks) do callback() end
assert(next(caster.auras) == nil)
spells.A02C.onCast({pid = 1, caster = caster})
spells.A026.onCast({pid = 1, caster = caster})
assert(#effects == 1 and effects[1].color == 6, "Song switching did not reuse/recolor music")
active_timer.onRemove(active_timer)
active_timer = nil
local new_caster = {auras = {}}
spells.A027.onCast({pid = 1, caster = new_caster})
assert(#effects == 2 and effects[1].destroyed and effects[2].unit == new_caster)
assert(effects[2].color == 4, "Song music did not restart after repick/cleanup")
print("PASS: Bard native indicators removed, music reuse/recolor, and recreation after cleanup.")

FPS_32, bj_PI, BOOST = 1 / 32, math.pi, {[1] = 1}
local queued = {}
TQ = {callDelayed = function(_, delay, callback, handle)
    queued[#queued + 1] = {delay = delay, callback = callback, handle = handle}
end}
local beams = {}
AddLightningEx = function(id, _, x1, y1, z1, x2, y2, z2)
    assert(id == "RAIL" and x1 == 65 and y1 == 0 and x2 == 3065 and y2 == 0)
    assert(z1 == 135 and z2 == 135)
    local beam = {}
    beams[#beams + 1] = beam
    return beam
end
DestroyLightning = function(beam) beam.destroyed = true end
local enemy = {}
MakeGroupInRange = function(_, group, _, _, radius) group[1] = radius == 800 and enemy or nil end
Condition = function(callback) return callback end
FilterEnemy = function() return true end
GetUnitX, GetUnitY = function(unit) return unit.x end, function(unit) return unit.y end
GetTerrainZ = function() return 0 end
ModuloReal = function(a, b) return a % b end
BlzGroupGetSize = function(group) return #group end
each = function(group)
    local index = 0
    return function() index = index + 1 return group[index] end
end
local function noop() end
AddSpecialEffect = function() return {} end
BlzSetSpecialEffectScale, BlzSetSpecialEffectYaw, BlzSetSpecialEffectRoll = noop, noop, noop
BlzSetSpecialEffectZ, BlzPlaySpecialEffect, BlzPlaySpecialEffectWithTimeScale = noop, noop, noop
BlzGetLocalSpecialEffectZ, GetUnitFacing = function() return 0 end, function() return 0 end
SetUnitScale, SetUnitAnimation, BlzSetUnitFacingEx = noop, noop, noop
local hits = 0
DamageTarget = function(attacker, target, amount)
    assert(attacker == caster and target == enemy and amount == 100)
    hits = hits + 1
end
Dummy = {create = function() error("Railgun beam must not require attack dummies") end}
thistype = {range = 3000, aoe = 800, dmg = function() return 100 end}
source = read("cotlua/src/content/abilities/heroes/thunderblade.lua")
first = assert(source:find("    ---@class RAILGUN", 1, true))
first = assert(source:find("        local function periodic(pt)", first, true))
last = assert(source:find("        function thistype:onCast()", first, true))
local periodic = assert(load(source:sub(first, last - 1) .. "\nreturn periodic"))()
local timer = {pid = 1, time = 0, dur = 4, ug = {}, angle = 0,
    source = caster, target = {x = 65, y = 0}}
assert(periodic(timer) and #beams == 0)
timer.time = 4 - FPS_32
assert(not periodic(timer) and #beams == 1 and hits == 1)
for _, entry in ipairs(queued) do entry.callback(entry.handle) end
assert(beams[1].destroyed)
print("PASS: Railgun charging, custom beam endpoints/height, beam expiry, and unchanged single AoE hit.")
