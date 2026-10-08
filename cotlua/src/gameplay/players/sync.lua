OnInit.global("PlayerSync", function(Require)
    Require('Users')

    ---@param prefix string
    ---@param callback code
    function SyncCallback(prefix, callback)
        local trigger = CreateTrigger()
        local user = User.first

        while user do
            BlzTriggerRegisterPlayerSyncEvent(trigger, user.player, prefix, false)
            user = user.next
        end

        TriggerAddCondition(trigger, Condition(callback))
    end
end, Debug and Debug.getLine())
