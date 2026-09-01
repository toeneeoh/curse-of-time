--[[ TasSpellView 1.2 by Tasyen
    A library that allows players to view spells of units they do not own on the command card with
    custom UI.

    https://www.hiveworkshop.com/threads/tasspellview.349600/

TasSpellView.AddTechReq(skillCode, techCode[, techAmount])
    skillCode requires TechCode of level techAmount techamount is 1 when not provided
    each adds 1 more requirment
    TasSpellView.AddTechReq('Ahwd','Rowd',2)
TasSpellView.AddUnitSkill(unitCode, skillCode)
    units of unitCode have skillCode, you can this multiple times for one unitCode with different skillCodes or once with many skillCodes in one string
    adding skills disables autodetect for units of that unitcode, autodetect works better in Reforged than in Warcraft 3 V1.31.1
    TasSpellView.AddUnitSkill('unec', 'Acri,Arai,Auhf,Aiun')
    TasSpellView.AddUnitSkill('unec', 'Acri')
]]

OnInit.final("SpellView", function(Require)
    -- spells disabled on spellview
    local disabled_spells = {
        -- backpack utilities
        [DETECT_LEAVE_ABILITY] = 1,
        [0] = 1,
        [FourCC('A04M')] = 1, -- Cosmetics
        [FourCC('A0KX')] = 1, -- Change Skin
        [FourCC('A04N')] = 1, -- Special Effects

        -- hero utilities
        [FourCC('A00B')] = 1, -- Movement Toggle
        [FourCC('A02T')] = 1, -- Hero Panels
        [FourCC('A031')] = 1, -- Damage Numbers
        [FourCC('A067')] = 1, -- Deselect Backpack
        [FourCC('A00F')] = 1, -- Settings
        [FourCC('A00Y')] = 1, -- Item Drops

        -- dummy spells
        [FourCC('A06K')] = 1, -- Forced Meta
        [FourCC('A0A3')] = 1, -- Multi-Shot
        [FourCC('A00N')] = 1, -- Song of Fatigue
        [FourCC('A01A')] = 1, -- Song of Harmony
        [FourCC('A09X')] = 1, -- Song of Peace
        [FourCC('A024')] = 1, -- Song of War
    }

    TasSpellView = {
        AutoRun = true --(true) will create Itself at 0s, (false) you need to InitSpellView() or InitTasSpellView()
        ,ParentFuncSimple = function()
            if GetHandleId(BlzGetFrameByName("CommandBarFrame", 0)) > 0 then return BlzGetFrameByName("CommandBarFrame",  0) end
            return BlzGetFrameByName("ConsoleUI", 0)
        end
        ,ParentFunc = function()
         --   if GetHandleId(BlzGetFrameByName("ConsoleUIBackdrop", 0)) > 0 then return BlzGetFrameByName("ConsoleUIBackdrop",  0) end
            return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        end
        ,TextFormat0 = "\x25.0f"
        ,TextFormat1 = "\x25.1f"
        ,TextReplace = "\x25\x25d"
        ,TextDisallowed = "X" -- display this when not allowed by tech data in chargebox
        ,UpdateTime = 0.1 -- lower number is faster
        -- allowed Unit can be further custimzed in function this.ShowAllowed
        ,ShowHero = true
        ,ShowAlly = true -- can see skills of friends
        ,ShowEnemy = true -- can see skills of enemies, includes hostile creeps
        ,ShowNeutral = true -- can see skills of Neutral Players, includes hostile creeps
        ,UseCommandCardPos = true -- display skills as object editor setup says, taking a slot twice will not show some skils. for Non heroes
        ,UseCommandCardPosHero = true --^^ for hero & hero-illusion
        ,ShowCooldown = true -- can be async, needs BlzGetAbilityId for ability by index 
        ,ShowCooldownText = true -- show remaining cooldown text overlay requires BlzGetAbilityId or setup in UnitSkills
        ,ShortBigNumber = true -- Display values greater than 9999, in thousands like 10k or 100k for Range,Mana,Area
        ,ToolTipSizeX = 0.26
        ,ToolTipPosX = 0.79
        ,ToolTipPosY = 0.165
        ,ToolTipPos = FRAMEPOINT_BOTTOMRIGHT
        ,Data = {} -- temp display data
        ,UnitSkills = {
            -- you can store the abilities shown for that unitCode
            --, otherwise the system will show the abilites found by index which pass the filter
            -- TasSpellView.AddUnitSkill fills this
            -- [FourCC'Ulic'] = {[1]= FourCC'AUfn',[2]= FourCC'AUfu',[3]= FourCC'AUdr',[4]= FourCC'AUdd'}
        }
        ,IdData = { -- stores Ability to FourCC in Warcraft 3 V1.31.1, does nothing when BlzGetAbilityId is found
            Enabled = 2
            -- 0 -> disable this feature
            -- 1 -> create Learn_Skill Trigger
            -- 2 -> create SPELL_EFFECT Trigger ^^
            -- 3 -> hook UnitAddAbility ^^
        } 
        ,TechReq = {} -- TasSpellView[FourCC'AHhb'] = {FourCC'hfoo', 1, FourCC'hsor', 2}
        ,Frame = {Tooltip = {}} -- [0 to 11] = {Button=y,Icon=y,...}        
    }
    local this = TasSpellView
    local thisTooltip = this.Frame.Tooltip
    function this.ShowAllowed(unit, localPlayer)
            local controlType = GetHandleId(GetPlayerController(GetOwningPlayer(unit))) -- user = 0 computer = 1, treat all above as Neutral
            if this.ShowNeutral and controlType >= 2 then return true end

            if not this.ShowAlly and IsUnitAlly(unit, localPlayer) then return false end
            if not this.ShowEnemy and IsUnitEnemy(unit, localPlayer) then return false end
            if not this.ShowHero and IsHeroUnitId(GetUnitTypeId(unit)) then return false end

            return true
        end
    function this.IdString2IdArray(x)
        local result = {}
        local startIndex = 1
        while startIndex + 3 <= string.len(x)  do
            local skillCode = string.sub(x, startIndex, startIndex + 3)
            startIndex = startIndex + 5
            skillCode = FourCC(skillCode)
            table.insert(result, skillCode)
        end
        return result
    end
    this.AddTechReq = function(skillCode, techCode, techAmount)
        if  type(skillCode) == "string" then skillCode = FourCC(skillCode) end
        if not this.TechReq[skillCode] then this.TechReq[skillCode] = {} end
        if  type(techCode) == "string" then techCode = FourCC(techCode) end
        table.insert(this.TechReq[skillCode], techCode)
        table.insert(this.TechReq[skillCode], techAmount or 1)
    end
    this.AddUnitSkill = function(unitCode, skillCode)
        if type(unitCode) == "string" then unitCode = FourCC(unitCode) end
        if not this.UnitSkills[unitCode] then this.UnitSkills[unitCode] = {} end
        if type(skillCode) == "string" then
            if string.len( skillCode ) >4 then
                for i, v in ipairs(this.IdString2IdArray(skillCode)) do table.insert(this.UnitSkills[unitCode], v) end
            else
                if  type(skillCode) == "string" then skillCode = FourCC(skillCode) end
                table.insert(this.UnitSkills[unitCode], skillCode)
            end
        else
            table.insert(this.UnitSkills[unitCode], skillCode)
        end
    end

    local AbilityCache = {}
    local testSkill = FourCC('AHre') -- should not be used in the map
    function this.GetField(abiCode, tag, convertFunc, formatTag)
        if not formatTag then formatTag = "" end
        -- was this ability already parsed?
        if not AbilityCache[abiCode] then
            AbilityCache[abiCode] = {}
            AbilityCache[abiCode].String = string.pack(">I4", abiCode) -- store the result
        end
        if not AbilityCache[abiCode][tag] then
            -- calc it and store it
            -- have ParseTags native?
            if ParseTags then
                AbilityCache[abiCode][tag] = ParseTags("<"..AbilityCache[abiCode].String..","..tag..formatTag..">")
            else
                --local backup = BlzGetAbilityExtendedTooltip(abiCode, 0)
                BlzSetAbilityExtendedTooltip(testSkill, "<"..AbilityCache[abiCode].String..","..tag..formatTag..">", 0)
                AbilityCache[abiCode][tag] = BlzGetAbilityExtendedTooltip(testSkill, 0)
                --BlzSetAbilityExtendedTooltip(abiCode, backup, 0)
            end
            if convertFunc then AbilityCache[abiCode][tag] = convertFunc(AbilityCache[abiCode][tag]) end
        end
        return AbilityCache[abiCode][tag]
    end

    function this.AbiFilter(abi, text)
        if BlzGetAbilityBooleanField(abi, ABILITY_BF_ITEM_ABILITY) then return false end

        local posY = BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_Y)
        if posY == -11 then return false end

        local pos = BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_X) + posY*4
        if pos < 0 or pos > 11 then return false end

        if text == "Tool tip missing!" or text == "" or text == " " then return false end

        local id = BlzGetAbilityId(abi)
        if disabled_spells[id] then return false end

        return true
    end
    this.GetUnitDataAddSkill = function(unit, index, skill)
        local i = index
        if not this.Data[i] then this.Data[i] = {} end
        local data = this.Data[i]
        if not skill then skill = data.FourCC
        else data.FourCC = skill end
        local abi = BlzGetUnitAbility(unit, skill)
        local level = GetUnitAbilityLevel(unit, skill)
        data.Used = true
        data.Icon = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_ICON_NORMAL, math.max(0, level - 1))
        if data.Icon == "" then data.Icon = BlzGetAbilityIcon(skill) end
        BlzFrameSetTexture(this.Frame[i].Icon, data.Icon, 0, false)
        if level > 0 then
            data.Mana = BlzGetUnitAbilityManaCost(unit, skill, level - 1)
            data.Cool = BlzGetUnitAbilityCooldown(unit, skill, level - 1)
            data.Range = R2I(BlzGetAbilityRealLevelField(abi, ABILITY_RLF_CAST_RANGE, level - 1))
            data.Area = R2I(BlzGetAbilityRealLevelField(abi, ABILITY_RLF_AREA_OF_EFFECT, level - 1))
            data.Name = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_TOOLTIP_NORMAL, level - 1)
            data.Text = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED, level - 1)
        else
            data.Name =  BlzGetAbilityResearchTooltip(skill, 0)
            data.Text = BlzGetAbilityResearchExtendedTooltip(skill, 0)
            data.Mana = BlzGetAbilityManaCost(skill, 0)
            data.Cool = BlzGetAbilityCooldown(skill, 0)
            data.Range = R2I(this.GetField(skill, "Rng1"))
            data.Area = R2I(this.GetField(skill, "Area1"))
        end
        if this.ShortBigNumber then
            if data.Mana > 9999 then
                data.Mana = string.format(this.TextFormat0, data.Mana/1000).."k"
            end
            if data.Range > 9999 then
                data.Range = string.format(this.TextFormat0, data.Range/1000).."k"
            end
            if data.Area > 9999 then
                data.Area = string.format(this.TextFormat0, data.Area/1000).."k"
            end
        end
        abi = nil
    end

    local function FindDisplayPosition(preferred)
        if preferred >= 0 and preferred <= 11 and this.Data[preferred].FourCC == 0 and not this.Data[preferred].Used then
            return preferred
        end

        for pos = 0, 11 do
            if this.Data[pos].FourCC == 0 and not this.Data[pos].Used then
                return pos
            end
        end

        return -1
    end

    this.GetUnitData = function(unit)
        local unitCode = GetUnitTypeId(unit)
        local isHero = IsHeroUnitId(unitCode)
        local commandCardPos = (not isHero and this.UseCommandCardPos) or (isHero and this.UseCommandCardPosHero)
        for i= 0, 11 do this.Data[i].FourCC = 0 this.Data[i].Used = false end
        if not unit or unitCode == 0 then return end

        -- have presaved Data
        if this.UnitSkills[unitCode] then
            if commandCardPos then
                for i, v in ipairs(this.UnitSkills[unitCode]) do 
                    local pos = FindDisplayPosition(BlzGetAbilityPosX(v) + BlzGetAbilityPosY(v)*4)
                    if pos >= 0 then this.Data[pos].FourCC = v end
                end
                -- only these are displayed, only add upto 11 skills and only get text/icons/data once for each slot
                for i= 0, 11 do
                    if this.Data[i].FourCC > 0 then
                        this.GetUnitDataAddSkill(unit, i)
                    end
                end
            else
                for i= 0, 11 do
                    local skill = this.UnitSkills[unitCode][i + 1]
                    if skill then this.GetUnitDataAddSkill(unit, i, skill) end
                end
            end
        else
            local addCount = 0
            local abi
            for i = 0, 9999 do
                if addCount > 11 then break end -- only 12 fit into the commandcard starts addcount is increased afterwards therefore bigger then 11
                abi = BlzGetUnitAbilityByIndex(unit, i)
                if not abi then break end
                if this.AbiFilter(abi, BlzGetAbilityStringLevelField(abi, ABILITY_SLF_TOOLTIP_NORMAL, 0)) then

                    if BlzGetAbilityId or this.IdData[abi] then
                        -- treat it like MOD_ABI_CODE
                        if this.IdData[abi] then abi = this.IdData[abi]
                        elseif BlzGetAbilityId then abi = BlzGetAbilityId(abi)
                        end

                        if commandCardPos then
                            local pos = FindDisplayPosition(BlzGetAbilityPosX(abi) + BlzGetAbilityPosY(abi)*4)
                            if pos >= 0 then
                                this.Data[pos].FourCC = abi
                                this.GetUnitDataAddSkill(unit, pos)
                            end
                        else
                            this.GetUnitDataAddSkill(unit, addCount, abi)
                        end
                    else
                        local insertPos = addCount
                        if commandCardPos then
                            local pos = BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_X) + BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_Y)*4
                            insertPos = FindDisplayPosition(pos)
                        end
                        if insertPos < 0 then break end
                        -- store the data
                        local data = this.Data[insertPos]
                        data.Used = true
                        data.Icon = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_ICON_NORMAL, 0)
                        BlzFrameSetTexture(this.Frame[insertPos].Icon, data.Icon, 0, false)
                        data.Name = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_TOOLTIP_NORMAL, 0)
                        data.Text = BlzGetAbilityStringLevelField(abi, ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED, 0)
                        data.Mana = BlzGetAbilityIntegerLevelField(abi, ABILITY_ILF_MANA_COST, 0)
                        data.Cool = BlzGetAbilityRealLevelField(abi, ABILITY_RLF_COOLDOWN, 0)
                        data.Range = R2I(BlzGetAbilityRealLevelField(abi, ABILITY_RLF_CAST_RANGE, 0))
                        data.Area = R2I(BlzGetAbilityRealLevelField(abi, ABILITY_RLF_AREA_OF_EFFECT, 0))
                        if this.ShortBigNumber then
                            if data.Mana > 9999 then
                                data.Mana = string.format(this.TextFormat0, data.Mana/1000).."k"
                            end
                            if data.Range > 9999 then
                                data.Range = string.format(this.TextFormat0, data.Range/1000).."k"
                            end
                            if data.Area > 9999 then
                                data.Area = string.format(this.TextFormat0, data.Area/1000).."k"
                            end
                        end
                    end
                    addCount = addCount + 1
                end
            end
            abi = nil
        end
    end

    local LastHoveredIndex, LastUnit, LastUnitCode
    function this.TechFullFilled(player, skill)
        local data = this.TechReq[skill]
        if not data then return true end
        local lastIndex = #data
        for i=1,lastIndex,2 do
            if GetPlayerTechCount(player, data[i], true) < data[i + 1] then return false end
        end
    end

    function this.Update()
        -- check for visible buttons, if any is visible then do not show TasSpellView
        for i= 0, 11 do
            if BlzFrameIsVisible(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i)) then
                BlzFrameSetVisible(this.ParentSimple, false)
                BlzFrameSetVisible(this.Parent, false)
                LastUnit = nil
                return
            end
        end

        local foundTooltip = false
        local unit
        local localPlayer = GetLocalPlayer()
        local unitCode

        GroupEnumUnitsSelected(this.Group, localPlayer, nil)
        unit = FirstOfGroup(this.Group)
        GroupClear(this.Group)

        -- from this point you need to clear unit = nil !!!
        unitCode = GetUnitTypeId(unit)
        if unit ~= LastUnit or LastUnitCode ~= unitCode then
            -- happen only when a new unit is selected or the unit morphed
            LastUnit = unit
            LastUnitCode = unitCode
            this.GetUnitData(unit)
            LastHoveredIndex = -1
            for i = 0, 11 do
                local dataI = this.Data[i]
                local obj = this.Frame[i]
                BlzFrameSetVisible(obj.Button, dataI.Used)
                
                if dataI.FourCC <= 0 then
                    BlzFrameSetVisible(obj.Cooldown, false)
                    BlzFrameSetVisible(obj.OverLayFrame, false)
                else
                    BlzFrameSetVisible(obj.Cooldown, true)
                    BlzFrameSetVisible(obj.OverLayFrame, true)
                end
            end
        end
        local showSpellView
        if unitCode > 0 then
            local hasControl = IsUnitOwnedByPlayer(unit, localPlayer) or GetPlayerAlliance(GetOwningPlayer(unit), localPlayer, ALLIANCE_SHARED_CONTROL)
            showSpellView = not hasControl
            if showSpellView then showSpellView = this.ShowAllowed(unit, localPlayer) end
        else
            showSpellView = false
        end
        BlzFrameSetVisible(this.ParentSimple, showSpellView)
        BlzFrameSetVisible(this.Parent, showSpellView)
        if showSpellView then
            local stillShowLastTooltip = LastHoveredIndex >= 0 and BlzFrameIsVisible(this.Frame[LastHoveredIndex].SimpleTooltip)
            --print("stillShowLastTooltip",stillShowLastTooltip)
            local data = this.Data
            for i = 0, 11 do
                local dataI = data[i]
                local obj = this.Frame[i]
                local level = 1
                if dataI.Used then
                    if dataI.FourCC > 0 then
                        local skill = dataI.FourCC
                        level = GetUnitAbilityLevel(unit, skill)
                        if this.ShowCooldown then
                            local cdRemain = BlzGetUnitAbilityCooldownRemaining(unit, skill)
                            if cdRemain > 0 then
                                if this.ShowCooldownText then
                                    BlzFrameSetVisible(obj.TextCool, true)
                                    if cdRemain > 5 then
                                        BlzFrameSetText(obj.TextCool, string.format(this.TextFormat0, cdRemain))
                                    else
                                        BlzFrameSetText(obj.TextCool, string.format( this.TextFormat1, cdRemain))
                                    end
                                else
                                    BlzFrameSetVisible(obj.TextCool, false)
                                end
                                -- this be inaccurate when the map has systems to change cooldowns only during the casting.
                                local cdTotal = BlzGetUnitAbilityCooldown(unit, skill, level - 1)
                                --print(GetObjectName(skill),cdRemain,cdTotal, cdRemain/cdTotal)
                                BlzFrameSetVisible(obj.Cooldown, true)
                                BlzFrameSetValue(obj.Cooldown, 100-(cdRemain/cdTotal)*100)
                                --print(BlzFrameIsVisible(obj.Cooldown), BlzFrameGetValue(obj.Cooldown))
                            else
                                BlzFrameSetVisible(obj.TextCool, false)
                                BlzFrameSetVisible(obj.Cooldown, false)
                            end
                        else
                            BlzFrameSetVisible(obj.Cooldown, false)
                        end

                        BlzFrameSetVisible(obj.OverLayFrame, true)
                        if not this.TechFullFilled(GetOwningPlayer(unit), skill) then BlzFrameSetText(obj.ChargeBoxText, this.TextDisallowed)
                        else BlzFrameSetText(obj.ChargeBoxText, level) end
                    end

                    -- hovered?
                    if not stillShowLastTooltip and not foundTooltip and BlzFrameIsVisible(obj.SimpleTooltip) then
                        foundTooltip = true
                        -- only update Tooltip when needed
                        if i ~= LastHoveredIndex then
                            LastHoveredIndex = i
                            BlzFrameSetTexture(thisTooltip.Icon, dataI.Icon, 0, false)
                            BlzFrameSetText(thisTooltip.Name, dataI.Name)

                            local spell = Spells[dataI.FourCC]

                            if spell then
                                BlzFrameSetText(thisTooltip.Text, spell:getTooltip(unit, level))
                            else
                                BlzFrameSetText(thisTooltip.Text, dataI.Text)
                            end
                            BlzFrameSetText(thisTooltip.TextMana, dataI.Mana)
                            BlzFrameSetText(thisTooltip.TextCool, dataI.Cool)
                            BlzFrameSetText(thisTooltip.TextRange, dataI.Range)
                            BlzFrameSetText(thisTooltip.TextArea, dataI.Area)
                        end
                    end
                end
            end
            BlzFrameSetVisible(thisTooltip.Frame, stillShowLastTooltip or foundTooltip)
        end
        unit = nil
    end

    local InitFramesCodeOnlyCreateButton = function(i, simpleButton)
        local obj = this.Frame[i]
        local frame
        local buttonFrame
        local overlayFrame
        buttonFrame = BlzCreateFrameByType("FRAME", "TasSpellViewButton", this.Parent, "", i)
        BlzFrameSetAllPoints(buttonFrame, simpleButton)
        obj.Button = buttonFrame
        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewButtonBackdrop", buttonFrame, "", i)
        BlzFrameSetAllPoints(frame, simpleButton)
        obj.Icon = frame
        overlayFrame = BlzCreateFrameByType("FRAME", "TasSpellViewButtonOverLayFrame", buttonFrame, "", i)
        BlzFrameSetAllPoints(frame, simpleButton)
        obj.OverLayFrame = overlayFrame
        frame = BlzCreateFrameByType("TEXT", "TasSpellViewButtonTextOverLay", overlayFrame, "", i)
        obj.OverLayText = frame
        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewButtonChargeBox", overlayFrame, "", i)
        obj.ChargeBox = frame
        BlzFrameSetSize(frame, 0.02, 0.02)
        BlzFrameSetTexture(frame, "UI/Widgets/Console/Human/CommandButton/human-button-lvls-overlay.blp", 0, true)
        BlzFrameSetPoint(frame, FRAMEPOINT_BOTTOMRIGHT, simpleButton, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        frame = BlzCreateFrameByType("TEXT", "TasSpellViewButtonChargeText", overlayFrame, "", i)
        obj.ChargeBoxText = frame
        BlzFrameSetSize(frame, 0.02, 0.02)
        BlzFrameSetPoint(frame, FRAMEPOINT_BOTTOMRIGHT, simpleButton, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        BlzFrameSetTextAlignment(frame, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        frame = BlzCreateFrameByType("STATUSBAR", "TasSpellViewButtonCooldown", overlayFrame, "", i)
        obj.Cooldown = frame
        BlzFrameSetModel(frame, "UI/Feedback/Cooldown/UI-Cooldown-Indicator.mdl", 0)
        BlzFrameSetAllPoints(frame, simpleButton)
        BlzFrameSetVisible(frame, false)
        frame = BlzCreateFrameByType("TEXT", "TasSpellViewButtonCooldownText", frame, "TeamLadderRankValueTextTemplate", i)
        obj.TextCool = frame
        BlzFrameSetAllPoints(frame, simpleButton)
        BlzFrameSetTextAlignment(frame, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    end

    local InitFramesCodeOnly = function()
        local frame
        local frameB
        local tooltipFrame
        this.ParentSimple = BlzCreateFrameByType("SIMPLEFRAME", "TasSpellViewSimpleFrame", this.ParentFuncSimple(), "", 0)
        this.Parent = BlzCreateFrameByType("FRAME", "TasSpellViewFrame", this.ParentFunc(), "", 0)
        for i = 0, 11 do
            this.Frame[i] = {}
            frame = BlzCreateFrameByType("SIMPLEBUTTON", "TasSpellViewButtonCode", this.ParentSimple, "UpperButtonBarButtonTemplate", i)
            this.Frame[i].SimpleButton = frame
            BlzFrameSetPoint(frame, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i), FRAMEPOINT_CENTER, 0, 0.0)
            BlzFrameSetSize(frame, 0.034, 0.034)
            BlzFrameSetLevel(frame, 6) -- reforged stuff
            BlzFrameSetAlpha(frame, 0)
            tooltipFrame = BlzCreateFrameByType("SIMPLEFRAME", "TasSpellViewButtonToolTip", frame, "", i)
            this.Frame[i].SimpleTooltip = tooltipFrame
            BlzFrameSetTooltip(frame, tooltipFrame)
            BlzFrameSetVisible(tooltipFrame, false)

            InitFramesCodeOnlyCreateButton(i, frame)
        end

        -- create one ToolTip which shows data for current hovered inside a timer.
        -- also reserve handleIds to allow async usage
        tooltipFrame = BlzCreateFrameByType("FRAME", "TasSpellViewTooltipFrame", this.Parent, "", 0)
        thisTooltip.Frame = tooltipFrame
        --frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipBox", tooltipFrame, "QuestButtonDisabledBackdropTemplate", 0)
        frame = BlzCreateFrameByType("FRAME", "TasSpellViewTooltipBox", tooltipFrame, "Leaderboard", 0)
        thisTooltip.Box = frame

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipIcon", tooltipFrame, "", 0)
        thisTooltip.Icon = frame
        BlzFrameSetSize(frame, 0.035, 0.035)

        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipName", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.Name = frame
        BlzFrameSetTextAlignment(frame, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipSeperator", tooltipFrame, "", 0)
        thisTooltip.Sep = frame
        BlzFrameSetSize(frame, 0, 0.001)
        BlzFrameSetTexture(frame, "replaceabletextures/teamcolor/teamcolor08", 0, false)
        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipText", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.Text = frame

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipManaIcon", tooltipFrame, "", 0)
        thisTooltip.IconMana = frame
        BlzFrameSetTexture(frame, "UI/Widgets/ToolTips/Human/ToolTipManaIcon.blp", 0, false)
        BlzFrameSetSize(frame, 0.015, 0.015)
        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipManaText", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.TextMana = frame
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconMana, FRAMEPOINT_RIGHT, 0.005, 0)

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipCooldownIcon", tooltipFrame, "", 0)
        thisTooltip.IconCool = frame
        BlzFrameSetSize(frame, 0.015, 0.015)
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconMana, FRAMEPOINT_RIGHT, 0.042, 0)
        BlzFrameSetTexture(frame, "ui/widgets/battlenet/bnet-tournament-clock", 0, false)

        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipCooldownText", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.TextCool = frame
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconCool, FRAMEPOINT_RIGHT, 0.005, 0)

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipRangeIcon", tooltipFrame, "", 0)
        thisTooltip.IconRange = frame
        BlzFrameSetSize(frame, 0.015, 0.015)
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconCool, FRAMEPOINT_RIGHT, 0.042, 0)
        BlzFrameSetTexture(frame, "replaceabletextures/commandbuttons/btnload", 0, false)

        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipRangeText", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.TextRange = frame
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconRange, FRAMEPOINT_RIGHT, 0.005, 0)

        frame = BlzCreateFrameByType("BACKDROP", "TasSpellViewTooltipAreaIcon", tooltipFrame, "", 0)
        thisTooltip.IconArea = frame
        BlzFrameSetSize(frame, 0.015, 0.015)
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconRange, FRAMEPOINT_RIGHT, 0.042, 0)
        BlzFrameSetTexture(frame, "replaceabletextures/selection/spellareaofeffect_undead", 0, true)

        frame = BlzCreateFrameByType("TEXT", "TasSpellViewTooltipAreaText", tooltipFrame, "TeamValueTextTemplate", 0)
        thisTooltip.TextArea = frame
        BlzFrameSetPoint(frame, FRAMEPOINT_LEFT, thisTooltip.IconArea, FRAMEPOINT_RIGHT, 0.005, 0)

        BlzFrameSetPoint(thisTooltip.IconMana, FRAMEPOINT_BOTTOMLEFT, thisTooltip.Sep, FRAMEPOINT_TOPLEFT, 0, 0.005)

        BlzFrameSetPoint(thisTooltip.Sep, FRAMEPOINT_BOTTOMLEFT, thisTooltip.Text, FRAMEPOINT_TOPLEFT, 0, 0.005)
        BlzFrameSetPoint(thisTooltip.Sep, FRAMEPOINT_BOTTOMRIGHT, thisTooltip.Text, FRAMEPOINT_TOPRIGHT, 0, 0.005)

        BlzFrameSetPoint(thisTooltip.Name, FRAMEPOINT_TOPLEFT, thisTooltip.Icon, FRAMEPOINT_TOPRIGHT, 0.005, -0.002)
        BlzFrameSetPoint(thisTooltip.Name, FRAMEPOINT_BOTTOMRIGHT, thisTooltip.Sep, FRAMEPOINT_TOPRIGHT, -0.005, 0.021)

        BlzFrameSetPoint(thisTooltip.Icon, FRAMEPOINT_BOTTOMLEFT, thisTooltip.Sep, FRAMEPOINT_TOPLEFT, 0, 0.021)

        BlzFrameSetSize(thisTooltip.Text, this.ToolTipSizeX, 0)
        BlzFrameSetAbsPoint(thisTooltip.Text, this.ToolTipPos, this.ToolTipPosX, this.ToolTipPosY)
        BlzFrameSetPoint(thisTooltip.Box, FRAMEPOINT_TOPLEFT, thisTooltip.Icon, FRAMEPOINT_TOPLEFT, -0.009, 0.009)
        BlzFrameSetPoint(thisTooltip.Box, FRAMEPOINT_BOTTOMRIGHT, thisTooltip.Text, FRAMEPOINT_BOTTOMRIGHT, 0.009, -0.009)
        BlzFrameSetVisible(thisTooltip.Frame, false)

        BlzFrameSetVisible(this.ParentSimple, false)
        BlzFrameSetVisible(this.Parent, false)
    end

    local InitFrames = function()
        this.ParentSimple = BlzCreateFrameByType("SIMPLEFRAME", "TasSpellViewSimpleFrame", this.ParentFuncSimple(), "", 0)
        this.Parent = BlzCreateFrameByType("FRAME", "TasSpellViewFrame", this.ParentFunc(), "", 0)
        for i = 0, 11 do
            this.Frame[i] = {}
            local obj = this.Frame[i]
            local frame = BlzCreateSimpleFrame("TasSpellViewButton", this.ParentSimple, i)
            obj.SimpleButton = frame
            obj.Button = frame
            BlzFrameSetPoint(frame, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i), FRAMEPOINT_CENTER, 0, 0.0)
            local tooltipFrame = BlzCreateFrameByType("SIMPLEFRAME", "TasSpellViewButtonToolTip", frame, "", i)
            obj.SimpleTooltip = tooltipFrame
            obj.OverLayFrame = BlzGetFrameByName("TasSpellViewButtonOverLayFrame", i)
            obj.Icon = BlzGetFrameByName("TasSpellViewButtonBackdrop", i)
            obj.OverLayText = BlzGetFrameByName("TasSpellViewButtonTextOverLay", i)
            obj.ChargeBox = BlzGetFrameByName("TasSpellViewButtonChargeBox", i)
            obj.ChargeBoxText = BlzGetFrameByName("TasSpellViewButtonChargeText", i)
            obj.Cooldown = BlzCreateFrame("TasSpellViewButtonCooldown", this.Parent, 0, i)
            obj.TextCool = BlzGetFrameByName("TasSpellViewButtonCooldownText", i)
            BlzFrameSetLevel(frame, 6) -- reforged stuff
            BlzFrameSetLevel(obj.OverLayFrame, 7) -- reforged stuff
            BlzFrameSetTooltip(frame, tooltipFrame)
            BlzFrameSetVisible(tooltipFrame, false)

            BlzFrameSetVisible(obj.Cooldown, false)
        end

        -- create one ToolTip which shows data for current hovered inside a timer.
        thisTooltip.Frame = BlzCreateFrame("TasSpellViewTooltipFrame", this.Parent, 0, 0)
        thisTooltip.Box = BlzGetFrameByName("TasSpellViewTooltipBox", 0)
        thisTooltip.Icon = BlzGetFrameByName("TasSpellViewTooltipIcon", 0)
        thisTooltip.Name = BlzGetFrameByName("TasSpellViewTooltipName", 0)
        thisTooltip.Sep = BlzGetFrameByName("TasSpellViewTooltipSeperator", 0)
        thisTooltip.Text = BlzGetFrameByName("TasSpellViewTooltipText", 0)
        thisTooltip.TextMana = BlzGetFrameByName("TasSpellViewTooltipManaText", 0)
        thisTooltip.TextCool = BlzGetFrameByName("TasSpellViewTooltipCooldownText", 0)
        thisTooltip.TextRange = BlzGetFrameByName("TasSpellViewTooltipRangeText", 0)
        thisTooltip.TextArea = BlzGetFrameByName("TasSpellViewTooltipAreaText", 0)

        BlzFrameSetSize(thisTooltip.Text, this.ToolTipSizeX, 0)
        BlzFrameSetAbsPoint(thisTooltip.Text, this.ToolTipPos, this.ToolTipPosX, this.ToolTipPosY)
        BlzFrameSetPoint(thisTooltip.Box, FRAMEPOINT_TOPLEFT, thisTooltip.Icon, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
        BlzFrameSetPoint(thisTooltip.Box, FRAMEPOINT_BOTTOMRIGHT, thisTooltip.Text, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        BlzFrameSetVisible(thisTooltip.Frame, false)

        BlzFrameSetVisible(this.ParentSimple, false)
        BlzFrameSetVisible(this.Parent, false)
    end

    local InitFramesPre = function()
        if this.CodeOnly then
            InitFramesCodeOnly()
        else
            InitFrames()
        end
    end
    function InitTasSpellView()
        for i= 0,11 do this.Data[i] = {} end
        this.Group = CreateGroup()
        this.Timer = CreateTimer()
        if not BlzGetAbilityId and this.IdData.Enabled and this.IdData.Enabled > 0 then
            -- Warcraft 3 V1.31.1 does not have BlzGetAbilityId, but i want to know the ability Ids of activ spells.
            local function ClearDeadSpells()
                for i=#this.IdData, 1,-1 do
                    abi = this.IdData[i]
                    skillCode = this.IdData[abi]

                    local pos = BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_X) + BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_Y)*4
                    local posB = BlzGetAbilityPosX(skillCode) + BlzGetAbilityPosY(skillCode)*4
                    if pos ~= posB then
                        local lastIndex = #this.IdData
                        this.IdData[i] = this.IdData[lastIndex]
                        this.IdData[lastIndex] = nil
                        this.IdData[abi] = nil
                    end
                end
            end
            this.ClearDeadSpells = ClearDeadSpells

            this.TimerIdData = CreateTimer()
            TimerStart(this.TimerIdData, 20, true, ClearDeadSpells)

            local alocSkill = ABIL_ALOC
            local function unitFilt(unit)
                if not BlzIsUnitSelectable(unit)
                 or IsUnitHidden(unit)
                 or GetUnitAbilityLevel(unit, alocSkill) > 0 then
                    return false
                end
                return true
            end
            local function addSkill(abi,skillCode)
                if this.IdData[abi] then return end
                local pos = BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_X) + BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_Y)*4
                if pos ~= 0 and BlzGetAbilityIntegerField(abi, ABILITY_IF_BUTTON_POSITION_NORMAL_Y) ~= -11 then
                    if not this.IdData[abi] then table.insert(this.IdData, abi) end
                    this.IdData[abi] = skillCode
                end
            end

            if this.IdData.Enabled >= 3 then
                local realAddAbi = UnitAddAbility
                function UnitAddAbility(u, skillCode)
                    local returnValue = realAddAbi(u, skillCode)
                    if skillCode ~= alocSkill and unitFilt(u) then addSkill(BlzGetUnitAbility(u, skillCode),skillCode) end
                    return returnValue
                end
            end

            if this.IdData.Enabled >= 2 then
                this.TriggerId = CreateTrigger()
                TriggerAddAction(this.TriggerId, function()
                    if not unitFilt(GetTriggerUnit()) then return end
                    local skillCode = GetSpellAbilityId()
                    local abi = GetSpellAbility()
                    addSkill(abi,skillCode)
                end)
                TriggerRegisterAnyUnitEventBJ(this.TriggerId, EVENT_PLAYER_UNIT_SPELL_EFFECT)
            end

            if this.IdData.Enabled >= 1 then
                this.TriggerId2 = CreateTrigger()
                TriggerAddAction(this.TriggerId2, function()
                    local skillCode = GetLearnedSkill()
                    local abi = BlzGetUnitAbility(GetTriggerUnit(), skillCode)
                    addSkill(abi,skillCode)
                end)
                TriggerRegisterAnyUnitEventBJ(this.TriggerId2, EVENT_PLAYER_HERO_SKILL)
            end
        end
        --TimerStart(this.Timer, this.UpdateTime, true,function()  xpcall(this.Update, print) end)
        TimerStart(this.Timer, this.UpdateTime, true, this.Update)
        InitFramesPre()
    end
    InitSpellView = InitTasSpellView
    if this.AutoRun then
        if OnInit then -- Total Initialization
            OnInit.final(InitTasSpellView)
        else -- without
            local real = MarkGameStarted
            function MarkGameStarted()
                real()
                InitTasSpellView()
            end
        end
    end
end, Debug and Debug.getLine())
