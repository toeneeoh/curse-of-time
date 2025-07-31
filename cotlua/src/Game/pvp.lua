OnInit.final("PVP", function(Require)
    Require('Users')
    Require('Events')
    Require('ItemLookup')

    local ARENA_FFA = 1
    local ArenaQueue = __jarray(0) ---@type integer[] 
    local Arena = {
        {}, {}, {}
    }

    -- frame setup
    local exit = SimpleButton.create(BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "war3mapImported\\ExitButton.blp", 0.03, 0.015, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., 0.015)
    BlzFrameClearAllPoints(exit.frame)
    BlzFrameSetPoint(exit.frame, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_CENTER, 0, -0.154)
    BlzFrameSetVisible(exit.frame, false)
    --

    ---@type fun(pid: integer): integer?
    local function GetArena(pid)
        for i, v in ipairs(Arena) do
            if TableHas(v, pid) then
                return i
            end
        end

        return nil
    end

    local arena_death
    local ArenaSpawn = {
        -- spawn location and associated facing angle
        [2] = {gg_rct_Arena1Spawn1, gg_rct_Arena1Spawn2, 270, 90},
        [3] = {gg_rct_Arena3Spawn1, gg_rct_Arena3Spawn2, 0, 180},
    }

    ---@type fun(pid: integer)
    local function unpause_arena(pid)
        PauseUnit(Hero[pid], false)
        UnitRemoveAbility(Hero[pid], FourCC('Avul'))
    end

    ---@type fun(pid: integer, tpid: integer, time: integer)
    local function countdown(pid, tpid, time)
        time = time - 1

        if time == 0 then
            -- start
            PauseUnit(Hero[pid], false)
            PauseUnit(Hero[tpid], false)
            SoundHandler("Sound\\Interface\\GameFound.wav", false, Player(pid - 1), nil)
            SoundHandler("Sound\\Interface\\GameFound.wav", false, Player(tpid - 1), nil)
            DisplayTextToPlayer(Player(pid - 1), 0, 0, "FIGHT!")
            DisplayTextToPlayer(Player(tpid - 1), 0, 0, "FIGHT!")
        else
            -- tick sound
            SoundHandler("Sound\\Interface\\BattleNetTick.wav", false, Player(pid - 1), nil)
            SoundHandler("Sound\\Interface\\BattleNetTick.wav", false, Player(tpid - 1), nil)
            DisplayTextToPlayer(Player(pid - 1), 0, 0, (time + 1) .. "...")
            DisplayTextToPlayer(Player(tpid - 1), 0, 0, (time + 1) .. "...")
            TimerQueue:callDelayed(1., countdown, pid, tpid, time)
        end
    end

    local function on_death(killed, killer, amount)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1
        local kpid = GetPlayerId(GetOwningPlayer(killer)) + 1
        amount.value = 0
        UnitRemoveBuffs(killed, true, true)
        Buff.dispelAll(killed)
        DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has been slain by " .. User[kpid - 1].nameColored .. "!")
        UnitAddAbility(killed, FourCC('Avul'))
        SetUnitAnimation(killed, "death")
        PauseUnit(killed, true)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIem\\AIemTarget.mdl", killer, "origin"))
        arena_death(killed, killer)
    end

    ---@param arena integer
    local function reset_arena(arena)
        if not arena or arena == ARENA_FFA then
            return
        end

        local U = User.first

        while U do
            if TableHas(Arena[arena], U.id) then
                PauseUnit(Hero[U.id], false)
                UnitRemoveAbility(Hero[U.id], FourCC('Avul'))
                SetUnitAnimation(Hero[U.id], "stand")
                MoveHeroLoc(U.id, TOWN_CENTER)
            end

            U = U.next
        end
    end

    local function on_cleanup(pid)
        reset_arena(GetArena(pid))
        ArenaQueue[pid] = 0
    end

    ---@param spawn1 rect
    ---@param spawn2 rect
    ---@param face number
    ---@param face2 number
    ---@param arena integer
    local function setup_duel(pid, tpid, spawn1, spawn2, face, face2, arena)
        local x  = GetRectCenterX(spawn1) ---@type number 
        local y  = GetRectCenterY(spawn1) ---@type number 
        local x2 = GetRectCenterX(spawn2) ---@type number 
        local y2 = GetRectCenterY(spawn2) ---@type number 
        local p  = Player(pid - 1)
        local p2 = Player(tpid - 1)

        ArenaQueue[pid] = 0
        ArenaQueue[tpid] = 0

        CleanupSummons(p)
        CleanupSummons(p2)

        Arena[arena][#Arena[arena] + 1] = Player(pid - 1)
        Arena[arena][#Arena[arena] + 1] = Player(tpid - 1)

        DisplayTextToPlayer(p, 0, 0, User[tpid - 1].nameColored .. " has joined the arena.")
        DisplayTextToPlayer(p2, 0, 0, User[pid - 1].nameColored .. " has joined the arena.")

        --randomize start location
        if GetRandomInt(0, 1) == 1 then
            local tempX = x
            local tempY = y
            local tempFace = face

            x = x2
            y = y2
            face = face2

            x2 = tempX
            y2 = tempY
            face2 = tempFace
        end

        MoveHero(pid, x, y)
        MoveHero(tpid, x2, y2)
        BlzSetUnitFacingEx(Hero[pid], face)
        BlzSetUnitFacingEx(Hero[tpid], face2)

        SetPlayerAllianceStateBJ(p, p2, bj_ALLIANCE_UNALLIED)
        SetPlayerAllianceStateBJ(p2, p, bj_ALLIANCE_UNALLIED)

        if IS_HERO_PANEL_ON[pid * PLAYER_CAP + tpid] then
            ShowHeroPanel(p, p2, true)
        end

        if IS_HERO_PANEL_ON[tpid * PLAYER_CAP + pid] then
            ShowHeroPanel(p2, p, true)
        end

        PauseUnit(Hero[pid], true)
        PauseUnit(Hero[tpid], true)

        TimerQueue:callDelayed(1., countdown, pid, tpid, 3)

        EVENT_ON_FATAL_DAMAGE:register_unit_action(Hero[pid], on_death)
        EVENT_ON_FATAL_DAMAGE:register_unit_action(Hero[tpid], on_death)
        -- no need to unregister these
        EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
        EVENT_ON_CLEANUP:register_action(tpid, on_cleanup)
    end

    ---@type fun(arena: integer, killed: unit)
    local function arena_cleanup(arena, killed)

        if arena == ARENA_FFA then
            local pid = GetPlayerId(GetOwningPlayer(killed)) + 1
            TableRemove(Arena[arena], pid)
            SetUnitAnimation(killed, "stand")
            MoveHeroLoc(pid, TOWN_CENTER)
            SetWidgetLife(killed, BlzGetUnitMaxHP(killed))
            ArenaQueue[pid] = 0
            TimerQueue:callDelayed(2., unpause_arena, pid)
        else
            for _, pid in ipairs(Arena[arena]) do
                SetUnitAnimation(Hero[pid], "stand")
                SetWidgetLife(Hero[pid], BlzGetUnitMaxHP(Hero[pid]))
                MoveHeroLoc(pid, TOWN_CENTER)
                ArenaQueue[pid] = 0
                TimerQueue:callDelayed(2., unpause_arena, pid)
            end
            Arena[arena] = {}
        end
    end

    ---@param killed unit
    ---@param killer unit
    arena_death = function(killed, killer)
        local U    = User.first ---@type User 
        local p    = GetOwningPlayer(killed)
        local p2   = GetOwningPlayer(killer)
        local pid  = GetPlayerId(p) + 1 ---@type integer 
        local tpid = GetPlayerId(p2) + 1 ---@type integer 
        local arena = GetArena(pid)

        if arena == ARENA_FFA then
            while U do
                SetPlayerAllianceStateBJ(U.player, p, bj_ALLIANCE_ALLIED_VISION)
                SetPlayerAllianceStateBJ(p, U.player, bj_ALLIANCE_ALLIED_VISION)
                if IS_HERO_PANEL_ON[pid * PLAYER_CAP + (tpid - 1)] then
                    ShowHeroPanel(p, p2, true)
                end

                if IS_HERO_PANEL_ON[tpid * PLAYER_CAP + (pid - 1)] then
                    ShowHeroPanel(p2, p, true)
                end
                U = U.next
            end
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(killed, on_death)
        else
            PauseUnit(killer, true)
            UnitAddAbility(killer, FourCC('Avul'))
            SetPlayerAllianceStateBJ(p, p2, bj_ALLIANCE_ALLIED_VISION)
            SetPlayerAllianceStateBJ(p2, p, bj_ALLIANCE_ALLIED_VISION)
            if IS_HERO_PANEL_ON[pid * PLAYER_CAP + (tpid - 1)] then
                ShowHeroPanel(p, p2, true)
            end

            if IS_HERO_PANEL_ON[tpid * PLAYER_CAP + (pid - 1)] then
                ShowHeroPanel(p2, p, true)
            end
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(killed, on_death)
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(killer, on_death)
        end

        --timer, cleanup
        TimerQueue:callDelayed(3., arena_cleanup, arena, killed)
    end

    ---@type fun(arena: integer, pid: integer): integer?
    local function first_of_arena(arena, pid)
        local U = User.first ---@type User 

        while U do
            local tpid = GetPlayerId(U.player) + 1

            if pid ~= tpid and ArenaQueue[tpid] == arena then
                return tpid
            end

            U = U.next
        end

        return nil
    end

    ---@type fun(arena: integer): integer
    local function in_arena_queue(arena)
        local U = User.first ---@type User 
        local count = 0

        while U do
            if ArenaQueue[U.id] == arena then
                count = count + 1
            end

            U = U.next
        end

        return count
    end

    local function in_queue_range(pid)
        if ArenaQueue[pid] == 0 then
            return
        end

        if IsUnitInRangeXY(Hero[pid], -1900., 1100., 1000.) == false then
            ArenaQueue[pid] = 0
            DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5.0, "You have been removed from the PvP queue.")
        else
            TimerQueue:callDelayed(1, in_queue_range, pid)
        end
    end

    local function exit_button()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1

        DisableBackpackTeleports(pid, false)

        if GetLocalPlayer() == p then
            BlzFrameSetVisible(exit.frame, false)
        end

        MoveHeroLoc(pid, TOWN_CENTER)
        ArenaQueue[pid] = 0
        TableRemove(Arena[ARENA_FFA], pid)

        local U = User.first
        while U do
                SetPlayerAllianceStateBJ(U.player, Player(pid - 1), bj_ALLIANCE_ALLIED_VISION)
                SetPlayerAllianceStateBJ(Player(pid - 1), U.player, bj_ALLIANCE_ALLIED_VISION)

                if IS_HERO_PANEL_ON[pid * PLAYER_CAP + U.id] then
                    ShowHeroPanel(Player(pid - 1), U.player, true)
                end

                if IS_HERO_PANEL_ON[U.id * PLAYER_CAP + pid] then
                    ShowHeroPanel(U.player, Player(pid - 1), true)
                end
            U = U.next
        end
        EVENT_ON_FATAL_DAMAGE:unregister_unit_action(Hero[pid], on_death)
    end
    exit:onClick(exit_button)

    local function enter_pvp()
        local p     = GetTriggerPlayer()
        local pid   = GetPlayerId(p) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local arena = dw:getClickedIndex(GetClickedButton()) + 1 ---@type integer 

        if arena > 0 then

            local tpid = first_of_arena(arena, pid)

            if not GetArena(pid) then
                if arena == ARENA_FFA then
                    Arena[arena][#Arena[arena] + 1] = pid

                    CleanupSummons(p)
                    local x, y
                    repeat
                        x = GetRandomReal(GetRectMinX(gg_rct_Arena2), GetRectMaxX(gg_rct_Arena2))
                        y = GetRandomReal(GetRectMinY(gg_rct_Arena2), GetRectMaxY(gg_rct_Arena2))
                    until IsTerrainWalkable(x, y)

                    MoveHero(pid, x, y)

                    local U = User.first

                    while U do
                        SetPlayerAllianceStateBJ(U.player, p, bj_ALLIANCE_UNALLIED)
                        SetPlayerAllianceStateBJ(p, U.player, bj_ALLIANCE_UNALLIED)

                        if IS_HERO_PANEL_ON[pid * PLAYER_CAP + (U.id - 1)] then
                            ShowHeroPanel(p, U.player, true)
                        end

                        if IS_HERO_PANEL_ON[U.id * PLAYER_CAP + (pid - 1)] then
                            ShowHeroPanel(U.player, p, true)
                        end
                        U = U.next
                    end

                    EVENT_ON_FATAL_DAMAGE:register_unit_action(Hero[pid], on_death)
                    if GetLocalPlayer() == p then
                        BlzFrameSetVisible(exit.frame, true)
                    end
                    DisableBackpackTeleports(pid, true)
                    DisplayTextToPlayer(p, 0, 0, "You may leave at any time by pressing the EXIT button below.")
                else
                    ArenaQueue[pid] = arena
                    local num = in_arena_queue(arena)

                    if #Arena[arena] > 0 then
                        DisplayTextToPlayer(p, 0, 0, "This arena is occupied already!")
                        ArenaQueue[pid] = 0
                    elseif num == 1 then
                        DisplayTextToPlayer(p, 0, 0, "Waiting for an opponent to join...")
                        TimerQueue:callDelayed(1., in_queue_range, pid)
                    elseif num == 2 then
                        setup_duel(pid, tpid, ArenaSpawn[arena][1], ArenaSpawn[arena][2], ArenaSpawn[arena][3], ArenaSpawn[arena][4], arena)
                        DisableBackpackTeleports(pid, true)
                    end
                end
            end

            dw:destroy()
        end
    end

    ITEM_LOOKUP[FourCC('PVPA')] = function(p, pid)
        local dw = DialogWindow.create(pid, "Choose an arena.", enter_pvp) ---@type DialogWindow

        dw:addButton("Wastelands [FFA]")
        dw:addButton("Pandaren Forest [Duel]")
        dw:addButton("Ice Cavern [Duel]")

        dw:display()
    end

    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end

end, Debug and Debug.getLine())
