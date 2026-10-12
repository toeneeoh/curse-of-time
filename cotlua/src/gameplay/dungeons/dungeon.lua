--[[
    dungeon.lua

    This module contains dungeon related globals and functions.
]]

OnInit.final("Dungeons", function(Require)
    Require('Variables')
    Require('ItemEventRegistry')
    Require('SimpleButton')
    Require('TimerFrame')
    Require('PlayerLifecycle')
    Require('Inventory')
    Require('WorldTransitions')
    Require('TimerQueue')
    Require('Users')
    Require('UnitTable')

    ---@type Dungeon|false
    QUEUE_DUNGEON = false
    QUEUE_GROUP   = {} ---@type integer[]
    QUEUE_READY   = {} ---@type boolean[]

    ---@class Dungeon
    ---@field id integer|string
    ---@field level integer
    ---@field queue_x number
    ---@field queue_y number
    ---@field starting? boolean
    ---@field managed_entry? boolean
    ---@field canStart? fun(self: Dungeon): boolean, string?
    ---@field onStart fun(self: Dungeon)
    ---@field queue fun(self: Dungeon, pid: integer): boolean, string?
    ---@field requestStart fun(self: Dungeon, pid: integer): boolean, string?
    ---@field isEligible fun(self: Dungeon, pid: integer): boolean
    ---@field setReady fun(pid: integer, value: boolean): boolean
    ---@field subscribeQueue fun(callback: fun(open_pid: integer?))
    ---@field started boolean
    ---@field name string
    ---@field players integer[]
    ---@field chest unit
    ---@field enemies unit[]
    ---@field creepDeath function
    ---@field define function
    ---@field endDungeon function
    ---@field entrance_x number
    ---@field entrance_y number
    ---@field exit_x number
    ---@field exit_y number
    ---@field timer TimerFrame
    ---@field playerDeath function
    Dungeon = {}
    do
        local thistype = Dungeon
        local mt = { __index = thistype }

        local function onBuy(p, pid, u, itm)
            local ok, reason = thistype[itm.id]:queue(pid)
            if not ok then DisplayTextToPlayer(Player(pid - 1), 0, 0, reason or 'Dungeon unavailable.') end
        end

        ---@param id string
        ---@return Dungeon
        function thistype.define(id)
            local self = {
                id = #id == 4 and FourCC(id) or id,
                players = {},
                enemies = {},
                floor = 0,
            }

            setmetatable(self, mt)

            -- setup item onbuy event
            if type(self.id) == 'number' then ITEM_LOOKUP[self.id] = onBuy end
            thistype[self.id] = self

            return self
        end

        ---@type fun(id: integer, x: number, y: number, facing: number, dmgr: integer, g: table):unit
        function thistype:createUnit(id, x, y, facing)
            local u = CreateUnit(PLAYER_CREEP, id, x, y, facing)
            self.enemies[#self.enemies + 1] = u

            if self.creepDeath then
                EVENT_ON_UNIT_DEATH:register_unit_action(u, self.creepDeath)
            end

            return u
        end

        function thistype:destroy()
            self.floor = 0
            self.started = false
            self.starting = false

            if self.timer then
                self.timer:destroy()
                self.timer = nil
            end

            if self.exit_timer then
                if self.exit_button then
                    self.exit_button:destroy()
                    self.exit_button = nil
                end
                self.exit_timer:destroy()
                self.exit_timer = nil
            end

            if self.chest then
                RemoveUnit(self.chest)
                self.chest = nil
            end

            for i = 1, #self.enemies do
                RemoveUnit(self.enemies[i])
                self.enemies[i] = nil
            end
        end

        -- dungeon end ui
        function thistype:endDungeon()

            -- reenable items immediately for players
            for i = 1, #self.players do
                local pid = self.players[i]
                DisableItems(pid, false)
                if self.playerDeath then
                    EVENT_GRAVE_DEATH:unregister_unit_action(Hero[pid], self.playerDeath)
                end
            end

            -- timer runs out, dungeon closes
            local function close()
                for i = 1, #self.players do
                    local pid = self.players[i]
                    DisableBackpackTeleports(pid, false)
                    MoveHero(pid, self.exit_x, self.exit_y)
                    self.players[i] = nil
                end

                self:destroy()
            end
            self.exit_timer = TimerFrame.create("Dungeon closing in: ", 120., close, self.players)

            -- player presses EXIT
            local exit = function()
                local p = GetTriggerPlayer()
                local pid = GetPlayerId(p) + 1

                TableRemove(self.players, pid)
                DisableBackpackTeleports(pid, false)
                MoveHero(pid, self.exit_x, self.exit_y)

                if GetLocalPlayer() == p then
                    BlzFrameSetVisible(self.exit_timer.minimize, false)
                end

                if #self.players == 0 then
                    self:destroy()
                end
            end
            self.exit_button = SimpleButton.create(self.exit_timer.frame, "war3mapImported\\ExitButton.blp", 0.03, 0.015, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., 0.015, exit)
        end


        local listeners, queued_heroes = {}, {}
        local generation = 0
        function thistype.subscribeQueue(callback)
            listeners[#listeners + 1] = callback
        end
        local function notify(open_pid)
            for _, callback in ipairs(listeners) do callback(open_pid) end
        end
        local function eligible(self, pid)
            local hero = Hero[pid]
            return hero and UnitAlive(hero) and not Unit[hero].busy
                and GetHeroLevel(hero) >= self.level
                and IsUnitInRangeXY(hero, self.queue_x, self.queue_y, 750.)
        end
        function thistype:isEligible(pid)
            return eligible(self, pid) and true or false
        end
        local function clear_queue()
            for _, pid in ipairs(QUEUE_GROUP) do QUEUE_READY[pid] = false end
            QUEUE_GROUP = {}
            queued_heroes = {}
            QUEUE_DUNGEON = false
            generation = generation + 1
            notify()
        end
        local function refresh_queue(self)
            if QUEUE_DUNGEON ~= self then return end
            local previous, found = QUEUE_GROUP, {}
            local u = User.first
            while u do
                if eligible(self, u.id) then found[#found + 1] = u.id end
                u = u.next
            end
            for _, pid in ipairs(previous) do
                if not TableHas(found, pid) then QUEUE_READY[pid] = false end
            end
            for _, pid in ipairs(found) do
                if not TableHas(previous, pid) or queued_heroes[pid] ~= Hero[pid] then QUEUE_READY[pid] = false end
                queued_heroes[pid] = Hero[pid]
            end
            QUEUE_GROUP = found
            if #found == 0 and not self.starting then clear_queue() else notify() end
        end
        local function ready_check()
            if #QUEUE_GROUP == 0 then return false end
            for _, pid in ipairs(QUEUE_GROUP) do
                if not QUEUE_READY[pid] then return false end
            end
            return true
        end
        function thistype.setReady(pid, value)
            local self = QUEUE_DUNGEON
            if not self or self.starting then return false end
            refresh_queue(self)
            if not TableHas(QUEUE_GROUP, pid) then return false end
            QUEUE_READY[pid] = value == true
            notify()
            return true
        end
        function thistype:queue(pid)
            if self.started then
                return false, "This dungeon is already in progress!"
            elseif QUEUE_DUNGEON and QUEUE_DUNGEON ~= self then
                return false, "Please wait while another dungeon is queueing!"
            elseif not eligible(self, pid) then
                return false, "A living, available hero of the required level must be near the entrance."
            end
            if self.canStart then
                local allowed, reason = self:canStart()
                if not allowed then return false, reason end
            end
            if not QUEUE_DUNGEON then
                QUEUE_DUNGEON = self
                generation = generation + 1
                local token = generation
                TimerQueue:callPeriodically(.25, function()
                    return generation ~= token or QUEUE_DUNGEON ~= self
                end, function()
                    if generation == token then refresh_queue(self) end
                end)
            end
            refresh_queue(self)
            notify(pid)
            return true
        end
        function thistype:requestStart(pid)
            if QUEUE_DUNGEON ~= self or self.starting or self.started then return false end
            refresh_queue(self)
            if not TableHas(QUEUE_GROUP, pid) or not ready_check() then
                return false, "Every nearby participant must be ready."
            end
            if self.canStart then
                local allowed, reason = self:canStart()
                if not allowed then return false, reason end
            end
            local party = {}
            for i, id in ipairs(QUEUE_GROUP) do party[i] = id end
            self.starting = true
            local token = generation
            notify()
            BlackMask(party, 2, 2)
            TimerQueue:callDelayed(2., function()
                if generation ~= token or QUEUE_DUNGEON ~= self then return end
                refresh_queue(self)
                local unchanged = #QUEUE_GROUP == #party and ready_check()
                for _, id in ipairs(party) do unchanged = unchanged and TableHas(QUEUE_GROUP, id) end
                if self.canStart then unchanged = unchanged and self:canStart() end
                self.starting = false
                if not unchanged then
                    DisplayTextToTable(party, "The party changed. Check readiness and start again.")
                    if #QUEUE_GROUP == 0 then clear_queue() else notify() end
                    return
                end
                self.started = true
                self.players = party
                for _, id in ipairs(party) do
                    if not self.managed_entry then
                        MoveHero(id, self.entrance_x, self.entrance_y)
                        DisableItems(id, true)
                        DisableBackpackTeleports(id, true)
                    end
                    if self.playerDeath then EVENT_GRAVE_DEATH:register_unit_action(Hero[id], self.playerDeath) end
                end
                clear_queue()
                self:onStart()
            end)
            return true
        end
        -- Dungeon-specific entry and encounters are defined in content/dungeons.
        function thistype:onStart() end
    end
end, Debug and Debug.getLine())
