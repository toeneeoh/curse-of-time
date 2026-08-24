--[[ 
    chain.lua 
    
    A graphics library that introduces chain physics between two units/sfx (anchors) with customizable texture / length / segments / etc.
    Features leash and yank functionality to restrain and pull the target towards the source

--]]

OnInit.global("Chain", function(Require)
    Require('TimerQueue')

    ---@class Chain
    ---@field source unit
    ---@field target unit
    ---@field source_height number
    ---@field target_height number
    ---@field length number
    ---@field segments integer
    ---@field texture string
    ---@field gravity number
    ---@field friction number
    ---@field stiffness number
    ---@field ground_collision boolean
    ---@field leash boolean
    ---@field max_speed number
    ---@field straighten number
    ---@field straighten_start number
    ---@field lightning lightning[]
    ---@field yank function
    Chain = {}
    Chain.__index = Chain

    local function dist3(dx, dy, dz)
        return SquareRoot(dx * dx + dy * dy + dz * dz)
    end

    function Chain.unit(u, height)
        return {
            type = "unit",
            handle = u,
            height = height or 0.,
        }
    end

    function Chain.sfx(sfx, height)
        return {
            type = "sfx",
            handle = sfx,
            height = height or 0.,
        }
    end

    local function anchor_pos(anchor, fallback_height)
        if anchor.type == "unit" then
            local u = anchor.handle
            local x = GetUnitX(u)
            local y = GetUnitY(u)

            return x, y, GetUnitZ(u) + (anchor.height or fallback_height or 0.)
        end

        if anchor.type == "sfx" then
            local sfx = anchor.handle
            local x = BlzGetLocalSpecialEffectX(sfx)
            local y = BlzGetLocalSpecialEffectY(sfx)

            return x, y, GetLocZ(x, y) + (anchor.height or fallback_height or 0.)
        end

        -- backwards compat: raw unit
        local x = GetUnitX(anchor)
        local y = GetUnitY(anchor)

        return x, y, GetUnitZ(anchor) + (fallback_height or 0.)
    end

    local function anchor_alive(anchor)
        if anchor.type == "unit" then
            return UnitAlive(anchor.handle)
        end

        if anchor.type == "sfx" then
            return anchor.handle ~= nil
        end

        -- backwards compat raw unit
        return UnitAlive(anchor)
    end

    local function anchor_unit(anchor)
        if anchor.type == "unit" then
            return anchor.handle
        end

        if anchor.type == nil then
            return anchor -- backwards compat
        end

        return nil
    end

    -- initialize segments evenly between both anchors
    function Chain:init()
        local sx, sy, sz = anchor_pos(self.source, self.source_height)
        local tx, ty, tz = anchor_pos(self.target, self.target_height)

        for i = 0, self.segments do
            local t = i / self.segments

            self.x[i] = sx + (tx - sx) * t
            self.y[i] = sy + (ty - sy) * t
            self.z[i] = sz + (tz - sz) * t

            self.vx[i] = 0.
            self.vy[i] = 0.
            self.vz[i] = 0.
        end

        for i = 0, self.segments - 1 do
            self.lightning[i] = AddLightningEx(self.texture, true, self.x[i], self.y[i], self.z[i], self.x[i + 1], self.y[i + 1], self.z[i + 1] )
            SetLightningColor(self.lightning[i], self.r, self.g, self.b, self.a)
        end
    end

    function Chain.create(opts)
        local self = setmetatable({}, Chain)

        self.source = opts.source
        self.target = opts.target

        self.source_height = opts.source_height or 120.
        self.target_height = opts.target_height or 80.

        self.length = opts.length or 900.
        self.segments = opts.segments or 6
        self.texture = opts.texture or "CHAI"

        self.gravity = opts.gravity or 1.
        self.friction = opts.friction or 0.45
        self.stiffness = opts.stiffness or 0.25

        self.ground_collision = opts.ground_collision ~= false
        self.leash = opts.leash ~= false
        self.max_speed = opts.max_speed or 28.

        self.straighten = opts.straighten or 0.14
        self.straighten_start = opts.straighten_start or 0.9

        self.yanking = false
        self.yank_time = 0.
        self.yank_duration = 0.
        self.yank_intensity = 0.
        self.yank_old_leash = false
        self.yank_old_friction = self.friction
        self.yank_old_straighten = self.straighten

        local color = opts.color or {1., 1., 1., 1.}
        self.r = color[1]
        self.g = color[2]
        self.b = color[3]
        self.a = color[4]

        self.x = {}
        self.y = {}
        self.z = {}

        self.vx = {}
        self.vy = {}
        self.vz = {}

        self.fx = {}
        self.fy = {}
        self.fz = {}

        self.lightning = {}

        self:init()

        return self
    end

    function Chain:clear_lightning()
        for i = 0, self.segments - 1 do
            if self.lightning[i] then
                DestroyLightning(self.lightning[i])
                self.lightning[i] = nil
            end
        end
    end

    -- rebuild by resampling the current chain instead of resetting to a straight line.
    function Chain:rebuild()
        local old_segments = self.segments
        local new_segments = self.pending_segments or self.segments

        self.pending_segments = nil

        self:clear_lightning()

        local old_x = self.x
        local old_y = self.y
        local old_z = self.z

        local old_vx = self.vx
        local old_vy = self.vy
        local old_vz = self.vz

        self.segments = new_segments

        self.x = {}
        self.y = {}
        self.z = {}

        self.vx = {}
        self.vy = {}
        self.vz = {}

        for i = 0, new_segments do
            local t = i / new_segments
            local old_pos = t * old_segments
            local a = R2I(old_pos)

            if a >= old_segments then
                a = old_segments - 1
            end

            local b = a + 1
            local f = old_pos - a

            self.x[i] = old_x[a] + (old_x[b] - old_x[a]) * f
            self.y[i] = old_y[a] + (old_y[b] - old_y[a]) * f
            self.z[i] = old_z[a] + (old_z[b] - old_z[a]) * f

            self.vx[i] = old_vx[a] + (old_vx[b] - old_vx[a]) * f
            self.vy[i] = old_vy[a] + (old_vy[b] - old_vy[a]) * f
            self.vz[i] = old_vz[a] + (old_vz[b] - old_vz[a]) * f
        end

        self.fx = {}
        self.fy = {}
        self.fz = {}

        for i = 0, self.segments - 1 do
            self.lightning[i] = AddLightningEx(self.texture, true, self.x[i], self.y[i], self.z[i], self.x[i + 1], self.y[i + 1], self.z[i + 1])
            SetLightningColor(self.lightning[i], self.r, self.g, self.b, self.a)
        end
    end

    function Chain:set_length(length)
        self.length = length
    end

    function Chain:set_segments(segments)
        segments = math.max(1, R2I(segments))

        if segments ~= self.segments then
            self.pending_segments = segments
            self:rebuild()
        end
    end

    function Chain:set_texture(texture)
        if texture ~= self.texture then
            self.texture = texture
            self:rebuild()
        end
    end

    function Chain:set_source(source)
        self.source = source
        self:rebuild()
    end

    function Chain:set_target(target)
        self.target = target
        self:rebuild()
    end

    function Chain:update_anchors()
        self.x[0], self.y[0], self.z[0] = anchor_pos(self.source, self.source_height)
        self.x[self.segments], self.y[self.segments], self.z[self.segments] = anchor_pos(self.target, self.target_height)
    end

    function Chain:yank(length_cut, segment_cut, duration)
        self.yanking = true
        self.yank_time = 0.
        self.yank_duration = duration or 0.25

        self.yank_start_length = self.length
        self.yank_end_length = math.max(100., self.length - length_cut)

        self.yank_start_segments = self.segments
        self.yank_end_segments = math.max(1, self.segments - segment_cut)

        self.yank_old_leash = self.leash
        self.leash = false

        self.yank_start_x = GetUnitX(self.target)
        self.yank_start_y = GetUnitY(self.target)

        local sx = GetUnitX(self.source)
        local sy = GetUnitY(self.source)

        -- direction from target -> source
        local dx = sx - self.yank_start_x
        local dy = sy - self.yank_start_y
        local d = SquareRoot(dx * dx + dy * dy)

        if d > 0.001 then
            dx = dx / d
            dy = dy / d
        else
            dx = 1.
            dy = 0.
        end

        -- only pull enough to satisfy the new shortened leash
        -- don't move if target is already within the new leash length
        local excess = d - self.yank_end_length

        if excess <= 0.001 then
            self.yank_end_x = self.yank_start_x
            self.yank_end_y = self.yank_start_y
            return
        end

        local pull = math.min(length_cut, excess)

        self.yank_end_x = self.yank_start_x + dx * pull
        self.yank_end_y = self.yank_start_y + dy * pull
    end

    function Chain:apply_yank()
        if not self.yanking then
            return
        end

        self.yank_time = self.yank_time + FPS_32

        local t = math.min(self.yank_time / self.yank_duration, 1.)

        -- fast start, softer end
        local smooth = 1. - (1. - t) * (1. - t)

        local x = self.yank_start_x + (self.yank_end_x - self.yank_start_x) * smooth
        local y = self.yank_start_y + (self.yank_end_y - self.yank_start_y) * smooth

        SetUnitX(self.target, x)
        SetUnitY(self.target, y)

        self.length = self.yank_start_length +
            (self.yank_end_length - self.yank_start_length) * smooth

        if t >= 1. then
            self.length = self.yank_end_length
            self:set_segments(self.yank_end_segments)

            self.leash = self.yank_old_leash
            self.yanking = false
        end
    end

    function Chain:apply_leash()
        if not self.leash then
            return
        end

        local target_unit = anchor_unit(self.target)

        if not target_unit then
            return
        end

        local end_index = self.segments

        local dx = self.x[end_index] - self.x[0]
        local dy = self.y[end_index] - self.y[0]
        local d = SquareRoot(dx * dx + dy * dy)

        if d > self.length then
            local nx = dx / d
            local ny = dy / d

            SetUnitX(target_unit, self.x[0] + nx * self.length)
            SetUnitY(target_unit, self.y[0] + ny * self.length)

            self.x[end_index], self.y[end_index], self.z[end_index] = anchor_pos(self.target, self.target_height)
        end
    end

    function Chain:simulate()
        local sub_length = self.length / self.segments

        local ax = self.x[0]
        local ay = self.y[0]
        local az = self.z[0]

        local bx = self.x[self.segments]
        local by = self.y[self.segments]
        local bz = self.z[self.segments]

        local abx = bx - ax
        local aby = by - ay
        local abz = bz - az

        local anchor_dist = dist3(abx, aby, abz)
        local stretch = math.min(anchor_dist / self.length, 1.)

        local straighten_factor = 0.
        local straighten_start = self.straighten_start
        local straighten = self.straighten

        if stretch > straighten_start then
            straighten_factor = ((stretch - straighten_start) / (1. - straighten_start)) * straighten
        end

        for i = 1, self.segments - 1 do
            local fx = 0.
            local fy = 0.
            local fz = -self.gravity

            local dx = self.x[i - 1] - self.x[i]
            local dy = self.y[i - 1] - self.y[i]
            local dz = self.z[i - 1] - self.z[i]
            local d = dist3(dx, dy, dz)

            if d > 0.001 then
                local force = self.stiffness * (1. - sub_length / d)

                fx = fx + force * dx
                fy = fy + force * dy
                fz = fz + force * dz
            end

            dx = self.x[i + 1] - self.x[i]
            dy = self.y[i + 1] - self.y[i]
            dz = self.z[i + 1] - self.z[i]
            d = dist3(dx, dy, dz)

            if d > 0.001 then
                local force = self.stiffness * (1. - sub_length / d)

                fx = fx + force * dx
                fy = fy + force * dy
                fz = fz + force * dz
            end

            if straighten_factor > 0. then
                local t = i / self.segments

                local line_x = ax + abx * t
                local line_y = ay + aby * t
                local line_z = az + abz * t

                fx = fx + (line_x - self.x[i]) * straighten_factor
                fy = fy + (line_y - self.y[i]) * straighten_factor
                fz = fz + (line_z - self.z[i]) * straighten_factor
            end

            self.vx[i] = (self.vx[i] + fx) * (1. - self.friction)
            self.vy[i] = (self.vy[i] + fy) * (1. - self.friction)
            self.vz[i] = (self.vz[i] + fz) * (1. - self.friction)

            local speed = SquareRoot(self.vx[i] * self.vx[i] + self.vy[i] * self.vy[i] + self.vz[i] * self.vz[i])

            if speed > self.max_speed then
                local scale = self.max_speed / speed

                self.vx[i] = self.vx[i] * scale
                self.vy[i] = self.vy[i] * scale
                self.vz[i] = self.vz[i] * scale
            end

            self.x[i] = self.x[i] + self.vx[i]
            self.y[i] = self.y[i] + self.vy[i]
            self.z[i] = self.z[i] + self.vz[i]

            if self.ground_collision then
                local min_z = GetTerrainZ(self.x[i], self.y[i])

                if self.z[i] < min_z then
                    self.z[i] = min_z
                    self.vz[i] = 0.
                end
            end
        end
    end

    -- slightly extend every segment to hide gaps
    local OVERLAP = 3.

    function Chain:render()
        for i = 0, self.segments - 1 do
            local x1, y1, z1 = self.x[i], self.y[i], self.z[i]
            local x2, y2, z2 = self.x[i + 1], self.y[i + 1], self.z[i + 1]

            local dx = x2 - x1
            local dy = y2 - y1
            local dz = z2 - z1
            local d = dist3(dx, dy, dz)

            if d > 0.001 then
                local ox = dx / d * OVERLAP
                local oy = dy / d * OVERLAP
                local oz = dz / d * OVERLAP

                MoveLightningEx(self.lightning[i], true, x1 - ox, y1 - oy, z1 - oz, x2 + ox, y2 + oy, z2 + oz)
            else
                MoveLightningEx(self.lightning[i], true, x1, y1, z1, x2, y2, z2)
            end
        end
    end

    -- main loop
    function Chain:update()
        if not self.source or not self.target then
            self:destroy()
            return false
        end

        if not anchor_alive(self.source) or not anchor_alive(self.target) then
            self:destroy()
            return false
        end

        self:update_anchors()
        self:apply_yank()
        self:apply_leash()
        self:simulate()
        self:render()

        return true
    end

    function Chain:destroy()
        self:clear_lightning()

        self.source = nil
        self.target = nil

        self.x = nil
        self.y = nil
        self.z = nil

        self.vx = nil
        self.vy = nil
        self.vz = nil

        self.fx = nil
        self.fy = nil
        self.fz = nil

        self.lightning = nil
    end

end, Debug and Debug.getLine())
