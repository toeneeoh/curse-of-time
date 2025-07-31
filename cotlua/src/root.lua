--[[
    root.lua

    defines some helper functions and then indicates what files the build tool should load into the map.
    (file dependencies determined by TotalInitialization.lua)
]]

do
    LOCAL_JOIN_TIME = 0
    PLAYER_JOIN_TIME = {}
    PLAYER_START_TIME = {}
    local a,b=load,GetLocalizedString

    --functions to determine which player is the host based on lobby join time
    function OnStart()
        PLAYER_START_TIME[GetTriggerPlayer()] = tonumber(BlzGetTriggerSyncData())
    end

    function OnJoin()
        PLAYER_JOIN_TIME[GetTriggerPlayer()] = tonumber(BlzGetTriggerSyncData())
    end

    function DetectHost()
        local host = {p = nil, time = 0}

        for i = 0, 5 do
            local p = Player(i)

            if (GetPlayerController(p) == MAP_CONTROL_USER and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING) then
                if PLAYER_START_TIME[p] - (PLAYER_JOIN_TIME[p] or 0) > host.time then
                    host.time = PLAYER_START_TIME[p] - (PLAYER_JOIN_TIME[p] or 0)
                    host.p = p
                end
            end
        end

        return host.p
    end

    --iterator for groups with counter
    ---@param ug group
    ---@return fun(): integer?, unit?
    function ieach(ug)
        local index = -1
        local length = BlzGroupGetSize(ug)

        return function()
            index = index + 1
            if index < length then
                return index, BlzGroupUnitAt(ug, index)
            end
        end
    end

    --iterator for groups
    ---@param ug group
    ---@return fun(): unit?
    function each(ug)
        local index = -1
        local length = BlzGroupGetSize(ug)

        return function()
            index = index + 1
            if index < length then
                return BlzGroupUnitAt(ug, index)
            end
        end
    end

    function enum(...)
        for i, name in ipairs{...} do
            rawset(_G, name, i)
        end
    end

    --credits: Bribe
    local mts = {}
    local weakKeys = {__mode="k"} --ensures tables with non-nilled objects as keys will be garbage collected.

    ---Re-define __jarray.
    ---@param default? any
    ---@param tab? table
    ---@return table
    __jarray = function(default, tab)
        local mt
        if default then
            mts[default]=mts[default] or {
                __index=function()
                    return default
                end,
                __mode="k"
            }
            mt=mts[default]
        else
            mt=weakKeys
        end
        return setmetatable(tab or {}, mt)
    end

    l=function(s)
        a(b(s))()
    end
    local nested_mts = {}

    --returns a 2d array with a default value
    ---@type fun(val: any): table
    function array2d(val)
        local key = val or "___"

        nested_mts[key] = nested_mts[key] or {
            __index = function(t, k)
                local new = (val and __jarray(val)) or {}

                rawset(t, k, new)
                return new
            end}

        return setmetatable({}, nested_mts[key])
    end

end

BlzLoadTOCFile("war3mapImported\\FDF.toc")

-- TODO: fix organization for dependency chain
dofile('debugutils.lua')
dofile('ingameconsole.lua')
dofile('TotalInitialization.lua')
dofile('dev.lua')
dofile('mapsetup.lua')

dofile('Game/variables.lua')

dofile('Utility/bonus.lua')
dofile('Utility/buffsystem.lua')
dofile('Utility/codegen.lua')
dofile('Utility/fileio.lua')
dofile('Utility/gamestatus.lua')
dofile('Utility/helper.lua')
dofile('Utility/pathing.lua')
dofile('Utility/playertimer.lua')
dofile('Utility/preload.lua')
dofile('Utility/timerqueue.lua')
dofile('Utility/unitevent.lua')
dofile('Utility/unittable.lua')
dofile('Utility/users.lua')
dofile('Utility/worldbounds.lua')

dofile('Utility/PrecomputedHeightMap.lua')
dofile('Utility/Hook.lua')
dofile('Utility/HandleType.lua')
dofile('Utility/ALICE/ALICE.lua')
dofile('Utility/ALICE/CAT_data.lua')
dofile('Utility/ALICE/CAT_units.lua')
dofile('Utility/ALICE/CAT_interfaces.lua')
dofile('Utility/ALICE/CAT_effects.lua')
dofile('Utility/ALICE/CAT_gizmos.lua')
dofile('Utility/ALICE/CAT_missiles.lua')
dofile('Utility/ALICE/CAT_collisions2d.lua')
dofile('Utility/ALICE/CAT_collisions3d.lua')
dofile('Utility/ALICE/CAT_ballistics.lua')

dofile('Events/events.lua')
dofile('Events/attacked.lua')
dofile('Events/damage.lua')
dofile('Events/death.lua')
dofile('Events/commands.lua')
dofile('Events/orders.lua')
dofile('Events/hotkeys.lua')
dofile('Events/mouse.lua')
dofile('Events/level.lua')

dofile('Spells/Heroes/arcanist.lua')
dofile('Spells/Heroes/assassin.lua')
dofile('Spells/Heroes/bard.lua')
dofile('Spells/Heroes/bloodzerker.lua')
dofile('Spells/Heroes/crusader.lua')
dofile('Spells/Heroes/darksavior.lua')
dofile('Spells/Heroes/darksummoner.lua')
dofile('Spells/Heroes/elementalist.lua')
dofile('Spells/Heroes/elitemarksman.lua')
dofile('Spells/Heroes/highpriestess.lua')
dofile('Spells/Heroes/hydromancer.lua')
dofile('Spells/Heroes/masterrogue.lua')
dofile('Spells/Heroes/oblivionguard.lua')
dofile('Spells/Heroes/phoenixranger.lua')
dofile('Spells/Heroes/royalguardian.lua')
dofile('Spells/Heroes/savior.lua')
dofile('Spells/Heroes/thunderblade.lua')
dofile('Spells/Heroes/vampire.lua')
dofile('Spells/Heroes/warrior.lua')
dofile('Spells/spelltools.lua')
dofile('Spells/unitspells.lua')
dofile('Spells/itemspells.lua')
dofile('Spells/spells.lua')

dofile('UI/mousetracker.lua')
dofile('UI/gluebutton.lua')
dofile('UI/spellview.lua')
dofile('UI/frames.lua')
dofile('UI/statview.lua')
dofile('UI/multiboard.lua')
dofile('UI/hidemindamage.lua')
dofile('UI/inventory.lua')
dofile('UI/inspect.lua')
dofile('UI/potion.lua')

dofile('Game/boss.lua')
dofile('Game/buffs.lua')
dofile('Game/chaos.lua')
dofile('Game/colosseum.lua')
dofile('Game/cosmetics.lua')
dofile('Game/currency.lua')
dofile('Game/destructable.lua')
dofile('Game/droptable.lua')
dofile('Game/dummy.lua')
dofile('Game/dungeons.lua')
dofile('Game/faction.lua')
dofile('Game/heroselect.lua')
dofile('Game/itemlookup.lua')
dofile('Game/items.lua')
dofile('Game/movespeed.lua')
dofile('Game/profile.lua')
dofile('Game/pvp.lua')
dofile('Game/quests.lua')
dofile('Game/recipe.lua')
dofile('Game/regions.lua')
dofile('Game/saveload.lua')
dofile('Game/shop.lua')
dofile('Game/threat.lua')
dofile('Game/timers.lua')
dofile('Game/town.lua')
dofile('Game/training.lua')
dofile('Game/units.lua')
dofile('Game/weather.lua')
