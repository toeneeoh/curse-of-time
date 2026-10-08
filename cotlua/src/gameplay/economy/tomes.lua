-- Synchronized stat-tome quotes and commits. The shop/dialog layer only
-- selects a tome and bundle; all cap, currency, and stat checks happen here.

OnInit.final("TomeService", function(Require)
    Require('Currency')
    Require('Profile')
    Require('UnitTable')

    TomeService = {}

    TomeService.types = {
        [FourCC('I0TS')] = 1,
        [FourCC('I0TA')] = 2,
        [FourCC('I0TI')] = 3,
        [FourCC('I0TT')] = 4,
    }

    TomeService.names = {
        "|cff990000Strength|r",
        "|cff006600Agility|r",
        "|cff3333ffIntelligence|r",
        "All Stats",
    }

    -- Knowledge has twice the purchase price, but the same number of gain
    -- iterations. Each awarded point counts three times against the shared cap.
    TomeService.bundles = {
        { name = "10,000 Gold", iterations = 1, gold = 10000, platinum = 0 },
        { name = "100,000 Gold", iterations = 10, gold = 100000, platinum = 0 },
        { name = "1 Platinum", iterations = 100, gold = 0, platinum = 1 },
        { name = "10 Platinum", iterations = 1000, gold = 0, platinum = 10 },
        { name = "100 Platinum", iterations = 10000, gold = 0, platinum = 100 },
    }

    local function rawcode(id)
        local _, raw = GetItem(id)
        return raw
    end

    local function total_stats(pid)
        local hero = Hero[pid]
        if not hero or not Unit[hero] then
            return nil
        end
        local unit = Unit[hero]
        return unit.str + unit.agi + unit.int
    end

    ---@param pid integer
    ---@return boolean, string?
    function TomeService.availability(pid)
        local total = total_stats(pid)
        if not total then
            return false, "NO HERO"
        end
        if total >= TomeCap(GetHeroLevel(Hero[pid])) then
            return false, "MAXED"
        end
        return true
    end

    ---@class TomeQuote
    ---@field can_buy boolean
    ---@field reason string?
    ---@field tome_type integer
    ---@field gain integer
    ---@field gold integer
    ---@field platinum integer

    ---@param pid integer
    ---@param id string|integer
    ---@param bundle_index integer
    ---@return TomeQuote
    function TomeService.quote(pid, id, bundle_index)
        local tome_type = TomeService.types[rawcode(id)]
        local bundle = TomeService.bundles[bundle_index]
        local quote = {
            can_buy = false,
            reason = "invalid",
            tome_type = tome_type or 0,
            gain = 0,
            gold = 0,
            platinum = 0,
        }
        if not tome_type or not bundle then
            return quote
        end

        local available, reason = TomeService.availability(pid)
        if not available then
            quote.reason = reason
            return quote
        end

        local multiplier = tome_type == 4 and 3 or 1
        local cost_multiplier = tome_type == 4 and 2 or 1
        local total = total_stats(pid)
        local cap = TomeCap(GetHeroLevel(Hero[pid]))
        local bonus = 0

        for _ = 1, bundle.iterations do
            local projected = total + bonus * multiplier
            local gain = 100 // (projected ^ 0.25)
                * (math.log(cap / projected + 0.75, 2.71828) / 3.)
            bonus = bonus + gain
            if total + bonus * multiplier >= cap then
                bonus = (cap - total) / multiplier
                break
            end
        end

        quote.gain = math.floor(bonus)
        quote.gold = bundle.gold * cost_multiplier
        quote.platinum = bundle.platinum * cost_multiplier
        if quote.gain <= 0 then
            quote.reason = "MAXED"
        elseif GetCurrency(pid, GOLD) < quote.gold
            or GetCurrency(pid, PLATINUM) < quote.platinum then
            quote.reason = "currency"
        else
            quote.can_buy = true
            quote.reason = nil
        end
        return quote
    end

    ---Re-quotes immediately before charging and applying stats.
    ---@param pid integer
    ---@param id string|integer
    ---@param bundle_index integer
    ---@return TomeQuote
    function TomeService.commit(pid, id, bundle_index)
        local quote = TomeService.quote(pid, id, bundle_index)
        if not quote.can_buy then
            return quote
        end

        AddCurrency(pid, GOLD, -quote.gold)
        AddCurrency(pid, PLATINUM, -quote.platinum)

        local unit = Unit[Hero[pid]]
        if quote.tome_type == 1 then
            unit.str = unit.str + quote.gain
        elseif quote.tome_type == 2 then
            unit.agi = unit.agi + quote.gain
        elseif quote.tome_type == 3 then
            unit.int = unit.int + quote.gain
        else
            unit.str = unit.str + quote.gain
            unit.agi = unit.agi + quote.gain
            unit.int = unit.int + quote.gain
        end

        DisplayTextToPlayer(Player(pid - 1), 0, 0,
            "You have gained |cffffcc00" .. quote.gain .. "|r " .. TomeService.names[quote.tome_type])
        DestroyEffect(AddSpecialEffectTarget("Objects\\InventoryItems\\tomeRed\\tomeRed.mdl", Hero[pid], "origin"))
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", Hero[pid], "origin"))
        return quote
    end
end, Debug and Debug.getLine())
