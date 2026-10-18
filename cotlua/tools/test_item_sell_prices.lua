-- Real price registry and sell quote, without native items or shop UI.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local f = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = f:read('*a'):gsub('\r\n', '\n'); f:close(); return source
end
OnInit = {final = function(_, init) init(function() end) end}
FourCC, GetItem = function(id) return id end, function(id) return id end
__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
GOLD, PLATINUM, CRYSTAL, HONOR, FACTION = 1, 2, 3, 4, 5
ITEM_COST, ITEM_STACK = 1, 2
assert(load(read('gameplay/economy/prices.lua'), 'real prices', 't', env))()
local source = read('gameplay/items/item.lua')
local first = assert(source:find('    function GetItemSellPrice', 1, true))
local last = assert(source:find('    ---@type fun(slot:', first, true))
assert(load(source:sub(first, last - 1), 'real sell quote', 't', env))()
local function item(id, cost, stack, charges)
    return {id = id, pid = 1, cached_stats = {[ITEM_COST] = cost or 0, [ITEM_STACK] = stack or 0}, charges = charges}
end
assert(GetItemSellPrice(item('I06T')) == 300, 'Ursa equipment is unsellable')
assert(GetItemSellPrice(item('I08I')) == 500)
assert(GetItemSellPrice(item('I06J')) == 1250, 'Centaur equipment is unsellable')
assert(GetItemSellPrice(item('I006')) == 2500)
assert(GetItemSellPrice(item('I01V')) == 25)
assert(GetItemSellPrice(item('I06T', 2000)) == 1000, 'Formula cost was overridden')
assert(GetItemSellPrice(item('I01X')) == 500, 'Existing shop resale changed')
assert(GetItemSellPrice(item('I04X', 0, 10, 3)) == 750, 'Material stack was not paid per unit')
assert(GetItemSellPrice(item('I056', 0, 10, 10)) == 5000)
for _, id in ipairs({'I044', 'I008', 'I028', 'unknown'}) do
    assert(GetItemSellPrice(item(id)) == 0, 'Quest/ticket/carrier gained a sell value')
end
for id, value in pairs(ITEM_SELL_PRICES) do
    assert(value > 0 and value % 1 == 0)
    assert(GetItemPrice(id, 1) == nil, 'Sell-only valuation added a buy price')
end
SetItemPrice('I06T', 100)
assert(GetItemSellPrice(item('I06T')) == 50, 'Configured shop price was overridden')
local total, gold, platinum = GetItemSellPrice(item('unknown', 2000006))
assert(total == 1000003 and gold == 3 and platinum == 1)
print('PASS: prechaos sale values, formula/shop precedence, material stacks, quest exclusions, no new buy prices, and platinum split.')
