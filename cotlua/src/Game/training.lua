--[[
    training.lua

    Sets up the training arena zone
]]

OnInit.final("Training", function(Require)
    Require('Events')
    Require('ItemLookup')
    Require('Units')

    local prechaosTrainer = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h001'), 26205., 252., 270.)
    local chaosTrainer = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h001'), 29415., 252., 270.)
    do
        local itm = UnitAddItemById(prechaosTrainer, FourCC('I0MY'))
        BlzSetItemName(itm.obj, "|cffffcc00" .. GetObjectName(FourCC('nitt')) .. "|r")
        BlzSetItemIconPath(itm.obj, BlzGetAbilityIcon(FourCC('nitt')))
        itm.spawn = 0

        itm = UnitAddItemById(chaosTrainer, FourCC('I0MY'))
        BlzSetItemName(itm.obj, "|cffffcc00" .. GetObjectName(FourCC('n033')) .. "|r")
        BlzSetItemIconPath(itm.obj, BlzGetAbilityIcon(FourCC('n033')))
        itm.spawn = 29 --chaos unit start
    end

    -- enter training
    ITEM_LOOKUP[FourCC('I0MT')] = function(p, pid, u)
        if RectContainsCoords(MAIN_MAP.rect, GetUnitX(u), GetUnitY(u)) then
            if GetHeroLevel(Hero[pid]) < 160 then --prechaos
                x = GetRandomReal(GetRectMinX(gg_rct_PrechaosTraining_Vision), GetRectMaxX(gg_rct_PrechaosTraining_Vision))
                y = GetRandomReal(GetRectMinY(gg_rct_PrechaosTraining_Vision), GetRectMaxY(gg_rct_PrechaosTraining_Vision))
            else --chaos
                x = GetRandomReal(GetRectMinX(gg_rct_ChaosTraining_Vision), GetRectMaxX(gg_rct_ChaosTraining_Vision))
                y = GetRandomReal(GetRectMinY(gg_rct_ChaosTraining_Vision), GetRectMaxY(gg_rct_ChaosTraining_Vision))
            end

            MoveHero(pid, x, y)
            reselect(Hero[pid])
        end
    end

    -- exit training
    ITEM_LOOKUP[FourCC('I0MW')] = function(p, pid, u)
        if RectContainsCoords(gg_rct_PrechaosTrainingSpawn, GetUnitX(u), GetUnitY(u)) then
            local ug = CreateGroup()
            GroupEnumUnitsInRect(ug, gg_rct_PrechaosTrainingSpawn, Condition(ishostile))

            if not FirstOfGroup(ug) then
                MoveHero(pid, GetRectCenterX(gg_rct_Training_Exit), GetRectCenterY(gg_rct_Training_Exit))
                reselect(Hero[pid])
            else
                DisplayTextToPlayer(p, 0, 0, "You must kill all enemies before leaving!")
            end

            DestroyGroup(ug)
        elseif RectContainsCoords(gg_rct_ChaosTrainingSpawn, GetUnitX(u), GetUnitY(u)) then
            local ug = CreateGroup()
            GroupEnumUnitsInRect(ug, gg_rct_ChaosTrainingSpawn, Condition(ishostile))

            if not FirstOfGroup(ug) then
                MoveHero(pid, GetRectCenterX(gg_rct_Training_Exit), GetRectCenterY(gg_rct_Training_Exit))
                reselect(Hero[pid])
            else
                DisplayTextToPlayer(p, 0, 0, "You must kill all enemies before leaving!")
            end

            DestroyGroup(ug)
        end
    end

    -- only reward xp and gold from training
    local function on_death(killed, killer)
        RewardXPGold(killed, killer)
        TimerQueue:callDelayed(3., RemoveUnit, killed)
    end

    -- spawn unit
    ITEM_LOOKUP[FourCC('I0MS')] = function(p, pid, u)
        local flag = (RectContainsCoords(gg_rct_PrechaosTrainingSpawn, GetUnitX(u), GetUnitY(u)) and 0) or 1
        local trainer = ((flag == 0) and prechaosTrainer) or chaosTrainer
        local trainerItem = Item[UnitItemInSlot(trainer, 0)]
        local r = ((flag == 0) and gg_rct_PrechaosTrainingSpawn) or gg_rct_ChaosTrainingSpawn

        u = CreateUnit(PLAYER_CREEP, UnitData[trainerItem.spawn], GetRandomReal(GetRectMinX(r), GetRectMaxX(r)), GetRandomReal(GetRectMinY(r), GetRectMaxY(r)), GetRandomReal(0,359))
        EVENT_ON_UNIT_DEATH:register_unit_action(u, on_death)
    end

    -- change difficulty
    ITEM_LOOKUP[FourCC('I0MU')] = function(p, pid, u, itm)
        local increase = (itm.id == FourCC('I0MU') and true) or false
        local flag = (RectContainsCoords(gg_rct_PrechaosTrainingSpawn, GetUnitX(u), GetUnitY(u)) and 0) or 1
        local trainer = ((flag == 0) and prechaosTrainer) or chaosTrainer
        local trainerItem = Item[UnitItemInSlot(trainer, 0)]

        if increase == true then
            trainerItem.spawn = trainerItem.spawn + 1
            if UnitData[UnitData[trainerItem.spawn]].mode ~= flag then
                trainerItem.spawn = trainerItem.spawn - 1
            end
        else
            trainerItem.spawn = math.max(0, trainerItem.spawn - 1)
            if UnitData[UnitData[trainerItem.spawn]].mode ~= flag then
                trainerItem.spawn = trainerItem.spawn + 1
            end
        end

        -- update item info
        BlzSetItemName(trainerItem.obj, "|cffffcc00" .. GetObjectName(UnitData[trainerItem.spawn]) .. "|r")
        -- blzgetability icon works for units as well
        BlzSetItemIconPath(trainerItem.obj, BlzGetAbilityIcon(UnitData[trainerItem.spawn]))
    end

    ITEM_LOOKUP[FourCC('I0MV')] = ITEM_LOOKUP[FourCC('I0MU')]
end, Debug and Debug.getLine())
