-- Offline frame/sync mocks. No claim of native UI rendering or network testing.
local env = setmetatable({}, {__index = _G}); env._G = env
local _ENV = env
OnInit = {final = function(_, fn) fn(function() end) end}
FRAMEPOINT_TOP, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPRIGHT = 1, 2, 3
FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMRIGHT, FRAMEEVENT_CONTROL_CLICK = 4, 5, 6
PLAYER_CAP = 6
local frames, hooks, sync, escapes, sent = {}, {}, {}, {}, {}
Player = function(id) return id end
GetLocalPlayer, GetTriggerPlayer = function() return 0 end, function() return 0 end
GetPlayerId = function(player) return player end
GetPlayerName = function(id) return 'Player ' .. id end
local clicked, payload
BlzGetTriggerFrame, BlzGetTriggerSyncData = function() return clicked end, function() return payload end
BlzCreateFrameByType = function(kind, _, parent)
    local f = {kind = kind, parent = parent, enables = {}}
    frames[#frames + 1] = f; return f
end
BlzCreateFrame = function(kind, parent) return BlzCreateFrameByType(kind, '', parent) end
BlzGetFrameByName = function() return {} end
BlzFrameSetAbsPoint, BlzFrameSetSize, BlzFrameSetPoint = function() end, function() end, function() end
BlzFrameSetLevel, BlzFrameSetScale = function() end, function() end
BlzFrameSetVisible = function(f, value) f.visible = value end
BlzFrameSetEnable = function(f, value) f.enabled = value; f.enables[#f.enables + 1] = value end
BlzFrameSetText = function(f, value) f.text = value end
NextFrameCreateContext = function() return 1 end
CreateTrigger = function() return {} end
Condition = function(f) return f end
BlzTriggerRegisterFrameEvent = function(trigger, frame) trigger.frame = frame end
TriggerAddCondition = function(trigger, fn) trigger.frame.click = fn end
SimpleButton = {create = function(parent, _, _, _, _, _, _, _, callback)
    local f = BlzCreateFrameByType('close', '', parent); f.click = callback; return {frame = f}
end}
SyncCallback = function(prefix, callback) sync[prefix] = callback end
BlzSendSyncData = function(prefix, value) sent[#sent + 1] = {prefix, value} end
AddToEsc = function(callback) escapes[#escapes + 1] = callback end
TableHas = function(t, value) for _, v in ipairs(t) do if v == value then return true end end return false end
DisplayTextToPlayer = function() end
User = {[0] = {nameColored = 'One'}, [1] = {nameColored = 'Two'}}
QUEUE_GROUP, QUEUE_READY, QUEUE_DUNGEON = {}, {}, false
Dungeon = {subscribeQueue = function(callback) hooks[#hooks + 1] = callback end,
    setReady = function(pid, value) QUEUE_READY[pid] = value; hooks[1]() end}
local f = assert(io.open('cotlua/src/ui/dialogs/dungeon_ready.lua', 'rb'))
assert(load(f:read('*a'), 'dungeon_ready.lua', 't', env))(); f:close()
local window, ready, start, close = frames[1]
for _, frame in ipairs(frames) do
    if frame.kind == 'GLUETEXTBUTTON' then if not ready then ready = frame else start = frame end end
    if frame.kind == 'close' then close = frame end
end
assert(not window.visible and #hooks == 1 and #escapes == 1)
local started = 0
QUEUE_DUNGEON = {id = 'scarab_crawl', name = 'Scarab Tunnels',
    requestStart = function() started = started + 1; return true end}
QUEUE_GROUP, QUEUE_READY = {1, 2}, {[1] = false, [2] = false}
hooks[1]()
assert(window.visible and ready.enabled and not start.enabled)
clicked = ready; ready.click()
assert(not QUEUE_READY[1] and sent[1][1] == 'dungeon_ready', 'Local clicks must only send a sync request')
assert(ready.enables[#ready.enables - 1] == false and ready.enables[#ready.enables] == true)
payload = sent[1][2]; sync.dungeon_ready()
assert(QUEUE_READY[1] and ready.text == 'Not Ready' and not start.enabled)
QUEUE_READY[2] = true; hooks[1](); assert(start.enabled)
clicked = start; start.click(); payload = sent[2][2]; sync.dungeon_ready()
assert(started == 1)
payload = 'start:old_queue'; sync.dungeon_ready(); assert(started == 1, 'Old window requests must not start another dungeon')
QUEUE_DUNGEON.starting = true; hooks[1](); assert(not start.enabled and not ready.enabled)
QUEUE_DUNGEON.starting = false
clicked = close; close.click(); hooks[1](); assert(not window.visible and QUEUE_READY[1])
hooks[1](1); assert(window.visible, 'Entrance repurchase must reopen a closed ready window')
escapes[1](1); assert(not window.visible)
DungeonReadyView.open(1); assert(window.visible)
QUEUE_GROUP = {2}; hooks[1](); assert(not window.visible, 'Leaving the roster must hide the window')
QUEUE_DUNGEON = false; hooks[1](); assert(not window.visible)
print('PASS: live ready-check view, synchronized requests, stale queue rejection, focus reset, departure locking and reopen/escape behavior.')
