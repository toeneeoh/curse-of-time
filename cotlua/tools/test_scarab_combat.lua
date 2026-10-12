-- Offline tests: native Ghost (Visible) behavior still needs in-game testing.
local env = setmetatable({}, {__index = _G})
local _ENV = env
OnInit = {final = function(_, fn) fn(function() end) end}
ORDER_ID_ATTACK, ORDER_ID_SMART, ABIL_AVUL = 1, 2, 'invulnerable'
FourCC = function(id) return id end
Unit = setmetatable({}, {__index = function(t, u) local data = {unit = u}; rawset(t, u, data); return data end})
SetUnitCreepGuard = function(u, enabled) assert(not enabled); u.guard = enabled end
RemoveGuardPosition = function(u) u.guard_removed = true end
UnitAddAbility = function(u, id) assert(id == 'Aeth'); u.phase = true end
SetUnitPathing = function() error('Phasing must not disable terrain pathing') end
GetUnitX, GetUnitY = function(u) return u.x end, function(u) return u.y end
GetUnitCurrentOrder = function(u) return u.order end
UnitAlive = function(u) return u.alive end
GetUnitAbilityLevel = function(u) return u.invulnerable and 1 or 0 end
IsUnitVisible = function(u) return not u.hidden end
GetOwningPlayer = function() return 12 end
local attacks, stops = 0, 0
IssueTargetOrder = function(u, _, target) attacks = attacks + 1; u.order, u.target = ORDER_ID_ATTACK, target end
IssueImmediateOrder = function(u) stops = stops + 1; u.order = 0 end
local file = assert(io.open('cotlua/src/gameplay/dungeons/scarab/combat.lua', 'rb'))
local source = file:read('*a'); file:close(); assert(load(source, 'scarab_combat', 't', env))()
local enemy = {x = 0, y = 0, order = 0, alive = true}
local near = {x = 100, y = 0, alive = true}
local far = {x = 1000, y = 0, alive = true}
ScarabCombat.prepare(enemy, true)
assert(enemy.phase and enemy.guard_removed and enemy.guard == false)
ScarabCombat.pursue(enemy, {far, near}); assert(enemy.target == near and attacks == 1)
for _ = 1, 100 do ScarabCombat.pursue(enemy, {far, near}) end
assert(attacks == 1, 'Repeated orders would restart attacks and cause stuttering')
near.x = 2000
ScarabCombat.pursue(enemy, {far, near}); assert(enemy.target == near, 'Must retain a still-valid victim')
enemy.order = 0
ScarabCombat.pursue(enemy, {near, far}); assert(attacks == 2, 'Idle summon must resume pursuit')
near.hidden = true
ScarabCombat.pursue(enemy, {near, far}); assert(enemy.target == far and attacks == 3)
far.invulnerable = true
ScarabCombat.pursue(enemy, {near, far}); assert(stops == 1 and Unit[enemy].target == nil)
ScarabCombat.pursue(enemy, {near, far}); assert(stops == 1, 'Do not spam stop orders')
far.invulnerable, far.alive = false, false
near.hidden = false
ScarabCombat.pursue(enemy, {far, near}); assert(enemy.target == near)
ScarabCombat.pursue(enemy, {}); assert(Unit[enemy].target == nil and stops == 2)
print('PASS: visible ghost setup without pathing bypass, guard removal, sticky targets, idle recovery, visibility/invulnerability/death filtering, and no attack-order spam.')
