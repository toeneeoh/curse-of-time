--[[
    shop.lua

    Used in tandem with shopcomponent.lua to define shop UI and any shop related
    functions.
]]

OnInit.final("Shop", function(Require)
    Require('Gluebutton')
    Require('UnitEvent')
    Require('Users')
    Require('Profile')
    Require('Variables')
    Require('ShopQuote')
    Require('ShopTransaction')
    Require('ItemEventRegistry')
    Require('ShopCatalog')

    -- Credits:
    --      Taysen: FDF file
    --      Hate: Frame border effects
    --      Chopinski: Original vJass

    -- Main window 
    local X                              = -0.04 ---@type number 
    local Y                              = 0.52 ---@type number 
    local WIDTH                          = 0.6 ---@type number 
    local HEIGHT                         = 0.35 ---@type number 
    local TOOLBAR_BUTTON_SIZE            = 0.02 ---@type number 
    local ROWS                           = 4 ---@type integer 
    local COLUMNS                        = 10 ---@type integer 
    local DETAILED_ROWS                  = 4 ---@type integer 
    local DETAILED_COLUMNS               = 4 ---@type integer 
    local CLOSE_ICON                     = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp" ---@type string 
    local PURCHASE_ICON                  = "ReplaceableTextures\\CommandButtons\\BTNReturnGoods.blp" ---@type string 
    local CLEAR_ICON                     = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp" ---@type string 
    local LOGIC_ICON                     = "ReplaceableTextures\\CommandButtons\\BTNMagicalSentry.blp" ---@type string 
    local SORT_LEVEL_ICON                = "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp" ---@type string 
    local SORT_CRAFTABLE_ICON            = "ReplaceableTextures\\CommandButtons\\BTNBasicStruct.blp" ---@type string 
    --local HELP_ICON                      = "UI\\Widgets\\EscMenu\\Human\\quest-unknown.blp" ---@type string 
    --local UNDO_ICON                      = "ReplaceableTextures\\CommandButtons\\BTNReplay-Loop.blp" ---@type string 
    --local DISMANTLE_ICON                 = "UI\\Feedback\\Resources\\ResourceUpkeep.blp" ---@type string 

    local INVENTORY_COUNT                = 24 ---@type integer 

    -- Details window
    local DETAIL_WIDTH                   = 0.3125 ---@type number 
    local DETAIL_HEIGHT                  = HEIGHT ---@type number 
    local DETAIL_USED_COUNT              = 6 ---@type integer 
    local DETAIL_BUTTON_SIZE             = 0.028 ---@type number 
    local DETAIL_BUTTON_GAP              = 0.045 ---@type number 
    local DETAIL_CLOSE_BUTTON_SIZE       = 0.02 ---@type number 
    local DETAIL_SHIFT_BUTTON_SIZE       = 0.012 ---@type number 
    local USED_RIGHT                     = "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedDown.blp" ---@type string 
    local USED_LEFT                      = "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedUp.blp" ---@type string 

    -- When true, a click in a component in the
    -- detail panel will detail the clicked component
    local DETAIL_COMPONENT               = true ---@type boolean 

    -- Side Panels
    local SIDE_WIDTH                     = 0.075 ---@type number 
    local SIDE_HEIGHT                    = HEIGHT ---@type number 
    local EDIT_WIDTH                     = 0.15 ---@type number 
    local EDIT_HEIGHT                    = 0.0285 ---@type number 

    -- Category buttons
    local CATEGORY_COUNT                 = 15 ---@type integer 
    local CATEGORY_SIZE                  = 0.0255 ---@type number 
    local CATEGORY_GAP                   = 0.00225 ---@type number 

    -- Item slots
    local INITIAL_X_OFFSET               = 0.04
    local INITIAL_Y_OFFSET               = 0.03
    local SLOT_WIDTH                     = 0.0375 ---@type number 
    local SLOT_HEIGHT                    = 0.0375 ---@type number 
    local ITEM_SIZE                      = 0.0375 ---@type number 
    local GOLD_SIZE                      = 0.008 ---@type number 
    local COST_WIDTH                     = 0.06 ---@type number 
    local COST_HEIGHT                    = 0.005 ---@type number 
    local COST_SCALE                     = 0.7 ---@type number 
    local COST_GAP                   = 0.009 ---@type number 
    local SLOT_GAP_X                     = 0.0145 ---@type number 
    local SLOT_GAP_Y                     = 0.038 ---@type number 
    local COMPONENT_GAP                  = SLOT_WIDTH * 0.61 ---@type number 

    -- Selected item highlight
    local ITEM_HIGHLIGHT                 = "blue_energy_sprite.mdx" ---@type string 
    local HIGHLIGHT_WIDTH                = 0.00001 ---@type number 
    local HIGHLIGHT_HEIGHT               = 0.00001 ---@type number 
    local HIGHLIGHT_SCALE                = 0.675 ---@type number 
    local HIGHLIGHT_XOFFSET              = -0.0052 ---@type number 
    local HIGHLIGHT_YOFFSET              = -0.0048 ---@type number 

    -- Scroll
    local SCROLL_DELAY                   = 0.01 ---@type number 

    -- Buy / Sell sound, model and scale
    local SPRITE_MODEL                   = "UI\\Feedback\\GoldCredit\\GoldCredit.mdl" ---@type string 
    local SPRITE_SCALE                   = 0.0005 ---@type number 
    local SUCCESS_SOUND                  = "Abilities\\Spells\\Other\\Transmute\\AlchemistTransmuteDeath1.wav" ---@type string 
    local ERROR_SOUND                    = "Sound\\Interface\\Error.wav" ---@type string 

    -- Main storage table
    local registry = array2d() ---@type any[][]

    --[[ ----------------------------------------------------------------------------------------- ]]
    --[[                                          API                                              ]]
    --[[ ----------------------------------------------------------------------------------------- ]]
    ---@param shop Shop
    ---@param pid integer
    ---@param si ShopItem
    ---@return boolean
    local function IsCraftable(shop, pid, si)
        return ShopQuote.isCraftable(shop, si, pid)
    end

    ---@type fun(id: integer, aoe: number):Shop
    function CreateShop(id, aoe)
        return Shop.create(id, aoe)
    end

    ---@type fun(id: integer, itm: string|integer, num: integer)
    function ShopSetStock(id, itm, num)
        Shop.setStock(id, itm, num)
    end

    ---@type fun(id: integer, icon: string, description: string):integer
    function ShopAddCategory(id, icon, description)
        return Shop.addCategory(id, icon, description)
    end

    ---@type fun(id: integer, itemId: string|integer, categories: integer)
    function ShopAddItem(id, itemId, categories)
        Shop.addItem(id, itemId, categories)
    end

    ---@type fun(whichItem: string|integer, compstring: string)
    function ItemAddComponents(whichItem, compstring)
        ShopItem.addComponents(whichItem, compstring)
    end

    --[[ ----------------------------------------------------------------------------------------- ]]
    --[[                                           System                                          ]]
    --[[ ----------------------------------------------------------------------------------------- ]]
    ---@class Slot
    ---@field item ShopItem
    ---@field button Button
    ---@field costicon framehandle[]
    ---@field cost framehandle[]
    ---@field xPos number
    ---@field yPos number
    ---@field isVisible boolean
    ---@field slot framehandle
    ---@field visible function
    ---@field create function
    ---@field x function
    ---@field y function
    ---@field onClick function
    ---@field onScroll function
    ---@field onDoubleClick function
    ---@field parent framehandle
    Slot = {}
    do
        local thistype = Slot
        local mt = { __index = Slot }
        thistype.isVisible=nil ---@type boolean 

        function thistype:x(newX)
            if newX then
                self.xPos = newX

                BlzFrameClearAllPoints(self.slot)
                BlzFrameSetPoint(self.slot, FRAMEPOINT_TOPLEFT, self.parent, FRAMEPOINT_TOPLEFT, self.xPos, self.yPos)
            end

            return self.xPos
        end

        function thistype:y(newY)
            if newY then
                self.yPos = newY

                BlzFrameClearAllPoints(self.slot)
                BlzFrameSetPoint(self.slot, FRAMEPOINT_TOPLEFT, self.parent, FRAMEPOINT_TOPLEFT, self.xPos, self.yPos)
            end

            return self.yPos
        end

        function thistype:visible(visibility)
            if visibility ~= nil then
                self.isVisible = visibility
                BlzFrameSetVisible(self.slot, visibility)
            end

            return self.isVisible
        end

        function thistype:onClick(c)
            self.button:onClick(c)
        end

        function thistype:onScroll(c)
            self.button:onScroll(c)
        end

        function thistype:onDoubleClick(c)
            self.button:onDoubleClick(c)
        end

        ---@type fun(parent: framehandle, i: ShopItem, width: number, height: number, x: number, y: number, point: framepointtype, simpleTooltip: boolean): Slot
        function Slot.create(parent, i, width, height, x, y, point, simpleTooltip)
            local self = {}

            setmetatable(self, mt)

            self.item = i
            self.xPos = x
            self.yPos = y
            self.parent = parent
            self.slot = BlzCreateFrameByType("FRAME", "", parent, "", 0)
            self.button = Button.create(self.slot, width, height, 0, 0, simpleTooltip)
            self.button.tooltip:point(point)

            BlzFrameSetPoint(self.slot, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, x, y)
            BlzFrameSetSize(self.slot, width, height)

            if i ~= 0 then
                self.button:icon(i.icon)
                self.button.tooltip:text(i.tooltip)
                self.button.tooltip:name(i.name)
                self.button.tooltip:icon(i.icon)
            end

            return self
        end
    end

    ---@class ShopSlot : Slot
    ---@field shop Shop
    ---@field prev Slot
    ---@field next Slot
    ---@field right Slot
    ---@field left Slot
    ---@field row integer
    ---@field column integer
    ---@field refresh function
    ---@field update function
    ---@field move function
    ---@field item ShopItem
    ---@field onClick function
    ---@field onDoubleClick function
    ShopSlot = {}
    do
        local thistype = ShopSlot

        ---@param pid integer
        function thistype:refresh(pid)
            local available, label = GetItemAvailability(self.item.id, pid)
            local price = GetItemPrice(self.item.id, pid)
            local status

            if self.shop.stock[self.item.id] == 0 then
                status = "SOLD OUT"
            elseif not available then
                status = label or "UNAVAILABLE"
            elseif not price then
                status = "NOT FOR SALE"
            end

            local row = 0
            for currency = 0, CURRENCY_COUNT - 1 do
                local visible = not status and price[currency] > 0

                BlzFrameSetVisible(self.costicon[currency], visible)
                BlzFrameSetVisible(self.cost[currency], visible)

                if visible then
                    BlzFrameClearAllPoints(self.costicon[currency])
                    BlzFrameSetPoint(self.costicon[currency], FRAMEPOINT_TOPLEFT, self.slot, FRAMEPOINT_TOPLEFT, 0., -0.04 - row * COST_GAP)
                    BlzFrameSetText(self.cost[currency], "|cffffcc00    " .. price[currency] .. "|r")
                    row = row + 1
                end
            end

            if status then
                BlzFrameSetVisible(self.cost[0], true)
                BlzFrameSetText(self.cost[0], "|cff999999" .. status .. "|r")
            end
        end

        ---@type fun(self: ShopSlot, row: integer, column: integer)
        function thistype:move(row, column)
            self.row = row
            self.column = column
            self:x(INITIAL_X_OFFSET + ((SLOT_WIDTH + SLOT_GAP_X) * column))
            self:y(- (INITIAL_Y_OFFSET + ((SLOT_HEIGHT + SLOT_GAP_Y) * row)))

            self:update()
        end

        function thistype:update()
            if self.column <= (self.shop.columns / 2) and self.row < 3 then
                self.button.tooltip:point(FRAMEPOINT_TOPLEFT)
            elseif self.column >= ((self.shop.columns / 2) + 1) and self.row < 3 then
                self.button.tooltip:point(FRAMEPOINT_TOPRIGHT)
            elseif self.column <= (self.shop.columns / 2) and self.row >= 3 then
                self.button.tooltip:point(FRAMEPOINT_BOTTOMLEFT)
            else
                self.button.tooltip:point(FRAMEPOINT_BOTTOMRIGHT)
            end
        end

        local mt = {
            __index = function(tbl, key)
                return rawget(Slot, key) or rawget(ShopSlot, key)
            end
        }

        ---@type fun(S: Shop, i: ShopItem, row: integer, column: integer): ShopSlot
        function ShopSlot.create(S, i, row, column)
            local self = Slot.create(S.main, i, ITEM_SIZE, ITEM_SIZE, INITIAL_X_OFFSET + ((SLOT_WIDTH + SLOT_GAP_X) * column), - (INITIAL_Y_OFFSET + ((SLOT_HEIGHT + SLOT_GAP_Y) * row)), FRAMEPOINT_TOPLEFT, false) ---@type ShopSlot

            --inherit from both Slot and ShopSlot
            setmetatable(self, mt)

            self.shop = S
            self.next = nil
            self.prev = nil
            self.right = nil
            self.left = nil
            self.row = row
            self.column = column
            self.costicon = {}
            self.cost = {}
            self:onClick(thistype.onClicked)
            self:onScroll(thistype.onScrolled)
            self:onDoubleClick(thistype.onDoubleClicked)
            registry[(self.button.frame)][0] = self

            --currencies
            for k = 0, CURRENCY_COUNT - 1 do
                self.costicon[k] = BlzCreateFrameByType("BACKDROP", "", self.slot, "", 0)
                self.cost[k] = BlzCreateFrameByType("TEXT", "", self.slot, "", 0)
                BlzFrameSetText(self.cost[k], "")
                BlzFrameSetPoint(self.costicon[k], FRAMEPOINT_TOPLEFT, self.slot, FRAMEPOINT_TOPLEFT, 0., -0.04 - k * COST_GAP)
                BlzFrameSetSize(self.costicon[k], GOLD_SIZE, GOLD_SIZE)
                BlzFrameSetTexture(self.costicon[k], CURRENCY_ICON[k + 1], 0, true)
                --call BlzFrameSetEnable(costicon[k], false)

                BlzFrameSetPoint(self.cost[k], FRAMEPOINT_TOPLEFT, self.costicon[k], FRAMEPOINT_TOPRIGHT, -0.013, -0.004)
                BlzFrameSetSize(self.cost[k], COST_WIDTH, COST_HEIGHT)
                --call BlzFrameSetEnable(cost[k], false)
                BlzFrameSetScale(self.cost[k], COST_SCALE)
                BlzFrameSetTextAlignment(self.cost[k], TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)

                BlzFrameSetVisible(self.costicon[k], false)
                BlzFrameSetVisible(self.cost[k], false)
            end

            ShopSlot.update(self)

            return self
        end

        function thistype.onScrolled() --shop button
            local self = registry[(BlzGetTriggerFrame())][0] ---@type ShopSlot

            if self then
                BlzFrameSetEnable(BlzGetTriggerFrame(), false)
                BlzFrameSetEnable(BlzGetTriggerFrame(), true)

                if GetLocalPlayer() == GetTriggerPlayer() then
                    local down = BlzGetTriggerFrameValue() < 0

                    self.shop:scroll(down)
                end
            end
        end

        function thistype.onClicked()
            local p = GetTriggerPlayer()
            local frame = BlzGetTriggerFrame() ---@type framehandle 
            local self = registry[(frame)][0] ---@type ShopSlot

            if self then
                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)

                self.shop:detail(self.item, p)
            end
        end

        function thistype.onDoubleClicked()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type ShopSlot

            if self then
                if self.shop:buy(self.item, GetTriggerPlayer()) then
                    if GetLocalPlayer() == GetTriggerPlayer() then
                        self.button:play(SPRITE_MODEL, SPRITE_SCALE, 0)
                    end
                end
            end
        end
    end

    ---@class Detail
    ---@field button Button[][]
    ---@field components Slot[][]
    ---@field main ShopSlot[]
    ---@field item ShopItem[]
    ---@field purchase Button
    ---@field used table
    ---@field trigger trigger
    ---@field show function
    ---@field refresh function
    ---@field shop Shop
    ---@field close Button
    ---@field left Button
    ---@field right Button
    ---@field shift function
    ---@field visible function
    ---@field isVisible boolean
    ---@field create function
    ---@field count integer[]
    ---@field frame framehandle
    ---@field topSeparator framehandle
    ---@field bottomSeparator framehandle
    ---@field usedIn framehandle
    ---@field horizontalRight framehandle
    ---@field horizontalLeft framehandle
    ---@field verticalCenter framehandle
    ---@field tooltip framehandle
    ---@field scrollFrame framehandle
    Detail = {}
    do
        local thistype = Detail
        local mt = { __index = Detail }
        thistype.trigger = CreateTrigger()

        thistype.isVisible=nil ---@type boolean 
        thistype.used=array2d(0) ---@type table 
        thistype.count = __jarray(0)

        function thistype:visible(visibility)
            if visibility ~= nil then
                self.isVisible = visibility
                BlzFrameSetVisible(self.frame, visibility)
            end

            return self.isVisible
        end

        ---@param frame framehandle
        ---@param point framepointtype
        ---@param parent framehandle
        ---@param relative framepointtype
        ---@param width number
        ---@param height number
        ---@param x number
        ---@param y number
        ---@param visible boolean
        function thistype:update(frame, point, parent, relative, width, height, x, y, visible)
            if visible then
                BlzFrameClearAllPoints(frame)
                BlzFrameSetPoint(frame, point, parent, relative, x, y)
                BlzFrameSetSize(frame, width, height)
            end

            BlzFrameSetVisible(frame, visible)
        end

        ---@param left boolean
        ---@param p player
        function thistype:shift(left, p)
            local i ---@type ShopItem 
            local j ---@type integer 
            local pid = GetPlayerId(p) + 1 ---@type integer 

            if left then
                if self.item[pid].relation[self.count[pid]] ~= 0 and self.count[pid] >= DETAIL_USED_COUNT then
                    j = 0

                    while not (j == DETAIL_USED_COUNT - 1) do
                            self.used[pid][j] = self.used[pid][j + 1]

                            if GetLocalPlayer() == p then
                                self.button[pid][j]:icon(self.used[pid][j].icon)
                                self.button[pid][j].tooltip:text(self.used[pid][j].tooltip)
                                self.button[pid][j].tooltip:name(self.used[pid][j].name)
                                self.button[pid][j].tooltip:icon(self.used[pid][j].icon)
                                self.button[pid][j]:available(self.shop:has(self.used[pid][j].id))
                                self.button[pid][j]:visible(true)
                            end
                        j = j + 1
                    end

                    i = ShopItem.get(self.item[pid].relation[self.count[pid]])

                    if i ~= 0 then
                        self.count[pid] = self.count[pid] + 1
                        self.used[pid][j] = i

                        if GetLocalPlayer() == p then
                            self.button[pid][j]:icon(i.icon)
                            self.button[pid][j].tooltip:text(i.tooltip)
                            self.button[pid][j].tooltip:name(i.name)
                            self.button[pid][j].tooltip:icon(i.icon)
                            self.button[pid][j]:available(self.shop:has(i.id))
                            self.button[pid][j]:visible(true)
                        end
                    end
                end
            else
                if self.count[pid] > DETAIL_USED_COUNT then
                    j = DETAIL_USED_COUNT - 1

                    while j ~= 0 do
                            self.used[pid][j] = self.used[pid][j - 1]

                            if GetLocalPlayer() == p then
                                self.button[pid][j]:icon(self.used[pid][j].icon)
                                self.button[pid][j].tooltip:text(self.used[pid][j].tooltip)
                                self.button[pid][j].tooltip:name(self.used[pid][j].name)
                                self.button[pid][j].tooltip:icon(self.used[pid][j].icon)
                                self.button[pid][j]:available(self.shop:has(self.used[pid][j].id))
                                self.button[pid][j]:visible(true)
                            end
                        j = j - 1
                    end

                    i = ShopItem.get(self.item[pid].relation[self.count[pid] - DETAIL_USED_COUNT - 1])

                    if i ~= 0 then
                        self.count[pid] = self.count[pid] - 1
                        self.used[pid][j] = i

                        if GetLocalPlayer() == p then
                            self.button[pid][j]:icon(i.icon)
                            self.button[pid][j].tooltip:text(i.tooltip)
                            self.button[pid][j].tooltip:name(i.name)
                            self.button[pid][j].tooltip:icon(i.icon)
                            self.button[pid][j]:available(self.shop:has(i.id))
                            self.button[pid][j]:visible(true)
                        end
                    end
                end
            end
        end

        ---@param p player
        function thistype:showUsed(p)
            local pid = GetPlayerId(p) + 1 ---@type integer 

            if GetLocalPlayer() == p then
                for i = 0, INVENTORY_COUNT - 1 do
                    if i < DETAIL_USED_COUNT then
                        self.button[pid][i]:visible(false)
                    end
                    self.components[pid][i]:visible(false)
                end
            end

            for i = 0, DETAIL_USED_COUNT - 1 do
                if self.item[pid].relation[i] == 0 then break end

                local itm = ShopItem.get(self.item[pid].relation[i]) ---@type ShopItem

                if itm ~= 0 then
                    self.used[pid][i] = itm

                    if GetLocalPlayer() == p then
                        self.button[pid][self.count[pid]]:icon(itm.icon)
                        self.button[pid][self.count[pid]].tooltip:text(itm.tooltip)
                        self.button[pid][self.count[pid]].tooltip:name(itm.name)
                        self.button[pid][self.count[pid]].tooltip:icon(itm.icon)
                        self.button[pid][self.count[pid]]:visible(true)
                        self.button[pid][self.count[pid]]:available(self.shop:has(itm.id))
                    end

                    self.count[pid] = self.count[pid] + 1
                end
            end
        end

        ---@param pid integer
        function thistype:refresh(pid)
            if self.isVisible and self.item[pid] ~= 0 then
                self:show(self.item[pid], Player(pid - 1))
            end
        end

        ---@param i ShopItem
        ---@param p player
        function thistype:show(i, p)
            local component ---@type ShopItem 
            local slot ---@type Slot 
                local pid = GetPlayerId(p) + 1
            local counter = __jarray(0) ---@type table 

            if i ~= 0 then
                self.item[pid] = i
                self.count[pid] = 0

                self.main[pid].item = i
                self.main[pid].button:icon(i.icon)
                self.main[pid].button.tooltip:text(i.tooltip)
                self.main[pid].button.tooltip:name(i.name)
                self.main[pid].button.tooltip:icon(i.icon)
                self.main[pid].button:available(self.shop:has(i.id))

                self:showUsed(p)

                local componentCount = i:components()

                -- count items
                for k = 1, INVENTORY_COUNT do
                    local itm = Profile[pid].hero.items[k]
                    if itm and not itm.nocraft then
                        local index = GetItem(itm.id)
                        counter[index] = counter[index] + math.max(1, itm.charges)
                    end
                end

                if componentCount > 0 then
                    if GetLocalPlayer() == p then
                        BlzFrameSetVisible(self.verticalCenter, true)
                    end

                    for k = 0, INVENTORY_COUNT - 1 do
                        if k == componentCount then break end

                        slot = self.components[pid][k]
                        component = ShopItem.get(i.component[k])

                        if GetLocalPlayer() == p then
                            self:update(slot.slot, FRAMEPOINT_TOPLEFT, slot.parent, FRAMEPOINT_TOPLEFT, ITEM_SIZE, ITEM_SIZE, 0.1436 - (COMPONENT_GAP * 0.5 * (componentCount - 1)) + k * COMPONENT_GAP, -0.09, true)
                        end

                        slot.item = component
                        slot.button:icon(component.icon)
                        slot.button.tooltip:text(component.tooltip)
                        slot.button.tooltip:name(component.name)
                        slot.button.tooltip:icon(component.icon)
                        slot.button:available(self.shop:has(component.id))

                        if counter[component.id] > 0 then
                            counter[component.id] = counter[component.id] - 1
                            slot.button:checked(true)
                        else
                            slot.button:checked(false)
                        end

                        if GetLocalPlayer() == p then
                            slot:visible(true)
                        end
                    end
                else
                    for k = 0, INVENTORY_COUNT - 1 do
                        if GetLocalPlayer() == p then
                            self.components[pid][k]:visible(false)
                        end
                    end

                    if GetLocalPlayer() == p then
                        BlzFrameSetVisible(self.verticalCenter, false)
                    end
                end

                if GetLocalPlayer() == p then
                    BlzFrameSetText(self.tooltip, i.tooltip)
                    self.purchase:enabled(ShopQuote.evaluate(self.shop, i, pid).can_buy)
                    self:visible(true)
                end
            end
        end

        ---@type fun(s: Shop): Detail
        function thistype.create(s)
            ---@diagnostic disable-next-line: missing-fields
            local self = {} ---@type Detail
            local u = User.first ---@type User 

            setmetatable(self, mt)

            self.shop = s
            self.isVisible = false
            self.frame = BlzCreateFrame("EscMenuBackdrop", s.main, 0, 0)
            self.topSeparator = BlzCreateFrameByType("BACKDROP", "", self.frame, "", 0)
            self.bottomSeparator = BlzCreateFrameByType("BACKDROP", "", self.frame, "", 0)
            self.tooltip = BlzCreateFrame("DescriptionArea", self.frame, 0, 0)
            self.button = {}
            self.components = {}
            self.main = {}
            self.item = {}

            --components

            self.verticalCenter = BlzCreateFrameByType("BACKDROP", "", self.frame, "", 0)
            BlzFrameSetSize(self.verticalCenter, 0.001, 0.021)

            self.scrollFrame = BlzCreateFrameByType("BUTTON", "", self.frame, "", 0)
            self.usedIn = BlzCreateFrameByType("TEXT", "", self.scrollFrame, "", 0)
            self.close = Button.create(self.frame, DETAIL_CLOSE_BUTTON_SIZE, DETAIL_CLOSE_BUTTON_SIZE, 0.26676, - 0.025000, true)
            self.close:icon(CLOSE_ICON)
            self.close:onClick(thistype.onClick)
            self.close.tooltip:text("Close")
            self.purchase = Button.create(self.frame, DETAIL_CLOSE_BUTTON_SIZE, DETAIL_CLOSE_BUTTON_SIZE, 0., 0., true)
            self.purchase:icon(PURCHASE_ICON)
            self.purchase:onClick(thistype.onPurchase)
            self.purchase.tooltip:text("Purchase")
            self.purchase:enabled(false)
            self.left = Button.create(self.scrollFrame, DETAIL_SHIFT_BUTTON_SIZE, DETAIL_SHIFT_BUTTON_SIZE, 0.0050000, - 0.0025000, true)
            self.left:icon(USED_LEFT)
            self.left:onClick(thistype.onClick)
            self.left.tooltip:text("Scroll Left")
            self.right = Button.create(self.scrollFrame, DETAIL_SHIFT_BUTTON_SIZE, DETAIL_SHIFT_BUTTON_SIZE, 0.24650, - 0.0025000, true)
            self.right:icon(USED_RIGHT)
            self.right:onClick(thistype.onClick)
            self.right.tooltip:text("Scroll Right")
            registry[(self.close.frame)][0] = self
            registry[(self.left.frame)][0] = self
            registry[(self.right.frame)][0] = self
            registry[(self.scrollFrame)][0] = self
            registry[(self.purchase.frame)][0] = self

            BlzFrameSetPoint(self.frame, FRAMEPOINT_TOPLEFT, self.shop.main, FRAMEPOINT_TOPLEFT, WIDTH - DETAIL_WIDTH, 0.0000)
            BlzFrameSetPoint(self.scrollFrame, FRAMEPOINT_TOPLEFT, self.frame, FRAMEPOINT_TOPLEFT, 0.022500, - 0.28)
            BlzFrameSetPoint(self.topSeparator, FRAMEPOINT_TOPLEFT, self.frame, FRAMEPOINT_TOPLEFT, 0.027500, - 0.13)
            BlzFrameSetPoint(self.bottomSeparator, FRAMEPOINT_TOPLEFT, self.frame, FRAMEPOINT_TOPLEFT, 0.027500, - 0.28)
            BlzFrameSetPoint(self.verticalCenter, FRAMEPOINT_TOPLEFT, self.frame, FRAMEPOINT_TOPLEFT, 0.155, - 0.0677)
            BlzFrameSetPoint(self.usedIn, FRAMEPOINT_TOPLEFT, self.scrollFrame, FRAMEPOINT_TOPLEFT, 0.11500, - 0.0025000)
            BlzFrameSetPoint(self.tooltip, FRAMEPOINT_TOPLEFT, self.frame, FRAMEPOINT_TOPLEFT, 0.027500, - 0.135)
            BlzFrameSetPoint(self.purchase.iconFrame, FRAMEPOINT_TOPLEFT, self.close.iconFrame, FRAMEPOINT_BOTTOMLEFT, 0., 0.)
            BlzFrameSetSize(self.frame, DETAIL_WIDTH, DETAIL_HEIGHT)
            BlzFrameSetSize(self.scrollFrame, 0.26750, 0.06100)
            BlzFrameSetSize(self.topSeparator, 0.252, 0.001)
            BlzFrameSetSize(self.bottomSeparator, 0.252, 0.001)
            BlzFrameSetSize(self.usedIn, 0.04, 0.012)
            BlzFrameSetSize(self.tooltip, 0.31, 0.145)
            BlzFrameSetText(self.tooltip, "")
            BlzFrameSetText(self.usedIn, "|cffFFCC00Used in|r")
            BlzFrameSetEnable(self.usedIn, false)
            BlzFrameSetScale(self.usedIn, 1.00)
            BlzFrameSetTextAlignment(self.usedIn, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
            BlzFrameSetTexture(self.bottomSeparator, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
            BlzFrameSetTexture(self.topSeparator, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
            BlzFrameSetTexture(self.verticalCenter, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
            BlzTriggerRegisterFrameEvent(self.trigger, self.scrollFrame, FRAMEEVENT_MOUSE_WHEEL)

            while u do
                self.main[u.id] = Slot.create(self.frame, 0, SLOT_WIDTH, SLOT_HEIGHT, 0.13625, - 0.030000, FRAMEPOINT_TOPRIGHT, false)
                self.main[u.id]:visible(GetLocalPlayer() == u.player)
                self.main[u.id]:onClick(thistype.onClick)
                self.main[u.id]:onDoubleClick(thistype.onDoubleClick)

                registry[(self.main[u.id].button.frame)][0] = self

                self.components[u.id] = {}
                for j = 0, INVENTORY_COUNT - 1 do
                    self.components[u.id][j] = Slot.create(self.frame, 0, SLOT_WIDTH * 0.6, SLOT_HEIGHT * 0.6, 0.13625, 0., FRAMEPOINT_TOPRIGHT, false)
                    self.components[u.id][j]:visible(false)
                    self.components[u.id][j]:onClick(thistype.onClick)
                    self.components[u.id][j]:onDoubleClick(thistype.onDoubleClick)

                    registry[(self.components[u.id][j].button.frame)][0] = self
                end

                self.button[u.id] = {}
                for j = 0, DETAIL_USED_COUNT - 1 do
                    self.button[u.id][j] = Button.create(self.scrollFrame, DETAIL_BUTTON_SIZE, DETAIL_BUTTON_SIZE, 0.0050000 + DETAIL_BUTTON_GAP*j, - 0.019, false)
                    self.button[u.id][j]:visible(false)
                    self.button[u.id][j]:onClick(thistype.onClick)
                    self.button[u.id][j]:onScroll(thistype.onScroll)
                    self.button[u.id][j].tooltip:point(FRAMEPOINT_BOTTOMRIGHT)
                    registry[(self.button[u.id][j].frame)][0] = self
                    registry[(self.button[u.id][j].frame)][1] = j
                end

                u = u.next
            end

            BlzFrameSetVisible(self.frame, false)

            return self
        end

        function thistype.onScroll()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Detail

            if self then
                self:shift(BlzGetTriggerFrameValue() < 0, GetTriggerPlayer())
            end
        end

        function thistype.onClick()
            local frame = BlzGetTriggerFrame() ---@type framehandle 
            local self = registry[(frame)][0] ---@type Detail
            local i = registry[(frame)][1] ---@type integer
            local j = 0 ---@type integer 
            local pid = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
            local found = false ---@type boolean 

            if self then
                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)

                if frame == self.close.frame then
                    self.shop:detail(0, GetTriggerPlayer())
                elseif frame == self.left.frame then
                    self:shift(false, GetTriggerPlayer())
                elseif frame == self.right.frame then
                    self:shift(true, GetTriggerPlayer())
                elseif frame == self.main[pid].button.frame then
                    self.shop:select(self.main[pid].item, GetTriggerPlayer())
                else
                    while j ~= INVENTORY_COUNT do
                            if frame == self.components[pid][j].button.frame then
                                found = true
                                if DETAIL_COMPONENT then
                                    self.shop:detail(self.components[pid][j].item, GetTriggerPlayer())
                                end
                            end

                        j = j + 1
                    end

                    if not found and frame ~= self.main[pid].button.frame then
                        self.shop:detail(self.used[pid][i], GetTriggerPlayer())
                    end
                end
            end
        end

        function thistype.onPurchase()
            local frame     = BlzGetTriggerFrame() ---@type framehandle 
            local p         = GetTriggerPlayer()
            local pid       = GetPlayerId(p) + 1
            local self      = registry[(frame)][0] ---@type Detail

            if self then
                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)

                if self.shop:buy(self.main[pid].item, p) then
                    if GetLocalPlayer() == p then
                        self.main[pid].button:play(SPRITE_MODEL, SPRITE_SCALE, 0)
                    end
                end
            end
        end

        function thistype.onDoubleClick()
            local frame     = BlzGetTriggerFrame() ---@type framehandle 
            local p         = GetTriggerPlayer()
            local self      = registry[(frame)][0] ---@type Detail
            local i         = registry[(frame)][1] ---@type integer
            local j         = 0 ---@type integer 
            local pid        = GetPlayerId(p) + 1
            local found     = false ---@type boolean 

            if self then
                if frame == self.main[pid].button.frame then
                    if self.shop:buy(self.main[pid].item, p) then
                        if GetLocalPlayer() == p then
                            self.main[pid].button:play(SPRITE_MODEL, SPRITE_SCALE, 0)
                        end
                    end
                else
                    while j ~= INVENTORY_COUNT do
                            if frame == self.components[pid][j].button.frame then
                                found = true
                                if self.shop:buy(self.components[pid][j].item, p) then
                                    if GetLocalPlayer() == p then
                                        self.components[pid][j].button:play(SPRITE_MODEL, SPRITE_SCALE, 0)
                                    end
                                end
                            end

                        j = j + 1
                    end

                    if not found then
                        if self.shop:buy(self.used[pid][i], p) then
                            if GetLocalPlayer() == p then
                                self.button[pid][i]:play(SPRITE_MODEL, SPRITE_SCALE, 0)
                            end
                        end
                    end
                end
            end
        end

        TriggerAddAction(thistype.trigger, thistype.onScroll)
    end

    --[[ TODO: INVENTORY ONCLICK FOR SHOP
        function thistype.onClick()
            local frame     = BlzGetTriggerFrame() ---@type framehandle 
            local self      = registry[(frame)][0] ---@type Inventory
            local i         = registry[(frame)][1] ---@type integer
            local pid       = GetPlayerId(GetTriggerPlayer()) + 1

            if self then
                self.selected[pid] = i

                local s = ShopItem.get(Profile[pid].hero.items[i + 1].id)

                if s ~= 0 then
                    self.shop:detail(s, GetTriggerPlayer())
                end
            end
        end
        ]]

    ---@class Category
    ---@field active integer
    ---@field andLogic boolean
    ---@field add function
    ---@field shop Shop
    ---@field count integer
    ---@field value integer[]
    ---@field button Button[]
    ---@field clear function
    ---@field create function
    Category = {}
    do
        local thistype = Category
        local mt = { __index = Category }

        function thistype:clear()
            local i         = 0 ---@type integer 

            self.active = 0

            while i ~= CATEGORY_COUNT do
                if self.button[i] then
                    self.button[i]:enabled(false)
                end
                i = i + 1
            end

            self.shop:filter(self.active, self.andLogic)
        end

        ---@type fun(self: Category, icon: string, description: string):integer
        function thistype:add(icon, description)
            if self.count < CATEGORY_COUNT then
                self.count = self.count + 1
                self.value[self.count] = R2I(2 ^ self.count)
                self.button[self.count] = Button.create(self.shop.leftPanel, CATEGORY_SIZE, CATEGORY_SIZE, 0.024750, - (0.021500 + CATEGORY_SIZE * self.count + CATEGORY_GAP), true)
                self.button[self.count]:icon(icon)
                self.button[self.count]:enabled(false)
                self.button[self.count]:onClick(thistype.onClick)
                self.button[self.count].tooltip:text(description)
                registry[(self.button[self.count].frame)][0] = self
                registry[(self.button[self.count].frame)][1] = self.count

                return self.value[self.count]
            else
                print("Maximum number of categories reached.")
            end

            return 0
        end

        ---@type fun(shop: Shop): Category
        function thistype.create(shop)
            local self = {}

            setmetatable(self, mt)

            self.count = -1
            self.active = 0
            self.andLogic = true
            self.shop = shop
            self.value = __jarray(0)
            self.button = {}

            return self
        end

        function thistype.onClick()
            local frame             = BlzGetTriggerFrame() ---@type framehandle 
            local self          = registry[(frame)][0] ---@type Category
            local i         = registry[(frame)][1] ---@type integer

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    self.button[i]:enabled(not self.button[i].isEnabled)

                    if self.button[i].isEnabled then
                        self.active = self.active + self.value[i]
                    else
                        self.active = self.active - self.value[i]
                    end

                    self.shop:filter(self.active, self.andLogic)
                end

                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)
            end
        end
    end

    local shoppool = array2d()

    ---@class Shop
    ---@field setStock function
    ---@field addCategory function
    ---@field addItem function
    ---@field main framehandle
    ---@field base framehandle
    ---@field stock table
    ---@field aoe number
    ---@field create function
    ---@field current unit[]
    ---@field detail function
    ---@field buy function
    ---@field category Category
    ---@field scroll function
    ---@field rows integer
    ---@field columns integer
    ---@field details Detail
    ---@field leftPanel framehandle
    ---@field select function
    ---@field has function
    ---@field filter function
    ---@field logic Button
    ---@field levelreqButton Button
    ---@field levelsort boolean
    ---@field craftableButton Button
    ---@field craftablesort boolean
    ---@field clearCategory Button
    ---@field canScroll boolean[]
    ---@field timer timer[]
    ---@field visible function
    ---@field first ShopSlot
    ---@field group group[]
    ---@field trigger trigger
    ---@field search trigger
    ---@field lastClicked Button[]
    ---@field edit framehandle
    ---@field sliderFrame framehandle
    ---@field sliderTrigger trigger
    ---@field sliderValue number
    ---@field refresh function
    Shop = {}
    do
        local thistype = Shop
        local mt = { __index = Shop }
        thistype.search     = CreateTrigger()
        thistype.keyPress   = CreateTrigger()
        thistype.escPressed = CreateTrigger()
        thistype.count      = -1 ---@type integer 
        thistype.success    = nil ---@type sound 
        thistype.error      = nil ---@type sound 
        thistype.noGold     = {} ---@type sound[] 
        thistype.timer      = {} ---@type timer[] 
        thistype.canScroll  = {} ---@type boolean[] 
        thistype.current    = {} ---@type unit[] 
        thistype.isVisible  = nil ---@type boolean 
        thistype.aoe        = 1000 ---@type number 

        ---@type fun(id: integer, itemid: integer, num: integer)
        function thistype.setStock(id, itemid, num)
            local self = registry[id][0] ---@type Shop
            itemid = GetItem(itemid)
            local slot = registry[self][itemid] ---@type ShopSlot

            self.stock[itemid] = num
            if slot and GetItemPrice then
                slot:refresh(GetPlayerId(GetLocalPlayer()) + 1)
            end
        end

        ---@type fun(self: Shop, visibility: boolean):boolean
        function thistype:visible(visibility)
            if visibility ~= nil then
                self.isVisible = visibility

                if visibility then
                    thistype.refresh(GetPlayerId(GetLocalPlayer()) + 1)
                end

                BlzFrameSetVisible(self.base, visibility)
            end

            return self.isVisible
        end

        ---@param i ShopItem
        ---@param p player
        ---@param test boolean
        ---@return boolean
        function thistype:buy(i, p, test)
            local pid = GetPlayerId(p) + 1
            local quote = test and ShopQuote.evaluate(self, i, pid)
                or ShopTransaction.commit(self, i, pid)

            if not quote.can_buy then
                if not test then
                    local sound = quote.reason == "currency"
                        and self.noGold[GetPlayerRace(p)] or self.error
                    if not GetSoundIsPlaying(sound) then
                        StartSoundForPlayerBJ(p, sound)
                    end
                end
                return false
            end

            if test then
                return true
            end

            if not GetSoundIsPlaying(self.success) then
                StartSoundForPlayerBJ(p, self.success)
            end

            thistype.refresh(pid)

            return true
        end

        ---@type fun(self: Shop, down: boolean)
        function thistype:scroll(down)
            local slot = self.first

            if (down and self.tail ~= self.last) or (not down and self.head ~= self.first) then
                while slot do
                        if down then
                            slot:move(slot.row - 1, slot.column)
                        else
                            slot:move(slot.row + 1, slot.column)
                        end

                        slot:visible(slot.row >= 0 and slot.row <= self.rows - 1 and slot.column >= 0 and slot.column <= self.columns - 1)

                        if slot.row == 0 and slot.column == 0 then
                            self.head = slot
                        end

                        if (slot.row == self.rows - 1 and slot.column == self.columns - 1) or (slot == self.last and slot.isVisible) then
                            self.tail = slot
                        end
                    slot = slot.right ---@type ShopSlot
                end

                local adjust = (down and -1) or 1

                self.sliderValue = self.sliderValue + adjust

                BlzFrameSetValue(self.sliderFrame, self.sliderValue)
            end
        end

        ---@type fun(self: Shop, categories: integer, andLogic: boolean)
        function thistype:filter(categories, andLogic)
            local slot  = shoppool[self][0] ---@type ShopSlot 
            local text  = BlzFrameGetText(self.edit) ---@type string 
            local i     = -1 ---@type integer 
            local total = self.rows * self.columns
            local pid   = GetPlayerId(GetLocalPlayer()) + 1
            local process

            self.size = 0
            self.first = nil
            self.last = nil
            self.head = nil
            self.tail = nil

            while slot do
                    if andLogic then
                        process = categories == 0 or BlzBitAnd(slot.item.categories, categories) >= categories
                    else
                        process = categories == 0 or BlzBitAnd(slot.item.categories, categories) > 0
                    end

                    if text ~= "" and text ~= nil then
                        process = process and thistype.find(StringCase(slot.item.name, false), StringCase(text, false))
                    end

                    local _, origid = GetItem(slot.item.id)

                    if self.levelsort then
                        process = process and (GetHeroLevel(Hero[pid]) >= ItemData[origid][ITEM_LEVEL_REQUIREMENT])
                    end

                    if self.craftablesort then
                        process = process and IsCraftable(self, pid, slot.item)
                    end

                    if process then
                        i = i + 1
                        self.size = self.size + 1
                        slot:move(R2I(i/self.columns), ModuloInteger(i, self.columns))
                        slot:visible(slot.row >= 0 and slot.row <= self.rows - 1 and slot.column >= 0 and slot.column <= self.columns - 1)

                        if i > 0 then
                            slot.left = self.last
                            self.last.right = slot
                        else
                            self.first = slot
                            self.head = self.first
                        end

                        if slot.isVisible then
                            self.tail = slot
                        end

                        self.last = slot

                        if self.size > total then
                            BlzFrameSetVisible(self.sliderFrame, true)

                            local max = 1 + math.ceil((self.size - total) / self.columns)

                            BlzFrameSetMinMaxValue(self.sliderFrame, 1, max)
                            self.sliderValue = max
                            BlzFrameSetValue(self.sliderFrame, max)

                            BlzFrameClearAllPoints(self.sliderFrame)

                            if self.detailed == false then
                                BlzFrameSetPoint(self.sliderFrame, FRAMEPOINT_TOPRIGHT, self.base, FRAMEPOINT_TOPRIGHT, -0.03, -0.03)
                            else
                                BlzFrameSetPoint(self.sliderFrame, FRAMEPOINT_TOPRIGHT, self.details.frame, FRAMEPOINT_TOPLEFT, -0.02, -0.03)
                            end
                        else
                            BlzFrameSetVisible(self.sliderFrame, false)
                        end
                    else
                        slot:visible(false)
                    end
                slot = slot.next ---@type ShopSlot
            end
        end

        ---@param i ShopItem
        ---@param p player
        function thistype:select(i, p)
            local pid = GetPlayerId(p) + 1

            if i ~= 0 and GetLocalPlayer() == p then
                if self.lastClicked[pid] then
                    self.lastClicked[pid]:display(nil, 0, 0, 0, nil, nil, 0, 0)
                end

                if registry[self][i.id] then
                    self.lastClicked[pid] = registry[self][i.id].button
                    self.lastClicked[pid]:display(ITEM_HIGHLIGHT, HIGHLIGHT_WIDTH, HIGHLIGHT_HEIGHT, HIGHLIGHT_SCALE, FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMLEFT, HIGHLIGHT_XOFFSET, HIGHLIGHT_YOFFSET)
                end
            end
        end

        ---@param i ShopItem
        ---@param p player
        function thistype:detail(i, p)
            if i ~= 0 then
                if GetLocalPlayer() == p then
                    self.rows = DETAILED_ROWS
                    self.columns = DETAILED_COLUMNS

                    if not self.detailed then
                        self.detailed = true
                        self:filter(self.category.active, self.category.andLogic)
                    end
                end

                self:select(i, p)
                self.details:show(i, p)
            else
                if GetLocalPlayer() == p then
                    self.rows = ROWS
                    self.columns = COLUMNS
                    self.detailed  = false
                    self.details:visible(false)
                    self:filter(self.category.active, self.category.andLogic)
                end
            end
        end

        ---@type fun(self: Shop, id: integer): boolean
        function thistype:has(id)
            return registry[self][id] ~= nil
        end

        ---@type fun(source: string, target: string):boolean
        function thistype.find(source, target)
            return source:find(target, 1, true) ~= nil
        end

        ---@type fun(id: integer, icon: string, description: string):integer
        function thistype.addCategory(id, icon, description)
            local self = registry[id][0] ---@type Shop

            if self then
                return self.category:add(icon, description)
            end

            return 0
        end

        ---@type fun(id: integer, itemId: integer, categories: integer)
        function thistype.addItem(id, itemId, categories)
            local self = registry[id][0] ---@type Shop
            local slot ---@type ShopSlot 

            if self then
                itemId = GetItem(itemId)
                if not registry[self][itemId] then
                    local itm = ShopItem.create(itemId, categories) ---@type ShopItem

                    if itm ~= 0 then
                        self.size = self.size + 1
                        self.index = self.index + 1
                        slot = ShopSlot.create(self, itm, R2I(self.index//COLUMNS), ModuloInteger(self.index, COLUMNS))
                        slot:visible(slot.row >= 0 and slot.row <= ROWS - 1 and slot.column >= 0 and slot.column <= COLUMNS - 1)
                        self.stock[itemId] = -1

                        if self.index > 0 then
                            slot.prev = self.last
                            slot.left = self.last
                            self.last.next = slot
                            self.last.right = slot
                        else
                            self.first = slot
                            self.head = slot
                        end

                        if slot.isVisible then
                            self.tail = slot
                        end

                        self.last = slot
                        registry[self][itemId] = slot

                        shoppool[self][self.index] = slot

                        local total = COLUMNS * ROWS

                        if self.size > total then
                            BlzFrameSetVisible(self.sliderFrame, true)

                            local max = 1 + math.ceil((self.size - total) / COLUMNS)

                            BlzFrameSetMinMaxValue(self.sliderFrame, 1, max)
                            self.sliderValue = max
                            BlzFrameSetValue(self.sliderFrame, max)
                        end
                    else
                        print("Invalid item code: " .. string.pack(">I4", itemId))
                    end
                else
                    print("The item " .. itemId .. " is already registered for the shop " .. GetObjectName(id))
                end
            end
        end

        ---@type fun(id: integer, aoe: number): Shop
        function thistype.create(id, aoe)
            local self
            local u = User.first ---@type User 

            if not registry[id][0] then
                self = setmetatable({}, mt)
                self.id = id
                self.aoe = aoe
                self.first = 0
                self.last = 0
                self.head = 0
                self.tail = 0
                self.size = 0
                self.index = -1
                self.rows = ROWS
                self.columns = COLUMNS
                self.count = self.count + 1
                self.detailed = false
                self.base = BlzCreateFrame("EscMenuBackdrop", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
                self.main = BlzCreateFrameByType("BUTTON", "", self.base, "", 0)
                self.edit = BlzCreateFrame("EscMenuEditBoxTemplate", self.main, 0, 0)
                self.leftPanel = BlzCreateFrame("EscMenuBackdrop", self.main, 0, 0)
                self.sliderFrame = BlzCreateFrameByType("SLIDER", "", self.main, "QuestMainListScrollBar", 0)
                self.sliderValue = 0
                self.category = Category.create(self)
                self.details = Detail.create(self)
                self.close = Button.create(self.main, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE, (WIDTH - 2*TOOLBAR_BUTTON_SIZE), 0.015000, true)
                self.close:icon(CLOSE_ICON)
                self.close:onClick(thistype.onClose)
                self.close.tooltip:text("Close 'ESC'")
                self.clearCategory = Button.create(self.leftPanel, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE, 0.028000, 0.015000, true)
                self.clearCategory:icon(CLEAR_ICON)
                self.clearCategory:onClick(thistype.onClear)
                self.clearCategory.tooltip:text("Clear Category")
                self.logic = Button.create(self.leftPanel, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE, 0.049000, 0.015000, true)
                self.logic:icon(LOGIC_ICON)
                self.logic:onClick(thistype.onLogic)
                self.logic:enabled(false)
                self.logic.tooltip:text("AND Logic")
                self.levelreqButton = Button.create(self.leftPanel, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE, 0.221, 0.015000, true)
                self.levelreqButton:icon(SORT_LEVEL_ICON)
                self.levelreqButton:onClick(thistype.onSortLevel)
                self.levelreqButton:enabled(false)
                self.levelreqButton.tooltip:text("Showing items of all levels")
                self.levelsort = false
                self.craftableButton = Button.create(self.leftPanel, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE, 0.242, 0.015000, true)
                self.craftableButton:icon(SORT_CRAFTABLE_ICON)
                self.craftableButton:onClick(thistype.onCraftableSort)
                self.craftableButton:enabled(false)
                self.craftableButton.tooltip:text("Showing uncraftable items")
                self.craftablesort = false
                self.lastClicked = {}
                self.stock = {}
                registry[id][0] = self
                registry[(self.main)][0] = self
                registry[(self.sliderFrame)][0] = self
                registry[(self.close.frame)][0] = self
                registry[(self.clearCategory.frame)][0] = self
                registry[(self.logic.frame)][0] = self
                registry[(self.levelreqButton.frame)][0] = self
                registry[(self.craftableButton.frame)][0] = self
                registry[(self.edit)][0] = self

                while u do
                        thistype.timer[u.id] = CreateTimer()
                        thistype.canScroll[u.id] = true
                        registry[(u.player)][id] = self
                        registry[(u.player)][self.count] = id
                    u = u.next
                end

                BlzFrameSetAbsPoint(self.base, FRAMEPOINT_TOPLEFT, X, Y)
                BlzFrameSetSize(self.base, WIDTH, HEIGHT)
                BlzFrameSetPoint(self.main, FRAMEPOINT_TOPLEFT, self.base, FRAMEPOINT_TOPLEFT, 0.0000, 0.0000)
                BlzFrameSetSize(self.main, WIDTH, HEIGHT)
                BlzFrameSetPoint(self.edit, FRAMEPOINT_TOPLEFT, self.main, FRAMEPOINT_TOPLEFT, 0.021000, 0.020000)
                BlzFrameSetSize(self.edit, EDIT_WIDTH, EDIT_HEIGHT)
                BlzFrameSetPoint(self.leftPanel, FRAMEPOINT_TOPLEFT, self.base, FRAMEPOINT_TOPLEFT, -0.04800, 0.0000)
                BlzFrameSetSize(self.leftPanel, SIDE_WIDTH, SIDE_HEIGHT)
                self.trigger = CreateTrigger()
                BlzTriggerRegisterFrameEvent(self.trigger, self.main, FRAMEEVENT_MOUSE_WHEEL)
                TriggerAddCondition(self.trigger, Condition(thistype.onScrolled))
                BlzTriggerRegisterFrameEvent(self.search, self.edit, FRAMEEVENT_EDITBOX_TEXT_CHANGED)

                BlzFrameClearAllPoints(self.sliderFrame)
                BlzFrameSetSize(self.sliderFrame, 0.012, HEIGHT - 0.065)
                BlzFrameSetMinMaxValue(self.sliderFrame, 1, 2)
                BlzFrameSetStepSize(self.sliderFrame, 1)
                BlzFrameSetPoint(self.sliderFrame, FRAMEPOINT_TOPRIGHT, self.base, FRAMEPOINT_TOPRIGHT, -0.03, -0.03)
                BlzFrameSetVisible(self.sliderFrame, false)
                self.sliderTrigger = CreateTrigger()
                BlzTriggerRegisterFrameEvent(self.sliderTrigger, self.sliderFrame, FRAMEEVENT_SLIDER_VALUE_CHANGED)
                TriggerAddCondition(self.sliderTrigger, Condition(thistype.onSlider))

                self:visible(false)
            end

            return self
        end

        function thistype.onSlider()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    local newvalue = BlzFrameGetValue(BlzGetTriggerFrame())
                    local diff = self.sliderValue - newvalue
                    local count = math.abs(diff)

                    for _ = 1, count do
                        self:scroll(diff > 0)
                    end
                end
            end

            return false
        end

        function thistype.onScrolled() --shop
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                BlzFrameSetEnable(BlzGetTriggerFrame(), false)
                BlzFrameSetEnable(BlzGetTriggerFrame(), true)

                if GetLocalPlayer() == GetTriggerPlayer() then
                    local down = BlzGetTriggerFrameValue() < 0

                    self:scroll(down)
                end
            end

            return false
        end

        function thistype.refresh(pid)
            local self = registry[GetUnitTypeId(thistype.current[pid])][0] ---@type Shop

            if self then
                local slot = self.first
                while slot do
                    slot:refresh(pid)
                    slot = slot.next
                end
                self.details:refresh(pid)
            end

            return false
        end

        function thistype.onSearch()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    self:filter(self.category.active, self.category.andLogic)
                end
            end
        end

        function thistype.onCraftableSort()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    self.craftableButton:enabled(not self.craftableButton.isEnabled)
                    self.craftablesort = not self.craftablesort

                    if self.craftablesort then
                        self.craftableButton.tooltip:text("Hiding uncraftable items")
                    else
                        self.craftableButton.tooltip:text("Showing uncraftable items")
                    end

                    self:filter(self.category.active, self.category.andLogic)
                end

                BlzFrameSetEnable(self.craftableButton.frame, false)
                BlzFrameSetEnable(self.craftableButton.frame, true)
            end
        end

        function thistype.onSortLevel()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    self.levelreqButton:enabled(not self.levelreqButton.isEnabled)
                    self.levelsort = not self.levelsort

                    if self.levelsort then
                        self.levelreqButton.tooltip:text("Hiding too high level items")
                    else
                        self.levelreqButton.tooltip:text("Showing items of all levels")
                    end

                    self:filter(self.category.active, self.category.andLogic)
                end

                BlzFrameSetEnable(self.levelreqButton.frame, false)
                BlzFrameSetEnable(self.levelreqButton.frame, true)
            end
        end

        function thistype.onLogic()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    self.logic:enabled(not self.logic.isEnabled)
                    self.category.andLogic = not self.category.andLogic

                    if self.category.andLogic then
                        self.logic.tooltip:text("AND Logic")
                    else
                        self.logic.tooltip:text("OR Logic")
                    end

                    self:filter(self.category.active, self.category.andLogic)
                end

                BlzFrameSetEnable(self.logic.frame, false)
                BlzFrameSetEnable(self.logic.frame, true)
            end
        end

        function thistype.onClear()
            local frame = BlzGetTriggerFrame() ---@type framehandle 
            local self = registry[(frame)][0] ---@type Shop

            if self then
                if frame == self.clearCategory.frame then
                    if GetLocalPlayer() == GetTriggerPlayer() then
                        self.category:clear()
                    end
                end

                BlzFrameSetEnable(frame, false)
                BlzFrameSetEnable(frame, true)
            end
        end

        function thistype.onClose()
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1 ---@type integer 

            if self then
                if GetLocalPlayer() == p then
                    self:visible(false)
                end

                self.current[pid] = nil
            end
        end

        function thistype.onExpire()
            thistype.canScroll[GetPlayerId(GetLocalPlayer()) + 1] = true
        end

        function thistype.onScroll() --shop
            local self = registry[(BlzGetTriggerFrame())][0] ---@type Shop
            local pid = GetPlayerId(GetLocalPlayer()) + 1

            if self then
                if GetLocalPlayer() == GetTriggerPlayer() then
                    if thistype.canScroll[pid] then
                        if SCROLL_DELAY > 0 then
                            thistype.canScroll[pid] = false
                        end

                        self:scroll(BlzGetTriggerFrameValue() < 0)
                    end
                end
            end

            if SCROLL_DELAY > 0 then
                TimerStart(thistype.timer[pid], SCROLL_DELAY, false, thistype.onExpire)
            end
        end

        function thistype.onSelect()
            local self = registry[GetUnitTypeId(GetTriggerUnit())][0] ---@type Shop

            if self then
                local p = GetTriggerPlayer()
                local pid = GetPlayerId(p) + 1 ---@type integer 
                local selected = GetTriggerEventId() == EVENT_PLAYER_UNIT_SELECTED

                -- Commit the active shop before visible() refreshes the detail UI.
                -- Otherwise the affordability check sees a nil current shop and
                -- leaves the purchase icon in its disabled state.
                self.current[pid] = selected and GetTriggerUnit() or nil

                if GetLocalPlayer() == p then
                    self:visible(selected)
                end
            end
        end

        function Shop.onEsc(pid)
            if registry[GetUnitTypeId(thistype.current[pid])] then
                local self = registry[GetUnitTypeId(thistype.current[pid])][0]; ---@type Shop

                if self then
                    if GetLocalPlayer() == Player(pid - 1) then
                        self:visible(false)
                    end

                    self.current[pid] = nil
                end
            end
        end
        AddToEsc(Shop.onEsc) -- close window hotkey reference

        local id

        thistype.success = CreateSound(SUCCESS_SOUND, false, false, false, 10, 10, "")
        SetSoundDuration(thistype.success, 1600)
        thistype.error = CreateSound(ERROR_SOUND, false, false, false, 10, 10, "")
        SetSoundDuration(thistype.error, 614)
        id = (RACE_HUMAN)
        thistype.noGold[id] = CreateSound("Sound\\Interface\\Warning\\Human\\KnightNoGold1.wav", false, false, false, 10, 10, "")
        SetSoundParamsFromLabel(thistype.noGold[id], "NoGoldHuman")
        SetSoundDuration(thistype.noGold[id], 1618)
        id = (RACE_ORC)
        thistype.noGold[id] = CreateSound("Sound\\Interface\\Warning\\Orc\\GruntNoGold1.wav", false, false, false, 10, 10, "")
        SetSoundParamsFromLabel(thistype.noGold[id], "NoGoldOrc")
        SetSoundDuration(thistype.noGold[id], 1450)
        id = (RACE_NIGHTELF)
        thistype.noGold[id] = CreateSound("Sound\\Interface\\Warning\\NightElf\\SentinelNoGold1.wav", false, false, false, 10, 10, "")
        SetSoundParamsFromLabel(thistype.noGold[id], "NoGoldNightElf")
        SetSoundDuration(thistype.noGold[id], 1229)
        id = (RACE_UNDEAD)
        thistype.noGold[id] = CreateSound("Sound\\Interface\\Warning\\Undead\\NecromancerNoGold1.wav", false, false, false, 10, 10, "")
        SetSoundParamsFromLabel(thistype.noGold[id], "NoGoldUndead")
        SetSoundDuration(thistype.noGold[id], 2005)
        id = (ConvertRace(11))
        thistype.noGold[id] = CreateSound("Sound\\Interface\\Warning\\Naga\\NagaNoGold1.wav", false, false, false, 10, 10, "")
        SetSoundParamsFromLabel(thistype.noGold[id], "NoGoldNaga")
        SetSoundDuration(thistype.noGold[id], 2690)

        TriggerAddAction(thistype.trigger, thistype.onScroll)
        TriggerAddCondition(thistype.search, Condition(thistype.onSearch))
        RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SELECTED, thistype.onSelect)
        RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DESELECTED, thistype.onSelect)
    end

    RegisterItemChangedAction(Shop.refresh)

end, Debug and Debug.getLine())
