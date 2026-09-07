-- Registries shared by item content and the Warcraft pickup/sell adapter.

OnInit.global("ItemEventRegistry", function()
    ON_BUY_LOOKUP = {}
    ITEM_LOOKUP = {}

    local changed = {}
    local debug_try = Debug.try

    ---@param callback fun(pid: integer)
    function RegisterItemChangedAction(callback)
        for index = 1, #changed do
            if changed[index] == callback then
                return false
            end
        end

        changed[#changed + 1] = callback
        return true
    end

    ---@param pid integer
    function NotifyItemChanged(pid)
        for index = 1, #changed do
            -- These subscribers are nested Lua callbacks rather than native
            -- trigger actions, so invoke them through the existing diagnostic
            -- boundary and allow later presentation subscribers to refresh.
            debug_try(changed[index], pid)
        end
    end
end, Debug and Debug.getLine())
