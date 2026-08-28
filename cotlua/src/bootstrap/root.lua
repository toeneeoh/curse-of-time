--[[
    root.lua

    defines some helper functions and then indicates what files the build tool should load into the map.
    (file dependencies determined by TotalInitialization.lua)
]]

do
    RuntimeMetrics = {
        items = { created = 0, destroyed = 0, live = 0, peak = 0 },
        initializers = { started = 0, completed = 0 },
        events = { triggers = 0, callbacks = 0 },
        damage = { events = 0 },
        enemy_ai = { evaluations = 0, dispatches = 0 },
        mouse_tracker = {
            active = false,
            ticks = 0,
            sessions = 0,
            active_time = 0.,
            started_at = nil,
            samples = 0,
            sample_time = 0.,
            max_sample_time = 0.,
            period = 0.0078125,
        },
        movespeed = {
            active = 0,
            peak = 0,
            ticks = 0,
            unit_updates = 0,
            sessions = 0,
            active_time = 0.,
            started_at = nil,
            samples = 0,
            sample_time = 0.,
            max_sample_time = 0.,
            period = 0.015625,
        },
        timer_queue = { scheduled = 0, executed = 0, active = 0, peak = 0 },
    }
    InitTrace = {}

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

    ---@return integer
    function enum(...)
        local count = 0
        for i, name in ipairs{...} do
            rawset(_G, name, i)
            count = count + 1
        end

        return count
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

dofile('vendor/debug_utils.lua')
dofile('devtools/console.lua')
dofile('vendor/total_initialization.lua')
dofile('bootstrap/environment.lua')
dofile('devtools/commands.lua')
dofile('bootstrap/map_setup.lua')

dofile('config/gameplay_constants.lua')
dofile('config/save_schema.lua')
dofile('gameplay/items/events.lua')

dofile('gameplay/combat/bonuses.lua')
dofile('gameplay/combat/buffs/engine.lua')
dofile('gameplay/persistence/codec.lua')
dofile('framework/wc3/file_io.lua')
dofile('devtools/runtime_log.lua')
dofile('framework/wc3/game_status.lua')
dofile('framework/wc3/legacy_helpers.lua')
dofile('framework/wc3/pathing.lua')
dofile('framework/scheduling/player_timer.lua')
dofile('framework/wc3/preload.lua')
dofile('framework/scheduling/timer_frame.lua')
dofile('framework/scheduling/timer_queue.lua')
dofile('framework/events/native_unit_events.lua')
dofile('gameplay/world/unit_table.lua')
dofile('gameplay/players/users.lua')
dofile('framework/wc3/world_bounds.lua')
dofile('gameplay/combat/shields.lua')
dofile('framework/collections/chain.lua')

dofile('framework/collections/priority_queue.lua')
dofile('framework/ui/dialog_window.lua')
dofile('framework/collections/circular_array.lua')
dofile('framework/ui/arcing_text_tag.lua')
dofile('framework/wc3/bezier_curve.lua')

dofile('vendor/alice/PrecomputedHeightMap.lua')
dofile('vendor/alice/HandleType.lua')
dofile('vendor/alice/ALICE.lua')
dofile('vendor/alice/CAT_data.lua')
dofile('vendor/alice/CAT_units.lua')
dofile('vendor/alice/CAT_interfaces.lua')
dofile('vendor/alice/CAT_effects.lua')
dofile('vendor/alice/CAT_gizmos.lua')
dofile('vendor/alice/CAT_missiles.lua')
dofile('vendor/alice/CAT_collisions2d.lua')
dofile('vendor/alice/CAT_collisions3d.lua')
dofile('vendor/alice/CAT_ballistics.lua')

dofile('framework/events/event_bus.lua')
dofile('gameplay/combat/attacks.lua')
dofile('gameplay/abilities/enemy_ai.lua')
dofile('gameplay/combat/damage.lua')
dofile('gameplay/combat/death.lua')
dofile('gameplay/players/commands.lua')
dofile('gameplay/players/unit_orders.lua')
dofile('gameplay/players/hotkeys.lua')
dofile('gameplay/players/mouse_input.lua')
dofile('gameplay/players/leveling.lua')

dofile('content/abilities/heroes/arcanist.lua')
dofile('content/abilities/heroes/assassin.lua')
dofile('content/abilities/heroes/bard.lua')
dofile('content/abilities/heroes/bloodzerker.lua')
dofile('content/abilities/heroes/crusader.lua')
dofile('content/abilities/heroes/dark_savior.lua')
dofile('content/abilities/heroes/dark_summoner.lua')
dofile('content/abilities/heroes/elementalist.lua')
dofile('content/abilities/heroes/elite_marksman.lua')
dofile('content/abilities/heroes/high_priestess.lua')
dofile('content/abilities/heroes/hydromancer.lua')
dofile('content/abilities/heroes/master_rogue.lua')
dofile('content/abilities/heroes/oblivion_guard.lua')
dofile('content/abilities/heroes/phoenix_ranger.lua')
dofile('content/abilities/heroes/royal_guardian.lua')
dofile('content/abilities/heroes/savior.lua')
dofile('content/abilities/heroes/thunderblade.lua')
dofile('content/abilities/heroes/vampire.lua')
dofile('content/abilities/heroes/warrior.lua')

dofile('content/abilities/bosses/absolute_horror.lua')
dofile('content/abilities/bosses/arkaden.lua')
dofile('content/abilities/bosses/azazoth.lua')
dofile('content/abilities/bosses/death_knight.lua')
dofile('content/abilities/bosses/demon_prince.lua')
dofile('content/abilities/bosses/dragoon.lua')
dofile('content/abilities/bosses/essence_of_darkness.lua')
dofile('content/abilities/bosses/forgotten_mystic.lua')
dofile('content/abilities/bosses/goddesses.lua')
dofile('content/abilities/bosses/hate.lua')
dofile('content/abilities/bosses/hellfire_magi.lua')
dofile('content/abilities/bosses/knowledge.lua')
dofile('content/abilities/bosses/last_dwarf.lua')
dofile('content/abilities/bosses/legion.lua')
dofile('content/abilities/bosses/love.lua')
dofile('content/abilities/bosses/minotaur.lua')
dofile('content/abilities/bosses/naga.lua')
dofile('content/abilities/bosses/orsted.lua')
dofile('content/abilities/bosses/perfect_being.lua')
dofile('content/abilities/bosses/satan.lua')
dofile('content/abilities/bosses/siren_of_the_tides.lua')
dofile('content/abilities/bosses/slaughter_queen.lua')
dofile('content/abilities/bosses/thanatos.lua')
dofile('content/abilities/bosses/vengeful_paladin.lua')
dofile('content/abilities/bosses/xallarath.lua')
dofile('content/abilities/bosses/init.lua')

dofile('gameplay/abilities/tools.lua')
dofile('gameplay/players/ability_controls.lua')
dofile('content/abilities/units/summons.lua')
dofile('gameplay/players/teleport_abilities.lua')
dofile('content/abilities/units/enemy_spells.lua')
dofile('gameplay/items/drop_ability.lua')
dofile('content/abilities/items/equipment_procs.lua')
dofile('content/abilities/items/equipment_mobility.lua')
dofile('content/abilities/items/active_items.lua')
dofile('content/abilities/items/auras.lua')
dofile('content/abilities/items/socketing.lua')
dofile('gameplay/abilities/registry.lua')

dofile('framework/ui/prompt.lua')
dofile('framework/ui/simple_button.lua')
dofile('ui/inventory/item_details.lua')
dofile('framework/ui/mouse_tracker.lua')
dofile('framework/ui/glue_button.lua')
dofile('ui/hud/spell_view.lua')
dofile('ui/hud/frames.lua')
dofile('ui/hud/stat_view.lua')
dofile('ui/hud/multiboard.lua')
dofile('ui/hud/hide_min_damage.lua')
dofile('ui/inventory/view.lua')
dofile('ui/inventory/inspect.lua')
dofile('ui/inventory/potion.lua')
dofile('ui/hud/buff_bar.lua')
dofile('ui/shop/view.lua')
dofile('ui/dialogs/shop_services.lua')

dofile('gameplay/world/boss.lua')
dofile('content/abilities/buffs/definitions.lua')
dofile('gameplay/world/chaos.lua')
dofile('gameplay/world/colosseum.lua')
dofile('gameplay/world/cosmetics.lua')
dofile('gameplay/economy/currency.lua')
dofile('gameplay/world/destructables.lua')
dofile('gameplay/world/drop_table.lua')
dofile('gameplay/world/dummy.lua')
dofile('gameplay/world/dungeons.lua')
dofile('gameplay/players/factions.lua')
dofile('gameplay/world/hero_select.lua')
dofile('gameplay/items/item_events.lua')
dofile('gameplay/items/item.lua')
dofile('gameplay/world/move_speed.lua')
dofile('gameplay/persistence/profile.lua')
dofile('gameplay/players/pvp.lua')
dofile('gameplay/world/quests.lua')
dofile('content/shops/blacksmith.lua')
dofile('gameplay/world/regions.lua')
dofile('gameplay/persistence/save_load.lua')
dofile('gameplay/combat/threat.lua')
dofile('gameplay/world/timers.lua')
dofile('gameplay/world/town.lua')
dofile('gameplay/world/training.lua')
dofile('gameplay/world/units.lua')
dofile('gameplay/world/weather.lua')
dofile('gameplay/economy/prices.lua')
dofile('gameplay/economy/tomes.lua')
dofile('gameplay/items/inventory.lua')
dofile('gameplay/shops/catalog.lua')
dofile('gameplay/shops/actions.lua')
dofile('gameplay/shops/services.lua')
dofile('gameplay/shops/quote.lua')
dofile('gameplay/shops/transaction.lua')
dofile('devtools/architecture_tests.lua')
