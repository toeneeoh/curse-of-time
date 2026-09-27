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
            ["NO POTIONS"] = "You have no potions to brew or refill.",
            ["NO HERO"] = "You have no active hero.",
            ["NOT REFINABLE"] = "That potion property cannot be refined.",
            ["ALREADY APPLIED"] = "That customization is already applied.",
            INHERENT = "That effect is already inherent to this flask.",
            ["REQUIRES LEVEL 200"] =
                "Chaos brewing requires a level 200 hero.",
            ["REQUIRES RANK 4"] =
                "That infusion requires Rank 4 with its faction.",
            ["BREW FAILED"] = "The potion could not be customized.",
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

    local open_brew_menu

    local function brewing_confirm(dialog, _, data)
        local quote = PotionBrewingService.commit(dialog.pid, data.slot,
                                                   data.operation, data.value)
        dialog:destroy()
        if not quote.available then
            failure(dialog.pid, quote.reason)
        end
        return false
    end

    local function confirm_brewing(pid, data)
        local quote = PotionBrewingService.quote(pid, data.slot,
                                                 data.operation, data.value)
        if not quote.available then
            failure(pid, quote.reason)
            return false
        end

        local action
        if data.operation == "refine" then
            action = "Refine " ..
                         PotionBrewingService.stat_names[data.value]
        elseif data.value == 0 then
            action = data.operation == "infusion" and "Remove infusion" or
                         "Remove catalyst"
        else
            action = "Apply " .. quote.option.name
        end
        local dialog = DialogWindow.create(pid,
            action .. " for " .. quote.price .. " |cffffcc00Gold|r?",
            brewing_confirm, "potion-brewing-confirm")
        dialog:addButton("Confirm", data)
        return dialog:display()
    end

    local function brewing_option(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        return confirm_brewing(pid, data)
    end

    local function add_brewing_option(dialog, slot, operation, value, label)
        local quote = PotionBrewingService.quote(dialog.pid, slot, operation,
                                                 value)
        if quote.available then
            label = label .. " (" .. quote.price .. " Gold)"
        elseif quote.reason == "ALREADY APPLIED" then
            label = label .. " (Applied)"
        elseif quote.reason ~= "currency" then
            label = label .. " (" .. quote.reason .. ")"
        else
            label = label .. " (" .. quote.price .. " Gold - NOT ENOUGH)"
        end
        dialog:addButton(label, {
            slot = slot,
            operation = operation,
            value = value
        }, quote.option and quote.option.icon or nil)
    end

    local function open_refinement(pid, slot)
        local item = PotionService.getEquipped(pid, slot)
        if not item then return false end
        local dialog = DialogWindow.create(pid, "Refine which property?",
                                           brewing_option,
                                           "potion-refinement")
        for _, stat in ipairs(PotionService.ROLLABLE_STATS) do
            if PotionService.canRefine(item, stat) then
                add_brewing_option(dialog, slot, "refine", stat,
                                   PotionBrewingService.stat_names[stat])
            end
        end
        return dialog:display()
    end

    local function open_infusions(pid, slot)
        local dialog = DialogWindow.create(pid, "Choose an infusion",
                                           brewing_option,
                                           "potion-infusions")
        local customization = PotionService.getCustomization(
                                  PotionService.getEquipped(pid, slot))
        if customization and customization.infusion_id ~= 0 then
            add_brewing_option(dialog, slot, "infusion", 0,
                               "Remove Infusion")
        end
        for _, infusion in ipairs(PotionService.getInfusions()) do
            add_brewing_option(dialog, slot, "infusion", infusion.id,
                               infusion.name)
        end
        return dialog:display()
    end

    local function open_catalysts(pid, slot)
        local dialog = DialogWindow.create(pid, "Choose a catalyst",
                                           brewing_option,
                                           "potion-catalysts")
        local customization = PotionService.getCustomization(
                                  PotionService.getEquipped(pid, slot))
        if customization and customization.catalyst_id ~= 0 then
            add_brewing_option(dialog, slot, "catalyst", 0,
                               "Remove Catalyst")
        end
        for _, catalyst in ipairs(PotionService.getCatalysts()) do
            add_brewing_option(dialog, slot, "catalyst", catalyst.id,
                               catalyst.name)
        end
        return dialog:display()
    end

    local function brewing_category(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        if data.operation == "refine" then
            return open_refinement(pid, data.slot)
        elseif data.operation == "infusion" then
            return open_infusions(pid, data.slot)
        end
        return open_catalysts(pid, data.slot)
    end

    open_brew_menu = function(pid, slot)
        local item = PotionService.getEquipped(pid, slot)
        if not item then return false end
        local dialog = DialogWindow.create(pid,
            "Customize " .. GetItemName(item.obj), brewing_category,
            "potion-brewing")
        local refinable = false
        for _, stat in ipairs(PotionService.ROLLABLE_STATS) do
            if PotionService.canRefine(item, stat) then
                refinable = true
                break
            end
        end
        if refinable then
            dialog:addButton("Refine Properties", {
                slot = slot,
                operation = "refine"
            })
        end
        dialog:addButton("Infusions", {slot = slot, operation = "infusion"})
        dialog:addButton("Catalysts", {slot = slot, operation = "catalyst"})
        return dialog:display()
    end

    local function potion_service_choice(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        if data == "refill" then return open_refill(pid) end
        return open_brew_menu(pid, data)
    end

    local function open_potion_services(pid)
        local first = PotionService.getEquipped(pid, 1)
        local second = PotionService.getEquipped(pid, 2)
        if not first and not second then
            failure(pid, "NO POTIONS")
            return false
        end
        local dialog = DialogWindow.create(pid, "Potion Services",
                                           potion_service_choice,
                                           "potion-services")
        local refill = PotionRefillService.quote(pid)
        if refill.available then
            dialog:addButton("Refill All (" .. refill.price .. " Gold)",
                             "refill")
        end
        if first then
            dialog:addButton("Customize " .. GetItemName(first.obj), 1,
                             BlzGetItemIconPath(first.obj))
        end
        if second then
            dialog:addButton("Customize " .. GetItemName(second.obj), 2,
                             BlzGetItemIconPath(second.obj))
        end
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
        label = "BREW / REFILL",
        availability = function(pid)
            return PotionService.getEquipped(pid, 1) ~= nil or
                       PotionService.getEquipped(pid, 2) ~= nil,
                   "NO POTIONS"
        end,
        open = open_potion_services,
    })
    RegisterShopAction('I084', {
        label = "4 PLATINUM",
        availability = function(pid) return service_availability(CurrencyConverterService.quote(pid)) end,
        open = open_converter,
    })
    RegisterShopAction('I101', {
        label = "AVAILABLE",
        availability = function(pid) return service_availability(BackpackUpgradeService.quote(pid, 'I101')) end,
        open = function(pid) return open_upgrade(pid, 'I101') end,
    })
    RegisterShopAction('I102', {
        label = "AVAILABLE",
        availability = function(pid) return service_availability(BackpackUpgradeService.quote(pid, 'I102')) end,
        open = function(pid) return open_upgrade(pid, 'I102') end,
    })
end, Debug and Debug.getLine())
