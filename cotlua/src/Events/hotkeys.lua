--[[
    hotkeys.lua

    A library that implements custom hotkeys for functions with hotkey customization.
]]

OnInit.final("Hotkeys", function(Require)
    Require('Users')
    Require('Variables')

    local hotkey_functions
    local changing_keybinds = {}
    local key_state = array2d(false) ---@type boolean[][]
    local key_bindings = {} ---@type table<integer, table<string, table<function>>>

    local function get_key_for_function(pid, target_func)
        if not key_bindings[pid] then
            return nil
        end

        for key_string, bound_functions in pairs(key_bindings[pid]) do
            for _, func in ipairs(bound_functions) do
                if func == target_func then
                    return key_string
                end
            end
        end

        return nil
    end

    local function update_state(pid, key_string, is_down)
        if key_state[pid][key_string] == is_down then
            return true
        end
        key_state[pid][key_string] = is_down

        return false
    end

    local function update_action_tooltip(pid, key_string, action)
        for _, func in ipairs(hotkey_functions) do
            if func.func == action then

                if func and func.frame then
                    local text = BlzFrameGetText(func.frame)

                    text = string.gsub(text, "('.-')", function()
                        return "'" .. key_string .. "'"
                    end)

                    if GetLocalPlayer() == Player(pid - 1) then
                        BlzFrameSetText(func.frame, text)
                    end
                end

                break
            end
        end
    end

    local function unregister_key_binding(pid, key_string, action)
        if key_bindings[pid] and key_bindings[pid][key_string] then
            TableRemove(key_bindings[pid][key_string], action)
        end
    end

    ---@type fun(pid: integer, key_string: string, action: function, immutable: boolean?)
    local function register_key_binding(pid, key_string, action, immutable)
        
        -- create tables if nil
        if not key_bindings[pid] then
            key_bindings[pid] = {}
        end
        if not key_bindings[pid][key_string] then
            key_bindings[pid][key_string] = {}
        end

        if not immutable then
            -- unbind previous key for action
            local prev = get_key_for_function(pid, action)
            if prev then
                unregister_key_binding(pid, prev, action)
            end
        end

        -- add action to key table
        key_bindings[pid][key_string][#key_bindings[pid][key_string] + 1] = action
        update_action_tooltip(pid, key_string, action)
    end

    local event_on_unit_select, event_on_select = EVENT_ON_UNIT_SELECT, EVENT_ON_SELECT

    local function select_delay(pid)
        local u = GetMainSelectedUnit()
        if u then
            BlzFrameSetVisible(HIDE_HEALTH_FRAME, (u and Unit[u] and Unit[u].hidehp))

            event_on_unit_select:trigger(u, pid)
            event_on_select:trigger(pid, u)
        end
    end

    local function update_ui(pid, _)
        TimerQueue:callDelayed(0., select_delay, pid)
    end

    local function on_rebind()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            local key = dw.data[index]
            DisplayTextToPlayer(Player(pid - 1), 0, 0, "Press a key to rebind " .. hotkey_functions[index + 1].name)
            changing_keybinds[pid] = {key = key, func = hotkey_functions[index + 1].func}

            dw:destroy()
        end

        return false
    end

    local function open_hotkey_dialog(pid)
        if DialogWindow[pid] then
            return
        end

        local dw = DialogWindow.create(pid, "Re-assign hotkeys", on_rebind)

        for _, v in ipairs(hotkey_functions) do
            local key = get_key_for_function(pid, v.func)
            dw:addButton("|cffffffff" .. v.name .. ":|r " .. (key or ""), key)
        end

        dw:display()
    end

    local function open_inventory(pid, is_down)
        if is_down then
            INVENTORY.display(pid, pid)
        end
    end

    local function open_stats(pid, is_down)
        if is_down then
            STAT_WINDOW.display(Hero[pid], pid)
        end
    end

    local function inspect_stats(pid, is_down)
        if is_down then
            local u = PLAYER_SELECTED_UNIT[pid]
            if u then
                STAT_WINDOW.display(u, pid)
            end
        end
    end

    local function inspect_inventory(pid, is_down)
        if is_down then
            local u = PLAYER_SELECTED_UNIT[pid]
            if u then
                local tpid = GetPlayerId(GetOwningPlayer(u)) + 1
                INVENTORY.display(pid, tpid)
            end
        end
    end

    local function toggle_auto_attack(pid, is_down)
        if is_down then
            ToggleAutoAttack(pid)
        end
    end

    local function clear_text(pid, is_down)
        if is_down then
            if Player(pid - 1) == GetLocalPlayer() then
                ClearTextMessages()
            end
        end
    end

    local esc_functions = {}

    function AddToEsc(f)
        esc_functions[#esc_functions + 1] = f
    end

    local function close_all_windows(pid, is_down)
        if is_down then
            for _, v in ipairs(esc_functions) do
                v(pid)
            end
        end
    end

    local function second_spell_special_cast(pid, is_down)
        if is_down then
            -- shatter frozen orb early
            local missile = FROZENORB.missile[pid]

            if missile then
                ALICE_Kill(missile)
            end

            -- cancel hidden guise early
            local pt = TimerList[pid]:get(HIDDENGUISE.id)

            if pt then
                HIDDENGUISE.expire(pt)
            end
        end
    end

    local key_mapper = {
        [0x08] = 'BACKSPACE',
        [0x1B] = 'ESC',
        [0xBC] = ',',
        [0xBE] = '.',
        [0xBF] = '/',
        [0xBA] = ';',
        [0xDE] = '\'',
        [0xDB] = '[',
        [0xDD] = ']',
        [0xBD] = '-',
        [0xBB] = '=',
        [0x70] = 'F1',
        [0x71] = 'F2',
        [0x72] = 'F3',
        [0x73] = 'F4',
        [0x75] = 'F6',
        [0x76] = 'F7',
        [0x77] = 'F8',
    }

    -- build reverse lookup for key_mapper
    local string_to_keycode = {}
    for code, name in pairs(key_mapper) do
        string_to_keycode[name] = code
    end

    local meta_keys = {
        [0xA0] = 'SHIFT',
        [0xA2] = 'CTRL',
        [0xA4] = 'ALT',
    }

    local meta_shift = 0x1
    local meta_ctrl = 0x2
    local meta_alt = 0x4

    --- Packs a key‑string (e.g. "CTRL+A", "F1", "/", "ALT+ALT") into an integer.
    --- @param key_string string
    --- @return integer packed
    local function key_string_to_int(key_string)
        local meta_bits = 0
        local base = key_string

        -- split off any single prefix "SHIFT+" / "CTRL+" / "ALT+"
        local prefix, rest = key_string:match("(\x25a+)+?(.+)")
        if     prefix == "SHIFT" then meta_bits = meta_shift; base = rest
        elseif prefix == "CTRL"  then meta_bits = meta_ctrl;  base = rest
        elseif prefix == "ALT"   then meta_bits = meta_alt;   base = rest
        end

        -- look up code; fall back to ASCII
        local code = string_to_keycode[base] or base:byte()
        return meta_bits * 256 + code
    end

    --- Unpacks an integer back into the exact same hotkey string.
    --- @param packed integer
    --- @return string key_string
    local function key_int_to_string(packed)
        local meta_bits = math.floor(packed / 256)
        local code      = packed - meta_bits * 256

        -- recover the base name
        local name = key_mapper[code] or string.char(code)

        -- re‑apply any prefix
        if     meta_bits == meta_shift then
            return "SHIFT+" .. name
        elseif meta_bits == meta_ctrl  then
            return "CTRL+"  .. name
        elseif meta_bits == meta_alt   then
            return "ALT+"   .. name
        else
            return name
        end
    end

    local function on_key_input()
        local key = GetHandleId(BlzGetTriggerPlayerKey())
        local meta = BlzGetTriggerPlayerMetaKey()
        local is_down = BlzGetTriggerPlayerIsKeyDown()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer
        local to_char = string.char(key)
        local key_string = key_mapper[key] or meta_keys[key] or to_char
        local invalid_char = not key_mapper[key] and (key < 0x30 or key > 0x77)

        if 0 ~= meta & meta_shift then
            key_string = "SHIFT+" .. key_string
        elseif 0 ~= meta & meta_ctrl then
            key_string = "CTRL+" .. key_string
        elseif 0 ~= meta & meta_alt then
            key_string = "ALT+" .. key_string
        end

        -- prevent multiple triggers
        if not meta_keys[key] and update_state(pid, key_string, is_down) then
            return
        end

        if changing_keybinds[pid] and not meta_keys[key] then -- prevent binding to only meta keys
            if invalid_char then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Invalid character!")
            else
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Successfully rebound to \'" .. key_string .. "\'")
                unregister_key_binding(pid, changing_keybinds[pid].key, changing_keybinds[pid].func)
                register_key_binding(pid, key_string, changing_keybinds[pid].func)
            end
            changing_keybinds[pid] = nil
            return false
        end

        -- Check for a binding and execute the bound function if it exists
        local bound_functions = key_bindings[pid] and key_bindings[pid][key_string]
        if bound_functions then
            for _, key_function in ipairs(bound_functions) do
                key_function(pid, is_down)
            end
        end

        return false
    end

    hotkey_functions = {
        {
            name = "Close Windows",
            func = close_all_windows,
        },
        {
            name = "Clear Text",
            func = clear_text,
        },
        {
            name = "Toggle Auto Attack",
            func = toggle_auto_attack,
        },
        {
            name = "View Inventory",
            func = open_inventory,
        },
        {
            name = "View Stats",
            func = open_stats,
        },
        {
            name = "Inspect Stats",
            func = inspect_stats,
        },
        {
            name = "Inspect Inventory",
            func = inspect_inventory,
        },
        {
            name = "Spell 2 Second Cast",
            func = second_spell_special_cast,
        },
    }

    -- associates an external frame with a hotkey action
    function RegisterHotkeyTooltip(table, index)
        local frame = table

        while type(frame) == "table" do
            frame = frame.tooltip
        end

        hotkey_functions[index].frame = frame
    end

    -- sets up a default key for external hotkeys in SetupDefaultHotkeys
    local default_extension = {}

    -- main function to define hotkey to func outside of this library
    ---@type fun(hotkey: string, name: string?, func: function, frame: framehandle?, immutable: boolean?): integer
    function RegisterHotkeyToFunc(hotkey, name, func, frame, immutable)
        local index = #hotkey_functions + 1

        if not immutable then
            hotkey_functions[index] = {name = name, func = func}
            if frame then
                RegisterHotkeyTooltip(frame, index)
            end
        end
        default_extension[#default_extension + 1] = {default = hotkey, func = func}

        local U = User.first

        while U do
            register_key_binding(U.id, hotkey, func, immutable)
            U = U.next
        end

        return index
    end

    function ChangeHotkeys(pid)
        open_hotkey_dialog(pid)
    end

    function GetHotkeyTable()
        return hotkey_functions
    end

    function GetHotkeyForFunc(pid, func)
        return get_key_for_function(pid, func)
    end

    function SaveHotkey(pid, index)
        if hotkey_functions[index] then
            return key_string_to_int(get_key_for_function(pid, hotkey_functions[index].func))
        end
    end

    function LoadHotkey(pid, hotkey, index)
        local key_string = key_int_to_string(hotkey)
        register_key_binding(pid, key_string, hotkey_functions[index].func)
    end

    function SetupDefaultHotkeys(pid)
        register_key_binding(pid, 'I', open_inventory)
        register_key_binding(pid, 'B', open_stats)
        register_key_binding(pid, 'Y', inspect_stats)
        register_key_binding(pid, 'U', inspect_inventory)
        register_key_binding(pid, 'ESC', close_all_windows)
        register_key_binding(pid, 'ESC', clear_text)
        register_key_binding(pid, 'W', second_spell_special_cast)
        register_key_binding(pid, 'CTRL+A', toggle_auto_attack)

        for _, v in ipairs(default_extension) do
            register_key_binding(pid, v.default, v.func)
        end
    end

    local t = CreateTrigger()
    TriggerAddCondition(t, Condition(on_key_input))

    local U = User.first

    while U do
        -- immutable hotkeys
        for i = 0, 9 do
            register_key_binding(U.id, tostring(i), update_ui, true)
        end
        register_key_binding(U.id, 'F1', update_ui, true)
        register_key_binding(U.id, 'F2', update_ui, true)
        register_key_binding(U.id, 'F3', update_ui, true)
        register_key_binding(U.id, 'F4', update_ui, true)

        for k = 0x00, 0xFF do
            local key = ConvertOsKeyType(k)
            for meta = 0, 15 do
                BlzTriggerRegisterPlayerKeyEvent(t, U.player, key, meta, true)
                BlzTriggerRegisterPlayerKeyEvent(t, U.player, key, meta, false)
            end
        end
        U = U.next
    end
end, Debug and Debug.getLine())
