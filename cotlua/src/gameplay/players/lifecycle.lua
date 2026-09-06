OnInit.global("PlayerLifecycle", function(Require)
    Require('Variables')
    Require('Groups')
    Require('PlayerCamera')
    Require('UnitHelpers')
    Require('Progression')
    Require('FrameHelpers')

    local stat_functions = {
        GetHeroStr,
        GetHeroInt,
        GetHeroAgi,
        function(_, _) return 0 end,
    }

    local function cleanup_bound_items(object, player)
        local item = Item[object]
        if item.owner == player then item:destroy() end
    end

    local function valid_item(object)
        return Item[object] and object ~= PATH_ITEM
    end

    ---@param pid integer
    function RemovePlayerUnits(pid)
        local group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, Player(pid - 1), nil)

        for target in each(group) do
            if not IsDummy(target) then
                EVENT:unregister_unit_action(target)
                Buff.dispelAll(target, true)
                RemoveUnit(target)
            end
        end
        DestroyGroup(group)
    end

    ---Use for player departure, repick, and permanent death cleanup.
    ---@type fun(pid: integer)
    function PlayerCleanup(pid)
        local player = Player(pid - 1)
        UnitRemoveAbility(Hero[pid], FourCC('A03C'))

        for _, cosmetic in ipairs(CosmeticTable.cosmetics) do
            local effect = cosmetic[pid .. cosmetic.name]
            if effect then DestroyEffect(effect) end
        end

        PLAYER_SELECTED_UNIT[pid] = nil
        ALICE_ForAllObjectsDo(cleanup_bound_items, "item", valid_item, player)
        EVENT_ON_CLEANUP:trigger(pid)
        TimerList[pid]:stopAllTimers()
        RemovePlayerUnits(pid)
        SetCameraLocked(pid, false)
        IS_AUTO_ATTACK_OFF[pid] = false
        SetCurrency(pid, GOLD, 0)
        SetCurrency(pid, PLATINUM, 0)
        SetCurrency(pid, CRYSTAL, 0)
        ResetPlayerLighting(pid)

        if GetLocalPlayer() == player then
            BlzFrameSetVisible(DPS_FRAME, false)
            DisplayCineFilter(false)
            BlzFrameSetText(MULTIBOARD.DAMAGE:get(2, 1).frame, " ")
        end
    end

    ---@type fun(p: player, p2: player, show: boolean)
    function ShowHeroPanel(p, p2, show)
        if show then
            SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, true, p)
            SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_CONTROL, false, p)
        else
            SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, false, p)
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

    ---@type fun(stat: integer, u: unit, bonuses: boolean): integer
    function GetHeroStat(stat, u, bonuses)
        return stat_functions[stat](u, bonuses)
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

    function ToggleTaunting(pid)
        if IS_TAUNT_DISABLED[pid] then
            DisplayTimedTextToForce(FORCE_PLAYING, 10,
                User[pid - 1].nameColored .. " toggled their taunts on.")
        else
            DisplayTimedTextToForce(FORCE_PLAYING, 10,
                User[pid - 1].nameColored .. " toggled their taunts off.")
        end
        IS_TAUNT_DISABLED[pid] = not IS_TAUNT_DISABLED[pid]
    end

    ---@type fun(pid: integer, x: number, y: number)
    function MoveHero(pid, x, y)
        SetUnitXBounded(Hero[pid], x)
        SetUnitYBounded(Hero[pid], y)
        SetUnitXBounded(HeroGrave[pid], x)
        SetUnitYBounded(HeroGrave[pid], y)
        BlzUnitClearOrders(Hero[pid], false)

        local region = GetRectFromCoords(x, y)
        if region then SetCamera(pid, region) end
    end

    ---@type fun(pid: integer, x: number, y: number, percenthp: number, percentmana: number)
    function RevivePlayer(pid, x, y, percenthp, percentmana)
        local player = Player(pid - 1)
        DisableBackpackTeleports(pid, false)
        DisableItems(pid, false)
        ReviveHero(Hero[pid], x, y, true)
        SetWidgetLife(Hero[pid], BlzGetUnitMaxHP(Hero[pid]) * percenthp)
        SetUnitState(Hero[pid], UNIT_STATE_MANA,
            GetUnitState(Hero[pid], UNIT_STATE_MAX_MANA) * percentmana)
        PanCameraToTimedForPlayer(player, x, y, 0)
        SetUnitFlyHeight(Hero[pid], 0, 0)
        reselect(Hero[pid])
        SetUnitTimeScale(Hero[pid], 1.)
        SetUnitPropWindow(Hero[pid], bj_DEGTORAD * 60.)
        SetUnitPathing(Hero[pid], true)
        EVENT_ON_REVIVE:trigger(Hero[pid])
    end
end)
