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
        character format magic/version
        scalar hero data
        inventory slots
            item id/stats/extra
            socket count
            socket id/stats/extra

]]

OnInit.final("Profile", function(Require)
    Require('HeroDefinitions')
    Require('MainMap')
    MAX_INVENTORY_SLOTS = 26 ---@type integer 
    BACKPACK_INDEX      = 9
    POTION_INDEX        = 7

    Require('CodeGen')
    Require('TimerQueue')
    Require('Hotkeys')
    Require('SaveSchema')

    local cos, sin = math.cos, math.sin
    local SETUP_X = -690.
    local SETUP_Y = -238.

    local MAX_TIME_PLAYED     = 10000000 -- ~10 years in minutes
    local MAX_PLAT_CRYS       = 100000
    local MAX_GOLD            = 10000000
    local MAX_HONOR           = 100000
    local MAX_FACTION         = 100000
    local MAX_UPGRADE_LEVEL   = 10
    local MAX_STATS           = 255000
    local CHARACTER_SAVE_MAGIC = 271828

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

            Hero[pid] = nil
            Backpack[pid] = nil
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
            local success, propagate_err = hero:propagate(data)

            if not success then
                DisplayTimedTextToPlayer(p, 0, 0, 30., propagate_err or "Unsupported character save data.")
                return nil
            end

            self.character_code[slot] = code
            self.storage[slot] = hero
            return hero
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
            hero.unit_id = id
            hero.hardcore = 0
            hero.prestige = 0
            hero.level = 1
            hero.str = HERO_STATS[id].str
            hero.agi = HERO_STATS[id].agi
            hero.int = HERO_STATS[id].int
            hero.gold = 100
            hero.platinum = 0
            hero.crystal = 0
            hero.honor = 0
            hero.faction_points = 0
            hero.time = 0
            hero.teleport = 1
            hero.reveal = 1
            hero.skin = 25
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

        ---@return boolean
        local function confirm_delete_character()
            local pid   = GetPlayerId(GetTriggerPlayer()) + 1
            local dw    = DialogWindow[pid]
            local index = dw:getClickedIndex(GetClickedButton())

            if index ~= -1 then
                Profile[pid]:delete_character()

                dw:destroy()
            end

            return false
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
                    dw = DialogWindow.create(pid, "Are you sure?|nAny perk bonuses from this character will be lost!", confirm_delete_character)
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
            local version = data[index] or 0

            if version ~= PROFILE_SAVE_VERSION then
                DisplayTimedTextToPlayer(p, 0, 0, 30., "Profile data corrupt or version mismatch!")
                return false
            end

            print("Profile Save Version: " .. (version))

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
            local backup_folder = MAP_NAME .. "\\BACKUP\\" .. User[self.pid - 1].name .. "\\" .. os.date("%B_%d_%Y_%H_%M")

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

            data[#data + 1] = PROFILE_SAVE_VERSION

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
                DisplayTimedTextToPlayer(p, 0, 0, 120, "(" .. MAP_NAME .. "\\BACKUP\\" .. GetPlayerName(p) .. "\\" .. os.date("%B_%d_%Y_%H_%M") .. ")")
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
                    itm.owner = p
                end
            end

            local s = Compile(self.pid, hero:values())

            if GAME_STATE == 2 then
                local hero_name = GetObjectName(hero.unit_id)
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

    local function backpack_periodic(pt)
        local pid = pt.pid
        local hero = Hero[pid]
        local bp = Backpack[pid]
        local facing = GetUnitFacing(hero)
        local x = GetUnitX(hero) + 50 * cos((facing - 45) * bj_DEGTORAD)
        local y = GetUnitY(hero) + 50 * sin((facing - 45) * bj_DEGTORAD)

        if not IsUnitInRange(hero, bp, 1000.) then
            SetUnitXBounded(bp, x)
            SetUnitYBounded(bp, y)
            BlzUnitClearOrders(bp, false)
        elseif not Unit[bp].busy or not IsUnitInRange(Hero[pid], bp, 800.) then
            if IsUnitInRange(Hero[pid], bp, 50.) == false then
                IssuePointOrderById(bp, ORDER_ID_MOVE, x, y)
            end
        end

        return true
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
    ---@field saved_items table[]
    ---@field honor integer
    ---@field faction_points integer
    ---@field teleport integer
    ---@field reveal integer
    ---@field skin integer
    ---@field summon_essence integer
    ---@field create function
    ---@field values function
    ---@field propagate function
    ---@field load_data function
    ---@field item_to_drop Item
    HeroData = {}
    do
        local thistype = HeroData
        local mt = { __index = thistype }

        local scalar_keys = {
            "id",
            "hardcore",
            "prestige",
            "level",
            "str",
            "agi",
            "int",
            "gold",
            "platinum",
            "crystal",
            "honor",
            "faction_points",
            "time",
            "teleport",
            "reveal",
            "skin",
        }

        local setter = {
            id = function(pid, value)
                local unit_id = SAVE_UNIT_TYPE[value]

                if not unit_id or unit_id == 0 then
                    return false
                end

                local hero = CreateUnit(Player(pid - 1), unit_id, GetRectCenterX(gg_rct_ChurchSpawn), GetRectCenterY(gg_rct_ChurchSpawn), 0.)
                Hero[pid] = hero
                PLAYER_SELECTED_UNIT[pid] = hero

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

                -- force refresh
                SetUnitOwner(backpack, Player(PLAYER_NEUTRAL_PASSIVE), false)
                SetUnitOwner(backpack, Player(pid - 1), false)

                -- locust trick (disable directly clicking)
                UnitAddAbility(backpack, ABIL_ALOC)
                ShowUnit(backpack, false)
                ShowUnit(backpack, true)
                UnitRemoveAbility(backpack, ABIL_ALOC)

                SetUnitAnimation(backpack, "stand")
                SuspendHeroXP(backpack, true)
                UnitAddAbility(backpack, TELEPORT.id)
                UnitAddAbility(backpack, FourCC('A0FK'))
                UnitAddAbility(backpack, TELEPORT_HOME.id)
                UnitAddAbility(backpack, FourCC('A04M'))
                UnitAddAbility(backpack, FourCC('A00F')) -- settings

                local pt = TimerList[pid]:add()
                pt:startLoop(0.35, backpack_periodic)
                EVENT_ON_ORDER:register_unit_action(backpack, backpack_ai)

                -- grave
                HeroGrave[pid] = CreateUnit(Player(pid - 1), GRAVE, 30000, 30000, 270)
                SuspendHeroXP(HeroGrave[pid], true)
                ShowUnit(HeroGrave[pid], false)

                UnitAddAbility(hero, FourCC('A015')) -- hidden spells
                UnitMakeAbilityPermanent(hero, true, FourCC('A015'))
                UnitAddAbility(backpack, FourCC('A015')) -- hidden spells
                UnitMakeAbilityPermanent(backpack, true, FourCC('A015'))

                return true
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

        local function read_value(data, index)
            return data[index] or 0
        end

        local function serialize_item(result, itm)
            if not itm then
                result[#result + 1] = 0
                return
            end

            local id = itm:encode_id() or 0
            if id == 0 then
                result[#result + 1] = 0
                return
            end

            result[#result + 1] = id
            result[#result + 1] = itm:encode_stats() or 0
            result[#result + 1] = itm:encode_extra() or 0

            local sockets = itm.sockets or {}
            local count = math.min(#sockets, MAX_SOCKETS)
            result[#result + 1] = count

            for i = 1, count do
                local socket = sockets[i]
                local socket_id = socket and socket:encode_id() or 0

                result[#result + 1] = socket_id or 0
                result[#result + 1] = socket and (socket:encode_stats() or 0) or 0
                result[#result + 1] = socket and (socket:encode_extra() or 0) or 0
            end
        end

        local function deserialize_item(data, index)
            local id = read_value(data, index)
            index = index + 1

            if id == 0 then
                return nil, index
            end

            local saved = {
                id = id,
                stats = read_value(data, index),
                extra = read_value(data, index + 1),
                sockets = {},
            }

            local socket_count = math.min(math.max(0, read_value(data, index + 2)), MAX_SOCKETS)
            index = index + 3

            for i = 1, socket_count do
                local socket_id = read_value(data, index)
                local socket_stats = read_value(data, index + 1)
                local socket_extra = read_value(data, index + 2)
                index = index + 3

                saved.sockets[i] = {
                    id = socket_id,
                    stats = socket_stats,
                    extra = socket_extra,
                }
            end

            return saved, index
        end

        local function instantiate_item(saved)
            if not saved or saved.id == 0 then
                return nil
            end

            local itm = Item.decode(saved.id or 0, saved.stats or 0, saved.extra or 0)
            if not itm then
                return nil
            end

            itm.sockets = {}

            for i = 1, math.min(#saved.sockets, MAX_SOCKETS) do
                local saved_socket = saved.sockets[i]
                local socket = nil

                if saved_socket and saved_socket.id ~= 0 then
                    socket = Item.decode(saved_socket.id or 0, saved_socket.stats or 0, saved_socket.extra or 0)
                end

                if socket then
                    socket.parent = itm
                    socket.socketed = true
                    itm.sockets[#itm.sockets + 1] = socket
                end
            end

            return itm
        end

        function thistype:load_data(pid)
            if setter.id(pid, self.id) == false then
                return false
            end

            for i = 2, #scalar_keys do
                local key = scalar_keys[i]
                if setter[key] then
                    setter[key](pid, self[key])
                end
            end

            local owner = Player(pid - 1)
            for slot = 1, MAX_INVENTORY_SLOTS do
                local itm = instantiate_item(self.saved_items[slot])
                self.items[slot] = itm

                if itm then
                    itm.pid = pid
                    itm.owner = owner

                    for i = 1, #itm.sockets do
                        local socket = itm.sockets[i]
                        socket.pid = pid
                        socket.owner = owner
                    end

                    itm:equip(slot)
                end
            end

            return true
        end

        ---@return integer[]
        function HeroData:values()
            local result = { CHARACTER_SAVE_MAGIC, CHARACTER_SAVE_VERSION }

            for i = 1, #scalar_keys do
                result[#result + 1] = self[scalar_keys[i]] or 0
            end

            for slot = 1, MAX_INVENTORY_SLOTS do
                serialize_item(result, self.items[slot])
            end

            -- Optional trailing data leaves all existing version-1 inventory
            -- offsets intact; an older character payload simply reads zero.
            result[#result + 1] = self.summon_essence or 0

            return result
        end

        local legacy_scalar_keys = {
            "id", "hardcore", "prestige", "level", "str", "agi", "int",
            "gold", "platinum", "crystal", "time",
        }

        local function propagate_legacy(self, data)
            local index = 1

            for i = 1, #legacy_scalar_keys do
                self[legacy_scalar_keys[i]] = data[index]
                index = index + 1
            end

            local ids = {}
            local stats = {}

            for slot = 1, MAX_INVENTORY_SLOTS do
                ids[slot] = data[index] or 0
                index = index + 1
            end

            for slot = 1, MAX_INVENTORY_SLOTS do
                stats[slot] = data[index] or 0
                index = index + 1
            end

            self.teleport = data[index] or 1
            self.reveal = data[index + 1] or 1
            self.skin = data[index + 2] or 25

            for slot = 1, MAX_INVENTORY_SLOTS do
                if ids[slot] ~= 0 then
                    self.saved_items[slot] = {
                        id = ids[slot],
                        stats = stats[slot],
                        extra = 0,
                        sockets = {},
                    }
                end
            end
        end

        ---@param data integer[]
        function HeroData:propagate(data)
            local magic = read_value(data, 1)

            if magic ~= CHARACTER_SAVE_MAGIC then
                propagate_legacy(self, data)
                return true
            end

            local version = read_value(data, 2)
            local index = 3

            if version == 1 then
                -- future migration point if version changes
            elseif version ~= CHARACTER_SAVE_VERSION then
                return false, "Unsupported character save version: " .. tostring(version)
            end

            for i = 1, #scalar_keys do
                self[scalar_keys[i]] = read_value(data, index)
                index = index + 1
            end

            self.unit_id = SAVE_UNIT_TYPE[self.id]

            for slot = 1, MAX_INVENTORY_SLOTS do
                self.saved_items[slot], index = deserialize_item(data, index)
            end

            self.summon_essence = read_value(data, index)

            return true
        end

        ---@return HeroData
        function HeroData.create()
            return setmetatable({
                items = {},
                saved_items = {},
            }, mt)
        end
    end

    ---@type fun(level: integer):integer
    function TomeCap(level)
        return math.floor(level ^ 4 * 0.000003 + 10 * level + level ^ 3 * 0.0005)
    end

    local function on_hero_death(killed, killer)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1
        local x, y = GetUnitX(killed), GetUnitY(killed)

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
        local profile = Profile[pid]
        local hero_data = profile.hero
        local x, y, angle, camera = SETUP_X, SETUP_Y, 0, MAIN_MAP.rect -- outside tavern

        if not hero_data:load_data(pid) then
            DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 30., "Character data could not be recovered.")
            return
        end

        if load then
            x, y, angle, camera = GetRectCenterX(gg_rct_ChurchSpawn), GetRectCenterY(gg_rct_ChurchSpawn), 270., gg_rct_Church
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ReviveHuman\\ReviveHuman.mdl", Hero[pid], "origin"))
        else
            -- new characters can save immediately
            profile.cannot_load = true

            -- give default potions
            PlayerAddItemById(pid, 'I02F')
            PlayerAddItemById(pid, 'I00E')
        end

        -- move passive ability icon position
        if GetLocalPlayer() == Player(pid - 1) then
            BlzSetAbilityPosY(HERO_STATS[hero_data.unit_id].passive, 0)
        end

        local hero = Hero[pid]

        -- set position and camera
        SetUnitPosition(hero, x, y)
        SetUnitPosition(Backpack[pid], x, y)
        BlzSetUnitFacingEx(hero, angle)
        SetCamera(pid, camera)

        -- set to playing and no longer selecting
        SELECTING_HERO[pid] = false
        profile.playing = true

        -- heal to max
        SetWidgetLife(hero, BlzGetUnitMaxHP(hero))
        SetUnitState(hero, UNIT_STATE_MANA, (hero_data.unit_id ~= HERO_VAMPIRE and BlzGetUnitMaxMana(hero)) or 0)

        -- register on death / stat change events
        EVENT_ON_UNIT_DEATH:register_unit_action(hero, on_hero_death)
        EVENT_STAT_CHANGE:register_unit_action(hero, UpdateSpellTooltips)

        -- trigger setup event (for any innates)
        EVENT_ON_SETUP:trigger(pid)

        -- force click event on hero
        EVENT_ON_UNIT_SELECT:trigger(hero, pid)
        EVENT_ON_SELECT:trigger(pid, hero)

        ExperienceControl(pid)
    end

end, Debug and Debug.getLine())
