-- Dialog controllers for shop service entries. These frames collect choices;
-- synchronized gameplay changes remain in TomeService and ShopServices.

OnInit.final("ShopServiceDialogs", function(Require)
    Require('DialogWindow')
    Require('ShopActions')
    Require('ShopRegistry')
    Require('ShopServices')
    Require('Prices')
    Require('TomeService')
    Require('Users')

    PotionMasterServices = {}

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
            ["NO DONOR"] = "Equip the donor flask in the other potion slot.",
            ["NO DONOR AFFIX"] = "The donor flask does not have that affix.",
            ["NO AFFIX SLOT"] = "That flask has no available affix slot.",
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

    local open_restoration_choices
    local open_restoration_ready
    local open_reroll_category

    local function announce_reroll(pid, quote)
        local result = quote.reroll_result
        if not result then return end
        local item_name = GetItemName(quote.item.obj)
        local result_text = "|cffffcc00Reroll Result - " .. item_name ..
                                ":|r " .. result.text
        if result.perfect then
            DisplayTimedTextToForce(FORCE_PLAYING, 20.,
                User[pid - 1].nameColored ..
                    " rolled a |cffffcc00PERFECT|r flask: " .. item_name ..
                    "! " .. result.text)
        elseif result.near_perfect then
            DisplayTimedTextToForce(FORCE_PLAYING, 20.,
                User[pid - 1].nameColored ..
                    " rolled a |cff40bf5fnear-perfect|r flask: " .. item_name ..
                    "! " .. result.text)
        else
            DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 15., result_text)
        end
    end

    local function brewing_confirm(dialog, _, data)
        local quote = PotionBrewingService.commit(dialog.pid, data.slot,
                                                   data.operation, data.value)
        dialog:destroy()
        if not quote.available then
            failure(dialog.pid, quote.reason)
        elseif quote.reroll_options then
            open_restoration_choices(dialog.pid, data.slot,
                                     quote.reroll_options)
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
        elseif data.operation == "reroll" then
            action = "Lock rerolls to " ..
                         PotionService.REROLL_CATEGORY_NAMES[data.value]
        else
            action = "Extract and apply " .. quote.option.name
        end
        local title = data.operation == "reroll" and action .. "?" or
                          action .. " for " .. quote.price ..
                              " |cffffcc00Gold|r?"
        local dialog = DialogWindow.create(pid, title,
            brewing_confirm, "potion-brewing-confirm")
        local confirm = data.operation == "reroll" and
                            "Confirm (" .. quote.price .. " Gold)" or "Confirm"
        dialog:addButton(confirm, data)
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
        local item = PotionService.getStored(pid, slot)
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

    local function stored_slot_name(slot)
        if slot < POTION_INDEX then return "Inventory " .. slot end
        if slot == POTION_INDEX then return "Potion Slot 1" end
        if slot == POTION_INDEX + 1 then return "Potion Slot 2" end
        return "Backpack " .. (slot - BACKPACK_INDEX + 1)
    end

    local function restoration_roll_again(pid, slot, replace_pending)
        local item = PotionService.getStored(pid, slot)
        local category = PotionService.getRerollCategory(item)
        if not category then return false end
        local quote = PotionBrewingService.quote(pid, slot, "reroll", category)
        if not quote.available then
            failure(pid, quote.reason)
            return false
        end
        if replace_pending then PotionBrewingService.rejectReroll(pid, slot) end
        quote = PotionBrewingService.commit(pid, slot, "reroll", category)
        if not quote.available then
            failure(pid, quote.reason)
            return false
        end
        return open_restoration_choices(pid, slot, quote.reroll_options)
    end

    local function restoration_ready_action(dialog, _, slot)
        local pid = dialog.pid
        dialog:destroy()
        if not restoration_roll_again(pid, slot, false) then
            return open_restoration_ready(pid, slot)
        end
        return false
    end

    open_restoration_ready = function(pid, slot)
        local item = PotionService.getStored(pid, slot)
        if not item then return false end
        local category = PotionService.getRerollCategory(item)
        if not category then return open_reroll_category(pid, slot) end
        local quote = PotionBrewingService.quote(pid, slot, "reroll", category)
        local label = "Reroll Again (" .. quote.price .. " Gold"
        if not quote.available then label = label .. " - NOT ENOUGH" end
        label = label .. ")"
        local dialog = DialogWindow.create(pid,
            "Reroll " .. PotionService.REROLL_CATEGORY_NAMES[category],
            restoration_ready_action, "potion-reroll-loop")
        dialog:addButton(label, slot, BlzGetItemIconPath(item.obj))
        return dialog:display()
    end

    local function restoration_choice(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        if data.action == "accept" then
            local quote = PotionBrewingService.acceptReroll(
                              pid, data.slot, data.attempt, data.option)
            if not quote.available then
                failure(pid, quote.reason)
                return open_restoration_ready(pid, data.slot)
            end
            announce_reroll(pid, quote)
            return open_restoration_ready(pid, data.slot)
        elseif data.action == "keep" then
            PotionBrewingService.rejectReroll(pid, data.slot)
            return open_restoration_ready(pid, data.slot)
        end
        if not restoration_roll_again(pid, data.slot, true) then
            local pending = PotionService.getPendingReroll(
                                PotionService.getStored(pid, data.slot))
            if pending then
                return open_restoration_choices(pid, data.slot, pending)
            end
            return open_restoration_ready(pid, data.slot)
        end
        return false
    end

    open_restoration_choices = function(pid, slot, options)
        local item = PotionService.getStored(pid, slot)
        if not item or not options then return false end
        local category_name = options[1].category_name or "Reroll"
        local dialog = DialogWindow.create(pid, category_name .. " Results",
                                           restoration_choice,
                                           "potion-reroll-options")
        for _, option in ipairs(options) do
            local prefix = option.mode_name or ("Option " .. option.option)
            dialog:addButton(prefix .. ": " .. option.text, {
                action = "accept",
                slot = slot,
                attempt = option.attempt,
                option = option.option
            })
        end
        dialog:addButton("Keep Current", {action = "keep", slot = slot})
        local category = PotionService.getRerollCategory(item)
        if not category then
            dialog:destroy()
            return false
        end
        local quote = PotionBrewingService.quote(
                          pid, slot, "reroll", category)
        local reroll_label = "Reroll Again (" .. quote.price .. " Gold"
        if not quote.available then reroll_label = reroll_label .. " - NOT ENOUGH" end
        dialog:addButton(reroll_label .. ")", {
            action = "reroll",
            slot = slot
        })
        return dialog:display()
    end

    local function reroll_category_choice(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        return confirm_brewing(pid, data)
    end

    open_reroll_category = function(pid, slot)
        local item = PotionService.getStored(pid, slot)
        if not item then return false end
        local dialog = DialogWindow.create(pid, "Choose a permanent property",
                                           reroll_category_choice,
                                           "potion-reroll-category")
        for category = PotionService.REROLL_RESTORATION,
            PotionService.REROLL_PREFIX do
            if PotionService.canRerollCategory(item, category) then
                add_brewing_option(
                    dialog, slot, "reroll", category,
                    PotionService.REROLL_CATEGORY_NAMES[category])
            end
        end
        return dialog:display()
    end

    local function reroll_target(dialog, _, slot)
        local pid = dialog.pid
        dialog:destroy()
        local item = PotionService.getStored(pid, slot)
        if not item then return false end
        if PotionService.canReroll(item) then
            local pending = PotionService.getPendingReroll(item)
            if pending then return open_restoration_choices(pid, slot, pending) end
            if PotionService.getRerollCategory(item) then
                return open_restoration_ready(pid, slot)
            end
            return open_reroll_category(pid, slot)
        end
        return false
    end

    local function open_reroll(pid)
        local dialog = DialogWindow.create(pid, "Choose a flask to reroll",
                                           reroll_target,
                                           "potion-reroll-target")
        for _, entry in ipairs(PotionService.getStoredAll(pid)) do
            local item = entry.item
            local refinable = PotionService.canReroll(item)
            if refinable then
                dialog:addButton(stored_slot_name(entry.slot) .. ": " ..
                                     GetItemName(item.obj), entry.slot,
                                 BlzGetItemIconPath(item.obj))
            end
        end
        if dialog.count == 0 then
            dialog:destroy()
            failure(pid, "NOT REFINABLE")
            return false
        end
        return dialog:display()
    end

    local function transfer_donor(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        return confirm_brewing(pid, data)
    end

    local function open_transfer_donors(pid, target_slot, kind)
        local target = PotionService.getStored(pid, target_slot)
        if not target then return false end
        local dialog = DialogWindow.create(pid,
            "Choose a donor. It will be destroyed.", transfer_donor,
            "potion-affix-donor")
        for _, entry in ipairs(PotionService.getStoredAll(pid)) do
            if entry.slot ~= target_slot then
                local available = PotionService.canTransferAffix(
                                      target, entry.item, kind)
                if available then
                    local customization =
                        PotionService.getCustomization(entry.item)
                    local affix = kind == "prefix" and customization.prefix or
                                      customization.suffix
                    dialog:addButton(stored_slot_name(entry.slot) .. ": " ..
                                         affix.name, {
                        slot = target_slot,
                        operation = kind,
                        value = entry.slot
                    }, affix.icon)
                end
            end
        end
        if dialog.count == 0 then
            dialog:destroy()
            failure(pid, "NO DONOR AFFIX")
            return false
        end
        return dialog:display()
    end

    local function transfer_target(dialog, _, data)
        local pid = dialog.pid
        dialog:destroy()
        return open_transfer_donors(pid, data.slot, data.kind)
    end

    local function open_transfer(pid, kind)
        local potions = PotionService.getStoredAll(pid)
        if #potions < 2 then
            failure(pid, "NO DONOR")
            return false
        end
        local dialog = DialogWindow.create(pid,
            "Choose the flask receiving the " .. kind, transfer_target,
            "potion-affix-target")
        for _, entry in ipairs(potions) do
            dialog:addButton(stored_slot_name(entry.slot) .. ": " ..
                                 GetItemName(entry.item.obj), {
                slot = entry.slot,
                kind = kind
            }, BlzGetItemIconPath(entry.item.obj))
        end
        return dialog:display()
    end

    local function has_stored_potion(pid)
        return #PotionService.getStoredAll(pid) > 0
    end

    local function has_transfer_pair(pid)
        return #PotionService.getStoredAll(pid) > 1
    end

    local function open_refill_action(pid)
        if not has_stored_potion(pid) then
            failure(pid, "NO POTIONS")
            return false
        end
        return open_refill(pid)
    end

    ---Adds object-free service entries to the dedicated Potion Master. These
    ---are actions rather than purchasable items, so their detail panel never
    ---leaks presentation from an arbitrary item carrier.
    function PotionMasterServices.addToShop(shop_id, category)
        ShopAddOffer(shop_id, {
            key = "potion_master_refill",
            name = "Refill Flasks",
            tooltip = "Refill every flask in your inventory and backpack.",
            icon = "ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp",
            categories = category,
            availability = function(pid)
                local quote = PotionRefillService.quote(pid)
                if quote.available then return true end
                if quote.reason == "currency" then
                    return false, "NOT ENOUGH"
                end
                return false, quote.reason
            end,
            purchase = open_refill_action
        })
        ShopAddOffer(shop_id, {
            key = "potion_master_reroll",
            name = "Reroll Flask",
            tooltip = "Permanently choose Restoration, Charges, Cooldown, or Prefix as this flask's reroll property. Each attempt offers deterministic choices that may be rejected; repeated rerolls cost substantially more.",
            icon = "ReplaceableTextures\\CommandButtons\\BTNStrongDrink.blp",
            categories = category,
            availability = function(pid)
                return has_stored_potion(pid), "NO POTIONS"
            end,
            purchase = open_reroll
        })
        ShopAddOffer(shop_id, {
            key = "potion_master_prefix",
            name = "Transfer Prefix",
            tooltip = "Transfer a prefix from another flask in your inventory or backpack. The donor flask is destroyed.",
            icon = "ReplaceableTextures\\CommandButtons\\BTNPotionOfVampirism.blp",
            categories = category,
            availability = function(pid)
                return has_transfer_pair(pid), "NO DONOR"
            end,
            purchase = function(pid) return open_transfer(pid, "prefix") end
        })
        ShopAddOffer(shop_id, {
            key = "potion_master_suffix",
            name = "Transfer Suffix",
            tooltip = "Transfer a suffix from another flask in your inventory or backpack. The donor flask is destroyed.",
            icon = "ReplaceableTextures\\CommandButtons\\BTNCloudOfFog.blp",
            categories = category,
            availability = function(pid)
                return has_transfer_pair(pid), "NO DONOR"
            end,
            purchase = function(pid) return open_transfer(pid, "suffix") end
        })
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

    local function purchase_upgrade(pid, id)
        local quote = BackpackUpgradeService.commit(pid, id)
        if not quote.available then
            failure(pid, quote.reason)
        else
            DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20,
                "You successfully upgraded to: " .. quote.name
                    .. " [|cffffcc00Level " .. quote.new_level .. "|r]")
            NotifyShopActionChanged(pid)
        end
        return quote.available
    end

    local function upgrade_availability(pid, id)
        local quote = BackpackUpgradeService.quote(pid, id)
        if quote.available or quote.reason == "currency" then return true end
        return false, quote.reason
    end

    local function upgrade_price(id)
        return function(pid)
            local quote = BackpackUpgradeService.quote(pid, id)
            return {gold = quote.gold or 0, platinum = quote.platinum or 0}
        end
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
    RegisterShopAction('I084', {
        label = "4 PLATINUM",
        availability = function(pid) return service_availability(CurrencyConverterService.quote(pid)) end,
        open = open_converter,
    })
    SetItemPrice('I101', upgrade_price('I101'))
    RegisterShopAction('I101', {
        label = "AVAILABLE",
        availability = function(pid) return upgrade_availability(pid, 'I101') end,
        open = function(pid) return purchase_upgrade(pid, 'I101') end,
        handles_price = true,
    })
    SetItemPrice('I102', upgrade_price('I102'))
    RegisterShopAction('I102', {
        label = "AVAILABLE",
        availability = function(pid) return upgrade_availability(pid, 'I102') end,
        open = function(pid) return purchase_upgrade(pid, 'I102') end,
        handles_price = true,
    })
end, Debug and Debug.getLine())
