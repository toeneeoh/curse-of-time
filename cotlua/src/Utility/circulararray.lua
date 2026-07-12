OnInit.global("CircularArray", function()

    local fmod = math.fmod

    ---@class CircularArrayList
    ---@field iterator function
    ---@field data table
    ---@field add function
    ---@field add_timed function
    ---@field count integer
    ---@field START integer
    ---@field END integer
    ---@field MAXSIZE integer
    ---@field create function
    ---@field destroy function
    ---@field wipe function
    CircularArrayList = {}
    do
        local thistype = CircularArrayList
        local mt = { __index = thistype }

        function thistype:iterator()
            local index = self.START
            local count = 0

            return function()
                if count < self.count then
                    local value = self.data[index]
                    index = fmod(index + 1, self.MAXSIZE)
                    count = count + 1
                    return value
                end
            end
        end

        ---@type fun(size: integer): CircularArrayList
        function thistype.create(size)
            local self = {
                data = {},
                count = 0,
                START = 1,
                END = 1,
                MAXSIZE = size or 200
            }

            setmetatable(self, mt)
            return self
        end

        ---@param value any
        function thistype:add(value)
            self.data[self.END] = value
            self.END = fmod((self.END + 1), self.MAXSIZE)

            if self.count < self.MAXSIZE then
                self.count = self.count + 1
            else
                -- Free up the last slot
                self.START = fmod((self.START + 1), self.MAXSIZE)
            end
        end

        local function remove(self)
            if self.count > 0 then
                self.START = fmod((self.START + 1), self.MAXSIZE)
                self.count = self.count - 1
            end
        end

        ---@param value any
        ---@param time number
        function thistype:add_timed(value, time)
            self:add(value)

            TQ:callDelayed(time, remove, self)
        end

        function thistype:wipe()
            self.data = {}
            self.count = 0
            self.START = 1
            self.END = 1
        end
    end
end, Debug and Debug.getLine())
