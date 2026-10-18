-- Host Lua only; exercise the actual alarm callbacks without a Warcraft client.
local env = setmetatable({}, {__index = _G})
env.OnInit = {final = function(_, init) init(function() end) end}
env.Debug = nil
env.PLAYER_CAP, env.PLAYER_CREEP = 6, 12
env.ABIL_AVUL, env.ABIL_ALOC = 'invulnerable', 'locust'
env.WorldBounds = {region = {}}
env.CreateTrigger, env.Filter = function() return {} end, function(fn) return fn end
env.TriggerAddCondition, env.TriggerRegisterUnitEvent = function() end, function() end
env.EVENT_ON_AGGRO, env.EVENT_ON_HIT, env.EVENT_ON_CAST = {register_unit_action = function() end},
    {register_unit_action = function() end}, {register_unit_action = function() end}
local enter, alarm, current
env.TriggerRegisterEnterRegion = function(_, _, fn) enter = fn end
env.EVENT_ON_STRUCK_FINAL = {register_unit_action = function(_, _, fn) alarm = fn end}
env.GetFilterUnit = function() return current end
env.GetOwningPlayer, env.GetPlayerId = function(u) return u.owner end, function(p) return p end
env.GetUnitX, env.GetUnitY = function() return 0 end, function() return 0 end
env.UnitAlive = function(u) return u.alive end
env.GetUnitAbilityLevel = function(u, ability) return u[ability] and 1 or 0 end
env.IsUnitAlly = function(u, p) return u.owner == p end
env.IsUnitEnemy = function(u, p) return u.owner ~= p end
env.IsUnitInvisible = function(u) return u.invisible end
env.IsUnitVisible = function() return false end -- asleep at night, beyond sight
env.UnitWakeUp = function(u) u.sleeping = false; u.wakes = (u.wakes or 0) + 1 end
env.GetLocalPlayer = function() error('Alarm must not depend on local player') end
local victim = {owner = 12, alive = true}
local attacker = {owner = 2, alive = true}
local helper = {owner = 12, alive = true, sleeping = true}
local busy = {owner = 12, alive = true, target = 'existing', sleeping = false}
local protected = {owner = 12, alive = true, invulnerable = true}
local dummy = {owner = 12, alive = true, locust = true}
local dead = {owner = 12, alive = false}
local other = {owner = 0, alive = true}
env.Unit = {[helper] = helper, [busy] = busy, [victim] = victim}
env.Unit[attacker] = {taunt = function(self, ally) ally.target = self end}
env.ALICE_EnumObjectsInRange = function(_, _, range, kind, filter, source)
    assert(range == 800 and kind == 'unit' and source == victim)
    local allies = {}
    for _, candidate in ipairs({victim, helper, busy, protected, dummy, dead, other}) do
        if filter(candidate, source) then allies[#allies + 1] = candidate end
    end
    return allies
end
assert(loadfile('cotlua/src/gameplay/combat/threat.lua', 't', env))()
current = victim; enter()
alarm(victim, attacker)
assert(not helper.sleeping and helper.target == env.Unit[attacker], 'Sleeping ally did not wake and assist beyond night sight')
assert(busy.target == 'existing' and not busy.wakes, 'Engaged ally was retargeted')
assert(not protected.wakes and not dummy.wakes and not dead.wakes and not other.wakes)
helper.target, helper.sleeping = nil, true
attacker.invisible = true
alarm(victim, attacker)
assert(not helper.sleeping and not helper.target, 'Alarm should wake but not detect an invisible attacker')
helper.sleeping = true
attacker.owner, attacker.invisible = 12, false
alarm(victim, attacker)
assert(helper.sleeping, 'Non-player sources must not trigger alarms')
attacker.owner, attacker.alive = 2, false
alarm(victim, attacker)
assert(helper.sleeping)
alarm(victim, victim)
print('PASS (offline mocks): nighttime alarms wake idle allies, preserve aggro and respect invisibility.')
