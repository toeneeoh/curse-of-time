-- Standalone control-flow mocks; NOT a Warcraft rendering or multiplayer test.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local file = assert(io.open("cotlua/src/ui/hud/tutorial.lua", "rb"))
local source = file:read("*a")
file:close()
local local_player, trigger_player, trigger_frame = 0, 0, nil
local text_clears = 0
ClearTextMessages = function() text_clears = text_clears + 1 end
Player, GetPlayerId = function(p) return p end, function(p) return p end
GetLocalPlayer, GetTriggerPlayer = function() return local_player end, function() return trigger_player end
PLAYER_CAP, Hero, Profile = 2, {[1] = {}}, {[1] = {playing = true}}
SELECTING_HERO = {}
MAIN_MAP = {rect = {}}
local hero_select_visible, camera_locations = true, {}
HideHeroSelect = function(pid) if pid == 1 then hero_select_visible = false end end
StartHeroSelect = function(pid) if pid == 1 then hero_select_visible = true end end
local selection_resumes, profile_confirmations = 0, 0
Profile[1].hero_select = function()
    selection_resumes = selection_resumes + 1
    SELECTING_HERO[1] = true
    StartHeroSelect(1)
end
Profile.new = function(pid) assert(pid == 1); profile_confirmations = profile_confirmations + 1 end
local camera_preview = false
PreviewPlayerCamera = function(pid, region, x, y)
    if pid ~= local_player + 1 then return end
    assert(region == MAIN_MAP.rect)
    camera_preview = true
    camera_locations[#camera_locations + 1] = {x, y}
end
RestorePlayerCameraPreview = function(pid) if pid == local_player + 1 then camera_preview = false end end
local frames, deferred, escape = {}, {}, nil
for _, name in ipairs({"FRAMEPOINT_TOPLEFT", "FRAMEPOINT_TOPRIGHT", "FRAMEPOINT_BOTTOMLEFT",
    "FRAMEPOINT_BOTTOMRIGHT", "FRAMEPOINT_LEFT", "FRAMEPOINT_RIGHT", "FRAMEEVENT_CONTROL_CLICK", "ORIGIN_FRAME_MINIMAP"}) do
    sandbox[name] = name
end
local parent, minimap = {visible = true}, {visible = true}
GetTutorialMenuFrame = function() return parent end
BlzGetFrameByName = function() return parent end
BlzGetOriginFrame = function() return minimap end
local function make_frame(kind)
    local frame = {kind = kind, visible = true, enabled = true}
    frames[#frames + 1] = frame
    return frame
end
BlzCreateFrame = function(kind) return make_frame(kind) end
BlzCreateFrameByType = function(kind) return make_frame(kind) end
BlzFrameSetAbsPoint, BlzFrameSetSize, BlzFrameSetLevel, BlzFrameSetPoint,
BlzFrameClearAllPoints = function() end, function() end, function() end, function() end, function() end
BlzFrameSetAbsPoint = function(frame, point, x, y) frame.anchor, frame.x, frame.y = point, x, y end
BlzFrameSetSize = function(frame, width, height) frame.width, frame.height = width, height end
BlzFrameSetEnable = function(frame, value) frame.enabled = value end
BlzFrameSetVisible = function(frame, value) frame.visible = value end
BlzFrameIsVisible = function(frame) return frame.visible end
BlzFrameSetText = function(frame, value) frame.text = value end
BlzFrameSetAllPoints = function(frame, target) frame.target = target end
BlzFrameSetTexture = function(_, texture)
    assert(texture == "ReplaceableTextures\\TeamColor\\TeamColor00.blp", "Tutorial requested a new asset")
end
CreateTrigger = function() return {} end
BlzTriggerRegisterFrameEvent = function(trigger, frame) trigger.frame = frame end
TriggerAddAction = function(trigger, callback) trigger.frame.click = callback end
TimerQueue = {callDelayed = function(_, delay, callback) assert(delay == 0); deferred[#deferred + 1] = callback end}
AddToEsc = function(callback) escape = callback end
EVENT_ON_CLEANUP = {register_action = function() end}
OnInit = {final = function(_, callback) callback(function() end) end}
local bindings = {
    {name = "View Inventory", func = "inventory"}, {name = "View Stats", func = "stats"},
    {name = "Use Potion 1", func = "potion1"}, {name = "Use Potion 2", func = "potion2"},
}
GetHotkeyTable = function() return bindings end
GetHotkeyForFunc = function(_, func) return ({inventory = "K", stats = "L", potion1 = "5", potion2 = "6"})[func] end
local opened, closed = {}, {}
local function window(name)
    local frame, is_open = {visible = false}, {}
    return {
        isOpen = function(pid) return is_open[pid] end,
        open = function(pid)
            opened[#opened + 1] = {name = name, pid = pid}
            is_open[pid], frame.visible = true, true
        end,
        close = function(pid)
            closed[#closed + 1] = {name = name, pid = pid}
            is_open[pid], frame.visible = false, false
        end,
        getTutorialFrame = function() return frame end,
        previewTutorial = function(pid, visible, page)
            if pid == local_player + 1 then frame.visible, frame.preview_page = visible, page end
        end,
    }
end
INVENTORY, StashUI, STAT_WINDOW, PerkTree = window("inventory"), window("stash"), window("stats"), window("perks")
INVENTORY.clearTutorialPractice = function() end
INVENTORY.prepareTutorialPractice = function() end
STAT_WINDOW.showTutorial = function(pid, page) STAT_WINDOW.open(pid); STAT_WINDOW.page = page end
PerkTree.display = PerkTree.open
MULTIBOARD = {main = {visible = true}}
gg_unit_h036_0002, gg_unit_n01A_0092 = {x = 666.6, y = -543}, {x = 890, y = 887.6}
gg_rct_Troll_Demon_1 = {x = 2160, y = -3856}
GetUnitTypeId = function(unit) return unit.removed and 0 or 1 end
GetUnitX, GetUnitY = function(unit) return unit.x end, function(unit) return unit.y end
GetRectCenterX, GetRectCenterY = GetUnitX, GetUnitY
local pings = {}
PingMinimapEx = function(x, y) pings[#pings + 1] = {x, y} end
Debug = nil
assert(load(source, "tutorial", "t", sandbox))()
assert(#frames == 0 and #deferred == 1, "Tutorial frames were not deferred")
deferred[1]()
local panel = frames[1]
assert(panel.anchor == FRAMEPOINT_TOPLEFT and panel.y - panel.height >= 0.20,
    "Tutorial panel coordinates overlap the bottom HUD")
local function find_button(label)
    for _, frame in ipairs(frames) do
        if frame.kind == "GLUETEXTBUTTON" and frame.text == label then return frame end
    end
    error("Missing tutorial button: " .. label)
end
local function click(label)
    trigger_frame = find_button(label)
    assert(trigger_frame.enabled, label .. " is disabled")
    trigger_frame.click()
end
local function contains(text)
    for _, frame in ipairs(frames) do
        if frame.text and frame.text:find(text, 1, true) then return true end
    end
    return false
end
Tutorial.prompt(2)
assert(not panel.visible and #opened == 0 and text_clears == 0, "Remote player's prompt changed local UI or text")
Tutorial.prompt(1)
assert(text_clears == 1, "Tutorial prompt did not clear the requesting player's displayed text")
assert(panel.visible and contains("Start the tutorial?") and not find_button("Back").enabled)
assert(#opened == 0, "Prompt opened a menu before opting in")
click("Start")
assert(INVENTORY.isOpen(1) and contains("K|r"), "Tour ignored the rebound inventory key")
click("Next")
click("Next")
assert(contains("5|r") and contains("6|r"), "Tour ignored potion key bindings")
click("Back")
click("Next")
click("Next")
assert(StashUI.isOpen(1) and INVENTORY.isOpen(1))
click("Next")
assert(not StashUI.isOpen(1) and not INVENTORY.isOpen(1) and STAT_WINDOW.page == 1)
assert(contains("L|r"), "Tour ignored rebound stat key")
click("Next")
assert(STAT_WINDOW.page == 2)
click("Next")
assert(PerkTree.isOpen(1))
click("Next")
assert(not PerkTree.isOpen(1) and STAT_WINDOW.page == 5)
click("Next")
click("Next")
click("Next")
assert(contains("The fountain") and #pings == 0, "Tour moved the view without a location click")
click("Mark Location")
assert(pings[1][1] == -270 and pings[1][2] == 320)
click("Next")
click("Mark Location")
assert(pings[2][1] == 666.6 and pings[2][2] == -543)
click("Next")
click("Mark Location")
assert(pings[3][1] == 2160 and pings[3][2] == -3856)
click("Next")
click("Mark Location")
assert(pings[4][1] == 890 and pings[4][2] == 887.6)
click("Finish")
assert(not panel.visible and not INVENTORY.isOpen(1) and not STAT_WINDOW.isOpen(1))
assert(selection_resumes == 0 and profile_confirmations == 0, "Finish interrupted an existing live hero")
for _, entry in ipairs(opened) do assert(entry.pid == 1, "Tour opened another player's menu") end
Tutorial.prompt(1)
click("Start")
escape(1)
assert(not panel.visible and not INVENTORY.isOpen(1), "Escape left tour windows open")
INVENTORY.open(1)
Tutorial.prompt(1)
click("Start")
click("Skip")
assert(INVENTORY.isOpen(1), "Tutorial closed a window it did not open")
INVENTORY.close(1)
Hero[1] = nil
Profile[1].playing = false
SELECTING_HERO[1] = true
Tutorial.prompt(1)
click("Start")
assert(not INVENTORY.isOpen(1) and INVENTORY.getTutorialFrame().visible,
    "No-hero tour must show inventory without opening gameplay subscriptions")
assert(not hero_select_visible, "Hero selection covers tutorial previews")
click("Next")
click("Next")
click("Next")
assert(StashUI.getTutorialFrame().visible and INVENTORY.getTutorialFrame().visible)
assert(panel.y - panel.height > 0.408, "Tutorial covers stash preview")
click("Next")
assert(STAT_WINDOW.getTutorialFrame().visible and STAT_WINDOW.getTutorialFrame().preview_page == 1)
click("Next")
assert(STAT_WINDOW.getTutorialFrame().preview_page == 2)
click("Next")
assert(PerkTree.getTutorialFrame().visible and panel.x >= 0.55, "Tutorial covers perk preview")
click("Next")
assert(STAT_WINDOW.getTutorialFrame().preview_page == 5)
click("Next")
click("Next")
click("Next")
assert(camera_preview and camera_locations[#camera_locations][1] == -270)
click("Back")
assert(not camera_preview, "Back left tavern camera bounds overridden")
click("Next")
click("Next")
click("Next")
assert(camera_locations[#camera_locations][2] == -3856)
click("Next")
click("Finish")
assert(hero_select_visible and not camera_preview, "Finish did not restore hero selection/camera")
assert(selection_resumes == 1, "Finish did not explicitly resume hero selection")
Tutorial.prompt(1)
click("Start")
escape(1)
assert(hero_select_visible and not INVENTORY.getTutorialFrame().visible, "Escape left a preview or hid hero selection")
-- A missing selection flag must not strand a pre-hero player after Finish.
SELECTING_HERO[1], hero_select_visible = false, false
Tutorial.prompt(1)
Tutorial.finish(1)
assert(hero_select_visible and SELECTING_HERO[1] and selection_resumes == 2)
local previous_profile = Profile[1]
Profile[1], SELECTING_HERO[1] = nil, nil
Tutorial.prompt(1)
Tutorial.finish(1)
assert(profile_confirmations == 1 and Profile[1] == nil,
    "Pre-profile Finish must request confirmation rather than silently create a profile")
Profile[1] = previous_profile
print("PASS (mocked control flow only): opt-in, navigation, rebound keys, menu cleanup, starter pings, and remote-player isolation.")

-- Exercise the real camera-preview helpers with native calls recorded, not a
-- substitute implementation. This cannot verify Warcraft's visual rendering.
local camera_env = setmetatable({}, {__index = sandbox})
local camera_callbacks = {}
camera_env.TimerQueue = {callDelayed = function(_, delay, callback)
    assert(delay == 0.03, "Camera pan must wait for bounds to settle")
    camera_callbacks[#camera_callbacks + 1] = callback
end}
local function flush_camera()
    local pending = camera_callbacks
    camera_callbacks = {}
    for _, callback in ipairs(pending) do callback() end
end
camera_env.OnInit = {global = function(_, callback) callback(function() end) end, final = function() end}
camera_env.__jarray = function() return {} end
local bounds, camera_x, camera_y, texture = {-100, -200, 100, 200}, 12, 34, nil
camera_env.GetCameraBoundMinX = function() return bounds[1] end
camera_env.GetCameraBoundMinY = function() return bounds[2] end
camera_env.GetCameraBoundMaxX = function() return bounds[3] end
camera_env.GetCameraBoundMaxY = function() return bounds[4] end
camera_env.GetCameraTargetPositionX = function() return camera_x end
camera_env.GetCameraTargetPositionY = function() return camera_y end
camera_env.SetCameraBounds = function(minx, miny, _, maxy, maxx) bounds = {minx, miny, maxx, maxy} end
camera_env.PanCameraToTimed = function(x, y) camera_x, camera_y = x, y end
camera_env.BlzChangeMinimapTerrainTex = function(value) texture = value end
camera_env.REGION_DATA = {[MAIN_MAP.rect] = {vision = {}, minimap = "main.dds"}}
camera_env.GetRectMinX, camera_env.GetRectMinY = function() return -1000 end, function() return -2000 end
camera_env.GetRectMaxX, camera_env.GetRectMaxY = function() return 1000 end, function() return 2000 end
file = assert(io.open("cotlua/src/gameplay/world/player_camera.lua", "rb"))
local camera_source = file:read("*a")
file:close()
assert(load(camera_source, "player camera", "t", camera_env))()
camera_env.SetMinimapTexture(1, "tavern.dds")
camera_env.PreviewPlayerCamera(2, MAIN_MAP.rect, 99, 99)
flush_camera()
assert(camera_x == 12 and bounds[1] == -100, "Remote camera preview changed local view")
camera_env.PreviewPlayerCamera(1, MAIN_MAP.rect, -256, 320)
assert(camera_x == 12, "Camera pan started before the bounds update settled")
flush_camera()
assert(bounds[1] == -1000 and camera_x == -256 and texture == "main.dds")
camera_env.PreviewPlayerCamera(1, MAIN_MAP.rect, 2160, -3856)
camera_env.RestorePlayerCameraPreview(1)
flush_camera()
assert(bounds[1] == -100 and bounds[4] == 200 and camera_x == 12 and camera_y == 34 and texture == "tavern.dds",
    "Camera preview failed to restore the original bounds, position, and minimap")
camera_env.PreviewPlayerCamera(1, MAIN_MAP.rect, -256, 320)
camera_env.PreviewPlayerCamera(1, MAIN_MAP.rect, 890, 887.6)
camera_callbacks[1]()
assert(camera_x == 12, "Stale tutorial page panned the camera")
flush_camera()
assert(camera_x == 890 and camera_y == 887.6, "Latest tutorial page did not pan")
camera_env.RestorePlayerCameraPreview(1)
print("PASS (mocked native calls only): camera preview overrides tavern bounds and restores the original local view.")

-- Run the actual preview functions to check icon state independently of clicks.
local preview_env = setmetatable({}, {__index = sandbox})
local preview_frame = {}
preview_env.frame, preview_env.title = preview_frame, {}
preview_env.manage_perks, preview_env.milestone_controls = {}, {}
preview_env.breakdown_frames = {}
preview_env.MAX_ROWS = 32
preview_env.clear_all_rows = function() end
preview_env.tabs, preview_env.tab_ui = {}, {}
for i = 1, 5 do
    preview_env.tabs[i] = {frame = {}, enable = function(self, value) self.normal_icon = value end}
    preview_env.tab_ui[i] = {order = {}, entries = {}, rows = {}}
end
preview_env.STAT_WINDOW = {}
file = assert(io.open("cotlua/src/ui/hud/stat_view.lua", "rb"))
local preview_source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local preview_first = assert(preview_source:find("    function STAT_WINDOW.previewTutorial", 1, true))
local preview_last = assert(preview_source:find("    function STAT_WINDOW.showTutorial", preview_first, true))
assert(load(preview_source:sub(preview_first, preview_last - 1), "stat preview", "t", preview_env))()
for _, page in ipairs({1, 2, 5}) do
    preview_env.STAT_WINDOW.previewTutorial(1, true, page)
    for i, tab in ipairs(preview_env.tabs) do
        assert(tab.normal_icon == (i == page) and not tab.frame.enabled,
            "Preview tab must display selected icon without accepting clicks")
    end
end
preview_env.STAT_WINDOW.previewTutorial(1, false)
for _, tab in ipairs(preview_env.tabs) do assert(tab.frame.enabled, "Preview left real tabs disabled") end
preview_env.STASH_MAX_ROWS, preview_env.MAX_STASH_SLOTS = 2, 0
preview_env.rows, preview_env.locks = {{}, {}}, {{}, {}}
preview_env.ROW_TEXTURE, preview_env.LOCKED_ROW_TEXTURE = "row", "locked"
preview_env.BlzFrameSetTexture = function() end
preview_env.plus_buttons = {[2] = {
    frame = {}, visible = function() end,
    enable = function() error("Preview must not derive a DISBTN path from a UI texture") end,
}}
preview_env.StashUI = {}
preview_env.INVENTORY = {renderItemButton = function() end, refreshTutorialPractice = function() end}
file = assert(io.open("cotlua/src/ui/inventory/stash.lua", "rb"))
preview_source = file:read("*a"):gsub("\r\n", "\n")
file:close()
preview_first = assert(preview_source:find("    local tutorial_preview", 1, true))
preview_last = assert(preview_source:find("    local function close_clicked", preview_first, true))
assert(load(preview_source:sub(preview_first, preview_last - 1), "stash preview", "t", preview_env))()
preview_env.StashUI.previewTutorial(1, true)
assert(not preview_env.plus_buttons[2].frame.enabled)
preview_env.StashUI.previewTutorial(1, false)
assert(preview_env.plus_buttons[2].frame.enabled)
print("PASS (mocked frame calls only): preview tab icons and stash button texture/click state.")

file = assert(io.open("cotlua/src/gameplay/players/commands.lua", "rb"))
local commands_source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(commands_source:find('        ["-new"] = function', 1, true))
local last = assert(commands_source:find('        ["-info"] = function', first, true))
local routes = assert(load("return {" .. commands_source:sub(first, last - 1) .. "}", "new routing", "t", sandbox))()
local prompts, new_profiles = 0, 0
Tutorial.prompt = function(pid) assert(pid == 1); prompts = prompts + 1 end
Profile.new = function(pid) assert(pid == 1); new_profiles = new_profiles + 1 end
routes["-new"](0, 1, {"-new"})
assert(prompts == 1 and new_profiles == 0, "Tutorial command overwrote the profile")
routes["-new"](0, 1, {"-new", "profile"})
routes["-new"](0, 1, {"-new", "PROFILE"})
assert(prompts == 1 and new_profiles == 2, "Explicit new-profile command no longer works")
print("PASS (mocked routing only): bare -new offers the tutorial; explicit -new profile retains profile creation.")

file = assert(io.open("cotlua/src/gameplay/players/hotkeys.lua", "rb"))
local hotkey_source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local registration_start = assert(hotkey_source:find('        -- Window cleanup must work', 1, true))
local registration_end = assert(hotkey_source:find('        -- immutable hotkeys', registration_start, true))
local early_bindings = {}
local hotkey_env = setmetatable({U = {id = 1}, close_all_windows = {}, clear_text = {},
    register_key_binding = function(pid, key, action)
        assert(pid == 1 and key == 'ESC')
        early_bindings[#early_bindings + 1] = action
    end}, {__index = sandbox})
assert(load(hotkey_source:sub(registration_start, registration_end - 1), 'pre-profile Escape bindings', 't', hotkey_env))()
assert(early_bindings[1] == hotkey_env.close_all_windows and early_bindings[2] == hotkey_env.clear_text,
    'Startup did not bind Escape independently of profile creation')
print('PASS (mocked binding calls only): Escape closes windows and clears text before a profile exists.')
