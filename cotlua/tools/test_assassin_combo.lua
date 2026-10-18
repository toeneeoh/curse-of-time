-- Execute real Blade Spin and Phantom Slash callbacks on host-native mocks.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local file = assert(io.open('cotlua/src/content/abilities/heroes/assassin.lua', 'rb'))
local source = file:read('*a'); file:close()
local now, queue = 0, {}
TimerQueue = {callDelayed = function(_, delay, callback, ...)
    local entry = {time = now + delay, callback = callback, args = {...}}
    queue[#queue + 1] = entry; return entry
end, disableCallback = function(_, entry) entry.cancelled = true end}
TQ, FPS_32 = TimerQueue, 1 / 32
OnInit = {global = function(_, callback) callback(function() end) end}
assert(loadfile('cotlua/src/framework/scheduling/player_timer.lua', 't', env))()
local function advance(duration)
    local deadline = now + duration
    while true do
        local index
        for i, entry in ipairs(queue) do
            if entry.time <= deadline + .000001 and (not index or entry.time < queue[index].time) then index = i end
        end
        if not index then break end
        local entry = table.remove(queue, index); now = entry.time
        if not entry.cancelled then entry.callback(table.unpack(entry.args)) end
    end
    now = deadline
end
local hero = {x = 0, y = 0, mana = 1000, abilities = {A0AQ = 4, A07Y = 2}}
Hero, Unit = {[1] = hero}, {[hero] = {evasion = 20}}
local targets, hits, added, radius = {}, {}, 0, nil
Spell = {define = function(id) return setmetatable({id = id}, {__index = function(t, key) return t.values and t.values[key] end}) end}
__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
FourCC = function(id) return id end
Player, GetPlayerId = function(p) return p end, function(p) return p end
GetOwningPlayer = function() return 0 end
GetHeroLevel, GetHeroAgi = function(u) assert(u == hero); return 500 end, function() return 100 end
GetUnitAbilityLevel = function(u, id) return u.abilities[id] or 0 end
UnitAddAbility = function(u, id) u.abilities[id] = 1; added = added + 1 end
UnitRemoveAbility = function(u, id) u.abilities[id] = nil end
UnitDisableAbility, BlzUnitDisableAbility = function() end, function() end
SetUnitAbilityLevel = function(u, id, level) u.abilities[id] = level end
BOOST, ABOOST = {[1] = 1}, {[1] = 1}
GetUnitX, GetUnitY, GetUnitZ = function(u) return u.x end, function(u) return u.y end, function() return 0 end
GetUnitFacing = function() return 0 end
SetUnitXBounded, SetUnitYBounded = function(u, v) u.x = v end, function(u, v) u.y = v end
CreateGroup = function() return {} end
DestroyGroup = function(g) assert(not g.destroyed); g.destroyed = true end
MakeGroupInRange = function(_, group, _, _, r) radius = r; group.targets = {}; for i, target in ipairs(targets) do group.targets[i] = target end end
BlzGroupGetSize = function(group) return #group.targets end
each = function(group) local i = 0; return function() i = i + 1; return group.targets[i] end end
IsUnitInGroup = function(target, group) return group[target] end
GroupAddUnit = function(group, target) group[target] = true end
Condition = function(f) return f end
FilterEnemy = function() return true end
UnitAlive, IsTerrainWalkable = function() return true end, function() return true end
AddSpecialEffect, AddSpecialEffectTarget = function() return {} end, function() return {} end
DestroyEffect, DelayAnimation, SetUnitTimeScale, SetUnitAnimationByIndex = function() end, function() end, function() end, function() end
BlzSetSpecialEffectZ, BlzSetSpecialEffectScale, BlzSetSpecialEffectTimeScale = function() end, function() end, function() end
BlzSetSpecialEffectYaw, BlzSetSpecialEffectColorByPlayer = function() end, function() end
BlzSetUnitFacingEx, BlzPlaySpecialEffectWithTimeScale, HideEffect, FadeSFX = function() end, function() end, function() end, function() end
BlzUnitClearOrders, IssueImmediateOrderById = function() end, function() end
SquareRoot, Pow, atan = math.sqrt, function(a, b) return a ^ b end, math.atan
bj_DEGTORAD, bj_RADTODEG, ANIM_TYPE_ATTACK = math.pi / 180, 180 / math.pi, 1
ORDER_ID_MANA_SHIELD, ORDER_ID_UNIMMOLATION = 'spin', 'undash'
UNIT_STATE_MANA, MAGIC, ATTACK_TYPE_NORMAL = 'mana', 'magic', 'normal'
BlzGetUnitMaxMana = function() return 1000 end
GetUnitState = function(u) return u.mana end
SetUnitState = function(u, _, amount) u.mana = amount end
DamageTarget = function(_, target, amount, _, kind) assert(kind == MAGIC); hits[#hits + 1] = {target, amount} end
MarkedForDeathDebuff = {add = function() return {duration = function() end} end}
local callbacks = {}
for _, name in ipairs({'EVENT_ON_HIT', 'EVENT_ON_ATTACK', 'EVENT_ON_ORDER', 'EVENT_STAT_CHANGE', 'EVENT_HERO_LEVEL_CHANGED'}) do
    env[name] = {register_unit_action = function(_, _, callback) callbacks[name] = callback end}
end
local first = assert(source:find('    ---@class BLADESPIN', 1, true))
local last = assert(source:find('    ---@class PHANTOMSLASH', first, true))
assert(load(source:sub(first, last - 1), 'real Blade Spin', 't', env))()
assert(load(source:sub(last):gsub('end, Debug and Debug.getLine%(%)%)%s*$', ''), 'real Phantom Slash', 't', env))()
BLADESPIN.onSetup(hero); advance(.01)
local a, b = {}, {}
local function active(enemies)
    targets, hits = enemies, {}
    BLADESPIN.ready(hero); callbacks.EVENT_ON_ORDER(hero, nil, ORDER_ID_MANA_SHIELD)
    assert(radius == 350)
    return hits
end
assert(active({a})[1][2] == 600, 'Isolated active spin did not get 1.5x damage')
local multiple = active({a, b})
assert(#multiple == 2 and multiple[1][2] == 400 and multiple[2][2] == 400)
targets, hits = {a}, {}
for _ = 1, 4 do callbacks.EVENT_ON_HIT(hero, a) end
callbacks.EVENT_ON_ATTACK(hero, a)
assert(#hits == 1 and hits[1][2] == 1200, 'Level-500 passive spin threshold or isolated damage is wrong')
local function dash(enemies)
    targets, hits = enemies, {}
    hero.x, hero.y = 0, 0; hero.abilities.A0AS = nil
    local spell = setmetatable({caster = hero, pid = 1, ablev = 2, x = 0, y = 0,
        targetX = 120, targetY = 0, dmg = 300}, {__index = PHANTOMSLASH})
    spell:onCast(); advance(FPS_32)
    assert(not hero.abilities.A0AS, 'Dash readied Spin before finishing')
    advance(FPS_32)
    assert(Unit[hero].evasion == 20, 'Dash left its evasion bonus behind')
end
local empty_before = added
dash({}); assert(hero.abilities.A0AS == 4 and added == empty_before + 1, 'Empty dash did not ready exactly one correctly leveled spin')
local before = added
dash({a, b}); assert(hero.abilities.A0AS == 4 and added == before + 1, 'Successful dash did not ready exactly one correctly leveled spin')
before = added
BLADESPIN.ready(hero); BLADESPIN.ready(hero)
assert(added == before, 'Readying a spin stacked or recreated an already-ready charge')
print('PASS: active/passive isolated damage, multi-target damage, spin radius/attack threshold, successful/empty dash, non-stacking readiness and dash evasion cleanup.')
