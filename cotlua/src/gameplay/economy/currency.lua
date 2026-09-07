--[[
    currency.lua

    This library provides general purpose money related functions for use elsewhere.
]]
OnInit.final("Currency", function(Require)
    Require('Users')
    Require('ItemEventRegistry')
    Require('EconomyEffects')

    local CURRENCY = __jarray(0) ---@type integer[]
    local PLAT_VALUE = 1000000
    local concat = table.concat

    GOLD           = 0
    PLATINUM       = 1
    CRYSTAL        = 2
    HONOR          = 3
    FACTION        = 4
    CURRENCY_COUNT = 5

    --currencies
    CURRENCY_ICON = {
        "gold.dds",
        "plat.dds",
        "crystal.dds",
        "ShopHonorPoints.dds",
        "ShopFactionPoints.dds",
    }

    local IS_CONVERTING_PLAT     = {} ---@type boolean[]
    local IS_CONVERTER_PURCHASED = {} ---@type boolean[]
    local changed_actions = {}
    local converter_changed_actions = {}

    ---@param callback fun(pid: integer, currency: integer, amount: integer)
    ---@return boolean
    function RegisterCurrencyChangedAction(callback)
        for index = 1, #changed_actions do
            if changed_actions[index] == callback then
                return false
            end
        end

        changed_actions[#changed_actions + 1] = callback
        return true
    end

    ---@param pid integer
    ---@param currency integer
    ---@param amount integer
    local function notify_currency_changed(pid, currency, amount)
        for index = 1, #changed_actions do
            changed_actions[index](pid, currency, amount)
        end
    end

    ---@param callback fun(pid: integer, purchased: boolean, enabled: boolean)
    ---@return boolean
    function RegisterCurrencyConverterChangedAction(callback)
        for index = 1, #converter_changed_actions do
            if converter_changed_actions[index] == callback then
                return false
            end
        end

        converter_changed_actions[#converter_changed_actions + 1] = callback
        return true
    end

    ---@param pid integer
    local function notify_converter_changed(pid)
        local purchased = IS_CONVERTER_PURCHASED[pid] == true
        local enabled = purchased and IS_CONVERTING_PLAT[pid] == true
        for index = 1, #converter_changed_actions do
            converter_changed_actions[index](pid, purchased, enabled)
        end
    end

    local function player_from_pid(pid)
        return Player(pid - 1)
    end

    local function currency_key(pid, index)
        return pid * CURRENCY_COUNT + index
    end

    local function on_cleanup(pid)
        IS_CONVERTER_PURCHASED[pid] = false
        IS_CONVERTING_PLAT[pid] = false
        notify_converter_changed(pid)
    end
    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end
    --

    ---@param pid integer
    ---@return boolean
    function HasCurrencyConverter(pid)
        return IS_CONVERTER_PURCHASED[pid] == true
    end

    ---@param pid integer
    ---@return boolean
    function IsCurrencyConverterEnabled(pid)
        return IS_CONVERTER_PURCHASED[pid] == true
            and IS_CONVERTING_PLAT[pid] == true
    end

    ---@param pid integer
    ---@return boolean
    function ToggleCurrencyConverter(pid)
        if not IS_CONVERTER_PURCHASED[pid] then
            return false
        end

        IS_CONVERTING_PLAT[pid] = not IS_CONVERTING_PLAT[pid]
        notify_converter_changed(pid)
        return IS_CONVERTING_PLAT[pid]
    end

    ---Marks the synchronized converter service as purchased. Charging remains
    ---the responsibility of its transaction immediately before this call.
    ---@param pid integer
    function GrantCurrencyConverter(pid)
        IS_CONVERTER_PURCHASED[pid] = true
        notify_converter_changed(pid)
    end

    -- crystal to gold
    ITEM_LOOKUP[FourCC('I0ME')] = function(p, pid)
        if GetCurrency(pid, CRYSTAL) >= 1 then
            AddCurrency(pid, CRYSTAL, -1)
            AddCurrency(pid, GOLD, 500000)
        else
            DisplayTimedTextToPlayer(p, 0, 0, 20, "You need at least 1 crystal to buy this.")
        end
    end

    -- platinum to crystal
    ITEM_LOOKUP[FourCC('I0MF')] = function(p, pid)
        AddCurrency(pid, CRYSTAL, 1)
        DisplayTimedTextToPlayer(p, 0, 0, 20, CRYSTAL_TAG .. (GetCurrency(pid, CRYSTAL)))
    end

    -- buy platinum
    ITEM_LOOKUP[FourCC('I04G')] = function(p, pid)
        AddCurrency(pid, PLATINUM, 1)
        ConversionEffect(pid)
        DisplayTimedTextToPlayer(p, 0, 0, 20, PLATINUM_TAG .. (GetCurrency(pid, PLATINUM)))
    end

    -- buy gold
    ITEM_LOOKUP[FourCC('I052')] = function(p, pid)
        ConversionEffect(pid)
        AddCurrency(pid, GOLD, PLAT_VALUE)
        DisplayTimedTextToPlayer(p, 0, 0, 20, PLATINUM_TAG .. (GetCurrency(pid, PLATINUM)))
    end

    local setter = {
        [GOLD] = function(pid, amount) SetPlayerState(player_from_pid(pid), PLAYER_STATE_RESOURCE_GOLD, amount) end,
        [PLATINUM] = function(pid, amount) SetPlayerState(player_from_pid(pid), PLAYER_STATE_RESOURCE_LUMBER, amount) end,
        [CRYSTAL] = function(pid, amount) SetPlayerState(player_from_pid(pid), PLAYER_STATE_RESOURCE_FOOD_USED, amount) end,
    }

    ---@type fun(pid: integer, index: integer, amount: integer)
    function SetCurrency(pid, index, amount)
        amount = math.max(0, amount)
        CURRENCY[currency_key(pid, index)] = amount
        local set_player_state = setter[index]
        if set_player_state then
            set_player_state(pid, amount)
        end
        notify_currency_changed(pid, index, amount)
    end

    ---@type fun(pid: integer, index: integer):integer
    function GetCurrency(pid, index)
        return CURRENCY[currency_key(pid, index)]
    end

    ---@type fun(pid: integer, index: integer, amount: integer)
    function AddCurrency(pid, index, amount)
        SetCurrency(pid, index, GetCurrency(pid, index) + amount)
    end

    ---@type fun(pid: integer, goldawarded: number, displaymessage: boolean)
    function AwardGold(pid, goldawarded, displaymessage)
        local p = player_from_pid(pid)
        local goldWon ---@type integer 
        local platWon ---@type integer 

        goldWon = math.floor(goldawarded * GetRandomReal(0.9, 1.1))
        goldWon = math.floor(goldWon * (1 + (Unit[Hero[pid]].gold_rate * 0.01)))

        platWon = goldWon // PLAT_VALUE
        goldWon = goldWon - platWon * PLAT_VALUE

        AddCurrency(pid, PLATINUM, platWon)
        AddCurrency(pid, GOLD, goldWon)

        if displaymessage then
            if platWon > 0 then
                DisplayTimedTextToPlayer(p, 0, 0, 10, concat({"|c00ebeb15You have gained ", goldWon, " gold and ", platWon, " platinum coins.|r",}))
                DisplayTimedTextToPlayer(p, 0, 0, 10, PLATINUM_TAG .. (GetCurrency(pid, PLATINUM)))
            else
                DisplayTimedTextToPlayer(p, 0, 0, 10, concat({"|c00ebeb15You have gained ", goldWon, " gold.|r",}))
            end
        end

        local s = "+" .. goldWon

        if goldWon >= 100000 then
            s = concat({"+", goldWon // 1000, "K"})
        end

        if platWon > 0 then
            s = concat({"|cffcccccc+", platWon, "|r |cffffcc00", s, "|r"})
            FloatingTextUnit(s, Hero[pid], 1.5, 75, -100, 9., 255, 255, 255, 0, false)
        else
            FloatingTextUnit(s, Hero[pid], 1.5, 75, -100, 9., 255, 255, 0, 0, false)
        end
    end

    ---@type fun(pid: integer, price: number, successMsg: string): boolean
    function ChargePlayer(pid, price, successMsg)
        local gold = GetCurrency(pid, GOLD)
        local plat = GetCurrency(pid, PLATINUM)

        -- not enough total
        if gold + plat * PLAT_VALUE < price then
            DisplayTextToPlayer(player_from_pid(pid), 0, 0, "You do not have enough funds!")
            return false
        end

        if gold >= price then
            -- all in gold
            SetCurrency(pid, GOLD, gold - price)
        else
            -- spend all gold, then cover the rest with platinum
            local shortage = price - gold
            local neededPlat = (shortage + PLAT_VALUE - 1) // PLAT_VALUE
            local leftoverGold = neededPlat * PLAT_VALUE - shortage

            SetCurrency(pid, PLATINUM, plat - neededPlat)
            SetCurrency(pid, GOLD,     leftoverGold)
        end

        DisplayTextToPlayer(player_from_pid(pid), 0, 0, successMsg)
        return true
    end

    ---@type fun(p: player, flat: integer, percent: number, minimum: integer, message: string)
    function ChargeNetworth(p, flat, percent, minimum, message)
        local pid          = GetPlayerId(p) + 1
        local playerGold   = GetCurrency(pid, GOLD)
        local platCost     = R2I(GetCurrency(pid, PLATINUM) * percent)

        local cost = flat + R2I(playerGold * percent)
        if cost < minimum then
            cost = minimum
        end

        AddCurrency(pid, GOLD, -cost)
        AddCurrency(pid, PLATINUM, -platCost)

        if message ~= "" then
            if platCost > 0 then
                message = concat({message, " ", RealToString(platCost)," platinum, ", RealToString(cost), " gold",})
            else
                message = concat({message, " ", RealToString(cost), " gold"})
            end
        end

        if message ~= "" then
            DisplayTextToPlayer(p, 0, 0, message)
        end
    end

    --- keeps the internal gold balance synchronized with Warcraft's resource state,
    --- then performs automatic gold-to-platinum conversion when enabled.
    ---@return boolean
    local function on_currency_changed()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 
        local gold_key = currency_key(pid, GOLD)
        local gold = GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD)

        if CURRENCY[gold_key] ~= gold then
            CURRENCY[gold_key] = gold
            notify_currency_changed(pid, GOLD, gold)
        end

        if IS_CONVERTING_PLAT[pid] then
            -- SetCurrency changes player state and fires this trigger again.
            IS_CONVERTING_PLAT[pid] = false
            local plat = CURRENCY[gold_key] // PLAT_VALUE

            if plat > 0 then
                AddCurrency(pid, PLATINUM, plat)
                AddCurrency(pid, GOLD, -PLAT_VALUE * plat)
                ConversionEffect(pid)
            end

            IS_CONVERTING_PLAT[pid] = true
        end

        return false
    end

    local currency_trigger = CreateTrigger()
    U = User.first ---@type User 

    while U do
        TriggerRegisterPlayerStateEvent(currency_trigger, U.player, PLAYER_STATE_RESOURCE_GOLD, GREATER_THAN_OR_EQUAL, 0.)
        TriggerRegisterPlayerStateEvent(currency_trigger, U.player, PLAYER_STATE_RESOURCE_LUMBER, GREATER_THAN_OR_EQUAL, 0.)
        U = U.next
    end

    TriggerAddCondition(currency_trigger, Filter(on_currency_changed))

end, Debug and Debug.getLine())
