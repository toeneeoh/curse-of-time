-- Real startup and ItemLookup dispatch. Native layering is deliberately retired.
local env = setmetatable({}, {__index = _G})
local _ENV = env
OnInit = {final = function(_, callback) callback(function() end) end}
local pause = function() end
PauseUnit, BlzPauseUnitEx = pause, pause
UnitAddAbility, UnitRemoveAbility = function() error("Inventory ability mutation") end, function() error("Inventory ability removal") end
assert(loadfile('cotlua/src/gameplay/items/ground_pickup.lua', 't', env))()
assert(not GroundPickup.refresh({}) and PauseUnit == pause and BlzPauseUnitEx == pause)
local callbacks, wrapped, lookups, guards, moved = {}, 0, 0, 0, 0
EVENT_PLAYER_UNIT_PICKUP_ITEM, EVENT_PLAYER_UNIT_DROP_ITEM, EVENT_PLAYER_UNIT_SELL_ITEM = 'pickup', 'drop', 'sell'
RegisterPlayerUnitEvent = function(event, callback) callbacks[event] = callback end
PLAYER_CAP, MAX_INVENTORY_SLOTS = 2, 26
Player, GetPlayerId, GetOwningPlayer = function(p) return p end, function(p) return p end, function(u) return u.player end
Hero, Profile = {[1] = {player = 0}}, {[1] = {hero = {items = {}}}}
GetItemTypeId = function(item) return item.id end
GetUnitX, GetUnitY = function() return 10 end, function() return 20 end
IsDummyCastItem = function(id) return id == 'dummy' end
local consumed = 0
LootService = {consumeProxy = function(_, item)
    if item.id == 'I1LP' then consumed = consumed + 1; return true end
    return false
end}
ItemRuntime = {wrap = function(item)
    assert(item.id ~= 'I1LP', 'Disposable proxy entered the managed Item registry')
    wrapped = wrapped + 1
    return {obj = item, id = item.id, pid = 0, type = 1,
        equip = function() return not item.denied end}
end, guardNativeItem = function() guards = guards + 1 end}
BlzGetItemBooleanField = function(item) return item.automatic end
SetItemPosition = function(item, x, y) assert(x == 10 and y == 20); item.detached = true; moved = moved + 1 end
NotifyItemChanged, DisplayTimedTextToPlayer = function() end, function() end
VerifySlotForType = function() return true end
ITEM_LOOKUP, ON_BUY_LOOKUP = {[101] = function() lookups = lookups + 1 end}, {}
assert(loadfile('cotlua/src/gameplay/items/item_lookup.lua', 't', env))()
assert(ItemLookup.collect(Hero[1], {id = 'I1LP'}, true))
assert(consumed == 1 and wrapped == 0 and moved == 0)
local item = {id = 101}
assert(ItemLookup.collect(Hero[1], item, true) and item.detached and lookups == 1)
assert(not ItemLookup.collect(Hero[1], {id = 101, denied = true}, true) and lookups == 1)
assert(not ItemLookup.collect(Hero[1], {id = 'dummy'}, true) and guards == 1)
assert(not ItemLookup.collect(Hero[1], {id = 101, automatic = true}, false))
assert(ItemLookup.collect(Hero[1], {id = 101, automatic = true}, true) and lookups == 2)
print('PASS (real dispatch): no secondary inventory or pause hooks; raw proxies bypass wrapping; ordinary acquisition, rejection, dummy protection and native powerup lookup remain intact.')
