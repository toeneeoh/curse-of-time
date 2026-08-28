OnInit.final("ItemSocketingAbilities", function(Require)
    Require("Spells")

    local SOCKET_ITEM_CHISEL = Spell.define('A00D')
    do
        local thistype = SOCKET_ITEM_CHISEL
        local TYPE_SOCKETABLE = 12
        local TARGET_DIALOG_KIND = "socket_item_target"
        local GEM_DIALOG_KIND = "socket_item_gem"

        ---@param itm Item?
        ---@return boolean
        local function is_socketable(itm)
            return itm ~= nil and itm.type == TYPE_SOCKETABLE and not itm.socketed
        end

        ---@param itm Item?
        ---@param socket_limit integer
        ---@return boolean
        local function is_socket_target(itm, socket_limit)
            return itm ~= nil
                and itm.type ~= TYPE_SOCKETABLE
                and ItemIsUpgradeable(itm)
                and #itm.sockets < socket_limit
        end

        ---@param pid integer
        ---@param socket_limit integer
        ---@return boolean, boolean
        local function get_socket_options(pid, socket_limit)
            local has_target = false
            local has_socketable = false
            local items = Profile[pid].hero.items

            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = items[i]
                has_target = has_target or is_socket_target(itm, socket_limit)
                has_socketable = has_socketable or is_socketable(itm)

                if has_target and has_socketable then
                    break
                end
            end

            return has_target, has_socketable
        end

        local function confirm_socket_item(self, index, socketable)
            if index ~= -1 then
                local to_socket = self.data[200]
                local chisel = self.data[100]
                local socket_limit = self.data[300]

                if chisel
                    and is_socketable(socketable)
                    and is_socket_target(to_socket, socket_limit)
                then
                    if to_socket:socket(socketable) then
                        chisel:destroy()
                    else
                        DisplayTextToPlayer(Player(self.pid - 1), 0., 0., "The socketable item could not be transferred.")
                    end
                else
                    DisplayTextToPlayer(Player(self.pid - 1), 0., 0., "The selected items are no longer valid for socketing.")
                end

                self:destroy()
            end

            return false
        end

        local function choose_socketable(self, index, to_socket)
            if index ~= -1 then
                local pid = self.pid
                local chisel = self.data[100]
                local socket_limit = self.data[300]
                local items = Profile[pid].hero.items

                self:destroy()

                if not is_socket_target(to_socket, socket_limit) then
                    DisplayTextToPlayer(Player(pid - 1), 0., 0., "That item can no longer be socketed.")
                    return false
                end

                local dw = DialogWindow.create(pid, "Choose a socketable item to use", confirm_socket_item, GEM_DIALOG_KIND)

                for i = 1, MAX_INVENTORY_SLOTS do
                    local itm = items[i]

                    if is_socketable(itm) then
                        dw:addButton(GetItemName(itm.obj), itm, BlzGetItemIconPath(itm.obj))
                    end
                end

                if dw.count > 0 then
                    dw.data[100] = chisel
                    dw.data[200] = to_socket
                    dw.data[300] = socket_limit
                    if not dw:display() then
                        dw:destroy()
                    end
                else
                    DisplayTextToPlayer(Player(pid - 1), 0., 0., "You have no socketable items to use.")
                    dw:destroy()
                end
            end

            return false
        end

        ---Shared entry point for chisel variants.
        ---A limit of 1 only accepts unsocketed targets; 3 accepts 0-2 sockets.
        ---@param spell table
        ---@param chisel_id string
        ---@param socket_limit integer
        local function cast_socket_chisel(spell, chisel_id, socket_limit)
            local pid = spell.pid
            local chisel = GetItemFromPlayer(pid, chisel_id)

            if not chisel then
                return
            end

            socket_limit = math.min(socket_limit, MAX_SOCKETS)

            local has_target, has_socketable = get_socket_options(pid, socket_limit)

            if not has_target then
                DisplayTextToPlayer(spell.owner, 0., 0., "You have no items that can receive sockets.")
                return
            elseif not has_socketable then
                DisplayTextToPlayer(spell.owner, 0., 0., "You have no socketable items to use.")
                return
            end

            local dw = DialogWindow.create(pid, "Choose an item to socket", choose_socketable, TARGET_DIALOG_KIND)
            local items = Profile[pid].hero.items

            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = items[i]

                if is_socket_target(itm, socket_limit) then
                    dw:addButton(GetItemName(itm.obj), itm, BlzGetItemIconPath(itm.obj))
                end
            end

            dw.data[100] = chisel
            dw.data[300] = socket_limit
            if not dw:display() then
                dw:destroy()
            end
        end

        function thistype:onCast()
            cast_socket_chisel(self, 'I00K:-1', 1)
        end

        local ADVANCED_SOCKET_ITEM_CHISEL = Spell.define('A01G')
        function ADVANCED_SOCKET_ITEM_CHISEL:onCast()
            cast_socket_chisel(self, 'I00U:-1', 3)
        end
    end
end, Debug and Debug.getLine())
