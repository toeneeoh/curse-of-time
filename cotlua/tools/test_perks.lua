-- Standalone tests of real perk logic and mocked frame calls, not WC3 rendering.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local f = assert(io.open(path, 'rb'))
    local s = f:read('*a'):gsub('\r\n', '\n'); f:close(); return s
end
local function run(path) assert(load(read(path), path, 't', env))() end
__jarray = function(v) return setmetatable({}, {__index = function() return v end}) end
OnInit = {final = function(_, callback) callback(function() end) end}
MAX_SLOTS, MAX_LEVEL, PLAYER_CAP, PROFILE_PERK_NODE_WORDS = 40, 500, 2, 8
local hero = {owner = 0, level = 50}
Hero = {[1] = hero}
Profile = {[1] = {playing = true, storage = {}, perk_node_words = __jarray(0),
    perk_ranks = __jarray(0), perk_reset_available = 1}}
local new_character, setup = nil, {}
Profile.registerNewCharacterAction = function(callback) new_character = callback end
Profile.registerStorageChangedAction = function() end
Progression = {setSharedXPBonusProvider = function() end}
ExperienceControl = function() end
Player, GetPlayerId = function(p) return p end, function(p) return p end
GetOwningPlayer = function(u) return u.owner end
GetHeroLevel = function(u) return u.level end
UnitAlive = function(u) return not u.dead end
MainStat = function() return 1 end
GetLocalPlayer, GetTriggerPlayer = function() return 0 end, function() return 0 end
User = {first = {id = 1}}
Unit = {[hero] = {damage_percent = 1, spellboost = 0, spell_area = 0, spell_duration = 0, cc_flat = 5, cd_flat = 100,
    ms_flat = 0, gold_rate = 0, status_resist_flat = 0, cooldown_acceleration = 0,
    drop_rate = 1, boss_drop_rate = 1, armor_percent = 1, regen_percent = 1,
    mana_regen_percent = 1, dr = .5, mr = .6, str = 100, bonus_str = 0}}
local baseline = {}; for key, value in pairs(Unit[hero]) do baseline[key] = value end
EVENT_ON_SETUP = {register_action = function(_, pid, cb) setup[pid] = cb end}
EVENT_ON_CLEANUP = {register_action = function() end}
EVENT_STAT_CHANGE = {register_unit_action = function() end}
DisplayTextToPlayer = function() end
local cooldown_tick, cooldown_finished, cooldown_starts = nil, nil, 0
TimerQueue = {callPeriodically = function(_, _, condition, callback)
    cooldown_tick, cooldown_finished = callback, condition
    cooldown_starts = cooldown_starts + 1
end}
local cooldown_remaining = 10.
BlzGetUnitAbilityByIndex = function(_, index) return index == 0 and {} or nil end
BlzGetAbilityId = function() return 42 end
BlzGetUnitAbilityCooldownRemaining = function() return cooldown_remaining end
BlzAdjustUnitAbilityCooldownRemaining = function(_, _, delta) cooldown_remaining = cooldown_remaining + delta end
run('cotlua/src/gameplay/abilities/cooldown_acceleration.lua')
run('cotlua/src/gameplay/players/perks.lua')
local nodes, names, positions = Perks.getNodes(), {}, {}
assert(#nodes == 241 and #Perks.getBranches() == 4)
for id, node in ipairs(nodes) do
    for other_id = 1, id - 1 do
        local other = nodes[other_id]
        assert((node.x - other.x)^2 + (node.y - other.y)^2 >= .95^2,
            'Cluster layout crowds nodes ' .. id .. '/' .. other_id)
    end
    for _, parent_id in ipairs({node.parent or 1, node.alternate_parent or 1}) do
        assert(parent_id == 1 or nodes[parent_id].branch == node.branch,
            'Prerequisite crosses category districts')
    end
    if id > 1 then
        local outward = node.branch == 'might' and node.x or node.branch == 'guard' and -node.x
            or node.branch == 'fellowship' and node.y or -node.y
        assert(outward > 0, 'Node escaped its category district')
    end
end
print('PASS: every node has breathing room, stays in its own district, and has no cross-category prerequisite.')
for _, node in ipairs(nodes) do
    if node.parent == 33 then
        local entrance = nodes[33]
        assert((node.x - entrance.x)^2 + (node.y - entrance.y)^2 < 6^2,
            'Legacy entrance regained an oversized empty connector')
    end
end
local primary_segments = {}
for id = 2, #nodes do
    local node, route = nodes[id], nodes[id].routes[nodes[id].parent]
    assert(#route == 4)
    for index = 1, #route - 1 do
        local a, b = route[index], route[index + 1]
        if math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) > 1e-6 then
            primary_segments[#primary_segments + 1] = {a = a, b = b, id = id, parent = node.parent,
                horizontal = math.abs(a[1] - b[1]) > math.abs(a[2] - b[2])}
        end
    end
end
for index, a in ipairs(primary_segments) do
    for other_index = 1, index - 1 do
        local b = primary_segments[other_index]
        if a.id ~= b.id and a.parent ~= b.parent and a.id ~= b.parent and b.id ~= a.parent then
            if a.horizontal ~= b.horizontal then
                local h, v = a.horizontal and a or b, a.horizontal and b or a
                local crossing = v.a[1] > math.min(h.a[1], h.b[1]) + 1e-6
                    and v.a[1] < math.max(h.a[1], h.b[1]) - 1e-6
                    and h.a[2] > math.min(v.a[2], v.b[2]) + 1e-6
                    and h.a[2] < math.max(v.a[2], v.b[2]) - 1e-6
                assert(not crossing, 'Unrelated primary paths cross: ' .. a.id .. '/' .. b.id)
            else
                local axis, across = a.horizontal and 1 or 2, a.horizontal and 2 or 1
                local overlap = math.abs(a.a[across] - b.a[across]) < 1e-6
                    and math.min(math.max(a.a[axis], a.b[axis]), math.max(b.a[axis], b.b[axis]))
                        > math.max(math.min(a.a[axis], a.b[axis]), math.min(b.a[axis], b.b[axis])) + 1e-6
                assert(not overlap, 'Unrelated primary paths overlap: ' .. a.id .. '/' .. b.id)
            end
        end
    end
end
print('PASS: unrelated primary prerequisite paths do not cross.')
Profile[3] = {storage = {{hardcore = 0, perk_milestones = 3}, {hardcore = 1, perk_milestones = 3}}}
assert(Perks.getTotal(3) == 20, 'SC/HC milestones no longer award 8/12 points per completed character')
Profile[3].storage = {}
for slot = 1, 20 do Profile[3].storage[slot] = {hardcore = 1, perk_milestones = 3} end
assert(Perks.getTotal(3) == #nodes - 1, 'Graph does not accommodate twenty completed hardcore characters')
local function connected(id, visited)
    if id == 1 then return true end
    visited = visited or {}; assert(not visited[id], 'Perk prerequisites contain a cycle')
    visited[id] = true
    local node = assert(nodes[id])
    assert(connected(node.parent, visited))
    visited[id] = nil
    return true
end
for id, node in ipairs(nodes) do
    assert(node.id == id)
    local position = node.x .. ':' .. node.y
    assert(not positions[position], 'Duplicate perk position'); positions[position] = true
    connected(id)
    if id > 1 then
        assert(not names[node.effect] or names[node.effect] == node.name)
        names[node.effect] = node.name
        if node.alternate_parent then connected(node.alternate_parent) end
        if node.effect == 'shared_xp' then
            assert(node.value == .02 and node.description:find('experience rate', 1, true))
            assert(not node.description:find('strongest', 1, true))
            assert(node.description == 'All players gain |cffffcc00+2%|r experience rate.')
        end
        local expected_icons = {regen_percent = 'BTNHeal.blp', movespeed = 'BTNBootsOfSpeed.blp',
            status_resistance = 'BTNAntiMagicShell.blp', drop_rate = 'BTNTransmute.blp', boss_drop_rate = 'BTNTransmute.blp'}
        if expected_icons[node.effect] then
            assert(node.icon == 'ReplaceableTextures\\CommandButtons\\' .. expected_icons[node.effect],
                'Perk icon differs between minor and reward nodes')
        end
        for _, other in ipairs(nodes) do
            if node.effect == other.effect then
                if node.value == other.value then assert(node.icon_size == other.icon_size) end
                if node.value > other.value then assert(node.icon_size > other.icon_size) end
            end
        end
    end
end
Perks.setDevPoints(1, 300)
local function allocate_path(pid, id)
    if id == 1 or Perks.hasNode(pid, id) then return end
    allocate_path(pid, nodes[id].parent)
    assert(Perks.allocateNode(pid, id))
end
assert(not Perks.canAllocate(1, 24), 'Large movement node is available without minor investment')
for id = 172, 175 do assert(Perks.allocateNode(1, id)) end
assert(Perks.getSpent(1) == 4 and Unit[hero].ms_flat == 4)
assert(Perks.allocateNode(1, 24))
assert(Perks.getSpent(1) == 5 and Unit[hero].ms_flat == 9,
    'Movement investment must cost five points for four +1 minors and a +5 reward')
assert(not Perks.canAllocate(1, 29), 'Second movement reward bypasses further minor investment')
for id = 176, 178 do assert(Perks.allocateNode(1, id)) end
assert(Perks.allocateNode(1, 29) and Unit[hero].ms_flat == 17 and Perks.getSpent(1) == 9)
assert(Perks.reset(1))
for _, path in ipairs({{92, 2, 9, 54}, {102, 46, 47, 48}, {112, 3, 7, 56},
    {122, 51, 52, 53}, {132, 13, 18, 19}, {142, 59, 14, 21},
    {152, 15, 16, 17}, {162, 68, 69, 70}, {172, 24, 29, 30},
    {182, 25, 31, 32}, {192, 77, 78, 79}}) do
    local cursor = path[1]
    for index = 2, #path do
        local reward = nodes[path[index]]
        local count = index == 2 and 4 or 3
        for _ = 1, count do
            assert(nodes[cursor].effect and nodes[cursor].parent)
            cursor = cursor + 1
        end
        assert(reward.parent == cursor - 1 and not reward.alternate_parent,
            'Reward can bypass its minor-node investment')
        if index < #path then
            local continuation = reward.id == 59 and 60 or reward.id
            assert(nodes[cursor].parent == continuation)
        end
    end
end
-- An old shortcut allocation is refunded, without adding points or touching
-- character milestones. Valid investment allocations survive reconcile.
Profile[3].perk_node_words = __jarray(0)
Profile[3].perk_node_words[1] = 1 << (24 - 2)
Profile[3].perk_ranks = __jarray(0)
assert(Perks.reconcile(3) and Perks.getSpent(3) == 0 and Perks.getAvailable(3) == 240)
assert(Profile[3].perk_reset_available == 1)
allocate_path(1, 24)
assert(not Perks.reconcile(1) and Perks.getSpent(1) == 5)
Profile[1].perk_reset_available = 1; assert(Perks.reset(1))
print('PASS: minor investments gate rewards, later rewards require additional investment, old shortcuts refund, and valid builds survive reconcile.')
allocate_path(1, 10)
assert(not Perks.hasNode(1, 4), 'Spell entry still requires physical Mastery')
allocate_path(1, 21)
assert(not Perks.hasNode(1, 15), 'Recovery entry still requires damage resistance')
Profile[1].perk_reset_available = 1
assert(Perks.reset(1))
for key, value in pairs(baseline) do assert(math.abs(Unit[hero][key] - value) < 1e-9, 'Reset drift: ' .. key) end
local remaining = #nodes - 1
while remaining > 0 do
    local before = remaining
    for id = 2, #nodes do
        if Perks.canAllocate(1, id) then assert(Perks.allocateNode(1, id)); remaining = remaining - 1 end
    end
    assert(remaining < before, 'Unreachable perk node')
end
assert(Perks.getSpent(1) == 240)
for word = 1, 8 do assert(Profile[1].perk_node_words[word] == 0x3fffffff, 'Lost high-word allocation bits') end
assert(Perks.getRank(1, 'fellowship') == 5 and Perks.getRank(1, 'inheritance') == 5)
local bonuses = Perks.getBonuses(1)
assert(math.abs(Unit[hero].status_resist_flat - 10) < 1e-9)
assert(math.abs(Unit[hero].cooldown_acceleration - .07) < 1e-9)
assert(math.abs(Unit[hero].mana_regen_percent - 1.10) < 1e-9)
assert(math.abs(Unit[hero].spell_area - .085) < 1e-9)
assert(math.abs(Unit[hero].spell_duration - .085) < 1e-9)
assert(math.abs(Unit[hero].mr - .6 * .92) < 1e-9)
assert(math.abs(Unit[hero].drop_rate - 1.07) < 1e-9 and math.abs(Unit[hero].boss_drop_rate - 1.05) < 1e-9)
assert(math.abs(bonuses.potion_restoration - .09) < 1e-9)
assert(math.abs(bonuses.potion_duration - .10) < 1e-9)
assert(math.abs(bonuses.potion_refill_discount - .12) < 1e-9)
assert(math.abs(bonuses.recharge_discount - .09) < 1e-9)
assert(bonuses.reincarnation_capacity == 1 and math.abs(bonuses.home_channel - .25) < 1e-9)
assert(math.abs(Perks.getSharedXPBonus() - .10) < 1e-9)
Profile[2] = {playing = true, storage = {}, perk_node_words = __jarray(0), perk_ranks = __jarray(0)}
User.first.next = {id = 2}
Perks.setDevPoints(2, 6)
allocate_path(2, 26)
assert(math.abs(Perks.getSharedXPBonus() - .12) < 1e-9, 'Other player did not stack experience rate')
Profile[2].playing = false
assert(math.abs(Perks.getSharedXPBonus() - .10) < 1e-9, 'Inactive player still supplied experience rate')
local before = cooldown_remaining
cooldown_tick()
assert(math.abs(cooldown_remaining - (before - .07 * .25)) < 1e-9, 'Permanent acceleration has no gameplay effect')
assert(CooldownAcceleration.apply(hero, .5, .5))
assert(math.abs(Unit[hero].cooldown_acceleration - .57) < 1e-9)
cooldown_tick(); cooldown_tick()
assert(math.abs(Unit[hero].cooldown_acceleration - .07) < 1e-9, 'Potion expiry erased permanent acceleration')
assert(CooldownAcceleration.apply(hero, .5, 1))
CooldownAcceleration.remove(hero)
assert(math.abs(Unit[hero].cooldown_acceleration - .07) < 1e-9)
assert(Perks.hasEligibleActiveOwner('huntsmans_favor', 30))
assert(not Perks.hasEligibleActiveOwner('huntsmans_favor', 60), 'Auto turn-in eligibility changed')
local child = {level = 1, gold = 100}; new_character(1, child)
assert(child.level == 26 and child.gold == 125100)
local source = read('cotlua/src/devtools/architecture_tests.lua')
local first = assert(source:find('    ArchitectureTests.register(\n        "Perk branches use consistent', 1, true))
local last = assert(source:find('    ArchitectureTests.register(', first + 30, true))
ArchitectureTests = {register = function(_, callback) local ok, why = callback(); assert(ok, why) end}
assert(load(source:sub(first, last - 1), 'perk architecture regression', 't', env))()
Profile[1].perk_reset_available = 1; assert(Perks.reset(1))
for key, value in pairs(baseline) do assert(math.abs(Unit[hero][key] - value) < 1e-9, 'Full reset drift: ' .. key) end
assert(cooldown_finished())
local previous_starts = cooldown_starts
assert(CooldownAcceleration.apply(hero, .5, 1))
assert(cooldown_starts == previous_starts + 1, 'Cooldown ticker failed to restart after reset/removal')
CooldownAcceleration.remove(hero); assert(cooldown_finished())
print('PASS: connected/canonical nodes, strength-ranked icon sizes, save capacity, reversible stats, stacking experience rate, permanent/temporary cooldown effects, and unchanged auto turn-in.')

-- Run the actual UI module with mocked frames, including branch navigation.
local frames, buttons = {}, {}
local calls = {abs = 0, point = 0, node_point = 0, size = 0, icon = 0, color = 0, visible = 0, text = 0, allocation = 0}
local function frame(kind)
    local f = setmetatable({kind = kind}, {__index = function(self, key)
        if (key == 'x' or key == 'y') and self.relative_parent then
            return (self.relative_parent[key] or 0) + (key == 'x' and self.relative_x or self.relative_y)
        end
    end})
    frames[#frames + 1] = f; return f
end
for _, name in ipairs({'FRAMEPOINT_TOPLEFT', 'FRAMEPOINT_TOP', 'FRAMEPOINT_CENTER', 'FRAMEPOINT_BOTTOMLEFT',
    'FRAMEPOINT_BOTTOMRIGHT', 'FRAMEPOINT_TOPRIGHT', 'FRAMEPOINT_BOTTOM', 'TEXT_JUSTIFY_MIDDLE',
    'TEXT_JUSTIFY_CENTER', 'TEXT_JUSTIFY_LEFT', 'FRAMEEVENT_MOUSE_WHEEL', 'FRAMEEVENT_CONTROL_CLICK'}) do env[name] = name end
BlzConvertColor = function(...) return table.concat({...}, ':') end
BlzGetFrameByName = function() return {} end
BlzCreateFrame = function(kind, parent) local f = frame(kind); f.parent = parent; return f end
BlzCreateFrameByType = BlzCreateFrame
BlzFrameSetAbsPoint = function(f, _, x, y) calls.abs = calls.abs + 1; f.relative_parent = nil; f.x, f.y = x, y end
BlzFrameSetSize = function(f, w, h) calls.size = calls.size + 1; f.width, f.height = w, h end
BlzFrameSetVisible = function(f, visible) calls.visible = calls.visible + 1; f.visible = visible end
BlzFrameSetEnable = function(f, enabled) f.enabled = enabled end
BlzFrameSetText = function(f, text) calls.text = calls.text + 1; f.text = text end
BlzFrameSetTextAlignment = function() end
BlzFrameSetLevel = function(f, level) f.level = level end
BlzFrameSetPoint = function(f, _, parent, _, x, y)
    calls.point = calls.point + 1
    if f.kind == 'button' then calls.node_point = calls.node_point + 1 end
    f.x, f.y = nil, nil
    f.relative_parent, f.relative_x, f.relative_y = parent, x, y
end
BlzFrameSetAllPoints, BlzFrameSetScale = function() end, function() end
BlzFrameSetTexture = function(f, path) f.texture = path end
BlzFrameSetVertexColor = function() calls.color = calls.color + 1 end
BlzFrameClearAllPoints = function(f) f.relative_parent = nil; f.x, f.y = nil, nil end
local clicked
BlzGetTriggerFrame = function() return clicked end
local sync_callback, pending_sync
SyncCallback = function(prefix, callback) assert(prefix == 'perk_tree'); sync_callback = callback end
BlzSendSyncData = function(prefix, value) assert(prefix == 'perk_tree'); pending_sync = value end
BlzGetTriggerSyncData = function() return pending_sync end
SimpleButton = {create = function(parent, icon, w, h, _, _, _, _, action, tip)
    local b = {frame = frame('button'), text_frame = {}, action = action, tip = tip,
        icon = function(self, path) calls.icon = calls.icon + 1; self.path = path end,
        iconColor = function() calls.color = calls.color + 1 end,
        visible = function(self, value) BlzFrameSetVisible(self.frame, value) end,
        enable = function(self, value) self.frame.enabled = value end,
        setTooltipText = function(self, value) self.tip = value end,
        text = function(self, label) self.label = label end}
    b.frame.parent = parent
    b.frame.width, b.frame.height = w, h; buttons[#buttons + 1] = b; return b
end}
CreateTrigger, CreateTimer = function() return {} end, function() return {} end
local frame_triggers = {}
BlzTriggerRegisterFrameEvent = function(trigger, f, event)
    frame_triggers[f] = frame_triggers[f] or {}
    frame_triggers[f][event] = trigger
end
TriggerAddAction = function(trigger, action) trigger.action = action end
local drag_tick
TimerStart = function(_, period, repeating, callback)
    assert(period == 1 / 32 and repeating); drag_tick = callback
end
AddToEsc = function() end
local mouse_x, mouse_y, wheel_delta = 400, 300, 1
BlzGetMouseScreenPosX, BlzGetMouseScreenPosY = function() return mouse_x end, function() return mouse_y end
BlzGetLocalClientWidth, BlzGetLocalClientHeight = function() return 800 end, function() return 600 end
BlzPixelToFrameX, BlzPixelToFrameY = function(x) return x / 1000 end, function(y) return y / 1000 end
BlzGetTriggerFrameValue = function() return wheel_delta end
EVENT_ON_M1_DOWN, EVENT_ON_M2_DOWN, EVENT_ON_M1_UP, EVENT_ON_M2_UP = {}, {}, {}, {}
for _, event in ipairs({EVENT_ON_M1_DOWN, EVENT_ON_M2_DOWN, EVENT_ON_M1_UP, EVENT_ON_M2_UP}) do
    event.actions = {}
    event.register_action = function(self, pid, action) self.actions[pid] = action end
end
local has_node = Perks.hasNode
Perks.hasNode = function(...) calls.allocation = calls.allocation + 1; return has_node(...) end
CloseAllWindows = function() end
run('cotlua/src/ui/dialogs/perk_tree.lua')
PerkTree.display(1)
assert(buttons[1].frame.visible and buttons[1].frame.width > .025,
    'Initial view squeezed the root to an unusable overview size')
local function assert_label_clearance()
    for _, label in ipairs(frames) do
        if label.kind == 'TEXT' and label.level == 34 and label.visible then
            for id = 1, #nodes do
                local f = buttons[id].frame
                if f.visible then
                    assert(math.abs(label.x - f.x) >= (label.width + f.width) / 2
                        or math.abs(label.y - f.y) >= (label.height + f.height) / 2,
                        'Branch label overlaps node ' .. id)
                end
            end
        end
    end
end
assert_label_clearance()
local function click_label(label)
    for _, b in ipairs(buttons) do
        if b.label == label then clicked = b.frame; b.action(); assert(b.frame.enabled); return end
    end
    error('Missing branch navigation: ' .. label)
end
click_label('All')
for id = 1, #nodes do assert(buttons[id].frame.visible, 'Overview clipped a node: ' .. id) end
for _, branch in ipairs(Perks.getBranches()) do
    click_label(branch.name)
    assert_label_clearance()
    for id, node in ipairs(nodes) do
        if node.branch == branch.key then assert(buttons[id].frame.visible, 'Focused branch clipped a node: ' .. id) end
    end
end
click_label('All')
for id = 1, #nodes do assert(buttons[id].frame.visible) end
assert(Perks.getSpent(1) == 0, 'Branch navigation spent perk points')
print('PASS (mocked frame calls): whole-tree overview and all four branch focuses fit every node; navigation restores keyboard focus and never allocates points.')

-- Local UI sends a request; only receipt on all clients may spend points.
clicked = buttons[10].frame; buttons[10].action()
assert(pending_sync == '10' and Perks.getSpent(1) == 0)
sync_callback(); assert(Perks.hasNode(1, 10) and Perks.getSpent(1) == 1)
pending_sync = nil
GetLocalPlayer = function() return 1 end
buttons[102].action()
assert(pending_sync == nil and Perks.getSpent(1) == 1, 'Remote client emitted a local UI request')
pending_sync = '102'; sync_callback()
assert(Perks.hasNode(1, 102), 'Remote client failed to apply synchronized allocation')
GetLocalPlayer = function() return 0 end
for _, malformed in ipairs({'0', '1', '242', '2.5', 'nan', 'not_a_node'}) do
    pending_sync = malformed; sync_callback(); assert(Perks.getSpent(1) == 2)
end
Profile[1].perk_reset_available = 1
pending_sync = 'reset'; sync_callback(); assert(Perks.getSpent(1) == 0)
print('PASS: local/remote allocation requests, synchronized reset, and malformed-request validation.')

-- Tutorial uses the normal origin zoom, even after selecting All/another branch.
click_label('All'); PerkTree.previewTutorial(1, true)
local root = buttons[1].frame
assert(math.abs(root.width - nodes[1].icon_size * .85) < 1e-9)
local expected_x, expected_y = root.x, root.y
local input
for _, f in ipairs(frames) do if f.kind == 'GLUEBUTTON' then input = f end end
assert(input and input.enabled and frame_triggers[input][FRAMEEVENT_MOUSE_WHEEL], 'Background cannot receive wheel input')
assert(root.parent.enabled and root.parent.level > input.level,
    'Node canvas is disabled or below the mouse input catcher')
assert(buttons[2].tip and buttons[2].frame.level > root.parent.level, 'Node tooltip/button layer missing')
local function wheel(f, delta)
    clicked, wheel_delta = f, delta
    frame_triggers[f][FRAMEEVENT_MOUSE_WHEEL].action()
    assert(f.enabled, 'Wheel handler retained disabled input')
end
local width = root.width
wheel(input, 1); assert(math.abs(root.width - width * 1.10) < 1e-9)
width = root.width
wheel(buttons[46].frame, -1); assert(math.abs(root.width - width * .90) < 1e-9)
pending_sync = nil; clicked = buttons[46].frame; buttons[46].action()
assert(pending_sync == nil and Perks.getSpent(1) == 0, 'Tutorial zoom enabled allocation')

-- Native frame-focus changes may briefly move/lose the screen cursor.
PerkTree.previewTutorial(1, true)
local enable = BlzFrameSetEnable
BlzFrameSetEnable = function(f, enabled)
    enable(f, enabled)
    if not enabled then mouse_x, mouse_y = -1, -1 end
end
mouse_x, mouse_y = 400, 300
width = root.width; wheel(input, 1)
assert(math.abs(root.width - width * 1.10) < 1e-9)
assert(math.abs(root.y - (expected_y + (expected_y - .300) * .10)) < 1e-9,
    'Wheel cursor was captured after the focus reset')
BlzFrameSetEnable = enable
PerkTree.previewTutorial(1, true)
mouse_x, mouse_y = -1, -1
width = root.width; wheel(input, 1)
assert(math.abs(root.width - width * 1.10) < 1e-9)
assert(math.abs(root.x - expected_x) < 1e-9 and math.abs(root.y - expected_y) < 1e-9,
    'Invalid cursor did not fall back to centered zoom')
width = root.width; wheel(input, 0); assert(root.width == width)
GetLocalPlayer = function() return 1 end
wheel(input, 1); assert(root.width == width, 'Remote client changed local zoom')
GetLocalPlayer = function() return 0 end
PerkTree.previewTutorial(1, false)
width = root.width; wheel(input, 1); assert(root.width == width, 'Closed tree still accepts wheel input')
PerkTree.previewTutorial(1, true)
assert(math.abs(root.width - nodes[1].icon_size * .85) < 1e-9, 'Revisited tutorial retained overview/scroll zoom')
PerkTree.previewTutorial(1, false)
print('PASS (mocked frame events): tutorial origin zoom, wheel over background/nodes, focus-reset cursor capture, invalid-cursor fallback, local-only/closed guards, and blocked allocations.')

-- Native mutation budget: steady panning is one parent translation, not a
-- full icon/anchor/style rebuild; stationary ticks do absolutely no UI work.
PerkTree.previewTutorial(1, true)
mouse_x, mouse_y = 400, 300
EVENT_ON_M1_DOWN.actions[1](1)
local function clear_calls() for key in pairs(calls) do calls[key] = 0 end end
clear_calls()
for _ = 1, 20 do drag_tick() end
for key, count in pairs(calls) do assert(count == 0, 'Stationary drag performed ' .. key .. ' updates') end
local before_root = root.x
for _ = 1, 10 do mouse_x = mouse_x + 1; drag_tick() end
assert(calls.abs == 10 and calls.node_point == 0 and calls.point < 200 and calls.size == calls.point,
    'Small pan rebuilt nodes or excessive connector geometry instead of translating the canvas')
assert(calls.icon == 0 and calls.color == 0 and calls.text == 0 and calls.allocation == 0,
    'Small pan reapplied textures/styles or rescanned allocation state')
assert(math.abs(root.x - before_root - .010) < 1e-9, 'Children did not follow canvas pan')
EVENT_ON_M1_UP.actions[1](1)
local connectors, viewport = {}, nil
for _, f in ipairs(frames) do
    if f.texture == 'replaceabletextures\\teamcolor\\teamcolor08' then connectors[#connectors + 1] = f end
    if f.texture == 'UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp' then viewport = f end
end
assert(viewport)
local offscreen_connections = 0
local function check_connector_clipping(expected_zoom)
    local index, scale = 1, expected_zoom and .065 * expected_zoom
    for id, button in ipairs(buttons) do
        if not scale and id <= #nodes and button.frame.visible then
            scale = .065 * button.frame.width / nodes[id].icon_size
            break
        end
    end
    assert(scale, 'Clipping test requires a visible node to measure current zoom')
    local ox, oy = root.x, root.y
    local function check_leg(x, y, w, h, endpoints_visible)
        local f = assert(connectors[index]); index = index + 1
        local left, right = math.max(x - w / 2, viewport.x), math.min(x + w / 2, viewport.x + viewport.width)
        local bottom, top = math.max(y - h / 2, viewport.y - viewport.height), math.min(y + h / 2, viewport.y)
        local expected = w > .000001 and h > .000001 and right > left and top > bottom
        assert(f.visible == expected, 'Connector ' .. (index - 1) .. ' culled by endpoints instead of viewport intersection')
        if expected then
            assert(math.abs(f.x - (left + right) / 2) < 1e-9 and math.abs(f.y - (bottom + top) / 2) < 1e-9
                and math.abs(f.width - (right - left)) < 1e-9 and math.abs(f.height - (top - bottom)) < 1e-9,
                'Connector geometry escapes the viewport or clips too soon')
            if not endpoints_visible then offscreen_connections = offscreen_connections + 1 end
        end
    end
    for _, node in ipairs(nodes) do
        for _, parent_id in ipairs({node.parent or false, node.alternate_parent or false}) do
            if parent_id then
                local both_visible = buttons[node.id].frame.visible or buttons[parent_id].frame.visible
                local thickness = math.max(.0008, .0014 * scale / .065)
                local route = node.routes[parent_id]
                for segment = 1, #route - 1 do
                    local a, b = route[segment], route[segment + 1]
                    local dx, dy = math.abs(a[1] - b[1]) * scale, math.abs(a[2] - b[2]) * scale
                    local horizontal = dx > .000001
                    check_leg(ox + (a[1] + b[1]) / 2 * scale, oy + (a[2] + b[2]) / 2 * scale,
                        horizontal and dx or thickness, horizontal and thickness or dy, both_visible)
                end
            end
        end
    end
    assert(index == #connectors + 1)
end
check_connector_clipping(.85)
for _ = 1, 4 do
    mouse_x, mouse_y = 400, 300; EVENT_ON_M1_DOWN.actions[1](1)
    mouse_x, mouse_y = 200, 220; drag_tick(); EVENT_ON_M1_UP.actions[1](1)
    check_connector_clipping(.85)
end
-- Center the longest corridor, rather than relying on the previous layout's
-- fixed pan offsets to happen to put both endpoint icons outside the window.
local longest, midpoint = 0, nil
for _, node in ipairs(nodes) do
    for _, route in pairs(node.routes or {}) do
        for index = 1, #route - 1 do
            local a, b = route[index], route[index + 1]
            local length = math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
            if length > longest then longest, midpoint = length, {(a[1] + b[1]) / 2, (a[2] + b[2]) / 2} end
        end
    end
end
local target_x = viewport.x + viewport.width / 2 - midpoint[1] * .065 * .85
local target_y = viewport.y - viewport.height / 2 - midpoint[2] * .065 * .85
for _ = 1, 60 do
    local dx, dy = target_x - root.x, target_y - root.y
    if math.abs(dx) + math.abs(dy) < 1e-8 then break end
    mouse_x, mouse_y = 400, 300; EVENT_ON_M1_DOWN.actions[1](1)
    mouse_x = 400 + math.max(-.15, math.min(.15, dx)) * 1000
    mouse_y = 300 + math.max(-.15, math.min(.15, dy)) * 1000
    drag_tick(); EVENT_ON_M1_UP.actions[1](1)
end
check_connector_clipping(.85)
assert(offscreen_connections > 0, 'Missing coverage for a connector with both endpoint icons offscreen')
wheel(input, 1); check_connector_clipping(.85 * 1.10)
click_label('All'); check_connector_clipping()
for _, button in ipairs(buttons) do
    if button.tip == 'Fullscreen' then
        clicked = button.frame; button.action(); check_connector_clipping()
        clicked = button.frame; button.action(); check_connector_clipping()
        break
    end
end
print('PASS: long connections remain visible with both endpoint icons offscreen; every segment clips exactly to viewport bounds during panning.')
PerkTree.previewTutorial(1, false)
print('PASS (mocked native-call budget): stationary ticks do no UI work; panning translates the canvas, updates only clipped connector geometry, and performs no node-anchor/style/allocation rebuilds.')
