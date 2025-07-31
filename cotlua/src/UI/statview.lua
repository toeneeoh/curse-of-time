--[[
    statview.lua

    This module defines the stat window for detailed information on heroes / units
]]

OnInit.final("StatView", function(Require)
    STAT_WINDOW = {}

    local tab_tags = {
        STAT_TAG, -- defined in variables.lua

        -- priority does not matter here
        {
            { tag = "|cffffcc00Gold|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return GetCurrency(pid, GOLD) end},
            { tag = "|cffccccccPlatinum|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return GetCurrency(pid, PLATINUM) end},
            { tag = "|cff6969ffCrystal|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return GetCurrency(pid, CRYSTAL) end},
        },
        {
            { tag = "|cffffcc00Perk Points|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return "1" end},
        },
    }

    -- main UI
    local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    -- separate breakdowns per tab (if they exist)
    local breakdown_frames = {
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
    }
    for i = 1, #breakdown_frames do
        BlzFrameSetTexture(breakdown_frames[i], "trans32.blp", 0, true)
        BlzFrameSetSize(breakdown_frames[i], 0.001, 0.001)
        BlzFrameSetEnable(breakdown_frames[i], false)
    end
    local tab_frame = BlzCreateFrame("ListBoxWar3", frame, 0, 0)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    local text = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local number = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local viewing = {}

    -- initialize viewing tables
    for i = 1, PLAYER_CAP do
        viewing[i] = {unit = nil, page = 1}
    end

    STAT_WINDOW.frame = frame
    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, -0.05, 0.55)
    BlzFrameSetSize(frame, 0.3, 0.33)
    BlzFrameSetEnable(frame, false)

    BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.013)
    BlzFrameSetEnable(title, false)

    BlzFrameSetPoint(number, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.113, -0.04)
    BlzFrameSetTextAlignment(number, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
    BlzFrameSetScale(number, 1.)
    BlzFrameSetEnable(number, false)

    BlzFrameSetPoint(text, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.015, -0.04)
    BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
    BlzFrameSetScale(text, 1.)
    BlzFrameSetEnable(text, false)

    BlzFrameSetPoint(tab_frame, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_BOTTOMLEFT, 0., 0.005)
    BlzFrameSetSize(tab_frame, 0.3, 0.05)
    BlzFrameSetEnable(tab_frame, false)

    local on_refresh = function(target)
        local U = User.first
        while U do
            local u = viewing[U.id].unit

            if u == target then
                STAT_WINDOW.refresh(U.id)
            end

            U = U.next
        end
    end

    local close = function(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, false)
        end

        -- no longer viewing stat window
        if viewing[pid].unit then
            EVENT_STAT_CHANGE:unregister_unit_action(viewing[pid].unit, on_refresh)
            viewing[pid].unit = nil
        end
    end
    STAT_WINDOW.close = close
    AddToEsc(close) -- close window hotkey reference

    local onClose = function()
        local f = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
        end

        close(pid)

        return false
    end

    -- escape button
    local esc_button = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onClose, "Close 'B'", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    RegisterHotkeyTooltip(esc_button, 5)

    local function ViewPlayersClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            viewing[pid].unit = Hero[dw.data[index]]
            STAT_WINDOW.refresh(pid)

            dw:destroy()
        end

        return false
    end

    local function ViewPlayers()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local dw  = DialogWindow.create(pid, "", ViewPlayersClick) ---@type DialogWindow 
        local U   = User.first ---@type User 

        while U do
            if viewing[pid].unit ~= Hero[U.id] then
                dw:addButton(U.nameColored, U.id)
            end

            U = U.next
        end

        dw:display()

        return false
    end

    -- choose player button
    SimpleButton.create(esc_button.frame, "ReplaceableTextures\\CommandButtons\\BTNCycleRight.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPLEFT, 0, 0, ViewPlayers, "Select Player", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

    local tabs = {
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelStatsButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.0125, -0.0125, nil, "View Stats", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelCurrencyButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.042, -0.0125, nil, "View Currency", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelPerkButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.0715, -0.0125, nil, "View Perks", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
    }
    tabs[2]:enable(false)
    tabs[3]:enable(false)

    local function switch_tab()
        local trigger_frame = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local tpid = GetPlayerId(GetOwningPlayer(viewing[pid].unit)) + 1
        local index = 1
        for i = 1, #tabs do
            if tabs[i].frame == trigger_frame then
                index = i
                break
            end
        end

        viewing[pid].page = (tpid <= PLAYER_CAP and index) or 1 -- set page to stats for non-player units

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(trigger_frame, false)
            BlzFrameSetEnable(trigger_frame, true)

            for i = 1, #tabs do
                tabs[i]:enable(false)
            end

            tabs[viewing[pid].page]:enable(true)
        end

        STAT_WINDOW.refresh(pid)
    end

    tabs[1]:onClick(switch_tab)
    tabs[2]:onClick(switch_tab)
    tabs[3]:onClick(switch_tab)

    -- hide by default
    BlzFrameSetVisible(frame, false)

    STAT_WINDOW.refresh = function(pid)
        local u = viewing[pid].unit

        if u then
            local page = viewing[pid].page
            local tab = tab_tags[page]
            local tpid = GetPlayerId(GetOwningPlayer(u)) + 1
            local stat_number = ""
            local stat_tag = ""
            local name = (u == Hero[tpid] and User[tpid - 1].nameColored) or GetUnitName(u)
            local ishero = (u == Hero[tpid] and 3) or 2

            if GetLocalPlayer() == Player(pid - 1) then
                for i = 1, #breakdown_frames do
                    if i ~= page then
                        BlzFrameSetVisible(breakdown_frames[i], false)
                    end
                end
                BlzFrameSetVisible(breakdown_frames[page], true)
            end

            -- propogate tags belonging to each tab
            for priority = 1, ishero do
                for i = 1, #tab do
                    local v = tab[i]

                    if v.priority == priority then
                        local num = v.getter and v.getter(u) or ""

                        if v.breakdown then
                            local breakdown = v.breakdown(u)

                            if GetLocalPlayer() == Player(pid - 1) then
                                BlzFrameSetText(v.breakdown_tooltip.tooltip, breakdown)
                                BlzFrameSetPoint(v.breakdown_backdrop, FRAMEPOINT_TOPLEFT, number, FRAMEPOINT_TOPLEFT, 0.01 + (v.suffix and 0.01 or 0) + num:len() * 0.0085, (-i + 1) * 0.01575)
                            end
                        end

                        stat_tag = stat_tag .. (v.alternate or v.tag) .. "|n"
                        stat_number = stat_number .. num .. (v.suffix or "") .. "|n"
                    end
                end
            end

            if GetLocalPlayer() == Player(pid - 1) then
                --set text and size
                BlzFrameSetText(title, name)
                BlzFrameSetText(number, stat_number)
                BlzFrameSetText(text, stat_tag)
            end
        end
    end

    STAT_WINDOW.display = function(u, pid)
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1

        if viewing[pid].unit == u then
            close(pid)
        elseif u and not BlzGetUnitBooleanField(u, UNIT_BF_IS_A_BUILDING) then
            viewing[pid].unit = u
            viewing[pid].page = (tpid <= PLAYER_CAP and viewing[pid].page) or 1 -- set page to stats for non-player units
            EVENT_STAT_CHANGE:register_unit_action(u, on_refresh)

            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(frame, true)
                for i = 1, #tabs do
                    tabs[i]:enable(false)
                end
                tabs[viewing[pid].page]:enable(true)
            end

            STAT_WINDOW.refresh(pid)
        end
    end

    -- getters and breakdowns for stats
    STAT_TAG[1].breakdown = function(u)
        local lvl = GetUnitLevel(u)
        local s = ""
        if IsUnitType(u, UNIT_TYPE_HERO) then
            s = "XP: " .. GetHeroXP(u) .. "/" .. RequiredXP(lvl)
        end
        return s
    end
    STAT_TAG[1].getter = function(u)
        local lvl = GetUnitLevel(u)
        local s = RealToString(lvl)
        return s
    end

    STAT_TAG[ITEM_HEALTH].getter = function(u) return RealToString(GetWidgetLife(u)) .. " / " .. RealToString(Unit[u].hp) end
    STAT_TAG[ITEM_MANA].getter = function(u) return RealToString(GetUnitState(u, UNIT_STATE_MANA)) .. " / " .. RealToString(GetUnitState(u, UNIT_STATE_MAX_MANA)) end
    STAT_TAG[ITEM_DAMAGE].getter = function(u) return RealToString(Unit[u].damage + 1) end -- include dice
    STAT_TAG[ITEM_DAMAGE].breakdown = function(u)
        return "|cffffcc00Base Damage:|r " .. BlzGetUnitBaseDamage(u, 0) ..
            "\n|cffffcc00Spell/Item Bonus:|r " .. Unit[u].bonus_damage ..
            "\n|cffffcc00Percent Bonus:|r " .. string.format("\x25.3f", (Unit[u].damage_percent - 1.) * 100.) .. "\x25" .. " (" .. string.format("\x25.3f", Unit[u].damage - Unit[u].bonus_damage - BlzGetUnitBaseDamage(u, 0)) .. ")" ..
            "\n|cffffcc00Total Damage:|r " .. (Unit[u].damage + 1)
    end
    STAT_TAG[ITEM_ARMOR].getter = function(u) return RealToString(BlzGetUnitArmor(u)) end
    STAT_TAG[ITEM_STRENGTH].getter = function(u) return RealToString(GetHeroStr(u, true)) end
    STAT_TAG[ITEM_AGILITY].getter = function(u) return RealToString(GetHeroAgi(u, true)) end
    STAT_TAG[ITEM_INTELLIGENCE].getter = function(u) return RealToString(GetHeroInt(u, true)) end
    STAT_TAG[ITEM_REGENERATION].getter = function(u) return RealToString(Unit[u].regen) end
    STAT_TAG[ITEM_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].regen_flat ..
            "\n|cffffcc00Percent Regeneration:|r " .. string.format("\x25.3f", Unit[u].regen_max) .. "\x25" .. " (" .. string.format("\x25.3f", Unit[u].regen_max * Unit[u].hp * 0.01) .. ")" ..
            "\n|cffffcc00Healing Received:|r " .. string.format("\x25.3f", Unit[u].regen_percent * 100.) .. "\x25" ..
            "\n|cffffcc00Total Regeneration:|r " .. Unit[u].regen
    end
    STAT_TAG[ITEM_MANA_REGENERATION].getter = function(u) return RealToString(Unit[u].mana_regen) end
    STAT_TAG[ITEM_MANA_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].mana_regen_flat ..
            "\n|cffffcc00Intelligence Regeneration:|r " .. GetHeroInt(u, true) * 0.05 ..
            "\n|cffffcc00Percent Regeneration:|r " .. string.format("\x25.2f", Unit[u].mana_regen_max) .. "\x25" .. " (" .. Unit[u].mana_regen_max * Unit[u].mana * 0.01 .. ")" ..
            "\n|cffffcc00Mana Received:|r " .. string.format("\x25.2f", Unit[u].mana_regen_percent * 100.) .. "\x25" ..
            "\n|cffffcc00Total Regeneration:|r " .. Unit[u].mana_regen
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].breakdown = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduc == 0.03 and "\n|cffffcc00Chaos Reduction:|r " .. string.format("\x25.3f", (1. - chaos_reduc) * 100) .. "\x25" or "")
        return "|cffffcc00Base Reduction:|r " .. string.format("\x25.3f", 100. - (HERO_STATS[GetType(u)].phys_resist) * 100.)  .. "\x25" ..
            "\n|cffffcc00Spell/Item Reduction:|r " .. string.format("\x25.3f", 100. - (Unit[u].dr * Unit[u].pr) / HERO_STATS[GetType(u)].phys_resist * 100.)  .. "\x25" ..
            "\n|cffffcc00Armor Reduction:|r " .. string.format("\x25.3f", ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u))) * 100.)  .. "\x25" ..
            chaos ..
            "\n|cffffcc00Total Reduction:|r " .. string.format("\x25.3f", 100. - (Unit[u].dr * Unit[u].pr) * 100. * (1. - ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u)))) * chaos_reduc) .. "\x25"
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].getter = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return string.format("\x25.3f", (Unit[u].dr * Unit[u].pr) * 100. * (1. - ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u)))) * chaos_reduc)
    end

    STAT_TAG[ITEM_MAGIC_RESIST].breakdown = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduc == 0.03 and "\n|cffffcc00Chaos Reduction:|r " .. string.format("\x25.3f", (1. - chaos_reduc) * 100) .. "\x25" or "")
        return "|cffffcc00Base Reduction:|r " .. string.format("\x25.3f", 100. - (HERO_STATS[GetType(u)].magic_resist) * 100.)  .. "\x25" ..
            "\n|cffffcc00Spell/Item Reduction:|r " .. string.format("\x25.3f", 100. - (Unit[u].dr * Unit[u].mr) / HERO_STATS[GetType(u)].magic_resist * 100.)  .. "\x25" ..
            chaos ..
            "\n|cffffcc00Total Reduction:|r " .. string.format("\x25.3f", 100. - (Unit[u].dr * Unit[u].mr) * 100. * chaos_reduc) .. "\x25"
    end

    STAT_TAG[ITEM_MAGIC_RESIST].getter = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return string.format("\x25.3f", (Unit[u].dr * Unit[u].mr) * 100. * chaos_reduc)
    end

    STAT_TAG[ITEM_DAMAGE_MULT].getter = function(u) return string.format("\x25.3f", (Unit[u].dm * Unit[u].pm) * 100.) end
    STAT_TAG[ITEM_MAGIC_MULT].getter = function(u) return string.format("\x25.3f", (Unit[u].dm * Unit[u].mm) * 100.) end
    STAT_TAG[ITEM_MOVESPEED].getter = function(u) return RealToString(Unit[u].movespeed) end
    STAT_TAG[ITEM_EVASION].getter = function(u) return math.min(100, (Unit[u].evasion)) end
    STAT_TAG[ITEM_SPELLBOOST].getter = function(u) return string.format("\x25.3f", Unit[u].spellboost * 100.) end
    STAT_TAG[ITEM_CRIT_CHANCE].getter = function(u) return string.format("\x25.2f", Unit[u].cc) end
    STAT_TAG[ITEM_CRIT_DAMAGE].getter = function(u) return string.format("\x25.2f", Unit[u].cd) end
    STAT_TAG[ITEM_CRIT_CHANCE_MULT].getter = function(u) return string.format("\x25.2f", Unit[u].cc) end
    STAT_TAG[ITEM_CRIT_DAMAGE_MULT].getter = function(u) return string.format("\x25.2f", Unit[u].cd * 100.) end
    STAT_TAG[ITEM_BASE_ATTACK_SPEED].getter = function(u) local as = BlzGetUnitWeaponBooleanField(u, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0) and 1. / Unit[u].bat or 0 return string.format("\x25.2f", as) .. " attacks per second" end
    STAT_TAG[ITEM_GOLD_GAIN].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return ItemGoldRate[pid] end
    STAT_TAG[ITEM_STACK + 1].getter = function(u) local as = BlzGetUnitWeaponBooleanField(u, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0) and (1. / Unit[u].bat) * (1 + math.min(GetHeroAgi(u, true), 400) * 0.01) or 0 return string.format("\x25.2f", as) .. " attacks per second" end
    STAT_TAG[ITEM_STACK + 2].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return string.format("\x25.2f", XP_Rate[pid]) end
    STAT_TAG[ITEM_STACK + 3].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return (Profile[pid].hero.time // 60) .. " hours and " .. ModuloInteger(Profile[pid].hero.time, 60) .. " minutes" end
    STAT_TAG[ITEM_STACK + 4].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return (Profile[pid].total_time) // 60 .. " hours and " .. ModuloInteger(Profile[pid].total_time, 60) .. " minutes" end

    -- initialize breakdown frames
    for j = 1, #tab_tags do
        local tab = tab_tags[j]
        for i = 1, #tab do
            local v = tab[i]

            if v.breakdown then
                v.breakdown_backdrop = BlzCreateFrameByType("BACKDROP", "", breakdown_frames[j], "", 0)
                v.breakdown_frame = BlzCreateFrameByType("FRAME", "", breakdown_frames[j], "", 0)
                BlzFrameSetTexture(v.breakdown_backdrop, "war3mapImported\\question.blp", 0, true)
                BlzFrameSetScale(v.breakdown_backdrop, 0.6)
                BlzFrameSetSize(v.breakdown_backdrop, 0.016, 0.016)
                BlzFrameSetAllPoints(v.breakdown_frame, v.breakdown_backdrop)
                v.breakdown_tooltip = FrameAddSimpleTooltip(v.breakdown_frame, "", "", true, FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_TOPRIGHT, 0., 0.008, 0.01)
            end
        end
    end

end, Debug and Debug.getLine())
