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

local caster, ally, enemy = {}, {}, {enemy = true}
Hero, LBOOST = {[1] = caster}, {[1] = 1}
Unit = {[caster] = {evasion = 5}, [ally] = {evasion = 2}, [enemy] = {ms_percent = 1}}
local ability_level = 1
GetUnitAbilityLevel = function() return ability_level end
local buffs = {}
Buff = {new = function()
    local class = {}
    function class:add(source, target)
        for _, buff in ipairs(buffs) do
            if buff.class == self and buff.target == target then return buff end
        end
        -- Deliberately do not initialize evasion: the real Buff also creates
        -- an empty instance, which exposed the original nil-arithmetic error.
        local buff = setmetatable({class = self, source = source, target = target}, {__index = self})
        function buff:duration(value) self.expires = now + value return self end
        buff:onApply()
        buffs[#buffs + 1] = buff
        return buff
    end
    return class
end}
assert(loadfile("cotlua/src/content/abilities/buffs/heroes/assassin.lua"))()
Spell = {define = function(id) return {id = id} end}
local source = read("cotlua/src/content/abilities/heroes/assassin.lua")
local first = assert(source:find("    ---@class SMOKEBOMB", 1, true))
local last = assert(source:find("    ---@class DAGGERSTORM", first, true))
assert(load(source:sub(first, last - 1)))()

BLADESPIN = {id = 1, id2 = 2}
UnitAddAbility, UnitDisableAbility, BlzSetSpecialEffectScale = function() end, function() end, function() end
Player = function(pid) return pid end
Condition = function(callback) return callback end
isalive = function() return true end
IsUnitAlly = function(target) return not target.enemy end
MakeGroupInRange = function() end
each = function()
    local targets, index = {caster, ally, enemy}, 0
    return function() index = index + 1 return targets[index] end
end

local spell = setmetatable({pid = 1, caster = caster, targetX = 50, targetY = 60,
    aoe = 300, dur = 8}, {__index = SMOKEBOMB})
spell:onCast()
assert(#TimerList[1].timers == 1)
while #queue > 0 do
    local entry = table.remove(queue, 1)
    now = entry.time
    if not entry.cancelled then entry.callback(table.unpack(entry.args)) end
    if now == 0.5 then
        assert(Unit[ally].evasion == 12, "Ally did not receive 10% evasion")
        assert(Unit[caster].evasion == 25, "Caster's doubled bonus changed")
        assert(math.abs(Unit[enemy].ms_percent - 0.7) < 0.00001, "Enemy slow changed")
    end
end
assert(now == 8 and #TimerList[1].timers == 0, "Smoke timer did not finish")
assert(effect_removals == 1 and group_removals == 1, "Smoke visual/group survived expiry")

-- Re-applying after removal (including a higher-level partial-stack refresh)
-- replaces the bonus, rather than adding to the old saved amount.
for _, buff in ipairs(buffs) do
    buff:onRemove()
    buff:onApply()
end
assert(Unit[ally].evasion == 12 and Unit[caster].evasion == 25)
for _, buff in ipairs(buffs) do buff:onRemove() end
assert(Unit[ally].evasion == 2 and Unit[caster].evasion == 5 and Unit[enemy].ms_percent == 1)
ability_level = 3
for _, buff in ipairs(buffs) do buff:onApply() end
assert(Unit[ally].evasion == 14 and Unit[caster].evasion == 29)
for _, buff in ipairs(buffs) do buff:onRemove() end
assert(Unit[ally].evasion == 2 and Unit[caster].evasion == 5)

-- Repick/leave cancellation also uses PlayerTimer's real resource cleanup.
spell:onCast()
TimerList[1]:stopAllTimers()
assert(effect_removals == 2 and group_removals == 2 and #TimerList[1].timers == 0)
print("PASS: Smoke Bomb evasion, refresh/removal, slow, timed visual cleanup, and cancellation cleanup.")
