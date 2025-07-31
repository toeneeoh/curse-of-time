--[[
    profile.lua

    A module that defines the Profile interface which provides
    functions to handle player specific data.

    profile breakdown:
        save version
        slot checksums
        hotkeys
        total time

    character breakdown:
        id
        hardcore
        prestige
        level
        str
        agi
        int
        gold
        platinum
        crystal
        honor
        faction points
        time
            MAX_INVENTORY_SLOTS
            item_id
            item_stats
        teleport
        reveal
        skin

]]

OnInit.global("Profile", function(Require)
    MAX_SLOTS           = 40 -- profile slots
    MAX_INVENTORY_SLOTS = 26 ---@type integer 
    BACKPACK_INDEX      = 9
    POTION_INDEX        = 7

    Require('CodeGen')
    Require('TimerQueue')
    Require('Hotkeys')

    local SETUP_X = -690.
    local SETUP_Y = -238.

    local MAX_TIME_PLAYED     = 10000000 -- ~10 years in minutes
    local MAX_PLAT_CRYS       = 100000
    local MAX_GOLD            = 10000000
    local MAX_HONOR           = 100000
    local MAX_FACTION         = 100000
    local MAX_UPGRADE_LEVEL   = 10
    local MAX_STATS           = 255000

    ---@class Profile
    ---@field brand_new boolean
    ---@field new_char boolean
    ---@field pid integer
    ---@field current_slot integer
    ---@field checksums integer[]
    ---@field total_time integer
    ---@field skin function
    ---@field hero HeroData
    ---@field new function
    ---@field repick function
    ---@field load function
    ---@field getSlotsUsed function
    ---@field save_profile function
    ---@field save_character function
    ---@field preload_character function
    ---@field create function
    ---@field saveCooldown function
    ---@field toggleAutoSave function
    ---@field save_timer integer
    ---@field save function
    ---@field autosave boolean
    ---@field destroy function
    ---@field get_empty_slot function
    ---@field open_dialog function
    ---@field hero_select function
    ---@field cannot_load boolean
    ---@field profile_code string
    ---@field character_code string[]
    ---@field storage HeroData[]
    ---@field generate_backup function
    ---@field new_character function
    ---@field delete_character function
    ---@field playing boolean
    Profile = {} ---@type Profile | Profile[]
    do
        local thistype = Profile

        local getter = {
            hero = function(tbl)
                return tbl.storage[tbl.current_slot]
            end
        }

        local mt = {
            __index = function(tbl, key)
                if getter[key] then
                    return getter[key](tbl)
                end
                return rawget(thistype, key)
            end}

        local function on_cleanup(pid)
            local profile = Profile[pid]

            profile.playing = false
            if profile.save_timer then
                TimerQueue:disableCallback(profile.save_timer)
                profile.save_timer = nil
            end
            profile.autosave = false
        end

        ---@type fun(pid: integer): Profile
        function Profile.create(pid)
            local self = setmetatable({
                pid = pid,
                checksums = __jarray(0),
                timers = {},
                total_time = 0,
                character_code = {},
                storage = {}, ---@type HeroData[]
                current_slot = 1,
            }, mt)

            EVENT_ON_CLEANUP:register_action(pid, on_cleanup)

            return self
        end

        function thistype:preload_character(code, slot)
            local p = Player(self.pid - 1)

            -- compare profile slot checksum with actual code
            if StringChecksum(tostring(StringHash(code))) ~= self.checksums[slot] then
                DisplayTimedTextToPlayer(p, 0, 0, 300., "|cffff0000Hero data in slot " .. slot .. " is corrupt and will not be loaded!|r")
                return nil
            end

            local data, err = Decompile(code, p)

            -- fail to load
            if err then
                DisplayTimedTextToPlayer(p, 0, 0, 30., err)
                return nil
            end

            local hero = HeroData.create()
            self.character_code[slot] = code
            self.storage[slot] = hero

            hero:propagate(data)
        end

        ---@return boolean
        local function profile_click()
            local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
            local dw    = DialogWindow[pid] ---@type DialogWindow 
            local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

            if index ~= -1 then
                thistype[pid] = thistype.create(pid)
                thistype[pid].brand_new = true
                thistype[pid].new_char = true
                thistype[pid]:hero_select()

                SetupDefaultHotkeys(pid)

                dw:destroy()
            end

            return false
        end

        ---@param pid integer
        function thistype.new(pid)
            if thistype[pid] and thistype[pid].brand_new then
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 30, "You already started a new profile!")
            else
                local dw = DialogWindow.create(pid, "Start a new profile?\n|cFFFF0000Any existing profile will be\noverwritten.|r", profile_click) ---@type DialogWindow

                dw:addButton("Yes")
                dw:display()
            end
        end

        function thistype:get_empty_slot()
            for i = 1, MAX_SLOTS do
                if self.checksums[i] == 0 then
                    self.current_slot = i
                    return
                end
            end

            self.current_slot = -1
        end

        ---@type fun(pid: integer)
        function thistype:repick()
            -- return if in hero selection
            if SELECTING_HERO[self.pid] then
                return
            end

            local p = Player(self.pid - 1)

            -- allow repicking after hardcore death
            if self.playing then
                if IsUnitPaused(Hero[self.pid]) or not UnitAlive(Hero[self.pid]) then
                    DisplayTextToPlayer(p, 0, 0, "You can't repick right now.")
                    return
                elseif RectContainsUnit(gg_rct_Tavern, Hero[self.pid]) or RectContainsUnit(gg_rct_Town_Main, Hero[self.pid]) or RectContainsUnit(gg_rct_Church, Hero[self.pid]) then
                else
                    DisplayTextToPlayer(p, 0, 0, "You can only repick in church, town or tavern.")
                    return
                end
            end

            -- close stat window
            if GetLocalPlayer() == p then
                BlzFrameSetVisible(STAT_WINDOW.frame, false)
            end

            -- reset multiboard
            local mb = MULTIBOARD.BOSS
            mb.viewing[self.pid] = nil
            mb.available[self.pid] = false
            MULTIBOARD.MAIN:display(self.pid)

            PlayerCleanup(self.pid)
            self:hero_select()

            self:get_empty_slot()
            self.new_char = true
        end

        local function on_save_expire(self)
            local success = self:save()

            -- save timer logic
            if self.autosave then
                if not success then
                    self.save_timer = TimerQueue:callDelayed(30., on_save_expire, self)
                elseif success then
                    self.save_timer = TimerQueue:callDelayed(1800., on_save_expire, self)
                end
            else
                if success then
                    self.save_timer = TimerQueue:callDelayed(1800., DoNothing)
                end
            end
        end

        ---@type fun(self: Profile)
        function thistype:toggleAutoSave()
            local time = self.save_timer and TimerQueue:getRemaining(self.save_timer) or 1800.

            if self.autosave then
                TimerQueue:disableCallback(self.save_timer)
                self.save_timer = TimerQueue:callDelayed(time, DoNothing)
                DisplayTextToPlayer(Player(self.pid - 1), 0, 0, "|cffffcc00Autosave disabled.|r")
            else
                self.save_timer = TimerQueue:callDelayed(time, on_save_expire, self.pid)
                DisplayTextToPlayer(Player(self.pid - 1), 0, 0, "|cffffcc00Autosave is now enabled -- you will save every 30 minutes or when your next save is available as Hardcore.|r")
            end

            self.autosave = not self.autosave
        end

        ---Displays save cooldown
        ---@type fun(self: Profile)
        function thistype:saveCooldown()
            if self.save_timer then
                local time = TimerQueue:getRemaining(self.save_timer)
                local text = RemainingTimeString(time)

                if self.autosave then
                    DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 20, "Your next autosave is in " .. text .. ".")
                elseif self.hero.hardcore > 0 then
                    DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 20, text .. " until you can save again.")
                end
            end
        end

        function thistype:save()
            local p = Player(self.pid - 1)

            if not self.cannot_load then
                DisplayTextToPlayer(p, 0, 0, "You must leave the church to save.")
                return false
            end

            if not self.playing or GetUnitTypeId(Hero[self.pid]) == 0 or UnitAlive(Hero[self.pid]) == false then
                DisplayTextToPlayer(p, 0, 0, "An error occured while attempting to save.")
                return false
            end

            -- autosave ignores location save restrictions
            if not self.autosave then

                -- hardcore save logic
                if self.hero.hardcore > 0 then
                    local time = self.save_timer and TimerQueue:getRemaining(self.save_timer) or 0

                    if time > 1 then
                        local text = RemainingTimeString(time)
                        DisplayTimedTextToPlayer(p, 0, 0, 20, text .. " until you can save again.")
                        return false
                    elseif RectContainsCoords(gg_rct_Church, GetUnitX(Hero[self.pid]), GetUnitY(Hero[self.pid])) == false then
                        DisplayTimedTextToPlayer(p, 0, 0, 30, "|cffFF0000You're playing in hardcore mode, you may only save inside the church in town.|r")
                        return false
                    end
                end

                self.save_timer = TimerQueue:callDelayed(1800., DoNothing)
            end

            if GetLocalPlayer() == p then
                ClearTextMessages()
            end

            self:save_character()

            return true
        end

        function thistype:new_character(id)
            local hero = HeroData.create()
            self.storage[self.current_slot] = hero
            hero.id = SAVE_TABLE.KEY_UNITS[id]
        end

        function thistype:delete_character()
            local path = GetCharacterPath(self.pid, self.current_slot)
            if GetLocalPlayer() == GetTriggerPlayer() then
                FileIO.Save(path, "")
            end
            self.storage[self.current_slot] = nil
            self.character_code[self.current_slot] = nil
            self:save_profile()
        end

        local toggle_delete = {} ---@type boolean[] 

        local function load_menu()
            local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
            local dw    = DialogWindow[pid]
            local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

            -- new character button
            if GetClickedButton() == dw.MenuButton[2] then
                thistype[pid]:get_empty_slot()

                if thistype[pid]:getSlotsUsed() >= MAX_SLOTS then
                    DisplayTimedTextToPlayer(GetTriggerPlayer(), 0, 0, 30.0, "You cannot save more than " .. MAX_SLOTS .. " heroes!")
                    dw.Page = -1
                    dw:display()
                else
                    if not SELECTING_HERO[pid] then
                        thistype[pid].new_char = true
                        thistype[pid]:hero_select()
                    end

                    dw:destroy()
                end
            -- load / delete button
            elseif GetClickedButton() == dw.MenuButton[3] then
                -- stay at the same page
                if dw.Page > -1 then
                    dw.Page = dw.Page - 1
                end

                if toggle_delete[pid] then
                    toggle_delete[pid] = false
                    dw.MenuButtonName[3] = "|cffff0000Delete Character"
                    dw.title = "|cffffffffLOAD"
                    dw:display()
                else
                    toggle_delete[pid] = true
                    dw.MenuButtonName[3] = "|cffffffffLoad Character"
                    dw.title = "|cffff0000DELETE"
                    dw:display()
                end
            -- character slot
            elseif index ~= -1 then
                local slot = dw.data[index]
                thistype[pid].current_slot = slot
                dw:destroy()

                if toggle_delete[pid] then
                    -- confirm delete character
                    dw = DialogWindow.create(pid, "Are you sure?|nAny perk bonuses from this character will be lost!", ConfirmDeleteCharacter)
                    dw:addButton("|cffff0000DELETE")
                    dw:display()
                else
                    -- load character
                    thistype[pid].new_char = false
                    DisplayTextToPlayer(GetTriggerPlayer(), 0, 0, "Loading |c006969ffhero|r from selected slot...")
                    CharacterSetup(pid, true)
                end
            end

            return false
        end

        function thistype:hero_select()
            if GetLocalPlayer() == Player(self.pid - 1) then
                EnablePreSelect(false, false)
                EnableSelect(false, false)
                SetDayNightModels("Environment\\DNC\\DNCAshenvale\\DNCAshenValeTerrain\\DNCAshenValeTerrain.mdx","Environment\\DNC\\DNCAshenvale\\DNCAshenValeTerrain\\DNCAshenValeTerrain.mdx")
            end

            SELECTING_HERO[self.pid] = true
            SetCurrency(self.pid, GOLD, 100)
            SetCamera(self.pid, gg_rct_Tavern)

            StartHeroSelect(self.pid)
        end

        function thistype:open_dialog()
            local dw = DialogWindow.create(self.pid, "|cffffffffLOAD", load_menu)

            toggle_delete[self.pid] = false

            for i = 1, MAX_SLOTS do
                if self.checksums[i] > 0 and self.character_code[i] then -- slot is not empty
                    local name = "|cffffcc00"
                    local storage = self.storage[i]

                    if storage.prestige > 0 then
                        name = name .. "[PRSTG] "
                    end
                    name = name .. GetObjectName(SAVE_UNIT_TYPE[storage.id]) .. " [" .. (storage.level) .. "] "
                    if storage.hardcore > 0 then
                        name = name .. "[HC]"
                    end

                    dw:addButton(name, i)
                end
            end

            dw:addMenuButton("|cffffffffNew Character")
            dw:addMenuButton("|cffff0000Delete Character")

            dw:display()
        end

        ---@type fun(code: string, pid: integer): boolean
        function thistype.load(code, pid)
            local p = Player(pid - 1)
            local data, err = Decompile(code, p)

            -- safety
            if err then
                DisplayTimedTextToPlayer(p, 0, 0, 30., err)
                return false
            end

            local index = 1
            -- load version
            local version = data[index]

            -- TODO: implement version handling
            if version <= SAVE_LOAD_VERSION - 2 or version >= SAVE_LOAD_VERSION + 2 then
                DisplayTimedTextToPlayer(p, 0, 0, 30., "Profile data corrupt or version mismatch!")
                return false
            end

            print("Save Load Version: " .. (version))

            local self = Profile.create(pid)

            -- load slot checksums
            for i = 1, MAX_SLOTS do
                index = index + 1
                self.checksums[i] = data[index]
            end

            -- load hotkeys
            local hotkeys = GetHotkeyTable()
            for i = 1, #hotkeys do
                index = index + 1
                LoadHotkey(pid, data[index], i)
            end

            -- load total time
            index = index + 1
            self.total_time = data[index]
            self.profile_code = code
            thistype[pid] = self

            return true
        end

        ---@return integer
        function thistype:getSlotsUsed()
            local count = 0

            for i = 1, MAX_SLOTS do
                if self.checksums[i] > 0 then
                    count = count + 1
                end
            end

            return count
        end

        -- save all codes in backup folder with time stamp
        function thistype:generate_backup()
            local backup_folder = MAP_NAME .. "\\BACKUP\\" .. User[self.pid - 1].name .. "\\" .. os.date("\x25B_\x25d_\x25Y_\x25H_\x25M")

            if GetLocalPlayer() == Player(self.pid - 1) then
                FileIO.Save(backup_folder .. "\\profile.pld", "\n" .. self.profile_code)

                for i = 1, MAX_SLOTS do
                    if self.character_code[i] then
                        local hero_name = GetObjectName(SAVE_UNIT_TYPE[self.storage[i].id])
                        FileIO.Save(backup_folder .. "\\slot" .. i .. ".pld", hero_name .. " " .. self.storage[i].level .. "\n" .. self.character_code[i])
                    end
                end
            end
        end

        -- this should be called after saving the character
        function thistype:save_profile()
            local p = Player(self.pid - 1)
            local data = {}

            data[#data + 1] = SAVE_LOAD_VERSION

            for i = 1, MAX_SLOTS do
                if i == self.current_slot then
                    self.checksums[i] = (self.character_code[i] and StringChecksum(tostring(StringHash(self.character_code[i])))) or 0
                end

                data[#data + 1] = self.checksums[i]
            end

            -- save hotkeys to profile
            local hotkeys = GetHotkeyTable()
            for i = 1, #hotkeys do
                data[#data + 1] = SaveHotkey(self.pid, i)
            end

            data[#data + 1] = self.total_time
            self.profile_code = Compile(self.pid, data)

            if GAME_STATE == 2 then
                local path = GetProfilePath(self.pid)

                if GetLocalPlayer() == p then
                    FileIO.Save(path, "\n" .. self.profile_code)
                end

                self:generate_backup()

                DisplayTimedTextToPlayer(p, 0, 0, 120, "-------------------------------------------------------------------")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "|cffffcc00Your data has been saved successfully at:|r")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "(Warcraft III\\CustomMapData\\" .. MAP_NAME .. "\\" .. GetPlayerName(p) .. ")")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "|cffffcc00Make sure to type|r -load |cffffcc00the next time you play.|r")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "|cffffcc00A backup of your data has also been created at:|r")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "(" .. MAP_NAME .. "\\BACKUP\\" .. GetPlayerName(p) .. "\\" .. os.date("\x25B_\x25d_\x25Y_\x25H_\x25M") .. ")")
                DisplayTimedTextToPlayer(p, 0, 0, 120, "-------------------------------------------------------------------")
            end
        end

        function thistype:save_character()
            local p = Player(self.pid - 1)
            local hero = self.hero

            -- update hero data
            hero.level = GetHeroLevel(Hero[self.pid])
            hero.str = math.min(MAX_STATS, Unit[Hero[self.pid]].str)
            hero.agi = math.min(MAX_STATS, Unit[Hero[self.pid]].agi)
            hero.int = math.min(MAX_STATS, Unit[Hero[self.pid]].int)
            hero.gold = math.min(GetCurrency(self.pid, GOLD), MAX_GOLD)
            hero.platinum = math.min(GetCurrency(self.pid, PLATINUM), MAX_PLAT_CRYS)
            hero.crystal = math.min(GetCurrency(self.pid, CRYSTAL), MAX_PLAT_CRYS)
            hero.honor = math.min(GetCurrency(self.pid, HONOR), MAX_HONOR)
            hero.faction_points = math.min(GetCurrency(self.pid, FACTION), MAX_FACTION)
            hero.teleport = GetUnitAbilityLevel(Backpack[self.pid], TELEPORT_HOME.id)
            hero.reveal = GetUnitAbilityLevel(Backpack[self.pid], FourCC('A0FK'))
            hero.time = math.min(hero.time, MAX_TIME_PLAYED)

            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = hero.items[i]
                if itm then
                    itm.owner = p -- bind items after saving
                    hero.item_id[i] = itm:encode_id()
                    hero.item_stats[i] = itm:encode_stats()
                else
                    hero.item_id[i] = 0
                    hero.item_stats[i] = 0
                end
            end

            local s = Compile(self.pid, hero:values())

            if GAME_STATE == 2 then
                local hero_name = GetObjectName(HeroID[self.pid])
                local path = GetCharacterPath(self.pid, self.current_slot)

                if GetLocalPlayer() == p then
                    FileIO.Save(path, hero_name .. " " .. self.hero.level .. "\n" .. s)
                end
            end

            self.character_code[self.current_slot] = s
            self:save_profile()
        end

        function thistype:skin(index)
            self.hero.skin = index

            BlzSetUnitSkin(Backpack[self.pid], CosmeticTable.skins[index].id)
            if CosmeticTable.skins[index].id == FourCC('H02O') then
                AddUnitAnimationProperties(Backpack[self.pid], "alternate", true)
            end
        end
    end

    local function move_expire(unit)
        unit.busy = false
    end

    local function backpack_ai(source, _, id)
        if id ~= ORDER_ID_MOVE then
            local unit = Unit[source]
            unit.busy = true
            if unit.callback then
                TimerQueue:disableCallback(unit.callback)
            end
            unit.callback = TimerQueue:callDelayed(4, move_expire, unit)
        end
    end

    local function backpack_periodic(bp, pid)
        if bp then
            local x = GetUnitX(Hero[pid]) + 50 * math.cos((GetUnitFacing(Hero[pid]) - 45) * bj_DEGTORAD)
            local y = GetUnitY(Hero[pid]) + 50 * math.sin((GetUnitFacing(Hero[pid]) - 45) * bj_DEGTORAD)

            if IsUnitInRange(Hero[pid], bp, 1000.) == false then
                SetUnitXBounded(bp, x)
                SetUnitYBounded(bp, y)
                BlzUnitClearOrders(bp, false)
            elseif not Unit[bp].busy or IsUnitInRange(Hero[pid], bp, 800.) == false then
                if IsUnitInRange(Hero[pid], bp, 50.) == false then
                    IssuePointOrderById(bp, ORDER_ID_MOVE, x, y)
                end
            end

            TimerQueue:callDelayed(0.35, backpack_periodic, bp, pid)
        end
    end

    ---@class HeroData
    ---@field id integer
    ---@field hardcore boolean
    ---@field prestige integer
    ---@field level integer
    ---@field str integer
    ---@field agi integer
    ---@field int integer
    ---@field gold integer
    ---@field platinum integer
    ---@field crystal integer
    ---@field time integer
    ---@field items Item[]
    ---@field item_id integer[]
    ---@field item_stats integer[]
    ---@field teleport integer
    ---@field reveal integer
    ---@field skin integer
    ---@field create function
    ---@field values function
    ---@field propagate function
    ---@field load_data function
    ---@field item_to_drop Item
    HeroData = {}
    do
        local thistype = HeroData
        local mt = { __index = thistype }

        local keys = {
            "id", "hardcore", "prestige", "level", "str", "agi", "int", "gold", "platinum", "crystal", "time", "item_id", "item_stats", "teleport", "reveal", "skin"
        }

        local setter = {
            id = function(pid, value)
                local hero = CreateUnit(Player(pid - 1), SAVE_UNIT_TYPE[value], GetRectCenterX(gg_rct_ChurchSpawn), GetRectCenterY(gg_rct_ChurchSpawn), 0.)
                local id = SAVE_UNIT_TYPE[value]
                Hero[pid] = hero
                HeroID[pid] = id
                PLAYER_SELECTED_UNIT[pid] = hero

                Unit[hero].mr = HERO_STATS[id].magic_resist
                Unit[hero].pr = HERO_STATS[id].phys_resist
                Unit[hero].pm = HERO_STATS[id].phys_damage
                Unit[hero].cc_flat = HERO_STATS[id].crit_chance
                Unit[hero].cd_flat = HERO_STATS[id].crit_damage
                Unit[hero].mana_regen_max = HERO_STATS[id].mana_regen_max or 0

                -- backpack
                local backpack = CreateUnit(Player(pid - 1), BACKPACK, GetRectCenterX(gg_rct_ChurchSpawn), GetRectCenterY(gg_rct_ChurchSpawn), 0)
                Backpack[pid] = backpack

                -- show backpack hero panel only for player
                if GetLocalPlayer() == Player(pid - 1) then
                    EnablePreSelect(true, true)
                    EnableSelect(true, true)
                    ClearSelection()
                    SelectUnit(hero, true)
                    ResetToGameCamera(0)
                    PanCameraToTimed(GetUnitX(hero), GetUnitY(hero), 0)
                    BlzSetUnitBooleanField(backpack, UNIT_BF_HERO_HIDE_HERO_INTERFACE_ICON, false)
                end

                SetUnitOwner(backpack, Player(PLAYER_NEUTRAL_PASSIVE), false)
                SetUnitOwner(backpack, Player(pid - 1), false)
                SetUnitAnimation(backpack, "stand")
                SuspendHeroXP(backpack, true)
                UnitAddAbility(backpack, TELEPORT.id)
                UnitAddAbility(backpack, FourCC('A0FK'))
                UnitAddAbility(backpack, TELEPORT_HOME.id)
                UnitAddAbility(backpack, FourCC('A04M'))
                UnitAddAbility(backpack, FourCC('A00F')) -- settings

                TimerQueue:callDelayed(0.01, backpack_periodic, backpack, pid)
                EVENT_ON_ORDER:register_unit_action(backpack, backpack_ai)

                -- grave
                HeroGrave[pid] = CreateUnit(Player(pid - 1), GRAVE, 30000, 30000, 270)
                SuspendHeroXP(HeroGrave[pid], true)
                ShowUnit(HeroGrave[pid], false)

                UnitAddAbility(hero, FourCC('A015')) -- hidden spells
                UnitMakeAbilityPermanent(hero, true, FourCC('A015'))
                UnitAddAbility(backpack, FourCC('A015')) -- hidden spells
                UnitMakeAbilityPermanent(backpack, true, FourCC('A015'))
            end,
            hardcore = function(pid, value)
                if value > 0 and Profile[pid].new_char then
                    TimerQueue:callDelayed(0.01, PlayerAddItemById, pid, FourCC('I03N'))
                end
            end,
            level = function(pid, value)
                if value > 1 then
                    SetHeroLevel(Hero[pid], value, false)
                    SetHeroLevel(Backpack[pid], value, false)
                end
            end,
            str = function(pid, value)
                local unit = Unit[Hero[pid]]

                unit.str = value or unit.str
            end,
            agi = function(pid, value)
                local unit = Unit[Hero[pid]]

                unit.agi = value or unit.agi
            end,
            int = function(pid, value)
                local unit = Unit[Hero[pid]]

                unit.int = value or unit.int
            end,
            gold = function(pid, value)
                SetCurrency(pid, GOLD, value)
            end,
            platinum = function(pid, value)
                SetCurrency(pid, PLATINUM, value)
            end,
            crystal = function(pid, value)
                SetCurrency(pid, CRYSTAL, value)
            end,
            honor = function(pid, value)
                SetCurrency(pid, HONOR, value)
            end,
            faction_points = function(pid, value)
                SetCurrency(pid, FACTION, value)
            end,
            item_id = function(pid, value)
                local hero = Profile[pid].hero

                for j = 1, MAX_INVENTORY_SLOTS do
                    local itm = Item.decode(hero.item_id[j], hero.item_stats[j], j)
                    if itm then
                        itm.pid = pid
                        itm:equip(j)
                        itm.owner = Player(pid - 1)
                    end
                end
            end,
            teleport = function(pid, value)
                SetUnitAbilityLevel(Backpack[pid], TELEPORT_HOME.id, value)
                SetUnitAbilityLevel(Backpack[pid], TELEPORT.id, value)
            end,
            reveal = function(pid, value)
                SetUnitAbilityLevel(Backpack[pid], FourCC('A0FK'), value)
            end,
            skin = function(pid, value)
                Profile[pid]:skin(value)
            end,
        }

        function thistype:load_data(pid)
            for i = 1, #keys do
                local key = keys[i]

                if setter[key] then
                    setter[key](pid, self[key])
                end
            end
        end

        ---@return integer[]
        function thistype:values()
            local result = {}

            for i = 1, #keys do
                local key = keys[i]

                if key == "item_id" or key == "item_stats" then
                    for j = 1, MAX_INVENTORY_SLOTS do
                        result[#result + 1] = self[key][j]
                    end
                else
                    result[#result + 1] = self[key]
                end
            end

            return result
        end

        ---@param data integer[]
        function thistype:propagate(data)
            local index = 1

            for i = 1, #keys do
                local key = keys[i]

                if key == "item_id" or key == "item_stats" then
                    for j = 1, MAX_INVENTORY_SLOTS do
                        self[key][j] = data[index]
                        index = index + 1
                    end
                else
                    self[key] = data[index]
                    index = index + 1
                end
            end
        end

        ---@return HeroData
        function HeroData.create()
            -- default values, some may not be necessary
            local self = setmetatable({
                hardcore = 0,
                prestige = 0,
                level = 1,
                gold = 100,
                platinum = 0,
                crystal = 0,
                time = 0,
                items = {},
                item_id = __jarray(0),
                item_stats = __jarray(0),
                teleport = 1,
                reveal = 1,
                skin = 25, -- wisp
            }, mt)

            return self
        end
    end

    ---@type fun(level: integer):integer
    function TomeCap(level)
        return math.floor(level ^ 4 * 0.000003 + 10 * level + level ^ 3 * 0.0005)
    end

    local function on_hero_death(killed, killer)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1

        -- disable backpack teleports
        DisableBackpackTeleports(pid, true)
        -- disable inventory (ankh cheese)
        DisableItems(pid, true)
        -- grave
        UnitRemoveAbility(Hero[pid], FourCC('BEme')) -- remove meta
        ShowUnit(HeroGrave[pid], true)
        SetUnitVertexColor(HeroGrave[pid], 175, 175, 175, 0)
        if IsTerrainWalkable(x, y) then
            SetUnitPosition(HeroGrave[pid], x, y)
        else
            SetUnitPosition(HeroGrave[pid], TERRAIN_X, TERRAIN_Y)
        end
        TimerQueue:callDelayed(1., SpawnGrave, pid)
    end

    ---@type fun(pid: integer, load: boolean)
    function CharacterSetup(pid, load)
        local hero = Profile[pid].hero
        local x, y, angle, camera = SETUP_X, SETUP_Y, 0, MAIN_MAP.rect -- outside tavern

        hero:load_data(pid)

        if load then
            x, y, angle, camera = GetRectCenterX(gg_rct_ChurchSpawn), GetRectCenterY(gg_rct_ChurchSpawn), 270., gg_rct_Church
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ReviveHuman\\ReviveHuman.mdl", Hero[pid], "origin"))
        else
            -- new characters can save immediately
            Profile[pid].cannot_load = true

            -- default potions
            PlayerAddItemById(pid, 'I02F')
            PlayerAddItemById(pid, 'I00E')
        end

        if GetLocalPlayer() == Player(pid - 1) then
            BlzSetAbilityPosY(HERO_STATS[HeroID[pid]].passive, 0)
        end

        SetUnitPosition(Hero[pid], x, y)
        SetUnitPosition(Backpack[pid], x, y)
        BlzSetUnitFacingEx(Hero[pid], angle)
        SetCamera(pid, camera)

        SELECTING_HERO[pid] = false
        Profile[pid].playing = true

        -- heal to max
        SetWidgetLife(Hero[pid], BlzGetUnitMaxHP(Hero[pid]))
        SetUnitState(Hero[pid], UNIT_STATE_MANA, (HeroID[pid] ~= HERO_VAMPIRE and BlzGetUnitMaxMana(Hero[pid])) or 0)

        EVENT_ON_UNIT_DEATH:register_unit_action(Hero[pid], on_hero_death)
        EVENT_STAT_CHANGE:register_unit_action(Hero[pid], UpdateSpellTooltips)
        EVENT_ON_SETUP:trigger(pid)
    end

end, Debug and Debug.getLine())
