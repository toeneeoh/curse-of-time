--[[
    frames.lua

    A library that modifies the base game's UI and creates extra UI for use elsewhere.
]]

OnInit.final("Frames", function(Require)
    Require('Gluebutton')
    Require('Events')

    -- Prevent multiplayer desyncs by forcing the creation of the QuestDialog frame
    BlzFrameClick(BlzGetFrameByName("UpperButtonBarQuestsButton", 0))
    BlzFrameClick(BlzGetFrameByName("QuestAcceptButton", 0))
    BlzFrameSetSize(BlzGetFrameByName("QuestItemListContainer", 0), 0.01, 0.01)
    BlzFrameSetSize(BlzGetFrameByName("QuestItemListScrollBar", 0), 0.001, 0.001)
    ForceUICancel()

    INVENTORYBACKDROP = {}

    --inventory buttons
    local function inventoryborders(index, x, y)
        INVENTORYBACKDROP[index] = BlzCreateFrameByType("BACKDROP", "PORTRAIT", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
        BlzFrameSetAbsPoint(INVENTORYBACKDROP[index], FRAMEPOINT_CENTER, x, y)
        BlzFrameSetSize(INVENTORYBACKDROP[index], 0.0375, 0.0375)
        BlzFrameSetVisible(INVENTORYBACKDROP[index], false)
    end

    inventoryborders(1, 0.5315, 0.0965)
    inventoryborders(2, 0.5715, 0.0965)
    inventoryborders(3, 0.5315, 0.058)
    inventoryborders(4, 0.5715, 0.058)
    inventoryborders(5, 0.5315, 0.0195)
    inventoryborders(6, 0.5715, 0.0195)

    -- main HUD
    do
        local FH = nil
        local ShowHideMenuButton = nil
        local F9QuestMenuButton = nil
        local F10MenuButton = nil
        local F11AlliesMenuButton = nil
        local F12ChatMenuButton = nil
        local PLAYER_UI_TEXTURE = "UI\\HumanPlayerUITexture.tga"
        local PLAYER_RESOURCE_TEXTURE = "UI\\HumanResourceTexture.tga"

        -- Create Top UI Bar Texture
        RESOURCE_BAR = BlzCreateFrameByType("BACKDROP", "FH", BlzGetFrameByName("ConsoleUIBackdrop", 0), "ButtonBackdropTemplate", 0)
        BlzFrameSetTexture(RESOURCE_BAR, PLAYER_RESOURCE_TEXTURE, 0, true)
        BlzFrameSetPoint(RESOURCE_BAR, FRAMEPOINT_TOP, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_TOP, 0, 0)
        BlzFrameSetSize(RESOURCE_BAR, .41, .0392)
        BlzFrameSetLevel(RESOURCE_BAR, 2)

        -- hide bottom and top console backgrounds
        BlzEnableUIAutoPosition(false)
        BlzFrameSetSize(BlzGetFrameByName("ConsoleUIBackdrop", 0), 0., 0.00001)

        -- portrait hp/mp black backdrop
        local backdrop = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetSize(backdrop, 0.095, 0.11)
        BlzFrameSetTexture(backdrop, "black.dds", 0, true)
        BlzFrameSetPoint(backdrop, FRAMEPOINT_BOTTOMLEFT, BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0), FRAMEPOINT_BOTTOMLEFT, -0.065, -0.026)
        BlzFrameSetEnable(backdrop, false)
        BlzFrameSetLevel(backdrop, 0)

        -- Create Bottom UI Texture
        PLAYERUI = BlzCreateFrameByType("SIMPLESTATUSBAR", "", backdrop, "", 0)
        BlzFrameClearAllPoints(PLAYERUI)
        BlzFrameSetTexture(PLAYERUI, PLAYER_UI_TEXTURE, 0, true)
        BlzFrameSetAbsPoint(PLAYERUI, FRAMEPOINT_BOTTOMLEFT, -0.018, 0.0)
        BlzFrameSetAbsPoint(PLAYERUI, FRAMEPOINT_TOPRIGHT, 0.817, 0.1625)
        BlzFrameSetValue(PLAYERUI, 100)

        -- Fix Minimap // not work?
        FH = BlzGetFrameByName("Minimap", 0)
        BlzFrameSetParent(FH, BlzGetFrameByName("ConsoleUIBackdrop", 0))

        -- FPS/Ping/APM (Default FPS/Ping/APM)
        FH = BlzGetFrameByName("ResourceBarFrame", 0)
        BlzFrameClearAllPoints(FH)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_CENTER, .42, .615)

        -- Day Night Clock (Default clock)
        FH = BlzFrameGetChild(BlzFrameGetChild(BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 5), 0)
        BlzFrameSetSize(BlzFrameGetChild(FH, 0), 0.02, 0.02)
        BlzFrameSetParent(FH, BlzGetFrameByName("ConsoleUIBackdrop", 0))
        BlzFrameSetScale(FH, .80)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_BOTTOMLEFT, 0.08, 0.12)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_TOPRIGHT, 0.0, 0.08)

        -- Real Time Clock (Custom)
        CLOCK_FRAME_TEXT = BlzCreateFrameByType("TEXT", "GameTime", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
        BlzFrameSetAbsPoint(CLOCK_FRAME_TEXT, FRAMEPOINT_CENTER, 0.25, 0.589)
        BlzFrameSetScale(CLOCK_FRAME_TEXT, 1.0)
        BlzFrameSetText(CLOCK_FRAME_TEXT, "00:00:00")
        BlzFrameSetTextColor(FH, BlzConvertColor(255, 255, 255, 255)) -- White

        local date = os.date
        local time = 0
        TimerQueue:callPeriodically(1., nil, function()
            time = time + 1
            BlzFrameSetText(CLOCK_FRAME_TEXT, date("!\x25H:\x25M:\x25S", time))
        end)

        -- Gold (Default Gold)
        FH = BlzGetFrameByName("ResourceBarGoldText", 0)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_TOPRIGHT, 0.375, 0.5965)
        BlzFrameSetTextColor(FH, BlzConvertColor(255, 255, 215, 0)) -- Gold

        -- Platinum (Default Lumber)
        FH = BlzGetFrameByName("ResourceBarLumberText", 0)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_TOPRIGHT, 0.5025, 0.5965)
        BlzFrameSetTextColor(FH, BlzConvertColor(255, 229, 228, 226)) -- Platinum

        -- Crystal (Default Food Supply)
        FH = BlzGetFrameByName("ResourceBarSupplyText", 0)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_TOPRIGHT, 0.5885, 0.5965)
        BlzFrameSetTextColor(FH, BlzConvertColor(255, 108, 160, 176)) -- Crystal Blue

        -- Honor (Custom)
        HONOR_TEXT = BlzCreateFrame("CurrencyText", RESOURCE_BAR, 0, 0)
        BlzFrameSetAbsPoint(HONOR_TEXT, FRAMEPOINT_CENTER, 0.355, 0.5690)
        BlzFrameSetScale(HONOR_TEXT, 1.0)
        BlzFrameSetTextAlignment(HONOR_TEXT, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_RIGHT)
        BlzFrameSetText(HONOR_TEXT, "0")
        BlzFrameSetTextColor(HONOR_TEXT, BlzConvertColor(255, 255, 135, 141)) -- Tulip

        -- Faction (Custom)
        FACTION_TEXT = BlzCreateFrame("CurrencyText", RESOURCE_BAR, 0, 0)
        BlzFrameSetAbsPoint(FACTION_TEXT, FRAMEPOINT_CENTER, 0.455, 0.5690)
        BlzFrameSetScale(FACTION_TEXT, 1.0)
        BlzFrameSetText(FACTION_TEXT, "0")
        BlzFrameSetTextColor(FACTION_TEXT, BlzConvertColor(255, 76, 145, 65)) -- May Green

        HONOR_FRAME = BlzCreateFrameByType("FRAME", "", RESOURCE_BAR, "", 0)
        BlzFrameSetTexture(HONOR_FRAME, "trans32.blp", 0, true)
        BlzFrameSetPoint(HONOR_FRAME, FRAMEPOINT_TOP, RESOURCE_BAR, FRAMEPOINT_TOP, - 0.055, - 0.024)
        BlzFrameSetSize(HONOR_FRAME, 0.062, 0.02)
        BlzFrameSetLevel(HONOR_FRAME, 1)

        FrameAddSimpleTooltip(HONOR_FRAME, "Honor", "Obtained by emerging victorious at the Colosseum.", false)

        FACTION_FRAME = BlzCreateFrameByType("FRAME", "", RESOURCE_BAR, "", 0)
        BlzFrameSetTexture(FACTION_FRAME, "trans32.blp", 0, true)
        BlzFrameSetPoint(FACTION_FRAME, FRAMEPOINT_TOP, RESOURCE_BAR, FRAMEPOINT_TOP, 0.055, - 0.024)
        BlzFrameSetSize(FACTION_FRAME, 0.062, 0.02)
        BlzFrameSetLevel(FACTION_FRAME, 1)

        FrameAddSimpleTooltip(FACTION_FRAME, "Faction Points", "Obtained by completing Faction Quests and may be spent at Faction Shops.", false)

        -- Upkeep // HIDDEN
        FH = BlzGetFrameByName("ResourceBarUpkeepText", 0)
        BlzFrameSetText(BlzGetFrameByName("ResourceBarUpkeepText", 0), " ")
        BlzFrameSetVisible(BlzFrameGetChild(BlzGetFrameByName("ResourceBarFrame", 0), 2), false)

        -- Expand Quest TextArea
        BlzFrameSetPoint(BlzGetFrameByName("QuestDisplay", 0), FRAMEPOINT_TOPLEFT, BlzGetFrameByName("QuestDetailsTitle", 0), FRAMEPOINT_BOTTOMLEFT, 0.003, -0.003)
        BlzFrameSetPoint(BlzGetFrameByName("QuestDisplay", 0), FRAMEPOINT_BOTTOMRIGHT, BlzGetFrameByName("QuestDisplayBackdrop", 0), FRAMEPOINT_BOTTOMRIGHT, -0.003, 0.)

        -- Relocate "close menu" button
        BlzFrameSetPoint(BlzGetFrameByName("QuestDisplayBackdrop", 0), FRAMEPOINT_BOTTOM, BlzGetFrameByName("QuestBackdrop", 0), FRAMEPOINT_BOTTOM, 0., 0.017)
        BlzFrameClearAllPoints(BlzGetFrameByName("QuestAcceptButton", 0))
        BlzFrameSetPoint(BlzGetFrameByName("QuestAcceptButton", 0), FRAMEPOINT_TOPRIGHT, BlzGetFrameByName("QuestBackdrop", 0), FRAMEPOINT_TOPRIGHT, -0.016, -0.016)
        BlzFrameSetText(BlzGetFrameByName("QuestAcceptButton", 0), "×")
        BlzFrameSetSize(BlzGetFrameByName("QuestAcceptButton", 0), 0.03, 0.03)

        -- Remove Deadspace (bottom)
        FH = BlzGetFrameByName("ConsoleUI", 0)
        BlzFrameSetVisible(BlzFrameGetChild(FH, 5), false)

        -- Hide Trade Menu Team Check Things
        BlzFrameSetVisible(BlzGetFrameByName("AlliedVictoryLabel", 0), false)
        BlzFrameSetVisible(BlzGetFrameByName("AlliedVictoryCheckBox", 0), false)

        -- Hide Allied Menu Stuffs
        BlzFrameSetScale(BlzGetFrameByName("AllianceAcceptButton", 0), 0.001)
        BlzFrameSetScale(BlzGetFrameByName("AlliedVictoryCheckBox", 0), 0.001)
        BlzFrameSetScale(BlzGetFrameByName("AlliedVictoryLabel", 0), 0.001)
        BlzFrameSetScale(BlzGetFrameByName("AllianceCancelButton", 0), 0.001)

        -- Damage Alignment
        FH = BlzGetFrameByName("InfoPanelIconBackdrop", 0)
        BlzFrameClearAllPoints(FH)
        BlzFrameSetAbsPoint(FH, FRAMEPOINT_TOPRIGHT, 0.3455, 0.083)

        -- Add Back Ally Resource Icons // Are ally buildings in use?
        BlzFrameSetTexture(BlzGetFrameByName("InfoPanelIconAllyGoldIcon", 7), "UI\\RGReplacement.dds", 0, false)
        BlzFrameSetTexture(BlzGetFrameByName("InfoPanelIconAllyWoodIcon", 7), "UI\\RLReplacement.dds", 0, false)
        BlzFrameSetTexture(BlzGetFrameByName("InfoPanelIconAllyFoodIcon", 7), "UI\\RSReplacement.dds", 0, false)

        -- Relocate Menu Buttons
        F9QuestMenuButton = BlzGetFrameByName("UpperButtonBarQuestsButton", 0)
        F10MenuButton = BlzGetFrameByName("UpperButtonBarMenuButton", 0)
        F11AlliesMenuButton = BlzGetFrameByName("UpperButtonBarAlliesButton", 0)
        F12ChatMenuButton = BlzGetFrameByName("UpperButtonBarChatButton", 0)

        BlzFrameClearAllPoints(F9QuestMenuButton)
        BlzFrameClearAllPoints(F10MenuButton)
        BlzFrameClearAllPoints(F11AlliesMenuButton)
        BlzFrameClearAllPoints(F12ChatMenuButton)

        BlzFrameSetAbsPoint(F9QuestMenuButton, FRAMEPOINT_TOPLEFT, 0.36, 0.554)
        BlzFrameSetPoint(F10MenuButton, FRAMEPOINT_TOP, F9QuestMenuButton, FRAMEPOINT_BOTTOM, 0.0, 0.0)
        -- BlzFrameSetPoint(F11AlliesMenuButton, FRAMEPOINT_TOP, F10MenuButton, FRAMEPOINT_BOTTOM, 0.0, 0.0)
        BlzFrameSetPoint(F12ChatMenuButton, FRAMEPOINT_TOP, F10MenuButton, FRAMEPOINT_BOTTOM, 0.0, 0.0)

        BlzFrameSetVisible(F9QuestMenuButton, false)
        BlzFrameSetVisible(F10MenuButton, false)
        BlzFrameSetVisible(F11AlliesMenuButton, false)
        BlzFrameSetVisible(F12ChatMenuButton, false)

        ShowHideMenuButton = BlzCreateFrame("ScriptDialogButton", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        BlzFrameSetPoint(ShowHideMenuButton, FRAMEPOINT_TOPLEFT, RESOURCE_BAR, FRAMEPOINT_TOPRIGHT, 0.05, -0.0125)
        BlzFrameSetText(ShowHideMenuButton, "|cffffffffMenus|r")
        BlzFrameSetSize(ShowHideMenuButton, 0.09, 0.035)
        BlzFrameSetScale(ShowHideMenuButton, 0.6)
        BlzFrameSetFont(ShowHideMenuButton, "MasterFont", 0.028, 0)

        local t = CreateTrigger()
        BlzTriggerRegisterFrameEvent(t, ShowHideMenuButton, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(t, function()
            if GetTriggerPlayer() == GetLocalPlayer() then
                if BlzFrameIsVisible(F10MenuButton) == true then
                    BlzFrameSetVisible(F9QuestMenuButton, false)
                    BlzFrameSetVisible(F10MenuButton, false)
                    -- BlzFrameSetVisible(F11AlliesMenuButton, false)
                    BlzFrameSetVisible(F12ChatMenuButton, false)
                elseif BlzFrameIsVisible(F10MenuButton) == false then
                    BlzFrameSetVisible(F9QuestMenuButton, true)
                    BlzFrameSetVisible(F10MenuButton, true)
                    -- BlzFrameSetVisible(F11AlliesMenuButton, true)
                    BlzFrameSetVisible(F12ChatMenuButton, true)
                end
                BlzFrameSetEnable(ShowHideMenuButton, false)
                BlzFrameSetEnable(ShowHideMenuButton, true)
                StopCamera()
            end
        end)

        t = CreateTrigger()
        for i = 0, PLAYER_CAP do
            BlzTriggerRegisterPlayerKeyEvent(t, Player(i), OSKEY_ESCAPE, 0, true)
        end
        TriggerAddAction(t, function()
            if GetTriggerPlayer() == GetLocalPlayer() then
                if BlzFrameIsVisible(F10MenuButton) == true then
                    BlzFrameSetVisible(F9QuestMenuButton, false)
                    BlzFrameSetVisible(F10MenuButton, false)
                    BlzFrameSetVisible(F11AlliesMenuButton, false)
                    BlzFrameSetVisible(F12ChatMenuButton, false)
                end
            end
        end)
    end

    --cover health text
    HIDE_HEALTH_FRAME = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
    BlzFrameSetAbsPoint(HIDE_HEALTH_FRAME, FRAMEPOINT_TOPLEFT, 0.225, 0.028)
    BlzFrameSetAbsPoint(HIDE_HEALTH_FRAME, FRAMEPOINT_BOTTOMRIGHT, 0.28, 0.0185)
    BlzFrameSetTexture(HIDE_HEALTH_FRAME, "black.dds", 0, true)
    BlzFrameSetVisible(HIDE_HEALTH_FRAME, false)

    --shield ui
    SHIELD_BACKDROP = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
    BlzFrameSetAbsPoint(SHIELD_BACKDROP, FRAMEPOINT_TOPLEFT, 0.215570, 0.0428)
    BlzFrameSetAbsPoint(SHIELD_BACKDROP, FRAMEPOINT_BOTTOMRIGHT, 0.290450, 0.0313600)
    BlzFrameSetTexture(SHIELD_BACKDROP, "black.dds", 0, true)

    SHIELD_TEXT = BlzCreateFrameByType("TEXT", "", SHIELD_BACKDROP, "", 0)
    BlzFrameSetText(SHIELD_TEXT, "")
    BlzFrameSetAllPoints(SHIELD_TEXT, SHIELD_BACKDROP)
    BlzFrameSetTextAlignment(SHIELD_TEXT, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
    BlzFrameSetVisible(SHIELD_BACKDROP, false)

    DPS_FRAME = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "ButtonBackdropTemplate", 0)
    BlzFrameSetPoint(DPS_FRAME, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_TOP, 0.30, -0.37)
    BlzFrameSetTexture(DPS_FRAME, "war3mapImported\\afkUI_3.dds", 0, true)
    BlzFrameSetSize(DPS_FRAME, 0.25, 0.14)
    BlzFrameSetVisible(DPS_FRAME, false)

    DPS_FRAME_TITLE = BlzCreateFrameByType("TEXT", "", DPS_FRAME, "CText_18", 0)
    BlzFrameSetTextAlignment(DPS_FRAME_TITLE, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
    BlzFrameSetPoint(DPS_FRAME_TITLE, FRAMEPOINT_CENTER, DPS_FRAME, FRAMEPOINT_CENTER, -0.04, 0)
    BlzFrameSetText(DPS_FRAME_TITLE, "Last Hit:\nTotal |cffE15F08Physical|r:\nTotal |cff8000ffMagic|r:\nTotal:\nDPS:\nPeak DPS:\nTime:")

    DPS_FRAME_TEXTVALUE = BlzCreateFrameByType("TEXT", "", DPS_FRAME, "CText_18", 0)
    BlzFrameSetTextAlignment(DPS_FRAME_TEXTVALUE, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_RIGHT)
    BlzFrameSetPoint(DPS_FRAME_TEXTVALUE, FRAMEPOINT_CENTER, DPS_FRAME, FRAMEPOINT_CENTER, 0.04, 0)
    BlzFrameSetText(DPS_FRAME_TEXTVALUE, "0\n0\n0\n0\n0\n0\n0s")

    local xp_bar = BlzGetFrameByName("SimpleHeroLevelBar", 0)
    local xp_tooltip = BlzFrameGetChild(xp_bar, 1)
    BlzFrameClearAllPoints(xp_tooltip)
    BlzFrameSetPoint(xp_tooltip, FRAMEPOINT_BOTTOM, xp_bar, FRAMEPOINT_TOP, 0, 0)

    --voting UI
    VOTING_BACKDROP = BlzCreateFrameByType("BACKDROP", "VOTING_BACKDROP", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "ButtonBackdropTemplate", 0)
    BlzFrameSetPoint(VOTING_BACKDROP, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_TOP, 0, - 0.11)
    BlzFrameSetSize(VOTING_BACKDROP, 0.12, 0.12)
    BlzFrameSetVisible(VOTING_BACKDROP, false)

    VOTING_BUTTON_FRAME = BlzCreateFrameByType("GLUEBUTTON", "FaceButton", VOTING_BACKDROP, "ScoreScreenTabButtonTemplate", 0)
    votingButtonIconYes = BlzCreateFrameByType("BACKDROP", "FaceButtonIcon", VOTING_BUTTON_FRAME, "", 0)
    BlzFrameSetAllPoints(votingButtonIconYes, VOTING_BUTTON_FRAME)
    BlzFrameSetTexture(votingButtonIconYes, "war3mapImported\\Checkframe.dds", 0, true)
    BlzFrameSetPoint(VOTING_BUTTON_FRAME, FRAMEPOINT_CENTER, VOTING_BACKDROP, FRAMEPOINT_CENTER, - 0.015, 0.015)
    BlzFrameSetSize(VOTING_BUTTON_FRAME, 0.03, 0.03)

    VOTING_BUTTON_FRAME2 = BlzCreateFrameByType("GLUEBUTTON", "FaceButton", VOTING_BACKDROP, "ScoreScreenTabButtonTemplate", 0)
    votingButtonIconNo = BlzCreateFrameByType("BACKDROP", "FaceButtonIcon", VOTING_BUTTON_FRAME2, "", 0)
    BlzFrameSetAllPoints(votingButtonIconNo, VOTING_BUTTON_FRAME2)
    BlzFrameSetTexture(votingButtonIconNo, "war3mapImported\\Xframe.dds", 0, true)
    BlzFrameSetPoint(VOTING_BUTTON_FRAME2, FRAMEPOINT_CENTER, VOTING_BACKDROP, FRAMEPOINT_CENTER, 0.015, - 0.015)
    BlzFrameSetSize(VOTING_BUTTON_FRAME2, 0.03, 0.03)

    --punching bag UI
    do
        PUNCHING_BAG_VALUES = {}

        PUNCHING_BAG_UI = BlzCreateFrame("ListBoxWar3", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        BlzFrameSetPoint(PUNCHING_BAG_UI, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_CENTER, -0.02, -0.14)
        BlzFrameSetSize(PUNCHING_BAG_UI, 0.15, 0.045)

        PUNCHING_BAG_BUTTON_1 = BlzCreateFrameByType("GLUEBUTTON", "", PUNCHING_BAG_UI, "ScoreScreenTabButtonTemplate", 0)
        BlzFrameSetPoint(PUNCHING_BAG_BUTTON_1, FRAMEPOINT_BOTTOMLEFT, PUNCHING_BAG_UI, FRAMEPOINT_BOTTOMLEFT, 0.0125, 0.012)
        BlzFrameSetSize(PUNCHING_BAG_BUTTON_1, 0.022, 0.022)
        PUNCHING_BAG_BUTTON_1_BG = BlzCreateFrameByType("BACKDROP", "", PUNCHING_BAG_BUTTON_1, "", 0)
        BlzFrameSetAllPoints(PUNCHING_BAG_BUTTON_1_BG, PUNCHING_BAG_BUTTON_1)
        BlzFrameSetTexture(PUNCHING_BAG_BUTTON_1_BG, "war3mapImported\\prechaosarmor.blp", 0, true)

        PUNCHING_BAG_BUTTON_2 = BlzCreateFrameByType("GLUEBUTTON", "", PUNCHING_BAG_UI, "ScoreScreenTabButtonTemplate", 0)
        BlzFrameSetPoint(PUNCHING_BAG_BUTTON_2, FRAMEPOINT_TOPLEFT, PUNCHING_BAG_BUTTON_1, FRAMEPOINT_TOPRIGHT, 0.005, 0)
        BlzFrameSetSize(PUNCHING_BAG_BUTTON_2, 0.022, 0.022)
        PUNCHING_BAG_BUTTON_2_BG = BlzCreateFrameByType("BACKDROP", "", PUNCHING_BAG_BUTTON_2, "", 0)
        BlzFrameSetAllPoints(PUNCHING_BAG_BUTTON_2_BG, PUNCHING_BAG_BUTTON_2)
        BlzFrameSetTexture(PUNCHING_BAG_BUTTON_2_BG, "war3mapImported\\chaosarmor.blp", 0, true)

        PUNCHING_BAG_EDIT = BlzCreateFrame("EscMenuEditBoxTemplate", PUNCHING_BAG_UI, 0, 0)
        BlzFrameSetPoint(PUNCHING_BAG_EDIT, FRAMEPOINT_BOTTOMLEFT, PUNCHING_BAG_BUTTON_2, FRAMEPOINT_BOTTOMRIGHT, 0.003, -0.0015)
        BlzFrameSetSize(PUNCHING_BAG_EDIT, 0.075, 0.025)
        BlzFrameSetTextSizeLimit(PUNCHING_BAG_EDIT, 6)

        BlzFrameSetVisible(PUNCHING_BAG_UI, false)

        local function TEXT_CHANGED()
            local number = MathClamp((tonumber(BlzGetTriggerFrameText()) or 0), -500, 100000)
            PUNCHING_BAG_VALUES[GetPlayerId(GetTriggerPlayer()) + 1] = number
            BlzSetUnitArmor(PUNCHING_BAG, PUNCHING_BAG_VALUES[GetPlayerId(GetTriggerPlayer()) + 1])
        end

        local editText = CreateTrigger()
        TriggerAddAction(editText, TEXT_CHANGED)
        BlzTriggerRegisterFrameEvent(editText, PUNCHING_BAG_EDIT, FRAMEEVENT_EDITBOX_TEXT_CHANGED)

        local function BUTTON_CLICK()
            local frame = BlzGetTriggerFrame()
            BlzSetUnitIntegerField(PUNCHING_BAG, UNIT_IF_DEFENSE_TYPE, (frame == PUNCHING_BAG_BUTTON_2 and 6) or 0)
            if GetLocalPlayer() == GetTriggerPlayer() then
                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)
            end
        end

        local buttonClick = CreateTrigger()
        TriggerAddAction(buttonClick, BUTTON_CLICK)
        BlzTriggerRegisterFrameEvent(buttonClick, PUNCHING_BAG_BUTTON_1, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(buttonClick, PUNCHING_BAG_BUTTON_2, FRAMEEVENT_CONTROL_CLICK)
    end
end, Debug and Debug.getLine())
