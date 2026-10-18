-- Actual use path: successful effects, failed-use silence, restoration and cleanup.
local file = assert(io.open('cotlua/src/gameplay/items/potions.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local first = assert(source:find('    local function play_use_effect', 1, true))
local last = assert(source:find('    local function prepare_vampire_flask', first, true))
local function client(heal, mana, behavior)
    local env = setmetatable({}, {__index = _G})
    local hero = {health = 100, mana = 100}
    local item = {charges = 2, cached_stats = {heal, 0, mana, 0}}
    local timers, effects, cooldowns, notifications = {}, {}, {}, 0
    env.ITEM_FLAT_HEAL, env.ITEM_PERCENT_HEAL, env.ITEM_FLAT_MANA, env.ITEM_PERCENT_MANA = 1, 2, 3, 4
    env.Hero, env.Unit = {[1] = hero}, {[hero] = {hp = 1000, mana = 500, regen_percent = 1}}
    env.UnitAlive = function(u) return not u.dead end
    env.potion_at = function() return item end
    env.potion_behavior = function() return behavior end
    env.Perks = {getBonuses = function() return {} end}
    env.GetWidgetLife = function(u) return u.health end
    env.HP = function(_, u, amount) u.health = u.health + amount end
    env.MP = function(u, amount) u.mana = u.mana + amount end
    env.UndyingRageBuff = {has = function() return false end}
    env.cooldown_table = function() return cooldowns end
    env.clear_cooldown = function(_, index) cooldowns[index] = nil end
    env.TQ = {callDelayed = function(_, delay, callback, ...)
        timers[#timers + 1] = {delay = delay, callback = callback, args = {...}}; return #timers
    end}
    env.AddSpecialEffectTarget = function(model, target, attachment)
        assert(target == hero and attachment == 'origin')
        local effect = {model = model}; effects[#effects + 1] = effect; return effect
    end
    env.HideEffect = function(effect) assert(not effect.destroyed); effect.destroyed = true end
    env.NotifyItemChanged = function() notifications = notifications + 1 end
    env.PotionService = {
        getCooldown = function(_, index) return cooldowns[index] and 5 or 0 end,
        getCustomization = function() end, describe = function() return 'Potion' end,
        getInfusionMultiplier = function() return 1 end, getUseCooldown = function() return 5 end,
    }
    assert(load(source:sub(first, last - 1), 'actual potion use', 't', env))()
    return {env = env, item = item, hero = hero, effects = effects, timers = timers, cooldowns = cooldowns,
        notices = function() return notifications end}
end
for _, case in ipairs({
    {100, 0, 'AIhe', 1.833}, {0, 50, 'AIma', 1.833}, {100, 50, 'AIre', 2.133},
    {0, 0, 'AIre', 2.133}, {100, 50, 'AIre', 2.133, {replaces_restoration = true}},
}) do
    local c = client(case[1], case[2], case[5])
    assert(c.env.PotionService.use(1, 1).success and c.item.charges == 1)
    assert(#c.effects == 1 and c.effects[1].model:find(case[3] .. 'Target.mdl', 1, true))
    local expectedHeal, expectedMana = case[5] and 0 or case[1], case[5] and 0 or case[2]
    assert(c.hero.health == 100 + expectedHeal and c.hero.mana == 100 + expectedMana)
    assert(c.notices() == 1 and #c.timers == 2)
    local cleanup = c.timers[2]
    assert(cleanup.callback == c.env.HideEffect and cleanup.delay >= case[4], 'Animation cut off before completion')
    cleanup.callback(table.unpack(cleanup.args)); assert(c.effects[1].destroyed)
    assert(not c.env.PotionService.use(1, 1).success and #c.effects == 1, 'Cooldown rejection played an effect')
end
for _, failure in ipairs({'slot', 'missing', 'dead', 'charges', 'cooldown'}) do
    local c = client(100, 50)
    if failure == 'missing' then c.env.potion_at = function() end end
    if failure == 'dead' then c.hero.dead = true end
    if failure == 'charges' then c.item.charges = 0 end
    if failure == 'cooldown' then c.cooldowns[1] = true end
    assert(not c.env.PotionService.use(1, failure == 'slot' and 3 or 1).success)
    assert(#c.effects == 0 and #c.timers == 0 and c.notices() == 0)
end
print('PASS: real potion use plays one matching hero effect on success, preserves restoration/charges/cooldown, cleans up after native animation duration, and creates no effects on rejected uses.')
