-- Run from the repository root. Exercises the real Arcane Shift callbacks
-- and PlayerTimer loop/cleanup with mocked Warcraft natives.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load, native_loadfile = load, loadfile
local function load(chunk, name, mode) return native_load(chunk, name, mode or "t", sandbox) end
local function loadfile(path) return native_loadfile(path, "t", sandbox) end

OnInit = {global = function(_, callback) callback(function() end) end}
local now, serial, queue = 0, 0, {}
TimerQueue = {
    callDelayed = function(_, delay, callback, ...)
        serial = serial + 1
        local entry = {time = now + delay, serial = serial, callback = callback, args = {...}}
        queue[#queue + 1] = entry
        return entry
    end,
    disableCallback = function(_, entry) entry.cancelled = true end,
}
local function advance(until_time)
    while true do
        table.sort(queue, function(a, b)
            return a.time < b.time or (a.time == b.time and a.serial < b.serial)
        end)
        if not queue[1] or queue[1].time > until_time then break end
        local entry = table.remove(queue, 1)
        now = entry.time
        if not entry.cancelled then entry.callback(table.unpack(entry.args)) end
    end
    now = until_time
end
assert(loadfile("cotlua/src/framework/scheduling/player_timer.lua"))()
FPS_32 = 1 / 32
TQ = TimerQueue
local caster = {cooldown_until = 0}
local enemy = {x = 0, y = 0, speed = 300, damage_count = 0}
local stationary = {x = 0, y = 0, speed = 0, damage_count = 0}
Hero, BOOST, LBOOST = {[1] = caster}, {[1] = 1}, {[1] = 1}
-- This legacy fixture grants equal area/duration bonuses; independent scaling
-- is covered separately by test_spell_scaling.lua.
ABOOST, DBOOST = LBOOST, LBOOST
Spell = {define = function(id) return {id = id, tag = id} end}
CreateGroup = function() return {} end
DestroyGroup = function(group) assert(not group.destroyed) group.destroyed = true end
MakeGroupInRange = function(_, group)
    group[1], group[2] = enemy, stationary
end
FirstOfGroup = function(group) return group[1] end
GroupAddUnit = function(group, unit) group[#group + 1] = unit end
each = function(group)
    local index = 0
    return function() index = index + 1 return group[index] end
end
Condition = function(callback) return callback end
FilterEnemy = function() return true end
UnitAddAbility = function() return true end
UnitRemoveAbility = function() end
FourCC = function(id) return id end
SetUnitFlyHeight = function(unit, height) unit.height = height end
GetUnitMoveSpeed = function(unit) return unit.speed end
SetUnitPathing = function(unit, flag) unit.pathing = flag end
SetUnitXBounded = function(unit, x) unit.x = x end
SetUnitYBounded = function(unit, y) unit.y = y end
GetUnitX = function(unit) return unit.x end
GetUnitY = function(unit) return unit.y end
AddSpecialEffect = function() return {} end
DestroyEffect = function() end
DamageTarget = function(_, unit) unit.damage_count = unit.damage_count + 1 end
BlzGetUnitAbilityCooldown = function() return 30 end
BlzStartUnitAbilityCooldown = function(unit, _, duration) unit.cooldown_until = now + duration end
BlzEndUnitAbilityCooldown = function(unit) unit.cooldown_until = now end
local stun_count = 0
Stun = {add = function(_, _, unit)
    stun_count = stun_count + 1
    return {duration = function(_, duration) unit.stunned_until = now + duration end}
end}
local file = assert(io.open("cotlua/src/content/abilities/heroes/arcanist.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(source:find("    ---@class ARCANESHIFT", 1, true))
local last = assert(source:find("\nend, Debug", first, true))
assert(load(source:sub(first, last - 1)))()
assert(ARCANESHIFT.values.dur == 4 and ARCANESHIFT.cooldown == 30)
local spell = setmetatable({pid = 1, caster = caster, sid = ARCANESHIFT.id,
    ablev = 1, dmg = 100, aoe = 350, dur = 4, targetX = 20, targetY = 30},
    {__index = ARCANESHIFT})
local function cast(x, y)
    if now < caster.cooldown_until then return false end
    spell.targetX, spell.targetY = x, y
    -- Native Warcraft starts the ability cooldown before its effect callback.
    BlzStartUnitAbilityCooldown(caster, ARCANESHIFT.id, 30)
    spell:onCast()
    return true
end

-- Early drop uses the same timer/group and preserves the original stun end.
assert(cast(20, 30))
local timer = assert(TimerList[1]:get(ARCANESHIFT.id, caster))
assert(enemy.height == 500 and enemy.stunned_until == 4)
advance(1)
assert(TimerList[1]:get(ARCANESHIFT.id, caster) == timer,
    "Pickup loop stopped before the second cast")
assert(cast(100, 200))
advance(1 + FPS_32)
assert(enemy.height == 0 and enemy.x == 100 and enemy.y == 200)
assert(stationary.height == 0 and stationary.x == 0 and stationary.y == 0)
assert(enemy.damage_count == 1 and stationary.damage_count == 1)
assert(enemy.stunned_until == 4 and stun_count == 2, "Early drop shortened or restarted stun")
assert(#TimerList[1].timers == 0 and timer._destroyed)
assert(caster.cooldown_until == 30 and not cast(100, 200), "Early drop allowed stun-lock recasts")
advance(5)
assert(enemy.damage_count == 1 and enemy.pathing == true, "Drop repeated damage or failed to restore pathing")

-- Natural timeout drops at the original point once and restores remaining CD.
advance(30)
assert(cast(300, 400))
advance(34)
assert(enemy.height == 0 and enemy.x == 300 and enemy.y == 400)
assert(enemy.damage_count == 2 and stationary.damage_count == 2)
assert(enemy.stunned_until == 34 and #TimerList[1].timers == 0)
assert(caster.cooldown_until == 60 and not cast(300, 400))

-- Cancelling before the delayed cooldown clear cannot wipe the restored CD.
advance(60)
assert(cast(500, 600))
TimerList[1]:stopAllTimers()
assert(enemy.height == 0 and stationary.height == 0)
advance(60 + FPS_32)
assert(caster.cooldown_until == 90 and #TimerList[1].timers == 0)
assert(enemy.damage_count == 2 and not cast(500, 600))
print("PASS: Arcane Shift early drop, full stun, natural expiry, single-hit damage, cooldown, and cancellation cleanup.")
