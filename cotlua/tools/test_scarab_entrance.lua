-- Offline lifecycle/shop mocks of the actual public Scarab definition.
local env = setmetatable({}, {__index = _G}); env._G = env
local _ENV = env
OnInit = {final = function(_, fn) fn(function() end) end}
FourCC, Player = function(id) return id end, function(id) return id end
PLAYER_NEUTRAL_PASSIVE, ABIL_AVUL = 15, 'invuln'
Hero, Unit = {}, {}
for pid = 1, 3 do Hero[pid] = {}; Unit[Hero[pid]] = {busy = false} end
TableHas = function(t, value) for _, v in ipairs(t) do if v == value then return true end end return false end
TableRemove = function(t, value) for i, v in ipairs(t) do if v == value then table.remove(t, i); return end end end
local prepared, entered, left, members, stopped, deferred, teleports, failure = false, {}, nil, {}, 0, {}, {}, nil
TimerQueue = {callDelayed = function(_, _, fn) deferred[#deferred + 1] = fn end}
DisableBackpackTeleports = function(pid, disabled) teleports[pid] = disabled end
GetRandomInt = function() return 123456 end
DisplayTextToTable, DisplayTextToPlayer = function() end, function() end
ScarabCrawl = {
    setPrepared = function(value) prepared = value end,
    canStart = function() return prepared and next(members) == nil end,
    participantCount = function() local n = 0; for _ in pairs(members) do n = n + 1 end; return n end,
    subscribeLeave = function(callback) left = callback end,
    enter = function(pid, seed)
        if failure == pid then return false, 'Injected entry failure' end
        members[pid] = true; entered[#entered + 1] = {pid, seed}; return true
    end,
    stop = function()
        stopped = stopped + 1
        for pid in pairs(members) do members[pid] = nil; left(pid) end
    end,
}
Dungeon = {define = function(id)
    return {id = id, players = {}, destroy = function(self) self.started = false end,
        isEligible = function(_, pid) return pid == 1 end,
        queue = function(self, pid) self.queued = pid; return true end}
end}
local function source(path)
    local f = assert(io.open('cotlua/src/' .. path, 'rb'))
    assert(load(f:read('*a'), path, 't', env))(); f:close()
end
source('content/dungeons/scarab.lua')
local d = DUNGEON_SCARAB
assert(d.managed_entry and d.level == 500 and d.queue_x == 16000 and d.queue_y == 6311 and prepared)
d.players, d.started = {1, 2}, true; d:onStart()
assert(#entered == 2 and entered[1][2] == entered[2][2], 'Party must enter one shared seed')
assert(Unit[Hero[1]].busy and Unit[Hero[2]].busy and teleports[1] and teleports[2])
members[1] = nil; left(1)
assert(d.started and #d.players == 1 and not Unit[Hero[1]].busy and not teleports[1])
members[2] = nil; left(2)
assert(not d.started and #d.players == 0 and not Unit[Hero[2]].busy and not teleports[2])
assert(stopped == 0, 'Leave callback must not recursively stop the crawl')
deferred[1](); assert(stopped == 1)
d.players, d.started, failure = {1, 2}, true, 2; d:onStart()
assert(not d.started and #d.players == 0 and next(members) == nil and not Unit[Hero[1]].busy and not teleports[1])
local merchant, catalog, offer
CreateUnit = function(owner, id, x, y) merchant = {owner = owner, id = id, x = x, y = y, removed_abilities = {}}; return merchant end
BlzSetUnitName = function(u, name) u.name = name end
UnitAddAbility = function(u, id) u.ability = id end
UnitRemoveAbility = function(u, id) u.removed_abilities[id] = true end
CreateShop = function(id, range) catalog = {id, range} end
ShopAddOffer = function(_, value) offer = value end
source('content/shops/scarab_entrance.lua')
assert(merchant.id == 'nmrk' and merchant.x == 16000 and merchant.y == 6311)
assert(merchant.removed_abilities.Asid and merchant.removed_abilities.Asud)
assert(catalog[2] == 750 and offer.key == 'scarab_dungeon_entrance' and offer.price == 0)
assert(offer.icon == 'ReplaceableTextures\\CommandButtons\\BTNCarrionScarabs.blp')
assert(not offer.availability(2) and offer.purchase(1) and d.queued == 1)
print('PASS: public Scarab entrance, virtual service, shared seed, busy/teleport cleanup, safe last-departure teardown and partial-entry rollback.')
