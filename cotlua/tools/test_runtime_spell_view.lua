-- Offline frame/native mocks, not an in-game tooltip or texture rendering test.
local env = setmetatable({}, {__index = _G})
env._G = env
local _ENV = env
OnInit = {global = function(_, fn) fn(function() end) end,
    final = function(name, fn) if type(name) == 'string' then fn(function() end) end end}
local function load_source(path)
    local file = assert(io.open(path, 'rb')); local source = file:read('*a'); file:close()
    assert(load(source, path, 't', env))()
end
FourCC = function(id) return id end
DETECT_LEAVE_ABILITY, ORIGIN_FRAME_COMMAND_BUTTON = 'leave', 'command'
FRAMEPOINT_BOTTOMRIGHT, ALLIANCE_SHARED_CONTROL = 0, 0
ABILITY_SLF_ICON_NORMAL, ABILITY_SLF_TOOLTIP_NORMAL, ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED = 'icon', 'name', 'text'
ABILITY_RLF_CAST_RANGE, ABILITY_RLF_AREA_OF_EFFECT = 'range', 'area'
local function frame() return {visible = false} end
BlzFrameIsVisible = function(f) return f.visible end
BlzFrameSetVisible = function(f, value) f.visible = value end
BlzFrameSetText = function(f, text) f.text = text end
BlzFrameSetTexture = function(f, texture) f.texture = texture end
BlzFrameSetValue = function(f, value) f.value = value end
BlzGetOriginFrame = function() return frame() end
GetUnitTypeId = function(u) return u and u.id or 0 end
IsHeroUnitId = function() return false end
GetLocalPlayer = function() return 0 end
GetOwningPlayer = function(u) return u.owner or 12 end
GetPlayerController, GetHandleId = function() return 2 end, function(id) return id end
IsUnitOwnedByPlayer, GetPlayerAlliance = function() return false end, function() return false end
IsUnitAlly, IsUnitEnemy = function() return false end, function() return true end
local selected, native_calls = nil, 0
GroupEnumUnitsSelected = function(g) g.unit = selected end
FirstOfGroup, GroupClear = function(g) return g.unit end, function(g) g.unit = nil end
local native = {id = 123, cooldown = 5, remaining = 2}
local function native_only(unit, skill)
    assert(skill == native.id, 'Runtime skill reached a native ability API')
    native_calls = native_calls + 1
    return native
end
BlzGetAbilityPosX, BlzGetAbilityPosY = function() return 0 end, function() return 0 end
BlzGetUnitAbility, GetUnitAbilityLevel = native_only, function(u, s) native_only(u, s); return 1 end
BlzGetUnitAbilityManaCost = function(u, s) native_only(u, s); return 10 end
BlzGetUnitAbilityCooldown = function(u, s) native_only(u, s); return 5 end
BlzGetUnitAbilityCooldownRemaining = function(u, s) native_only(u, s); return 2 end
BlzGetAbilityStringLevelField = function(_, field)
    return ({icon = 'native-icon', name = 'Native Skill', text = 'Native description'})[field]
end
BlzGetAbilityRealLevelField = function() return 100 end
BlzGetUnitAbilityByIndex = function() return nil end
GetPlayerTechCount = function() return 1 end
R2I = math.floor
-- Use the real Spell:create path, including evaluation of function-valued
-- fields. Resurrection's restore formula exposed a definition being formatted
-- directly as if it were a numeric spell instance.
local spell_file = assert(io.open('cotlua/src/gameplay/abilities/spells.lua', 'rb'))
local spell_source = spell_file:read('*a'):gsub('\r\n', '\n'); spell_file:close()
local first = assert(spell_source:find('        function thistype:create(u)', 1, true))
local last = assert(spell_source:find('        local mt = {', first, true))
GetPlayerId = function(player) return player end
local create_spell = assert(load('local thistype, mts = {}, {}\n' .. spell_source:sub(first, last - 1) ..
    '\nreturn thistype.create', 'real spell creation', 't', env))()
local definition = {id = 123, create = create_spell,
    values = {restore = function(_, u) return 40 + 20 * GetUnitAbilityLevel(u, 123) end}}
definition.getTooltip = function(self, u, level)
    assert(self.caster == u and self.pid == GetOwningPlayer(u) + 1 and self.ablev == level,
        'Spell View rendered a definition instead of the selected unit instance')
    assert(type(self.restore) == 'number' and self.restore == 60, 'Restore formula was not evaluated')
    return 'Native parsed tooltip'
end
Spells = {[123] = definition}
load_source('cotlua/src/gameplay/abilities/runtime_spells.lua')
load_source('cotlua/src/ui/hud/spell_view.lua')
local ui = TasSpellView
ui.Group, ui.Parent, ui.ParentSimple = {}, frame(), frame()
for index = 0, 11 do
    ui.Data[index] = {}
    ui.Frame[index] = {Icon = frame(), Button = frame(), Cooldown = frame(), OverLayFrame = frame(),
        TextCool = frame(), ChargeBoxText = frame(), SimpleTooltip = frame()}
end
for _, name in ipairs({'Icon', 'Name', 'Text', 'TextMana', 'TextCool', 'TextRange', 'TextArea', 'Frame'}) do
    ui.Frame.Tooltip[name] = frame()
end
local unit, other = {id = 100}, {id = 100}
local context = {remaining = 4, text = 'First description'}
RuntimeSpells.define('test.slam', {name = 'Runtime Slam', icon = 'runtime-icon', cooldown = 8, position = 0,
    description = function(_, state) return state.text end,
    remaining = function(_, state) return state.remaining end})
RuntimeSpells.define('test.passive', {name = 'Runtime Passive', icon = 'passive-icon', description = 'Passive', passive = true, position = 0})
assert(not pcall(RuntimeSpells.define, 'test.slam', {}), 'Duplicate key accepted')
assert(not pcall(RuntimeSpells.bind, unit, {'missing'}), 'Unknown key accepted')
local keys = {'test.slam', 'test.passive'}
RuntimeSpells.bind(unit, keys, context); keys[1] = 'missing'
ui.UnitSkills[100] = {native.id}
selected = unit
ui.Update()
assert(native_calls == 0 and ui.Data[0].RuntimeKey == 'test.slam' and ui.Data[1].RuntimeKey == 'test.passive')
assert(ui.Frame[0].TextCool.text == '4.0' and ui.Frame[0].Cooldown.value == 50)
assert(ui.Frame[1].ChargeBoxText.text == '')
ui.Frame[0].SimpleTooltip.visible = true; ui.Update()
assert(ui.Frame.Tooltip.Name.text == 'Runtime Slam' and ui.Frame.Tooltip.Text.text == 'First description')
context.text, context.remaining = 'Updated description', 0
ui.Update()
assert(ui.Frame.Tooltip.Text.text == 'Updated description' and not ui.Frame[0].Cooldown.visible)
assert(native_calls == 0, 'Runtime cooldown of zero incorrectly fell back to a native API')
-- Rebinding the selected handle must refresh even without selecting another unit.
RuntimeSpells.bind(unit, {'test.passive'}, context); ui.Update()
assert(ui.Data[0].RuntimeKey == 'test.passive' and not ui.Data[1].Used)
selected = other; ui.Update()
assert(not ui.Data[0].RuntimeKey and ui.Data[0].Name == 'Native Skill' and native_calls > 0)
ui.Frame[0].SimpleTooltip.visible = true; ui.Update()
assert(ui.Frame.Tooltip.Text.text == 'Native parsed tooltip', 'Existing Spell tooltip route changed')
selected = unit; ui.Update()
RuntimeSpells.unbind(unit); ui.Update()
assert(not ui.Data[0].RuntimeKey and ui.Data[0].Name == 'Native Skill', 'Unbinding retained stale runtime UI')
selected = nil; ui.Update(); assert(not ui.Parent.visible)
print('PASS: per-handle runtime spells, no fake editor IDs/native ability calls, live cooldown/tooltip updates, slot conflicts, rebind/unbind, passive display, and existing native Spell View compatibility.')
