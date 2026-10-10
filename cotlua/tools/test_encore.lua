-- Run from the repository root. Offline mocks stay outside the game globals.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load = load
local function load(chunk, name, mode) return native_load(chunk, name, mode or "t", sandbox) end

SONG_FATIGUE, SONG_HARMONY, SONG_WAR, SONG_PEACE = 1, 2, 3, 4
BARD_SONG, BOOST, LBOOST = {[1] = SONG_FATIGUE}, {[1] = 1}, {[1] = 1}
-- This legacy fixture grants equal area/duration bonuses; independent scaling
-- is covered separately by test_spell_scaling.lua.
ABOOST, DBOOST = LBOOST, LBOOST
IMPROV = {id = 10}
local improv
TimerList = {[1] = {get = function() return improv end}}
local caster = {x = 0, y = 0, owner = 0, ally = true}
local near = {x = 500, y = 0, owner = 2}
local edge = {x = 900, y = 0, owner = 2}
local outside = {x = 901, y = 0, owner = 2}
local remote = {x = 2080, y = 0, owner = 2}
local remote_outside = {x = 2200, y = 0, owner = 2}
local ally = {x = 600, y = 0, owner = 1, ally = true}
local remote_ally = {x = 2070, y = 0, owner = 3, ally = true}
local units = {near, edge, outside, remote, remote_outside, ally, remote_ally}
Hero = {[1] = caster, [2] = ally, [4] = remote_ally}
Spell = {define = function(id)
    return setmetatable({id = id}, {__index = function(self, key)
        return self.values and self.values[key]
    end})
end}
IsUnitInRangeXY = function(unit, x, y, radius)
    return (unit.x - x)^2 + (unit.y - y)^2 <= radius^2
end
CreateGroup = function() return {} end
local destroyed = 0
DestroyGroup = function(group)
    assert(not group.destroyed)
    group.destroyed = true
    destroyed = destroyed + 1
end
GroupEnumUnitsInRangeEx = function(_, group, x, y, radius)
    for _, unit in ipairs(units) do
        if IsUnitInRangeXY(unit, x, y, radius) then
            local found = false
            for _, member in ipairs(group) do if member == unit then found = true end end
            if not found then group[#group + 1] = unit end
        end
    end
end
MakeGroupInRange = GroupEnumUnitsInRangeEx
each = function(group)
    local index = 0
    return function() index = index + 1 return group[index] end
end
Player, GetPlayerId = function(id) return id end, function(id) return id end
GetOwningPlayer = function(unit) return unit.owner end
IsUnitAlly = function(unit) return unit.ally == true end
Condition = function(callback) return callback end
isalive = function() return true end
StunUnit = function(_, unit, duration)
    unit.stuns = (unit.stuns or 0) + 1
    unit.stun_duration = duration
end
HP = function(_, unit) unit.heals = (unit.heals or 0) + 1 end
AddSpecialEffectTarget, DestroyEffect = function() return {} end, function() end
local function buff(field)
    return {add = function(_, _, unit)
        unit[field] = (unit[field] or 0) + 1
        return {duration = function() end}
    end}
end
SongOfWarEncoreBuff, SongOfPeaceEncoreBuff = buff("war"), buff("peace")
local file = assert(io.open("cotlua/src/content/abilities/heroes/bard.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(source:find("    ---@class ENCORE", 1, true))
local last = assert(source:find("    ---@class MELODYOFLIFE", first, true))
assert(load(source:sub(first, last - 1)))()
local spell = setmetatable({pid = 1, caster = caster, x = 0, y = 0, aoe = 900, heal = 100},
    {__index = ENCORE})
local casts = 0
local function cast(song, temporary_song)
    for _, unit in ipairs(units) do
        unit.stuns, unit.stun_duration, unit.heals, unit.war, unit.peace = nil, nil, nil, nil, nil
    end
    BARD_SONG[1], improv = song, temporary_song
    spell:onCast()
    casts = casts + 1
    assert(destroyed == casts, "Encore leaked its target group")
end

cast(SONG_FATIGUE)
assert(near.stuns == 1 and edge.stuns == 1 and near.stun_duration == 3)
assert(not outside.stuns and not remote.stuns and not ally.stuns)
cast(SONG_HARMONY)
assert(ally.heals == 1 and not remote_ally.heals)
cast(SONG_WAR)
assert(ally.war == 1 and not remote_ally.war)
cast(SONG_PEACE)
assert(ally.peace == 1 and not remote_ally.peace)

-- A smaller Improv area must not shrink the Bard's own Encore radius.
cast(SONG_FATIGUE, {x = 2000, y = 0, aoe = 100, song = SONG_FATIGUE})
assert(near.stuns == 1 and edge.stuns == 1 and remote.stuns == 1)
assert(not outside.stuns and not remote_outside.stuns)
cast(SONG_WAR, {x = 2000, y = 0, aoe = 100, song = SONG_FATIGUE})
assert(ally.war == 1 and not near.stuns and remote.stuns == 1)
cast(SONG_HARMONY, {x = 2000, y = 0, aoe = 100, song = SONG_PEACE})
assert(ally.heals == 1 and remote_ally.peace == 1 and not remote_ally.heals)
cast(SONG_FATIGUE, {x = 0, y = 0, aoe = 900, song = SONG_FATIGUE})
assert(near.stuns == 1, "Overlapping areas applied Encore twice")
LBOOST[1] = 2
cast(SONG_FATIGUE)
assert(outside.stuns == 1 and near.stun_duration == 6 and not remote.stuns)
print("PASS: all Encore songs without Improv, separate area radii/songs, overlap, scaling, and group cleanup.")
