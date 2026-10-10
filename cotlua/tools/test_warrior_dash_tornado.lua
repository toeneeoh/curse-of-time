-- Offline regression against the actual Warrior spell callbacks.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local file = assert(io.open("cotlua/src/content/abilities/heroes/warrior.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local function extract(first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    assert(load(source:sub(first, last - 1), "warrior", "t", sandbox))()
end
local now, queue = 0, {}
TQ = {
    callDelayed = function(_, delay, callback, ...)
        local entry = {at = now + delay, callback = callback, args = {...}}
        queue[#queue + 1] = entry
        return entry
    end,
    disableCallback = function(_, entry) entry.disabled = true end,
}
local function advance(time)
    while true do
        table.sort(queue, function(a, b) return a.at < b.at end)
        if not queue[1] or queue[1].at > time then break end
        local entry = table.remove(queue, 1)
        now = entry.at
        if not entry.disabled then entry.callback(table.unpack(entry.args)) end
    end
    now = time
end
FPS_32, bj_DEGTORAD, bj_PI, atan = 1 / 32, math.pi / 180, math.pi, math.atan
Spell = {define = function(id)
    return setmetatable({id = id, tag = id}, {__index = function(self, key)
        return self.values and self.values[key]
    end})
end}
local hero = {x = 0, y = 0, alive = true}
Hero, Unit, BOOST, LBOOST = {[1] = hero}, {[hero] = {damage = 100}}, {[1] = 1}, {[1] = 1}
-- This legacy fixture grants equal area/duration bonuses; independent scaling
-- is covered separately by test_spell_scaling.lua.
ABOOST, DBOOST = LBOOST, LBOOST
LIMITBREAK = {id = "limit", flag = {[1] = 2}}
ADAPTIVESTRIKE = {id = "adaptive"}
GetUnitX, GetUnitY = function(u) return u.x end, function(u) return u.y end
SetUnitXBounded, SetUnitYBounded = function(u, x) u.x = x end, function(u, y) u.y = y end
GetUnitAbilityLevel = function(_, id) return id == "limit" and 0 or 1 end
GetOwningPlayer, GetPlayerId = function() return 0 end, function(p) return p end
UnitAlive = function(u) return u.alive end
DistanceCoords = function(x, y, tx, ty) return math.sqrt((tx - x)^2 + (ty - y)^2) end
IsUnitInRangeXY = function(u, x, y, radius) return DistanceCoords(u.x, u.y, x, y) <= radius end
UnitDisableAbility, BlzUnitHideAbility, BlzStartUnitAbilityCooldown = function() end, function() end, function() end
BlzGetUnitAbility, BlzSetAbilityIntegerLevelField = function() return {} end, function() end
SetUnitPropWindow = function(u, window) u.window = window end
SetUnitTimeScale = function(u, scale) u.scale = scale end
AddUnitAnimationProperties = function(u, _, enabled) u.spinning = enabled end
SetUnitPathing = function(u, enabled) u.pathing = enabled end
local effects = {}
AddSpecialEffectTarget = function(path, u, attachment)
    assert(path == "war3mapImported\\Red White Tornado.mdx" and u == hero and attachment == "origin")
    local effect = {}
    effects[#effects + 1] = effect
    return effect
end
BlzPlaySpecialEffectWithTimeScale = function(effect) assert(not effect.hidden); effect.playing = true end
HideEffect = function(effect) assert(effect and not effect.hidden); effect.hidden = true end
local buff
SpinDashBuff = {
    get = function() return buff end,
    add = function(_, unit)
        buff = {x = unit.x, y = unit.y, source = unit, duration = function() end,
            remove = function() buff = nil end}
        return buff
    end,
}
AdaptiveStrikeBuff = {get = function() end, add = function() return {duration = function() end} end}
valid_target = function() return true end
ALICE_ForAllObjectsInRangeDo = function() end
extract("    ---@class SPINDASH", "    ---@class INTIMIDATINGSHOUT")
local function cast_dash(tx)
    local spell = setmetatable({pid = 1, caster = hero, x = hero.x, y = hero.y,
        targetX = tx, targetY = 0, angle = 0}, {__index = SPINDASH})
    spell:onCast()
    return spell
end
local outward = cast_dash(800)
advance(0.2)
assert(not effects[1].hidden and hero.spinning and not hero.pathing)
local returning = cast_dash(0)
assert(outward.finished and outward.callback.disabled and effects[1].hidden)
assert(#effects == 2 and not effects[2].hidden and effects[2].playing)
assert(hero.spinning and not hero.pathing)
-- Even a stale queued callback must not interfere with the new cast.
outward.callback.callback(table.unpack(outward.callback.args))
assert(hero.spinning and not hero.pathing and not effects[2].hidden)
advance(2)
assert(returning.finished and effects[2].hidden and hero.pathing and not hero.spinning and hero.scale == 1)
-- Recast after the first leg has already completed also gets its own visual.
hero.x = 0
cast_dash(800)
advance(4)
assert(effects[3].hidden)
cast_dash(0)
assert(#effects == 4 and not effects[4].hidden)
advance(6)
LIMITBREAK.flag[1], hero.x = 0, 0
cast_dash(800)
advance(8)
assert(#effects == 4 and hero.pathing, "Normal dash tried to clean up a nonexistent effect")
print("PASS: empowered recasts keep their own visual; old dash callbacks cannot reset them; normal cleanup is safe.")

PARRY, INTIMIDATINGSHOUT, WINDSCAR = {id = "parry"}, {id = "shout"}, {id = "wind"}
LAST_CAST = {[1] = WINDSCAR.id}
FourCC = function(id) return id end
UNIT_RF_COLLISION_SIZE = "collision"
CreateGroup, DestroyGroup = function() return {} end, function() end
local tornadoes, timers = {}, {}
Dummy = {create = function(x, y)
    local unit = {x = x, y = y, pathing = false, collision = 16}
    tornadoes[#tornadoes + 1] = unit
    return {unit = unit}
end}
BlzSetUnitSkin = function(u, skin)
    assert(skin == "n001")
    u.skin, u.pathing, u.collision = skin, true, 32
end
BlzSetUnitRealField = function(u, field, value) assert(field == "collision"); u.collision = value end
SetUnitMoveSpeed, SetUnitScale, UnitAddAbility = function() end, function() end, function() end
IssuePointOrder = function(u)
    assert(u.skin == "n001" and not u.pathing and u.collision == 0, "Tornado can block movement after its skin changes")
end
TimerList = {[1] = {add = function()
    local timer = {pid = 1, time = 0, startLoop = function(self, period, callback)
        self.period, self.callback = period, callback
    end}
    timers[#timers + 1] = timer
    return timer
end}}
extract("    ---@class ADAPTIVESTRIKE", "    ---@class LIMITBREAK")
ADAPTIVESTRIKE.effect(hero, hero.x, hero.y)
assert(#tornadoes == 5 and #timers == 5)
for _, timer in ipairs(timers) do
    assert(timer.period == 0.5 and timer.dur == 3 and timer.dmg == 40)
    assert(not timer.target.pathing and timer.target.collision == 0)
end
print("PASS: all five Adaptive Strike tornadoes are non-blocking after skin changes; duration and damage are unchanged.")
