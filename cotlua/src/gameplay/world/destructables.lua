OnInit.final("Destructables", function(Require)
    Require('Items')

---@type fun(d: destructable, d2: destructable)

local DTable = {
    [gg_dest_LTcr_9593] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTbs_4010] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTbs_4009] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTcr_4012] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTba_9594] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTbs_4008] = function(d) ItemRuntime.create(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_B007_3861] = function(d) ItemRuntime.create(FourCC('I042'), GetWidgetX(d), GetWidgetY(d)) end,
}

function DestructableDeath()
    local d = GetTriggerDestructable()

    DTable[d](d)

    return false
end

    local t = CreateTrigger()

    TriggerRegisterDeathEvent(t, gg_dest_B007_3861)
    TriggerRegisterDeathEvent(t, gg_dest_LTbs_4010)
    TriggerRegisterDeathEvent(t, gg_dest_LTbs_4009)
    TriggerRegisterDeathEvent(t, gg_dest_LTcr_4012)
    TriggerRegisterDeathEvent(t, gg_dest_LTba_9594)
    TriggerRegisterDeathEvent(t, gg_dest_LTbs_4008)
    TriggerRegisterDeathEvent(t, gg_dest_LTcr_9593)

    TriggerAddCondition(t, Condition(DestructableDeath))
end, Debug and Debug.getLine())
