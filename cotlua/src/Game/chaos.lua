--[[
    chaos.lua

    A module that contains functions for transitioning to chaos mode.
]]

OnInit.final("Chaos", function(Require)
    Require('Units')
    Require('Boss')
    Require('ItemLookup')

    god_portal = nil ---@type unit 

    function OpenGodsPortal()
        local sfx = AddSpecialEffect("war3mapImported\\Rune Blue Aura.mdl", -1420., -15270.) ---@type effect 
        BlzSetSpecialEffectScale(sfx, 2.45)
        BlzPlaySpecialEffect(sfx, ANIM_TYPE_BIRTH)

        god_portal = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n01O'), -1409, -15255, 270)
        SetUnitPathing(god_portal, false)
        SetUnitPosition(god_portal, -1445, -15260)
    end

    function GoddessOfLife()
        PauseUnit(Boss[BOSS_LIFE].unit, false)
        UnitRemoveAbility(Boss[BOSS_LIFE].unit, FourCC('Avul'))
    end

    function SpawnGods()
        PauseUnit(Boss[BOSS_HATE].unit, false)
        UnitRemoveAbility(Boss[BOSS_HATE].unit, FourCC('Avul'))
        PauseUnit(Boss[BOSS_LOVE].unit, false)
        UnitRemoveAbility(Boss[BOSS_LOVE].unit, FourCC('Avul'))
        PauseUnit(Boss[BOSS_KNOWLEDGE].unit, false)
        UnitRemoveAbility(Boss[BOSS_KNOWLEDGE].unit, FourCC('Avul'))
    end

    function ZeknenExpire()
        UnitRemoveAbility(zeknen, FourCC('Avul'))
        PauseUnit(zeknen, false)
        SetCinematicScene(GetUnitTypeId(zeknen), GetPlayerColor(PLAYER_BOSS), "Zeknen", "Very well.", 5, 4)
    end

    local function ChaosTransition()
        local u = GetFilterUnit()
        local i = GetPlayerId(GetOwningPlayer(u)) ---@type integer 

        if (u ~= PUNCHING_BAG and
        UnitAlive(u) and
        GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
        (i == 10 or i == 11 or i == PLAYER_NEUTRAL_AGGRESSIVE) and
        RectContainsUnit(gg_rct_Colosseum, u) == false and
        RectContainsUnit(gg_rct_Infinite_Struggle, u) == false) and
        u ~= udg_SPONSOR then
            RemoveUnit(u)
        end

        return false
    end

    function SetupChaos()
        BANISH_FLAG = false

        -- change water color
        SetWaterBaseColorBJ(150.00, 0.00, 0.00, 0)
        -- crypt coffin
        RemoveDestructable(gg_dest_B003_1936)

        -- weird transition sound effect
        SoundHandler("Sound\\Interface\\BattleNetWooshStereo1.flac", false)

        DestroyQuest(Defeat_The_Horde_Quest)
        DestroyQuest(Evil_Shopkeeper_Quest_1)
        DestroyQuest(Evil_Shopkeeper_Quest_2)
        DestroyQuest(Key_Quest)

        SetDoodadAnimation(545, -663, 30.0, FourCC('D0CT'), true, "death", false)
        DestroyEffect(GODS_QUEST_MARKER)
        DestroyEffect(HORDE_QUEST_MARKER)

        -- remove units
        RemoveUnit(zeknen) -- zeknen
        RemoveUnit(gg_unit_h03A_0005) -- headhunter
        RemoveUnit(god_angel)
        RemoveUnit(gg_unit_n02Q_0382)
        RemoveUnit(kroresh)

        -- huntsman
        local facing = GetUnitFacing(gg_unit_h036_0002)
        local loc = {GetUnitX(gg_unit_h036_0002), GetUnitY(gg_unit_h036_0002)}
        RemoveUnit(gg_unit_h036_0002) -- huntsman
        CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h009'), loc[1], loc[2], facing)

        -- colosseum director
        BlzSetUnitSkin(gg_unit_h059_0714, FourCC('e000'))

        -- removes creeps and villagers
        local ug = CreateGroup()

        GroupEnumUnitsInRect(ug, WorldBounds.rect, Condition(ChaosTransition)) -- exception for struggle / colo

        -- remove ghosts
        for i = 1, #GHOST_UNITS do
            RemoveUnit(GHOST_UNITS[i])
        end

        for target in each(ug) do
            if target ~= udg_SPONSOR then
                RemoveUnit(target)
            end
        end

        -- replace villagers
        KILL_VILLAGERS() -- TODO: Spawn chaos villagers? (use effects)

        DestroyGroup(ug)

        -- town
        -- chaos merchant
        CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n0A2'), 1344., 1472., 270.)
        -- naga dungeon npc
        CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n01K'), -12363, -1185, 0)

        local u = User.first
        local x = 0. ---@type number 
        local y = 0. ---@type number 

        -- move players to fountain (unless in struggle or colosseum)
        while u do
            x = GetUnitX(Hero[u.id])
            y = GetUnitY(Hero[u.id])
            if not SELECTING_HERO[u.id] and RectContainsCoords(gg_rct_Colosseum, x, y) == false and RectContainsCoords(gg_rct_Infinite_Struggle, x, y) == false and RectContainsCoords(gg_rct_Church, x, y) == false then
                TableRemove(GODS_GROUP, u.player)
                MoveHeroLoc(u.id, TOWN_CENTER)
            end

            u = u.next
        end

        -- bosses

        -- clear spider webs in demon prince pit
        SetDoodadAnimation(7810., 1203., 1000., FourCC('D05Q'), false, "death", false)

        -- clean up bosses
        for i = BOSS_OFFSET, #Boss do
            RemoveUnit(Boss[i].unit)
            RemoveLocation(Boss[i].loc)
        end

        -- Demon Prince
        Boss.create(BOSS_DEMON_PRINCE, GetRectCenter(gg_rct_Demon_Prince_Boss_Spawn), 315.00, FourCC('N038'), "Demon Prince", 190,
        1, 2000)
        -- Absolute Horror
        Boss.create(BOSS_ABSOLUTE_HORROR, GetRectCenter(gg_rct_Absolute_Horror_Spawn), 270.00, FourCC('N017'), "Absolute Horror", 230,
        2, 2000)
        -- Orsted
        Boss.create(BOSS_ORSTED, GetRectCenter(gg_rct_Orsted_Boss_Spawn), 270.00, FourCC('N00F'), "Orsted", 250,
        3, 2000)
        -- Slaughter Queen
        Boss.create(BOSS_SLAUGHTER_QUEEN, Location(-5400, -15470), 135.00, FourCC('O02B'), "Slaughter Queen", 270,
        3, 2000)
        -- Satan
        Boss.create(BOSS_SATAN, GetRectCenter(gg_rct_Hell_Boss_Spawn), 315.00, FourCC('O02I'), "Satan", 310,
        5, 2000)
        -- Dark Soul
        Boss.create(BOSS_DARK_SOUL, GetRectCenter(gg_rct_Dark_Soul_Boss_Spawn), bj_UNIT_FACING, FourCC('O02H'), "Essence of Darkness", 300,
        3, 2000)
        -- Legion
        Boss.create(BOSS_LEGION, GetRectCenter(gg_rct_To_The_Forrest), bj_UNIT_FACING, FourCC('H04R'), "Legion", 340,
        8, 2000)
        -- Thanatos
        Boss.create(BOSS_THANATOS, GetRandomLocInRect(gg_rct_Thanatos_Boss_Spawn), bj_UNIT_FACING, FourCC('O02K'), "Thanatos", 320,
        5, 2000)
        -- Existence
        Boss.create(BOSS_EXISTENCE, GetRandomLocInRect(gg_rct_Existence_Boss_Spawn), bj_UNIT_FACING, FourCC('O02M'), "Pure Existence", 320,
        8, 2000)
        -- Azazoth
        Boss.create(BOSS_AZAZOTH, GetRectCenter(gg_rct_Azazoth_Boss_Spawn), 270.00, FourCC('O02T'), "Azazoth", 380,
        12, 2000)
        -- Xallarath
        Boss.create(BOSS_XALLARATH, GetRectCenter(gg_rct_Forgotten_Leader_Boss_Spawn), 135.00, FourCC('O03G'), "Xallarath", 360,
        12, 4000)

        BOSS_OFFSET = BOSS_DEMON_PRINCE

        -- minigame banners
        KILL_BANNERS()

        for i = 1, 4 do
            local s = AddSpecialEffect("war3mapImported\\DragonmawBannerHQ.mdl", GetRectCenterX(_G["gg_rct_ColoBanner" .. i]), GetRectCenterY(_G["gg_rct_ColoBanner" .. i]))
            local yaw = (math.fmod(i, 2) == 0 and 0) or bj_PI
            BlzSetSpecialEffectYaw(s, yaw)
        end

        -- chaotic enemies
        SpawnCreeps(1)

        forgotten_spawner = CreateUnit(PLAYER_BOSS, FourCC('o02E'), 15100., -12650., bj_UNIT_FACING)
        SetUnitAnimation(forgotten_spawner, "Stand Work")
        SpawnForgotten(5)
        TimerQueue:callDelayed(60., SpawnForgotten, 1)

        SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
        SetCineFilterBlendMode(BLEND_MODE_BLEND)
        SetCineFilterTexMapFlags(TEXMAP_FLAG_NONE)
        SetCineFilterStartUV(0, 0, 1, 1)
        SetCineFilterEndUV(0, 0, 1, 1)
        SetCineFilterStartColor(0, 0, 0, 255)
        SetCineFilterEndColor(0, 0, 0, 0)
        SetCineFilterDuration(2.5)
        TimerQueue:callDelayed(2.5, DisplayCineFilter, false)

        -- display main multiboard
        local id = GetPlayerId(GetLocalPlayer()) + 1
        MULTIBOARD.MAIN:display(id)

        CHAOS_LOADING = false
    end

    function BeginChaos(killed)
        -- 10 minute grace period for legion jumps
        TimerQueue:disableCallback(HUNT_TIMER)
        TimerQueue:callDelayed(600., function() TimerQueue:enableCallback(HUNT_TIMER) end)

        CHAOS_LOADING = true
        CHAOS_MODE = true

        if killed then
            RemoveUnit(killed)
        end

        RemoveUnit(god_portal)
        god_portal = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n00N'), -1409., -15255., 270)
        AddItemToStock(god_portal, FourCC('I08T'), 1, 1)

        DisplayTimedTextToForce(FORCE_PLAYING, 100, "|cff800807Without the Goddess of Life, unspeakable chaos walks the land and wreaks havoc on all life. Chaos spreads across the land and thus the chaotic world is born.")
        SoundHandler("Sound\\Interface\\GlueScreenEarthquake1.flac", false, nil, nil)

        SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
        SetCineFilterBlendMode(BLEND_MODE_BLEND)
        SetCineFilterTexMapFlags(TEXMAP_FLAG_NONE)
        SetCineFilterStartUV(0, 0, 1, 1)
        SetCineFilterEndUV(0, 0, 1, 1)
        SetCineFilterStartColor(0, 0, 0, 0)
        SetCineFilterEndColor(0, 0, 0, 255)
        SetCineFilterDuration(3.0)
        DisplayCineFilter(true)

        TimerQueue:callDelayed(3., SetupChaos)
    end

    -- setup god portal actions
    local function start_god_fight(p, pid, u, itm)
        if god_portal ~= nil and TableHas(GODS_GROUP, p) == false and CHAOS_MODE == false then
            GODS_GROUP[#GODS_GROUP + 1] = p

            BlzSetUnitFacingEx(Hero[pid], 45)
            MoveHero(pid, GetRectCenterX(gg_rct_GodsEntrance), GetRectCenterY(gg_rct_GodsEntrance))
            reselect(Hero[pid])

            if GodsEnterFlag == false then
                GodsEnterFlag = true
                DisplayTextToForce(FORCE_PLAYING, "This is your last chance to -flee.")

                SetCinematicScene(GetUnitTypeId(zeknen), GetPlayerColor(PLAYER_BOSS), "Zeknen", "Explain yourself or be struck down from this heaven!", 9, 8)
                TimerQueue:callDelayed(10., ZeknenExpire)
            end
        end
    end

    local function rescind_to_darkness(p, pid, u, itm)
        if GodsEnterFlag == false and CHAOS_MODE == false and GetHeroLevel(Hero[pid]) >= 300 then
            BeginChaos()
        end
    end

    ITEM_LOOKUP[FourCC('I0JO')] = start_god_fight
    ITEM_LOOKUP[FourCC('I0NO')] = rescind_to_darkness

end, Debug and Debug.getLine())
