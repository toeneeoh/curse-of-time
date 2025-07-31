--[[
    dev.lua

    A library used for debugging and testing.
]]

OnInit.final("Dev", function(Require)
    DEV_ENABLED         = true
    SAVE_LOAD_VERSION   = 0x40000000
    MAP_NAME            = "CoT Nevermore BETA"
    EXTRA_DEBUG         = false ---@type boolean 
    BUDDHA_MODE         = {} ---@type boolean[] 
    DEBUG_COUNT         = 0 ---@type integer 
    WEATHER_OVERRIDE    = 0 ---@type integer 

    Require('GameStatus')
    GAME_STATE          = (GAME_STATE == 0) and 2 or GAME_STATE -- keep game state as replay if replay

    Require('TimerQueue')
    local pack, find, lower = string.pack, string.find, string.lower
    local searchable = {} ---@type boolean[] 
    local dev_cmds, wipe_item_stats, find_item, event_setup

    local help_table = {
        ["nocd"] = "Toggles spell and item cooldowns off",
        ["cd"] = "Toggles spell and item cooldowns on",
        ["nocost"] = "Toggles spell and item mana costs off",
        ["cost"] = "Toggles spell and item mana costs on",
        ["sight"] = "Sets your hero's sight radius to #. usage: -sight [0-1800]",
        ["dummycount"] = "Prints the number of dummies in the dummy pool",
        ["vision"] = "Reveals the whole map",
        ["novision"] = "Reenables fog of war",
        ["sp"] = "Set the amount of platinum you have to #. usage: -sp [#]",
        ["sc"] = "Set the amount of crystals you have to #. usage: -sc [#]",
        ["sh"] = "Set the amount of honor you have to #. usage: -sh [#]",
        ["sf"] = "Set the amount of faction points you have to #. usage: -sf [#]",
        ["lvl"] = "Set the selected hero's level to #. usage: -lvl [1-500]",
        ["str"] = "Set the selected hero's strength to #. usage: -str [#]",
        ["agi"] = "Set the selected hero's agility to #. usage: -agi [#]",
        ["int"] = "Set the selected hero's intelligence to #. usage: -int [#]",
        ["g"] = "Set the amount of gold you have to #. usage: -g [#]",
        ["day"] = "Set the time of day to morning.",
        ["night"] = "Set the time of day to midnight.",
        ["si"] = "Search for an item by name. usage: -si [Azazoth]",
        ["gi"] = "Give the selected unit an item by id #. usage: -gi [#]",
        ["hero"] = "Spawns an allied hero with player id # and hero type #. usage: -hero [#] [#]. Potentially buggy",
        ["enterchaos"] = "Triggers the transition into chaos",
        ["shopkeeper"] = "Pings the location of the evil shopkeeper",
        ["setweather"] = "Randomly changes the weather with no second argument or changes it to id #. usage: -setweather [#]",
        ["noborders"] = "Allows you to view the entire map",
        ["bossrespawn"] = "Toggles 5 second boss respawn time on/off",
        ["heal"] = "Fully restores the health and mana of the selected unit.",
        ["hp"] = "Sets the maximum health of the selected unit. usage: -hp [#]",
        ["armor"] = "Sets the armor of the selected unit. usage: -armor [#]",
        ["armortype"] = "Sets the armor type of the selected unit. usage: -armortype [0-7]",
        ["boost"] = "Toggles the spellboost +/-20% variance on/off",
        ["hurt"] = "Damages the selected unit by a percent #. usage: hurt [1-100]",
        ["buddha"] = "Prevents your hero from dying",
        ["tp"] = "Teleports the selected unit to your cursor's position.",
        ["dmg"] = "Sets the base damage of the selected unit to #. usage: -dmg [#]",

        ["shadowstep"] = "Forces legion / death knight to cast shadow step / death march.",

        ["anim"] = "Plays the animation of the selected unit by id #. usage: -anim [#] (usually 0-10, depends on number of animations)",

        ["itemlevel"] = "Sets the level of the item in your hero's first slot to #. usage: -itemlevel [#]",
        ["maxlevel"] = "Sets the level of the item in your hero's first slot to its maximum.",
        ["itemset"] = "Sets the formula of the item in your hero's first slot. usage: -itemset [tier 1][damage 5|10=2>2%150@2][spellboost*5]. see -help syntax for more item formula info.",
        ["itemformula"] = "Prints the current formula of the item in your hero's first slot.",
        ["restock"] = "Moves the evil shopkeeper to a random location and refreshes his stock.",

        ["syntax"] = [[[tier #] - tier name (0-24)|n[req #] - level requirement
[upg #] - max number of item upgrades for enhancer
[type #] - proficiency (0-all, 1-plate, 2-fullplate, 3-leather, 4-cloth, 5-shield, 6-heavy, 7-sword, 8-dagger, 9-bow, 10-staff)
[limit #] - multiple item restriction (1 - can only have one, 2+ special error messages)
[cost #] - upgrade item price
other keywords: armor, str, agi, int, regen, damage, spellboost, cd (crit damage), cc (crit chance), health, mana, dr, mr, ms, evasion, bat, gold

modifiers:
* - stat is fixed per level // for stuff like spellboost and damage resist that has linear scaling
| - value range
= - flat scaling per level
> - flat scaling per rarity
% - percent scaling per level (default is 100%) // this one is ignorable
@ - unlocks at specified level
# - ability id"]],
        ["go"] = "Lazy command to pick a hero quickly"
    }

    local function BUDDHA(target, source, amount)
        amount.value = 0.
    end

    local function NOCOST(source)
        if not Unit[source].nomanaregen then
            SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MAX_MANA))
        end
    end

    local function reset_cd(source)
        UnitResetCooldown(source)
    end

    local function NOCD(source)
        TimerQueue:callDelayed(0.1, reset_cd, source)
    end

    local boost_mt = {
        __index = function(tbl, key)
            return (1. + Unit[Hero[key]].spellboost)
        end,
        __newindex = function() end,
    }

    --lookup table
    dev_cmds = {
        ["nocd"] = function(p, pid, args)
            if EVENT_ON_ORDER:register_unit_action(Hero[pid], NOCD) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "No cd enabled")
            else
                EVENT_ON_ORDER:unregister_unit_action(Hero[pid], NOCD)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "No cd disabled")
            end

            if EVENT_ON_ORDER:register_unit_action(Backpack[pid], NOCD) then
            else
                EVENT_ON_ORDER:unregister_unit_action(Backpack[pid], NOCD)
            end
        end,
        ["nocost"] = function(p, pid, args)
            if EVENT_ON_ORDER:register_unit_action(Hero[pid], NOCOST) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "No cost enabled")
            else
                EVENT_ON_ORDER:unregister_unit_action(Hero[pid], NOCOST)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "No cost disabled")
            end
        end,
        ["sight"] = function(p, pid, args)
            local r = 400.

            if args[2] then
                r = S2I(args[2])
            end

            BlzSetUnitRealField(Hero[pid], UNIT_RF_SIGHT_RADIUS, r)
        end,
        ["dummycount"] = function(p, pid, args)
            print(DUMMY_COUNT)
        end,
        ["vision"] = function(p, pid, args)
            FogMaskEnable(false)
            FogEnable(false)
        end,
        ["novision"] = function(p, pid, args)
            FogMaskEnable(true)
            FogEnable(true)
        end,
        ["sp"] = function(p, pid, args)
            SetCurrency(pid, PLATINUM, S2I(args[2]))
        end,
        ["sc"] = function(p, pid, args)
            SetCurrency(pid, CRYSTAL, S2I(args[2]))
        end,
        ["sh"] = function(p, pid, args)
            SetCurrency(pid, HONOR, S2I(args[2]))
        end,
        ["sf"] = function(p, pid, args)
            SetCurrency(pid, FACTION, S2I(args[2]))
        end,
        ["lvl"] = function(p, pid, args)
            if GetHeroLevel(PLAYER_SELECTED_UNIT[pid]) > S2I(args[2]) then
                UnitStripHeroLevel(PLAYER_SELECTED_UNIT[pid], GetHeroLevel(PLAYER_SELECTED_UNIT[pid]) - S2I(args[2]))
            else
                SetHeroLevel(PLAYER_SELECTED_UNIT[pid], S2I(args[2]), false)
            end
            ExperienceControl(pid)
        end,
        ["str"] = function(p, pid, args)
            Unit[PLAYER_SELECTED_UNIT[pid]].str = S2I(args[2])
        end,
        ["agi"] = function(p, pid, args)
            Unit[PLAYER_SELECTED_UNIT[pid]].agi = S2I(args[2])
        end,
        ["int"] = function(p, pid, args)
            Unit[PLAYER_SELECTED_UNIT[pid]].int = S2I(args[2])
        end,
        ["g"] = function(p, pid, args)
            SetCurrency(pid, GOLD, S2I(args[2]))
        end,
        ["day"] = function(p, pid, args)
            SetTimeOfDay(5.95)
        end,
        ["night"] = function(p, pid, args)
            SetTimeOfDay(18.01)
        end,
        ["si"] = function(p, pid, args)
            local search = ""

            for i = 2, #args do
                search = search .. args[i] .. " "
            end
            search = search:gsub("\x25s+$", "")

            find_item(search, pid)
        end,
        ["gi"] = function(p, pid, args)
            if args[2] then
                local itm = CreateItem(FourCC(args[2]), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
                local min_lvl = IMaxBJ(0, ItemData[FourCC(args[2])][ITEM_UPGRADE_MAX] - ITEM_MAX_LEVEL_VARIANCE)
                itm:lvl(min_lvl)
                PlayerAddItem(pid, itm)
            end
        end,
        ["hero"] = function(p, pid, args)
            local id = S2I(args[2])
            local type = S2I(args[3])

            if id <= PLAYER_CAP and GetPlayerSlotState(Player(id - 1)) ~= PLAYER_SLOT_STATE_PLAYING and type and type ~= 0 then
                if not User[id - 1] then
                    User.create(id - 1)
                end

                if not Profile[id] then
                    Profile[id] = Profile.create(id)
                    event_setup(id)
                else
                    PlayerCleanup(id)
                end

                SelectHero(id, SAVE_UNIT_TYPE[type])
            end
        end,
        ["sharecontrol"] = function(p, pid, args)
            SetPlayerAlliance(Player(S2I(args[2]) - 1), p, ALLIANCE_SHARED_CONTROL, true)
        end,
        ["enterchaos"] = function(p, pid, args)
            OpenGodsPortal()
            BeginChaos()
        end,
        ["settime"] = function(p, pid, args)
            Profile[pid].hero.time = S2I(args[2])
        end,
        ["punchingbags"] = function(p, pid, args)
            local max = S2I(args[2])

            for i = 0, S2I(args[2]) do
                local r = bj_PI * 2 * i / max
                CreateUnit(PLAYER_CREEP, FourCC('h02D'), GetUnitX(Hero[pid]) + math.cos(r) * 30 * i / max, GetUnitY(Hero[pid]) + math.sin(r) * 30 * i / max, 270.)
            end
        end,
        ["shopkeeper"] = function(p, pid, args)
            PingMinimap(GetUnitX(evilshopkeeper), GetUnitY(evilshopkeeper), 3)
        end,
        ["setweather"] = function(p, pid, args)
            local w = (args[2] and S2I(args[2])) or 0

            WEATHER_OVERRIDE = w
            WeatherPeriodic()
        end,

        ["getrate"] = function(p, pid, args)
            local rate = args[2]

            if rate then
                rate = FourCC(rate)

                for i = 1, ItemDrops[rate][100] do
                    print(ItemDrops[rate][i .. "\x25"])
                end
            end
        end,
        ["noborders"] = function(p, pid, args)
            if GetLocalPlayer() == p then
                SetCameraField(CAMERA_FIELD_ROTATION, 90., 0)
                SetCameraBounds(WorldBounds.minX, WorldBounds.minY, WorldBounds.minX, WorldBounds.maxY, WorldBounds.maxX, WorldBounds.maxY, WorldBounds.maxX, WorldBounds.minY)
            end
            SetMinimapTexture(pid, "war3mapImported\\minimap_noborders.dds")
        end,
        ["bossrespawn"] = function(p, pid, args)
            args[2] = args[2] or 5
            
            BOSS_RESPAWN_TIME = args[2]
            print("Boss respawn time set to " .. args[2] .. " seconds")
        end,
        ["pause"] = function(p, pid, args)
            PauseUnit(Hero[pid], true)
        end,
        ["unpause"] = function(p, pid, args)
            PauseUnit(Hero[pid], false)
        end,
        ["setfirestorm"] = function(p, pid, args)
            firestormRate = S2I(args[2])
        end,
        ["horde"] = function(p, pid, args)
            for _ = 0, 39 do
                CreateUnitAtLoc(PLAYER_CREEP, FourCC('n07R'), GetUnitLoc(Hero[pid]), GetRandomReal(0, 359))
            end
        end,
        ["kill"] = function(p, pid, args)
            DamageTarget(Hero[pid], PLAYER_SELECTED_UNIT[pid], BlzGetUnitMaxHP(PLAYER_SELECTED_UNIT[pid]) * 2., ATTACK_TYPE_NORMAL, PURE, "Kill")
        end,
        ["ally"] = function(p, pid, args)
            CreateUnit(p, FourCC(args[2]), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]) - 300., GetRandomReal(0, 359))
        end,
        ["setowner"] = function(p, pid, args)
            SetUnitOwner(PLAYER_SELECTED_UNIT[pid], Player(S2I(args[2])), true)
        end,
        ["enemy"] = function(p, pid, args)
            CreateUnit(PLAYER_CREEP, FourCC(args[2]), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]) - 300., GetRandomReal(0, 359))
        end,
        ["donation"] = function(p, pid, args)
            print("weather rate: " .. R2S(donation))
        end,
        ["help"] = function(p, pid, args)
            local text = ""

            if help_table[args[2]] then
                text = help_table[args[2]]
            else
                for key, _ in pairs(dev_cmds) do
                    text = text .. "-" .. key .. " "
                end
            end

            DisplayTextToPlayer(p, 0, text:len() ^ 0.05 - 0.8, text)
        end,
        ["killall"] = function(p, pid, args)
            local ug = CreateGroup()

            GroupEnumUnitsInRect(ug, WorldBounds.rect, nil)

            for target in each(ug) do
                KillUnit(target)
            end

            DestroyGroup(ug)
        end,
        ["print"] = function(p, pid, args)
            print(StringHash(args[2]))
        end,
        ["printc"] = function(p, pid, args)
            print(FourCC(args[2]))
        end,
        ["test"] = function(p, pid, args)
            SetCurrency(pid, GOLD, 9999999)
            SetCurrency(pid, PLATINUM, 9999)
            SetCurrency(pid, CRYSTAL, 9999)
            SetHeroLevel(Hero[pid], 400, false)
            FogMaskEnable(false)
            FogEnable(false)
            ExperienceControl(pid)
        end,
        ["heal"] = function(p, pid, args)
            SetWidgetLife(PLAYER_SELECTED_UNIT[pid], BlzGetUnitMaxHP(PLAYER_SELECTED_UNIT[pid]))
            SetUnitState(PLAYER_SELECTED_UNIT[pid], UNIT_STATE_MANA, BlzGetUnitMaxMana(PLAYER_SELECTED_UNIT[pid]))
        end,
        ["ms"] = function(p, pid, args)
            args[2] = args[2] and S2I(args[2]) or GetUnitMoveSpeed(Hero[pid])

            Unit[Hero[pid]].overmovespeed = args[2]
        end,
        ["yeah"] = function(p, pid, args)
            print((StringHash(GetLocalizedString("TRIGSTR_001"))))
        end,
        ["invul"] = function(p, pid, args)
            if GetUnitAbilityLevel(PLAYER_SELECTED_UNIT[pid], FourCC('Avul')) > 0 then
                UnitRemoveAbility(PLAYER_SELECTED_UNIT[pid], FourCC('Avul'))
            else
                UnitAddAbility(PLAYER_SELECTED_UNIT[pid], FourCC('Avul'))
            end
        end,
        ["colo"] = function(p, pid, args)
            ColoPlayerCount = S2I(args[2])
        end,
        ["hp"] = function(p, pid, args)
            SetWidgetLife(PLAYER_SELECTED_UNIT[pid], S2I(args[2]))
            BlzSetUnitMaxHP(PLAYER_SELECTED_UNIT[pid], S2I(args[2]))
        end,
        ["armor"] = function(p, pid, args)
            BlzSetUnitArmor(PLAYER_SELECTED_UNIT[pid], S2I(args[2]))
        end,
        ["armortype"] = function(p, pid, args)
            BlzSetUnitIntegerField(PLAYER_SELECTED_UNIT[pid], UNIT_IF_DEFENSE_TYPE, S2I(args[2]))
        end,
        ["boost"] = function(p, pid, args)
            if BOOST_OFF then
                DisplayTextToPlayer(p, 0, 0, "Boost enabled.")
                BOOST_OFF = false
                setmetatable(BOOST, nil)
            else
                DisplayTextToPlayer(p, 0, 0, "Boost disabled.")
                BOOST_OFF = true
                local U = User.first
                while U do
                    BOOST[U.id] = nil
                    U = U.next
                end
                setmetatable(BOOST, boost_mt)
            end
        end,
        ["hurt"] = function(p, pid, args)
            SetWidgetLife(PLAYER_SELECTED_UNIT[pid], GetWidgetLife(PLAYER_SELECTED_UNIT[pid]) - BlzGetUnitMaxHP(PLAYER_SELECTED_UNIT[pid]) * 0.01 * S2I(args[2]))
        end,
        ["buddha"] = function(p, pid, args)
            if BUDDHA_MODE[pid] then
                EVENT_ON_FATAL_DAMAGE:unregister_unit_action(Hero[pid], BUDDHA)
                DisplayTextToPlayer(p, 0, 0, "Buddha disabled.")
                BUDDHA_MODE[pid] = false
            else
                EVENT_ON_FATAL_DAMAGE:register_unit_action(Hero[pid], BUDDHA)
                DisplayTextToPlayer(p, 0, 0, "Buddha enabled.")
                BUDDHA_MODE[pid] = true
            end
        end,
        ["saveall"] = function(p, pid, args)
            local U = User.first
            while U do
                Profile[pid]:save()
                U = U.next
            end
        end,
        ["tp"] = function(p, pid, args)
            SetUnitPosition(PLAYER_SELECTED_UNIT[pid], GetMouseX(pid), GetMouseY(pid))
        end,
        ["extradebug"] = function(p, pid, args)
            EXTRA_DEBUG = not EXTRA_DEBUG
        end,
        ["astar"] = function(p, pid, args)
            A_STAR_PATHING = not A_STAR_PATHING
        end,
        ["currentorder"] = function(p, pid, args)
            print((GetUnitCurrentOrder(PLAYER_SELECTED_UNIT[pid])))
            print(OrderId2String(GetUnitCurrentOrder(PLAYER_SELECTED_UNIT[pid])))
        end,
        ["currenttarget"] = function(p, pid, args)
            local target = Unit[PLAYER_SELECTED_UNIT[pid]].target

            print((target and GetUnitName(target)) or "no target")
        end,
        ["dmg"] = function(p, pid, args)
            BlzSetUnitBaseDamage(PLAYER_SELECTED_UNIT[pid], S2I(args[2]), 0)
        end,
        ["getitemabilstring"] = function(p, pid, args)
            print((ItemData[Profile[pid].hero.items[1]][ITEM_ABILITY .. "data"]))
        end,
        ["getitemdata"] = function(p, pid, args)
            print((ItemData[Profile[pid].hero.items[1]][S2I(args[2])]))
        end,
        ["itemdata"] = function(p, pid, args)
            SetItemUserData(Profile[pid].hero.items[1].obj, S2I(args[2]))
        end,
        ["anim"] = function(p, pid, args)
            SetUnitAnimationByIndex(PLAYER_SELECTED_UNIT[pid], S2I(args[2]))
        end,
        ["shadowstep"] = function(p, pid, args)
            ShadowStepExpire(true)
        end,
        ["rotate"] = function(p, pid, args)
            BlzSetUnitFacingEx(PLAYER_SELECTED_UNIT[pid], S2R(args[2]))
        end,
        ["position"] = function(p, pid, args)
            print(R2S(GetUnitX(PLAYER_SELECTED_UNIT[pid])) .. " " .. R2S(GetUnitY(PLAYER_SELECTED_UNIT[pid])))
        end,
        ["skills"] = function(p, pid, args)
            print(BlzGetAbilityStringLevelField(BlzGetUnitAbilityByIndex(Hero[pid], S2I(args[2])), ABILITY_SLF_TOOLTIP_NORMAL, 0))
            print(BlzGetAbilityStringField(BlzGetUnitAbilityByIndex(Hero[pid], S2I(args[2])), ABILITY_SF_NAME))
            print(pack(">I4", BlzGetAbilityId(BlzGetUnitAbilityByIndex(Hero[pid], S2I(args[2])))))
        end,
        ["makeitem"] = function(p, pid, args)
            CreateItem(FourCC('I0OX'), 0, 0)
        end,
        ["itemtest"] = function(p, pid, args)
            CreateItem(FourCC('I0OX'), 0, 0, 10)
        end,
        ["FourCC"] = function(p, pid, args)
            print(FourCC(args[2]))
        end,
        ["itemlevel"] = function(p, pid, args)
            Profile[pid].hero.items[1]:lvl(S2I(args[2]))
        end,
        ["maxlevel"] = function(p, pid, args)
            Profile[pid].hero.items[1]:lvl(ItemData[Profile[pid].hero.items[1].id][ITEM_UPGRADE_MAX])
        end,
        ["itemset"] = function(p, pid, args)
            local items = Profile[pid].hero.items
            items[1]:drop()
            wipe_item_stats(items[1].id)
            local text = ""
            for i = 2, #args do
                text = text .. args[i] .. " "
            end
            ParseItemTooltip(items[1].obj, text)
            items[1]:update()
            items[1]:equip()
        end,
        ["mousecoords"] = function(p, pid, args)
            local mouse_x = GetMouseFrameXStable()
            local mouse_y = GetMouseFrameYStable()

            print(mouse_x .. " " .. mouse_y)
        end,
        ["itemprint"] = function(p, pid, args)
            print(BlzGetItemExtendedTooltip(UnitItemInSlot(Hero[pid], 0)))
        end,
        ["itemformula"] = function(p, pid, args)
            print(ItemData[GetItemTypeId(UnitItemInSlot(Hero[pid], 0))][ITEM_TOOLTIP])
        end,
        ["mode"] = function(p, pid, args)
            print(GetLocalizedString("ASSET_MODE"))
        end,
        ["ablev"] = function(p, pid, args)
            print(GetUnitAbilityLevel(Hero[pid], FourCC(args[2])))
        end,
        ["shunpo"] = function(p, pid, args)
            ShowUnit(PLAYER_SELECTED_UNIT[pid], false)
            ShowUnit(PLAYER_SELECTED_UNIT[pid], true)
        end,
        ["pathable"] = function(p, pid, args)
            if IsTerrainWalkable(GetMouseX(pid), GetMouseY(pid)) then
                print("yeah")
            end
        end,
        ["heropos"] = function(p, pid, args)
            print(R2S(GetUnitX(Hero[pid])))
            print(R2S(GetUnitY(Hero[pid])))
        end,
        ["setskin"] = function(p, pid, args)
            CosmeticTable[User[p].name][S2I(args[2])] = S2I(args[3])
        end,
        ["setaura"] = function(p, pid, args)
            CosmeticTable[User[p].name][S2I(args[2]) + DONATOR_AURA_OFFSET] = S2I(args[3])
        end,
        ["id2char"] = function(p, pid, args)
            print(GetObjectName(SAVE_UNIT_TYPE[S2I(args[2])]))
        end,
        ["addspell"] = function(p, pid, args)
            UnitAddAbility(PLAYER_SELECTED_UNIT[pid], FourCC(args[2]))
        end,
        ["removespell"] = function(p, pid, args)
            UnitRemoveAbility(PLAYER_SELECTED_UNIT[pid], FourCC(args[2]))
        end,
        ["restock"] = function(p, pid, args)
            ShopkeeperMove()
        end,
        ["host"] = function(p, pid, args)
            local host = DetectHost()

            if host then
                print("The host is " .. User[host].nameColored)
            end
        end,
        ["keys"] = function(p, pid, args)
            for index = 8,255 do
                local trigger = CreateTrigger()
                TriggerAddAction(trigger, function()
                    print("OsKey:",index, "meta",BlzGetTriggerPlayerMetaKey())
                end)
                local key = ConvertOsKeyType(index)
                for metaKey = 0,15,1 do
                    BlzTriggerRegisterPlayerKeyEvent(trigger, p, key, metaKey, true)
                    BlzTriggerRegisterPlayerKeyEvent(trigger, p, key, metaKey, false)
                end
            end
        end,
        ["handlecount"] = function(p, pid, args)
            local t = CreateTrigger()
            local i = GetHandleId(t)
            DestroyTrigger(t)
            print(i - 0x100000)
        end,
        ["gc"] = function()
            ---@diagnostic disable-next-line: undefined-global
            print(GC)
        end,

        ["benchmark"] = function(p, pid, args)
            iterations = (args[2] and S2I(args[2])) or 1000

            local Allied = function(object, p)
                return IsUnitAlly(object, p)
            end

            local print_name = function(object)
                print(GetUnitName(object))
            end

            local s = os.clock()
            for _ = 1, iterations do
                ALICE_ForAllObjectsInRangeDo(print_name, 0, 0, 500., "unit", Allied, Player(0))
                --
            end
            local e = os.clock()

            local time = e - s
            print(string.format("Function time: %.4f seconds", time))
        end,

        ["benchmark2"] = function(p, pid, args)
            iterations = (args[2] and S2I(args[2])) or 1000

            local Allied = function()
                local u = GetFilterUnit()

                return IsUnitAlly(u, p)
            end

            local s = os.clock()
            for _ = 1, iterations do
                local ug = CreateGroup()
                MakeGroupInRange(pid, ug, 0., 0., 500., Filter(Allied))
                DestroyGroup(ug)
                --
            end
            local e = os.clock()

            local time = e - s
            print(string.format("Function time: %.4f seconds", time))
        end,

        ["go"] = function(p, pid, args)
            local hero = (args[2]) or "oblivion"

            for _, v in ipairs(HERO_STATS) do
                local name = v.name:lower()

                if name:find(hero, nil, true) then
                    SelectHero(pid, v.id)
                    break
                end
            end
        end,
   }

    ---@param id integer
    wipe_item_stats = function(id)
        for i = 1, 30 do
            ItemData[id][i] = 0
            ItemData[id][i .. "range"] = 0
            ItemData[id][i .. "fpl"] = 0
            ItemData[id][i .. "fpr"] = 0
            ItemData[id][i .. "percent"] = 0
            ItemData[id][i .. "unlock"] = 0
            ItemData[id][i .. "fixed"] = 0
            ItemData[id][i .. "id"] = 0
            ItemData[id][i .. "data"] = 0
        end
    end

    ---@param pid integer
    event_setup = function(pid)
        local index = User.AmountPlaying
        MULTIBOARD.MAIN:addRows(1)
        MULTIBOARD.MAIN:get(index, 1).text = {0.02, 0, 0.09, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:get(index, 2).icon = {0.11, 0, MULTIBOARD.ICON_SIZE, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:get(index, 3).icon = {0.13, 0, MULTIBOARD.ICON_SIZE, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:get(index, 4).text = {0.15, 0, 0.08, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:get(index, 5).text = {0.23, 0, 0.03, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:get(index, 6).text = {0.26, 0, 0.03, MULTIBOARD.ICON_SIZE}
        MULTIBOARD.MAIN:refresh()

        local boss = MULTIBOARD.BOSS
        boss:addRows(1, false)
        local offset = pid + 3
        boss:get(offset, 1).icon = {0.02, 0.004, 0.015, 0.015}
        boss:get(offset, 2).text = {0.04, 0.002, 0.05, 0.0175}
        boss:get(offset, 3).text = {0.15, 0.002, 0.05, 0.0175}
        boss:showRow(offset, false)

        --alliance setup
        SetPlayerAllianceStateBJ(Player(PLAYER_TOWN), Player(pid - 1), bj_ALLIANCE_ALLIED)
        SetPlayerAlliance(Player(pid - 1), Player(PLAYER_NEUTRAL_PASSIVE), ALLIANCE_SHARED_SPELLS, true)

        local i = 0
        while i ~= bj_MAX_PLAYERS do

            local i2 = 0
            while i2 ~= bj_MAX_PLAYERS do
                if i ~= i2 then
                    SetPlayerAlliance(Player(i), Player(i2), ALLIANCE_SHARED_VISION, true)
                    SetPlayerAlliance(Player(i), Player(i2), ALLIANCE_SHARED_CONTROL, false)
                end
                i2 = i2 + 1
            end

            i = i + 1
        end
    end

    local function preload_items()
        local count = 0 ---@type integer 
        local itm ---@type item 

        -- I000 to I0SX
        for i = 0, 9000 do
            local name = GetObjectName(CUSTOM_ITEM_OFFSET + i)
            if name ~= "Default string" and name ~= "" then
                itm = OldCreateItem(CUSTOM_ITEM_OFFSET + i, 30000., 30000.)
                if GetItemType(itm) ~= ITEM_TYPE_POWERUP and GetItemType(itm) ~= ITEM_TYPE_CAMPAIGN then
                    searchable[i] = true
                end
                SetWidgetLife(itm, 1.)
                RemoveItem(itm)
            end

            count = count + 1

            -- ignore non word/digit characters
            if count == 10 then
                i = i + 7
            elseif count == 36 then
                i = i + 6
            elseif count == 62 then
                i = i + 181
                count = 0
            end
        end

        preload_items = function() end
    end

    local function SearchPage()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            local itm = CreateItem(dw.data[index], GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
            local min_lvl = IMaxBJ(0, ItemData[dw.data[index]][ITEM_UPGRADE_MAX] - ITEM_MAX_LEVEL_VARIANCE)
            itm:lvl(min_lvl)
            PlayerAddItem(pid, itm)

            dw:destroy()
        end

        return false
    end

    ---@param search string
    ---@param pid integer
    find_item = function(search, pid)
        local itemCode = "" ---@type string 
        local id       = 0 ---@type integer 
        local name     = "" ---@type string 
        local count    = 0 ---@type integer 
        local dw = DialogWindow.create(pid, "", SearchPage)

        preload_items()

        -- I000 to I0SX
        for i = 0, 9000 do
            id = CUSTOM_ITEM_OFFSET + i
            itemCode = pack(">I4", id)
            name = GetObjectName(id)
            if searchable[i] and find(lower(name), lower(search)) then
                dw:addButton(itemCode .. " - " .. name, id)
            end

            if dw.count >= DialogWindow.BUTTON_MAX then
                break
            end

            count = count + 1

            -- ignore non word/digit characters
            if count == 10 then
                i = i + 7
            elseif count == 36 then
                i = i + 6
            elseif count == 62 then
                i = i + 181
                count = 0
            end
        end

        dw:display()
    end

    local function dev_commands()
        local p    = GetTriggerPlayer()
        local pid  = GetPlayerId(p) + 1 ---@type integer 
        local args = {}

        --propogate args table
        for arg in GetEventPlayerChatString():gmatch("\x25S+") do
            args[#args + 1] = arg
        end

        if dev_cmds[args[1]:sub(2)] then
            dev_cmds[args[1]:sub(2)](p, pid, args)
        end
    end

    local devcmd = CreateTrigger()

    for i = 0, PLAYER_CAP - 1 do
        TriggerRegisterPlayerChatEvent(devcmd, Player(i), "-", false)
    end

    TriggerAddAction(devcmd, dev_commands)

    local function teleport(pid, is_down)
        if is_down then
            local u = PLAYER_SELECTED_UNIT[pid]
            SetUnitXBounded(u, GetMouseX(pid))
            SetUnitYBounded(u, GetMouseY(pid))
        end
    end
    RegisterHotkeyToFunc('P', "Dev Teleport", teleport)

    local setup = function(x, y)
        local pid = 1
        local p = Player(0)
        dev_cmds["go"](p, pid, {"go", "arcani"})

        SetUnitXBounded(Hero[pid], x)
        SetUnitYBounded(Hero[pid], y)
        PanCameraToTimedForPlayer(p, x, y, 0)
    end

    --- start somewhere
    -- TimerQueue:callDelayed(1.5, setup, 0, 0)

end, Debug and Debug.getLine())
