-- Native frame mocks: executes real UI callbacks without claiming WC3 rendering.
local env = setmetatable({}, {__index = _G})
local _ENV = env
OnInit = {global = function(_, f) f(function() end) end, final = function(_, f) f(function() end) end}
assert(loadfile('cotlua/src/gameplay/players/stat_allocation_model.lua', 't', env))()
local M = StatAllocationModel
local data, level = M.create(), 2
local local_player, sender, clicked, wire = 0, 0, nil, nil
local frames, sync, listeners = {}, nil, {}
local enable_calls = {}
local root = {}
INSPECT_HUD_ANCHOR = {}
for _, name in ipairs({'ORIGIN_FRAME_GAME_UI', 'FRAMEPOINT_TOPRIGHT', 'FRAMEPOINT_TOPLEFT',
    'FRAMEPOINT_BOTTOM', 'FRAMEPOINT_TOP', 'FRAMEPOINT_LEFT', 'FRAMEPOINT_RIGHT', 'FRAMEEVENT_CONTROL_CLICK'}) do env[name] = name end
Player, GetPlayerId = function(p) return p end, function(p) return p end
GetLocalPlayer, GetTriggerPlayer = function() return local_player end, function() return sender end
BlzGetTriggerFrame = function() return clicked end
BlzGetOriginFrame = function() return root end
local function frame(kind, parent)
    local f = {kind = kind, parent = parent, visible = true, enabled = true}
    frames[#frames + 1] = f; return f
end
BlzCreateFrame = function(kind, parent) return frame(kind, parent) end
BlzCreateFrameByType = function(kind, _, parent) return frame(kind, parent) end
BlzFrameSetAbsPoint = function(f, anchor, x, y) f.x, f.y, f.anchor = x, y, anchor end
BlzFrameSetPoint = function(f, _, _, _, x, y) f.x, f.y = x, y end
BlzFrameClearAllPoints = function() end
BlzFrameSetTexture = function(f, texture) f.texture = texture end
BlzFrameSetSize = function(f, width, height) f.width, f.height = width, height end
BlzFrameSetLevel = function() end
BlzFrameSetVisible = function(f, visible) assert(f); f.visible = visible end
BlzFrameSetEnable = function(f, enabled)
    assert(f); f.enabled = enabled; enable_calls[#enable_calls + 1] = {f, enabled}
end
BlzFrameSetText = function(f, value) assert(f); f.text = value end
BlzFrameGetText = function(f) return f.text end
FrameAddSimpleTooltip = function(_, _, text) return {frame = {}, tooltip = {text = text}} end
local context, named, icons = 0, {}, {}
NextFrameCreateContext = function() context = context + 1; return context end
BlzGetFrameByName = function(name, index)
    local key = name .. index
    named[key] = named[key] or {}; return named[key]
end
DestroyTrigger = function() end
Condition = function(f) return f end
CreateTrigger = function() return {} end
BlzTriggerRegisterFrameEvent = function(t, f) t.frame = f end
TriggerAddAction = function(t, f) t.frame.click = f end
TriggerAddCondition = function(t, f) t.callback = f end
BlzTriggerRegisterFrameEvent = function(t, f) t.frame = f; f.click = t.callback end
assert(loadfile('cotlua/src/framework/ui/simple_button.lua', 't', env))()
local create_icon = SimpleButton.create
SimpleButton.create = function(...)
    local icon = create_icon(...); icons[#icons + 1] = icon; return icon
end
local sound_handles, sounds, playing = 0, {}, {}
CreateSound = function(path) sound_handles = sound_handles + 1; return path end
StopSound = function() error('UI feedback must not force-stop a reusable sound') end
GetSoundIsPlaying = function(sound) return playing[sound] or false end
StartSound = function(sound)
    assert(not playing[sound], 'UI feedback restarted a playing sound')
    playing[sound] = true
    sounds[#sounds + 1] = sound
end
AddToEsc = function() end
SyncCallback = function(prefix, f) assert(prefix == 'stat_alloc'); sync = f end
BlzSendSyncData = function(prefix, payload) assert(prefix == 'stat_alloc'); wire = payload end
BlzGetTriggerSyncData = function() return wire end
local cleanup
EVENT_ON_CLEANUP = {register_action = function(_, _, f) cleanup = f end}
PLAYER_CAP = 1
Hero = {[1] = {}}
GetHeroLevel = function() return level end
Profile, HERO_STATS = {[1] = {hero = {unit_id = 1}}}, {[1] = {str = 10, agi = 10, int = 5}}
local perk = false
StatAllocation = {
    get = function() return data end, getGeneration = function() return 1 end,
    available = function() return data and M.available(level, data) or 0 end,
    hasAutomation = function() return perk end,
    canReset = function() return true end,
    resetCost = function() return level * 100 end,
    registerChangedAction = function(f) listeners[#listeners + 1] = f end,
    commit = function(_, generation, revision, counts)
        assert(generation == 1 and revision == data.revision)
        assert(#counts == 3)
        for i = 1, 3 do data.flat[i] = data.flat[i] + counts[i] end
        data.revision = data.revision + 1; return true
    end,
    setPlan = function(_, _, enabled, ratio) data.automatic = enabled; data.ratio = ratio; data.revision = data.revision + 1; return true end,
    reset = function()
        data.flat, data.ratio, data.automatic = {0, 0, 0}, {0, 0, 0}, 0
        data.revision = data.revision + 1; return true
    end,
}
DisplayTimedTextToPlayer = function() end
assert(loadfile('cotlua/src/ui/dialogs/stat_allocation.lua', 't', env))()
local UI = StatAllocationUI
local panel = frames[1]
local function find(label, width)
    for _, f in ipairs(frames) do if f.text == label and f.click and (not width or f.width == width) then return f end end
    error('Missing control ' .. label)
end
local function click(label, width)
    clicked = find(label, width); assert(clicked.enabled, 'Disabled ' .. label)
    enable_calls = {}; clicked.click()
    assert(enable_calls[1][1] == clicked and enable_calls[1][2] == false
        and enable_calls[2][1] == clicked and enable_calls[2][2] == true,
        'Button did not release keyboard focus on its trigger frame: ' .. label)
end
UI.open(1); assert(panel.visible)
local reminder_icon = icons[2]
local reminder = reminder_icon.frame
assert(reminder_icon.texture:find('BTNStatUp.blp', 1, true))
assert(icons[1].texture:find('BTNCancel.blp', 1, true), 'Close button does not use the standard icon')
assert(icons[1].frame.x == -.04 and icons[1].frame.y == -.04, 'Close button did not move inward by .02')
assert(panel.height == .27 and not find('Save Ratio').visible, 'Unowned automation section was not hidden and collapsed')
assert(reminder_icon.tooltip.tooltip.text:find('8 stat points remaining.', 1, true))
assert(reminder.visible and reminder.parent == INSPECT_HUD_ANCHOR and
    reminder.x == (.039 + .032) * .5 and reminder.y == .03, 'HUD reminder is not centered .03 above inspect buttons')
click('+5'); click('+', .03)
assert(#sounds == 1 and sound_handles == 3, 'Rapid draft clicks restarted audio or allocated local handles')
local click_sound = sounds[1]
UI.playClick(1); UI.playClick(1)
assert(#sounds == 1, 'Repeated clicks restarted an active sound')
playing[click_sound] = false -- Simulate native completion.
UI.playClick(1)
assert(#sounds == 2 and sounds[2] == click_sound, 'Completed feedback could not play again')
assert(data.flat[1] == 0 and wire == nil, 'Draft changed synchronized allocations')
click('Apply')
assert(wire == 'apply:1:0:5:0:0')
sync(); assert(data.flat[1] == 5)
assert(sounds[#sounds]:find('HeroSkillUp', 1, true), 'Apply did not play success feedback')
assert(reminder_icon.tooltip.tooltip.text:find('3 stat points remaining.', 1, true))
click('All'); click('+', .03); click('Apply'); sync()
assert(data.flat[1] == 8 and not reminder.visible, 'Spending the last point did not clear the reminder')
assert(not find('Enable Plan').enabled, 'Missing perk did not gate automatic mode')
perk = true; listeners[1](1)
assert(panel.height == .36 and find('Save Ratio').visible, 'Owned automation did not expand the window')
click('Enable Plan'); sync(); assert(data.automatic == 1)
UI.close(1); UI.open(1)
assert(find('Pause Plan').enabled)
-- No secondary pool or percentage controls; a point remains one stat at 500.
for _, f in ipairs(frames) do assert(f.text ~= 'Base Growth' and f.text ~= 'Stat Points' and f.text ~= 'Allocate Stats' and f.text ~= 'X') end
level = 500
listeners[1](1)
click('+1'); click('+', .03)
local scaled_preview = false
for _, f in ipairs(frames) do
    if f.text and f.text:find('Strength: 18', 1, true) and f.text:find('19', 1, true) then scaled_preview = true end
end
assert(scaled_preview, 'High-level preview did not preserve one stat per point')
click('Reset in Town'); assert(wire ~= 'reset:1:50000', 'Reset skipped cost confirmation')
click('Pay 50000 Gold'); assert(wire == 'reset:1:50000', 'Confirmed reset did not send its quoted price')
sync()
local zero_fields = 0
for _, f in ipairs(frames) do
    if f.kind == 'EscMenuEditBoxTemplate' then
        assert(f.visible and f.text == '0', 'Reset did not visibly clear a ratio field')
        zero_fields = zero_fields + 1
    end
    assert(not f.text or not f.text:find('allocation plan', 1, true), 'Reset still mentions an allocation plan')
end
assert(zero_fields == 3)
-- Icon callbacks go through the real SimpleButton focus-release wrapper.
clicked = icons[1].frame; enable_calls = {}; clicked.click()
assert(not panel.visible and enable_calls[1][1] == clicked and enable_calls[1][2] == false
    and enable_calls[2][1] == clicked and enable_calls[2][2] == true)
clicked = reminder; enable_calls = {}; clicked.click()
assert(panel.visible and enable_calls[1][1] == clicked and enable_calls[1][2] == false
    and enable_calls[2][1] == clicked and enable_calls[2][2] == true)
-- Exercise the actual Stats shortcut, including the shared focus handler.
local stat_file = assert(io.open('cotlua/src/ui/hud/stat_view.lua', 'rb'))
local stat_source = stat_file:read('*a'); stat_file:close()
local stat_first = assert(stat_source:find('    -- Fits the existing tab strip', 1, true))
local stat_last = assert(stat_source:find('    local function ViewPlayersClick()', stat_first, true))
env.frame = panel
assert(load(stat_source:sub(stat_first, stat_last - 1), 'real Stats shortcut', 't', env))()
local shortcut = icons[3]
assert(shortcut.texture:find('BTNStatUp.blp', 1, true))
clicked = shortcut.frame; enable_calls = {}; clicked.click()
assert(enable_calls[1][1] == clicked and enable_calls[1][2] == false
    and enable_calls[2][1] == clicked and enable_calls[2][2] == true)
perk = false; listeners[1](1)
assert(panel.height == .27 and not find('Save Ratio').visible and not find('Enable Plan').visible,
    'Removing the perk left automation controls visible')
local sound_count = #sounds
wire = nil; local_player = 1
clicked = find('Save Ratio'); clicked.click()
assert(wire == nil, 'Remote frame event sent an allocation request')
assert(#sounds == sound_count, 'Remote frame event played local feedback')
UI.open(1); assert(panel.visible, 'Remote open changed local frame visibility')
local_player = 0
UI.close(1)
data = nil
UI.previewTutorial(1, true); assert(panel.visible)
wire = nil
clicked = find('Save Ratio'); clicked.click()
assert(wire == nil, 'Tutorial preview sent a gameplay request')
UI.previewTutorial(1, false); assert(not panel.visible)
assert(sound_handles == 3, 'UI interactions allocated new sound handles')
cleanup()
print('PASS (mocked frames): bulk drafts, sync boundary, HUD count clearing, remote isolation, plan gating and no-hero tutorial preview.')
