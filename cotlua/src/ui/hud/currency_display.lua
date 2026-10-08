-- Currency resource text and automatic-converter controls.

OnInit.final("CurrencyDisplay", function(Require)
    Require('Currency')
    Require('Frames')
    Require('SimpleButton')

    local converter_frame = BlzCreateFrame("QuestButtonDisabledBackdropTemplate", RESOURCE_BAR, 0, 0)
    local convert_button

    local function is_local_player(pid)
        return GetLocalPlayer() == Player(pid - 1)
    end

    ---@param pid integer
    ---@param purchased boolean
    ---@param enabled boolean
    local function refresh_converter(pid, purchased, enabled)
        if not is_local_player(pid) then
            return
        end

        local tooltip = purchased
            and "Convert gold to platinum automatically"
            or "Must purchase a converter to use!"
        BlzFrameSetText(convert_button.tooltip.tooltip, tooltip)
        convert_button:enable(enabled)
    end

    local function on_convert()
        local frame = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        ToggleCurrencyConverter(pid)

        if is_local_player(pid) then
            BlzFrameSetEnable(frame, false)
            BlzFrameSetEnable(frame, true)
            convert_button:enable(IsCurrencyConverterEnabled(pid))
        end
    end

    BlzFrameSetTexture(converter_frame, "trans32.blp", 0, true)
    BlzFrameSetSize(converter_frame, 0.006, 0.006)
    BlzFrameSetPoint(converter_frame, FRAMEPOINT_TOP, RESOURCE_BAR, FRAMEPOINT_TOP, 0, -0.025)

    convert_button = SimpleButton.create(
        converter_frame,
        "ReplaceableTextures\\CommandButtons\\BTNConvert.blp",
        0.017,
        0.017,
        FRAMEPOINT_CENTER,
        FRAMEPOINT_CENTER,
        -0.0975,
        -0.0025,
        on_convert,
        "Must purchase a converter to use!",
        FRAMEPOINT_TOP,
        FRAMEPOINT_BOTTOM
    )
    convert_button:enable(false)

    RegisterCurrencyConverterChangedAction(refresh_converter)
    RegisterCurrencyChangedAction(function(pid, currency, amount)
        if not is_local_player(pid) then
            return
        end
        if currency == HONOR then
            BlzFrameSetText(HONOR_TEXT, amount)
        elseif currency == FACTION then
            BlzFrameSetText(FACTION_TEXT, amount)
        end
    end)

    local local_pid = GetPlayerId(GetLocalPlayer()) + 1
    refresh_converter(
        local_pid,
        HasCurrencyConverter(local_pid),
        IsCurrencyConverterEnabled(local_pid)
    )
    BlzFrameSetText(HONOR_TEXT, GetCurrency(local_pid, HONOR))
    BlzFrameSetText(FACTION_TEXT, GetCurrency(local_pid, FACTION))
end, Debug and Debug.getLine())
