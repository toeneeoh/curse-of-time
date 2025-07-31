--[[
    main.lua

    main entrypoint of the map
]]

--BlzFrameSetAbsPoint(BlzGetFrameByName("ConsoleUI", 0), FRAMEPOINT_BOTTOM, 0.4, -0.18)

-- welcome message
DisplayTimedTextToForce(FORCE_PLAYING, 15.00, "Welcome to Curse of Time RPG: |c009966ffNevermore|r\n\n")
DisplayTimedTextToForce(FORCE_PLAYING, 45.00, "Official |cff0080c0Discord|r for updates, bug reports, and non-hacked downloads:\n|c009ebef5https://discord.gg/peSTvTd|r\n\n")
DisplayTimedTextToForce(FORCE_PLAYING, 600.0, "\nType |c006969ff-new profile|r if you are completely new\nor |c00ff7f00-load|r if you want to load your hero or start a new one.")
DisplayTimedTextToForce(FORCE_PLAYING, 15.00, "Please read the Quests Menu for updates.")

-- hide load lag
SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
SetCineFilterBlendMode(BLEND_MODE_NONE)
SetCineFilterTexMapFlags(TEXMAP_FLAG_NONE)
SetCineFilterStartUV(0, 0, 1, 1)
SetCineFilterEndUV(0, 0, 1, 1)
SetCineFilterStartColor(0, 0, 0, 255)
SetCineFilterEndColor(0, 0, 0, 255)
SetCineFilterDuration(1.)
DisplayCineFilter(true)

ShowInterface(false, 0)
EnableUserControl(false)

-- god area doodad stuff
SetDoodadAnimation(-16300, 1000, 100, FourCC('D08O'), true, "Stand Work -1", false)
SetDoodadAnimation(1730, 750, 100, FourCC('D088'), true, "Stand Work", false)

-- determine host by syncing join and start times
TimerQueue:callDelayed(0., function()
    local ON_JOIN = CreateTrigger()
    local ON_START = CreateTrigger()

    for i = 0, PLAYER_CAP - 1 do
        BlzTriggerRegisterPlayerSyncEvent(ON_JOIN, Player(i), "join", false)
        BlzTriggerRegisterPlayerSyncEvent(ON_START, Player(i), "start", false)
    end
    TriggerAddAction(ON_JOIN, OnJoin)
    TriggerAddAction(ON_START, OnStart)

    BlzSendSyncData("join", tostring(LOCAL_JOIN_TIME))
    BlzSendSyncData("start", tostring(os.clock()))
end)
