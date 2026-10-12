-- Offline execution of real spell callbacks; no Warcraft rendering claims.
local env = setmetatable({}, {__index = _G})
local _ENV = env
do
    local f = assert(io.open('cotlua/src/gameplay/abilities/spells.lua', 'rb'))
    local text = f:read('*a'):gsub('\r\n', '\n'); f:close()
    local first = assert(text:find('    function TagSpellDurationTooltip', 1, true))
    local last = assert(text:find('    -- Derive the note', first, true))
    assert(load(text:sub(first, last - 1), 'real duration tag rewrite', 't', env))()
end
local function source(name)
    local f = assert(io.open('cotlua/src/content/abilities/heroes/' .. name .. '.lua', 'rb'))
    local text = f:read('*a'):gsub('\r\n', '\n'); f:close(); return text
end
local function section(name, first, last, tail)
    local text = source(name)
    local a = assert(text:find(first, 1, true))
    local b = assert(text:find(last, a, true))
    return assert(load(text:sub(a, b - 1) .. (tail or ''), name, 't', env))()
end
Spell = {define = function(id) return setmetatable({id = id, tag = id},
    {__index = function(definition, key) return definition.values and definition.values[key] end}) end}
local queued, effects, ranges, damages, durations = {}, {}, {}, {}, {}
TQ = {callDelayed = function(_, delay, callback, ...)
    local entry = {delay = delay, callback = callback, args = {...}}
    queued[#queued + 1] = entry; return entry
end, disableCallback = function(_, entry) if entry then entry.cancelled = true end end}
TimerQueue = TQ
BOOST, ABOOST, DBOOST = {[1] = 1.5}, {[1] = 1.5}, {[1] = 1.4}
LBOOST = {[1] = 1.25}
FPS_32 = 1 / 32
ANIM_TYPE_BIRTH, ANIM_TYPE_DEATH, ANIM_TYPE_STAND = 1, 2, 3
ATTACK_TYPE_NORMAL, MAGIC = 1, 2
FilterEnemy, FilterAlly, isalive = function() end, function() end, function() end
Condition = function(f) return f end
local caster, enemy = {x = 0, y = 0}, {x = 100, y = 100}
Hero = {[1] = caster}
GetUnitX, GetUnitY = function(u) return u.x end, function(u) return u.y end
GetHeroInt, GetTerrainZ, GetLocZ = function() return 100 end, function() return 0 end, function() return 0 end
GetUnitAbilityLevel = function() return 1 end
UnitAddAbility, UnitRemoveAbility, SetUnitAbilityLevel = function() end, function() end, function() end
BlzUnitHideAbility, BlzSetUnitAbilityCooldown, BlzEndUnitAbilityCooldown = function() end, function() end, function() end
CreateGroup = function() return {} end
DestroyGroup = function(group) assert(not group.destroyed); group.destroyed = true end
MakeGroupInRange = function(_, group, _, _, radius)
    assert(not group.destroyed); ranges[#ranges + 1] = radius; group[1] = enemy
end
each = function(group) local i = 0; return function() i = i + 1; return group[i] end end
DamageTarget = function(_, _, damage) damages[#damages + 1] = damage end
AddSpecialEffect = function(path) local effect = {path = path}; effects[#effects + 1] = effect; return effect end
BlzSetSpecialEffectScale = function(effect, scale) effect.scale = scale end
BlzSetSpecialEffectZ, BlzPlaySpecialEffectWithTimeScale, BlzPlaySpecialEffect = function() end, function() end, function() end
BlzSetSpecialEffectTimeScale, BlzSetSpecialEffectAlpha = function() end, function() end
DestroyEffect, HideEffect = function() end, function() end
IsUnitInRangeXY = function() return true end
local function buff()
    return {add = function() return {duration = function(_, duration) durations[#durations + 1] = duration end} end}
end
ArcanosphereBuff, ArcanosphereDebuff, BloodLordBuff = buff(), buff(), buff()
local cleanup = {}
EVENT_ON_CLEANUP = {register_action = function(_, pid, callback) cleanup[pid] = callback end,
    unregister_action = function(_, pid) cleanup[pid] = nil end}
ARCANEBOLTS, ARCANEBARRAGE = {id = 'bolts'}, {id = 'barrage'}
section('arcanist', '    ---@class ARCANECOMETS', '    ---@class ARCANEBOLTS')
section('arcanist', '    ---@class ARCANOSPHERE', '    ---@class STASISFIELD')
local function sphere()
    local cast = setmetatable({pid = 1, caster = caster, targetX = 0, targetY = 0, dur = 12}, {__index = ARCANOSPHERE})
    cast:onCast(); return cast
end
local first = sphere()
assert(first.aoe == 1200 and first.sfx.scale == 15)
assert(ARCANOSPHERE.active[1] == first and cleanup[1])
local old_expiry = queued[#queued]
assert(old_expiry.delay == 12 * 1.4)
local comet = setmetatable({pid = 1, caster = caster, dmg = 100, aoe = 250, ablev = 1}, {__index = ARCANECOMETS})
comet:onCast()
assert(ranges[#ranges] == 1200)
local impact, next_wave
for _, entry in ipairs(queued) do
    if entry.delay == .6 then impact = entry end
    if entry.delay == .2 then next_wave = entry end
end
assert(impact.args[4] == 375)
impact.callback(table.unpack(impact.args))
assert(ranges[#ranges] == 375 and damages[#damages] == 150)
local second = sphere()
assert(first.expired and first.ug.destroyed and ARCANOSPHERE.active[1] == second)
old_expiry.callback(table.unpack(old_expiry.args))
assert(ARCANOSPHERE.active[1] == second and not second.expired and cleanup[1])
cleanup[1](1)
assert(second.expired and not ARCANOSPHERE.active[1] and not cleanup[1])
next_wave.callback(table.unpack(next_wave.args))
assert(comet.ug.destroyed)
print('PASS: sphere radius/art and comet damage/impact radius scale separately; expiry/recast/cleanup are idempotent.')

-- Real song membership checks: a target beyond 900 but inside 1350 receives it.
__jarray = function(default) return setmetatable({}, {__index = function() return default end}) end
SONG_WAR, SONG_HARMONY, SONG_PEACE, SONG_FATIGUE = 1, 2, 3, 4
IMPROV = {id = 'improv'}
TimerList = {[1] = {get = function() return nil end}}
GetOwningPlayer, Player = function() return 0 end, function(p) return p end
IsUnitAlly = function() return true end
enemy.x, enemy.y = 1050, 0
IsUnitInRange = function(target, origin, radius) return math.abs(target.x - origin.x) <= radius end
local applications = 0
SongOfWarBuff = {add = function() applications = applications + 1; return {duration = function() end} end}
local periodic, songs = section('bard', '    local BARD_SONG', '    local songeffect', '\nreturn song_periodic, BARD_SONG')
songs[1] = SONG_WAR
periodic({pid = 1, caster = caster, ug = {}})
assert(applications == 1 and ranges[#ranges] == 1350)
ABOOST[1] = 1
periodic({pid = 1, caster = caster, ug = {}})
assert(applications == 1)
ABOOST[1] = 1.5
print('PASS: song enumeration and membership use the same Area-scaled radius.')

-- Whirlpool's bonus duration is scaled before its existing per-enemy countdown.
InfusedWaterBuff = {get = function() return {dispel = function() end} end}
ALICE_ForAllObjectsInRangeDo = function() end
section('hydromancer', '    ---@class WHIRLPOOL', '    ---@class TIDALWAVE')
local whirlpool = setmetatable({pid = 1, caster = caster, targetX = 0, targetY = 0, dur = 4, aoe = 330}, {__index = WHIRLPOOL})
whirlpool:onCast()
assert(math.abs(whirlpool.dur - ((4 + 3) * 1.4 - FPS_32)) < 1e-9)
assert(math.abs(whirlpool.sfx.scale - .9) < 1e-9 and math.abs(whirlpool.sfx2.scale - .525) < 1e-9)
section('vampire', '    ---@class BLOODLORD', '\nend, Debug')
setmetatable({pid = 1, caster = caster, dur = 10}, {__index = BLOODLORD}):onCast()
assert(durations[#durations] == 14)
print('PASS: Whirlpool and Blood Lord lifetimes use Duration; Whirlpool art uses Area.')

Shield = {add = function(_, amount, lifetime) assert(amount == 25 and lifetime == 7) end}
BlzGetUnitMaxHP = function() return 100 end
section('crusader', '    ---@class AURAOFJUSTICE', '    ---@class DIVINERADIANCE')
setmetatable({pid = 1, caster = caster, x = 0, y = 0, pshield = 20, dur = 5}, {__index = AURAOFJUSTICE}):onCast()
assert(ranges[#ranges] == 1350)

-- Missile Strike uses its second native damage tag, with no object-data edits.
section('elite_marksman', '    HANDGRENADE = Spell.define', '\n    do\n        local thistype = HANDGRENADE')
local original = 'Normal [dmg=50% Attack Damage]. Missile Strike [dmg=100% Attack Damage].'
local rewritten = HANDGRENADE.tooltip_rewrite(original)
assert(rewritten == 'Normal [dmg=50% Attack Damage]. Missile Strike [dmg2=100% Attack Damage].')
assert(HANDGRENADE.tooltip_rewrite(original) == rewritten)

-- Real Railgun impact path: search range stays fixed; splash and bubble expand.
bj_PI = math.pi
ModuloReal = function(a, b) return a % b end
BlzSetSpecialEffectYaw, BlzSetSpecialEffectRoll = function() end, function() end
BlzGetLocalSpecialEffectZ = function() return 0 end
BlzGroupGetSize = function(group) return #group end
LightningAttackBeam, SetUnitScale, SetUnitAnimation = function() end, function() end, function() end
GetHeroAgi = function() return 10 end
local rail_periodic = section('thunderblade', '    RAILGUN = Spell.define', '        function thistype:onCast()', '\nreturn periodic\nend')
assert(rail_periodic({pid = 1, source = caster, target = caster, time = 0, dur = 0, angle = 0, ug = {}}) == false)
assert(ranges[#ranges] == 1200)
local bubble = effects[#effects]
assert(bubble.path:find('EMPBubble', 1, true) and bubble.scale == 12)
print('PASS: Justice active radius, Missile Strike tooltip tag, and Railgun impact radius/art agree with scaling.')

-- Approved finite durations; costs, cooldowns and fatal-save effects stay fixed.
local shield_lifetimes = {}
Shield.add = function(_, _, lifetime)
    shield_lifetimes[#shield_lifetimes + 1] = lifetime
    return {color = function() end}
end
AddSpecialEffectTarget = function() return {} end
BlzStartUnitAbilityCooldown, BlzGetUnitAbilityCooldownRemaining = function() end, function() return 10 end
RESURRECTION = {id = 'resurrection'}
ProtectionBuff = buff()
section('high_priestess', '    ---@class PROTECTION', '    ---@class RESURRECTION')
local protection = setmetatable({pid = 1, caster = caster, x = 0, y = 0, dur = 30, shield = 100, aoe = 650}, {__index = PROTECTION})
protection:onCast()
assert(shield_lifetimes[#shield_lifetimes] == 42 and durations[#durations] == 42)
assert(PROTECTION.tooltip_rewrite('30 second duration.\n60 second cooldown.') ==
    '>{dur=30] second duration.\n60 second cooldown.')

masterElement, ELEMENTEARTH = {[1] = 0}, {value = 4}
local shield_expire, removed_effects = nil, 0
EVENT_ON_SHIELD_EXPIRE = {register_unit_action = function(_, _, callback) shield_expire = callback end,
    unregister_unit_action = function() shield_expire = nil end}
GetPlayerId = function() return 0 end
Unit = {[caster] = {addEffect = function() return {} end,
    removeEffect = function() removed_effects = removed_effects + 1 end}}
section('elementalist', '    ---@class GAIAARMOR', '    ---@class FLAMEBREATH')
local gaia = setmetatable({pid = 1, caster = caster, dur = 30, shield = 100}, {__index = GAIAARMOR})
gaia:onCast()
assert(shield_lifetimes[#shield_lifetimes] == 42 and shield_expire)
shield_expire(caster)
assert(removed_effects == 1 and not GAIAARMOR.sfx[1] and not shield_expire)
masterElement[1] = ELEMENTEARTH.value
gaia:onCast()
assert(shield_lifetimes[#shield_lifetimes] == 42)
assert(GAIAARMOR.tooltip_rewrite('30 second duration.\n120 second cooldown.') ==
    '>{dur=30] second duration.\n120 second cooldown.')

local timer, spinning
TimerList[1].add = function()
    timer = {pid = 1, startLoop = function(self, interval, callback) self.interval, self.callback = interval, callback end}
    return timer
end
IssueImmediateOrderById = function() end
AddUnitAnimationProperties = function(_, _, enabled) spinning = enabled end
UnitAlive = function() return true end
section('thunderblade', '    ---@class BLADESTORM', '    ---@class OMNISLASH')
BLADESTORM.chance = 0 -- Isolate the fixed cadence from the independent proc.
local storm = setmetatable({pid = 1, caster = caster, dur = 3, dmg = 100, dot = 10}, {__index = BLADESTORM})
storm:onCast()
assert(math.abs(timer.dur - 12.6) < 1e-9 and timer.interval == .33 and spinning)
local ticks = 0
while timer.callback(timer) do ticks = ticks + 1; assert(ticks < 30) end
assert(ticks == 12 and not spinning)
assert(BLADESTORM.tooltip_rewrite('3 second duration.\n10 second cooldown.') ==
    '>{dur=3] second duration.\n10 second cooldown.')
assert(source('vampire'):find('pt.dur = 5.', 1, true), 'Blood Domain must retain its fixed lifetime')
print('PASS: Protection buff/shield share Duration; both Gaia variants scale and retain expiration cleanup; Bladestorm extends ticks without speeding them up; Blood Domain stays fixed.')

BloodFrenzyBuff = buff()
section('bloodzerker', '    ---@class BLOODFRENZY', '    ---@class BLOODLEAP')
setmetatable({pid = 1, caster = caster, dur = 5}, {__index = BLOODFRENZY}):onCast()
assert(durations[#durations] == 7)
assert(BLOODFRENZY.tooltip_rewrite('15% max health cost.\n5 second duration.\n5 second cooldown.') ==
    '15% max health cost.\n>{dur=5] second duration.\n5 second cooldown.')
DBOOST[1] = 1
setmetatable({pid = 1, caster = caster, dur = 5}, {__index = BLOODFRENZY}):onCast()
assert(durations[#durations] == 5)
print('PASS: Blood Frenzy duration scales and its tooltip tags only duration, not health cost or cooldown.')

-- Overload must initialize the native activation cost before the first cast,
-- and refresh the correct native ability level after level/stat changes.
local cost_writes, stat_change, level_change = {}, nil, nil
EVENT_STAT_CHANGE = {register_unit_action = function(_, _, callback) stat_change = callback end}
EVENT_ON_ORDER = {register_unit_action = function() end}
EVENT_HERO_LEVEL_CHANGED = {register_unit_action = function(_, _, callback) level_change = callback end}
OverloadBuff = {get = function() return nil end}
R2I = math.floor
caster.overload_level, caster.hero_level, caster.max_mana = 1, 150, 1075
GetHeroLevel = function(u) return u.hero_level end
GetUnitAbilityLevel = function(u) return u.overload_level end
SetUnitAbilityLevel = function(u, _, level) u.overload_level = level end
BlzGetUnitMaxMana = function(u) return u.max_mana end
BlzSetUnitAbilityManaCost = function(u, id, level, amount)
    assert(id == 'A096' and level == u.overload_level - 1 and level >= 0)
    cost_writes[#cost_writes + 1] = {level = level, amount = amount}
end
section('thunderblade', '    ---@class OVERLOAD', '    ---@class THUNDERDASH')
OVERLOAD.onSetup(caster)
assert(caster.overload_level == 3 and cost_writes[#cost_writes].amount == 21)
caster.max_mana = 2500
stat_change(caster, 'bonus_mana')
assert(cost_writes[#cost_writes].amount == 50)
level_change(caster, 225)
assert(cost_writes[#cost_writes].level == 3 and cost_writes[#cost_writes].amount == 50)
caster.max_mana = 3000
OVERLOAD.onLearn(caster, 4, 1)
assert(cost_writes[#cost_writes].amount == 60)
local count = #cost_writes
stat_change(caster, 'armor')
assert(#cost_writes == count)
caster.overload_level = 0
stat_change(caster, 'int')
assert(#cost_writes == count)
print('PASS: Overload starts at 2% maximum mana, follows stat/ability-level changes, and never writes a negative native level.')
