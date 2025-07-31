OnInit.final("HeroSelect", function(Require)
    Require('Users')
    Require('Variables')
    Require('Spells')
    Require('Frames')

    SELECTING_HERO = {} ---@type boolean[] 
    local hardcore = {}

    -- sort all heroes alphabetically
    local heroes = {}

    for i, v in pairs(HERO_STATS) do
        -- automatically assign key to id value
        v.id = i
        -- get hero name
        v.name = GetObjectName(i)
        heroes[#heroes + 1] = v
    end

    table.sort(heroes, function(a, b)
        local name1 = string.lower(a.name)
        local name2 = string.lower(b.name)
        return name1 < name2
    end)

    --#region frame setup
        local frame = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, 0.4, 0.53)
        BlzFrameSetSize(frame, 0.7, 0.35)
        BlzFrameSetEnable(frame, false)
        BlzFrameSetTexture(frame, "CHARSELECTUI5.dds", 0, true)
        BlzFrameSetVisible(frame, false)

        local sprite_frame = BlzCreateFrameByType("SPRITE", "", frame, "", 0)
        BlzFrameClearAllPoints(sprite_frame)
        BlzFrameSetAbsPoint(sprite_frame, FRAMEPOINT_CENTER, 0.61, 0.285)
        BlzFrameSetSize(sprite_frame, 0.001, 0.001)
        BlzFrameSetScale(sprite_frame, 0.0008)

        local select_button = SimpleButton.create(frame, "trans32.blp", 0.1, 0.033, FRAMEPOINT_BOTTOMRIGHT, FRAMEPOINT_BOTTOMRIGHT, -0.09, 0.03)
        select_button:text("Select")
        select_button:visible(false)
        BlzFrameSetScale(select_button.text_frame, 1.5)

        local name_label = BlzCreateFrame("TitleText", frame, 0, 0)
        BlzFrameSetPoint(name_label, FRAMEPOINT_BOTTOM, select_button.frame, FRAMEPOINT_TOP, 0., 0.277)
        BlzFrameSetScale(name_label, 0.85)

        local stars = {}
        local roles = { "Tank", "Single Target", "AoE", "Support", "Solo" }

        for i = 1, 5 do
            stars[i] = {}
            local role = SimpleButton.create(frame, "trans32.blp", 0.023, 0.023, FRAMEPOINT_TOP, FRAMEPOINT_TOP, -0.07, -0.038 - 0.025 * i, nil, roles[i], FRAMEPOINT_TOP, FRAMEPOINT_BOTTOM)

            for j = 1, 3 do
                stars[i][j] = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
                BlzFrameSetPoint(stars[i][j], FRAMEPOINT_LEFT, j == 1 and role.frame or stars[i][j - 1], FRAMEPOINT_RIGHT, j == 1 and 0.015 or 0.005, 0.)
                BlzFrameSetSize(stars[i][j], 0.018, 0.018)
                BlzFrameSetEnable(stars[i][j], false)
                BlzFrameSetTexture(stars[i][j], "trans32.blp", 0, true)
            end
        end

        -- TODO: make a SimpleCheckbox class?
        local hardcore_ticker = BlzCreateFrame("EscMenuCheckBoxTemplate", frame, 0, 0)
        BlzFrameSetPoint(hardcore_ticker, FRAMEPOINT_BOTTOM, select_button.frame, FRAMEPOINT_TOP, 0., 0.01)
        local hardcore_icon = SimpleButton.create(hardcore_ticker, "ReplaceableTextures\\CommandButtons\\BTNHardcore.blp", 0.02, 0.02, FRAMEPOINT_RIGHT, FRAMEPOINT_LEFT, 0., 0.)
        hardcore_icon:makeTooltip(FRAMEPOINT_TOPRIGHT, 0.2)
        hardcore_icon:setTooltipIcon("ReplaceableTextures\\CommandButtons\\BTNHardcore.blp")
        hardcore_icon:setTooltipName("Hardcore Mode")
        hardcore_icon:setTooltipText("If your character is hardcore blablabla we still don't know what the fuck hardcore does pepeSmilers")
        hardcore_icon:enable(false)
        local t = CreateTrigger()

        BlzTriggerRegisterFrameEvent(t, hardcore_ticker, FRAMEEVENT_CHECKBOX_CHECKED)
        BlzTriggerRegisterFrameEvent(t, hardcore_ticker, FRAMEEVENT_CHECKBOX_UNCHECKED)

        TriggerAddAction(t, function()
            local f = BlzGetTriggerFrame()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1

            hardcore[pid] = not hardcore[pid]

            if GetLocalPlayer() == p then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
                hardcore_icon:enable(hardcore[pid])
            end
        end)

        local icon_x_gap = 0.0385
        local icon_y_gap = 0.04

        local hero_buttons = {}
        local agi_count = 0
        local str_count = 0
        local int_count = 0

        -- hero buttons
        for i, v in ipairs(heroes) do
            local count = 0
            local x_gap = 0.05
            local y_gap = 0.01
            if v.main == "str" then
                count = str_count
                str_count = str_count + 1
                y_gap = 0.053
            elseif v.main == "agi" then
                count = agi_count
                agi_count = agi_count + 1
                y_gap = 0.152
            elseif v.main == "int" then
                count = int_count
                int_count = int_count + 1
                y_gap = 0.25
            end
            local x = math.fmod(count, 5) * icon_x_gap + x_gap
            local y = (count // 5) * icon_y_gap + y_gap
            hero_buttons[i] = SimpleButton.create(frame, BlzGetAbilityIcon(v.id), 0.028, 0.028, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, x, -y)
            hero_buttons[i]:makeTooltip(FRAMEPOINT_TOPLEFT, 0.2)
            hero_buttons[i]:setTooltipIcon(BlzGetAbilityIcon(v.id))
            hero_buttons[i]:setTooltipName(v.name)
            hero_buttons[i]:setTooltipText(BlzGetAbilityExtendedTooltip(v.select, 0) ..
            "\n\n" .. "|cffbb0000Strength:|r " .. v.str .. " (+" .. (v.str_gain or 0) ..
            ")\n" .. "|cff008800Agility:|r " .. v.agi .. " (+" .. (v.agi_gain or 0) ..
            ")\n" .. "|cff2255ffIntelligence:|r " .. v.int .. " (+" .. (v.int_gain or 0) ..
            ")\n" .. "|cffff6600Damage:|r " .. (v[v.main] + 1) ..
            "\n" .. "|cffa4a4feArmor:|r " .. v.armor ..
            "\nRange: " .. v.range)
        end

        local selected = {}

        local on_confirm = function()
            local f = BlzGetTriggerFrame()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1

            if GetLocalPlayer() == p then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
            end

            if selected[pid] and SELECTING_HERO[pid] then
                SelectHero(pid, heroes[selected[pid]].id)
            end
        end

        select_button:onClick(on_confirm)

        -- ability icons
        local abilities = {}

        for i = 1, 6 do
            local x = math.fmod(i - 1, 3)
            local y = (i - 1) // 3
            abilities[i] = SimpleButton.create(frame, "", 0.028, 0.028, FRAMEPOINT_BOTTOM, FRAMEPOINT_BOTTOM, -0.0638 + x * 0.0385, 0.076 - y * 0.0395)
            abilities[i]:makeTooltip(FRAMEPOINT_TOPRIGHT, 0.2)
            abilities[i]:visible(false)
        end

        -- info icon
        local info = SimpleButton.create(frame, "", 0.028, 0.028, FRAMEPOINT_BOTTOM, FRAMEPOINT_BOTTOM, 0.0637, 0.0563)
        info:makeTooltip(FRAMEPOINT_TOPRIGHT, 0.2)
        info:visible(false)

        local on_click = function()
            local f = BlzGetTriggerFrame()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1

            if GetLocalPlayer() == p then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
            end

            for i, v in ipairs(hero_buttons) do
                if f == v.frame then
                    local hero = heroes[i]
                    selected[pid] = i

                    -- set sprite, name, info
                    if GetLocalPlayer() == p then
                        select_button:visible(true)
                        info:visible(true)
                        info:icon(BlzGetAbilityIcon(hero.passive))
                        info:setTooltipIcon(BlzGetAbilityIcon(hero.passive))
                        info:setTooltipName(GetAbilityName(hero.passive))
                        info:setTooltipText(BlzGetAbilityExtendedTooltip(hero.passive, 0))
                        BlzFrameSetText(name_label, hero.name)
                        BlzFrameSetModel(sprite_frame, hero.model, 1)
                        BlzFrameSetSpriteAnimate(sprite_frame, 2, 0)
                    end

                    -- populate stars
                    for j = 1, 5 do
                        local val = hero.stars[j]
                        for k = 1, 3 do
                            if val > k - 1 and val < k then
                                if GetLocalPlayer() == p then
                                    BlzFrameSetTexture(stars[j][k], "CharSelectStarHalf.dds", 0, true)
                                end
                            elseif val >= k then
                                if GetLocalPlayer() == p then
                                    BlzFrameSetTexture(stars[j][k], "CharSelectStarWhole.dds", 0, true)
                                end
                            else
                                if GetLocalPlayer() == p then
                                    BlzFrameSetTexture(stars[j][k], "trans32.blp", 0, true)
                                end
                            end
                        end
                    end

                    -- populate hero buttons
                    for j = 1, 6 do
                        if hero.skills[j] then
                            local abil = FourCC(hero.skills[j])
                            if GetLocalPlayer() == p then
                                abilities[j]:visible(true)
                                abilities[j]:icon(BlzGetAbilityIcon(abil))
                                abilities[j]:setTooltipIcon(BlzGetAbilityIcon(abil))
                                abilities[j]:setTooltipName(GetAbilityName(abil))
                                abilities[j]:setTooltipText(Spells[abil]:getTooltip())
                            end
                        else
                            if GetLocalPlayer() == p then
                                abilities[j]:visible(false)
                            end
                        end
                    end

                    break
                end
            end
        end

        for _, v in ipairs(hero_buttons) do
            v:onClick(on_click)
        end
    --#endregion

    ---@param pid integer
    ---@param id integer
    function SelectHero(pid, id)
        local p = Player(pid - 1)

        Profile[pid]:new_character(id)
        Profile[pid].hero.hardcore = (hardcore[pid] and 1) or 0
        SELECTING_HERO[pid] = false

        if (GetLocalPlayer() == p) then
            ClearTextMessages()
            ClearSelection()
            SelectUnit(Hero[pid], true)
            ResetToGameCamera(0)
            BlzFrameSetVisible(frame, false)
        end

        ExperienceControl(pid)
        CharacterSetup(pid, false)
    end

    function StartHeroSelect(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, true)
            ClearTextMessages()
        end
    end
end, Debug and Debug.getLine())
