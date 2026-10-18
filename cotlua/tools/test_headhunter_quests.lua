-- Execute the actual headhunter definitions, handlers, and turn-in logic.
local file = assert(io.open('cotlua/src/gameplay/world/quests.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local first = assert(source:find('    -- headhunter\n', 1, true))
local last = assert(source:find('    -- kill quests\n', first, true))
local env = setmetatable({}, {__index = _G})
env.FourCC = function(id) return id end
env.ITEM_LOOKUP, env.Hero, env.Unit = {}, {[1] = {}, [2] = {}}, {}
env.Unit[env.Hero[1]], env.Unit[env.Hero[2]] = {xp_rate = 100}, {xp_rate = 150}
local level, heads, rewards, xp, messages = 50, {}, {}, {}, {}
env.Player = function(id) return id end
env.GetHeroLevel = function() return level end
env.GetItemFromPlayer = function(pid, id) return heads[pid] and heads[pid][id] end
env.PlayerAddItemById = function(pid, id) rewards[#rewards + 1] = {pid, id} end
env.AwardXP = function(pid, amount) xp[#xp + 1] = {pid, amount} end
env.DisplayTextToPlayer = function(_, _, _, message) messages[#messages + 1] = message end
env.register_quest_reward = function() end
env.ItemRuntime = {create = function() end}
assert(load(source:sub(first, last - 1), 'headhunter quests', 't', env))()
for _, id in ipairs({'I049', 'I03G', 'I05N', 'I04M', 'I092'}) do
    assert(type(env.ITEM_LOOKUP[id]) == 'function', 'Missing turn-in: ' .. id)
end
local function give_head(pid, id)
    heads[pid] = heads[pid] or {}
    local head = {destroy = function(self)
        assert(heads[pid][id] == self, 'Consumed head twice')
        heads[pid][id] = nil
    end}
    heads[pid][id] = head
end
local function turn_in(id, pid)
    env.ITEM_LOOKUP[id](pid - 1, pid, env.Hero[pid], {id = id})
end
give_head(1, 'I02M')
level = 49; turn_in('I049', 1)
assert(heads[1].I02M and #rewards == 0 and #xp == 0)
level = 50; turn_in('I049', 1)
assert(not heads[1].I02M and rewards[1][1] == 1 and rewards[1][2] == 'I04C')
assert(xp[1][2] == 10000)
turn_in('I049', 1)
assert(#rewards == 1 and #xp == 1 and messages[#messages] == 'You do not have the head.')
give_head(2, 'I044'); turn_in('I03G', 2)
assert(rewards[2][1] == 2 and rewards[2][2] == 'I0F8' and xp[2][2] == 11250)
give_head(1, 'I05R'); level = 59; turn_in('I05N', 1)
assert(heads[1].I05R and #rewards == 2)
level = 60; turn_in('I05N', 1)
assert(not heads[1].I05R and rewards[3][2] == 'I03O' and xp[3][2] == 10000)
print('PASS: all five headhunter handlers registered; Ogre/Hydra/Yeti correct heads, rewards, XP, level gates, per-player ownership, and repeat rejection.')
