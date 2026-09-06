OnInit.global("SimpleButton", function(Require)
    Require('FrameHelpers')

    ---@class SimpleButton
    ---@field frame framehandle
    ---@field button framehandle
    ---@field tooltip framehandle|table
    ---@field text_frame framehandle
    ---@field text function
    ---@field onClick function
    ---@field makeTooltip function
    ---@field icon function
    ---@field iconColor function
    ---@field enable function
    ---@field enabled boolean
    ---@field texture string
    ---@field visible function
    ---@field setTooltipIcon function
    ---@field setTooltipText function
    ---@field setTooltipName function
    SimpleButton = {}
    do
        local thistype = SimpleButton
        local mt = { __index = thistype }

        ---@type fun(frame: framehandle, texture: string, width: number, height: number, point1: framepointtype, point2: framepointtype, x: number, y: number, onClick: function?, tooltip: string?, point3: framepointtype?, point4: framepointtype?, x2: number?, y2: number?): SimpleButton
        function SimpleButton.create(frame, texture, width, height, point1, point2, x, y, onClick, tooltip, point3, point4, x2, y2)
            local self = setmetatable({ enabled = true }, mt)
            local inset = 0.004
            local context = NextFrameCreateContext()

            self.frame = BlzCreateFrame("ContextFrameButton", frame, 0, context)
            self.button = BlzGetFrameByName("ContextFrameButtonIcon", context)
            self.text_frame = BlzGetFrameByName("ContextFrameText", context)
            BlzFrameSetPoint(self.frame, point1, frame, point2, x, y)
            BlzFrameSetSize(self.frame, width + inset * 2, height + inset * 2)
            BlzFrameSetTexture(self.button, texture, 0, true)
            BlzFrameSetSize(self.frame, width, height)
            --BlzFrameSetPoint(self.frame, FRAMEPOINT_CENTER, frame, FRAMEPOINT_CENTER, 0, 0)
            self.texture = texture

            -- Set up onClick event
            if onClick then
                self:onClick(onClick)
            end

            -- Set up simple tooltip
            if tooltip then
                self.tooltip = FrameAddSimpleTooltip(self.frame, "", tooltip, true, point3, point4, x2, y2)
            end

            return self
        end

        function thistype:setTooltipIcon(icon)
            if self.iconFrame then
                BlzFrameSetTexture(self.iconFrame, icon, 0, false)
            end
        end

        function thistype:setTooltipText(string)
            BlzFrameSetText(self.tooltip, string)
        end

        function thistype:setTooltipName(name)
            if self.nameFrame then
                BlzFrameSetText(self.nameFrame, name)
            end
        end

        function thistype:iconColor(color)
            BlzFrameSetVertexColor(self.button, color)
            BlzFrameSetVertexColor(self.frame, color)
        end

        function thistype:point(p1, p2, x, y)
            BlzFrameClearAllPoints(self.tooltip)
            BlzFrameSetPoint(self.tooltip, p1, self.frame, p2, x, y)
        end

        -- advanced tooltip
        function thistype:makeTooltip(point, width)
            local context = NextFrameCreateContext()
            self.tooltip_frame = BlzCreateFrame("TooltipBoxFrame", self.frame, 0, context)
            self.box = BlzGetFrameByName("TooltipBox", context)
            self.line = BlzGetFrameByName("TooltipSeperator", context)
            self.tooltip = BlzGetFrameByName("TooltipText", context)
            self.iconFrame = BlzGetFrameByName("TooltipIcon", context)
            self.nameFrame = BlzGetFrameByName("TooltipName", context)

            if point == FRAMEPOINT_TOPLEFT then
                BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_TOPRIGHT, 0.005, -0.05)
            elseif point == FRAMEPOINT_TOPRIGHT then
                BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_TOPLEFT, -0.005, -0.05)
            elseif point == FRAMEPOINT_BOTTOMLEFT then
                BlzFrameSetPoint(self.tooltip, point, self.frame, FRAMEPOINT_BOTTOMRIGHT, 0.005, 0.0)
            end

            BlzFrameSetPoint(self.box, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
            BlzFrameSetPoint(self.box, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
            BlzFrameSetSize(self.tooltip, width, 0)
            BlzFrameSetTooltip(self.frame, self.tooltip_frame)
        end

        function thistype:text(string)
            BlzFrameSetText(self.text_frame, string)
        end

        function thistype:icon(path)
            if path ~= nil then
                self.texture = path
                BlzFrameSetTexture(self.button, path, 0, false)
            end

            return self.texture
        end

        function thistype:visible(flag)
            BlzFrameSetVisible(self.frame, flag)
        end

        function thistype:enable(flag)
            local t = self.texture ---@type string 

            if flag == false then
                t = (t:sub(1, 34) .. "Disabled\\DIS" .. t:sub(36, t:len()))
            end

            self.enabled = flag

            BlzFrameSetTexture(self.button, t, 0, true)
        end

        function thistype:onClick(func)
            DestroyTrigger(self.click)
            self.click = nil

            if func ~= nil then
                self.click = CreateTrigger()
                TriggerAddCondition(self.click, Condition(func))
                BlzTriggerRegisterFrameEvent(self.click, self.frame, FRAMEEVENT_CONTROL_CLICK)
            end
        end

        function thistype:destroy()
            if self.click then
                DestroyTrigger(self.click)
                self.click = nil
            end

            if self.tooltip_frame then
                BlzDestroyFrame(self.tooltip_frame)
                self.tooltip_frame = nil
            elseif type(self.tooltip) == "table" and self.tooltip.frame then
                BlzDestroyFrame(self.tooltip.frame)
            end

            if self.frame then
                BlzDestroyFrame(self.frame)
                self.frame = nil
            end
        end
    end
end, Debug and Debug.getLine())
