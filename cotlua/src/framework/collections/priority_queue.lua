OnInit.global("PriorityQueue", function()

    ---@class PriorityQueue
    ---@field create function
    ---@field push function
    ---@field pop function
    ---@field clear function
    ---@field isEmpty function
    PriorityQueue = {}
    do
        local thistype = PriorityQueue
        thistype.__index = thistype

        function thistype.create()
            local self = setmetatable({}, thistype)
            self.heap = {}
            self.currentSize = 0
            return self
        end

        function thistype:push(value, priority)
            local node = {value = value, priority = priority}
            self.currentSize = self.currentSize + 1
            local i = self.currentSize
            self.heap[i] = node
            while i > 1 do
                local parentIndex = math.floor(i / 2)
                if self.heap[parentIndex].priority <= priority then
                    break
                end
                self.heap[i] = self.heap[parentIndex]
                self.heap[parentIndex] = node
                i = parentIndex
            end
        end

        function thistype:pop()
            local minNode = self.heap[1]
            local lastNode = self.heap[self.currentSize]
            self.currentSize = self.currentSize - 1
            local i = 1
            while true do
                local childIndex = 2 * i
                if childIndex > self.currentSize then
                    break
                end
                if childIndex + 1 <= self.currentSize and self.heap[childIndex + 1].priority < self.heap[childIndex].priority then
                    childIndex = childIndex + 1
                end
                if lastNode.priority <= self.heap[childIndex].priority then
                    break
                end
                self.heap[i] = self.heap[childIndex]
                i = childIndex
            end
            self.heap[i] = lastNode
            return minNode.value
        end

        function thistype:isEmpty()
            return self.currentSize == 0
        end

        function thistype:clear()
            self.heap = {}
            self.currentSize = 0
        end
    end
end, Debug and Debug.getLine())
