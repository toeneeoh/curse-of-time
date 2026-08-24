OnInit.final("DialogWindow", function(Require)

    Require("SimpleButton")
    Require("Hotkeys")

    ---@class DialogWindowChoice
    ---@field name string
    ---@field data any
    ---@field icon string?

    ---@class DialogWindow
    ---@field pid integer
    ---@field title string
    ---@field kind any
    ---@field callback function
    ---@field data any[]
    ---@field Button framehandle[]
    ---@field ButtonName string[]
    ---@field MenuButton framehandle[]
    ---@field MenuButtonName string[]
    ---@field count integer
    ---@field menu_count integer
    ---@field Page integer
    ---@field options_per_page integer
    ---@field cancellable boolean
    ---@field display function
    ---@field addButton function
    ---@field addMenuButton function
    ---@field getClickedIndex function
    ---@field getClickedData function
    ---@field getCurrent function
    ---@field destroy function
    DialogWindow = {}
    do
        local thistype = DialogWindow
        local mt = { __index = thistype }

        thistype.OPTIONS_PER_PAGE = 7
        thistype.OPTIONS_PER_PAGE_MAX = 10
        thistype.BUTTON_MAX = 100
        thistype.MENU_BUTTON_MAX = 5

        local queues = {} ---@type DialogWindow[][]
        local current = {} ---@type DialogWindow[]
        local rows = {} ---@type table[]
        local menu_rows = {} ---@type table[]
        local row_by_frame = {} ---@type table<framehandle, table>
        local row_trigger = CreateTrigger()

        local MAIN_WIDTH = 0.30
        local HEADER_HEIGHT = 0.042
        local ROW_HEIGHT = 0.035
        local ROW_GAP = 0.002
        local FOOTER_HEIGHT = 0.042
        local SIDE_PADDING = 0.018
        local ICON_SIZE = 0.024
        local BUTTON_FONT_SIZE = 0.014

        local main = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.542)
        BlzFrameSetSize(main, MAIN_WIDTH, 0.20)
        BlzFrameSetEnable(main, false)
        BlzFrameSetLevel(main, 20)

        local title = BlzCreateFrame("TitleText", main, 0, 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.0, -0.015)
        BlzFrameSetSize(title, MAIN_WIDTH - 0.04, 0)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetEnable(title, false)
        BlzFrameSetScale(title, 0.8)

        local close_button
        local previous_button
        local next_button
        local page_text = BlzCreateFrameByType("TEXT", "", main, "", 0)
        BlzFrameSetSize(page_text, 0.08, 0.02)
        BlzFrameSetTextAlignment(page_text, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetEnable(page_text, false)

        BlzFrameSetVisible(main, false)

        local function resetFrame(frame)
            if GetTriggerPlayer() == GetLocalPlayer() then
                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)
            end
        end

        local function getPid()
            return GetPlayerId(GetTriggerPlayer()) + 1
        end

        ---@param self DialogWindow
        local function hasDuplicate(self)
            local active = current[self.pid]
            if active and active ~= self and active.kind == self.kind then
                return true
            end

            local q = queues[self.pid]
            if q then
                for i = 1, #q do
                    if q[i] ~= self and q[i].kind == self.kind then
                        return true
                    end
                end
            end

            return false
        end

        local function onRowClick()
            local frame = BlzGetTriggerFrame()
            local row = row_by_frame[frame]
            local pid = getPid()
            local self = current[pid]
            resetFrame(frame)

            if not row or not self then
                return
            end

            if row.is_menu then
                local choice = self.menu[row.index]
                if choice then
                    self.clicked_index = row.index
                    self.clicked_data = choice.data
                    self.clicked_menu = true
                    (choice.callback or self.callback)(self, row.index, choice.data, true)
                end
            else
                local absolute_index = self.Page * self.options_per_page + row.index
                local choice = self.choices[absolute_index]
                if choice then
                    self.clicked_index = absolute_index
                    self.clicked_data = choice.data
                    self.clicked_menu = false
                    self.callback(self, absolute_index, choice.data, false)
                end
            end
        end

        TriggerAddAction(row_trigger, onRowClick)

        local function createRow(index, is_menu)
            local collection = is_menu and menu_rows or rows
            local button = BlzCreateFrame("DialogWindowChoiceButton", main, 0, 0)
            local icon = BlzCreateFrameByType("BACKDROP", "", button, "", 0)

            BlzFrameSetSize(button, MAIN_WIDTH - SIDE_PADDING * 2.0, ROW_HEIGHT)
            BlzFrameSetFont(button, "MasterFont", BUTTON_FONT_SIZE, 0)
            BlzFrameSetSize(icon, ICON_SIZE, ICON_SIZE)
            BlzFrameSetPoint(icon, FRAMEPOINT_LEFT, button, FRAMEPOINT_LEFT, 0.006, -0.001)
            BlzFrameSetEnable(icon, false)
            BlzFrameSetVisible(button, false)

            local row = {
                frame = button,
                icon = icon,
                index = index,
                is_menu = is_menu,
            }
            collection[index] = row
            row_by_frame[button] = row
            BlzTriggerRegisterFrameEvent(row_trigger, button, FRAMEEVENT_CONTROL_CLICK)

            return row
        end

        -- Allocate the complete frame pool once. Showing another DialogWindow
        -- only changes these frames' text, textures, points, and visibility.
        for i = 0, thistype.OPTIONS_PER_PAGE_MAX - 1 do
            createRow(i, false)
        end
        for i = 0, thistype.MENU_BUTTON_MAX - 1 do
            createRow(i, true)
        end

        local function setRow(row, choice, y, local_player)
            if local_player then
                BlzFrameClearAllPoints(row.frame)
                BlzFrameSetPoint(row.frame, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.0, y)
                BlzFrameSetText(row.frame, choice.name)

                if choice.icon then
                    BlzFrameSetTexture(row.icon, choice.icon, 0, true)
                    BlzFrameSetVisible(row.icon, true)
                else
                    BlzFrameSetVisible(row.icon, false)
                end

                BlzFrameSetVisible(row.frame, true)
            end
        end

        local function hideUnused(collection, first, local_player)
            if local_player then
                for i = first, #collection do
                    if collection[i] then
                        BlzFrameSetVisible(collection[i].frame, false)
                    end
                end
            end
        end

        local function totalPages(self)
            return math.max(1, math.ceil(self.count / self.options_per_page))
        end

        local function refresh(pid)
            local self = current[pid]
            if not self then
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(main, false)
                end
                return
            end

            local pages = totalPages(self)
            if self.Page >= pages then
                self.Page = pages - 1
            elseif self.Page < 0 then
                self.Page = 0
            end

            local first = self.Page * self.options_per_page
            local shown = math.min(self.options_per_page, self.count - first)
            local has_pages = pages > 1
            local local_player = GetLocalPlayer() == Player(pid - 1)
            local y = -HEADER_HEIGHT

            for slot = 0, shown - 1 do
                local index = first + slot
                setRow(rows[slot], self.choices[index], y, local_player)
                self.Button[index] = rows[slot].frame
                y = y - ROW_HEIGHT - ROW_GAP
            end
            hideUnused(rows, shown, local_player)

            if has_pages then
                y = -HEADER_HEIGHT - self.options_per_page * (ROW_HEIGHT + ROW_GAP)
            end

            for index = 0, self.menu_count - 1 do
                setRow(menu_rows[index], self.menu[index], y, local_player)
                self.MenuButton[index] = menu_rows[index].frame
                y = y - ROW_HEIGHT - ROW_GAP
            end
            hideUnused(menu_rows, self.menu_count, local_player)

            -- Paginated windows reserve a full page so the cabinet does not
            -- resize when the last page contains fewer choices.
            local choice_slots = has_pages and self.options_per_page or shown
            local height = HEADER_HEIGHT + (choice_slots + self.menu_count) * (ROW_HEIGHT + ROW_GAP)
            if has_pages then
                height = height + FOOTER_HEIGHT
            else
                height = height + 0.012
            end

            if local_player then
                BlzFrameSetSize(main, MAIN_WIDTH, height)
                BlzFrameSetText(title, "|cffffffff" .. self.title .. "|r")
                close_button:visible(self.cancellable)

                previous_button:visible(has_pages)
                next_button:visible(has_pages)
                BlzFrameSetVisible(page_text, has_pages)

                if has_pages then
                    previous_button:enable(self.Page > 0)
                    next_button:enable(self.Page < pages - 1)
                    BlzFrameSetText(page_text, (self.Page + 1) .. " / " .. pages)

                    BlzFrameClearAllPoints(page_text)
                    BlzFrameSetPoint(page_text, FRAMEPOINT_BOTTOM, main, FRAMEPOINT_BOTTOM, 0.0, 0.018)
                end

                BlzFrameSetVisible(main, true)
            end
        end

        local function promote(pid)
            local q = queues[pid]
            local self = q and table.remove(q, 1) or nil
            current[pid] = self
            thistype[pid] = self

            if self then
                self.queued = false
                self.active = true
            end

            refresh(pid)
        end

        local function cancelCurrent(pid)
            local self = current[pid]
            if self and self.cancellable then
                if self.on_cancel then
                    self.on_cancel(self, pid)
                end
                self:destroy()
            end
        end

        local function onClose()
            local frame = BlzGetTriggerFrame()
            resetFrame(frame)
            cancelCurrent(getPid())
            return false
        end

        local function onPrevious()
            local pid = getPid()
            local self = current[pid]
            resetFrame(BlzGetTriggerFrame())
            if self and self.Page > 0 then
                self.Page = self.Page - 1
                refresh(pid)
            end
            return false
        end

        local function onNext()
            local pid = getPid()
            local self = current[pid]
            resetFrame(BlzGetTriggerFrame())
            if self and self.Page < totalPages(self) - 1 then
                self.Page = self.Page + 1
                refresh(pid)
            end
            return false
        end

        close_button = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.018, -0.018, onClose, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0.0, 0.01)
        previous_button = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedDown.blp", 0.022, 0.022, FRAMEPOINT_BOTTOMRIGHT, FRAMEPOINT_BOTTOMRIGHT, -0.17, 0.015, onPrevious, "Previous Page", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0.0, 0.01)
        next_button = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedUp.blp", 0.022, 0.022, FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMLEFT, 0.17, 0.015, onNext, "Next Page", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0.0, 0.01)

        AddToEsc(cancelCurrent)

        --- Returns the dialog currently shown to pid
        ---@param pid integer
        ---@return DialogWindow?
        function thistype.getCurrent(pid)
            return current[pid]
        end

        ---@return integer
        function thistype:getClickedIndex()
            return self.clicked_index or -1
        end

        ---@return any
        function thistype:getClickedData()
            return self.clicked_data
        end

        ---@return boolean
        function thistype:clickedMenuButton()
            return self.clicked_menu == true
        end

        ---@param count integer
        ---@return DialogWindow
        function thistype:setOptionsPerPage(count)
            self.options_per_page = math.max(1, math.min(thistype.OPTIONS_PER_PAGE_MAX, count))
            if self.active then
                self.Page = 0
                refresh(self.pid)
            end
            return self
        end

        ---@param callback function?
        ---@return DialogWindow
        function thistype:setCancelCallback(callback)
            self.on_cancel = callback
            return self
        end

        ---@param name string
        ---@param data any?
        ---@param icon string?
        ---@return boolean
        function thistype:addButton(name, data, icon)
            if self.count >= thistype.BUTTON_MAX or self.active or self.queued or self.destroyed then
                return false
            end

            self.choices[self.count] = { name = name, data = data, icon = icon }
            self.ButtonName[self.count] = name
            self.data[self.count] = data
            self.count = self.count + 1
            return true
        end

        ---@param name string
        ---@param callback function?
        ---@param data any?
        ---@param icon string?
        ---@return boolean
        function thistype:addMenuButton(name, callback, data, icon)
            if self.menu_count >= thistype.MENU_BUTTON_MAX or self.active or self.queued or self.destroyed then
                return false
            end

            self.menu[self.menu_count] = {
                name = name,
                callback = callback,
                data = data,
                icon = icon,
            }
            self.MenuButtonName[self.menu_count] = name
            self.menu_count = self.menu_count + 1
            return true
        end

        ---Queues the completed window, or shows it immediately if the player has no active window.
        ---@return boolean
        function thistype:display()
            if self.destroyed or self.active or self.queued or hasDuplicate(self) then
                return false
            end

            -- A dialog with no choices has no useful interaction and otherwise
            -- renders as an empty cabinet with only a close button.
            if self.count == 0 and self.menu_count == 0 then
                self:destroy()
                return false
            end

            queues[self.pid] = queues[self.pid] or {}
            self.queued = true
            queues[self.pid][#queues[self.pid] + 1] = self

            if not current[self.pid] then
                promote(self.pid)
            end

            return true
        end

        function thistype:destroy()
            if self.destroyed then
                return
            end

            self.destroyed = true

            if self.active and current[self.pid] == self then
                self.active = false
                current[self.pid] = nil
                thistype[self.pid] = nil
                promote(self.pid)
                return
            end

            if self.queued then
                local q = queues[self.pid]
                for i = 1, #q do
                    if q[i] == self then
                        table.remove(q, i)
                        break
                    end
                end
                self.queued = false
            end
        end

        ---@type fun(pid: integer, title: string, callback: function, kind: any?): DialogWindow
        function thistype.create(pid, title_text, callback, kind)
            local self = setmetatable({}, mt) ---@type DialogWindow

            self.pid = pid
            self.title = title_text
            self.callback = callback
            self.kind = kind == nil and callback or kind
            self.data = {}
            self.Button = {}
            self.ButtonName = {}
            self.MenuButton = {}
            self.MenuButtonName = {}
            self.choices = {}
            self.menu = {}
            self.count = 0
            self.menu_count = 0
            self.Page = 0
            self.options_per_page = thistype.OPTIONS_PER_PAGE
            self.cancellable = true
            self.clicked_index = -1
            self.clicked_menu = false
            self.active = false
            self.queued = false
            self.destroyed = false

            return self
        end
    end
end, Debug and Debug.getLine())
