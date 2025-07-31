--[[
    users.lua

    A module that creates a User interface and a linked structure such that
    player manipulation is simpler.
]]

OnInit.global("Users", function()

    FORCE_PLAYING = CreateForce() ---@type force 
    LEAVE_TRIGGER = CreateTrigger()
    OriginalHex = { ---@type string[] 
        "|cffff0303",
        "|cff0042ff",
        "|cff1ce6b9",
        "|cff540081",
        "|cfffffc01",
        "|cfffe8a0e",
        "|cff20c000",
        "|cffe55bb0",
        "|cff959697",
        "|cff7ebff1",
        "|cff106246",
        "|cff4e2a04",
        "|cff9B0000",
        "|cff0000C3",
        "|cff00EAFF",
        "|cffBE00FE",
        "|cffEBCD87",
        "|cffF8A48B",
        "|cffBFFF80",
        "|cffDCB9EB",
        "|cff282828",
        "|cffEBF0FF",
        "|cff00781E",
        "|cffA46F33",
    }

    OriginalRGB = {}
        OriginalRGB[0] =  { r = 255, g = 3,   b = 3 }
        OriginalRGB[1] =  { r = 0,   g = 66,  b = 255 }
        OriginalRGB[2] =  { r = 28,  g = 230, b = 185 }
        OriginalRGB[3] =  { r = 84,  g = 0,   b = 129 }
        OriginalRGB[4] =  { r = 255, g = 252, b = 0 }
        OriginalRGB[5] =  { r = 254, g = 138, b = 14 }
        OriginalRGB[6] =  { r = 32,  g = 192, b = 0 }
        OriginalRGB[7] =  { r = 229, g = 91,  b = 176 }
        OriginalRGB[8] =  { r = 149, g = 150, b = 151 }
        OriginalRGB[9] =  { r = 126, g = 191, b = 241 }
        OriginalRGB[10] = { r = 16,  g = 98,  b = 70 }
        OriginalRGB[11] = { r = 74,  g = 42,  b = 4 }

    ---@class User
    ---@field player player
    ---@field first User
    ---@field id integer
    ---@field next User
    ---@field prev User
    ---@field color playercolor
    ---@field colorUnits function
    ---@field name string
    ---@field nameColored string
    ---@field onLeave function
    ---@field create function
    ---@field AmountPlaying integer
    User = {}
    do
        local thistype = User
        local mt = { __index = User }
        thistype.first = nil
        thistype.AmountPlaying = 0

        function thistype.create(i)
            local p = Player(i)

            local self = {
                player = p,
                id = i + 1,
                isPlaying = true,
                color = GetPlayerColor(p),
                name = GetPlayerName(p),
                hex = OriginalHex[i + 1],
            }

            self.nameColored = self.hex .. self.name .. "|r"

            thistype[p] = self
            thistype[i] = self
            setmetatable(self, mt)

            thistype.last = self

            if not thistype.first then
                thistype.first = self
                self.next = nil
                self.prev = nil
            else
                self.prev = thistype[thistype.AmountPlaying - 1]
                self.prev.next = self
                self.next = nil
            end

            -- Increment the number of players when a new user is created
            thistype.AmountPlaying = thistype.AmountPlaying + 1

            TriggerRegisterPlayerEvent(LEAVE_TRIGGER, p, EVENT_PLAYER_LEAVE)
            TriggerRegisterPlayerEvent(LEAVE_TRIGGER, p, EVENT_PLAYER_DEFEAT)

            ForceAddPlayer(FORCE_PLAYING, p)
        end

        function thistype:colorUnits()
            local ug = CreateGroup()

            GroupEnumUnitsOfPlayer(ug, self.player, nil)

            local u = FirstOfGroup(ug)
            while u do
                SetUnitColor(u, self.color)
                GroupRemoveUnit(ug, u)
                u = FirstOfGroup(ug)
            end

            DestroyGroup(ug)
        end

        ---@return boolean
        function thistype.onLeave()
            local p = GetTriggerPlayer()

            if BlzForceHasPlayer(FORCE_PLAYING, p) then
                local u = thistype[p]

                ForceRemovePlayer(FORCE_PLAYING, p)

                -- recycle index
                thistype.AmountPlaying = thistype.AmountPlaying - 1

                if (thistype.AmountPlaying == 1) then
                    if u.prev then
                        u.prev.next = nil
                    end
                    if u.next then
                        u.next.prev = nil
                    end
                else
                    if u.prev then
                        u.prev.next = u.next
                    end
                    if u.next then
                        u.next.prev = u.prev
                    end
                end

                u.isPlaying = false
            end

            return false
        end

        for i = 0, bj_MAX_PLAYERS - 1 do
            local p = Player(i)

            if (GetPlayerController(p) == MAP_CONTROL_USER and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING) then
                User.create(i)
            end
        end

        TriggerAddCondition(LEAVE_TRIGGER, Filter(thistype.onLeave))
    end
end, Debug and Debug.getLine())
