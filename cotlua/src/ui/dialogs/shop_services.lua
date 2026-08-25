-- Dialog controllers for shop service entries. These frames collect choices;
-- synchronized gameplay changes remain in TomeService and ShopServices.

OnInit.final("ShopServiceDialogs", function(Require)
    Require('DialogWindow')
    Require('ShopActions')
    Require('ShopServices')
    Require('TomeService')

    local function failure(pid, reason)
        local messages = {
            currency = "You do not have enough money!",
            MAXED = "This service is already at its maximum.",
            FULL = "This service is already full.",
            ["NO ITEM"] = "You have no item to recharge!",
            ["NO POTIONS"] = "You have no potions to refill.",
            ["NO STATS"] = "You have no stats available to refund.",
            COOLDOWN = "This service is currently on cooldown.",
            OWNED = "You already own this service.",
        }
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 15,
            messages[reason] or "That service is no longer available.")
    end

    local function price_text(gold, platinum)
        local text = ""
        if platinum > 0 then
            text = text .. platinum .. " |cffe3e2e2Platinum|r"
        end
        if gold > 0 then
            if text ~= "" then text = text .. " and " end
            text = text .. gold .. " |cffffcc00Gold|r"
        end
        return text
    end

    local function tome_confirm(dialog, _, data)
        local quote = TomeService.commit(dialog.pid, data.id, data.bundle)
        dialog:destroy()
        if not quote.can_buy then
            failure(dialog.pid, quote.reason)
        end
        return false
    end

    local function tome_bundle(dialog, _, bundle_index)
        local quote = TomeService.quote(dialog.pid, dialog.data.id, bundle_index)
        local id = dialog.data.id
        dialog:destroy()
        if quote.gain <= 0 then
            failure(dialog.pid, quote.reason)
            return false
        end

        local confirm = DialogWindow.create(dialog.pid,
            "Purchase " .. quote.gain .. " " .. TomeService.names[quote.tome_type]
                .. " for " .. price_text(quote.gold, quote.platinum) .. "?",
            tome_confirm, "tome-confirm")
        confirm:addButton("Confirm", { id = id, bundle = bundle_index })
        confirm:display()
        return false
    end

    local function open_tome(pid, id)
        local _, raw = GetItem(id)
        local tome_type = TomeService.types[raw]
        local dialog = DialogWindow.create(pid,
            "Purchase " .. TomeService.names[tome_type], tome_bundle, "tome-bundle")
        dialog.data.id = id
        local cost_multiplier = tome_type == 4 and 2 or 1
        for index = 1, #TomeService.bundles do
            local bundle = TomeService.bundles[index]
            dialog:addButton(price_text(bundle.gold * cost_multiplier,
                bundle.platinum * cost_multiplier), index)
        end
        return dialog:display()
    end

    local function focus_confirm(dialog)
        local quote = FocusService.commit(dialog.pid)
        dialog:destroy()
        if not quote.available then
            failure(dialog.pid, quote.reason)
        else
            DisplayTextToPlayer(Player(dialog.pid - 1), 0, 0,
                "Your attributes were focused and you were refunded |cffffcc00"
                    .. quote.refund .. "|r gold.")
        end
        return false
    end

    local function open_focus(pid)
        local quote = FocusService.quote(pid)
        if not quote.available then return false end
        local dialog = DialogWindow.create(pid, "Focus attributes?",
            focus_confirm, "focus-service")
        dialog:addButton("Reduce " .. quote.strength .. "/" .. quote.agility
            .. "/" .. quote.intelligence .. " (+" .. quote.refund .. " Gold)")
        return dialog:display()
    end

    local function retrain_confirm(dialog)
        local quote = RetrainingService.commit(dialog.pid)
        dialog:destroy()
        if not quote.available then failure(dialog.pid, quote.reason) end
        return false
    end

    local function open_retraining(pid)
        local dialog = DialogWindow.create(pid, "Retrain your hero's abilities?",
            retrain_confirm, "retraining-service")
        dialog:addButton("Retrain")
        return dialog:display()
    end

    local function recharge_confirm(dialog)
        local quote = RechargeService.commit(dialog.pid)
        dialog:destroy()
        if not quote.available then
            failure(dialog.pid, quote.reason)
        else
            DisplayTextToPlayer(Player(dialog.pid - 1), 0, 0,
                "Recharged " .. GetItemName(quote.item.obj) .. " for "
                    .. price_text(quote.gold, quote.platinum) .. ".")
        end
        return false
    end

    local function open_recharge(pid)
        local quote = RechargeService.quote(pid)
        if not quote.available then return false end
        local dialog = DialogWindow.create(pid, "Recharge reincarnation?",
            recharge_confirm, "recharge-service")
        dialog:addButton("Recharge (" .. price_text(quote.gold, quote.platinum) .. ")")
        return dialog:display()
    end

    local function refill_confirm(dialog)
        local quote = PotionRefillService.commit(dialog.pid)
        dialog:destroy()
        if not quote.available then failure(dialog.pid, quote.reason) end
        return false
    end

    local function open_refill(pid)
        local quote = PotionRefillService.quote(pid)
        if not quote.available then return false end
        local dialog = DialogWindow.create(pid,
            "Refill potions for " .. quote.price .. " |cffffcc00Gold|r?",
            refill_confirm, "potion-refill-service")
        dialog:addButton("Refill")
        return dialog:display()
    end

    local function open_converter(pid)
        local quote = CurrencyConverterService.commit(pid)
        if not quote.available then
            failure(pid, quote.reason)
            return false
        end
        DisplayTextToPlayer(Player(pid - 1), 0, 0,
            "You have purchased a Currency Converter.")
        return true
    end

    local function upgrade_confirm(dialog, _, id)
        local quote = BackpackUpgradeService.commit(dialog.pid, id)
        dialog:destroy()
        if not quote.available then
            failure(dialog.pid, quote.reason)
        else
            DisplayTimedTextToPlayer(Player(dialog.pid - 1), 0, 0, 20,
                "You successfully upgraded to: " .. quote.name
                    .. " [|cffffcc00Level " .. quote.new_level .. "|r]")
        end
        return false
    end

    local function open_upgrade(pid, id)
        local quote = BackpackUpgradeService.quote(pid, id)
        if not quote.available then return false end
        local dialog = DialogWindow.create(pid,
            "Upgrade cost: " .. price_text(quote.gold, quote.platinum),
            upgrade_confirm, "backpack-upgrade-service")
        dialog:addButton("Upgrade", id)
        return dialog:display()
    end

    local function service_availability(quote)
        if quote.available then return true end
        if quote.reason == "currency" then return false, "NOT ENOUGH" end
        return false, quote.reason
    end

    local function register_tome(id)
        RegisterShopAction(id, {
            label = "AVAILABLE",
            availability = function(pid) return TomeService.availability(pid) end,
            open = function(pid) return open_tome(pid, id) end,
        })
    end

    local tome_ids = { 'I0TS', 'I0TA', 'I0TI', 'I0TT' }
    for index = 1, #tome_ids do
        register_tome(tome_ids[index])
    end

    RegisterShopAction('I0N0', {
        label = "REFUND STATS",
        availability = function(pid) return service_availability(FocusService.quote(pid)) end,
        open = open_focus,
    })
    RegisterShopAction('I0JN', {
        label = "RETRAIN",
        availability = function(pid) return service_availability(RetrainingService.quote(pid)) end,
        open = open_retraining,
    })
    RegisterShopAction('I0JS', {
        label = "AVAILABLE",
        availability = function(pid) return service_availability(RechargeService.quote(pid)) end,
        open = open_recharge,
        cooldown = function(pid) return RECHARGE_COOLDOWN[pid], 180 end,
    })
    RegisterShopAction('I00J', {
        label = "AVAILABLE",
        availability = function(pid) return service_availability(PotionRefillService.quote(pid)) end,
        open = open_refill,
    })
    RegisterShopAction('I084', {
        label = "4 PLATINUM",
        availability = function(pid) return service_availability(CurrencyConverterService.quote(pid)) end,
        open = open_converter,
    })
    RegisterShopAction('I101', {
        label = "DYNAMIC COST",
        availability = function(pid) return service_availability(BackpackUpgradeService.quote(pid, 'I101')) end,
        open = function(pid) return open_upgrade(pid, 'I101') end,
    })
    RegisterShopAction('I102', {
        label = "DYNAMIC COST",
        availability = function(pid) return service_availability(BackpackUpgradeService.quote(pid, 'I102')) end,
        open = function(pid) return open_upgrade(pid, 'I102') end,
    })
end, Debug and Debug.getLine())
