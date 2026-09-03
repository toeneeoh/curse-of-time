--[[
    buffbar.lua

    Adds custom UI for buff status on units
]]

OnInit.final("BuffBar", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('Events')

    --#region frame setup
    local backdrop = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
    local buff_buttons = {} ---@type Button[]
    BlzFrameSetSize(backdrop, 0.001, 0.001)
    BlzFrameSetTexture(backdrop, "trans32.blp", 0, true)
    BlzFrameSetAbsPoint(backdrop, FRAMEPOINT_BOTTOM, 0.205, 0.165)
    BlzFrameSetEnable(backdrop, false)

    local ICON_SIZE = 0.025
    local MAX_BUFFS = 20

    for i = 1, MAX_BUFFS do
        local x_offset = math.fmod(i - 1, 10)
        local y_offset = (i - 1) // 10
        local btn = Button.create(backdrop, ICON_SIZE, ICON_SIZE, x_offset * ICON_SIZE, y_offset * ICON_SIZE, false)
        buff_buttons[i] = btn

        btn:use_cooldowns()
        BlzFrameSetScale(btn.cooldownFrame, 0.666)
        BlzFrameSetScale(btn.cooldownText, 1.25)
        btn:visible(false)
        btn:use_click_placeholder()

        btn.tooltip:point(FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_TOPLEFT, 0.005, 0.005)
        BlzFrameClearAllPoints(btn.chargeFrame)
        BlzFrameSetPoint(btn.chargeFrame, FRAMEPOINT_BOTTOMRIGHT, btn.iconFrame, FRAMEPOINT_BOTTOMRIGHT, 0., 0.)
        BlzFrameSetSize(btn.chargeFrame, ICON_SIZE * 0.45, ICON_SIZE * 0.45)
        BlzFrameSetScale(btn.chargeText, 0.95)
        BlzFrameSetLevel(btn.chargeFrame, 20)
    end
    --#endregion

    local viewing = {} ---@type table<integer, unit>

    -- prelocals for parse_desc
    local format = string.format
    local abs = math.abs
    local floor = math.floor
    local tostring = tostring

    local function parse_desc(buff)
        if not buff.DESC then
            return ""
        end

        -- matches:
        --   $ = exact
        --   # = inverse
        --   ^ = percentage
        --   ! = no rounding
        --   @ = abs value
        return (buff.DESC:gsub("(%@?)(%!?)(%^?)([%$#])([%w_]+)", function(absolute, round, caret, prefix, key)
            local v = buff[key]
            if v == nil then
                return key
            end

            -- percentage symbol
            if caret ~= "" then
                v = v * 100
            end

            -- inverse symbol
            if prefix == "#" then
                v = abs(100 - v)
            end

            -- abs symbol
            if absolute == "@" then
                v = abs(v)
            end

            if type(v) == "number" then
                if round == "" then
                    v = floor(v + 0.5)
                elseif round == "!" then
                    v = format("%.2f", v)
                end
            end

            return "|cffffcc00" .. tostring(v) .. "|r"
        end))
    end

    local function refresh_buff(buff)
        local button = buff_buttons[buff.index]
        if not button then
            return
        end

        local desc = parse_desc(buff)
        local name = buff.NAME
        if buff.level then
            name = name .. " (Level |cffffcc00" .. buff.level .. "|r)"
        end

        local u = viewing[GetPlayerId(GetLocalPlayer()) + 1]

        if u == buff.target then
            button:visible(true)
            button:icon(buff.ICON)
            button.tooltip:icon(buff.ICON)
            button.tooltip:text(desc)
            button.tooltip:name(buff.DISPEL_TYPE == BUFF_NEGATIVE and "|cffFF0000" .. name .. "|r" or "|cff00FF00" .. name .. "|r")
            button:charge(buff.charges or 0)
        end
    end

    ---@type fun(u: Unit, pid: integer)
    local function update(u, pid)
        local is_local = (GetLocalPlayer() == Player(pid - 1))

        if not u.buffs then
            if is_local then
                BlzFrameSetVisible(backdrop, false)
            end
            return
        end

        if is_local then
            BlzFrameSetVisible(backdrop, UnitAlive(u.unit))
        end

        for i = 1, MAX_BUFFS do
            local buff = u.buffs[i]
            local button = buff_buttons[i]

            if buff then
                refresh_buff(buff)

                local remaining = buff:remaining()
                if remaining and not buff.AURA then
                    button:cooldown(remaining, pid, buff:timeout())
                elseif is_local then
                    BlzFrameSetVisible(button.cooldownFrame, false)
                end
            else
                if is_local then
                    button:visible(false)
                end
            end
        end
    end

    ---@type fun(u: Unit, pid: integer?)
    local function display(u, pid)
        -- display / refresh for one player
        if pid then
            update(u, pid)
        else
        -- display / refresh for every player viewing unit
            for pid, unit in pairs(viewing) do
                if unit == u.unit then
                    update(u, pid)
                end
            end
        end
    end

    Buff.onChange(function(u, buff, change)
        if change == "refresh" and buff and buff.index then
            refresh_buff(buff)
        else
            display(Unit[u])
        end
    end)

    local function on_select(pid, u)
        viewing[pid] = u
        local selected = u and Unit[u]

        if selected then
            display(selected, pid)
        elseif GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(backdrop, false)
        end
    end

    local function on_cleanup(pid)
        viewing[pid] = nil
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(backdrop, false)
        end
    end

    local U = User.first
    while U do
        EVENT_ON_SELECT:register_action(U.id, on_select)
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end

end, Debug and Debug.getLine())
