-- Offline native mocks: tests the actual queue module, not Warcraft rendering.
local env = setmetatable({}, {__index = _G})
env._G = env
local _ENV = env
OnInit = {final = function(_, fn) fn(function() end) end}
FourCC = function(id)
    local n = 0
    for i = 1, #id do n = n * 256 + id:byte(i) end
    return n
end
ITEM_LOOKUP, Hero, Unit, QUEUE_DUNGEON = {}, {}, {}, false
User = {first = {id = 1, next = {id = 2, next = {id = 3}}}}
for pid = 1, 3 do
    Hero[pid] = {pid = pid, alive = true, level = 500, near = pid ~= 3}
    Unit[Hero[pid]] = {busy = false}
end
UnitAlive = function(u) return u.alive end
GetHeroLevel = function(u) return u.level end
IsUnitInRangeXY = function(u) return u.near end
TableHas = function(t, value) for _, v in ipairs(t) do if v == value then return true end end return false end
TableRemove = function(t, value) for i, v in ipairs(t) do if v == value then table.remove(t, i); return end end end
Player = function(i) return i end
local messages, moves, locks, listeners, delay, periodic = {}, {}, {}, 0, {}, {}
DisplayTextToPlayer = function(_, _, _, message) messages[#messages + 1] = message end
DisplayTextToTable = function(_, message) messages[#messages + 1] = message end
MoveHero = function(pid) moves[#moves + 1] = pid end
DisableItems = function(pid, disabled) locks[pid] = disabled end
DisableBackpackTeleports = function() end
BlackMask = function() end
TimerQueue = {
    callDelayed = function(_, seconds, fn) delay[#delay + 1] = {seconds = seconds, fn = fn} end,
    callPeriodically = function(_, seconds, stop, fn)
        periodic[#periodic + 1] = {seconds = seconds, stop = stop, fn = fn}
    end,
}
local f = assert(io.open('cotlua/src/gameplay/dungeons/dungeon.lua', 'rb'))
assert(load(f:read('*a'), 'dungeon.lua', 't', env))(); f:close()
local native = Dungeon.define('I0JU')
assert(ITEM_LOOKUP[FourCC('I0JU')])
local d = Dungeon.define('test_crawl')
d.level, d.queue_x, d.queue_y = 400, 0, 0
native.level, native.queue_x, native.queue_y = 400, 0, 0
local started = 0
d.onStart = function() started = started + 1 end
Dungeon.subscribeQueue(function() listeners = listeners + 1 end)
assert(not d:queue(3) and not QUEUE_DUNGEON)
assert(d:queue(1) and QUEUE_DUNGEON == d and #QUEUE_GROUP == 2)
assert(periodic[1].seconds == .25 and not QUEUE_READY[1] and not QUEUE_READY[2])
assert(not Dungeon.setReady(3, true) and not d:requestStart(3))
assert(not native:queue(1), 'Different dungeons must not share one ready check')
assert(not d:requestStart(1), 'Unready players must block departure')
assert(Dungeon.setReady(1, true) and Dungeon.setReady(2, true))
Hero[2].near = false; periodic[1].fn()
assert(#QUEUE_GROUP == 1 and QUEUE_READY[2] == false)
Hero[2].near = true; periodic[1].fn()
assert(#QUEUE_GROUP == 2 and not QUEUE_READY[2], 'Rejoining must require readiness again')
assert(Dungeon.setReady(2, true) and d:requestStart(1))
assert(d.starting and not d:requestStart(1) and not Dungeon.setReady(1, false))
Hero[2].alive = false; delay[1].fn()
assert(started == 0 and not d.starting and not d.started and #moves == 0,
    'A death during the departure delay must cancel entry')
Hero[2].alive = true; periodic[1].fn()
assert(Dungeon.setReady(2, true))
local old_hero = Hero[2]
Hero[2] = {pid = 2, alive = true, level = 500, near = true}; Unit[Hero[2]] = {busy = false}
periodic[1].fn()
assert(not QUEUE_READY[2], 'Replacement heroes must not inherit readiness')
assert(Dungeon.setReady(2, true))
Hero[3].near = true; periodic[1].fn()
assert(#QUEUE_GROUP == 3 and not QUEUE_READY[3])
assert(Dungeon.setReady(3, true) and d:requestStart(1))
delay[2].fn()
assert(started == 1 and d.started and not QUEUE_DUNGEON and #QUEUE_GROUP == 0)
assert(#d.players == 3 and #moves == 3 and periodic[1].stop())
for pid = 1, 3 do assert(locks[pid] and not QUEUE_READY[pid]) end
assert(not d:queue(1), 'Active dungeons must reject another party')
d:destroy()
d.managed_entry = true
assert(d:queue(1))
for pid = 1, 3 do assert(Dungeon.setReady(pid, true)) end
assert(d:requestStart(1)); delay[3].fn()
assert(started == 2 and #moves == 3, 'Managed crawls must own their own positioning')
assert(listeners > 10)
d:destroy()
assert(d:queue(1))
for pid = 1, 3 do Hero[pid].near = false end
periodic[#periodic].fn()
assert(not QUEUE_DUNGEON and #QUEUE_GROUP == 0, 'An empty queue must close')
print('PASS: standalone dungeon queue, readiness, live roster, replacement heroes, delayed start validation, managed entry and teardown.')
