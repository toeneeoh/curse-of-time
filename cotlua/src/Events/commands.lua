--[[
    commands.lua

    A library that defines player chat commands
]]

OnInit.final("Commands", function(Require)
    Require('Users')
    Require('Profile')
    Require('Frames')

    local vote_yay  = 0
    local vote_nay  = 0
    local vk_target = 0
    local vk_source = 0
    local HINT_PLAYERS = {}

    IS_AUTO_ATTACK_OFF = {} ---@type boolean[] 
    IS_BASE_DESTROYED  = {} ---@type boolean[] 

    local VOTING_TYPE = 0
    local I_VOTED     = {} ---@type boolean[] 

    local CMD_LIST
    local votekick_panel_click
    local roll_function

    function GetCommandList() -- TODO: use?
        return CMD_LIST
    end

    CMD_LIST = {
        ["-commands"] = function(p, pid, args)
            DisplayTimedTextToPlayer(p, 0, 0, 30, "|cffffcc00Commands are located in F9.|r")
        end,
        ["-stats"] = function(p, pid, args)
            local tpid = tonumber(args[2])

            tpid = tpid or GetPlayerId(p) + 1

            STAT_WINDOW.display(Hero[tpid] or PLAYER_SELECTED_UNIT[tpid], pid)
        end,
        ["-clear"] = function(p, pid, args)
            if p == GetLocalPlayer() then
                ClearTextMessages()
            end
        end,
        ["-suicide"] = function(p, pid, args)
            reselect(Hero[pid])
            KillUnit(Hero[pid])
        end,
        ["-proficiency"] = function(p, pid, args)
            for i, _ in ipairs(PROF) do
                DisplayTimedTextToPlayer(p, 0, 0, 30, TYPE_NAME[i] .. ((HasProficiency(pid, PROF[i]) and " - |cffFF0909Y|r") or " - |cff00ff33X|r"))
            end
        end,
        ["-tome"] = function(p, pid, args)
            local unit = Unit[Hero[pid]]
            local stats = unit.str + unit.agi + unit.int

            DisplayTextToPlayer(p, 0, 0, "|cffffcc00Total Stats:|r " .. stats)
            DisplayTextToPlayer(p, 0, 0, "|cffffcc00Tome Cap:|r " .. TomeCap(GetHeroLevel(Hero[pid])))
        end,
        ["-ready"] = function(p, pid, args)
            QUEUE_READY[pid] = true
        end,
        ["-color"] = function(p, pid, args)
            local num = tonumber(args[2])

            if num and num > 0 and num < 26 then
                User[p].color = ConvertPlayerColor(num - 1)
                User[p].hex = OriginalHex[num]
                User[p]:colorUnits()
                User[p].nameColored = OriginalHex[num] .. GetPlayerName(p) .. "|r"
                SetPlayerColor(p, ConvertPlayerColor(num - 1))
            end
        end,
        ["-roll"] = function(p, pid, args)
            roll_function(pid)
        end,
        ["-p"] = function(p, pid, args)
            if GetCurrency(pid, PLATINUM) > 0 then
                AddCurrency(pid, PLATINUM, -1)
                AddCurrency(pid, GOLD, 1000000)
                DisplayTimedTextToPlayer(p, 0, 0, 10, PlatTag .. (GetCurrency(pid, PLATINUM)))
            else
                DisplayTimedTextToPlayer(p, 0, 0, 20, "You need 1 Platinum Coin to buy this")
            end
        end,
        ["-flee"] = function(p, pid, args)
            FleeCommand(p)
        end,
        ["-cam"] = function(p, pid, args)
            if args[2] then
                local _, _, zoom, lock = args[2]:find("(\x25d+)\x25s.([lL])")

                if zoom then
                    if lock == "l" then
                        SetCameraLocked(pid, true)
                    end
                    ZOOM[pid] = MathClamp(tonumber(zoom), 100, 3000)
                end
            end
        end,
        ["-zml"] = function(p, pid, args, cmd)
            local _, _, lock = cmd:find("[lL]$")
            if lock == "l" then
                SetCameraLocked(pid, true)
            end
            ZOOM[pid] = 2500
        end,
        ["-lock"] = function(p, pid, args)
            SetCameraLocked(pid, true)
        end,
        ["-unlock"] = function(p, pid, args)
            SetCameraLocked(pid, false)
        end,
        ["-new"] = function(p, pid, args)
            Profile.new(pid)
        end,
        ["-info"] = function(p, pid, args)
            local index = (args[2] and S2I(args[2])) or 1
            DisplayTimedTextToPlayer(p, 0, 0, 30, infoString[index])
        end,
        ["-unstuck"] = function(p, pid, args)
            if GetLocalPlayer() == p then
                ShowInterface(false, 0)
                EnableUserControl(false)
                EnableOcclusion(false)
            end
            TimerQueue:callDelayed(0.5, function()
                if GetLocalPlayer() == p then
                    ShowInterface(true, 0)
                    EnableUserControl(true)
                    EnableOcclusion(true)
                end
            end)
        end,
        ["-st"] = function(p, pid, args)
            if Profile[pid] then
                Profile[pid]:saveCooldown()
            end
        end,
        ["-restime"] = function(p, pid, args)
            if RECHARGE_COOLDOWN[pid] <= 0. then
                DisplayTimedTextToPlayer(p, 0, 0, 20, "You can recharge.")
            else
                DisplayTimedTextToPlayer(p, 0, 0, 20, (RECHARGE_COOLDOWN[pid]) .. " seconds until you can recharge again.")
            end
        end,
        ["-autosave"] = function(p, pid, args)
            if Profile[pid] then
                Profile[pid]:toggleAutoSave()
            end
        end,
        ["-votekick"] = function(p, pid, args)
            if VOTING_TYPE == 0 and User.AmountPlaying > 2 then
                local dw = DialogWindow.create(pid, "", votekick_panel_click) ---@type DialogWindow
                local U = User.first

                while U do

                    if pid ~= U.id then
                        dw:addButton(U.nameColored, U.id)
                    end

                    U = U.next
                end
            end
        end,
        ["-repick"] = function(p, pid, args)
            if Profile[pid] then
                if Profile[pid]:getSlotsUsed() >= MAX_SLOTS then
                    DisplayTimedTextToPlayer(p, 0, 0, 30.0, "You cannot save more than " .. MAX_SLOTS .. " heroes!")
                else
                    Profile[pid]:repick()
                end
            end
        end,
        ["-quests"] = function(p, pid, args)
            DisplayQuestProgress(pid)
        end,
        ["-hints"] = function(p, pid, args)
            if TableHas(HINT_PLAYERS, pid) then
                TableRemove(HINT_PLAYERS, pid)
                DisplayTimedTextToPlayer(p, 0, 0, 10, "Hints turned off.")
            else
                HINT_PLAYERS[#HINT_PLAYERS + 1] = pid
                DisplayTimedTextToPlayer(p, 0, 0, 10, "Hints turned on.")
            end
        end,
    }

    --alternate syntax
    CMD_LIST["-cl"] = CMD_LIST["-clear"]
    CMD_LIST["-clr"] = CMD_LIST["-clear"]

    CMD_LIST["-pf"] = CMD_LIST["-proficiency"]
    CMD_LIST["-prof"] = CMD_LIST["-proficiency"]

    CMD_LIST["-r"] = CMD_LIST["-ready"]

    CMD_LIST["-zm"] = CMD_LIST["-zml"]

    CMD_LIST["-newprofile"] = CMD_LIST["-new"]

    CMD_LIST["-savetime"] = CMD_LIST["-st"]

    CMD_LIST["-rt"] = CMD_LIST["-restime"]

    CMD_LIST["-q"] = CMD_LIST["-quests"]

    CMD_LIST["-nohints"] = CMD_LIST["-hints"]

local function ResetVote()
    vote_yay = 0
    vote_nay = 0

    for i = 1, PLAYER_CAP do
        I_VOTED[i] = false
    end
end

local function votekick()
    ResetVote()
    VOTING_TYPE = 2
    vote_yay = 1
    vote_nay = 1
    DisplayTimedTextToForce(FORCE_PLAYING, 30, "Voting to kick player " + User[vk_target - 1].nameColored .. " has begun.")
    BlzFrameSetTexture(VOTING_BACKDROP, "war3mapImported\\afkUI_3.dds", 0, true)

    local id = GetPlayerId(GetLocalPlayer()) + 1

    if id ~= vk_target and id ~= vk_source then
        BlzFrameSetVisible(VOTING_BACKDROP, true)
    end
end

---@return boolean
votekick_panel_click = function()
    local pid   = GetPlayerId(GetTriggerPlayer()) + 1
    local dw    = DialogWindow[pid]
    local index = dw:getClickedIndex(GetClickedButton())

    if index ~= -1 then
        if VOTING_TYPE == 0 then
            vk_target = dw.data[index]
            vk_source = pid
            votekick()
        end

        dw:destroy()
    end

    return false
end

---@return boolean
local function VotingMenu()
    local pid = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 

    if not I_VOTED[pid] then
        I_VOTED[pid] = true
        return true
    end

    return false
end

local function check_vote()
    if VOTING_TYPE == 2 then
        if (vote_yay + vote_nay) >= User.AmountPlaying then
            VOTING_TYPE = 0

            if vote_yay > vote_nay then
                DisplayTextToForce(FORCE_PLAYING, User[vk_target - 1].nameColored .. " has been kicked from the game.")
                CustomDefeatBJ(Player(vk_target - 1), "You were vote kicked.")
            else
                DisplayTextToForce(FORCE_PLAYING, "Votekick vote failed.")
            end
        end
    end
end

local function VoteYes()
    vote_yay = vote_yay + 1

    check_vote()

    if GetLocalPlayer() == GetTriggerPlayer() then
        BlzFrameSetEnable(BlzGetTriggerFrame(), false)
        BlzFrameSetEnable(BlzGetTriggerFrame(), true)
        BlzFrameSetVisible(VOTING_BACKDROP, false)
    end
end

local function VoteNo()
    vote_nay = vote_nay + 1

    check_vote()

    if GetLocalPlayer() == GetTriggerPlayer() then
        BlzFrameSetEnable(BlzGetTriggerFrame(), false)
        BlzFrameSetEnable(BlzGetTriggerFrame(), true)
        BlzFrameSetVisible(VOTING_BACKDROP, false)
    end
end

---@type fun(p: player)
function FleeCommand(p)
    local pid = GetPlayerId(p) + 1 ---@type integer 

    if IS_IN_STRUGGLE[pid] then
        IS_FLEEING[pid] = true
        DisplayTimedTextToPlayer(p, 0, 0, 10, "You will escape once the current wave is complete.")
    elseif TableHas(GODS_GROUP, p) then
        if DeadGods == 4 then
            TableRemove(GODS_GROUP, p)
            MoveHeroLoc(pid, TOWN_CENTER)
        else
            DisplayTimedTextToPlayer(p, 0, 0, 10, "You cannot escape.")
        end
    end
end

local rolls = {}
local roll_cd = nil

local function reset_roll()
    local results = {}

    for i = 1, PLAYER_CAP do
        if rolls[i] then
            results[#results + 1] = {roll = rolls[i], player = i}
        end
        rolls[i] = nil
    end

    table.sort(results, function(a, b) return a.roll > b.roll end)

    DisplayTimedTextToForce(FORCE_PLAYING, 20., "Roll results:")
    for _, v in ipairs(results) do
        DisplayTimedTextToForce(FORCE_PLAYING, 20., User[v.player - 1].nameColored .. ": |cffffcc00" .. v.roll .. "|r")
    end
    roll_cd = nil
end

---@param pid integer
roll_function = function(pid)
    if not rolls[pid] then
        rolls[pid] = math.random(0, 100)
        DisplayTimedTextToForce(FORCE_PLAYING, 20., User[pid - 1].nameColored .. " rolled a |cffffcc00" .. rolls[pid] .. "|r!")
    end

    if not roll_cd then
        roll_cd = TimerQueue:callDelayed(20., reset_roll)
    end
end

---@type fun(): boolean
local function CustomCommands()
    local cmd = GetEventPlayerChatString() ---@type string 
    local p = GetTriggerPlayer() 
    local pid = GetPlayerId(p) + 1 ---@type integer 
    local args = {}

    --propogate args table
    for arg in cmd:gmatch("\x25S+") do
        args[#args + 1] = arg
    end

    if CMD_LIST[args[1]] then
        CMD_LIST[args[1]](p, pid, args, cmd)
    end

    return false
end

    local commands = CreateTrigger()
    local u = User.first

    while u do
        TriggerRegisterPlayerChatEvent(commands, u.player, "-", false)
        u = u.next
    end

    TriggerAddCondition(commands, Condition(CustomCommands))

    local votingSelectYes = CreateTrigger()
    local votingSelectNo = CreateTrigger()

    TriggerAddCondition(votingSelectYes, Condition(VotingMenu))
    TriggerAddAction(votingSelectYes, VoteYes)
    BlzTriggerRegisterFrameEvent(votingSelectYes, VOTING_BUTTON_FRAME, FRAMEEVENT_CONTROL_CLICK)

    TriggerAddCondition(votingSelectNo, Condition(VotingMenu))
    TriggerAddAction(votingSelectNo, VoteNo)
    BlzTriggerRegisterFrameEvent(votingSelectNo, VOTING_BUTTON_FRAME2, FRAMEEVENT_CONTROL_CLICK)
end, Debug and Debug.getLine())
