OnInit.global("BezierCurve", function()

    ---@class BezierCurve
    ---@field numPoints integer
    ---@field pointX number[]
    ---@field pointY number[]
    ---@field X number
    ---@field Y number
    ---@field addPoint function
    ---@field calcT function
    ---@field create function
    ---@field destroy function
    BezierCurve = {}
    do
        local thistype = BezierCurve
        local mt = { __index = thistype }

        ---@type fun():BezierCurve
        function thistype.create()
            local self = {
                pointX = {},
                pointY = {},
                X = 0.,
                Y = 0.
            }

            setmetatable(self, mt)

            return self
        end

        function thistype:destroy()
            self = nil
        end

        ---@param x number
        ---@param y number
        function thistype:addPoint(x, y)
            self.pointX[#self.pointX + 1] = x
            self.pointY[#self.pointY + 1] = y
        end

        ---@param t number
        function thistype:calcT(t)
            local n       = #self.pointX - 1
            local resultX = 0.
            local resultY = 0.
            local blend   = 0.

            for i = 0, n do
                blend = BinomialCoefficient(n, i) * (t ^ i) * ((1 - t) ^ (n - i))
                resultX = resultX + blend * self.pointX[i + 1]
                resultY = resultY + blend * self.pointY[i + 1]
            end

            self.X = resultX
            self.Y = resultY
        end
    end
end, Debug and Debug.getLine())
