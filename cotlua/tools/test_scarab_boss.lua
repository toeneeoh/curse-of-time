-- Offline tests of the actual encounter module, not proof of native rendering.
local env = setmetatable({}, {__index = _G})
env._G = env
local _ENV = env
OnInit = {global = function(_, fn) fn(function() end) end, final = function(_, fn) fn(function() end) end}
local units, effects, timers, cleanup, attacks, hits = {}, {}, {}, {}, {}, {}
local views, restores, crawl_leaves = {}, {}, 0
PLAYER_CAP, PLAYER_CREEP, ABIL_AVUL = 6, 12, 'invulnerable'
ARMOR_CHAOS, ATTACK_CHAOS, ATTACK_TYPE_NORMAL, MAGIC = 0, 0, 0, 0
ANIM_TYPE_STAND, ANIM_TYPE_WALK, ANIM_TYPE_SPELL = 'stand', 'walk', 'spell'
ANIM_TYPE_DEATH, ANIM_TYPE_ATTACK = 'death', 'attack'
SUBANIM_TYPE_SLAM, SUBANIM_TYPE_THROW, SUBANIM_TYPE_CHANNEL = 'slam', 'throw', 'channel'
ORDER_ID_ATTACK, ORDER_ID_SMART = 1, 2
SetUnitCreepGuard, RemoveGuardPosition = function() end, function() end
IsUnitVisible, GetOwningPlayer = function(u) return not u.hidden end, function() return PLAYER_CREEP end
FourCC = function(id) return id end
Player = function(id) return id end
Hero, Backpack, REGION_DATA = {}, {}, {}
for pid = 1, 6 do Hero[pid] = {x = 100 * pid, y = 200, alive = true, abilities = {}} end
Backpack[1] = {x = 100, y = 200}
UnitAlive = function(u) return u and u.alive and not u.removed end
GetUnitX, GetUnitY = function(u) return u.x end, function(u) return u.y end
GetUnitFacing = function(u) return u.facing end
GetTerrainZ = function() return 0 end
GetUnitCurrentOrder = function(u) return u.order or 0 end
GetUnitAbilityLevel = function(u, id) return u.abilities[id] and 1 or 0 end
UnitAddAbility = function(u, id) u.abilities[id] = true end
UnitRemoveAbility = function(u, id) u.abilities[id] = nil end
SetUnitXBounded, SetUnitYBounded = function(u, x) u.x = x end, function(u, y) u.y = y end
MoveHero = function(pid, x, y) Hero[pid].x, Hero[pid].y = x, y end
SetWidgetLife = function(u, life) u.life = life end
BlzGetUnitMaxHP = function(u) return u.max_hp end
BlzGetUnitBaseDamage = function() return 1 end
BlzCreateUnitWithSkin = function(_, id, x, y, facing, skin)
    local u = {x = x, y = y, facing = facing, alive = true, abilities = {}, max_hp = 100, id = id, skin = skin}
    units[#units + 1] = u
    return u
end
CreateUnit = function(owner, id, x, y, facing)
    return BlzCreateUnitWithSkin(owner, id, x, y, facing, id)
end
SetUnitAnimation = function(u, animation) u.animation = animation; u.anim_calls = (u.anim_calls or 0) + 1 end
ResetUnitAnimation = function(u) u.animation = 'native' end
Unit = setmetatable({}, {__index = function(self, u)
    local data = setmetatable({}, {__index = {bonus_hp = 0, unit = u}, __newindex = function(t, key, value)
        rawset(t, key, value)
        if key == 'bonus_hp' then u.max_hp = 100 + value end
    end})
    rawset(self, u, data); return data
end})
PauseUnit = function(u, paused) u.paused = paused end
BlzSetUnitFacingEx = function(u, angle) u.facing = angle end
IssueImmediateOrder = function(u) u.order, u.target = 0, nil end
IssueTargetOrder = function(u, _, target) u.order, u.target = 1, target end
RemoveUnit = function(u) assert(not u.removed); u.removed, u.alive = true, false end
SetUnitVertexColor = function() end
BlzSetUnitIntegerField, BlzSetUnitWeaponIntegerField = function() end, function() end
UNIT_RF_ACQUISITION_RANGE, UNIT_WEAPON_RF_ATTACK_RANGE = 'acquisition', 'range'
BlzSetUnitRealField = function(_, field) assert(field == 'acquisition', 'Invalid unit real field') end
BlzSetUnitWeaponRealField = function(_, field) assert(field == 'range', 'Invalid weapon real field') end
BlzSetUnitArmor, BlzSetUnitName = function() end, function() end
Rect = function(a, b, c, d) return {a, b, c, d} end
RemoveRect = function(rect) rect.removed = true end
GetRectMinX, GetRectMinY = function(r) return r[1] end, function(r) return r[2] end
GetRectMaxX, GetRectMaxY = function(r) return r[3] end, function(r) return r[4] end
GetRectCenterX, GetRectCenterY = function(r) return (r[1]+r[3])/2 end, function(r) return (r[2]+r[4])/2 end
PreviewPlayerCamera = function(pid, rect, _, _, instant)
    assert(instant and REGION_DATA[rect].hide_minimap); views[pid] = rect
end
RestorePlayerCameraPreview = function(pid) views[pid] = nil; restores[pid] = (restores[pid] or 0) + 1 end
ScarabCrawl = {leave = function() crawl_leaves = crawl_leaves + 1 end}
Buff = {dispelAll = function(u, override) assert(override); u.dispelled = true end}
DisplayTimedTextToPlayer = function() end
AddSpecialEffect = function(path, x, y)
    local effect = {path = path, x = x, y = y}
    effects[#effects + 1] = effect; return effect
end
AddSpecialEffectTarget = function(path, unit, attach)
    assert(attach == 'origin', 'Boss model must be attached to native movement')
    local effect = AddSpecialEffect(path, unit.x, unit.y)
    effect.unit = unit
    return effect
end
DestroyEffect = function(e) assert(not e.destroyed); e.destroyed = true end
BlzSetSpecialEffectAlpha = function(e, alpha) e.alpha = alpha end
BlzSetSpecialEffectPosition = function() error('Attached boss model must not need a position-following loop') end
BlzSetSpecialEffectYaw = function(e, angle) e.angle = angle end
BlzSetSpecialEffectScale, BlzSetSpecialEffectColor = function() end, function() end
BlzPlaySpecialEffect = function(e, anim) e.anim = anim; e.anim_calls = (e.anim_calls or 0) + 1 end
BlzSpecialEffectClearSubAnimations = function(e) e.sub_anim = nil end
BlzSpecialEffectAddSubAnimation = function(e, sub) e.sub_anim = sub end
DamageTarget = function(_, hero, damage) hits[#hits + 1] = {hero, damage} end
EVENT_ON_CLEANUP = {register_action = function(_, pid, callback) cleanup[pid] = callback end}
EVENT_ON_ATTACK = {register_unit_action = function(_, u, callback) attacks[u] = callback end,
    unregister_unit_action = function(_, u, callback) assert(attacks[u] == callback); attacks[u] = nil end}
TimerQueue = {callPeriodically = function(_, period, stop, callback, ...)
    timers[#timers + 1] = {period = period, stop = stop, callback = callback, args = {...}}
end}
local function tick(count)
    for _ = 1, count do
        for _, timer in ipairs(timers) do
            if not timer.stopped then
                timer.callback(table.unpack(timer.args))
                timer.stopped = timer.stop()
            end
        end
    end
end
local file = assert(io.open('cotlua/src/gameplay/abilities/runtime_spells.lua', 'rb'))
local source = file:read('*a'); file:close(); assert(load(source, 'runtime_spells', 't', env))()
file = assert(io.open('cotlua/src/gameplay/dungeons/scarab/boss.lua', 'rb'))
source = file:read('*a'); file:close(); assert(load(source, 'scarab_boss', 't', env))()
file = assert(io.open('cotlua/src/gameplay/dungeons/scarab/combat.lua', 'rb'))
source = file:read('*a'); file:close(); assert(load(source, 'scarab_combat', 't', env))()
assert(#units == 0 and #effects == 0 and #timers == 0, 'Startup must not create the encounter')
assert(not ScarabBoss.enter(1), 'Missing arena must be rejected without side effects')
gg_rct_Scarab_Boss_Arena = Rect(-19936, 25920, -16032, 30688)
assert(not ScarabBoss.enter(0))
assert(ScarabBoss.inCone(999, 0, 0, 0, 0))
assert(not ScarabBoss.inCone(1001, 0, 0, 0, 0))
assert(not ScarabBoss.inCone(-1, 0, 0, 0, 0))
assert(ScarabBoss.inCone(500, 500, 0, 0, 0))
assert(not ScarabBoss.inCone(100, 500, 0, 0, 0))
assert(ScarabBoss.enter(1) and ScarabBoss.enter(2))
assert(#units == 1 and crawl_leaves == 2 and not ScarabBoss.enter(1))
local boss = units[1]
assert(boss.id == 'U000' and #effects == 0, 'Boss must use its actual object, without a proxy model')
assert(boss.max_hp == ScarabBoss.spec.health and boss.max_hp < 2147483647)
assert(boss.abilities[ABIL_AVUL] and boss.paused and ScarabBoss.status():find('staged'))
assert(views[1][1] == -19936 + 850 and views[1][4] == 30688 - 850)
assert(#timers == 1 and timers[1].period == .1)
assert(#RuntimeSpells.get(boss).keys == 2 and not RuntimeSpells.get(Hero[1]))
assert(ScarabBoss.previewAnimation(1, 'channel') and boss.animation == 'stand channel')
assert(ScarabBoss.previewAnimation(1, 'slam') and boss.animation == 'spell slam')
assert(ScarabBoss.previewAnimation(1, 'spell') and boss.animation == 'spell')
-- Native orders own movement/attack animation, not a polling controller.
tick(31)
local origin_x, origin_y, before_anims = boss.x, boss.y, boss.anim_calls
for _ = 1, 32 do boss.x = boss.x + 2; tick(1) end
assert(boss.anim_calls == before_anims, 'Polling must not override native movement animations')
boss.x, boss.y = origin_x, origin_y
tick(1)
assert(ScarabBoss.fight(1) and not ScarabBoss.fight(1))
assert(RuntimeSpells.view(boss, 'scarab.frontal_slam').Remaining == 8)
assert(boss.animation == 'native' and not attacks[boss])
assert(not boss.abilities[ABIL_AVUL] and Unit[boss].dr == .8)
local saved_health = boss.max_hp * .75
boss.life = saved_health
assert(ScarabBoss.leave(2)); tick(1)
assert(Unit[boss].dr == .8 and boss.life == saved_health, 'Scaling must neither shrink nor heal mid-pull')
Hero[1].x, Hero[1].y = boss.x + 500, boss.y
tick(80)
assert(boss.paused, 'Sting should pause movement during its warning')
assert(boss.animation == 'spell slam', 'Frontal area attack must use Spell Slam')
-- Move behind the boss after the warning; the cone must not follow the hero.
Hero[1].x = boss.x - 500
tick(15)
assert(#hits == 0 and not boss.paused, 'Dodge or pause cleanup failed')
Hero[1].x = boss.x + 500
tick(65); tick(17)
assert(#hits == 1 and hits[1][2] == ScarabBoss.spec.sting_damage)
tick(100)
assert(#units >= 7, 'Brood discharge did not spawn its first wave')
assert(units[2].abilities.Aeth, 'Brood must use visible ghost phasing')
units[2].order = 0; tick(6)
assert(units[2].order == ORDER_ID_ATTACK, 'Idle brood lost pursuit')
for _ = 1, 4 do tick(240) end
local living_brood = 0
for _, u in ipairs(units) do if u ~= boss and UnitAlive(u) then living_brood = living_brood + 1 end end
assert(living_brood == ScarabBoss.spec.brood_cap, 'Brood must remain capped')
Hero[1].alive = false; tick(52)
assert(ScarabBoss.status():find('staged') and boss.life == boss.max_hp and boss.abilities[ABIL_AVUL])
assert(not views[1] and Unit[boss].dr == .9, 'Wipe must restore view and reset scaling')
for _, u in ipairs(units) do if u ~= boss then assert(u.removed) end end
Hero[1].alive = true; Hero[1].x, Hero[1].y = 100, 200
assert(ScarabBoss.enter(1) and ScarabBoss.fight(1))
tick(81)
ScarabBoss.stop(); tick(1)
assert(boss.removed and not attacks[boss] and not views[1])
assert(not RuntimeSpells.get(boss), 'Removed boss retained runtime spells')
assert(Hero[1].x == 100 and Backpack[1].x == 100 and next(REGION_DATA) == nil)
for _, e in ipairs(effects) do assert(e.destroyed) end
-- Defeat cannot respawn or reward; re-entry is blocked until explicit cleanup.
assert(ScarabBoss.enter(1)); boss = units[#units]
assert(ScarabBoss.fight(1)); boss.alive = false; tick(1)
assert(ScarabBoss.status():find('defeated') and not ScarabBoss.enter(2))
local before = #units; tick(100); assert(#units == before)
Hero[1].x = -15000; tick(1)
assert(not views[1], 'Leaving after a defeat must still restore the camera')
cleanup[1](1); ScarabBoss.stop(); tick(1)
print('PASS: Scarab startup guards, staged entry, instant camera, fixed sting cone, dodge/damage, capped brood, high-water scaling, wipe/reset, defeat, and cleanup.')
