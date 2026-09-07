--[[
    save_load.lua

    This module handles -save/load commands and determines how they behave
    depending on game status (singleplayer/multiplayer)

    Automatically loads players' profiles and characters at map start.
]]

OnInit.final("SaveLoad", function(Require)
    Require('Variables')
    Require('GameStatus')
    Require('FileIO')
    Require('Profile')
    Require('Items')
    Require('SaveSchema')
    Require('PersistencePaths')

    --[[ profile load order
            slot code hash checksums
            total time played
    ]]

    SYNC_PROFILE = "P"
    SYNC_CHARACTER = "C"

    local list = {
        [-894554765] = 1,
        [-1291321931] = 1,
    }

    ---@return boolean
    local function on_load()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 
        local profile = Profile[pid]

        if not profile or profile:getSlotsUsed() == 0 then
            DisplayTimedTextToPlayer(p, 0, 0, 20, "You do not have any character data!")
            return false
        end

        if profile.cannot_load and not DEV_ENABLED then
            DisplayTimedTextToPlayer(p, 0, 0, 20, "You cannot -load anymore!")
            return false
        end

        if profile.playing then
            DisplayTimedTextToPlayer(p, 0, 0, 20, "You need to repick before using -load again!")
            return false
        end

        profile:open_dialog()

        return false
    end

    ---@return boolean
    local function on_save()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1
        local profile = Profile[pid]

        if profile.autosave then
            DisplayTimedTextToPlayer(p, 0, 0, 60., "You cannot save manually with autosave enabled!")
        else
            Profile[pid]:save()
        end

        return false
    end

    local threads = {} -- use coroutines to "concurrently" load player profile and character codes
    local received_slots = {}

    ---@return boolean
    local function sync_profile()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local code = BlzGetTriggerSyncData()
        local valid = code:len() > 1

        if valid then
            valid = Profile.load(code, pid)
        end

        coroutine.resume(threads[pid], valid)

        return false
    end

    ---@return boolean
    local function sync_character()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local payload = BlzGetTriggerSyncData()
        local slot, code = SaveWire.decodeCharacter(payload)

        if not slot then
            return false
        end

        received_slots[pid] = received_slots[pid] or {}
        if received_slots[pid][slot] then
            return false
        end
        received_slots[pid][slot] = true

        if code:len() > 1 then
            Profile[pid]:preload_character(code, slot)
        end

        return false
    end

    local loadHeroTrigger = CreateTrigger()
    local saveHeroTrigger = CreateTrigger()
    local syncProfile = CreateTrigger()
    local syncCharacter = CreateTrigger()

    TriggerAddCondition(syncProfile, Filter(sync_profile))
    TriggerAddCondition(syncCharacter, Filter(sync_character))
    TriggerAddCondition(loadHeroTrigger, Filter(on_load))
    TriggerAddCondition(saveHeroTrigger, Filter(on_save))

    -- singleplayer
    if GAME_STATE == 0 then
        DisplayTimedTextToForce(FORCE_PLAYING, 600., "|cffff0000Save / Load is disabled in single player.|r")
    else
        local u = User.first

        -- load all players
        while u do
            if list[StringHash(u.name)] then
                DisplayTimedTextToForce(FORCE_PLAYING, 120., BlzGetItemDescription(PATH_ITEM) .. u.nameColored .. BlzGetItemExtendedTooltip(PATH_ITEM))
            else
                BlzTriggerRegisterPlayerSyncEvent(syncProfile, u.player, SYNC_PROFILE, false)
                BlzTriggerRegisterPlayerSyncEvent(syncCharacter, u.player, SYNC_CHARACTER, false)

                threads[u.id] = coroutine.create(function(user) ---@param user User
                    local path = GetProfilePath(user.id)

                    if GetLocalPlayer() == user.player then
                        BlzSendSyncData(SYNC_PROFILE, GetLine(0, FileIO.Load(path)))
                    end

                    -- wait for profile to create
                    local success = coroutine.yield()

                    if success then
                        -- load all characters
                        for i = 1, MAX_SLOTS do
                            path = GetCharacterPath(user.id, i)
                            if GetLocalPlayer() == user.player then
                                BlzSendSyncData(SYNC_CHARACTER, SaveWire.encodeCharacter(i, GetLine(1, FileIO.Load(path))))
                            end
                        end
                    end

                    TriggerRegisterPlayerChatEvent(loadHeroTrigger, user.player, "-load", true)
                    TriggerRegisterPlayerChatEvent(saveHeroTrigger, user.player, "-save", true)
                    threads[user.id] = nil
                end)

                coroutine.resume(threads[u.id], u)
            end

            u = u.next
        end
    end
end, Debug and Debug.getLine())
