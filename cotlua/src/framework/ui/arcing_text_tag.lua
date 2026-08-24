OnInit.global("ArcingTextTag", function(Require)

    Require('TimerQueue')

    local SIZE_MIN                = 0.009          ---@type number -- Minimum size of text
    local SIZE_BONUS              = 0.006          ---@type number -- Text size increase
    local TIME_LIFE               = 0.9            ---@type number -- How long the text lasts
    local TIME_FADE               = 0.7            ---@type number -- When does the text start to fade
    local Z_OFFSET                = 100             ---@type number -- Height above unit
    local Z_OFFSET_BON            = 75             ---@type number -- How much extra height the text gains
    local VELOCITY                = 2.75              ---@type number -- How fast the text move in x/y plane
    local MAX_PER_TICK            = 4 ---@type integer 
    local count                   = 0 ---@type integer 
    local instances               = {}

    ---@class ArcingTextTag
    ---@field create function
    ArcingTextTag = {}
    do
        local thistype = ArcingTextTag

        local move_text_tag = SetTextTagPos
        local set_text_tag_text = SetTextTagText
        local min, max, sin, cos, random = math.min, math.max, math.sin, math.cos, math.random
        local FPS_32 = FPS_32
        local TQ = TimerQueue

        local function condition()
            return #instances == 0
        end

        local function update()
            local i = 1
            count = 0

            while i <= #instances do
                local self = instances[i]
                local p = sin(bj_PI * (self.time / self.timeScale))
                self.time = self.time - FPS_32
                self.x = self.x + self.ac
                self.y = self.y + self.as
                move_text_tag(self.tt, self.x, self.y, Z_OFFSET + Z_OFFSET_BON * p)
                set_text_tag_text(self.tt, self.text, (SIZE_MIN + SIZE_BONUS * p) * self.scale)

                if self.time <= 0 then
                    instances[i] = instances[#instances]
                    instances[#instances] = nil
                else
                    i = i + 1
                end
            end
        end

        ---@type fun(text: string|number, u: unit, duration: number, size: number, r: integer, g: integer, b: integer, alpha: integer): ArcingTextTag?
        function thistype.create(text, u, duration, size, r, g, b, alpha)
            count = count + 1

            if count > MAX_PER_TICK then
                return
            end

            if type(text) == "number" then
                local hp = text / BlzGetUnitMaxHP(u)
                size = size + min(hp * 2., 2.)
                duration = duration + min(hp, 1.25)
                text = RealToString(text)
            end

            local a = random() * 2 * bj_PI
            ---@diagnostic disable-next-line: missing-fields
            local self = { ---@type ArcingTextTag
                scale = size,
                timeScale = max(duration, 0.001),
                text = text,
                x = GetUnitX(u),
                y = GetUnitY(u),
                time = TIME_LIFE,
                as = sin(a) * VELOCITY,
                ac = cos(a) * VELOCITY,
            }

            local pid = GetPlayerId(GetLocalPlayer()) + 1 ---@type integer 

            if DMG_NUMBERS[pid] == 0 or (DMG_NUMBERS[pid] == 1 and not IsUnitAlly(u, GetLocalPlayer())) then
                self.tt = CreateTextTag()
                SetTextTagPermanent(self.tt, false)
                SetTextTagColor(self.tt, r, g, b, 255 - alpha)
                SetTextTagLifespan(self.tt, TIME_LIFE * duration)
                SetTextTagFadepoint(self.tt, TIME_FADE * duration)
                SetTextTagText(self.tt, text, SIZE_MIN * size)
                SetTextTagPos(self.tt, self.x, self.y, Z_OFFSET)
            end

            instances[#instances + 1] = self

            if #instances == 1 then
                TQ:callPeriodically(FPS_32, condition, update)
            end

            return self
        end
    end
end, Debug and Debug.getLine())
