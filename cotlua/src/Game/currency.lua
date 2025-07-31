--[[
    currency.lua

    This library provides general purpose money related functions for use elsewhere.
]]
OnInit.final("Currency", function(Require)
    Require('Users')
    Require('Frames')
    Require('ItemLookup')

    local CURRENCY = __jarray(0) ---@type integer[] 
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

    local IS_CONVERTING_PLAT = {} ---@type boolean[]
    local IS_CONVERTER_PURCHASED = {} ---@type boolean[]

    local GOLD = GOLD
    local PLATINUM = PLATINUM
    local CRYSTAL = CRYSTAL
    local HONOR = HONOR
    local FACTION = FACTION
    local CURRENCY_COUNT = CURRENCY_COUNT

    -- frame setup
    local converter_frame = BlzCreateFrame("QuestButtonDisabledBackdropTemplate", RESOURCE_BAR, 0, 0)
    local convert_button
    BlzFrameSetTexture(converter_frame, "trans32.blp", 0, true)
    BlzFrameSetSize(converter_frame, 0.006, 0.006)
    BlzFrameSetPoint(converter_frame, FRAMEPOINT_TOP, RESOURCE_BAR, FRAMEPOINT_TOP, 0, -0.025)

    -- converter button
    local onConvert = function()
        local frame = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local enabled = false

        if IS_CONVERTER_PURCHASED[pid] then
            enabled = not IS_CONVERTING_PLAT[pid]
            IS_CONVERTING_PLAT[pid] = enabled
        end

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(frame, false)
            BlzFrameSetEnable(frame, true)
            convert_button:enable(enabled)
        end
    end

    convert_button = SimpleButton.create(converter_frame, "ReplaceableTextures\\CommandButtons\\BTNConvert.blp", 0.017, 0.017, FRAMEPOINT_CENTER, FRAMEPOINT_CENTER, -0.0975, -0.0025, onConvert, "Must purchase a converter to use!", FRAMEPOINT_TOP, FRAMEPOINT_BOTTOM)
    convert_button:enable(false)

    local function on_cleanup(pid)
        IS_CONVERTER_PURCHASED[pid] = false
        IS_CONVERTING_PLAT[pid] = false
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetText(convert_button.tooltip.tooltip, "Must purchase a converter to use!")
            convert_button:enable(false)
        end
    end
    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end
    --

    -- purchase auto converter
    local function BuyConverter()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid]
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        -- converter
        if index == 0 then
            local price = dw.data[index]
            if ChargePlayer(pid, price, "You have purchased a Currency Converter.") then
                IS_CONVERTER_PURCHASED[pid] = true
                if GetLocalPlayer() == GetTriggerPlayer() then
                    BlzFrameSetText(convert_button.tooltip.tooltip, "Convert gold to platinum automatically")
                end
            end

            dw:destroy()
        end

        return false
    end

    -- map item currency exchange purchases to functions
    ITEM_LOOKUP[FourCC('I084')] = function(p, pid)
        if not IS_CONVERTER_PURCHASED[pid] then
            local dw = DialogWindow.create(pid, "Purchase cost: |n|cffffffff4 |cffe3e2e2Platinum|r", BuyConverter)

            dw:addButton("Purchase", 4000000)

            dw:display()
        end
    end

    -- crystal to gold & platinum
    ITEM_LOOKUP[FourCC('I0ME')] = function(p, pid)
        if GetCurrency(pid, CRYSTAL) >= 1 then
            AddCurrency(pid, CRYSTAL, -1)
            AddCurrency(pid, GOLD, 500000)
        else
            DisplayTimedTextToPlayer(p, 0, 0, 20, "You need at least 1 crystal to buy this.")
        end
    end

    --platinum to crystal
    ITEM_LOOKUP[FourCC('I0MF')] = function(p, pid)
        AddCurrency(pid, CRYSTAL, 1)
        DisplayTimedTextToPlayer(p, 0, 0, 20, CrystalTag .. (GetCurrency(pid, CRYSTAL)))
    end

    ITEM_LOOKUP[FourCC('I04G')] = function(p, pid)
        AddCurrency(pid, PLATINUM, 1)
        ConversionEffect(pid)
        DisplayTimedTextToPlayer(p, 0, 0, 20, PlatTag .. (GetCurrency(pid, PLATINUM)))
    end

    ITEM_LOOKUP[FourCC('I052')] = function(p, pid)
        ConversionEffect(pid)
        AddCurrency(pid, GOLD, 1000000)
        DisplayTimedTextToPlayer(p, 0, 0, 20, PlatTag .. (GetCurrency(pid, PLATINUM)))
    end

    local setter = {
        [GOLD] = function(pid, amount) SetPlayerState(Player(pid - 1), PLAYER_STATE_RESOURCE_GOLD, amount) end,
        [PLATINUM] = function(pid, amount) SetPlayerState(Player(pid - 1), PLAYER_STATE_RESOURCE_LUMBER, amount) end,
        [CRYSTAL] = function(pid, amount) SetPlayerState(Player(pid - 1), PLAYER_STATE_RESOURCE_FOOD_USED, amount) end,
        [HONOR] = function (pid, amount)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetText(HONOR_TEXT, amount)
            end
        end,
        [FACTION] = function(pid, amount)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetText(FACTION_TEXT, amount)
            end
        end,
    }

    ---@type fun(pid: integer, index: integer, amount: integer)
    function SetCurrency(pid, index, amount)
        amount = math.max(0, amount)
        CURRENCY[pid * CURRENCY_COUNT + index] = amount
        setter[index](pid, amount)
        Shop.refresh(pid)
    end

    ---@type fun(pid: integer, index: integer):integer
    function GetCurrency(pid, index)
        return CURRENCY[pid * CURRENCY_COUNT + index]
    end

    ---@type fun(pid: integer, index: integer, amount: integer)
    function AddCurrency(pid, index, amount)
        SetCurrency(pid, index, GetCurrency(pid, index) + amount)
    end

    ---@type fun(pid: integer, goldawarded: number, displaymessage: boolean)
    function AwardGold(pid, goldawarded, displaymessage)
        local p = Player(pid - 1)
        local goldWon ---@type integer 
        local platWon ---@type integer 

        goldWon = math.floor(goldawarded * GetRandomReal(0.9,1.1))
        goldWon = math.floor(goldWon * (1 + (ItemGoldRate[pid] * 0.01)))

        platWon = goldWon // 1000000
        goldWon = goldWon - platWon * 1000000

        AddCurrency(pid, PLATINUM, platWon)
        AddCurrency(pid, GOLD, goldWon)

        if displaymessage then
            if platWon > 0 then
                DisplayTimedTextToPlayer(p, 0, 0, 10, "|c00ebeb15You have gained " .. (goldWon) .. " gold and " .. (platWon) .. " platinum coins.|r")
                DisplayTimedTextToPlayer(p, 0, 0, 10, PlatTag .. (GetCurrency(pid, PLATINUM)))
            else
                DisplayTimedTextToPlayer(p, 0, 0, 10, "|c00ebeb15You have gained " .. (goldWon) .. " gold.|r")
            end
        end

        local s = "+" .. goldWon

        if goldWon >= 100000 then
            s = "+" .. (goldWon // 1000) .. "K"
        end

        if platWon > 0 then
            s = "|cffcccccc+" .. platWon .. "|r |cffffcc00" .. s .. "|r"
            FloatingTextUnit(s, Hero[pid], 1.5, 75, -100, 9., 255, 255, 255, 0, false)
        else
            FloatingTextUnit(s, Hero[pid], 1.5, 75, -100, 9., 255, 255, 0, 0, false)
        end
    end

    local PLAT_VALUE = 1000000

    ---@type fun(pid: integer, price: number, successMsg: string): boolean
    function ChargePlayer(pid, price, successMsg)
        local gold = GetCurrency(pid, GOLD)
        local plat = GetCurrency(pid, PLATINUM)

        -- not enough total
        if gold + plat * PLAT_VALUE < price then
            DisplayTextToPlayer(Player(pid - 1), 0, 0, "You do not have enough funds!")
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

        DisplayTextToPlayer(Player(pid - 1), 0, 0, successMsg)
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
                message = message .. " " .. RealToString(platCost) .. " platinum, " .. RealToString(cost) .. " gold"
            else
                message = message .. " " .. RealToString(cost) .. " gold"
            end
        end

        if message ~= "" then
            DisplayTextToPlayer(p, 0, 0, message)
        end
    end

    ---@return boolean
    local function CurrencyConverter()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 

        Shop.refresh(pid)
        CURRENCY[pid * CURRENCY_COUNT + GOLD] = GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD)

        if IS_CONVERTING_PLAT[pid] then
            -- prevent stack overflow
            IS_CONVERTING_PLAT[pid] = false
            local plat = CURRENCY[pid * CURRENCY_COUNT + GOLD] // 1000000

            if plat > 0 then
                AddCurrency(pid, PLATINUM, plat)
                AddCurrency(pid, GOLD, -1000000 * plat)
                ConversionEffect(pid)
            end
            IS_CONVERTING_PLAT[pid] = true
        end

        return false
    end

    local convert = CreateTrigger()
    U = User.first ---@type User 

    while U do
        TriggerRegisterPlayerStateEvent(convert, U.player, PLAYER_STATE_RESOURCE_GOLD, GREATER_THAN_OR_EQUAL, 0.)
        TriggerRegisterPlayerStateEvent(convert, U.player, PLAYER_STATE_RESOURCE_LUMBER, GREATER_THAN_OR_EQUAL, 0.)
        U = U.next
    end

    TriggerAddCondition(convert, Filter(CurrencyConverter))

end, Debug and Debug.getLine())
