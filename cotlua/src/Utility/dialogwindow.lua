OnInit.global("DialogWindow", function()

    ---@class DialogWindow
    ---@field getClickedIndex function
    ---@field pid integer
    ---@field data any[]
    ---@field Button button[]
    ---@field ButtonName string[]
    ---@field MenuButton button[]
    ---@field MenuButtonName string[]
    ---@field count integer
    ---@field menu_count integer
    ---@field Page integer
    ---@field display function
    ---@field addButton function
    ---@field addMenuButton function
    ---@field create function
    ---@field destroy function
    ---@field BUTTON_MAX integer
    DialogWindow = {}
    do
        local thistype = DialogWindow
        local mt = { __index = thistype }

        thistype.OPTIONS_PER_PAGE = 7 ---@type integer 
        thistype.BUTTON_MAX       = 100 ---@type integer 
        thistype.MENU_BUTTON_MAX  = 5 ---@type integer 
        thistype.DATA_MAX         = 100 ---@type integer 

        thistype.dialog          = nil ---@type dialog 
        thistype.pid             = 0 ---@type integer 
        thistype.title           = "" ---@type string 
        thistype.count     = 0  ---@type integer 
        thistype.menu_count = 2  ---@type integer 
        thistype.Page            = -1 ---@type integer 
        thistype.trig            = nil

        thistype.cancellable     = true ---@type boolean 

        ---@return boolean
        function thistype.dialogHandler()
            local self = thistype[GetPlayerId(GetTriggerPlayer()) + 1]

            --cancel
            if self then
                if GetClickedButton() == self.MenuButton[0] then
                    self:destroy()
                --next page
                elseif GetClickedButton() == self.MenuButton[1] then
                    self:display()
                end
            end

            return false
        end

        ---@param b button
        ---@return integer
        function thistype:getClickedIndex(b)
            for index = 0, self.count do
                if b == self.Button[index] then
                    return index
                end
            end

            return -1
        end

        function thistype:display()
            local index = self.Page * self.OPTIONS_PER_PAGE + self.OPTIONS_PER_PAGE ---@type integer 
            local shown = 0 ---@type integer 

            DialogClear(self.dialog)

            --buttons
            if index >= self.count then
                index = 0
                self.Page = -1
            end

            while not (shown >= self.OPTIONS_PER_PAGE or index >= self.count) do

                self.Button[index] = DialogAddButton(self.dialog, self.ButtonName[index], 0)

                index = index + 1
                shown = shown + 1
            end

            --menu buttons
            index = 2
            while index < self.menu_count do

                self.MenuButton[index] = DialogAddButton(self.dialog, self.MenuButtonName[index], 0)

                index = index + 1
            end

            --reserve first two menu buttons for next page / cancel
            if self.count > self.OPTIONS_PER_PAGE then
                self.MenuButton[1] = DialogAddButton(self.dialog, "Next Page", 0)
                self.Page = self.Page + 1
            end

            if self.cancellable then
                self.MenuButton[0] = DialogAddButton(self.dialog, "Cancel", 0)
            end

            DialogSetMessage(self.dialog, self.title)
            DialogDisplay(Player(self.pid - 1), self.dialog, GetLocalPlayer() == Player(self.pid - 1))
        end

        ---Second argument allows some data to be associated with the button index
        ---@type fun(self: DialogWindow, s: string, data: any?)
        function thistype:addButton(s, data)
            if data ~= nil then
                self.data[self.count] = data
            end
            self.ButtonName[self.count] = s
            self.count = self.count + 1
        end

        ---@param s string
        function thistype:addMenuButton(s)
            self.MenuButtonName[self.menu_count] = s
            self.menu_count = self.menu_count + 1
        end

        function thistype:destroy()
            DialogDisplay(Player(self.pid - 1), self.dialog, false)
            DialogDestroy(self.dialog)
            DestroyTrigger(self.trig)

            thistype[self.pid] = nil
        end

        ---@type fun(pid: integer, s: string, c: function): DialogWindow | nil
        function DialogWindow.create(pid, s, c)
            --safety
            if thistype[pid] then
                thistype[pid]:destroy()
            end

            ---@diagnostic disable-next-line: missing-fields
            local self = {} ---@type DialogWindow
            self.dialog = DialogCreate()
            self.title = s
            self.pid = pid
            self.trig = CreateTrigger()
            self.data = {}
            self.Button = {}
            self.ButtonName = __jarray("")
            self.MenuButton = {}
            self.MenuButtonName = __jarray("")

            setmetatable(self, mt)

            DialogSetMessage(self.dialog, self.title)
            TriggerRegisterDialogEvent(self.trig, self.dialog)
            TriggerAddCondition(self.trig, Filter(c))
            TriggerAddCondition(self.trig, Filter(thistype.dialogHandler))

            thistype[pid] = self

            return self
        end
    end
end, Debug and Debug.getLine())
