-- Development-only runtime log persisted through Warcraft's Preload FileIO.

OnInit.global("DevRuntimeLog", function(Require)
    Require('Variables')
    Require('FileIO')

    DevLog = {
        enabled = DEV_LOG_ENABLED and FileIO.enabled,
        path = MAP_NAME .. "\\dev\\runtime-player-" .. (GetPlayerId(GetLocalPlayer()) + 1) .. ".pld",
        entries = {},
    }

    local writing = false
    local original_print = print

    local function timestamp()
        return string.format("%010.3f", os.clock())
    end

    local function join(...)
        local values = {}
        for index = 1, select('#', ...) do
            values[index] = tostring(select(index, ...))
        end
        return table.concat(values, "    ")
    end

    function DevLog.flush()
        if DevLog.enabled and not writing then
            writing = true
            FileIO.Save(DevLog.path, table.concat(DevLog.entries, "\n") .. "\n")
            writing = false
        end
    end

    function DevLog.write(category, message, defer_flush)
        if not DevLog.enabled then return end
        DevLog.entries[#DevLog.entries + 1] = "[" .. timestamp() .. "] [" .. category .. "] " .. tostring(message)
        if not defer_flush then
            DevLog.flush()
        end
    end

    function DevLog.snapshot(label)
        if not DevLog.enabled then return end
        local items = RuntimeMetrics.items
        local initializers = RuntimeMetrics.initializers
        local events = RuntimeMetrics.events
        local enemy_ai = RuntimeMetrics.enemy_ai
        local timers = RuntimeMetrics.timer_queue
        DevLog.write("METRICS", string.format(
            "%s init=%d/%d items=%d/%d/%d peak=%d events=%d callbacks=%d damage=%d ai=%d/%d timers=%d peak=%d mouse_ticks=%d",
            label or "snapshot",
            initializers.completed, initializers.started,
            items.live, items.created, items.destroyed, items.peak,
            events.triggers, events.callbacks, RuntimeMetrics.damage.events,
            enemy_ai.dispatches, enemy_ai.evaluations,
            timers.active, timers.peak, RuntimeMetrics.mouse_tracker.ticks))
    end

    if not DevLog.enabled then return end

    -- Start a fresh file for each map process. FileIO.Save replaces the file,
    -- which also makes every subsequent entry visible before Warcraft exits.
    DevLog.entries[1] = "[" .. timestamp() .. "] [RUN] start player="
        .. (GetPlayerId(GetLocalPlayer()) + 1) .. " name=" .. GetPlayerName(GetLocalPlayer())
    DevLog.flush()

    print = function(...)
        original_print(...)
        if writing then return end
        local message = join(...)
        DevLog.write(message:find("ERROR at", 1, true) and "ERROR" or "PRINT", message)
    end

    -- Preserve an error raised before FileIO became available.
    if Debug.data.firstError then
        DevLog.write("EARLY_ERROR", Debug.data.firstError)
    end
end, Debug and Debug.getLine())
