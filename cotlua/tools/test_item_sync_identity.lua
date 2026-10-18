-- Offline Lua 5.3 test of the actual runtime creation/wrapping code.
-- Never loaded by Warcraft; mocks deliberately give clients different handles.
local file = assert(io.open('cotlua/src/gameplay/items/item.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n')
file:close()
local function section(first, last)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(last, start + #first, true), last)
    return source:sub(start, finish - 1)
end
local code = section('        local NativeCreateItem = CreateItem', '        ---Returns the rarity') ..
    section('        function ItemRuntime.create', '        local backpack_allowed')
local function client(pid, initial_native_id)
    local handles, objects, native_id = {}, {}, initial_native_id
    local env = setmetatable({}, {__index = _G})
    env.Item = {cache_stats = function() end}
    env.mt = {__index = env.Item}
    env.ItemRuntime = {definitions = {}, applyData = function() end}
    env.ItemData = setmetatable({}, {__index = function()
        return setmetatable({tooltip = 'example'}, {__index = function() return 0 end})
    end})
    env.ITEM_TIER, env.CUSTOM_ITEM_OFFSET = 1, 0
    env.SAVE_TABLE = {KEY_ITEMS = {}}
    env.IS_ITEM_DROP = setmetatable({}, {__index = function() return true end})
    env.__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
    env.CreateItem = function(id)
        -- Real Lua userdata allows the actual existing-handle branch to run.
        local handle = assert(io.open('cotlua/src/gameplay/items/item.lua', 'rb'))
        handles[#handles + 1] = handle
        native_id = native_id + 1
        objects[handle] = {id = id, native_id = native_id}
        return handle
    end
    env.GetItemTypeId = function(handle) return assert(objects[handle]).id end
    env.GetHandleId = function(handle) return assert(objects[handle]).native_id end
    env.GetItemX, env.GetItemY, env.GetItemCharges = function() return 0 end, function() return 0 end, function() return 0 end
    env.CreateTrigger = function() native_id = native_id + 1; return native_id end
    env.TriggerRegisterDeathEvent, env.TriggerAddCondition = function() end, function() end
    env.GetLocalPlayer, env.GetPlayerId = function() return pid end, function(p) return p end
    env.thistype = env.Item
    assert(load(code, 'actual ItemRuntime creation', 't', env))()
    return env, function() for _, handle in ipairs(handles) do handle:close() end end
end
local host, close_host = client(0, 1130000)
local guest, close_guest = client(4, 1120000)
for i = 1, 3 do
    local a = host.ItemRuntime.create(1010)
    local b = guest.ItemRuntime.create(1010)
    assert(a.sync_id == i and b.sync_id == i, 'Identity must follow shared creation order')
    assert(host.GetHandleId(a.obj) ~= guest.GetHandleId(b.obj))
    assert(host.ItemRuntime.wrap(a.obj) == a and guest.ItemRuntime.wrap(b.obj) == b)
    assert(host.ItemRuntime.create(a.obj) == a and guest.ItemRuntime.create(b.obj) == b)
    assert(a.sync_id == i and b.sync_id == i, 'Wrapping an existing item must not consume an identity')
end
local unwrapped_host = host.CreateItem(2020)
local unwrapped_guest = guest.CreateItem(2020)
local a, b = host.ItemRuntime.wrap(unwrapped_host), guest.ItemRuntime.wrap(unwrapped_guest)
assert(a.sync_id == 4 and b.sync_id == 4, 'First wrap must assign a fresh identity')
assert(host.ItemRuntime.create(1010).sync_id == 5 and guest.ItemRuntime.create(1010).sync_id == 5)
close_host(); close_guest()
print('PASS: actual item creation assigns synchronized monotonic identities independently of native handles; repeated wraps preserve identity.')
