--[[
    shield.lua

    A library for applying stackable shields to units with visual effects and individual expiration timers
]]

OnInit.global("Shield", function(Require)
    local FPS_64 = FPS_32 * 0.5
    local TQ = TimerQueue

    ---@class shieldtimer
    ---@field shield Shield
    ---@field amount number
    ---@field create function
    ---@field destroy function
    ---@field queue TimerQueue
    local shieldtimer = {}
    do
        local thistype = shieldtimer
        local mt = { __index = thistype }

        function thistype:destroy()
            TQ:disableCallback(self.queue)
            TableRemove(self.shield.timers, self)
            setmetatable(self, nil)
        end

        ---@type fun(self: shieldtimer)
        local function expire(self)
            self.shield.max = self.shield.max - self.amount
            self.shield.hp = self.shield.hp - self.amount

            -- remove self before removing shield object
            self:destroy()

            if self.shield.hp <= 0 then
                self.shield:destroy()
            else
                self.shield:refresh()
            end
        end

        -- timer op associated with one shield instance
        function thistype.create(shield, amount, dur)
            local self = {}

            setmetatable(self, mt)

            self.shield = shield
            self.amount = amount
            self.queue = TQ:callDelayed(dur, expire, self)

            return self
        end

    end

    ---@class Shield
    ---@field refresh function
    ---@field sfx effect
    ---@field max number
    ---@field queue integer
    ---@field target unit
    ---@field add function
    ---@field create function
    ---@field destroy function
    ---@field color function
    ---@field c integer
    ---@field r integer
    ---@field g integer
    ---@field b integer
    ---@field addTimer function
    ---@field timers shieldtimer[]
    ---@field shieldheight number[]
    ---@field list Shield[]
    Shield = {}
    do
        local thistype = Shield
        local mt = { __index = thistype }

        thistype.list = {}
        -- class specific heights for shield visual
        thistype.shieldheight = {
            HERO_ELEMENTALIST = 200,
            HERO_MARKSMAN = 220,
            HERO_ROYAL_GUARDIAN = 230,
            HERO_MASTER_ROGUE = 230,
            HERO_ASSASSIN = 230,
            HERO_DARK_SUMMONER = 230,
            HERO_THUNDERBLADE = 240,
            HERO_HIGH_PRIEST = 240,
            HERO_VAMPIRE = 240,
            HERO_OBLIVION_GUARD = 275
        }

        -- shieldheight default value
        __jarray(250, thistype.shieldheight)

        function thistype:color(c)
            self.c = c
            self.r = OriginalRGB[c].r
            self.g = OriginalRGB[c].g
            self.b = OriginalRGB[c].b
            BlzSetSpecialEffectColorByPlayer(self.sfx, Player(c))
        end

        function thistype:refresh()
            BlzSetSpecialEffectTime(self.sfx, self.hp / self.max)
        end

        ---@type fun(self: Shield, dmg: number, source: unit): number
        function thistype:damage(dmg, source)
            local angle = math.atan(GetUnitY(source) - GetUnitY(self.target), GetUnitX(source) - GetUnitX(self.target)) ---@type number 
            local x     = GetUnitX(self.target) + 80. * math.cos(angle) ---@type number 
            local y     = GetUnitY(self.target) + 80. * math.sin(angle) ---@type number 
            local e     = AddSpecialEffect("war3mapImported\\BoneArmorCasterTC.mdx", x, y) ---@type effect 

            BlzSetSpecialEffectZ(e, BlzGetUnitZ(self.target) + 90.)
            BlzSetSpecialEffectColorByPlayer(e, Player(self.c))
            BlzSetSpecialEffectYaw(e, angle)
            BlzSetSpecialEffectScale(e, 0.85)
            BlzSetSpecialEffectTimeScale(e, 3.5)

            DestroyEffect(e)

            self.hp = self.hp - dmg

            if self.hp <= 0. then
                self:destroy()
                return -self.hp
            else
                self:refresh()
                return 0.00
            end
        end

        local function update()
            local u = GetMainSelectedUnit() ---@type unit 

            if thistype[u] then
                BlzFrameSetVisible(SHIELD_BACKDROP, true)

                if thistype[u].max >= 100000 then
                    BlzFrameSetText(SHIELD_TEXT, "|cff22ddff" .. R2I(thistype[u].hp))
                else
                    BlzFrameSetText(SHIELD_TEXT, "|cff22ddff" .. R2I(thistype[u].hp) .. " / " .. R2I(thistype[u].max))
                end
            else
                BlzFrameSetVisible(SHIELD_BACKDROP, false)
            end

            -- move shield visual positions
            for i = 1, #thistype.list do
                local s = thistype.list[i]
                if UnitAlive(s.target) then
                    BlzSetSpecialEffectX(s.sfx, GetUnitX(s.target))
                    BlzSetSpecialEffectY(s.sfx, GetUnitY(s.target))
                    BlzSetSpecialEffectZ(s.sfx, BlzGetUnitZ(s.target) + thistype.shieldheight[GetUnitTypeId(s.target)])
                else
                    s:destroy()
                end
            end

            thistype.queue = TQ:callDelayed(FPS_64, update)
        end

        local function onStruck(target, source, amount, amount_after_red)
            amount.color = {thistype[target].r, thistype[target].g, thistype[target].b}
            amount.value = thistype[target]:damage(amount_after_red, source)
        end

        -- shield fully expires
        function thistype:onDestroy()
            BlzSetSpecialEffectAlpha(self.sfx, 0)
            DestroyEffect(self.sfx)

            -- destroy all active shieldtimers
            for _, v in ipairs(self.timers) do
                v:destroy()
            end

            TableRemove(thistype.list, self)

            if #thistype.list == 0 then
                BlzFrameSetVisible(SHIELD_BACKDROP, false)
                TQ:disableCallback(thistype.queue)
            end

            EVENT_ON_SHIELD_EXPIRE:trigger(self.target)
            EVENT_ON_STRUCK_AFTER_REDUCTIONS:unregister_unit_action(self.target, onStruck)
        end

        function thistype:destroy()
            self:onDestroy()
            thistype[self.target] = nil
            setmetatable(self, nil)
        end

        ---@type fun(self: Shield, amount: number, dur: number)
        function thistype:addTimer(amount, dur)
            local timer = shieldtimer.create(self, amount, dur)

            self.timers[#self.timers + 1] = timer
        end

        ---@type fun(u: unit, amount: number, dur: number): Shield
        function Shield.add(u, amount, dur)
            local self = Shield[u] ---@type Shield

            -- shield already exists
            if self then
                self.max = self.max + amount
                self.hp = self.hp + amount

                self:refresh()
            -- make a new one
            else
                self = thistype.create(u, amount, dur)
                EVENT_ON_STRUCK_AFTER_REDUCTIONS:register_unit_action(u, onStruck)
            end

            EVENT_ON_SHIELD_APPLY:trigger(u, amount, dur)

            self:addTimer(amount, dur)

            return self
        end

        ---@type fun(u: unit, amount: number, dur: number):Shield
        function thistype.create(u, amount, dur)
            ---@diagnostic disable-next-line: missing-fields
            local self = setmetatable({}, mt) ---@type Shield

            -- setup
            self.max = amount
            self.hp = amount
            self.target = u
            self.sfx = AddSpecialEffect("war3mapImported\\HPbar.mdx", GetUnitX(u), GetUnitY(u))
            self.timers = {}
            self:color(2)
            BlzSetSpecialEffectTime(self.sfx, 1.)
            BlzSetSpecialEffectTimeScale(self.sfx, 0.)
            BlzSetSpecialEffectScale(self.sfx, 1.6)

            thistype[u] = self
            thistype.list[#thistype.list + 1] = self

            if #thistype.list == 1 then
                update()
            end

            return self
        end
    end
end, Debug and Debug.getLine())
