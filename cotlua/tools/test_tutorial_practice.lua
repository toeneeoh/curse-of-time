-- Standalone mocked UI checks, not Warcraft rendering or input verification.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n')
    file:close()
    return source
end
Player, GetPlayerId = function(p) return p end, function(p) return p end
GetLocalPlayer, GetTriggerPlayer = function() return 0 end, function() return 0 end
OnInit = {global = function(_, callback) callback(function() end) end}
BlzFrameSetTexture = function(frame, path) frame.texture = path end
BlzFrameSetVisible = function(frame, visible) frame.visible = visible end
BlzFrameSetText = function(frame, text) frame.text = text end
BlzFrameSetEnable = function(frame, enabled) frame.enabled = enabled end
BlzFrameSetPoint, BlzFrameSetSize = function() end, function() end
BlzCreateFrame = function() return {} end
local named, context = {}, 0
NextFrameCreateContext = function() context = context + 1; return context end
BlzGetFrameByName = function(name, id)
    local key = name .. id
    named[key] = named[key] or {}
    return named[key]
end
assert(load(read('cotlua/src/framework/ui/simple_button.lua'), 'SimpleButton', 't', env))()
local ui_button = SimpleButton.create({}, 'inventorymenubuttons.dds', 0, 0)
assert(ui_button.button.texture == ui_button.disabled_button.texture)
ui_button:enable(false)
assert(ui_button.disabled_button.texture == 'inventorymenubuttons.dds', 'UI texture became a fabricated DISBTN path')
local icon = 'ReplaceableTextures\\CommandButtons\\BTNHeroPanelStatsButton.dds'
ui_button:icon(icon)
ui_button:enable(false)
assert(ui_button.disabled_button.texture == 'ReplaceableTextures\\CommandButtonsDisabled\\DISBTNHeroPanelStatsButton.dds')
ui_button:enable(true)
BlzFrameSetEnable(ui_button.frame, false)
assert(ui_button.disabled_button.texture == icon, 'Native-disabled selected tab lost its normal texture')
print('PASS (mocked frame calls only): normal and disabled backdrops receive textures; UI backgrounds are not converted to DISBTN paths.')

INVENTORY, slots, MAX_INVENTORY_SLOTS, title, frame = {}, {}, 26, {}, {}
STASH_COLUMNS, ctrl_down = 6, {}
alt_down = {}
FourCC = function(id) return id end
thistype = INVENTORY
for i = 1, MAX_INVENTORY_SLOTS do
    slots[i] = {
        frame = {},
        tooltip = {icon = function() end, name = function() end, text = function() end, visible = function() end},
        icon = function(self, icon) self.texture = icon end,
        charge = function(self, charges) self.charges = charges end,
        visible = function(self, visible) self.visible_now = visible end,
    }
end
INVENTORY.renderItemButton = function(button, item) assert(item == nil); button.visible_now = false end
local hovered, stash_hovered, tracker_visible, stash_open = 0, -1, false, false
get_inventory_hovered_slot = function() return hovered end
local stash_items, stash_drag
StashUI = {
    isTutorialPreviewOpen = function() return stash_open end,
    getLocalHoveredSlot = function() return stash_hovered end,
    renderTutorialPractice = function(_, items, drag) stash_items, stash_drag = items, drag end,
    getTutorialSlotFrame = function() return {} end,
    setTutorialTooltipsVisible = function() end,
}
context_menu_backdrop, transparent_placeholder, cost_frame = {}, {}, {}
context_buttons, frame_to_btn = {}, {}
frame_clear_all_points = function() end
BlzFrameSetTooltip = function(frame, tip) frame.tooltip = tip end
for i = 1, 7 do
    local button = {frame = {}, visible = function(self, value) self.frame.visible = value end,
        text = function(self, value) self.frame.text = value end}
    context_buttons[i], frame_to_btn[button.frame] = button, i
end
local detail_views, clicked_frame = 0, nil
ItemDetails = {show = function() detail_views = detail_views + 1 end, hide = function() end}
BlzGetTriggerFrame = function() return clicked_frame end
local destroyed = 0
ItemRuntime = {create = function(id)
    return {obj = {id = id}, tooltip = 'Starter tooltip', alt_tooltip = 'Starter ranges', charges = id == 'I02F' and 3 or 0,
        destroy = function() destroyed = destroyed + 1 end}
end}
SetItemVisible = function() end
PotionService = {refreshItem = function() end}
GetItemName = function(obj) return obj.id == 'I02F' and 'Health Flask' or 'Iron Sword' end
BlzGetItemIconPath = function(obj)
    return 'ReplaceableTextures\\CommandButtons\\' .. (obj.id == 'I02F' and 'BTNPotionGreenSmall.blp' or 'BTNSteelMelee.blp')
end
show_tracker, hide_tracker = function() tracker_visible = true end, function() tracker_visible = false end
frame_set_visible = BlzFrameSetVisible
local function mouse_event()
    return {
        register_action = function(self, pid, callback) self.callback = callback end,
        unregister_action = function(self) self.callback = nil end,
    }
end
EVENT_ON_M1_DOWN, EVENT_ON_M1_UP = mouse_event(), mouse_event()
EVENT_ON_M2_DOWN, EVENT_ON_M2_UP = mouse_event(), mouse_event()
local source = read('cotlua/src/ui/inventory/inventory.lua')
local first = assert(source:find('        local practice, practice_visible', 1, true))
local last = assert(source:find('        local function send_context', first, true))
assert(load(source:sub(first, last - 1), 'practice inventory', 't', env))()
INVENTORY.prepareTutorialPractice()
assert(destroyed == 2, 'Temporary presentation items were retained')
INVENTORY.previewTutorial(1, true)
assert(slots[1].visible_now and slots[9].visible_now)
assert(slots[1].texture:find('BTNSteelMelee.blp', 1, true))
local click_first = assert(source:find('        local on_context_push = function()', 1, true))
local click_last = assert(source:find('        for i = 1, #context_buttons do', click_first, true))
local click_menu = assert(load(source:sub(click_first, click_last - 1) .. '\nreturn on_context_push', 'practice menu routing', 't', env))()
local function right_click(slot, stash_slot)
    hovered, stash_hovered = slot or -1, stash_slot or -1
    EVENT_ON_M2_DOWN.callback(); EVENT_ON_M2_UP.callback()
    assert(context_menu_backdrop.visible, 'Right-click did not open the practice menu')
end
local function choose(action)
    clicked_frame = context_buttons[action].frame
    click_menu()
    assert(not context_menu_backdrop.visible)
end
right_click(1)
assert(context_buttons[2].frame.visible and context_buttons[3].frame.visible and context_buttons[4].frame.visible)
choose(3)
assert(slots[1].visible_now, 'Context Drop removed a practice item')
right_click(1); choose(4)
assert(slots[1].visible_now, 'Context Sell removed a practice item')
right_click(1); choose(5)
assert(detail_views == 1, 'Context Details did not show starter presentation')
right_click(1); choose(2)
assert(slots[10].visible_now and not slots[1].visible_now)
right_click(10); choose(1)
assert(slots[1].visible_now and not slots[10].visible_now)
stash_open = true
right_click(1); choose(6)
assert(stash_items[27] and not slots[1].visible_now)
right_click(nil, 1)
assert(context_buttons[1].frame.text == 'Take')
choose(3)
assert(stash_items[27], 'Stash context Drop removed a practice item')
right_click(nil, 1); choose(4)
assert(stash_items[27], 'Stash context Sell removed a practice item')
right_click(nil, 1); choose(1)
assert(slots[10].visible_now and not stash_items[27])
right_click(10); choose(1)
assert(slots[1].visible_now)
stash_open = false
print('PASS (mocked context events only): inventory/stash menus, Equip/Unequip, Take/Stash, Details, and harmless Drop/Sell.')
local function drag(from, to)
    hovered, stash_hovered = from, -1; EVENT_ON_M1_DOWN.callback()
    if from > 0 and from <= MAX_INVENTORY_SLOTS and slots[from].visible_now then
        error('Source icon remained visible while dragging')
    end
    hovered, stash_hovered = to, -1; EVENT_ON_M1_UP.callback()
    assert(not tracker_visible)
end
drag(1, 10)
assert(not slots[1].visible_now and slots[10].visible_now, 'Practice gear did not move')
drag(10, -1)
assert(slots[10].visible_now, 'Practice gear could be dropped')
drag(10, 7)
assert(slots[10].visible_now and not slots[7].visible_now, 'Sword entered a potion slot')
drag(9, 7)
assert(slots[7].visible_now and slots[7].charges == 3 and not slots[9].visible_now)
drag(7, 1)
assert(slots[7].visible_now and not slots[1].visible_now, 'Flask entered an equipment slot')
stash_open = true
hovered, stash_hovered = 10, -1; EVENT_ON_M1_DOWN.callback()
assert(not slots[10].visible_now)
hovered, stash_hovered = -1, 1; EVENT_ON_M1_UP.callback()
assert(stash_items[27] and not slots[10].visible_now, 'Drag to stash failed')
hovered, stash_hovered = -1, 1; EVENT_ON_M1_DOWN.callback()
assert(stash_drag == 27, 'Stash source was not hidden while dragging')
hovered, stash_hovered = 10, -1; EVENT_ON_M1_UP.callback()
assert(slots[10].visible_now and not stash_items[27], 'Drag from stash failed')
ctrl_down[1] = true
hovered, stash_hovered = 10, -1; EVENT_ON_M1_DOWN.callback(); EVENT_ON_M1_UP.callback()
assert(stash_items[27] and not slots[10].visible_now, 'Ctrl-click to stash failed')
hovered, stash_hovered = -1, 1; EVENT_ON_M1_DOWN.callback(); EVENT_ON_M1_UP.callback()
assert(not stash_items[27] and slots[9].visible_now, 'Ctrl-click to backpack failed')
ctrl_down[1] = false
drag(9, 10)
INVENTORY.previewTutorial(1, false)
assert(not EVENT_ON_M1_DOWN.callback and not EVENT_ON_M1_UP.callback)
INVENTORY.previewTutorial(1, true)
assert(slots[10].visible_now and slots[7].visible_now, 'Changing tutorial page reset practice items')
INVENTORY.previewTutorial(1, false)
INVENTORY.clearTutorialPractice(1)
INVENTORY.previewTutorial(1, true)
assert(slots[1].visible_now and slots[9].visible_now, 'Finishing did not reset the practice session')
print('PASS (mocked input only): starter presentation, drag source hiding, stash drag/Ctrl-click transfers, slot restrictions, no dropping, and cleanup.')
