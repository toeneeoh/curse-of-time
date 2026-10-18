-- Run from the repository root. Uses the real Smoke Bomb spell/buff callbacks
-- and PlayerTimer loop/cleanup with mocked Warcraft natives.
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
OnInit = {
    global = function(_, callback) callback(function() end) end,
    final = function(_, callback) callback(function() end) end,
}
local now, queue = 0, {}
TimerQueue = {
    callDelayed = function(_, delay, callback, ...)
        local entry = {time = now + delay, callback = callback, args = {...}}
        queue[#queue + 1] = entry
        return entry
    end,
    disableCallback = function(_, entry) entry.cancelled = true end,
}
local effects, groups, effect_removals, group_removals = {}, {}, 0, 0
AddSpecialEffect = function()
    -- Tables use PlayerTimer's effect-wrapper branch; live natives return
    -- userdata and take its direct-handle branch.
    local effect = {effect = {}}
    effects[#effects + 1] = effect
    return effect
end
CreateGroup = function()
    local group = {}
    groups[#groups + 1] = group
    return group
end
DestroyEffect = function(effect)
    assert(not effect.removed, "Smoke effect destroyed twice")
    effect.removed = true
    effect_removals = effect_removals + 1
end
DestroyGroup = function(group)
    assert(not group.removed, "Smoke group destroyed twice")
    group.removed = true
    group_removals = group_removals + 1
end
assert(loadfile("cotlua/src/framework/scheduling/player_timer.lua"))()

local caster, ally, enemy = {x = 100, y = 200}, {x = 100, y = 220}, {enemy = true, x = 130, y = 200}
Hero, LBOOST = {[1] = caster}, {[1] = 1}
ABOOST, DBOOST = {[1] = 1.4}, {[1] = 2}
Unit = {[caster] = {evasion = 5}, [ally] = {evasion = 2}, [enemy] = {ms_percent = 1}}
local ability_level = 1
GetUnitAbilityLevel = function() return ability_level end
local buffs = {}
Buff = {new = function()
    local class = {}
    function class:get(source, target)
        for _, buff in ipairs(buffs) do
            if not buff.removed and buff.class == self and buff.target == target
                and (source == nil or buff.source == source) then return buff end
        end
    end
    function class:add(source, target)
        local existing = self:get(source, target)
        if existing then return existing end
        -- Deliberately do not initialize evasion: the real Buff also creates
        -- an empty instance, which exposed the original nil-arithmetic error.
        local buff = setmetatable({class = self, source = source, target = target}, {__index = self})
        function buff:remove()
            assert(not self.removed, 'Buff removed twice')
            self.removed = true
            if self.expiry then TimerQueue:disableCallback(self.expiry) end
            self:onRemove()
        end
        function buff:duration(value)
            if self.expiry then TimerQueue:disableCallback(self.expiry) end
            self.expires = now + value
            self.expiry = TimerQueue:callDelayed(value, function() self:remove() end)
            -- Buff:duration schedules expiration and returns nil in the game.
        end
        buff:onApply()
        buffs[#buffs + 1] = buff
        return buff
    end
    return class
end}
assert(loadfile("cotlua/src/content/abilities/buffs/heroes/assassin.lua"))()
Spell = {define = function(id) return {id = id} end}
Condition = function(callback) return callback end
isalive = function() return true end
local source = read("cotlua/src/content/abilities/heroes/assassin.lua")
local first = assert(source:find("    ---@class SMOKEBOMB", 1, true))
local last = assert(source:find("    ---@class DAGGERSTORM", first, true))
assert(load(source:sub(first, last - 1)))()

local spins = 0
BLADESPIN = {id = 1, id2 = 2, ready = function(u) assert(u == caster); spins = spins + 1 end}
UnitAddAbility, UnitDisableAbility, BlzSetSpecialEffectScale = function() end, function() end, function() end
Player = function(pid) return pid end
Condition = function(callback) return callback end
isalive = function() return true end
IsUnitAlly = function(target) return not target.enemy end
MakeGroupInRange = function() end
MakeGroupInRange = function(_, group, x, y, radius)
    group.targets = {}
    assert(radius == 630)
    for _, target in ipairs({caster, ally, enemy}) do
        if (target.x - x)^2 + (target.y - y)^2 <= radius^2 then group.targets[#group.targets + 1] = target end
    end
end
each = function(group)
    local index = 0
    return function() index = index + 1 return group.targets[index] end
end
GetUnitX, GetUnitY, GetUnitZ = function(u) return u.x end, function(u) return u.y end, function() return 0 end
UnitAlive = function(u) return not u.dead end
BlzSetSpecialEffectPosition = function(effect, x, y) effect.x, effect.y = x, y end
BlzSetSpecialEffectTimeScale = function(effect, speed) effect.speed = speed end
GetPlayerId, GetOwningPlayer = function() return 0 end, function() return 0 end
EVENT_STAT_CHANGE = {register_unit_action = function() end}
R2I, BlzGetUnitMaxMana = math.floor, function() return 1000 end
local mana_cost
BlzSetUnitAbilityManaCost = function(_, _, _, value) mana_cost = value end

local function advance(duration)
    local deadline = now + duration
    while true do
        local next_index
        for i, entry in ipairs(queue) do
            if entry.time <= deadline + .000001 and (not next_index or entry.time < queue[next_index].time) then next_index = i end
        end
        if not next_index then break end
        local entry = table.remove(queue, next_index)
        now = entry.time
        if not entry.cancelled then entry.callback(table.unpack(entry.args)) end
    end
    now = deadline
end

local spell = setmetatable({pid = 1, caster = caster, targetX = 50, targetY = 60,
    aoe = 450, dur = 8}, {__index = SMOKEBOMB})
SMOKEBOMB.onLearn(caster, 1, 1); assert(mana_cost == 150)
spell:onCast()
assert(#TimerList[1].timers == 1)
assert(Unit[caster].evasion == 125 and Unit[ally].evasion == 22, 'Smoke did not apply protection immediately')
assert(math.abs(Unit[enemy].ms_percent - .7) < .00001)
assert(effects[1].speed == 1.5 and spins == 1)
caster.x, caster.y = 200, 300
advance(.1)
assert(effects[1].x == 200 and effects[1].y == 300, 'Smoke did not follow the caster')
advance(2.9)
assert(Unit[caster].evasion == 25, 'Duration scaling extended the fixed three-second protection')
advance(13)
assert(#TimerList[1].timers == 0 and effect_removals == 1 and group_removals == 1)
advance(1)
assert(Unit[caster].evasion == 5 and Unit[ally].evasion == 2 and Unit[enemy].ms_percent == 1)
spell:onCast(); advance(1); spell:onCast()
assert(Unit[caster].evasion == 125 and #TimerList[1].timers == 1, 'Recast stacked smoke or protection')
TimerList[1]:stopAllTimers()
assert(Unit[caster].evasion == 25 and effect_removals == 3 and group_removals == 3)
advance(1)
assert(Unit[caster].evasion == 5)
spell:onCast(); caster.dead = true; advance(.1)
assert(#TimerList[1].timers == 0 and Unit[caster].evasion == 25, 'Death did not cancel smoke/protection')
advance(1)
assert(Unit[caster].evasion == 5)
spell:onCast()
SmokebombVeilBuff:get(caster, caster):remove()
assert(Unit[caster].evasion == 25)
TimerList[1]:stopAllTimers()
advance(1)
assert(Unit[caster].evasion == 5, 'Dispelled protection was removed twice during cleanup')
print('PASS: immediate following smoke, scaled radius/duration, fixed protection, 1.5x animation, mana cost, expiry/recast/death/cleanup with nil-returning Buff:duration.')
