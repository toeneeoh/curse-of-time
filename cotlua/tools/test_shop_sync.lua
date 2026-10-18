-- Host Lua 5.3 only: exercise real purchase handlers on isolated native mocks.
-- This does not simulate the Warcraft network or certify absence of desyncs.
local file = assert(io.open('cotlua/src/ui/shop/shop.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n')
file:close()
local function section(first, last)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(last, start + #first, true))
    return source:sub(start, finish - 1)
end
local handlers = section('        function thistype:requestBuy', '        ---@type fun(self: Shop, down: boolean)') ..
    section('        function thistype.refresh(pid)', '        function thistype.onSearch()')
assert(not section('        function thistype.onPurchase()', '    ---@class Category'):find(':buy(', 1, true))
local function client(local_player)
    local env = setmetatable({}, {__index = _G})
    local packet, callback, payload, trace = nil, nil, '', {}
    local gold, renders, messages, in_range = 100, 0, 0, true
    local item = {id = 'I001:0'}
    local offer = {id = 'offer:example'}
    local shop = {id = 1234, first = nil, details = {refresh = function() renders = renders + 1 end}}
    shop.definition = {canOpen = function() return true end}
    shop.visible = function() end
    env.thistype = {current = {[5] = 1234}, noGold = {}, error = 'error', success = 'success'}
    setmetatable(shop, {__index = env.thistype})
    local slot = {item = item, button = {play = function() end}}
    env.registry = setmetatable({[1234] = {[0] = shop}, [shop] = {[item.id] = slot,
        [offer.id] = {item = offer, button = slot.button}}}, {__index = function() return {} end})
    env.GetLocalPlayer, env.GetTriggerPlayer = function() return local_player end, function() return 4 end
    env.GetPlayerId, env.Player, env.GetUnitTypeId = function(p) return p end, function(p) return p end, function(u) return u or 0 end
    env.BlzSendSyncData = function(prefix, data) packet = {prefix, data} end
    env.BlzGetTriggerSyncData = function() return payload end
    env.SyncCallback = function(prefix, fn) assert(prefix == 'shop_buy'); callback = fn end
    env.ShopTransaction = {commit = function(_, selected, pid)
        if not in_range then return {can_buy = false, reason = 'range'} end
        local bought = gold >= 50
        if bought then gold = gold - 50 end
        trace[#trace + 1] = selected.id .. ':' .. pid .. ':' .. gold .. ':' .. tostring(bought)
        return {can_buy = bought, reason = bought and nil or 'currency'}
    end}
    env.ShopQuote = {evaluate = function() return {can_buy = in_range, reason = not in_range and 'range'} end}
    env.DisplayTimedTextToPlayer = function(p, _, _, _, text)
        assert(p == 4 and text:find('too far away', 1, true))
        messages = messages + 1
    end
    env.GetPlayerRace = function() return 'human' end
    env.GetSoundIsPlaying, env.StartSoundForPlayerBJ = function() return false end, function() end
    env.SPRITE_MODEL, env.SPRITE_SCALE = 'sprite', 1
    assert(load(handlers, 'shop handlers', 't', env))()
    -- Peers deliberately have different locally rendered detail selections.
    shop.details.item = local_player == 4 and item or offer
    shop:requestBuy(item, 4)
    assert((packet ~= nil) == (local_player == 4), 'Only the actor may emit the request')
    if packet then assert(packet[1] == 'shop_buy' and packet[2] == '1234:I001:0') end
    for _ = 1, 3 do payload = '1234:I001:0'; callback() end
    assert(gold == 0 and #trace == 3, 'Two purchases plus insufficient-gold rejection')
    in_range = false
    payload = '1234:I001:0'; callback()
    assert(gold == 0 and #trace == 3, 'Range failure must not mutate purchases')
    assert(messages == (local_player == 4 and 1 or 0), 'Range text must appear only for the buyer')
    shop:buy(item, 4, true)
    assert(messages == (local_player == 4 and 1 or 0), 'Dry-run quote must not display errors')
    in_range = true
    for _, bad in ipairs({'garbage', '1234:unknown', '9999:I001:0', '1234:'}) do
        payload = bad; callback()
    end
    assert(#trace == 3, 'Invalid/catalog-missing purchases must not mutate state')
    payload = '1234:offer:example'; callback()
    assert(trace[4]:find('offer:example', 1, true), 'Virtual offer keys must preserve colons')
    env.thistype.current[5] = nil
    payload = '1234:I001:0'; callback()
    assert(#trace == 4, 'Closed-shop request must be rejected')
    env.thistype.current[5] = 1234
    shop.definition.canOpen = function() return false end
    env.thistype.refresh(5)
    assert(env.thistype.current[5] == 1234, 'Local UI refresh mutated authoritative selection')
    payload = '1234:I001:0'; callback()
    assert(#trace == 4, 'Revoked access must be rejected')
    if local_player ~= 4 then assert(renders == 0, 'Remote detail panel was refreshed') end
    return table.concat(trace, '\n')
end
assert(client(0) == client(4), 'Local detail selection changed purchase outcome between clients')
print('PASS (offline mocks): shop keys, two purchases, insufficient funds, stale/invalid requests and local refresh isolation.')
