-- Exercise the actual boss tuning through initial creation and fresh respawn.
local file = assert(io.open('cotlua/src/gameplay/world/boss.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
local env = setmetatable({}, {__index = _G})
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b - 1)
end
env.FourCC = function(id) return id end
env.GetUnitTypeId = function(unit) return unit.id end
env.BlzGetUnitArmor = function(unit) return unit.armor end
env.SetWidgetLife = function(unit, hp) unit.life = hp end
env.__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
env.Boss = {setup_range_event = function() end}
env.thistype, env.mt = env.Boss, {__index = env.Boss}
env.User, env.PLAYER_BOSS, env.FORCE_PLAYING = {}, 12, {}
env.SetUnitCreepGuard, env.DisplayTimedTextToForce = function() end, function() end
local function event() return {register_unit_action = function() end} end
env.EVENT_ON_STRUCK_FINAL, env.EVENT_ON_UNIT_DEATH = event(), event()
env.EVENT_ON_AGGRO, env.EVENT_ON_ENTER_SAFE_AREA = event(), event()
local template = {hp = 100000, armor = 500}
env.CreateUnit = function(_, id)
    return {id = id, hp = template.hp, base_armor = template.armor, armor = template.armor}
end
env.Unit = setmetatable({}, {__index = function(t, unit)
    local values = {hp = unit.hp, bonus_hp = 0, armor_percent = 1}
    local data = setmetatable({}, {
        __index = values,
        __newindex = function(_, key, value)
            values[key] = value
            if key == 'bonus_hp' then values.hp = unit.hp + value end
            if key == 'armor_percent' then unit.armor = unit.base_armor * value end
        end,
    })
    rawset(t, unit, data); return data
end})
env.SetHeroLevel = function(unit, level)
    unit.level = level
    -- The live wrapper has already synchronized Strength-derived HP here.
    local data = env.Unit[unit]
    data.bonus_hp = data.bonus_hp
end
local tuning = section('    local PRECHAOS_HEALTH =', '    ---@class Boss')
local creation = section('        function Boss.create(', '        ---@param hero_level')
local revive = section('        function thistype:revive()', '\n    end\n\n    ---@type fun(pt: PlayerTimer)')
local regen = section('                    if CHAOS_MODE then\n                        hp = hp * (0.01', '\n                    if numplayers == 0')
local run_regen = assert(load(tuning .. creation .. revive .. '\nreturn function()\n' .. regen .. '\nend',
    'boss tuning, creation, respawn, and regen', 't', env))()
local main = {'O002', 'H045', 'U00G', 'H01V', 'H02H', 'O01B', 'H040', 'H020', 'H04Q', 'E00B', 'E00D', 'E00C', 'H00O'}
local early = {'n02H', 'n03L', 'n02U', 'n0pb'}
local function check(id, armor, hp_multiplier, expected_armor)
    template.armor = armor
    local unit = env.Boss.create(1, 0, 0, 0, id, id, 100, 0, 2000)
    assert(env.Unit[unit].hp == template.hp * hp_multiplier, id .. ' HP')
    assert(math.abs(unit.armor - expected_armor) < 1e-8, id .. ' armor')
    if hp_multiplier > 1 then assert(unit.life == env.Unit[unit].hp) end
    -- The bonus survives later derived-health recalculations.
    env.Unit[unit].bonus_hp = env.Unit[unit].bonus_hp
    assert(env.Unit[unit].hp == template.hp * hp_multiplier)
    env.Boss[1]:revive()
    local respawn = env.Boss[1].unit
    assert(respawn ~= unit and env.Unit[respawn].hp == env.Unit[unit].hp)
    assert(math.abs(respawn.armor - expected_armor) < 1e-8)
end
for _, id in ipairs(main) do check(id, 500, 2, 250) end
for _, id in ipairs(early) do check(id, 140, 1.5, 140) end
check('H02H', 1761.53, 2, 350)
check('H045', 300, 2, 300)
check('H045', 300.01, 2, 150.005)
for _, id in ipairs({'N038', 'H04R', 'n002', 'unknown'}) do check(id, 2000, 1, 2000) end
-- Run the production in-combat regen branch, including the original max-HP
-- relationship, to catch accidental doubling of absolute healing.
env.CHAOS_MODE = false
env.boss, env.hp = {id = 'H045', nearby_count = 2}, 1
run_regen()
assert(math.abs(env.hp * 200000 * .01 - .2 * 2 * 100000 * .01) < 1e-8)
print('PASS: 17 prechaos bosses, derived HP retention, armor boundaries/cap, initial spawn/respawn parity, unchanged Chaos/other types, and unchanged absolute combat regen.')
