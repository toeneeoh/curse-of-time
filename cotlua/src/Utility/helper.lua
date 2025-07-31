--[[
    helper.lua

    A general purpose module with a myriad of useful helper functions and structs for use across files.
]]

OnInit.global("Helper", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local pack = string.pack
    local FPS_32 = FPS_32

    ---@class CircularArrayList
    ---@field iterator function
    ---@field data table
    ---@field add function
    ---@field add_timed function
    ---@field count integer
    ---@field START integer
    ---@field END integer
    ---@field MAXSIZE integer
    ---@field create function
    ---@field destroy function
    ---@field wipe function
    CircularArrayList = {}
    do
        local thistype = CircularArrayList
        local mt = { __index = thistype }

        function thistype:iterator()
            local index = self.START
            local count = 0

            return function()
                if count < self.count then
                    local value = self.data[index]
                    index = math.fmod(index + 1, self.MAXSIZE)
                    count = count + 1
                    return value
                end
            end
        end

        ---@type fun(size: integer): CircularArrayList
        function thistype.create(size)
            local self = {
                data = {},
                count = 0,
                START = 1,
                END = 1,
                MAXSIZE = size or 200
            }

            setmetatable(self, mt)
            return self
        end

        ---@param value any
        function thistype:add(value)
            self.data[self.END] = value
            self.END = math.fmod((self.END + 1), self.MAXSIZE)

            if self.count < self.MAXSIZE then
                self.count = self.count + 1
            else
                -- Free up the last slot
                self.START = math.fmod((self.START + 1), self.MAXSIZE)
            end
        end

        local function remove(self)
            if self.count > 0 then
                self.START = math.fmod((self.START + 1), self.MAXSIZE)
                self.count = self.count - 1
            end
        end

        ---@param value any
        ---@param time number
        function thistype:add_timed(value, time)
            self:add(value)

            TimerQueue:callDelayed(time, remove, self)
        end

        function thistype:wipe()
            self.data = {}
            self.count = 0
            self.START = 1
            self.END = 1
        end
    end

---@type fun(val: number, min: number, max: number): number
function MathClamp(val, min, max)
    if val < min then
        return min
    elseif val > max then
        return max
    end

    return val
end

---@param b boolean
---@return integer
function B2I(b)
    if b then
        return 1
    end

    return 0
end

---@type fun(source: unit, target: unit, dmg: number, attack_type: attacktype, damage_type: damagetype, tag: string|nil)
function DamageTarget(source, target, dmg, attack_type, damage_type, tag)
    DAMAGE_TAG[#DAMAGE_TAG + 1] = tag
    UnitDamageTarget(source, target, dmg, true, false, attack_type, damage_type, WEAPON_TYPE_WHOKNOWS)
end

---@type fun():boolean
function onPlayerLeave()
    local p   = GetTriggerPlayer()
    local pid = GetPlayerId(p) + 1

    -- clean up
    DisplayTextToForce(FORCE_PLAYING, (User[p].nameColored .. " has left the game"))

    if Profile[pid] then
        PlayerCleanup(pid)
    end

    return false
end

--[[Tasyen/Bribes's GetMainSelectedUnit]]
function GetMainSelectedUnit(...)
    --initialize on the first call...        group frame:      bottom UI:               console:
    local containerFrame = BlzFrameGetChild(BlzFrameGetChild(BlzFrameGetParent(BlzGetFrameByName("SimpleInfoPanelUnitDetail", 0)), 5), 0)

    local function getUnitSortValue(unit)
                --heroes use handleId                                    units use type ID
        return IsUnitType(unit, UNIT_TYPE_HERO) and GetHandleId(unit) or GetUnitTypeId(unit)
    end
    local units
    local function getUnitAt(index)
        return units[index + 1]
    end
    local filter        = Filter(function()
        local unit      = GetFilterUnit()
        local prio      = BlzGetUnitRealField(unit, UNIT_RF_PRIORITY)
        local pos       = #units + 1
        -- compare the current unit with already found, to place it in the right slot
        for i = 1, pos - 1 do
            local value = units[i]
            -- higher prio than this; take it's slot                    equal prio and better colisions Value
            if BlzGetUnitRealField(value, UNIT_RF_PRIORITY) < prio or (BlzGetUnitRealField(value, UNIT_RF_PRIORITY) == prio and getUnitSortValue(value) > getUnitSortValue(unit)) then
                pos = i
                break
            end
        end
        table.insert(units, pos, unit)
    end)
    -- give each frame a unique ID
    local frames = {}
    for int = 0, BlzFrameGetChildrenCount(containerFrame) - 1 do
        local buttonContainer = BlzFrameGetChild(containerFrame, int)
        frames[int + 1] = BlzFrameGetChild(buttonContainer, 0)
    end
    ---@param atIndex? integer
    ---@param async? boolean --if no atIndex is specified but this is true, returns the local current main selected unit's index. Beware: using it in a sync gamestate relevant manner breaks the game.
    function GetMainSelectedUnit(atIndex, async) --re-declare itself once it was called the first time.
        if async and not atIndex then
            -- local player is in group selection?
            if BlzFrameIsVisible(containerFrame) then
                -- find the first visible yellow Background Frame
                for i = 1, #frames do
                    local frame = frames[i]

                    if BlzFrameIsVisible(frame) then
                        atIndex = i - 1
                        break
                    end
                end
            end
        end
        local whichFilter
        local getUnit   = FirstOfGroup
        if atIndex then
            units       = {}
            whichFilter = filter
            getUnit     = getUnitAt
        end
        GroupEnumUnitsSelected(bj_lastCreatedGroup, GetLocalPlayer(), whichFilter)
        return getUnit(atIndex or bj_lastCreatedGroup)
    end
    return GetMainSelectedUnit(...) --return the product of the newly-declared function.
end

--[[Damage number pop-up text]]
do
    local SIZE_MIN                = 0.009          ---@type number -- Minimum size of text
    local SIZE_BONUS              = 0.006          ---@type number -- Text size increase
    local TIME_LIFE               = 0.9            ---@type number -- How long the text lasts
    local TIME_FADE               = 0.7            ---@type number -- When does the text start to fade
    local Z_OFFSET                = 100             ---@type number -- Height above unit
    local Z_OFFSET_BON            = 75             ---@type number -- How much extra height the text gains
    local VELOCITY                = 2.75              ---@type number -- How fast the text move in x/y plane
    local MAX_PER_TICK            = 4 ---@type integer 
    local count                   = 0 ---@type integer 
    local instances               = {}

    ---@class ArcingTextTag
    ---@field create function
    ArcingTextTag = {}
    do
        local thistype = ArcingTextTag

        local move_text_tag = SetTextTagPos
        local set_text_tag_text = SetTextTagText

        local function condition()
            return #instances == 0
        end

        local function update()
            local i = 1
            count = 0

            while i <= #instances do
                local self = instances[i]
                local p = math.sin(bj_PI * (self.time / self.timeScale))
                self.time = self.time - FPS_32
                self.x = self.x + self.ac
                self.y = self.y + self.as
                move_text_tag(self.tt, self.x, self.y, Z_OFFSET + Z_OFFSET_BON * p)
                set_text_tag_text(self.tt, self.text, (SIZE_MIN + SIZE_BONUS * p) * self.scale)

                if self.time <= 0 then
                    instances[i] = instances[#instances]
                    instances[#instances] = nil
                else
                    i = i + 1
                end
            end
        end

        ---@type fun(text: string|number, u: unit, duration: number, size: number, r: integer, g: integer, b: integer, alpha: integer): ArcingTextTag?
        function thistype.create(text, u, duration, size, r, g, b, alpha)
            count = count + 1

            if count > MAX_PER_TICK then
                return
            end

            if type(text) == "number" then
                local hp = text / BlzGetUnitMaxHP(u)
                size = size + math.min(hp * 2., 2.)
                duration = duration + math.min(hp, 1.25)
                text = RealToString(text)
            end

            local a = GetRandomReal(0, 2 * bj_PI) ---@type number 
            ---@diagnostic disable-next-line: missing-fields
            local self = { ---@type ArcingTextTag
                scale = size,
                timeScale = math.max(duration, 0.001),
                text = text,
                x = GetUnitX(u),
                y = GetUnitY(u),
                time = TIME_LIFE,
                as = math.sin(a) * VELOCITY,
                ac = math.cos(a) * VELOCITY,
            }

            local pid = GetPlayerId(GetLocalPlayer()) + 1 ---@type integer 

            if DMG_NUMBERS[pid] == 0 or (DMG_NUMBERS[pid] == 1 and not IsUnitAlly(u, GetLocalPlayer())) then
                self.tt = CreateTextTag()
                SetTextTagPermanent(self.tt, false)
                SetTextTagColor(self.tt, r, g, b, 255 - alpha)
                SetTextTagLifespan(self.tt, TIME_LIFE * duration)
                SetTextTagFadepoint(self.tt, TIME_FADE * duration)
                SetTextTagText(self.tt, text, SIZE_MIN * size)
                SetTextTagPos(self.tt, self.x, self.y, Z_OFFSET)
            end

            instances[#instances + 1] = self

            if #instances == 1 then
                TimerQueue:callPeriodically(FPS_32, condition, update)
            end

            return self
        end
    end
end

--[[Shield system and UI]]
do
    ---@class shieldtimer
    ---@field shield shield
    ---@field amount number
    ---@field create function
    ---@field destroy function
    ---@field queue TimerQueue
    shieldtimer = {}
    do
        local thistype = shieldtimer
        local mt = { __index = thistype }

        function thistype:destroy()
            self.queue:destroy()
            self = nil
        end

        ---@type fun(timer: shieldtimer)
        local function expire(timer)
            timer.shield.max = timer.shield.max - timer.amount
            timer.shield.hp = timer.shield.hp - timer.amount

            if timer.shield.hp <= 0 then
                timer.shield:destroy()
            else
                timer.shield:refresh()
            end

            TableRemove(timer.shield.timers, timer)
            timer:destroy()
        end

        function thistype.create(shield, amount, dur)
            local self = {}

            setmetatable(self, mt)

            self.shield = shield
            self.amount = amount
            self.queue = TimerQueue.create()

            self.queue:callDelayed(dur, expire, self)

            return self
        end

    end

    ---@class shield
    ---@field refresh function
    ---@field sfx effect
    ---@field max number
    ---@field queue TimerQueue
    ---@field target unit
    ---@field add function
    ---@field create function
    ---@field destroy function
    ---@field color function
    ---@field c integer
    ---@field r integer
    ---@field g integer
    ---@field b integer
    ---@field addTimer function
    ---@field timers shieldtimer[]
    ---@field shieldheight number[]
    ---@field list shield[]
    shield = {}
    do
        local thistype = shield
        local mt = { __index = thistype }

        thistype.list = {}
        thistype.shieldheight = {
            HERO_ELEMENTALIST = 200,
            HERO_MARKSMAN = 220,
            HERO_MARKSMAN_SNIPER = 220,
            HERO_ROYAL_GUARDIAN = 230,
            HERO_MASTER_ROGUE = 230,
            HERO_ASSASSIN = 230,
            HERO_DARK_SUMMONER = 230,
            HERO_THUNDERBLADE = 240,
            HERO_HIGH_PRIEST = 240,
            HERO_VAMPIRE = 240,
            HERO_OBLIVION_GUARD = 275
        }

        --shieldheight default value
        __jarray(250, thistype.shieldheight)

        function thistype:color(c)
            self.c = c
            self.r = OriginalRGB[c].r
            self.g = OriginalRGB[c].g
            self.b = OriginalRGB[c].b
            BlzSetSpecialEffectColorByPlayer(self.sfx, Player(c))
        end

        function thistype:refresh()
            BlzSetSpecialEffectTime(self.sfx, self.hp / self.max)
        end

        ---@type fun(self: shield, dmg: number, source: unit): number
        function thistype:damage(dmg, source)
            local angle = math.atan(GetUnitY(source) - GetUnitY(self.target), GetUnitX(source) - GetUnitX(self.target)) ---@type number 
            local x     = GetUnitX(self.target) + 80. * math.cos(angle) ---@type number 
            local y     = GetUnitY(self.target) + 80. * math.sin(angle) ---@type number 
            local e     = AddSpecialEffect("war3mapImported\\BoneArmorCasterTC.mdx", x, y) ---@type effect 

            BlzSetSpecialEffectZ(e, BlzGetUnitZ(self.target) + 90.)
            BlzSetSpecialEffectColorByPlayer(e, Player(self.c))
            BlzSetSpecialEffectYaw(e, angle)
            BlzSetSpecialEffectScale(e, 0.85)
            BlzSetSpecialEffectTimeScale(e, 3.5)

            DestroyEffect(e)

            self.hp = self.hp - dmg

            if self.hp <= 0. then
                self:destroy()
                return -self.hp
            else
                self:refresh()
                return 0.00
            end
        end

        local function update()
            local u = GetMainSelectedUnit() ---@type unit 

            if thistype[u] then
                BlzFrameSetVisible(SHIELD_BACKDROP, true)

                if thistype[u].max >= 100000 then
                    BlzFrameSetText(SHIELD_TEXT, "|cff22ddff" .. R2I(thistype[u].hp))
                else
                    BlzFrameSetText(SHIELD_TEXT, "|cff22ddff" .. R2I(thistype[u].hp) .. " / " .. R2I(thistype[u].max))
                end
            else
                BlzFrameSetVisible(SHIELD_BACKDROP, false)
            end

            --move shield visual positions
            for i = 1, #thistype.list do
                local s = thistype.list[i]
                if UnitAlive(s.target) then
                    BlzSetSpecialEffectX(s.sfx, GetUnitX(s.target))
                    BlzSetSpecialEffectY(s.sfx, GetUnitY(s.target))
                    BlzSetSpecialEffectZ(s.sfx, BlzGetUnitZ(s.target) + thistype.shieldheight[GetUnitTypeId(s.target)])
                else
                    s:destroy()
                end
            end

            if thistype.queue then
                thistype.queue:callDelayed(FPS_32, update)
            end
        end

        local function onStruck(target, source, amount, amount_after_red)
            amount.color = {thistype[target].r, thistype[target].g, thistype[target].b}
            amount.value = thistype[target]:damage(amount_after_red, source)
        end

        --shield fully expires
        function thistype:onDestroy()
            local pid = GetPlayerId(GetOwningPlayer(self.target)) + 1 ---@type integer 

            TimerList[pid]:stopAllTimers(GAIAARMOR.id) --gaia armor attachment
            ProtectionBuff:dispel(nil, self.target) --high priestess protection attack speed

            BlzSetSpecialEffectAlpha(self.sfx, 0)
            DestroyEffect(self.sfx)

            --destroy all active shieldtimers
            for _, v in ipairs(self.timers) do
                v:destroy()
            end

            TableRemove(thistype.list, self)

            if #thistype.list == 0 then
                BlzFrameSetVisible(SHIELD_BACKDROP, false)
                thistype.queue:destroy()
            end

            EVENT_ON_STRUCK_AFTER_REDUCTIONS:unregister_unit_action(self.target, onStruck)
        end

        function thistype:destroy()
            self:onDestroy()
            thistype[self.target] = nil
            self = nil
        end

        ---@type fun(self: shield, amount: number, dur: number)
        function thistype:addTimer(amount, dur)
            local timer = shieldtimer.create(self, amount, dur)

            self.timers[#self.timers + 1] = timer
        end

        ---@type fun(u: unit, amount: number, dur: number):shield
        function thistype.add(u, amount, dur)
            local self = shield[u] ---@type shield

            --shield already exists
            if self then
                self.max = self.max + amount
                self.hp = self.hp + amount

                self:refresh()
            else
            --make a new one
                self = thistype.create(u, amount, dur)
                EVENT_ON_STRUCK_AFTER_REDUCTIONS:register_unit_action(u, onStruck)
            end

            self:addTimer(amount, dur)

            return self
        end

        ---@type fun(u: unit, amount: number, dur: number):shield
        function thistype.create(u, amount, dur)
            ---@diagnostic disable-next-line: missing-fields
            local self = {} ---@type shield

            setmetatable(self, mt)

            --setup
            self.max = amount
            self.hp = amount
            self.target = u
            self.sfx = AddSpecialEffect("war3mapImported\\HPbar.mdx", GetUnitX(u), GetUnitY(u))
            self.timers = {}
            self:color(2)
            BlzSetSpecialEffectTime(self.sfx, 1.)
            BlzSetSpecialEffectTimeScale(self.sfx, 0.)
            BlzSetSpecialEffectScale(self.sfx, 1.6)

            thistype[u] = self
            thistype.list[#thistype.list + 1] = self

            if #thistype.list == 1 then
                thistype.queue = TimerQueue.create()
                thistype.queue:callDelayed(FPS_32, update)
            end

            return self
        end
    end
end

---@class DialogWindow
---@field getClickedIndex function
---@field pid integer
---@field data any[]
---@field Button button[]
---@field ButtonName string[]
---@field MenuButton button[]
---@field MenuButtonName string[]
---@field count integer
---@field menu_count integer
---@field Page integer
---@field display function
---@field addButton function
---@field addMenuButton function
---@field create function
---@field destroy function
---@field BUTTON_MAX integer
DialogWindow = {}
do
    local thistype = DialogWindow
    local mt = { __index = thistype }

    thistype.OPTIONS_PER_PAGE = 7 ---@type integer 
    thistype.BUTTON_MAX       = 100 ---@type integer 
    thistype.MENU_BUTTON_MAX  = 5 ---@type integer 
    thistype.DATA_MAX         = 100 ---@type integer 

    thistype.dialog          = nil ---@type dialog 
    thistype.pid             = 0 ---@type integer 
    thistype.title           = "" ---@type string 
    thistype.count     = 0  ---@type integer 
    thistype.menu_count = 2  ---@type integer 
    thistype.Page            = -1 ---@type integer 
    thistype.trig            = nil

    thistype.cancellable     = true ---@type boolean 

    ---@return boolean
    function thistype.dialogHandler()
        local self = thistype[GetPlayerId(GetTriggerPlayer()) + 1]

        --cancel
        if self then
            if GetClickedButton() == self.MenuButton[0] then
                self:destroy()
            --next page
            elseif GetClickedButton() == self.MenuButton[1] then
                self:display()
            end
        end

        return false
    end

    ---@param b button
    ---@return integer
    function thistype:getClickedIndex(b)
        for index = 0, self.count do
            if b == self.Button[index] then
                return index
            end
        end

        return -1
    end

    function thistype:display()
        local index = self.Page * self.OPTIONS_PER_PAGE + self.OPTIONS_PER_PAGE ---@type integer 
        local shown = 0 ---@type integer 

        DialogClear(self.dialog)

        --buttons
        if index >= self.count then
            index = 0
            self.Page = -1
        end

        while not (shown >= self.OPTIONS_PER_PAGE or index >= self.count) do

            self.Button[index] = DialogAddButton(self.dialog, self.ButtonName[index], 0)

            index = index + 1
            shown = shown + 1
        end

        --menu buttons
        index = 2
        while index < self.menu_count do

            self.MenuButton[index] = DialogAddButton(self.dialog, self.MenuButtonName[index], 0)

            index = index + 1
        end

        --reserve first two menu buttons for next page / cancel
        if self.count > self.OPTIONS_PER_PAGE then
            self.MenuButton[1] = DialogAddButton(self.dialog, "Next Page", 0)
            self.Page = self.Page + 1
        end

        if self.cancellable then
            self.MenuButton[0] = DialogAddButton(self.dialog, "Cancel", 0)
        end

        DialogSetMessage(self.dialog, self.title)
        DialogDisplay(Player(self.pid - 1), self.dialog, GetLocalPlayer() == Player(self.pid - 1))
    end

    ---Second argument allows some data to be associated with the button index
    ---@type fun(self: DialogWindow, s: string, data: any?)
    function thistype:addButton(s, data)
        if data ~= nil then
            self.data[self.count] = data
        end
        self.ButtonName[self.count] = s
        self.count = self.count + 1
    end

    ---@param s string
    function thistype:addMenuButton(s)
        self.MenuButtonName[self.menu_count] = s
        self.menu_count = self.menu_count + 1
    end

    function thistype:destroy()
        DialogDisplay(Player(self.pid - 1), self.dialog, false)
        DialogDestroy(self.dialog)
        DestroyTrigger(self.trig)

        thistype[self.pid] = nil
    end

    ---@type fun(pid: integer, s: string, c: function): DialogWindow | nil
    function DialogWindow.create(pid, s, c)
        --safety
        if thistype[pid] then
            thistype[pid]:destroy()
        end

        ---@diagnostic disable-next-line: missing-fields
        local self = {} ---@type DialogWindow
        self.dialog = DialogCreate()
        self.title = s
        self.pid = pid
        self.trig = CreateTrigger()
        self.data = {}
        self.Button = {}
        self.ButtonName = __jarray("")
        self.MenuButton = {}
        self.MenuButtonName = __jarray("")

        setmetatable(self, mt)

        DialogSetMessage(self.dialog, self.title)
        TriggerRegisterDialogEvent(self.trig, self.dialog)
        TriggerAddCondition(self.trig, Filter(c))
        TriggerAddCondition(self.trig, Filter(thistype.dialogHandler))

        thistype[pid] = self

        return self
    end
end

---@class TimerFrame
---@field running boolean
---@field stop function
---@field create function
---@field update function
---@field destroy function
---@field expire function
---@field frame framehandle
---@field text framehandle
---@field timer integer
---@field time integer
---@field title string
---@field trig trigger
---@field minimize framehandle
---@field minimize_frame framehandle
---@field playerGroup table
TimerFrame = {}
do
    local thistype = TimerFrame
    local mt = { __index = thistype }
    local date = os.date
    local minimize = BlzCreateFrameByType("GLUEBUTTON", "", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "ScoreScreenTabButtonTemplate", 0)
    local minimize_frame = BlzCreateFrameByType("BACKDROP", "", minimize, "", 0)
    local frame = BlzCreateFrame("ListBoxWar3", minimize_frame, 0, 0)
    local text = BlzCreateFrameByType("TEXT", "", frame, "", 0)

    function thistype:run()
        self.time = self.time - 1

        if self.time < 0 then
            self:stop()
        else
            self:update()
            self.timer = TimerQueue:callDelayed(1, thistype.run, self)
        end
    end

    function thistype:destroy()
        TimerQueue:disableCallback(self.timer)
        DestroyTrigger(self.trig)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        if TableHas(self.playerGroup, GetLocalPlayer()) or TableHas(self.playerGroup, pid) then
            BlzFrameSetVisible(minimize, false)
        end
        setmetatable(self, nil)
        self = nil
    end

    function thistype:stop()
        self.expire()
        self:destroy()
    end

    function thistype:update()
        BlzFrameSetText(text, self.title .. "|n" .. date("!\x25H:\x25M:\x25S", self.time))
    end

    function TimerFrame.create(title, time, onExpire, playerGroup)
        local self = {
            running = true,
            expire = onExpire,
            time = time,
            title = title,
            playerGroup = playerGroup,
        }

        BlzFrameSetSize(minimize, 0.015, 0.015)
        BlzFrameSetTexture(minimize_frame, "war3mapImported\\expand.blp", 0, true)

        self.trig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(self.trig, minimize, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(self.trig, function()
            if GetTriggerPlayer() == GetLocalPlayer() then
                BlzFrameSetEnable(BlzGetTriggerFrame(), false)
                BlzFrameSetEnable(BlzGetTriggerFrame(), true)

                if BlzFrameIsVisible(frame) then
                    BlzFrameSetVisible(frame, false)
                    BlzFrameSetTexture(minimize_frame, "war3mapImported\\minimize.blp", 0, true)
                else
                    BlzFrameSetVisible(frame, true)
                    BlzFrameSetTexture(minimize_frame, "war3mapImported\\expand.blp", 0, true)
                end
            end
        end)

        setmetatable(self, mt)

        BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
        BlzFrameSetPoint(minimize, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_CENTER, 0, -0.154)
        BlzFrameSetAllPoints(minimize_frame, minimize)
        BlzFrameSetPoint(text, FRAMEPOINT_BOTTOM, minimize_frame, FRAMEPOINT_TOP, 0, 0.018)
        BlzFrameSetPoint(frame, FRAMEPOINT_TOPLEFT, text, FRAMEPOINT_TOPLEFT, -0.04, 0.02)
        BlzFrameSetPoint(frame, FRAMEPOINT_BOTTOMRIGHT, text, FRAMEPOINT_BOTTOMRIGHT, 0.04, -0.02)
        BlzFrameSetVisible(minimize, false)

        local pid = GetPlayerId(GetLocalPlayer()) + 1
        if TableHas(playerGroup, GetLocalPlayer()) or TableHas(playerGroup, pid) then
            BlzFrameSetVisible(minimize, true)
        end

        self:update()
        self.timer = TimerQueue:callDelayed(1, thistype.run, self)

        return self
    end
end

-- simple priority queue

---@class PriorityQueue
---@field create function
---@field push function
---@field pop function
---@field clear function
---@field isEmpty function
PriorityQueue = {}
do
    local thistype = PriorityQueue
    thistype.__index = thistype

    function thistype.create()
        local self = setmetatable({}, thistype)
        self.heap = {}
        self.currentSize = 0
        return self
    end

    function thistype:push(value, priority)
        local node = {value = value, priority = priority}
        self.currentSize = self.currentSize + 1
        local i = self.currentSize
        self.heap[i] = node
        while i > 1 do
            local parentIndex = math.floor(i / 2)
            if self.heap[parentIndex].priority <= priority then
                break
            end
            self.heap[i] = self.heap[parentIndex]
            self.heap[parentIndex] = node
            i = parentIndex
        end
    end

    function thistype:pop()
        local minNode = self.heap[1]
        local lastNode = self.heap[self.currentSize]
        self.currentSize = self.currentSize - 1
        local i = 1
        while true do
            local childIndex = 2 * i
            if childIndex > self.currentSize then
                break
            end
            if childIndex + 1 <= self.currentSize and self.heap[childIndex + 1].priority < self.heap[childIndex].priority then
                childIndex = childIndex + 1
            end
            if lastNode.priority <= self.heap[childIndex].priority then
                break
            end
            self.heap[i] = self.heap[childIndex]
            i = childIndex
        end
        self.heap[i] = lastNode
        return minNode.value
    end

    function thistype:isEmpty()
        return self.currentSize == 0
    end

    function thistype:clear()
        self.heap = {}
        self.currentSize = 0
    end
end

--misc helper functions

---@type fun(n: integer, t: table): table
function pickN(n, t)
    local seen = {}
    local out = {}
    while #out < n do
        local r = math.random(1, #t)
        if not seen[r] then
            seen[r] = true
            out[#out + 1] = t[r]
        end
    end
    return out
end

---@type fun(sfx: effect)
function HideEffect(sfx)
    BlzSetSpecialEffectScale(sfx, 0.)
    BlzSetSpecialEffectPosition(sfx, 30000., 30000., 0.)
    DestroyEffect(sfx)
end

---@param u unit
---@return boolean
function IsUnitStunned(u)
    return (Stun:has(nil, u) or Freeze:has(nil, u) or KnockUp:has(nil, u) or GetUnitAbilityLevel(u, FourCC('BPSE')) > 0 or GetUnitAbilityLevel(u, FourCC('BSTN')) > 0)
end

---@type fun(u: unit, id: integer, disable: boolean)
function UnitDisableAbility(u, id, disable)
    local ablev = GetUnitAbilityLevel(u, id) ---@type integer 

    if ablev == 0 then
        return
    end

    UnitRemoveAbility(u, id)
    UnitAddAbility(u, id)
    SetUnitAbilityLevel(u, id, ablev)
    BlzUnitDisableAbility(u, id, disable, false)
    BlzUnitHideAbility(u, id, true)
end

---@param position integer
---@param returnHex boolean
---@return integer|string, integer|nil, integer|nil
function HealthGradient(position, returnHex)
    -- Ensure the position is within the valid range [1, 100]
    position = math.min(100, math.max(1, position))

    -- Define color stops and their corresponding positions
    local colorStops = {
        {1,   {255, 0, 0}},
        {10,  {255, 0, 0}},
        {70,  {242, 255, 64}},
        {100, {8, 200, 2}}
    }

    -- Find the two color stops between which the position falls
    local startStop, endStop
    for i = 1, #colorStops - 1 do
        if position <= colorStops[i + 1][1] then
            startStop = colorStops[i]
            endStop = colorStops[i + 1]
            break
        end
    end

    -- Interpolate between the two color stops based on position
    local t = (position - startStop[1]) / (endStop[1] - startStop[1])
    local interpolatedColor = {
        math.floor(startStop[2][1] + t * (endStop[2][1] - startStop[2][1])),
        math.floor(startStop[2][2] + t * (endStop[2][2] - startStop[2][2])),
        math.floor(startStop[2][3] + t * (endStop[2][3] - startStop[2][3]))
    }

    if returnHex then
        -- Convert RGB values to hexadecimal string
        local hexString = string.format("|cff\x2502X\x2502X\x2502X", interpolatedColor[1], interpolatedColor[2], interpolatedColor[3])
        return hexString
    else
        return interpolatedColor[1], interpolatedColor[2], interpolatedColor[3]
    end
end

--Returns index if found otherwise false
---@type fun(tbl:table, val: any): integer | boolean
function TableHas(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            return i
        end
    end

    return false
end

---@type fun(tbl: table, val: any)
function TableRemove(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            tbl[i] = tbl[#tbl]
            tbl[#tbl] = nil
            break
        end
    end
end

---@type fun(tbl: table, text: string)
function DisplayTextToTable(tbl, text)
    for i = 1, #tbl do
        local p = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
        DisplayTextToPlayer(p, 0, 0, text)
    end
end

---@type fun(tbl: table, dur: number, text: string)
function DisplayTimedTextToTable(tbl, dur, text)
    for i = 1, #tbl do
        local p = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
        DisplayTimedTextToPlayer(p, 0, 0, dur, text)
    end
end

local passedValue = {}

---@type fun(pid: integer, g: group, r: rect, b: boolexpr)
function MakeGroupInRect(pid, g, r, b)
    passedValue[#passedValue + 1] = pid
    GroupEnumUnitsInRect(g, r, b)
    passedValue[#passedValue] = nil
end

---@type fun(pid: integer, g: group, x: number, y: number, radius: number, b: boolexpr)
function MakeGroupInRange(pid, g, x, y, radius, b)
    passedValue[#passedValue + 1] = pid
    GroupEnumUnitsInRange(g, x, y, radius, b)
    passedValue[#passedValue] = nil
end

---@type fun(pid: integer, g: group, x: number, y: number, radius: number, b: boolexpr)
function GroupEnumUnitsInRangeEx(pid, g, x, y, radius, b)
    local ug = CreateGroup()

    MakeGroupInRange(pid, ug, x, y, radius, b)
    BlzGroupAddGroupFast(ug, g)

    DestroyGroup(ug)
end

---@param u unit
---@param show boolean
function ToggleCommandCard(u, show)
    local classification = BlzGetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION) ---@type integer 
    local ward = GetHandleId(UNIT_CATEGORY_WARD) ---@type integer 

    if (BlzBitAnd(classification, ward) > 0 and show) or (BlzBitAnd(classification, ward) == 0 and not show) then
        BlzSetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION, BlzBitXor(classification, ward))
    end
end

---@type fun(path: string, is3D: boolean, p: player|nil, u: unit|nil)
function SoundHandler(path, is3D, p, u)
    local ss = ((p and GetLocalPlayer() ~= p) and "") or path ---@type string 
    local s = CreateSound(ss, false, is3D, is3D, 12700, 12700, "")

    if u ~= nil then
        AttachSoundToUnit(s, u)
    end

    StartSound(s)
    KillSoundWhenDone(s)
end

---@param time number
---@return string
function RemainingTimeString(time)
    local minutes = time // 60
    local seconds = math.fmod(R2I(time), 60)

    return (minutes > 0 and (minutes) .. " minutes") or (seconds) .. " seconds"
end

---@type fun(u: unit): boolean
function IsDummy(u)
    local id = GetUnitTypeId(u)

    return (id == DUMMY_CASTER or id == DUMMY_VISION)
end

---@return boolean
function ischar()
    local pid = GetPlayerId(GetOwningPlayer(GetFilterUnit())) + 1 ---@type integer 

    return (GetFilterUnit() == Hero[pid] and UnitAlive(Hero[pid]))
end

---@return boolean
function ishostile()
    local i =GetPlayerId(GetOwningPlayer(GetFilterUnit())) ---@type integer 

    return (UnitAlive(GetFilterUnit()) and GetUnitAbilityLevel(GetFilterUnit(),FourCC('Avul')) == 0 and (i ==10 or i ==11 or i ==PLAYER_NEUTRAL_AGGRESSIVE))
end

---@return boolean
function isplayerAlly()
    return (UnitAlive(GetFilterUnit()) and GetPlayerId(GetOwningPlayer(GetFilterUnit())) <= PLAYER_CAP and IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) == true and GetUnitTypeId(GetFilterUnit()) ~= BACKPACK)
end

---@return boolean
function isplayerunitRegion()
    local u = GetFilterUnit()

    return (UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and not IsDummy(u))
end

---@return boolean
function isplayerunit()
    local u = GetFilterUnit()

    return (UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and not IsDummy(u))
end

---@return boolean
function ishostileEnemy()
    local u = GetFilterUnit()
    local i = GetPlayerId(GetOwningPlayer(u)) ---@type integer 

    return
    (UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    i <= PLAYER_CAP and
    not IsDummy(u))
end

---@return boolean
function isalive()
    local u = GetFilterUnit()

    return
    (UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0
    and not IsDummy(u))
end

local similar_units = {
    [FourCC('nitt')] = FourCC('n0tb'), --troll
    [FourCC('n0tw')] = FourCC('n0ts'), --tuskarr
    [FourCC('n0tc')] = FourCC('n0ts'),
    [FourCC('n0sl')] = FourCC('n0ss'), --spider
    [FourCC('n0us')] = FourCC('n0uw'), --ursae
    [FourCC('n0po')] = FourCC('n0dm'), --polar bear / mammoth
    [FourCC('o01G')] = FourCC('n01G'), --ogre / tauren
    [FourCC('n0ut')] = FourCC('n0ud'), --unbroken
    [FourCC('n0ub')] = FourCC('n0ud'),
    [FourCC('n0hh')] = FourCC('n0hs'), --hellfire / hellhound
    [FourCC('n027')] = FourCC('n024'), --centaur
    [FourCC('n028')] = FourCC('n024'),
    [FourCC('n08M')] = FourCC('n01M'), --magnataur
    [FourCC('n01R')] = FourCC('n02P'), --frost dragon / drake
    [FourCC('n00C')] = FourCC('n02L'), --devourers
    [FourCC('E007')] = FourCC('H00O'), --arkaden
    [FourCC('n033')] = FourCC('n034'), --demons
    [FourCC('n03B')] = FourCC('n03A'), --horror
    [FourCC('n03C')] = FourCC('n03A'),
    [FourCC('n01W')] = FourCC('n03F'), --despair
    [FourCC('n00W')] = FourCC('n08N'), --abyssal
    [FourCC('n00X')] = FourCC('n08N'),
    [FourCC('n030')] = FourCC('n031'), --void
    [FourCC('n02Z')] = FourCC('n031'),
    [FourCC('n02J')] = FourCC('n020'), --nightmare
    [FourCC('n03E')] = FourCC('n03D'), --hell
    [FourCC('n03G')] = FourCC('n03D'),
    [FourCC('n01X')] = FourCC('n03J'), --existence
    [FourCC('n01V')] = FourCC('n03M'), --astral
    [FourCC('n03T')] = FourCC('n026'), --dimensional

    [HERO_DARK_SAVIOR_DEMON] = HERO_DARK_SAVIOR,
    [HERO_MARKSMAN_SNIPER] = HERO_MARKSMAN,
}

---unifies different unit types together
---@type fun(id: any): integer
function GetType(id)
    if type(id) == "userdata" then
        id = GetUnitTypeId(id)
    end

    if similar_units[id] then
        return similar_units[id]
    end

    return id
end

---@type fun(u: any): Boss|nil
function IsBoss(u)
    local uid = (type(u) == "number" and u) or GetType(GetUnitTypeId(u))

    for i = BOSS_OFFSET, #Boss do
        if Boss[i].id == uid then
            return Boss[i]
        end
    end

    return nil
end

---@param enemy integer|unit
---@return boolean
function IsEnemy(enemy)
    if type(enemy) == "userdata" then
        enemy = GetPlayerId(GetOwningPlayer(enemy)) + 1
    end

    return (enemy >= 12)
end

function ExplodeUnits()
    SetUnitExploded(GetEnumUnit(), true)
    KillUnit(GetEnumUnit())
end

---@type fun(itm: item): boolean
function isImportantItem(itm)
    return itm == PATH_ITEM
end

function ClearItems()
    local itm = GetEnumItem() ---@type item 

    if not isImportantItem(itm) then -- pathcheck
        Item[itm]:destroy()
    end
end

---@param source unit
---@param target unit
local function AttackDelay(source, target)
    BlzSetUnitWeaponBooleanField(source, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, true)
    IssueTargetOrderById(source, 852173, target)
end

---@param source unit
---@param target unit
function InstantAttack(source, target)
    UnitAddAbility(source, FourCC('IATK'))
    TimerQueue:callDelayed(FPS_32, AttackDelay, source, target)
end

---@param pid integer
function RemovePlayerUnits(pid)
    local ug = CreateGroup()

    GroupEnumUnitsOfPlayer(ug, Player(pid - 1), nil)

    for target in each(ug) do
        if not IsDummy(target) then
            EVENT:unregister_unit_action(target)
            Buff.dispelAll(target, true)
            RemoveUnit(target)
        end
    end

    DestroyGroup(ug)
end

---@param hero unit
---@return integer
function HighestStat(hero)
    local str = GetHeroStr(hero, true) ---@type integer 
    local agi = GetHeroAgi(hero, true) ---@type integer 
    local int = GetHeroInt(hero, true) ---@type integer 

    if str > agi and str > int then
        return 1
    elseif agi > str and agi > int then
        return 2
    elseif int > str and int > agi then
        return 3
    else
        return MainStat(hero)
    end
end

---@param hero unit
---@return integer
function MainStat(hero) --returns integer signifying primary attribute
    return BlzGetUnitIntegerField(hero, UNIT_IF_PRIMARY_ATTRIBUTE)
end

---@param r rect
---@param x number
---@param y number
---@return boolean
function NearbyRect(r, x, y)
    local angle = math.atan(GetRectCenterY(r) - y, GetRectCenterX(r) - x) ---@type number 

    for i = 5, 50, 5 do
        if RectContainsCoords(r, x + i * math.cos(angle), y + math.sin(angle) * i) then
            return true
        end
    end

    return false
end

---@param i integer
---@param x number
---@param y number
function CustomLightingPlayerCheck(i, x, y)
    local daynightmodel = DEFAULT_LIGHTING ---@type string 

    CustomLighting[i] = 1

    if RectContainsCoords(gg_rct_Naga_Dungeon, x, y) and not RectContainsCoords(gg_rct_Naga_Dungeon_Reward, x, y) then
        CustomLighting[i] = 2
    elseif RectContainsCoords(gg_rct_Naga_Dungeon_Boss, x, y) then
        CustomLighting[i] = 2
    elseif RectContainsCoords(gg_rct_Cave, x, y) then
        CustomLighting[i] = 3
    elseif RectContainsCoords(gg_rct_Crypt, x, y) then
        CustomLighting[i] = 4
    elseif RectContainsCoords(gg_rct_Church, x, y) then
        CustomLighting[i] = 4
    end

    if CustomLighting[i] ~= 1 then
        daynightmodel = "blacklight.mdx"
    end

    if CustomLighting[i] == 1 then
        UnitRemoveAbility(Hero[i], FourCC('A059'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
    elseif CustomLighting[i] == 2 and GetUnitAbilityLevel(Hero[i], FourCC('A0AN')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
        UnitRemoveAbility(Hero[i], FourCC('A059'))
    elseif CustomLighting[i] == 3 and GetUnitAbilityLevel(Hero[i], FourCC('A0B8')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A0B8'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A059'))
    elseif CustomLighting[i] == 4 and GetUnitAbilityLevel(Hero[i], FourCC('A059')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A059'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
    end

    if GetLocalPlayer() == Player(i - 1) then
        SetDayNightModels(daynightmodel, daynightmodel)
    end
end

---@type fun(pt: PlayerTimer)
function DelayAnimationExpire(pt)
    if pt.pause then
        BlzPauseUnitEx(pt.target, false)
    end

    if pt.dur > 0. then
        SetUnitTimeScale(pt.target, pt.dur)
    end

    if UnitAlive(pt.target) then
        SetUnitAnimationByIndex(pt.target, pt.index)
    end

    pt:destroy()
end

---@type fun(pid: integer, u: unit, delay: number, index: integer, timescale: number, pause: boolean)
function DelayAnimation(pid, u, delay, index, timescale, pause)
    local pt = TimerList[pid]:add() ---@type PlayerTimer

    pt.target = u
    pt.index = index
    pt.pause = false
    pt.dur = timescale

    if pause then
        BlzPauseUnitEx(u, true)
        pt.pause = true
    end

    pt.timer:callDelayed(delay, DelayAnimationExpire, pt)
end

---@param p player
---@param r rect
function SetCameraBoundsRectForPlayerEx(p, r)
    local minX = GetRectMinX(r) ---@type number 
    local minY = GetRectMinY(r) ---@type number 
    local maxX = GetRectMaxX(r) ---@type number 
    local maxY = GetRectMaxY(r) ---@type number 
    local pid  = GetPlayerId(p) + 1 ---@type integer 

    --lighting
    CustomLightingPlayerCheck(pid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))

    if GetLocalPlayer() == p then
        SetCameraField(CAMERA_FIELD_ROTATION, 90., 0)
        SetCameraBounds(minX, minY, minX, maxY, maxX, maxY, maxX, minY)
    end
end

---@type fun(u: unit)
function ResetPathing(u)
    SetUnitPathing(u, true)
end

---@param line integer
---@param contents string?
---@return string
function GetLine(line, contents)
    if contents == nil then
        return ""
    end

    local count = 0

    for match in contents:gmatch("[^\n]*\n?") do
        if count == line then
            return match
        end
        count = count + 1
    end

    return ""
end

---@param pid integer
function DisplayQuestProgress(pid)
    local i = 0 ---@type integer 
    local flag = (CHAOS_MODE and 1) or 0
    local index = KillQuest[flag][i]

    while index ~= 0 do
        local s = (KillQuest[index].count == KillQuest[index].goal and "|cff40ff40") or ""

        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, KillQuest[index].name .. ": " .. s .. (KillQuest[index].count) .. "/" .. (KillQuest[index].goal) .. "|r |cffffcc01LVL " .. (KillQuest[index].min) .. "-" .. (KillQuest[index].max))
        i = i + 1
        index = KillQuest[flag][i]
    end
end

---@return boolean
function ConfirmDeleteCharacter()
    local pid   = GetPlayerId(GetTriggerPlayer()) + 1
    local dw    = DialogWindow[pid]
    local index = dw:getClickedIndex(GetClickedButton())

    if index ~= -1 then
        Profile[pid]:delete_character()

        dw:destroy()
    end

    return false
end

---@type fun(pid: integer, slot: integer): string
function GetCharacterPath(pid, slot)
     return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\slot" .. (slot) .. ".pld"
end

---@type fun(pid: integer): string
function GetProfilePath(pid)
    return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\profile.pld"
end

local function CleanupBoundItems(object, p)
    local itm = Item[object]

    if itm.owner == p then
        itm:destroy()
    end
end

local function valid_item(object)
    return Item[object] and object ~= PATH_ITEM
end

-- use for any instance of player removal (leave, repick, permanent death)
---@type fun(pid: integer)
function PlayerCleanup(pid)
    local p = Player(pid - 1)

    -- close actions spellbook
    UnitRemoveAbility(Hero[pid], FourCC('A03C'))

    -- clear cosmetics
    for _, v in ipairs(CosmeticTable.cosmetics) do
        local sfx = v[pid .. v.name] ---@type effect

        if sfx then
            DestroyEffect(sfx)
        end
    end

    TimerList[pid]:stopAllTimers()

    PLAYER_SELECTED_UNIT[pid] = nil

    -- TODO: Use this more
    EVENT_ON_CLEANUP:trigger(pid)

    -- cleanup bound items
    ALICE_ForAllObjectsDo(CleanupBoundItems, "item", valid_item, p)

    RemovePlayerUnits(pid)
    SetCameraLocked(pid, false)
    Hero[pid] = nil
    HeroID[pid] = 0
    Backpack[pid] = nil
    IS_AUTO_ATTACK_OFF[pid] = false
    SetCurrency(pid, GOLD, 0)
    SetCurrency(pid, PLATINUM, 0)
    SetCurrency(pid, CRYSTAL, 0)
    ItemGoldRate[pid] = 0
    CustomLighting[pid] = 1
    IS_FLEEING[pid] = false

    if GetLocalPlayer() == p then
        BlzFrameSetVisible(DPS_FRAME, false)
        DisplayCineFilter(false)

        -- clear damage log
        BlzFrameSetText(MULTIBOARD.DAMAGE:get(2, 1).frame, " ")
    end
end

---@param u1 unit
---@param u2 unit
---@return number
function UnitDistance(u1, u2)
    local dx = GetUnitX(u2) - GetUnitX(u1) ---@type number 
    local dy = GetUnitY(u2) - GetUnitY(u1) ---@type number 

    return SquareRoot(dx * dx + dy * dy)
end

---@type fun(x: number, y: number, x2: number, y2: number):number
function DistanceCoords(x, y, x2, y2)
    return SquareRoot((x - x2) * (x - x2) + (y - y2) * (y - y2))
end

---@param u unit
function ExpireUnit(u)
    UnitApplyTimedLife(u, FourCC('BTLF'), 0.1)
end

---@param u unit
---@param abid integer
function UnitResetAbility(u, abid)
    local i = GetUnitAbilityLevel(u, abid) ---@type integer 

    UnitRemoveAbility(u, abid)
    UnitAddAbility(u, abid)
    SetUnitAbilityLevel(u, abid,i)
end

---@type fun(p: player, p2: player, show: boolean)
function ShowHeroPanel(p, p2, show)
    if show == true then
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, true, p)
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_CONTROL, false, p)
    else
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, false, p)
    end
end

---@type fun(pid: integer, id: integer): boolean
function PlayerHasItemType(pid, id)
    for i = 1, MAX_INVENTORY_SLOTS do
        local itm = Profile[pid].hero.items[i]
        if itm and itm.id == id then
            return true
        end
    end

    return false
end

local dummies = {
    FourCC('I00D'),
    FourCC('I00M'),
    FourCC('I028'),
    FourCC('I02K'),
    FourCC('I01B'),
    FourCC('I027'),
}

function IsDummyCastItem(id)
    return TableHas(dummies, id)
end

function MakeDummyCastItem(u)
    local index = 0

    for i = 0, 5 do
        if not UnitItemInSlot(u, i) then
            index = i + 1
            break
        end
    end

    local itm = OldCreateItem(dummies[index], 30000, 30000)
    UnitAddItem(u, itm)

    return itm
end

---@param pid integer
---@param charge boolean
---@return Item?
function GetResurrectionItem(pid, charge)
    local items = Profile[pid].hero.items

    for i = 1, 6 do
        local itm = items[i]
        if itm then
            if itm.abil == FourCC('Arrv') or itm.abil == FourCC('Anrv') then
                if charge and itm.abil == FourCC('Arrv') then
                    return itm
                elseif not charge and itm.charges > 0 then
                    return itm
                end
            end
        end
    end

    if charge then
        for i = 1, 6 do
            local itm = items[i]
            if itm then
                if itm.abil == FourCC('Arrv') or itm.abil == FourCC('Anrv') then
                    if charge and itm.abil == FourCC('Arrv') then
                        return itm
                    elseif not charge and itm.charges > 0 then
                        return itm
                    end
                end
            end
        end
    end

    return nil
end

---@param groupnumber integer
---@return rect
function SelectGroupedRegion(groupnumber)
    local REGION_GAP = 25 ---@type integer 
    local lowBound  = groupnumber * REGION_GAP ---@type integer 
    local highBound = lowBound ---@type integer 

    while not (RegionCount[highBound] == nil) do
        highBound = highBound + 1
    end

    return RegionCount[GetRandomInt(lowBound, highBound - 1)]
end

--formats a number to a string with commas (no decimals), Lua handles string representation of numbers greater than integer limit
---@param value number
---@return string
function RealToString(value)
    if value >= INT_32_LIMIT then
        return tostring(tonumber(value))
    end

    local s = tostring(math.floor(value + 0.5))
    local _, _, minus, int = s:find("([-]?)(\x25d+)")

    int = int:reverse():gsub("(\x25d\x25d\x25d)", "\x251,")

    return minus .. int:reverse():gsub("^,", "")
end

---@type fun(pid: integer, prof: integer): boolean
function HasProficiency(pid, prof)
    local id = HeroID[pid]

    if not HERO_STATS[id] then
        return false
    end

    return BlzBitAnd(HERO_STATS[id].prof, prof) ~= 0 or prof == 0 or prof == PROF_SHIELD or prof == PROF_POTION
end

---@type fun(id: integer, pid: integer):number
function ItemProfMod(id, pid)
    local prof = ItemData[id][ITEM_TYPE] ---@type integer 

    return (HasProficiency(pid, PROF[prof]) and 1) or 0.75
end

---@type fun(itemid: integer): integer|nil
function ItemToIndex(itemid)
    return SAVE_TABLE.KEY_ITEMS[itemid]
end


--overrides default UnitAddItemById function
---@type fun(u: unit, id: integer): Item
function UnitAddItemById(u, id)
    local itm = CreateItem(id, GetUnitX(u), GetUnitY(u)) ---@type Item

    UnitAddItem(u, itm.obj)

    return itm
end

---@type fun(pid: integer, itm: Item)
function PlayerAddItem(pid, itm)
    itm.owner = Player(pid - 1)
    itm.pid = pid

    -- power ups are given to hero regardless
    if GetItemType(itm.obj) == ITEM_TYPE_POWERUP then
        UnitAddItem(Hero[pid], itm.obj)
    else
        if not itm:equip() then
            SetItemPosition(itm.obj, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        end
    end
end

---@type fun(pid: integer, id: string|integer): Item
function PlayerAddItemById(pid, id)
    local _, origid, level = GetItem(id)
    local itm = CreateItem(origid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid])) ---@type Item
    itm.owner = Player(pid - 1)
    itm.pid = pid

    -- power ups are given to hero regardless
    if GetItemType(itm.obj) == ITEM_TYPE_POWERUP then
        UnitAddItem(Hero[pid], itm.obj)
    else
        if level > 0 then
            itm:lvl(level)
        end

        itm:equip()
    end

    return itm
end

---@type fun(pid: integer): integer
function GetEmptyIndex(pid)
    for i = 1, MAX_INVENTORY_SLOTS do
        if Profile[pid].hero.items[i] == nil then
            return i
        end
    end

    return -1
end

---@type fun(killed: unit, killer: unit)
function RewardXPGold(killed, killer)
    local kpid = GetPlayerId(GetOwningPlayer(killer)) + 1 ---@type integer 
    local xpgroup = {}
    local lvl = GetUnitLevel(killed)

    -- nearby allies
    local U = User.first

    while U do
        if U.id ~= kpid and IsUnitInRange(Hero[U.id], killed, 1800.00) and UnitAlive(Hero[U.id]) then
            if (GetHeroLevel(Hero[U.id]) >= (lvl - 20)) and (GetHeroLevel(Hero[U.id])) >= GetUnitLevel(Hero[kpid]) - LEECH_CONSTANT then
                xpgroup[#xpgroup + 1] = U.id
            end
        end
        U = U.next
    end

    -- killer
    if GetHeroLevel(Hero[kpid]) >= (lvl - 20) then
        xpgroup[#xpgroup + 1] = kpid
    end

    -- allocate rewards
    local maingold = GOLD_TABLE[lvl]
    local teamgold = 0
    local expbase = EXPERIENCE_TABLE[lvl] * 0.007 ---@type number 

    -- boss bounty
    local boss = IsBoss(killed)

    if boss then
        expbase = expbase * 10. * boss.difficulty
        maingold = expbase * 90 * boss.difficulty
    end

    if #xpgroup > 0 then
        expbase = expbase * (1.2 / #xpgroup)
        teamgold = maingold * (1. / #xpgroup)
    end

    for i = 1, #xpgroup do
        local pid = xpgroup[i]
        local XP = math.floor(expbase * XP_Rate[pid])

        AwardGold(pid, teamgold, false)
        AwardXP(pid, XP)
    end
end

function DisableBackpackTeleports(pid, disable)
    UnitDisableAbility(Backpack[pid], TELEPORT.id, disable)
    UnitDisableAbility(Backpack[pid], TELEPORT_HOME.id, disable)
    if disable then
        BlzUnitHideAbility(Backpack[pid], TELEPORT.id, false)
        BlzUnitHideAbility(Backpack[pid], TELEPORT_HOME.id, false)
    end
end

local StatTable = {
    GetHeroStr,
    GetHeroInt,
    GetHeroAgi,
    function() return 0 end,
}

---@type fun(stat: integer, u: unit, bonuses: boolean): integer
function GetHeroStat(stat, u, bonuses)
    return StatTable[stat](u, bonuses)
end

---@type fun(p0_x: number, p0_y: number, p1_x: number, p1_y: number, p2_x: number, p2_y: number, p3_x: number, p3_y: number): location | nil
function GetLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x = p1_x - p0_x ---@type number 
    local s1_y = p1_y - p0_y ---@type number 
    local s2_x = p3_x - p2_x ---@type number 
    local s2_y = p3_y - p2_y ---@type number 
    local s    = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y) ---@type number 
    local t    = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) // (-s2_x * s1_y + s1_x * s2_y) ---@type number 
    local i_x  = 0. ---@type number 
    local i_y  = 0. ---@type number 

    if (s >= 0.0 and s <= 1.0 and t >= 0.0 and t <= 1.0) then
        -- collision
        i_x = p0_x + (t * s1_x)
        i_y = p0_y + (t * s1_y)

        return {i_x, i_y}
    end

    --no collision
    return nil
end

---@type fun(x: number, y: number, x2: number, y2: number, minX: number, minY: number, maxX: number, maxY: number): boolean
function LineContainsRect(x, y, x2, y2, minX, minY, maxX, maxY)
    local leftSide   = GetLineIntersection(x, y, x2, y2, minX, minY, minX, maxY) ---@type table 
    local rightSide  = GetLineIntersection(x, y, x2, y2, maxX, minY, maxX, maxY) ---@type table 
    local bottomSide = GetLineIntersection(x, y, x2, y2, minX, minY, maxX, minY) ---@type table 
    local topSide    = GetLineIntersection(x, y, x2, y2, minX, maxY, maxX, maxY) ---@type table 

    return (leftSide ~= nil or rightSide ~= nil or bottomSide ~= nil or topSide ~= nil)
end

---@param u unit
---@return boolean
function InCombat(u)
    local ug = CreateGroup()

    GroupEnumUnitsInRange(ug, GetUnitX(u), GetUnitY(u), 900., Condition(ishostile))

    for target in each(ug) do
        if Unit[target].target == u then
            DestroyGroup(ug)
            return true
        end
    end

    DestroyGroup(ug)
    return false
end

---@param pid integer
function ToggleAutoAttack(pid)
    if IS_AUTO_ATTACK_OFF[pid] then
        IS_AUTO_ATTACK_OFF[pid] = false
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Auto Attacking on.")
        if Unit[Hero[pid]].can_attack then
            BlzSetUnitWeaponBooleanField(Hero[pid], UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, true)
        end
    else
        IS_AUTO_ATTACK_OFF[pid] = true
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Auto Attacking off.")
        BlzSetUnitWeaponBooleanField(Hero[pid], UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
    end
end

---@type fun(num: integer)
function SpawnForgotten(num)
    if UnitAlive(forgotten_spawner) and forgottenCount < 5 then
        for _ = 1, num do
            local id = forgottenTypes[GetRandomInt(0, 4)] ---@type integer 

            forgottenCount = forgottenCount + 1
            CreateUnit(PLAYER_CREEP, id, 13699 + GetRandomInt(-250, 250), -14393 + GetRandomInt(-250, 250), GetRandomInt(0, 359))
        end

        TimerQueue:callDelayed(60., SpawnForgotten, 1)
    end
end

local VALID_TREES = {
    ['ITtw'] = 1,
    ['JTtw'] = 1,
    ['FTtw'] = 1,
    ['NTtw'] = 1,
    ['B00B'] = 1,
    ['B00H'] = 1,
    ['ITtc'] = 1,
    ['NTtc'] = 1,
    ['WTst'] = 1,
    ['WTtw'] = 1,
    x = 0.,
    y = 0.,
    range = 0.
}

function EnumDestroyTreesInRange()
    local d   = GetEnumDestructable() ---@type destructable 
    local did = pack(">I4", GetDestructableTypeId(d))

    if VALID_TREES[did] and DistanceCoords(VALID_TREES.x, VALID_TREES.y, GetDestructableX(d), GetDestructableY(d)) <= VALID_TREES.range then
        KillDestructable(d)
    end
end

---@type fun(x: number, y: number, range: number)
function DestroyTreesInRange(x, y, range)
    local r = Rect(x - range, y - range, x + range, y + range) ---@type rect 

    VALID_TREES.x = x
    VALID_TREES.y = y
    VALID_TREES.range = range
    EnumDestructablesInRect(r, nil, EnumDestroyTreesInRange)

    RemoveRect(r)
end

---@type fun(pid: integer, target: unit, duration: number)
function StunUnit(pid, target, duration)
    local stun = Stun:add(Hero[pid], target)

    if IsUnitType(target, UNIT_TYPE_HERO) then
        stun:duration(duration * 0.5)
    else
        stun:duration(duration)
    end
end

--highlights a string with |cffffcc00
---@type fun(s: string, y: boolean): string
function HL(s, y)
    return (y and ("|cffffcc00" .. s .. "|r")) or s
end

---@type fun(u: unit, id: integer, index: integer):number
function GetAbilityField(u, id, index)
    return BlzGetAbilityRealLevelField(BlzGetUnitAbility(u, id), SPELL_FIELD[index], 0)
end

---@type fun(itm: item, s: string)
function ParseItemTooltip(itm, s)
    local orig = s ~= "" and s or BlzGetItemExtendedTooltip(itm)
    local itemid = GetItemTypeId(itm)
    local gmatch, gsub = string.gmatch, string.gsub

    -- store original tooltip
    ItemData[itemid][ITEM_TOOLTIP] = orig

    -- store original icon path
    ItemData[itemid].path = BlzGetItemIconPath(itm)

    -- store original name
    ItemData[itemid].name = GetItemName(itm)

    -- match balanced brackets
    orig = orig:gsub("(\x25b[])", function(contents)
        contents = contents:sub(2, -2) ---@type string

        local tag, suffix, value = contents:match("(\x25a+)([ \x25*])(\x25-?\x25d+\x25.?\x25d*)")
        local index
        for i = 1, #STAT_TAG do
            local v = STAT_TAG[i]

            if v.syntax == tag then
                index = i
                break
            end
        end

        if index then

            -- assign value
            ItemData[itemid][index] = tonumber(value)
            -- fixed toggle
            ItemData[itemid][index .. "fixed"] = (suffix == "*") and 1 or 0

            -- process ability data if available
            contents = contents:gsub("(#.*)", function(capture)
                local data = capture:sub(7, #capture)

                ItemData[itemid][index .. "id"] = FourCC(capture:sub(2, 5))
                ItemData[itemid][index .. "data"] = data

                -- read sfx data
                for entry in gmatch(data, "(\x25S+)") do
                    local args = {}

                    -- parse [sfx,level,attach,path] entries
                    for arg in gmatch(entry, "([^,]+)") do
                        args[#args + 1] = arg
                    end

                    if #args == 4 then
                        -- replace underscores with spaces in attachment point
                        args[3] = gsub(args[3], "_", " ")

                        local tbl = ItemData[itemid].sfx

                        if type(tbl) ~= "table" then
                            tbl = {}
                            ItemData[itemid].sfx = tbl
                        end

                        tbl[#tbl + 1] = {
                            level = args[2],
                            attach = args[3],
                            path = args[4],
                        }
                    end
                end

                return ""
            end)

            -- process affixes
            local affix = "([|=>\x25@])(\x25-?\x25d+\x25.?\x25d*)"
            local start = contents:find(affix)

            if start then
                contents = contents:sub(start)
                contents = gsub(contents, affix, function(prefix, capture)

                    -- value range
                    if prefix == "|" then
                        ItemData[itemid][index .. "range"] = tonumber(capture)
                    -- flat per level
                    elseif prefix == "=" then
                        ItemData[itemid][index .. "fpl"] = tonumber(capture)
                    -- flat per rarity
                    elseif prefix == ">" then
                        ItemData[itemid][index .. "fpr"] = tonumber(capture)
                    -- percent effectiveness
                    elseif prefix == "\x25" then
                        ItemData[itemid][index .. "percent"] = tonumber(capture)
                    -- unlock at
                    elseif prefix == "@" then
                        ItemData[itemid][index .. "unlock"] = tonumber(capture)
                    end
                end)
            end
        end
    end)
end

local function finish_cast(u)
    PauseUnit(u, false)
end

---@type fun(u: unit, id: integer, dur: number, anim: integer, timescale: number)
function CastSpell(u, id, dur, anim, timescale)
    BlzStartUnitAbilityCooldown(u, id, BlzGetUnitAbilityCooldown(u, id, GetUnitAbilityLevel(u, id) - 1))
    DelayAnimation(BOSS_ID, u, dur, 0, 1., true)
    if anim ~= -1 then
        SetUnitTimeScale(u, timescale)
        SetUnitAnimationByIndex(u, anim)
    end

    Unit[u].cast_time = dur
    PauseUnit(u, true)
    TimerQueue:callDelayed(dur, finish_cast, u)
end

function SetCamera(pid, r)
    local data = REGION_DATA[r]

    if data.vision then
        SetCameraBoundsRectForPlayerEx(Player(pid - 1), data.vision)
    end

    if Hero[pid] then
        PanCameraToTimedForPlayer(Player(pid - 1), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), 0.)
    end

    if data.minimap then
        SetMinimapTexture(pid, data.minimap)
    end
end

---@type fun(pid: integer, x: number, y: number)
function MoveHero(pid, x, y)
    SetUnitXBounded(Hero[pid], x)
    SetUnitYBounded(Hero[pid], y)
    SetUnitXBounded(HeroGrave[pid], x)
    SetUnitYBounded(HeroGrave[pid], y)
    BlzUnitClearOrders(Hero[pid], false)

    local r = GetRectFromCoords(x, y)

    if r then
        SetCamera(pid, r)
    end
end

---@type fun(pid: integer, loc: location)
function MoveHeroLoc(pid, loc)
    SetUnitPositionLoc(Hero[pid], loc)
    SetUnitPositionLoc(HeroGrave[pid], loc)
    BlzUnitClearOrders(Hero[pid], false)

    local r = GetRectFromCoords(GetLocationX(loc), GetLocationY(loc))

    if r then
        SetCamera(pid, r)
    end
end

---@param pid integer
function ExperienceControl(pid)
    local level = GetHeroLevel(Hero[pid]) ---@type integer 
    local xpRate = BASE_XP_RATE[level] ---@type number 

    if IS_IN_STRUGGLE[pid] then
        xpRate = xpRate * .3
    end

    XP_Rate[pid] = math.max(0, xpRate * (1. + 0.04 * PrestigeTable[pid][0]))
end

---@type fun(pid: integer, texture: string)
function SetMinimapTexture(pid, texture)
    if GetLocalPlayer() == Player(pid - 1) then
        BlzChangeMinimapTerrainTex(texture)
    end
end

local conversion_cd = {}
local conversion_reset_cd = function(pid) conversion_cd[pid] = nil end

---@type fun(pid: integer)
function ConversionEffect(pid)
    if not conversion_cd[pid] then
        conversion_cd[pid] = true
        TimerQueue:callDelayed(1., conversion_reset_cd, pid)
        local x = GetUnitX(Hero[pid])
        local y = GetUnitY(Hero[pid])

        for i = 1, 3 do
            for j = 1, i * 4 do
                local dist = i * 40
                local angle = 2. * bj_PI / (i * 4) * j
                local sfx = AddSpecialEffect("Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl", x + dist * math.cos(angle), y + dist * math.sin(angle))
                BlzSetSpecialEffectColor(sfx, 50, 50, 255)
                DestroyEffect(sfx)
            end
        end
    end
end

---@type fun(pid: integer, xp: number)
function AwardXP(pid, xp)
    xp = math.floor(xp)
    SetHeroXP(Hero[pid], GetHeroXP(Hero[pid]) + xp, true)
    ExperienceControl(pid)
    FloatingTextUnit("+" .. (xp) .. " XP", Hero[pid], 2, 80, 0, 10, 204, 0, 204, 0, false)
end

---@type fun(s: string, u: unit, dur: number, speed: number, z: number, size: number, r: integer, g: integer, b: integer, alpha: integer, shared: boolean)
function FloatingTextUnit(s, u, dur, speed, z, size, r, g, b, alpha, shared)
    local tt = nil

    if shared then
        tt = CreateTextTag()
    elseif GetLocalPlayer() == GetOwningPlayer(u) then
        tt = CreateTextTag()
    end

    if tt then
        SetTextTagText(tt, s, size * 0.0023)
        SetTextTagPos(tt, GetUnitX(u), GetUnitY(u), z)
        SetTextTagColor(tt, r, g, b, 255 - alpha)
        SetTextTagPermanent(tt, false)
        SetTextTagVelocity(tt, 0, speed / 1803.)
        SetTextTagLifespan(tt, dur)
        SetTextTagFadepoint(tt, dur - .4)
    end
end

---@type fun(s: string, x: number, y: number, dur: number, speed: number, z: number, size: number, r: integer, g: integer, b: integer, alpha: integer)
function DoFloatingTextCoords(s, x, y, dur, speed, z, size, r, g, b, alpha)
    local tt = CreateTextTag()

    SetTextTagText(tt, s, size * 0.0023)
    SetTextTagPos(tt, x, y, z)
    SetTextTagColor(tt, r, g, b, 255 - alpha)
    SetTextTagPermanent(tt, false)
    SetTextTagVelocity(tt, 0, speed / 1803.)
    SetTextTagLifespan(tt, dur)
    SetTextTagFadepoint(tt, dur - .4)
end

---@type fun(source: unit, target: unit, hp: number, tag: string|nil)
function HP(source, target, hp, tag)
    --attack count based units cannot be healed
    if Unit[target].attackCount == 0 then
        hp = hp * Unit[target].regen_percent

        local text = RealToString(hp)

        --undying rage heal delay
        if UndyingRageBuff:has(target, target) then
            UndyingRageBuff:get(target, target):addRegen(hp)
        else
            SetUnitState(target, UNIT_STATE_LIFE, GetUnitState(target, UNIT_STATE_LIFE) + hp)
            if R2I(hp) ~= 0 then
                FloatingTextUnit(text, target, 2, 50, 0, 10, 125, 255, 125, 0, true)
            end
        end

        LogDamage(source, target, "|cff7dff7d" .. text .. "|r", true, tag)
    end
end

---@type fun(source: unit, mp: number)
function MP(source, mp)
    if not Unit[source].nomanaregen then
        SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MANA) + mp)
        FloatingTextUnit(RealToString(mp), source, 2, 50, -70, 10, 0, 255, 255, 0, true)
    end
end

---@type fun(n: integer, k: integer): number
function BinomialCoefficient(n, k)
    local result = 1

    if k > n then
        return 0
    end

    for i = 0, k - 1 do
        result = result * (n - i) / (i + 1)
    end

    return result
end

---@class BezierCurve
---@field numPoints integer
---@field pointX number[]
---@field pointY number[]
---@field X number
---@field Y number
---@field addPoint function
---@field calcT function
---@field create function
---@field destroy function
BezierCurve = {}
do
    local thistype = BezierCurve
    local mt = { __index = thistype }

    ---@type fun():BezierCurve
    function thistype.create()
        local self = {
            pointX = {},
            pointY = {},
            X = 0.,
            Y = 0.
        }

        setmetatable(self, mt)

        return self
    end

    function thistype:destroy()
        self = nil
    end

    ---@param x number
    ---@param y number
    function thistype:addPoint(x, y)
        self.pointX[#self.pointX + 1] = x
        self.pointY[#self.pointY + 1] = y
    end

    ---@param t number
    function thistype:calcT(t)
        local n       = #self.pointX - 1
        local resultX = 0.
        local resultY = 0.
        local blend   = 0.

        for i = 0, n do
            blend = BinomialCoefficient(n, i) * (t ^ i) * ((1 - t) ^ (n - i))
            resultX = resultX + blend * self.pointX[i + 1]
            resultY = resultY + blend * self.pointY[i + 1]
        end

        self.X = resultX
        self.Y = resultY
    end
end

local function apply_fade(u, dur, fade, amount)
    local r = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_RED) ---@type integer 
    local g = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_BLUE) ---@type integer 
    local b = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_GREEN) ---@type integer 

    if GetUnitAbilityLevel(u, FourCC('Bmag')) > 0 then --magnetic stance
        r = 255 g = 25 b = 25
    end

    amount = amount + (255 / (dur * 32))

    if fade then
        SetUnitVertexColor(u, r, g, b, math.floor(math.max(255 - amount, 0)))
    else
        SetUnitVertexColor(u, r, g, b, math.floor(math.min(255, amount)))
    end

    if amount < 255 and UnitAlive(u) then
        TimerQueue:callDelayed(FPS_32, apply_fade, u, dur, fade, amount)
    end
end

---@type fun(u: unit, dur: number, fade: boolean)
function Fade(u, dur, fade)
    TimerQueue:callDelayed(0, apply_fade, u, dur, fade, 0)
end

local function apply_sfx_fade(sfx, fade, count)
    count = count - 1

    if count > 0 then
        if fade == true then
            BlzSetSpecialEffectAlpha(sfx, count * 7)
        else
            BlzSetSpecialEffectAlpha(sfx, 255 - count * 7)
        end

        TimerQueue:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
    end
end

---@type fun(sfx: effect, fade: boolean)
function FadeSFX(sfx, fade)
    local count = 40 ---@type number

    if fade == false then
        BlzSetSpecialEffectAlpha(sfx, 0)
    end

    TimerQueue:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
end

function ShopkeeperMove()
    if UnitAlive(evilshopkeeper) then
        local x = 0. ---@type number 
        local y = 0. ---@type number 

        repeat
            x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
            y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)

            if GetRandomInt(0, 99) < 5 then
                x = GetRandomReal(GetRectMinX(gg_rct_Tavern), GetRectMaxX(gg_rct_Tavern))
                y = GetRandomReal(GetRectMinY(gg_rct_Tavern), GetRectMaxY(gg_rct_Tavern))
            end

        until IsTerrainWalkable(x, y)

        evilshop:visible(false)
        ShowUnit(evilshopkeeper, false)
        ShowUnit(evilshopkeeper, true)
        SetUnitPosition(evilshopkeeper, x, y) --random starting spot
        BlzStartUnitAbilityCooldown(evilshopkeeper, FourCC('A017'), 300.)

        ShopSetStock(FourCC('n01F'), 'I02B:0', 1)
        ShopSetStock(FourCC('n01F'), 'I02C:0', 1)
        ShopSetStock(FourCC('n01F'), 'I0EY:0', 1)
        ShopSetStock(FourCC('n01F'), 'I074:0', 1)
        ShopSetStock(FourCC('n01F'), 'I03U:0', 1)
        ShopSetStock(FourCC('n01F'), 'I07F:0', 1)
        ShopSetStock(FourCC('n01F'), 'I03P:0', 1)
        ShopSetStock(FourCC('n01F'), 'I0F9:0', 1)
        ShopSetStock(FourCC('n01F'), 'I079:0', 1)
        ShopSetStock(FourCC('n01F'), 'I0FC:0', 1)
        ShopSetStock(FourCC('n01F'), 'I00A:0', 1)

        TimerQueue:callDelayed(300., ShopkeeperMove)
    end
end

---@type fun(pt: PlayerTimer)
function HideSummonDelay(pt)
    ShowUnit(pt.target, false)

    pt:destroy()
end

---@type fun(pt: PlayerTimer)
function HideSummon(pt)
    SetUnitXBounded(pt.target, 30000)
    SetUnitYBounded(pt.target, 30000)

    pt.timer:callDelayed(1., HideSummonDelay, pt)
end

---@param u unit
function SummonExpire(u)
    local pid = GetPlayerId(GetOwningPlayer(u)) + 1
    local uid = GetUnitTypeId(u)

    TimerList[pid]:stopAllTimers(u)

    Unit[u].borrowed_life = 0

    if IsUnitHidden(u) == false then --important
        if uid == SUMMON_DESTROYER or uid == SUMMON_HOUND or uid == SUMMON_GOLEM then
            UnitRemoveAbility(u, FourCC('BNpa'))
            UnitRemoveAbility(u, FourCC('BNpm'))
            local pt = TimerList[pid]:add()
            pt.target = u
            pt.tag = u
            TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", u, "origin"))

            pt.timer:callDelayed(2., HideSummon, pt)
        end

        if UnitAlive(u) then
            KillUnit(u)
        end
    end
end

---@param level integer
---@return integer
function RequiredXP(level)
    local base        = 150 ---@type integer 
    local levelFactor = 100 ---@type integer 

    for i = 2, level do
        base = base + i * levelFactor
    end

    return base
end

---@param p player
function CleanupSummons(p)
    for i = 1, #SummonGroup do
        local target = SummonGroup[i]
        if GetOwningPlayer(target) == p then
            SummonExpire(target)
        end
    end
end

---@param pid integer
function RecallSummons(pid)
    local p = Player(pid - 1) 
    local x = GetUnitX(Hero[pid]) + 200 * math.cos(bj_DEGTORAD * GetUnitFacing(Hero[pid])) ---@type number 
    local y = GetUnitY(Hero[pid]) + 200 * math.sin(bj_DEGTORAD * GetUnitFacing(Hero[pid])) ---@type number 

    for i = 1, #SummonGroup do
        local target = SummonGroup[i]
        if GetOwningPlayer(target) == p and (GetUnitTypeId(target) == SUMMON_HOUND or GetUnitTypeId(target) == SUMMON_GOLEM or GetUnitTypeId(target) == SUMMON_DESTROYER) and IsUnitHidden(target) == false then
            SetUnitPosition(target, x, y)
            SetUnitPathing(target, false)
            SetUnitPathing(target, true)
            BlzSetUnitFacingEx(target, GetUnitFacing(Hero[pid]))
        end
    end
end

---@param u unit
function reselect(u)
    if (GetLocalPlayer() == GetOwningPlayer(u)) then
        ClearSelection()
        SelectUnit(u, true)
    end
end

---@return boolean
function FilterHound()
    if UnitAlive(GetFilterUnit()) and GetUnitTypeId(GetFilterUnit()) == SUMMON_HOUND then
        if GetOwningPlayer(GetFilterUnit()) == Player(passedValue[#passedValue] - 1) then
            return true
        end
    end

    return false
end

---@return boolean
function FilterEnemyDead()
    local u = GetFilterUnit()

    return GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == false
end

---@type fun():boolean
function FilterEnemy()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    IsUnitEnemy(u, Player(passedValue[#passedValue] - 1)) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u)
end

---@return boolean
function FilterAllyHero()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == true and
    IsUnitType(u, UNIT_TYPE_HERO) == true and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u)
end

---@return boolean
function FilterAlly()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == true
end

---@return boolean
function FilterEnemyAwake()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == false and
    UnitIsSleeping(u) == false
end

---@return boolean
function FilterNotIllusion()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u) and
    IsUnitIllusion(u) == false
end

---@return boolean
function FilterAlive()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
    GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 and
    not IsDummy(u)
end

---@type fun(enemy: unit, player: player): boolean
function IsHittable(enemy, player)
    return UnitAlive(enemy) and GetUnitAbilityLevel(enemy, FourCC('Avul')) == 0 and IsUnitEnemy(enemy, player)
end

---@type fun(frame: framehandle, title: string, text: string, simple: boolean, point1: framepointtype|nil, point2: framepointtype|nil, x: number|nil, y: number|nil, margin: number|nil): table
function FrameAddSimpleTooltip(frame, title, text, simple, point1, point2, x, y, margin)
    local self = {}
    point1 = point1 or FRAMEPOINT_TOP
    point2 = point2 or FRAMEPOINT_BOTTOM
    x = x or 0.
    y = y or -0.008
    margin = margin or 0.008

    if simple then
        self.frame = BlzCreateFrame("Leaderboard", frame, 0, 0)
        self.tooltip = BlzCreateFrameByType("TEXT", "", self.frame, "", 0)
        BlzFrameSetPoint(self.tooltip, point1, frame, point2, x, y)
        BlzFrameSetPoint(self.frame, FRAMEPOINT_TOPLEFT, self.tooltip, FRAMEPOINT_TOPLEFT, -(margin), margin)
        BlzFrameSetPoint(self.frame, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, margin, -(margin))
    else
        self.frame = BlzCreateFrame("TooltipBoxFrame", frame, 0, 0)
        self.box = BlzGetFrameByName("TooltipBox", 0)
        self.line = BlzGetFrameByName("TooltipSeperator", 0)
        self.tooltip = BlzGetFrameByName("TooltipText", 0)
        self.iconFrame = BlzGetFrameByName("TooltipIcon", 0)
        self.nameFrame = BlzGetFrameByName("TooltipName", 0)

        BlzFrameSetPoint(self.tooltip, FRAMEPOINT_CENTER, BlzGetFrameByName("CommandButton_3", 0), FRAMEPOINT_TOPLEFT, -0.09, 0.045)
        BlzFrameSetSize(self.iconFrame, 0.009, 0.009)
        BlzFrameSetTexture(self.iconFrame, "trans32.blp", 0, true)
        BlzFrameSetText(self.nameFrame, title)
        BlzFrameSetPoint(self.box, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
        BlzFrameSetPoint(self.box, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        BlzFrameSetSize(self.tooltip, 0.275, 0)
        BlzFrameClearAllPoints(self.nameFrame)
        BlzFrameSetPoint(self.nameFrame, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, 0, 0)
        BlzFrameSetScale(self.nameFrame, 0.77)
    end

    BlzFrameSetText(self.tooltip, text)
    BlzFrameSetTooltip(frame, self.frame)

    return self
end

---@class SimpleButton
---@field frame framehandle
---@field button framehandle
---@field tooltip framehandle|table
---@field text_frame framehandle
---@field text function
---@field onClick function
---@field makeTooltip function
---@field icon function
---@field iconColor function
---@field enable function
---@field enabled boolean
---@field texture string
---@field visible function
---@field setTooltipIcon function
---@field setTooltipText function
---@field setTooltipName function
SimpleButton = {}
do
    local thistype = SimpleButton
    local mt = { __index = thistype }

    ---@type fun(frame: framehandle, texture: string, width: number, height: number, point1: framepointtype, point2: framepointtype, x: number, y: number, onClick: function?, tooltip: string?, point3: framepointtype?, point4: framepointtype?, x2: number?, y2: number?): SimpleButton
    function SimpleButton.create(frame, texture, width, height, point1, point2, x, y, onClick, tooltip, point3, point4, x2, y2)
        local self = setmetatable({ enabled = true }, mt)
        local inset = 0.004

        self.frame = BlzCreateFrame("ContextFrameButton", frame, 0, 0)
        self.button = BlzGetFrameByName("ContextFrameButtonIcon", 0)
        self.text_frame = BlzGetFrameByName("ContextFrameText", 0)
        BlzFrameSetPoint(self.frame, point1, frame, point2, x, y)
        BlzFrameSetSize(self.frame, width + inset * 2, height + inset * 2)
        BlzFrameSetTexture(self.button, texture, 0, true)
        BlzFrameSetSize(self.frame, width, height)
        --BlzFrameSetPoint(self.frame, FRAMEPOINT_CENTER, frame, FRAMEPOINT_CENTER, 0, 0)
        self.texture = texture

        -- Set up onClick event
        if onClick then
            self:onClick(onClick)
        end

        -- Set up simple tooltip
        if tooltip then
            self.tooltip = FrameAddSimpleTooltip(self.frame, "", tooltip, true, point3, point4, x2, y2)
        end

        return self
    end

    function thistype:setTooltipIcon(icon)
        if self.iconFrame then
            BlzFrameSetTexture(self.iconFrame, icon, 0, false)
        end
    end

    function thistype:setTooltipText(string)
        BlzFrameSetText(self.tooltip, string)
    end

    function thistype:setTooltipName(name)
        if self.nameFrame then
            BlzFrameSetText(self.nameFrame, name)
        end
    end

    function thistype:iconColor(color)
        BlzFrameSetVertexColor(self.button, color)
        BlzFrameSetVertexColor(self.frame, color)
    end

    function thistype:point(p1, p2, x, y)
        BlzFrameSetPoint(self.tooltip, p1, self.frame, p2, x, y)
    end

    -- advanced tooltip
    function thistype:makeTooltip(point, width)
        self.tooltip_frame = BlzCreateFrame("TooltipBoxFrame", self.frame, 0, 0)
        self.box = BlzGetFrameByName("TooltipBox", 0)
        self.line = BlzGetFrameByName("TooltipSeperator", 0)
        self.tooltip = BlzGetFrameByName("TooltipText", 0)
        self.iconFrame = BlzGetFrameByName("TooltipIcon", 0)
        self.nameFrame = BlzGetFrameByName("TooltipName", 0)

        if point == FRAMEPOINT_TOPLEFT then
            BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_TOPRIGHT, 0.005, -0.05)
        elseif point == FRAMEPOINT_TOPRIGHT then
            BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_TOPLEFT, -0.005, -0.05)
        elseif point == FRAMEPOINT_BOTTOMLEFT then
            BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_BOTTOMRIGHT, 0.005, 0.0)
        else
            BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_BOTTOMLEFT, -0.005, 0.0)
        end

        BlzFrameSetPoint(self.box, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
        BlzFrameSetPoint(self.box, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        BlzFrameSetSize(self.tooltip, width, 0)
        BlzFrameSetTooltip(self.frame, self.tooltip_frame)
    end

    function thistype:text(string)
        BlzFrameSetText(self.text_frame, string)
    end

    function thistype:icon(path)
        if path ~= nil then
            self.texture = path
            BlzFrameSetTexture(self.button, path, 0, false)
        end

        return self.texture
    end

    function thistype:visible(flag)
        BlzFrameSetVisible(self.frame, flag)
    end

    function thistype:enable(flag)
        local t = self.texture ---@type string 

        if flag == false then
            t = (t:sub(1, 34) .. "Disabled\\DIS" .. t:sub(36, t:len()))
        end

        self.enabled = flag

        BlzFrameSetTexture(self.button, t, 0, true)
    end

    function thistype:onClick(func)
        DestroyTrigger(self.click)
        self.click = nil

        if func ~= nil then
            self.click = CreateTrigger()
            TriggerAddCondition(self.click, Condition(func))
            BlzTriggerRegisterFrameEvent(self.click, self.frame, FRAMEEVENT_CONTROL_CLICK)
        end
    end
end

---@class PromptFrame
PromptFrame = {}
do
    local thistype = SimpleButton
    local prompt_queue = {}

    -- frame setup
    local main = BlzCreateFrame("QuestButtonDisabledBackdropTemplate", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.48)
    BlzFrameSetSize(main, 0.25, 0.20)
    BlzFrameSetEnable(main, false)
    BlzFrameSetLevel(main, 20)

    local title = BlzCreateFrame("TitleText", main, 0, 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.028)
    BlzFrameSetEnable(title, false)

    local blurb = BlzCreateFrameByType("TEXT", "", main, "", 0)
    BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.06)
    BlzFrameSetEnable(blurb, false)
    BlzFrameSetSize(blurb, 0.2, 1.0)

    BlzFrameSetVisible(main, false)
    --

    local function refresh(pid)
        local q = prompt_queue[pid][1]

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetText(title, "|cffffffff" .. q.name .. "|r")
            BlzFrameSetText(blurb, q.desc)
            BlzFrameSetVisible(main, true)
        end
    end

    local close = function(pid)
        -- shift queue positions
        local q = prompt_queue[pid]
        for i = 1, #q do
            q[i] = q[i + 1]
        end

        if q[1] then
            refresh(pid)
        else
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(main, false)
            end
        end
    end

    local onClose = function()
        local f = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
        end

        close(pid)

        return false
    end

    local onAccept = function()
        local f = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
        end

        prompt_queue[pid][1].func(pid)
        close(pid)

        return false
    end

    local accept = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNcheck.blp", 0.025, 0.025, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., -0.15, onAccept)
    local exit = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onClose, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

    ---@type fun(pid: integer, t: table): boolean
    function PromptFrame.create(pid, t)
        if not prompt_queue[pid] then
            prompt_queue[pid] = {}
        end

        -- ignore duplicate functions
        local q = prompt_queue[pid]
        for i = 1, #q do
            if q[i].func == t.func then
                return false
            end
        end

        -- add to queue
        prompt_queue[pid][#prompt_queue[pid] + 1] = t

        refresh(pid)

        return true
    end
end

---@type fun(tbl: table, fadedur: number, fade: boolean)
local applyblackmask = function(tbl, fadedur, fade)
    for _, pid in ipairs(tbl) do
        pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
        player_fog[pid] = false

        if GetLocalPlayer() == Player(pid - 1) then
            SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
            if fade then
                SetCineFilterStartColor(0,0,0,0)
                SetCineFilterEndColor(0,0,0,255)
            else
                SetCineFilterStartColor(0,0,0,255)
                SetCineFilterEndColor(0,0,0,0)
            end
            SetCineFilterDuration(fadedur)
            DisplayCineFilter(true)
        end
    end
end

---@type fun(tbl: table, fadein: number, fadeout: number)
function BlackMask(tbl, fadein, fadeout)
    applyblackmask(tbl, fadein, true)
    TimerQueue:callDelayed(fadein, applyblackmask, tbl, fadeout, false)
end

---@type fun(tbl: table, x: number, y: number)
function MovePlayers(tbl, x, y)
    for _, pid in ipairs(tbl) do
        pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
        MoveHero(pid, x, y)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", Hero[pid], "origin"))
    end
end

-- Handles "I000:0" format item ids (includes level/variation)
-- Has backwards compatibility for integer item ids
---@type fun(id: string|integer)
---@return string index, integer origid, integer var
function GetItem(id)
    local var = 0
    local origid = id

    if type(id) == "string" then
        var = tonumber(id:sub(6)) or 0 ---@type integer
        origid = FourCC(id:sub(1, 4))
    end

    local index = pack(">I4", origid) .. ":" .. var

    return index, origid, var
end

--optional third argument for the nth item found
---@type fun(pid: integer, id: string|integer, count: integer?): Item | nil
function GetItemFromPlayer(pid, id, count)
    _, id, lvl = GetItem(id)
    count = count or 1

    for i = 1, MAX_INVENTORY_SLOTS do
        local slot = Profile[pid].hero.items[i]

        if slot and slot.id == id and (slot.level == lvl or lvl == -1) then
            if count <= 1 then
                return Profile[pid].hero.items[i]
            else
                count = count - 1
            end
        end
    end

    return nil
end

function UpdateBackpackTooltips(pid)
    local s = ""
    local u = User[pid - 1]
    local unlocked = 0

    for j = PUBLIC_SKINS + 2, TOTAL_SKINS do
        if CosmeticTable[u.name][j] > 0 then
            unlocked = unlocked + 1
        end
    end

    if unlocked >= 17 then
        s = "Change your backpack's appearance.\n\nUnlocked skins: |c0000ff4017/17"
    else
        s = "Change your backpack's appearance.\n\nUnlocked skins: " .. (unlocked) .. "/17"
    end

    if GetLocalPlayer() == u.player then
        BlzSetAbilityExtendedTooltip(FourCC('A0KX'), s, 0)
    end
end

---@type fun(hero: unit, aoe: number)
function Taunt(hero, aoe)
    local ug = CreateGroup()
    local pid = GetPlayerId(GetOwningPlayer(hero)) + 1

    MakeGroupInRange(pid, ug, GetUnitX(hero), GetUnitY(hero), aoe, Condition(FilterEnemy))

    for enemy in each(ug) do
        Unit[hero]:taunt(Unit[enemy])
    end

    DestroyGroup(ug)
end

---@type fun(pid: integer, x: number, y: number, percenthp: number, percentmana: number)
function RevivePlayer(pid, x, y, percenthp, percentmana)
    local p = Player(pid - 1)

    -- reenable backpack teleports
    DisableBackpackTeleports(pid, false)

    -- reenable inventory
    DisableItems(pid, false)

    ReviveHero(Hero[pid], x, y, true)
    SetWidgetLife(Hero[pid], BlzGetUnitMaxHP(Hero[pid]) * percenthp)
    SetUnitState(Hero[pid], UNIT_STATE_MANA, GetUnitState(Hero[pid], UNIT_STATE_MAX_MANA) * percentmana)
    PanCameraToTimedForPlayer(p, x, y, 0)
    SetUnitFlyHeight(Hero[pid], 0, 0)
    reselect(Hero[pid])
    SetUnitTimeScale(Hero[pid], 1.)
    SetUnitPropWindow(Hero[pid], bj_DEGTORAD * 60.)
    SetUnitPathing(Hero[pid], true)

    EVENT_ON_REVIVE:trigger(Hero[pid])
end

---@param mana number
---@return integer
function Roundmana(mana)
    if mana > 99999 then
        return 1000 * (mana // 1000)
    end

    return R2I(mana)
end

function SyncCallback(prefix, func)
    local t = CreateTrigger()
    local U = User.first
    while U do
        BlzTriggerRegisterPlayerSyncEvent(t, U.player, prefix, false)
        U = U.next
    end
    TriggerAddCondition(t, Condition(func))
end

end, Debug and Debug.getLine())
