-- One local presentation shared by the HUD reminder and permanent Stats entry.
OnInit.final("StatAllocationUI", function(Require)
    Require('StatAllocation')
    Require('StatAllocationModel')
    Require('Frames')
    Require('FrameHelpers')
    Require('Hotkeys')
    Require('PlayerSync')
    Require('SimpleButton')
    Require('Inspect')
    StatAllocationUI = {}
    local UI, A, M = StatAllocationUI, StatAllocation, StatAllocationModel
    local states, preview, ratio, reset_armed = {}, {}, {}, {}
    local refresh
    -- Allocate sound handles on every client, never during a local UI click.
    local click_sound = CreateSound("Sound\\Interface\\MouseClick1.wav", false, false, false, 0, 0, "")
    local apply_sound = CreateSound("Abilities\\Spells\\Items\\AIam\\HeroSkillUp.wav", false, false, false, 0, 0, "")
    local error_sound = CreateSound("Sound\\Interface\\Error.wav", false, false, false, 0, 0, "")
    local function play(pid, sound)
        -- Let reusable feedback finish naturally. Forced stop/start cycles
        -- exercise the sound-manager path implicated in the 3.0.0 crash report.
        if GetLocalPlayer() == Player(pid - 1) and not GetSoundIsPlaying(sound) then
            StartSound(sound)
        end
    end
    function UI.playClick(pid) play(pid, click_sound) end
    local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
    local frame = BlzCreateFrame("EscMenuBackdrop", parent, 0, 0)
    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPRIGHT, .79, .55)
    BlzFrameSetSize(frame, .32, .27)
    BlzFrameSetLevel(frame, 60)
    BlzFrameSetVisible(frame, false)
    local function state(pid)
        if not states[pid] then states[pid] = {open = false, step = 1, draft = {0, 0, 0}} end
        return states[pid]
    end
    local function text(x, y, width, height)
        local value = BlzCreateFrameByType("TEXT", "", frame, "", 0)
        BlzFrameSetPoint(value, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetSize(value, width, height)
        BlzFrameSetEnable(value, false)
        return value
    end
    local function button(owner, label, x, y, width, callback)
        local value = BlzCreateFrameByType("GLUETEXTBUTTON", "", owner, "ScriptDialogButton", 0)
        BlzFrameSetPoint(value, FRAMEPOINT_TOPLEFT, owner, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetSize(value, width, .024)
        BlzFrameSetText(value, label)
        local trigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigger, value, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigger, function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            if GetLocalPlayer() ~= Player(pid - 1) then return end
            local f = BlzGetTriggerFrame()
            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
            UI.playClick(pid)
            callback(pid)
        end)
        return value
    end
    local function capture(pid)
        local s, data = state(pid), A.get(pid)
        s.draft = {0, 0, 0}
        s.generation, s.revision = A.getGeneration(pid), data and data.revision or 0
        if data then
            for i = 1, 3 do if ratio[i] then BlzFrameSetText(ratio[i], tostring(data.ratio[i])) end end
        end
    end
    local function send(pid, kind, payload)
        if preview[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        BlzSendSyncData("stat_alloc", kind .. ":" .. A.getGeneration(pid) .. ":" .. payload)
    end
    function UI.close(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        state(pid).open = false
        reset_armed[pid] = nil
        capture(pid)
        BlzFrameSetVisible(frame, false)
    end
    function UI.open(pid)
        if GetLocalPlayer() ~= Player(pid - 1) or not A.get(pid) then return end
        state(pid).open = true
        capture(pid)
        refresh(pid)
    end
    function UI.isOpen(pid) return state(pid).open end
    AddToEsc(UI.close)
    SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        .018, .018, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.04, -.04, function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            UI.playClick(pid)
            UI.close(pid)
            return false
        end, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., .01)
    local available = text(.03, -.028, .23, .018)
    local note = text(.03, -.05, .226, .028)
    local steps = {}
    for index, amount in ipairs({1, 5, 10, 100, 0}) do
        steps[index] = button(frame, amount == 0 and "All" or "+" .. amount,
            .03 + (index - 1) * .053, -.082, .048, function(pid)
                state(pid).step = amount; refresh(pid)
            end)
    end
    local rows, plus, minus = {}, {}, {}
    local function remaining(pid)
        local s = state(pid)
        local total = preview[pid] and 8 or A.available(pid)
        for i = 1, 3 do total = total - s.draft[i] end
        return math.max(0, total)
    end
    local function adjust(pid, index, direction)
        local s = state(pid)
        local count = direction > 0 and remaining(pid) or s.draft[index]
        if s.step ~= 0 then count = math.min(count, s.step) end
        s.draft[index] = s.draft[index] + direction * count
        refresh(pid)
    end
    for i = 1, 3 do
        local index = i
        local y = -.118 - (i - 1) * .033
        rows[i] = text(.03, y, .18, .029)
        minus[i] = button(frame, "-", .216, y, .03, function(pid) adjust(pid, index, -1) end)
        plus[i] = button(frame, "+", .26, y, .03, function(pid) adjust(pid, index, 1) end)
    end
    local apply = button(frame, "Apply", .03, -.222, .123, function(pid)
        local s = state(pid)
        send(pid, "apply", s.revision .. ":" .. table.concat(s.draft, ":"))
    end)
    local reset
    reset = button(frame, "Reset in Town", .164, -.222, .126, function(pid)
        if preview[pid] then return end
        if not reset_armed[pid] then
            reset_armed[pid] = A.resetCost(pid)
            BlzFrameSetText(reset, "Pay " .. reset_armed[pid] .. " Gold")
            return
        end
        local cost = reset_armed[pid]
        reset_armed[pid] = nil
        send(pid, "reset", tostring(cost))
    end)
    local reset_tip = FrameAddSimpleTooltip(reset, "Reset allocations", "", true)
    local auto_label = text(.03, -.26, .26, .018)
    local auto_frames = {auto_label}
    for i, name in ipairs({"STR", "AGI", "INT"}) do
        local x = .03 + (i - 1) * .089
        local label = text(x, -.288, .03, .016)
        BlzFrameSetText(label, name)
        ratio[i] = BlzCreateFrame("EscMenuEditBoxTemplate", frame, 0, 0)
        BlzFrameSetPoint(ratio[i], FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, x + .03, -.282)
        BlzFrameSetSize(ratio[i], .052, .027)
        BlzFrameSetText(ratio[i], tostring(i == 3 and 8 or 1))
        auto_frames[#auto_frames + 1] = label
        auto_frames[#auto_frames + 1] = ratio[i]
    end
    local toggle = button(frame, "Enable Plan", .03, -.319, .123, function(pid)
        local data = A.get(pid)
        local values = {}
        for i = 1, 3 do
            local value = tonumber(BlzFrameGetText(ratio[i]))
            if not value or value % 1 ~= 0 or value < 0 or value > 100 then
                DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 5., "Use ratio weights from 0 to 100.")
                return
            end
            values[i] = value
        end
        send(pid, "plan", (data and data.automatic == 1 and "0" or "1") .. ":" .. table.concat(values, ":"))
    end)
    local save_ratio = button(frame, "Save Ratio", .164, -.319, .126, function(pid)
        local data = A.get(pid)
        local values = {}
        for i = 1, 3 do
            local value = tonumber(BlzFrameGetText(ratio[i]))
            if not value or value % 1 ~= 0 or value < 0 or value > 100 then return end
            values[i] = value
        end
        send(pid, "plan", (data and data.automatic or 0) .. ":" .. table.concat(values, ":"))
    end)
    auto_frames[#auto_frames + 1] = toggle
    auto_frames[#auto_frames + 1] = save_ratio
    for _, control in ipairs(auto_frames) do BlzFrameSetVisible(control, false) end
    -- Inspect icons are .032 wide and spaced .039 apart from this anchor.
    -- Keep the HUD reminder below native and inspected-spell tooltips. Its
    -- screen anchor stays with Inspect; its render parent is the console.
    local reminder = SimpleButton.create(BlzGetFrameByName("ConsoleUIBackdrop", 0),
        "ReplaceableTextures\\CommandButtons\\BTNStatUp.blp", .027, .027,
        FRAMEPOINT_BOTTOM, FRAMEPOINT_TOPLEFT, (.039 + .032) * .5, .03, function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        UI.playClick(pid)
        UI.open(pid)
        return false
    end, "Allocate Stats", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., .01)
    BlzFrameClearAllPoints(reminder.frame)
    BlzFrameSetPoint(reminder.frame, FRAMEPOINT_BOTTOM, INSPECT_HUD_ANCHOR,
        FRAMEPOINT_TOPLEFT, (.039 + .032) * .5, .03)
    reminder:visible(false)
    refresh = function(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local s, data = state(pid), A.get(pid)
        local points = A.available(pid)
        reminder:visible(not preview[pid] and data ~= nil and points > 0)
        reminder:setTooltipText("Allocate Stats\n" .. points .. " stat points remaining.")
        if data and (s.generation ~= A.getGeneration(pid) or s.revision ~= data.revision) then capture(pid) end
        if not data and not preview[pid] then s.open = false end
        BlzFrameSetVisible(frame, s.open or preview[pid] == true)
        if not s.open and not preview[pid] then return end
        BlzFrameSetText(available, "|cffffcc00" .. remaining(pid) .. "|r stat points available")
        BlzFrameSetText(note, "Each point adds one base stat. Preview, then Apply.")
        local definition = data and HERO_STATS[Profile[pid].hero.unit_id]
        for i, name in ipairs({"Strength", "Agility", "Intelligence"}) do
            local n = s.draft[i]
            local allocation = data and data.flat[i] or 0
            local starting = definition and definition[({"str", "agi", "int"})[i]] or 10
            local value = M.value(starting, allocation)
            local preview_value = M.value(starting, allocation + n)
            BlzFrameSetText(rows[i], name .. ": " .. value
                .. (n > 0 and " |cff80ff80-> " .. preview_value .. "|r" or ""))
            BlzFrameSetEnable(plus[i], remaining(pid) > 0 and not preview[pid])
            BlzFrameSetEnable(minus[i], n > 0 and not preview[pid])
        end
        for i, amount in ipairs({1, 5, 10, 100, 0}) do BlzFrameSetEnable(steps[i], s.step ~= amount) end
        local total = 0
        for _, n in ipairs(s.draft) do total = total + n end
        BlzFrameSetEnable(apply, total > 0 and not preview[pid])
        local automation = data ~= nil and A.hasAutomation(pid) and not preview[pid]
        for _, control in ipairs(auto_frames) do BlzFrameSetVisible(control, automation) end
        BlzFrameSetSize(frame, .32, automation and .36 or .27)
        BlzFrameSetText(auto_label, "|cffffcc00Automatic allocation ratio|r")
        BlzFrameSetText(toggle, data and data.automatic == 1 and "Pause Plan" or "Enable Plan")
        BlzFrameSetEnable(toggle, automation)
        BlzFrameSetEnable(save_ratio, automation)
        BlzFrameSetEnable(reset, not preview[pid] and A.canReset(pid))
        local cost = A.resetCost(pid)
        BlzFrameSetText(reset_tip.tooltip, "Reset in town for " .. cost .. " Gold.\nRefunds assigned points and clears the ratio.")
        if reset_armed[pid] and reset_armed[pid] ~= cost then reset_armed[pid] = nil end
        if not reset_armed[pid] then BlzFrameSetText(reset, "Reset in Town") end
    end
    function UI.getTutorialFrame() return frame end
    function UI.previewTutorial(pid, visible)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        preview[pid] = visible or nil
        state(pid).open = visible
        capture(pid)
        refresh(pid)
    end
    local function parse(payload)
        local result = {}
        for part in payload:gmatch("[^:]+") do
            if not part:match("^%d+$") or #part > 10 then return nil end
            result[#result + 1] = tonumber(part)
        end
        return result
    end
    SyncCallback("stat_alloc", function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local kind, payload = BlzGetTriggerSyncData():match("^(%a+):(.+)$")
        local values = payload and parse(payload)
        if not values then return end
        local success, reason
        if kind == "apply" and #values == 5 then
            success, reason = A.commit(pid, values[1], values[2],
                {values[3], values[4], values[5]})
        elseif kind == "plan" and #values == 5 then
            success, reason = A.setPlan(pid, values[1], values[2], {values[3], values[4], values[5]})
        elseif kind == "reset" and #values == 2 then
            success, reason = A.reset(pid, values[1], values[2])
        else return end
        if success then
            play(pid, kind == "apply" and apply_sound or click_sound)
        else
            play(pid, error_sound)
            if reason then DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 5., reason) end
        end
        refresh(pid)
    end)
    A.registerChangedAction(refresh)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid, function()
            if GetLocalPlayer() == Player(pid - 1) then
                states[pid], preview[pid], reset_armed[pid] = nil, nil, nil
                refresh(pid)
            end
        end)
    end
end, Debug and Debug.getLine())
