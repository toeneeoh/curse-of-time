--[[
    potion.lua

    Adds custom UI buttons and functionality to potions
]]

OnInit.final("Potion", function(Require)
    Require('Hotkeys')
    Require('ItemEventRegistry')
    Require('PotionService')

    local potion_button = {} ---@type Button[]
    local icon_size = 0.032

    -- Keep persistent potion controls in the ordinary HUD layer. Feature
    -- windows such as Stat View are siblings under ConsoleUIBackdrop and use
    -- higher explicit levels, so they reliably cover the potion subtree.
    local backdrop = BlzCreateFrameByType("BACKDROP", "",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
    BlzFrameSetLevel(backdrop, 5)
    BlzFrameSetSize(backdrop, 0.001, 0.001)
    BlzFrameSetTexture(backdrop, "trans32.blp", 0, true)
    BlzFrameSetAbsPoint(backdrop, FRAMEPOINT_BOTTOM, 0.133, 0.194)
    BlzFrameSetEnable(backdrop, false)
    BlzFrameSetVisible(backdrop, false)

    local use_potion_factory
    local index = 1
    use_potion_factory = function()
        local capture_index = index
        index = index + 1

        return function(pid, is_down)
            if not is_down then return end
            local result = PotionService.use(pid, capture_index)
            if result.success and GetLocalPlayer() == Player(pid - 1) then
                potion_button[capture_index]:cooldown(result.cooldown, pid)
            end
        end
    end

    local use_potion, use_potion2 = use_potion_factory(), use_potion_factory()
    local pot_func = {use_potion, use_potion2}

    local function on_click()
        local f = BlzGetTriggerFrame()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1

        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)

        for i = 1, #potion_button do
            if f == potion_button[i].frame then
                pot_func[i](pid, true)
            end
        end

        return false
    end

    potion_button[1] = Button.create(backdrop, icon_size, icon_size, 0, 0, false)
    potion_button[1]:onClick(on_click)
    potion_button[1]:use_cooldowns()
    potion_button[1]:visible(false)
    RegisterHotkeyToFunc('3', "Use Potion 1", use_potion, potion_button[1].tooltip.nameFrame)

    potion_button[2] = Button.create(backdrop, icon_size, icon_size, icon_size, 0, false)
    potion_button[2]:onClick(on_click)
    potion_button[2]:use_cooldowns()
    potion_button[2]:visible(false)
    RegisterHotkeyToFunc('4', "Use Potion 2", use_potion2, potion_button[2].tooltip.nameFrame)

    local function on_cleanup(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(backdrop, false)
            potion_button[1]:visible(false)
            potion_button[2]:visible(false)
        end
    end

    local function on_setup(pid)
        local has_potion = false
        for i = POTION_INDEX, POTION_INDEX + 1 do
            local pot = Profile[pid].hero.items[i]
            local index = i - POTION_INDEX + 1
            local button = potion_button[index]

            if pot and pot.alive and pot.type == TYPE_POTION_INDEX then
                has_potion = true
                PotionService.refreshItem(pot)
                local name, icon, description = PotionService.describe(pot)
                if GetLocalPlayer() == Player(pid - 1) then
                    button:visible(true)
                    button:charge(pot.charges)
                    button.tooltip:name(name .. " '" .. GetHotkeyForFunc(pid, pot_func[index]) .. "'")
                    button:icon(icon)
                    button.tooltip:icon(icon)
                    button.tooltip:text(description)
                    button:enabled(pot.charges >= 1 and true or false)
                    local remaining = PotionService.getCooldown(pid, index)
                    if remaining > 0. and
                        (button.cooldown_time[pid] <= 0. or
                            remaining > button.cooldown_time[pid] + 0.1) then
                        button:cooldown(remaining, pid,
                                        math.max(remaining,
                                                 PotionService.getUseCooldown(
                                                     pot)))
                    end
                end
            else
                if GetLocalPlayer() == Player(pid - 1) then
                    button:visible(false)
                end
            end
        end

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(backdrop, has_potion)
        end
    end

    POTION = {}
    POTION.refresh = function(pid)
        on_setup(pid)
    end

    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        EVENT_ON_SETUP:register_action(U.id, on_setup)
        U = U.next
    end

end, Debug and Debug.getLine())
