--[[
    character_browser.lua

    Presents saved characters as a paged card grid. Profile owns all save data
    and supplies immutable display records plus synchronized command callbacks.
]]

OnInit.final("CharacterBrowser", function(Require)
    Require('FrameHelpers')
    Require('Frames')
    Require('SimpleButton')

    local CARDS_PER_PAGE = 15
    local COLUMN_COUNT = 5
    local sessions = {}
    local cards = {}

    CharacterBrowser = {}

    local main = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
    BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.53)
    BlzFrameSetSize(main, 0.7, 0.35)
    BlzFrameSetTexture(main, "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp", 0, true)
    BlzFrameSetVertexColor(main, BlzConvertColor(245, 30, 35, 45))
    BlzFrameSetLevel(main, 50)
    BlzFrameSetEnable(main, false)
    BlzFrameSetVisible(main, false)

    local title = BlzCreateFrame("TitleText", main, 0, 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.018)
    BlzFrameSetText(title, "Saved Heroes")
    BlzFrameSetEnable(title, false)

    local page_text = BlzCreateFrameByType("TEXT", "", main, "", 0)
    BlzFrameSetPoint(page_text, FRAMEPOINT_BOTTOM, main, FRAMEPOINT_BOTTOM, 0., 0.018)
    BlzFrameSetEnable(page_text, false)

    local function reset_clicked_frame()
        local clicked = BlzGetTriggerFrame()
        local player = GetTriggerPlayer()
        if GetLocalPlayer() == player then
            BlzFrameSetEnable(clicked, false)
            BlzFrameSetEnable(clicked, true)
        end
    end

    local function page_count(session)
        return math.max(1, math.ceil((session.max_slots or 1) / CARDS_PER_PAGE))
    end

    local function refresh(pid)
        local session = sessions[pid]
        if not session then
            return
        end

        local player = Player(pid - 1)
        local first_slot = session.page * CARDS_PER_PAGE + 1
        local deleting = session.deleting == true

        if GetLocalPlayer() ~= player then
            return
        end

        BlzFrameSetText(page_text, "Page " .. (session.page + 1) .. " / " .. page_count(session))
        session.delete_button:text(deleting and "|cffff5555Delete Mode: ON|r" or "Delete Character")

        for index = 1, CARDS_PER_PAGE do
            local card = cards[index]
            local slot = first_slot + index - 1
            local data = session.slots[slot]

            BlzFrameSetVisible(card.container, data ~= nil)
            if data then
                card.button:icon(data.icon)
                card.button:setTooltipIcon(data.icon)
                card.button:setTooltipName(data.name)
                card.button:setTooltipText(data.tooltip)
                BlzFrameSetText(card.name, (deleting and "|cffff5555" or "|cffffcc00") .. data.name .. "|r")
                BlzFrameSetText(card.summary, "Level " .. data.level .. " " .. data.mode .. "\n|cffaaaaaaSlot " .. slot .. "|r")
                BlzFrameSetText(card.preview_title,
                    "|cffffcc00Saved Inventory (" .. (data.item_count or 0) .. " / "
                    .. #card.preview_icons .. ")|r")
                for item_slot = 1, #card.preview_icons do
                    BlzFrameSetTexture(card.preview_icons[item_slot],
                        data.item_icons[item_slot] or "trans32.blp", 0, true)
                end
            end
        end
    end

    local function on_card_click(index)
        return function()
            local player = GetTriggerPlayer()
            local pid = GetPlayerId(player) + 1
            local session = sessions[pid]
            reset_clicked_frame()

            if session then
                local slot = session.page * CARDS_PER_PAGE + index
                if session.slots[slot] and session.on_select then
                    session.on_select(pid, slot, session.deleting == true)
                end
            end
            return false
        end
    end

    for index = 1, CARDS_PER_PAGE do
        local column = (index - 1) % COLUMN_COUNT
        local row = (index - 1) // COLUMN_COUNT
        local x = 0.025 + column * 0.132
        local y = -0.052 - row * 0.082
        local card = {}

        card.container = BlzCreateFrameByType("BACKDROP", "", main, "", 0)
        BlzFrameSetPoint(card.container, FRAMEPOINT_TOPLEFT, main, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetSize(card.container, 0.122, 0.071)
        BlzFrameSetTexture(card.container, "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp", 0, true)
        BlzFrameSetVertexColor(card.container, BlzConvertColor(225, 12, 15, 22))
        BlzFrameSetEnable(card.container, false)

        card.button = SimpleButton.create(card.container, "trans32.blp", 0.043, 0.043,
            FRAMEPOINT_LEFT, FRAMEPOINT_LEFT, 0.008, 0., on_card_click(index))
        card.button:makeTooltip(column >= 3 and FRAMEPOINT_TOPRIGHT or FRAMEPOINT_TOPLEFT, 0.22)

        card.preview_title = BlzCreateFrameByType("TEXT", "", card.button.tooltip_frame, "", 0)
        BlzFrameSetPoint(card.preview_title, FRAMEPOINT_TOPLEFT,
            card.button.tooltip, FRAMEPOINT_BOTTOMLEFT, 0., -0.008)
        BlzFrameSetSize(card.preview_title, 0.22, 0.014)
        BlzFrameSetScale(card.preview_title, 0.67)
        BlzFrameSetTextAlignment(card.preview_title, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(card.preview_title, false)

        card.preview = BlzCreateFrameByType("FRAME", "", card.button.tooltip_frame, "", 0)
        BlzFrameSetPoint(card.preview, FRAMEPOINT_TOPLEFT,
            card.preview_title, FRAMEPOINT_BOTTOMLEFT, 0., -0.002)
        BlzFrameSetSize(card.preview, 0.22, 0.032)
        BlzFrameSetEnable(card.preview, false)

        card.preview_icons = {}
        for item_slot = 1, 26 do
            local item_column = (item_slot - 1) % 13
            local item_row = (item_slot - 1) // 13
            local icon = BlzCreateFrameByType("BACKDROP", "", card.preview, "", 0)
            BlzFrameSetPoint(icon, FRAMEPOINT_TOPLEFT, card.preview, FRAMEPOINT_TOPLEFT,
                item_column * 0.0165, -item_row * 0.0165)
            BlzFrameSetSize(icon, 0.0145, 0.0145)
            BlzFrameSetTexture(icon, "trans32.blp", 0, true)
            BlzFrameSetEnable(icon, false)
            card.preview_icons[item_slot] = icon
        end

        -- Extend the standard tooltip box around the appended inventory grid.
        BlzFrameClearAllPoints(card.button.box)
        BlzFrameSetPoint(card.button.box, FRAMEPOINT_TOPLEFT,
            card.button.iconFrame, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
        BlzFrameSetPoint(card.button.box, FRAMEPOINT_BOTTOMRIGHT,
            card.preview, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)

        card.name = BlzCreateFrameByType("TEXT", "", card.container, "", 0)
        BlzFrameSetPoint(card.name, FRAMEPOINT_TOPLEFT, card.button.frame, FRAMEPOINT_TOPRIGHT, 0.004, -0.002)
        BlzFrameSetSize(card.name, 0.061, 0.018)
        BlzFrameSetScale(card.name, 0.72)
        BlzFrameSetTextAlignment(card.name, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(card.name, false)

        card.summary = BlzCreateFrameByType("TEXT", "", card.container, "", 0)
        BlzFrameSetPoint(card.summary, FRAMEPOINT_TOPLEFT, card.name, FRAMEPOINT_BOTTOMLEFT, 0., -0.002)
        BlzFrameSetSize(card.summary, 0.061, 0.034)
        BlzFrameSetScale(card.summary, 0.68)
        BlzFrameSetTextAlignment(card.summary, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(card.summary, false)
        BlzFrameSetVisible(card.container, false)
        cards[index] = card
    end

    local function close(pid)
        sessions[pid] = nil
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(main, false)
        end
    end

    local function on_previous()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local session = sessions[pid]
        reset_clicked_frame()
        if session and session.page > 0 then
            session.page = session.page - 1
            refresh(pid)
        end
        return false
    end

    local function on_next()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local session = sessions[pid]
        reset_clicked_frame()
        if session and session.page + 1 < page_count(session) then
            session.page = session.page + 1
            refresh(pid)
        end
        return false
    end

    SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCycleLeft.blp",
        0.021, 0.021, FRAMEPOINT_BOTTOM, FRAMEPOINT_BOTTOM, -0.055, 0.014,
        on_previous, "Previous Page", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCycleRight.blp",
        0.021, 0.021, FRAMEPOINT_BOTTOM, FRAMEPOINT_BOTTOM, 0.055, 0.014,
        on_next, "Next Page", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

    local function on_new()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local session = sessions[pid]
        reset_clicked_frame()
        if session and session.on_new then
            session.on_new(pid)
        end
        return false
    end

    local new_button = SimpleButton.create(main, "trans32.blp", 0.105, 0.027,
        FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMLEFT, 0.025, 0.012, on_new)
    new_button:text("New Character")
    BlzFrameSetScale(new_button.text_frame, 1.05)

    local function on_delete_mode()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local session = sessions[pid]
        reset_clicked_frame()
        if session then
            session.deleting = not session.deleting
            refresh(pid)
        end
        return false
    end

    local delete_button = SimpleButton.create(main, "trans32.blp", 0.115, 0.027,
        FRAMEPOINT_BOTTOMRIGHT, FRAMEPOINT_BOTTOMRIGHT, -0.025, 0.012, on_delete_mode)
    BlzFrameSetScale(delete_button.text_frame, 1.05)

    ---@param pid integer
    ---@param config table
    function CharacterBrowser.show(pid, config)
        config.page = config.page or 0
        config.deleting = false
        config.delete_button = delete_button
        sessions[pid] = config
        refresh(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(main, true)
        end
    end

    ---@param pid integer
    function CharacterBrowser.refresh(pid)
        refresh(pid)
    end

    ---@param pid integer
    function CharacterBrowser.hide(pid)
        close(pid)
    end
end, Debug and Debug.getLine())
