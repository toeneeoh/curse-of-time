-- Host Lua only: real frame construction on a mocked parent/level graph.
-- This checks sibling ordering, not Warcraft rendering or mouse hit-testing.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local text = file:read('*a'):gsub('\r\n', '\n')
    file:close()
    return text
end
local source = read('ui/hud/multiboard.lua')
local function section(first, last)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(last, start + #first, true))
    return source:sub(start, finish - 1)
end
local env = setmetatable({}, {__index = _G})
env.Debug = nil
local console, frames = {}, {}
local function frame(kind, parent)
    local result = {kind = kind, parent = parent, level = 0, visible = true}
    frames[#frames + 1] = result
    return result
end
env.BlzGetFrameByName = function(name) assert(name == 'ConsoleUIBackdrop'); return console end
env.BlzCreateFrameByType = function(kind, _, parent) return frame(kind, parent) end
env.BlzCreateFrame = function(kind, parent) return frame(kind, parent) end
env.BlzFrameSetLevel = function(f, level) f.level = level end
env.BlzFrameSetVisible = function(f, visible) f.visible = visible end
env.BlzFrameSetText = function(f, text) f.text = text end
env.BlzFrameSetEnable = function(f, enable) f.enabled = enable end
env.BlzFrameSetSize = function(f, width, height) f.width, f.height = width, height end
env.BlzFrameSetTexture, env.BlzFrameSetPoint, env.BlzFrameSetAbsPoint,
    env.BlzFrameClearAllPoints, env.BlzFrameSetTextAlignment,
    env.BlzFrameSetScale, env.BlzFrameSetFont = function() end, function() end,
    function() end, function() end, function() end, function() end, function() end
env.MB = {}
env.ROW_WIDTH, env.ROW_HEIGHT, env.ICON_SIZE = .3, .035, .011
assert(load(section('        MB.frame = BlzCreateFrameByType', '        MB.name ='),
    'real multiboard parent construction', 't', env))()
local boss = {frame = frame('boss body', env.MB.main), viewing = {}}
local drop_toggle = {frame = frame('drop toggle', boss.frame)}
drop_toggle.icon = function() end
drop_toggle.enable = function(self, enable) self.frame.enabled = enable end
local anchor = setmetatable({}, {__index = {gluebutton = drop_toggle}, __newindex = function() end})
boss.addRows, boss.get_anchor = function() end, function() return anchor end
env.boss = boss
local buttons = {}
env.Button = {create = function(parent)
    local button = {iconFrame = frame('drop icon', parent), tooltip = {point = function() end}}
    button.frame = frame('drop button', button.iconFrame)
    buttons[#buttons + 1] = button
    return button
end}
assert(load(section('            -- item drop button', '            boss.update_items = function(p)'),
    'real boss-drop construction', 't', env))()
env.MULTIBOARD = env.MB
env.MB.bodies, env.MB.lookingAt, env.MB.minimized = {{frame = boss.frame}}, {1}, {false}
env.MB.registerViewChangedAction = function() end
env.PLAYER_CAP, env.LEECH_CONSTANT = 1, 20
env.GetLocalPlayer, env.GetTriggerPlayer = function() return 0 end, function() return 0 end
env.Player, env.GetPlayerId = function(p) return p end, function(p) return p end
env.Profile, env.Hero = {}, {}
env.OnInit = {final = function(_, callback) callback(function() end) end}
env.RewardNotifications = {registerQuestAction = function() end,
    registerEligibilityAction = function() end}
env.EVENT_ON_SETUP, env.EVENT_ON_CLEANUP = {register_action = function() end}, {register_action = function() end}
local tracker, toggle_button
env.SimpleButton = {create = function(parent, _, _, _, _, _, _, _, callback)
    tracker = parent
    toggle_button = {frame = frame('tracker toggle', parent), tooltip = {tooltip = frame('tooltip', parent)}}
    toggle_button.icon = function() end
    toggle_button.click = callback
    return toggle_button
end}
env.BlzGetTriggerFrame = function() return toggle_button.frame end
assert(loadfile('cotlua/src/ui/hud/quest_tracker.lua', 't', env))()
assert(tracker.parent == console and env.MB.frame.parent == console)
local function above(left, right)
    local a, b = {}, {}
    while left do table.insert(a, 1, left); left = left.parent end
    while right do table.insert(b, 1, right); right = right.parent end
    for i = 1, math.min(#a, #b) do
        if a[i] ~= b[i] then
            assert(a[i].parent == b[i].parent)
            return a[i].level > b[i].level
        end
    end
    error('Expected separate frame branches')
end
local function verify()
    for _, button in ipairs(buttons) do
        assert(above(button.iconFrame, tracker), 'Drop icon behind tracker backdrop')
        assert(above(button.frame, toggle_button.frame), 'Drop hover/click behind tracker toggle')
    end
    assert(above(anchor.gluebutton.frame, toggle_button.frame), 'Drop toggle behind collapsed tracker')
end
assert(#buttons == 13)
for _, width in ipairs({.2, .032, .2, .032}) do
    verify()
    toggle_button.click()
    assert(tracker.width == (width == .2 and .032 or .2))
end
boss.close_items(0, false)
verify()
boss.close_items(0, true)
assert(anchor.gluebutton.frame.enabled, 'Closing drops must restore its open button')
verify()
-- Remote UI events must not toggle the local tracker.
local previous_width = tracker.width
env.GetTriggerPlayer = function() return 1 end
toggle_button.click()
assert(tracker.width == previous_width)
local modal = frame('dialog', console); modal.level = 20
assert(above(modal, buttons[1].iconFrame), 'HUD must stay beneath full dialog frames')
print('PASS (offline frame graph): all 13 drops/toggle outrank expanded/collapsed tracker; close behavior and dialog priority remain intact.')
