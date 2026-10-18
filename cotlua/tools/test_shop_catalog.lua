-- Actual town registration and registry, with presentation and price natives mocked.
local env = setmetatable({}, {__index = _G})
local _ENV = env
OnInit = {global = function(_, f) f(function() end) end,
    final = function(_, f) f(function() end) end}
Debug = nil
FourCC = function(id) return id end
GetItem = function(id) return id end
__jarray = function(v) return setmetatable({}, {__index = function() return v end}) end
SetItemPrice = function() end
PotionMasterServices = {addToShop = function() end}
assert(loadfile('cotlua/src/gameplay/shops/offers.lua', 't', env))()
assert(loadfile('cotlua/src/gameplay/shops/registry.lua', 't', env))()
assert(loadfile('cotlua/src/content/shops/town.lua', 't', env))()
local magic = assert(ShopRegistry.get('n01B'))
assert(#magic.categories == 0 and #magic.items == 5 and #magic.offers == 1)
local offer = magic.offers[1]
assert(offer.virtual and offer.key == 'stat_points' and magic:has(offer.id))
for _, id in ipairs({'I0TS:0', 'I0TA:0', 'I0TI:0', 'I0TT:0'}) do
    assert(not magic:has(id), 'Old attribute tome remains in the catalog')
end
print('PASS (actual registration): Magic Merchant has five items and one indexed stat-point offer; the four old tome offers are absent.')
