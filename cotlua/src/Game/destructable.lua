OnInit.final("Destructables", function(Require)
    Require('TimerQueue')

---@type fun(d: destructable, d2: destructable)
function DoBridge(d, d2)
    if GetDestructableLife(d) <= 0  then
        DestructableRestoreLife(d, GetDestructableMaxLife(d), true)
        SetDestructableAnimation(d, "birth")
    elseif GetDestructableLife(d) > 0 then
        KillDestructable(d)
    end
    TimerQueue:callDelayed(1., DestructableRestoreLife, d2, GetDestructableMaxLife(d2), true)
end

---@type fun(u: unit, u2: unit, d: destructable)
function DoWaygate(u, u2, d)
    if WaygateIsActive(u) then
        WaygateActivate(u, false)
        WaygateActivate(u2, false)
    else
        WaygateActivate(u, true)
        WaygateActivate(u2, true)
    end
    TimerQueue:callDelayed(1., DestructableRestoreLife, d, GetDestructableMaxLife(d), true)
end

---@type fun(d: destructable, d2: destructable)
function DoGate(d, d2)
    if GetDestructableLife(d) <= 0 then
        DestructableRestoreLife(d, GetDestructableMaxLife(d), true)
        SetDestructableAnimation(d, "stand")
    elseif GetDestructableLife(d) > 0 then
        KillDestructable(d)
        SetDestructableAnimation(d, "death alternate")
    end
    TimerQueue:callDelayed(1., DestructableRestoreLife, d2, GetDestructableMaxLife(d2), true)
end

local DTable = {
    --gates
    [gg_dest_DTlv_3795] = function(d) DoGate(gg_dest_ITg4_0445, d) end,
    [gg_dest_DTlv_3788] = function(d) DoGate(gg_dest_LTg3_1074, d) end,
    [gg_dest_DTlv_11055] = function(d) DoGate(gg_dest_ITtg_6978, d) end,
    [gg_dest_DTlv_8411] = function(d) DoGate(gg_dest_ITg1_8348, d) end,
    [gg_dest_DTlv_3778] = function(d) DoGate(gg_dest_LTe1_1075, d) end,
    [gg_dest_DTlv_3772] = function(d) DoGate(gg_dest_ITtg_0892, d) end,
    --waygates
    [gg_dest_DTlv_3796] = function(d) DoWaygate(gg_unit_nwgt_0024, gg_unit_nwgt_0023, d) end,
    [gg_dest_DTlv_3785] = function(d) DoWaygate(gg_unit_nwgt_0003, gg_unit_nwgt_0017, d) end,
    [gg_dest_DTlv_3774] = function(d) DoWaygate(gg_unit_nwgt_0010, gg_unit_nwgt_0010, d) end,
    --bridges
    [gg_dest_DTlv_3776] = function(d) DoBridge(gg_dest_DTs2_1495, d) end,
    [gg_dest_DTlv_4001] = function(d) DoBridge(gg_dest_DTs2_1073, d) end,
    --easter egg
    [gg_dest_LTcr_9593] = function(d) CreateItem(FourCC('Ipow'), GetDestructableX(d), GetDestructableY(d)) end,
    [gg_dest_LTbs_4010] = function(d) CreateItem(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTbs_4009] = function(d) CreateItem(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTcr_4012] = function(d) CreateItem(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTba_9594] = function(d) CreateItem(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_LTbs_4008] = function(d) CreateItem(DropTable:pickItem(69), GetWidgetX(d), GetWidgetY(d), 600.) end,
    [gg_dest_B007_3861] = function(d) CreateItem(FourCC('I042'), GetWidgetX(d), GetWidgetY(d)) end,
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
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3795)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3788)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_11055)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_8411)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3778)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3772)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3796)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3785)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3774)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_3776)
    TriggerRegisterDeathEvent(t, gg_dest_DTlv_4001)
    TriggerRegisterDeathEvent(t, gg_dest_LTcr_9593)

    TriggerAddCondition(t, Condition(DestructableDeath))
end, Debug and Debug.getLine())
