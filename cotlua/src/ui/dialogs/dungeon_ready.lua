-- Standalone live party readiness view. Gameplay owns the roster and validation.
OnInit.final('DungeonReadyView', function(Require)
    Require('Dungeons')
    Require('Frames')
    Require('SimpleButton')
    Require('PlayerSync')
    Require('Hotkeys')
    Require('Users')

    DungeonReadyView = {}
    local closed, last_queue
    local frame = BlzCreateFrame('ListBoxWar3', BlzGetFrameByName('ConsoleUIBackdrop', 0), 0, 0)
    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, .4, .52)
    BlzFrameSetSize(frame, .34, .30)
    BlzFrameSetLevel(frame, 15)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetVisible(frame, false)
    local function text(y, width, height)
        local f = BlzCreateFrameByType('TEXT', '', frame, '', 0)
        BlzFrameSetPoint(f, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, .018, y)
        BlzFrameSetSize(f, width, height)
        BlzFrameSetEnable(f, false)
        return f
    end
    local title = text(-.018, .275, .022)
    local hint = text(-.049, .30, .032)
    BlzFrameSetScale(hint, .9)
    local rows = {}
    for i = 1, PLAYER_CAP do rows[i] = text(-.086 - (i - 1) * .024, .30, .021) end
    local function close(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            closed = true
            BlzFrameSetVisible(frame, false)
        end
    end
    local ready, start
    local function send(action)
        local player = GetTriggerPlayer()
        local clicked = BlzGetTriggerFrame()
        BlzFrameSetEnable(clicked, false)
        BlzFrameSetEnable(clicked, true)
        if GetLocalPlayer() == player and QUEUE_DUNGEON then
            BlzSendSyncData('dungeon_ready', action .. ':' .. tostring(QUEUE_DUNGEON.id))
        end
        return false
    end
    local function text_button(point, x, action)
        local button = BlzCreateFrameByType('GLUETEXTBUTTON', '', frame, 'ScriptDialogButton', NextFrameCreateContext())
        BlzFrameSetSize(button, .13, .027)
        BlzFrameSetPoint(button, point, frame, point, x, .018)
        local trigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigger, button, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddCondition(trigger, Condition(function() return send(action) end))
        return {frame = button, text = function(_, value) BlzFrameSetText(button, value) end}
    end
    ready = text_button(FRAMEPOINT_BOTTOMLEFT, .02, 'ready')
    start = text_button(FRAMEPOINT_BOTTOMRIGHT, -.02, 'start')
    ready:text('Ready'); start:text('Start')
    SimpleButton.create(frame, 'ReplaceableTextures\\CommandButtons\\BTNCancel.blp', .018, .018,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.012, -.012, function()
            local clicked = BlzGetTriggerFrame()
            BlzFrameSetEnable(clicked, false); BlzFrameSetEnable(clicked, true)
            close(GetPlayerId(GetTriggerPlayer()) + 1)
            return false
        end, 'Close (readiness unchanged)')
    local function refresh(open_pid)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        local dungeon = QUEUE_DUNGEON
        if last_queue ~= dungeon then closed = false; last_queue = dungeon end
        if open_pid == pid then closed = false end
        local member = dungeon and TableHas(QUEUE_GROUP, pid)
        BlzFrameSetVisible(frame, member and not closed or false)
        if not member then return end
        BlzFrameSetText(title, '|cffffcc00' .. dungeon.name .. '|r')
        BlzFrameSetText(hint, dungeon.starting and 'Setting out...'
            or 'Nearby heroes join automatically. Everyone must be ready.')
        for i = 1, PLAYER_CAP do
            local id = QUEUE_GROUP[i]
            local user = id and User[id - 1]
            BlzFrameSetText(rows[i], id and ((user and user.nameColored or GetPlayerName(Player(id - 1)))
                .. (QUEUE_READY[id] and '  |cff33ff66Ready|r' or '  |cffffcc00Not Ready|r')) or '')
        end
        ready:text(QUEUE_READY[pid] and 'Not Ready' or 'Ready')
        local all_ready = #QUEUE_GROUP > 0
        for _, id in ipairs(QUEUE_GROUP) do all_ready = all_ready and QUEUE_READY[id] end
        BlzFrameSetEnable(ready.frame, not dungeon.starting)
        BlzFrameSetEnable(start.frame, all_ready and not dungeon.starting)
    end
    function DungeonReadyView.open(pid)
        if GetLocalPlayer() == Player(pid - 1) then closed = false; refresh() end
    end
    DungeonReadyView.close = close
    Dungeon.subscribeQueue(refresh)
    AddToEsc(close)
    SyncCallback('dungeon_ready', function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local action, id = BlzGetTriggerSyncData():match('^(%a+):(.+)$')
        local dungeon = QUEUE_DUNGEON
        if not dungeon or tostring(dungeon.id) ~= id then return false end
        if action == 'ready' then Dungeon.setReady(pid, not QUEUE_READY[pid])
        elseif action == 'start' then
            local ok, reason = dungeon:requestStart(pid)
            if not ok and reason then DisplayTextToPlayer(Player(pid - 1), 0, 0, reason) end
        end
        return false
    end)
end, Debug and Debug.getLine())
