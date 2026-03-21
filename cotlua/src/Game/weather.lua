--[[
    weather.lua

    A module that defines random weather behavior and effects.
]]

OnInit.global("Weather", function(Require)
    Require('Helper')
    Require('Buffs')

    local CURRENT_WEATHER
    local buff = WeatherBuff
    local WeatherTable = {}
    local WeatherGroup = {}
    local TQ = TimerQueue
    local callback
    local weather_periodic
    local weather_iterations = 0

    function buff:onRemove()
        local tbl = WeatherTable[CURRENT_WEATHER]
        Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.atk * 0.01
        Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as
        Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        Unit[self.target].dr = Unit[self.target].dr / self.dr
        Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms

        if tbl.buff then
            UnitRemoveAbility(self.target, tbl.buff)
        end
    end

    function buff:onApply()
        local tbl = WeatherTable[CURRENT_WEATHER]
        self.as = 1. - (tbl.as or 0) * 0.01
        self.atk = (tbl.atk or 0)
        self.spellboost = (tbl.boost or 0) * 0.01
        self.dr = (1. - (tbl.dr or 0) * 0.01)
        self.ms = (tbl.ms or 0) * 0.01 * (math.min(1, Unit[self.target].ms_percent))

        Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.atk * 0.01
        Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as
        Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        Unit[self.target].dr = Unit[self.target].dr * self.dr
        Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms

        if tbl.buff then
            UnitAddAbility(self.target, tbl.buff)
        end
    end

    local WEATHER_HURRICANE         = 1
    local WEATHER_CHAOTIC_HURRICANE = 2
    local WEATHER_SNOW              = 3
    local WEATHER_CHAOTIC_SNOW      = 4
    local WEATHER_FOG               = 5
    local WEATHER_CHAOTIC_FOG       = 6
    local WEATHER_RAIN              = 7
    local WEATHER_CHAOTIC_RAIN      = 8
    local WEATHER_CLEAR             = 9
    local WEATHER_SUNNY             = 10
    local WEATHER_DIVINE_GRACE      = 11
    local WEATHER_SIPHONING_MIST    = 12
    local WEATHER_FIRESTORM         = 13
    local WEATHER_SOLAR_FLARE       = 14
    local WEATHER_SAND_STORM        = 15

    WeatherTable[WEATHER_HURRICANE] = {
        text = "The winds begin to pick up...",
        name = "Hurricane",
        icon = "ReplaceableTextures\\CommandButtons\\BTNTornado.blp",
        desc = "This unit has -^$ms% movespeed and -^#as% base attack speed",
        dur = 120,
        as = 20,
        ms = 20,
        chance = 5,
        chaos = -1,
        bad = 1,
        fog = 50,
        red = 170,
        green = 170,
        blue = 210,
    }
    WeatherTable[WEATHER_CHAOTIC_HURRICANE] = {
        text = "The winds begin to pick up...",
        name = "Chaotic Hurricane",
        icon = "ReplaceableTextures\\CommandButtons\\BTNChaoticHurricane.blp",
        desc = "This unit has -^$ms% movespeed and -^#as% base attack speed",
        dur = 120,
        as = 25,
        ms = 25,
        chance = 5,
        chaos = 1,
        bad = 1,
        fog = 50,
        red = 255,
        green = 100,
        blue = 100,
    }
    WeatherTable[WEATHER_SNOW] = {
        text = "It is snowing.",
        name = "Snow",
        icon = "ReplaceableTextures\\CommandButtons\\BTNFrostBolt.blp",
        desc = "This unit has -^$ms% movespeed and -^#as% base attack speed",
        dur = 180,
        as = 15,
        ms = 15,
        chance = 20,
        chaos = -1,
        bad = 1,
        fog = 75,
        red = 255,
        green = 255,
        blue = 255,
    }
    WeatherTable[WEATHER_CHAOTIC_SNOW] = {
        text = "It is snowing.",
        name = "Chaotic Snow",
        icon = "ReplaceableTextures\\CommandButtons\\BTNChaoticSnow.blp",
        desc = "This unit has -^$ms% movespeed and -^#as% base attack speed",
        dur = 180,
        as = 20,
        ms = 20,
        chance = 20,
        chaos = 1,
        bad = 1,
        fog = 75,
        red = 255,
        green = 50,
        blue = 50,
    }
    WeatherTable[WEATHER_FOG] = {
        text = "It is getting foggy.",
        name = "Fog",
        icon = "ReplaceableTextures\\CommandButtons\\BTNCloudOfFog.blp",
        desc = "This unit has limited vision",
        dur = 180,
        chance = 20,
        chaos = -1,
        bad = 1,
        fog = 100,
        red = 200,
        green = 200,
        blue = 200,
        buff = FourCC('ASig'),
    }
    WeatherTable[WEATHER_CHAOTIC_FOG] = {
        text = "It is getting foggy.",
        name = "Chaotic Fog",
        icon = "ReplaceableTextures\\CommandButtons\\BTNChaoticFog.blp",
        desc = "This unit has limited vision",
        dur = 180,
        chance = 20,
        chaos = 1,
        bad = 1,
        fog = 100,
        red = 255,
        green = 50,
        blue = 50,
        buff = FourCC('ASig'),
    }
    WeatherTable[WEATHER_RAIN] = {
        text = "It is raining.",
        name = "Rain",
        icon = "ReplaceableTextures\\CommandButtons\\BTNTranquility.blp",
        desc = "This unit has -@^$spellboost% spellboost",
        dur = 180,
        chance = 20,
        chaos = -1,
        bad = 1,
        boost = -5,
        fog = 50,
        red = 150,
        green = 150,
        blue = 255,
    }
    WeatherTable[WEATHER_CHAOTIC_RAIN] = {
        text = "It is raining.",
        name = "Chaotic Rain",
        icon = "ReplaceableTextures\\CommandButtons\\BTNChaoticRain.blp",
        desc = "This unit has -@^$spellboost% spellboost",
        dur = 180,
        chance = 20,
        chaos = 1,
        bad = 1,
        boost = -10,
        fog = 50,
        red = 255,
        green = 30,
        blue = 120,
    }
    WeatherTable[WEATHER_CLEAR] = {
        text = "The skies are clear.",
        name = "Clear",
        icon = "ReplaceableTextures\\CommandButtons\\BTNAdventure Road.blp",
        desc = "This unit has no afflictions",
        dur = 600,
        chance = 40,
    }
    WeatherTable[WEATHER_SUNNY] = {
        text = "It is a sunny day.",
        name = "Sunny",
        icon = "ReplaceableTextures\\CommandButtons\\BTNWispSplode.blp",
        desc = "This unit has +@^$ms% movespeed and +^#as% base attack speed",
        dur = 300,
        ms = -50,
        as = -15,
        chance = 20,
        fog = 10,
        red = 230,
        green = 255,
        blue = 0,
    }
    WeatherTable[WEATHER_DIVINE_GRACE] = {
        text = "It is a blessed day.",
        name = "Divine Grace",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBeamsOfLight.blp",
        desc = "This unit has +@^$ms% movespeed and +^#as% base attack speed",
        dur = 300,
        ms = -50,
        as = -30,
        chance = 5,
        fog = 35,
        red = 230,
        green = 255,
        blue = 0,
    }
    WeatherTable[WEATHER_SIPHONING_MIST] = {
        text = "A mist rolls in...",
        name = "Siphoning Mist",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMagic Gas.blp",
        desc = "This unit has -@^$spellboost% spellboost and +^#as% base attack speed",
        dur = 300,
        as = -50,
        chance = 10,
        boost = -20,
        fog = 50,
        red = 50,
        green = 255,
        blue = 255,
    }
    WeatherTable[WEATHER_FIRESTORM] = {
        text = "Fire rains from the sky...",
        name = "Firestorm",
        icon = "ReplaceableTextures\\CommandButtons\\BTNFarSight.blp",
        desc = "This unit has +@^$spellboost% spellboost and -^#dr% damage resist",
        dur = 300,
        chance = 10,
        boost = 30,
        chaos = 1,
        dr = -25,
        fog = 35,
        red = 255,
        green = 150,
        blue = 0,
    }
    WeatherTable[WEATHER_SOLAR_FLARE] = {
        text = "Flares cross the horizon...",
        name = "Solar Flare",
        icon = "ReplaceableTextures\\CommandButtons\\BTNSunlight.blp",
        desc = "This unit has +$atk% attack damage",
        dur = 300,
        chance = 10,
        atk = 20,
        fog = 35,
        red = 255,
        green = 50,
        blue = 50,
    }
    WeatherTable[WEATHER_SAND_STORM] = {
        text = "Dust accumulates in the air...",
        name = "Sand Storm",
        icon = "ReplaceableTextures\\CommandButtons\\BTNSandstorm3.blp",
        desc = "This unit has -^#dr% damage resist",
        dur = 300,
        chance = 10,
        dr = -20,
        fog = 40,
        red = 150,
        green = 75,
        blue = 0,
        all = 1,
    }

    donationrate  = 0.1
    donation      = 1.
    firestormRate   = 4

    ---@type fun(x: number, y: number)
    local function firestorm_damage(x, y)
        local ug = CreateGroup()

        GroupEnumUnitsInRange(ug, x, y, 300, Condition(isplayerAlly))
        DestroyTreesInRange(x, y, 300)

        for target in each(ug) do
            DamageTarget(DUMMY_UNIT, target, BlzGetUnitMaxHP(target) * .1, ATTACK_TYPE_NORMAL, PURE, "Firestorm")
        end

        DestroyGroup(ug)
    end

    local function firestorm_effect(dur)
        dur = dur - 3
        if dur <= 0 then
            return
        end

        for _ = 1, firestormRate do
            local x, y
            repeat
                x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
                y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)
            until not RectContainsCoords(gg_rct_Town_Main, x, y)

            TQ:callDelayed(1.5, firestorm_damage, x, y)
            DestroyEffect(AddSpecialEffect("Units\\Demon\\Infernal\\InfernalBirth.mdl", x, y))
        end

        TQ:callDelayed(3., firestorm_effect, dur)
    end

    local function is_bad_weather(id)
        local cfg = WeatherTable[id]
        return cfg and cfg.bad == 1
    end

    local function grace_period(weather)
        CURRENT_WEATHER = weather
        local dur = WeatherTable[weather].dur

        callback = TQ:callDelayed(dur, weather_periodic)

        buff.NAME = WeatherTable[weather].name
        buff.ICON = WeatherTable[weather].icon
        buff.DESC = WeatherTable[weather].desc
        buff.DISPEL_TYPE = is_bad_weather(weather) and BUFF_NEGATIVE or BUFF_POSITIVE

        for i = 1, #WeatherGroup do
            local u = WeatherGroup[i]
            if GetPlayerId(GetOwningPlayer(u)) < PLAYER_CAP or WeatherTable[CURRENT_WEATHER].all == 1 then
                buff:add(u, u):duration(dur)
            end
        end

        if CURRENT_WEATHER == WEATHER_FIRESTORM then
            TQ:callDelayed(3., firestorm_effect, dur)
        end
    end

    local function is_valid_weather(id, time)
        local cfg = WeatherTable[id]
        if not cfg then
            return false
        end

        -- chaos gating
        if CHAOS_MODE and cfg.chaos == -1 then
            return false
        end
        if not CHAOS_MODE and cfg.chaos == 1 then
            return false
        end

        -- no sunny weather at night
        if id == WEATHER_SUNNY and (time < 6 or time > 15) then
            return false
        end

        -- do not repeat bad weather
        if is_bad_weather(CURRENT_WEATHER) and is_bad_weather(id) then
            return false
        end

        -- prevent bad weather for first 5 iterations of lobby
        if weather_iterations <= 5 and is_bad_weather(id) then
            return false
        end

        return true
    end

    local function weight_for_weather(id)
        local cfg = WeatherTable[id]
        if not cfg then
            return 0
        end

        local w = cfg.chance or 0

        -- donation makes bad weather "heavier"
        if cfg.bad == 1 then
            w = w * (donation or 1)
        end

        -- safety
        if w < 0 then
            w = 0
        end

        return w
    end

    local function pick_weighted_weather(time)
        local pool = {}
        local prefix = {}
        local total = 0

        -- build pool of valid weathers with cumulative weights
        for id = 1, #WeatherTable do
            if is_valid_weather(id, time) then
                local w = weight_for_weather(id)
                if w > 0 then
                    pool[#pool + 1] = id
                    total = total + w
                    prefix[#prefix + 1] = total
                end
            end
        end

        -- if nothing has positive weight, fall back to uniform over valid weathers
        if #pool == 0 or total <= 0 then
            local fallback = {}
            for id = 1, #WeatherTable do
                if is_valid_weather(id, time) then
                    fallback[#fallback + 1] = id
                end
            end
            if #fallback == 0 then
                -- nothing valid at all; just keep current as last resort
                return CURRENT_WEATHER
            end
            return fallback[math.random(1, #fallback)]
        end

        -- single random roll in [0, total)
        local r = math.random() * total
        for idx, threshold in ipairs(prefix) do
            if r <= threshold then
                return pool[idx]
            end
        end

        -- paranoia fallback
        return pool[#pool]
    end

    weather_periodic = function()
        TQ:disableCallback(callback)
        local time = GetTimeOfDay()
        weather_iterations = weather_iterations + 1

        local choice = pick_weighted_weather(time)

        if DEV_ENABLED and WEATHER_OVERRIDE > 0 then
            choice = WEATHER_OVERRIDE
            WEATHER_OVERRIDE = 0
        end

        DisplayTimedTextToForce(FORCE_PLAYING, 30, "|cff6666ff" .. WeatherTable[choice].text .. "|r")

        buff:removeAll()
        callback = TQ:callDelayed(4., grace_period, choice)
    end

    if DEV_ENABLED then
        WEATHER_PERIODIC = weather_periodic
    end

    local function enter_filter()
        local u = GetFilterUnit()
        if not u then
            return false
        end

        if GetUnitTypeId(u) == BACKPACK or IsDummy(u) then
            return false
        end

        if not RectContainsUnit(MAIN_MAP.rect, u) then
            return false
        end

        if TableHas(WeatherGroup, u) then
            return false
        end

        WeatherGroup[#WeatherGroup + 1] = u

        if GetPlayerId(GetOwningPlayer(u)) < PLAYER_CAP or WeatherTable[CURRENT_WEATHER].all == 1 then
            local cfg = WeatherTable[CURRENT_WEATHER]
            local remaining = cfg.dur - TQ:getElapsed(callback)
            if remaining > 0 then
                buff:add(u, u):duration(remaining)
            end
        end

        return false
    end

    local function leave_filter()
        local u = GetFilterUnit()
        if not u then
            return false
        end

        buff:dispel(u, u)
        TableRemove(WeatherGroup, u)

        return false
    end

    CURRENT_WEATHER = WEATHER_CLEAR
    buff.NAME = WeatherTable[CURRENT_WEATHER].name
    buff.ICON = WeatherTable[CURRENT_WEATHER].icon
    buff.DESC = WeatherTable[CURRENT_WEATHER].desc
    buff.DISPEL_TYPE = is_bad_weather(CURRENT_WEATHER) and BUFF_NEGATIVE or BUFF_POSITIVE

    callback = TQ:callDelayed(WeatherTable[CURRENT_WEATHER].dur, weather_periodic)

    local trig = CreateTrigger()
    TriggerRegisterEnterRegion(trig, MAIN_MAP.region, Filter(enter_filter))
    TriggerRegisterLeaveRegion(trig, MAIN_MAP.region, Filter(leave_filter))
end, Debug and Debug.getLine())
