-- Execute the real buff engine, Blood Frenzy callbacks and attack-time setters.
-- Damage/death and the timer clock are mocked; no Warcraft integration claim.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local f = assert(io.open('cotlua/src/' .. path, 'rb'))
    local text = f:read('*a'):gsub('\r\n', '\n'); f:close(); return text
end
local function load_module(path)
    assert(load(read(path), path, 't', env))()
end
OnInit = {final = function(_, callback) callback(function() end) end}
local now, next_id, scheduled = 0, 0, {}
TimerQueue = {
    callDelayed = function(_, delay, callback, ...)
        next_id = next_id + 1
        scheduled[next_id] = {time = now + delay, duration = delay, callback = callback,
            args = {...}, pending = true, enabled = true}
        return next_id
    end,
    disableCallback = function(_, id) if scheduled[id] then scheduled[id].enabled = false end end,
    getRemaining = function(_, id)
        local task = scheduled[id]
        return task and task.pending and math.max(0, task.time - now) or nil
    end,
    getTimeout = function(_, id) return scheduled[id] and scheduled[id].duration end,
}
local function advance(seconds)
    local finish = now + seconds
    while true do
        local first
        for _, task in pairs(scheduled) do
            if task.pending and task.time <= finish and (not first or task.time < first.time) then first = task end
        end
        if not first then break end
        now, first.pending = first.time, false
        if first.enabled then first.callback(table.unpack(first.args)) end
    end
    now = finish
end
local function active_timers()
    local count = 0
    for _, task in pairs(scheduled) do if task.pending and task.enabled then count = count + 1 end end
    return count
end
local death_callback, trigger_unit
EVENT_PLAYER_UNIT_DEATH = 'death'
RegisterPlayerUnitEvent = function(event, callback) assert(event == 'death'); death_callback = callback end
GetTriggerUnit = function() return trigger_unit end
GetPlayerId, GetOwningPlayer = function(p) return p end, function(u) return u.owner end
BlzGetUnitMaxHP = function(u) return u.max_hp end
BlzSetUnitAttackCooldown = function(u, value, index) assert(index == 0); u.attack_time = value end
ATTACK_TYPE_NORMAL, PURE, FPS_32 = 1, 2, 1 / 32
local damage_count = 0
DamageTarget = function(source, target, damage)
    assert(source == target)
    damage_count = damage_count + 1
    target.hp = target.hp - damage
    if target.hp <= 0 and target.alive then
        target.alive, trigger_unit = false, target
        death_callback()
    end
end
local unit_source = read('gameplay/world/unit_table.lua')
local first = assert(unit_source:find('            base_bat = function', 1, true))
local last = assert(unit_source:find('            bonus_damage = function', first, true))
local setters = assert(load('return {\n' .. unit_source:sub(first, last - 1) .. '\n}', 'attack-time setters', 't', env))()
Unit = {}
local effect_removals = 0
local function hero(owner)
    local u = {owner = owner, max_hp = 1000, hp = 1000, alive = true}
    local data = {unit = u, buffs = {}, proxy = {base_bat = 1.5, bonus_bat = .8}}
    data.addEffect = function() return {removals = 0} end
    data.removeEffect = function(_, effect)
        effect.removals = effect.removals + 1; effect_removals = effect_removals + 1
    end
    setmetatable(data, {__index = function(t, key) return t.proxy[key] end,
        __newindex = function(t, key, value)
            t.proxy[key] = value
            if setters[key] then setters[key](t, value) end
        end})
    Unit[u] = data
    data.bonus_bat = .8
    return u
end
load_module('gameplay/combat/buffs/buff_system.lua')
load_module('content/abilities/buffs/heroes/bloodzerker.lua')
Spell = {define = function(id) return {id = id, tag = 'Blood Frenzy'} end}
local spell_source = read('content/abilities/heroes/bloodzerker.lua')
first = assert(spell_source:find('    ---@class BLOODFRENZY', 1, true))
last = assert(spell_source:find('    ---@class BLOODLEAP', first, true))
assert(load(spell_source:sub(first, last - 1), 'real Blood Frenzy spell', 't', env))()
DBOOST = {[1] = 1, [2] = 1}
local function cast(u)
    setmetatable({caster = u, pid = u.owner + 1, dur = 5}, {__index = BLOODFRENZY}):onCast()
end
local function near(actual, expected, message)
    assert(math.abs(actual - expected) < 1e-9, (message or '') .. ': ' .. actual .. ' ~= ' .. expected)
end
local function baseline(u)
    near(Unit[u].bonus_bat, .8, 'Blood Frenzy permanently changed attack-time multiplier')
    near(u.attack_time, 1.2, 'Native attack cooldown did not return to its original value')
end
local victim, ally = hero(0), hero(1)
-- Reproduce the reported sequence, including expiration after a lethal cost.
for _ = 1, 5 do
    victim.hp, victim.alive = 100, true
    cast(victim)
    assert(not victim.alive, 'Blood Frenzy health cost should kill this caster')
    advance(6)
    baseline(victim)
    assert(not BloodFrenzyBuff:has(victim, victim) and #Unit[victim].buffs == 0,
        'Death during application left a ghost buff')
end
assert(effect_removals == 5, 'Each lethal application must clean up its effect exactly once')
assert(active_timers() == 0)
-- A lethal application must not publish a dead buff or schedule expiration.
local added = 0
Buff.onChange(function(_, _, change) if change == 'add' then added = added + 1 end end)
victim.hp, victim.alive = 100, true
cast(victim)
assert(added == 0 and active_timers() == 0, 'Removed buff was published or armed after onApply returned')
-- Surviving cast, partial-stack recast, normal expiration, and owner isolation.
victim.hp, victim.alive = 1000, true
cast(victim)
local buff = assert(BloodFrenzyBuff:get(victim, victim))
near(victim.attack_time, .8); near(victim.hp, 850)
advance(2)
local damage_before = damage_count
cast(victim)
assert(BloodFrenzyBuff:get(victim, victim) == buff and damage_count == damage_before,
    'Same-strength recast reapplied stats or health cost')
advance(4); near(victim.attack_time, .8)
advance(1); baseline(victim); baseline(ally)
-- Repeated/stale removals must not undo another buff or its list entry.
local marker = Buff.new()
local other = marker:add(ally, victim)
buff:remove(); buff:duration(5); buff:refresh()
baseline(victim)
assert(marker:get(ally, victim) == other and other.index == 1 and #Unit[victim].buffs == 1)
other:remove()
-- Death after registration cancels the timer. A stale callback is harmless.
victim.hp, victim.alive = 1000, true
cast(victim)
buff = assert(BloodFrenzyBuff:get(victim, victim))
local expiry = scheduled[buff.internal_callback]
DamageTarget(victim, victim, 10000)
baseline(victim); assert(active_timers() == 0 and #Unit[victim].buffs == 0)
expiry.callback(table.unpack(expiry.args)); baseline(victim)
-- Tier refresh can also kill during onApply; no reapplication after death.
victim.hp, victim.alive = 1000, true
cast(victim); victim.hp = 100
buff = BloodFrenzyBuff:add(victim, victim, 2)
buff:duration(5)
assert(not victim.alive and active_timers() == 0 and #Unit[victim].buffs == 0)
baseline(victim)
-- onRemove may synchronously trigger more cleanup. It must run only once.
local recursive, removals = Buff.new(), 0
function recursive:onRemove() removals = removals + 1; self:remove() end
recursive:add(ally, ally):remove()
assert(removals == 1 and #Unit[ally].buffs == 0)
-- Removing Frenzy must preserve another live multiplier on the same hero.
local speed = Buff.new()
function speed:onApply() Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / 2 end
function speed:onRemove() Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * 2 end
victim.hp, victim.alive = 1000, true
local speed_buff = speed:add(ally, victim)
cast(victim)
buff = assert(BloodFrenzyBuff:get(victim, victim))
buff:remove(); buff:remove()
near(Unit[victim].bonus_bat, .4); assert(speed:has(ally, victim))
speed_buff:remove(); baseline(victim)
-- Full stacks still compact their indices and can be purged together.
local full = Buff.new(); full.STACK_TYPE = BUFF_STACK_FULL
local full_one, full_two = full:add(ally, victim), full:add(ally, victim)
full_one:remove(); full_one:remove()
assert(full_two.index == 1 and #Unit[victim].buffs == 1)
full:removeAll(); assert(#Unit[victim].buffs == 0)
-- Existing cleanup hooks may read remaining duration after timer cancellation.
-- Spin Dash uses this to set its native cooldown on manual removal.
local warrior = read('content/abilities/buffs/heroes/warrior.lua')
first = assert(warrior:find('    ---@class SpinDashBuff', 1, true))
last = assert(warrior:find('    ---@class SpinDashDebuff', first, true))
SPINDASH, ABILITY_ILF_TARGET_TYPE = {id = 'spin-dash'}, 0
GetUnitX, GetUnitY, GetUnitAbilityLevel = function() return 0 end, function() return 0 end, function() return 1 end
BlzGetUnitAbility, BlzSetAbilityIntegerLevelField = function() return {} end, function() end
local cooldown
BlzStartUnitAbilityCooldown = function(u, id, value) assert(u == ally and id == SPINDASH.id); cooldown = value end
assert(load(warrior:sub(first, last - 1), 'real Spin Dash buff', 't', env))()
local dash = SpinDashBuff:add(ally, ally); dash:duration(5)
advance(2); dash:remove(); near(cooldown, 6, 'Cleanup lost remaining duration')
assert(active_timers() == 0)
print('PASS: lethal Blood Frenzy application/revival cycles restore native attack time, no ghost buffs/timers, normal recast/expiry, stale and recursive removal, death on refresh, and owner isolation.')
