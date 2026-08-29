--[[
    events.lua

    A library that defines custom events that can assign functions to units or players
]]

OnInit.final("Events", function()

    ---@class EVENT
    ---@field create function
    ---@field unit_actions table
    ---@field trigger function
    ---@field has_unit_actions fun(self: EVENT, u: unit): boolean
    ---@field register_unit_action function
    ---@field unregister_unit_action function
    EVENT = {}
    do
        local event_list = {}
        local thistype = EVENT
        local unit_actions_mt = { __mode = 'k' } -- make keys weak for when units are removed
        local event_mt = { __index = thistype }

        ---@return EVENT
        function EVENT.create()
            local self = setmetatable({
                unit_actions = setmetatable({}, unit_actions_mt),
            }, event_mt)

            event_list[#event_list + 1] = self

            return self
        end

        local recurse = setmetatable({}, { __mode = "k" })
        local recurseCount = setmetatable({}, { __mode = "k" })
        -- Custom subscribers are ordinary Lua calls, so they are below the
        -- native trigger/timer boundaries that DebugUtils wraps automatically.
        -- Use its wrapper here to retain mapped diagnostics without rethrowing.
        local debug_try = Debug.try

        ---@type fun(self: EVENT, u: unit, ...)
        function thistype:trigger(u, ...)
            if not u then return end

            if DEV_ENABLED and RuntimeMetrics then
                RuntimeMetrics.events.triggers = RuntimeMetrics.events.triggers + 1
            end

            -- grab or create the per‑unit table of in‑flight events
            local in_flight = recurse[u]
            if not in_flight then
                in_flight = {}
                recurse[u] = in_flight
                recurseCount[u] = 0
            end

            -- bail if this event is already running
            if in_flight[self] then
                return
            end

            -- mark the event
            in_flight[self] = true
            recurseCount[u] = recurseCount[u] + 1

            -- run all the associated actions
            local actions = self.unit_actions[u]
            if actions then
                for i = 1, #actions do
                    if DEV_ENABLED and RuntimeMetrics then
                        RuntimeMetrics.events.callbacks = RuntimeMetrics.events.callbacks + 1
                    end
                    debug_try(actions[i], u, ...)
                end
            end

            -- clear the mark
            in_flight[self] = nil
            recurseCount[u] = recurseCount[u] - 1

            -- TODO: less burden on gc?
            if recurseCount[u] == 0 then
                recurse[u] = nil
                recurseCount[u] = nil
            end
        end

        ---@type fun(self: EVENT, u: unit, func: function): boolean
        function thistype:register_unit_action(u, func)
            if not u then
                return false
            end
            if not self.unit_actions[u] then
                self.unit_actions[u] = {}
            end
            -- prevent duplicate registers
            if not TableHas(self.unit_actions[u], func) then
                self.unit_actions[u][#self.unit_actions[u] + 1] = func
                return true
            end

            return false
        end

        ---@param u unit
        ---@return boolean
        function thistype:has_unit_actions(u)
            local actions = u and self.unit_actions[u]
            return actions ~= nil and #actions > 0
        end

        function thistype:unregister_unit_action(u, func)
            -- remove all registered functions for unit from every event
            if self == EVENT then
                for i = 1, #event_list do
                    event_list[i]:unregister_unit_action(u)
                end
                return
            end

            if not u or not self.unit_actions[u] then
                return
            end

            -- remove all registered functions if not specified
            if not func then
                self.unit_actions[u] = nil
            else
                TableRemove(self.unit_actions[u], func)
            end
        end
    end

    -- A completely different type of event that is not ascribed to units but players
    -- Unlike unit events it is not cleaned automatically upon removal of the unit (because units are not used)

    ---@class PLAYER_EVENT
    ---@field create function
    ---@field actions table
    ---@field trigger function
    ---@field register_action function
    ---@field unregister_action function
    PLAYER_EVENT = {}
    do
        local thistype = PLAYER_EVENT
        local event_mt = { __index = thistype }
        local debug_try = Debug.try

        ---@return PLAYER_EVENT
        function PLAYER_EVENT.create()
            local self = setmetatable({
                actions = {},
            }, event_mt)

            return self
        end

        ---@type fun(self: EVENT, pid: integer, ...)
        function thistype:trigger(pid, ...)
            if DEV_ENABLED and RuntimeMetrics then
                RuntimeMetrics.events.triggers = RuntimeMetrics.events.triggers + 1
            end

            -- run any actions registered with the player
            local actions = self.actions[pid]
            if actions then
                -- Cleanup callbacks commonly unregister themselves. Dispatch a
                -- stable snapshot so mutations affect the next trigger instead
                -- of skipping callbacks or exposing a nil array entry.
                local pending = {}
                for i = 1, #actions do
                    pending[i] = actions[i]
                end

                for i = 1, #pending do
                    if DEV_ENABLED and RuntimeMetrics then
                        RuntimeMetrics.events.callbacks = RuntimeMetrics.events.callbacks + 1
                    end
                    debug_try(pending[i], pid, ...)
                end
            end
        end

        ---@type fun(self: EVENT, pid: integer, func: function): boolean
        function thistype:register_action(pid, func)
            if not self.actions[pid] then
                self.actions[pid] = {}
            end
            -- prevent duplicate function registration
            if not TableHas(self.actions[pid], func) then
                self.actions[pid][#self.actions[pid] + 1] = func
                return true
            end

            return false
        end

        function thistype:unregister_action(pid, func)
            if not self.actions[pid] then
                return
            end

            -- remove all registered functions if not specified
            if not func then
                self.actions[pid] = nil
            else
                TableRemove(self.actions[pid], func)
            end
        end
    end

    -- event that is called when a unit's stat is changed (either from leveling, UnitTable, or UnitSetBonus)
    EVENT_STAT_CHANGE = EVENT.create() ---@type EVENT

    -- damage events
    EVENT_DUMMY_ON_HIT               = EVENT.create() ---@type EVENT
    EVENT_ON_HIT_EVADE               = EVENT.create() ---@type EVENT
    EVENT_ON_HIT                     = EVENT.create() ---@type EVENT
    EVENT_ON_HIT_MULTIPLIER          = EVENT.create() ---@type EVENT
    EVENT_ON_HIT_AFTER_REDUCTIONS    = EVENT.create() ---@type EVENT
    EVENT_ON_HIT_FINAL               = EVENT.create() ---@type EVENT
    EVENT_ON_STRUCK                  = EVENT.create() ---@type EVENT
    EVENT_ON_STRUCK_MULTIPLIER       = EVENT.create() ---@type EVENT
    EVENT_ON_STRUCK_AFTER_REDUCTIONS = EVENT.create() ---@type EVENT
    EVENT_ON_STRUCK_FINAL            = EVENT.create() ---@type EVENT
    EVENT_ON_FATAL_DAMAGE            = EVENT.create() ---@type EVENT
    EVENT_ENEMY_AI                   = EVENT.create() ---@type EVENT

    EVENT_ON_ATTACK                  = EVENT.create() ---@type EVENT

    -- death events
    EVENT_ON_UNIT_DEATH = EVENT.create()
    EVENT_GRAVE_DEATH   = EVENT.create()
    EVENT_ON_KILL       = EVENT.create()
    EVENT_ON_REVIVE     = EVENT.create()
    EVENT_ON_DEATH      = PLAYER_EVENT.create()

    -- shields
    EVENT_ON_SHIELD_APPLY = EVENT.create()
    EVENT_ON_SHIELD_EXPIRE = EVENT.create()

    -- unit order events
    EVENT_ON_AGGRO = EVENT.create()
    EVENT_ON_CAST = EVENT.create()
    EVENT_ON_ORDER = EVENT.create()

    -- regions
    EVENT_ON_ENTER_SAFE_AREA = EVENT.create()

    -- specific unit selection (with hotkey as well)
    EVENT_ON_UNIT_SELECT = EVENT.create()
    -- player event version
    EVENT_ON_SELECT = PLAYER_EVENT.create()

    -- mouse events
    EVENT_ON_MOUSE_MOVE = PLAYER_EVENT.create()
    EVENT_ON_M1_DOWN = PLAYER_EVENT.create()
    EVENT_ON_M1_UP = PLAYER_EVENT.create()
    EVENT_ON_M2_DOWN = PLAYER_EVENT.create()
    EVENT_ON_M2_UP = PLAYER_EVENT.create()

    -- on player repick or leave
    EVENT_ON_CLEANUP = PLAYER_EVENT.create()

    -- on player character setup
    EVENT_ON_SETUP = PLAYER_EVENT.create()

end, Debug and Debug.getLine())
