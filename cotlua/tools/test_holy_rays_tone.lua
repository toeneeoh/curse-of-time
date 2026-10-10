-- Offline regression for the actual Holy Rays and Tone of Death callbacks.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local function load_spell(path, first_marker, last_marker)
    local source = read(path)
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    assert(load(source:sub(first, last - 1), path, "t", sandbox))()
end
Spell = {define = function(id)
    return setmetatable({id = id, tag = id}, {__index = function(self, key)
        return self.values and self.values[key]
    end})
end}
local caster = {x = 0, y = 0, z = 50, ally = true}
Hero, BOOST, LBOOST = {[1] = caster}, {[1] = 1.5}, {[1] = 1}
-- This legacy fixture grants equal area/duration bonuses; independent scaling
-- is covered separately by test_spell_scaling.lua.
ABOOST, DBOOST = LBOOST, LBOOST
GetUnitAbilityLevel = function() return 2 end
GetHeroInt = function() return 100 end
Player = function(id) return id end
GetUnitX, GetUnitY, GetUnitZ = function(u) return u.x end, function(u) return u.y end, function(u) return u.z or 0 end
IsUnitAlly = function(u) return u.ally == true end
Condition = function(callback) return callback end
isalive = function(u) return not u.dead end
local units, queued, rays, hits, heals, destroyed_groups = {}, {}, {}, {}, {}, 0
local impacts = {}
TimerQueue = {callDelayed = function(_, delay, callback, ...)
    queued[#queued + 1] = {delay = delay, callback = callback, args = {...}}
end}
CreateGroup = function() return {} end
DestroyGroup = function(group)
    assert(not group.destroyed)
    group.destroyed = true
    destroyed_groups = destroyed_groups + 1
end
MakeGroupInRange = function(_, group, x, y, radius, filter)
    for _, unit in ipairs(units) do
        if (unit.x - x)^2 + (unit.y - y)^2 <= radius^2 and filter(unit) then
            group[#group + 1] = unit
        end
    end
end
each = function(group)
    local i = 0
    return function() i = i + 1; return group[i] end
end
AddLightningEx = function(id, visible, x, y, z, tx, ty, tz)
    assert(id == "YENL" and visible and x == 0 and y == 0 and z == 125)
    local ray = {x = tx, y = ty, z = tz}
    rays[#rays + 1] = ray
    return ray
end
DestroyLightning = function(ray) assert(not ray.destroyed); ray.destroyed = true end
AddSpecialEffectTarget = function(path, target, attachment)
    assert(path == "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl" and attachment == "origin")
    local effect = {target = target}
    impacts[#impacts + 1] = effect
    return effect
end
DestroyEffect = function(effect) effect.destroyed = true end
Dummy = {create = function() error("Holy Rays still depends on native dummy attacks") end}
ATTACK_TYPE_NORMAL, MAGIC = "normal", "magic"
DamageTarget = function(source, target, amount, attack, damage_type, tag)
    assert(source == caster and attack == "normal" and damage_type == "magic")
    hits[#hits + 1] = {target = target, amount = amount, tag = tag}
end
HP = function(source, target, amount, tag)
    assert(source == caster and target.ally)
    heals[#heals + 1] = {target = target, amount = amount, tag = tag}
end
RESURRECTION = {id = "resurrection"}
local resurrection_cd
BlzGetUnitAbilityCooldownRemaining = function() return 30 end
BlzStartUnitAbilityCooldown = function(source, id, cooldown)
    assert(source == caster and id == RESURRECTION.id)
    resurrection_cd = cooldown
end
OnInit = {final = function(_, callback) callback(function() end) end}
assert(load(read('cotlua/src/gameplay/abilities/tools.lua'), 'SpellTools', 't', sandbox))()
load_spell("cotlua/src/content/abilities/heroes/high_priestess.lua", "    ---@class HOLYRAYS", "    ---@class PROTECTION")
local function cast(definition)
    local instance = {pid = 1, caster = caster, x = 0, y = 0, angle = 0}
    for key, value in pairs(definition.values) do
        instance[key] = type(value) == "function" and value(1) or value
    end
    setmetatable(instance, {__index = definition})
    instance:onCast()
end
local ally = {x = 100, y = 0, ally = true}
local enemy = {x = 600, y = 0}
local outside = {x = 601, y = 0}
local dead = {x = 100, y = 0, dead = true}
units = {ally, enemy, outside, dead}
cast(HOLYRAYS)
assert(#hits == 1 and hits[1].target == enemy and hits[1].amount == 600)
assert(#heals == 1 and heals[1].amount == 150)
assert(#rays == 2 and #queued == 2 and destroyed_groups == 1 and resurrection_cd == 28)
assert(#impacts == 2 and impacts[1].target == ally and impacts[2].target == enemy)
for _, effect in ipairs(impacts) do assert(effect.destroyed) end
for _, entry in ipairs(queued) do
    assert(entry.delay == 1)
    entry.callback(table.unpack(entry.args))
end
for _, ray in ipairs(rays) do assert(ray.destroyed) end
LBOOST[1], hits, heals, queued, rays = 2, {}, {}, {}, {}
units = {{x = 1200, y = 0}, {x = 1201, y = 0}}
cast(HOLYRAYS)
assert(#hits == 1 and #rays == 1 and destroyed_groups == 2, "Holy Rays range boost is incorrect")
print("PASS: Holy Rays heals allies, damages enemies directly, obeys range, and cleans up rays/groups.")

FPS_32 = 1 / 32
CAT_MoveAutoHeight, CAT_Orient2D, CAT_Decay = {}, {}, {}
valid_damage_target = function(u) return not u.ally and not u.dead end
valid_pull_target = function(u) return valid_damage_target(u) and not u.hero end
IsTerrainWalkable = function() return true end
SetUnitXBounded = function(u, x) u.x = x; u.pulled = true end
SetUnitYBounded = function(u, y) u.y = y end
AddSpecialEffect = function() return {} end
BlzSetSpecialEffectScale = function() end
local missile, enumerations
ALICE_Create = function(object) missile = object end
ALICE_ForAllObjectsInRangeDo = function(callback, x, y, radius, category, filter, object)
    enumerations[#enumerations + 1] = {radius = radius, category = category}
    for _, unit in ipairs(units) do
        if (unit.x - x)^2 + (unit.y - y)^2 <= radius^2 and filter(unit, object) then
            callback(unit, object)
        end
    end
end
load_spell("cotlua/src/content/abilities/heroes/bard.lua", "    ---@class TONEOFDEATH", "end, Debug and Debug.getLine()")
for _, boost in ipairs({1, 2}) do
    LBOOST[1], queued, hits, enumerations = boost, {}, {}, {}
    local radius = 700 * boost
    local edge = {x = radius, y = 0}
    local out = {x = radius + 1, y = 0}
    local far = {x = radius + 400, y = 0}
    local friendly = {x = 50, y = 0, ally = true}
    local enemy_hero = {x = 100, y = 0, hero = true}
    units = {edge, out, far, friendly, enemy_hero}
    cast(TONEOFDEATH)
    assert(missile.aoe == radius and #queued == 2)
    local damage, pull = queued[1], queued[2]
    damage.callback(table.unpack(damage.args))
    pull.callback(table.unpack(pull.args))
    assert(#hits == 2 and hits[1].target == edge and hits[2].target == enemy_hero)
    assert(edge.pulled and not out.pulled and not far.pulled and not friendly.pulled and not enemy_hero.pulled)
    assert(#enumerations == 2 and enumerations[1].radius == radius and enumerations[2].radius == radius,
        "Tone of Death pull/damage ranges differ")
    local count = #queued
    missile.lifetime = 0
    damage.callback(table.unpack(damage.args))
    pull.callback(table.unpack(pull.args))
    assert(#queued == count, "Expired Tone of Death kept scheduling effects")
end
print("PASS: Tone of Death pull and damage both use 700 AoE, scale together, and stop on expiry.")

local mana_costs, registered, mana_updates = {}, nil, 0
local ability_level, maximum_mana = 1, 1000
GetUnitAbilityLevel = function() return ability_level end
BlzGetUnitMaxMana = function() return maximum_mana end
R2I = math.floor
BlzSetUnitAbilityManaCost = function(unit, id, level, cost)
    assert(unit == caster and id == TONEOFDEATH.id and level >= 0)
    mana_costs[level] = cost
    mana_updates = mana_updates + 1
end
EVENT_STAT_CHANGE = {register_unit_action = function(_, unit, callback)
    assert(unit == caster)
    if registered then assert(registered == callback, "Duplicate mana cost subscriber") end
    registered = callback
end}
TONEOFDEATH.onLearn(caster, ability_level, 1)
assert(mana_costs[0] == 200, "Learning did not initialize the mana cost")
for _, key in ipairs({"int", "bonus_int", "bonus_mana"}) do
    maximum_mana = maximum_mana + 1000
    registered(caster, key)
    assert(mana_costs[0] == maximum_mana * 0.2, "Mana cost did not follow " .. key)
end
maximum_mana = 5000
registered(caster)
assert(mana_costs[0] == 1000, "Level-up stat refresh did not update the cost")
ability_level = 2
TONEOFDEATH.onLearn(caster, ability_level, 1)
assert(mana_costs[1] == 1000, "New skill rank did not initialize the cost")
maximum_mana = 6000
TONEOFDEATH.onSetup(caster)
assert(mana_costs[1] == 1200, "Hero setup did not initialize the cost")
local previous_updates = mana_updates
registered(caster, "armor")
assert(mana_updates == previous_updates, "Unrelated stat change updated mana cost")
ability_level = 0
TONEOFDEATH.onSetup(caster)
assert(mana_updates == previous_updates, "Unlearned ability wrote an invalid level")
print("PASS: Tone of Death costs 20% max mana on learn/setup, skill rank changes, equipment changes, and level-up.")
