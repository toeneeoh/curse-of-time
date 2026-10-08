-- Offline regression using the real Hidden Guise and PlayerTimer callbacks.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load, native_loadfile = load, loadfile
local function load(chunk) return native_load(chunk, "hidden guise", "t", sandbox) end
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
        local entry = {at = now + delay, callback = callback, args = {...}}
        queue[#queue + 1] = entry
        return entry
    end,
    disableCallback = function(_, entry) entry.cancelled = true end,
}
local function advance(until_time)
    while true do
        table.sort(queue, function(a, b) return a.at < b.at end)
        if not queue[1] or queue[1].at > until_time then break end
        local entry = table.remove(queue, 1)
        now = entry.at
        if not entry.cancelled then entry.callback(table.unpack(entry.args)) end
    end
    now = until_time
end
assert(loadfile("cotlua/src/framework/scheduling/player_timer.lua"))()
local rogue = {pathing = true, owner = 0, abilities = {}}
Hero, Unit = {[1] = rogue}, {[rogue] = {attack = true}}
ABIL_AVUL, ABIL_ALOC = "invulnerable", "locust"
SetUnitPathing = function(unit, enabled) unit.pathing = enabled end
SetUnitVertexColor = function(unit, _, _, _, alpha) unit.alpha = alpha end
ToggleCommandCard = function(unit, enabled) unit.command_card = enabled end
UnitAddAbility = function(unit, id) unit.abilities[id] = true end
UnitRemoveAbility = function(unit, id) unit.abilities[id] = nil end
FourCC = function(id) return id end
GetUnitFacing = function() return 0 end
AddSpecialEffect = function() return {} end
BlzSetSpecialEffectYaw, DestroyEffect = function() end, function() end
UnitAlive = function(unit) return not unit.dead end
bj_DEGTORAD = math.pi / 180
local exits, drops = 0, 0
PlayerAddItemById = function(pid, id)
    assert(pid == 1 and id == "I0OW")
    exits = exits + 1
    -- Model the existing five-second native Wind Walk powerup.
    rogue.invisible, rogue.pathing = true, false
    TimerQueue:callDelayed(5, function() rogue.invisible, rogue.pathing = false, true end)
end
DropAggro = function(unit) assert(unit == Unit[rogue]) drops = drops + 1 end
Spell = {define = function(id) return {id = id} end}
local source = read("cotlua/src/content/abilities/heroes/master_rogue.lua")
local first = assert(source:find("    ---@class HIDDENGUISE", 1, true))
local last = assert(source:find("    ---@class NERVEGAS", first, true))
assert(load(source:sub(first, last - 1)))()
local cast = {pid = 1, caster = rogue, x = 0, y = 0}
HIDDENGUISE.onCast(cast)
assert(not rogue.pathing and rogue.abilities[ABIL_AVUL] and not Unit[rogue].attack)
advance(2)
assert(exits == 1 and not rogue.abilities[ABIL_AVUL] and Unit[rogue].attack)
assert(rogue.invisible and not rogue.pathing and #TimerList[1].timers == 0)
advance(7)
assert(not rogue.invisible and rogue.pathing and drops == 2)

HIDDENGUISE.onCast(cast)
advance(7.5)
local timer = assert(TimerList[1]:get(HIDDENGUISE.id))
HIDDENGUISE.expire(timer)
HIDDENGUISE.expire(timer)
advance(9)
assert(exits == 2 and #TimerList[1].timers == 0, "Early exit duplicated the invisibility powerup")
advance(12.5)
HIDDENGUISE.onCast(cast)
TimerList[1]:stopAllTimers()
assert(rogue.pathing and rogue.command_card and not rogue.abilities[ABIL_AVUL] and Unit[rogue].attack)
advance(15)
assert(exits == 2, "Repick/leave cleanup incorrectly granted an exit powerup")

-- Scripted acquisition must honor visibility from the enemy's perspective.
PLAYER_CAP = 12
GetOwningPlayer = function(unit) return unit.owner end
GetPlayerId = function(player) return player end
GetUnitAbilityLevel = function(unit, id) return unit.abilities[id] and 1 or 0 end
IsUnitVisible = function(unit) return not unit.invisible or unit.detected end
local enemy = {owner = 12}
source = read("cotlua/src/gameplay/combat/threat.lua")
first = assert(source:find("    local function proximity_filter", 1, true))
last = assert(source:find("    ---@type fun(source: unit, dist: number)", first, true))
local eligible = assert(load(source:sub(first, last - 1) .. "\nreturn proximity_filter"))()
assert(eligible(rogue, enemy))
rogue.invisible = true
assert(not eligible(rogue, enemy), "Scripted retargeting reacquired an invisible Rogue")
rogue.detected = true
assert(eligible(rogue, enemy), "Detection must still reveal invisible targets")
rogue.abilities[ABIL_AVUL] = true
assert(not eligible(rogue, enemy))
rogue.abilities[ABIL_AVUL], rogue.invisible, rogue.detected = nil, false, false

PLAYER_BOSS = 12
GetFilterUnit = function() return rogue end
source = read("cotlua/src/gameplay/world/boss.lua")
first = assert(source:find("        local function valid_target()", 1, true))
last = assert(source:find("        function thistype:switch_target", first, true))
local boss_eligible = assert(load(source:sub(first, last - 1) .. "\nreturn valid_target"))()
rogue.invisible = true
assert(not boss_eligible(), "Boss retargeting ignored invisibility")
rogue.detected = true
assert(boss_eligible())

local dispatched = 0
EVENT_ENEMY_AI = {has_unit_actions = function() return true end, trigger = function() dispatched = dispatched + 1 end}
Stopwatch = {create = function() return {getElapsed = function() return now end} end}
INTERNAL_AI_COOLDOWN = 1
Unit[enemy] = {}
assert(loadfile("cotlua/src/gameplay/abilities/enemy_ai.lua"))()
rogue.invisible, rogue.detected = true, false
assert(not EnemyAI.evaluate(enemy, rogue) and dispatched == 0)
rogue.detected = true
assert(EnemyAI.evaluate(enemy, rogue) and dispatched == 1)
print("PASS: Hidden Guise collision, both phases, early exit, cancellation cleanup, visibility-aware retargeting, and detection.")
