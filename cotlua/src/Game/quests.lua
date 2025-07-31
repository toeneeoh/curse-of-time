--[[
    quests.lua

    Defines quest behavior and the quest log (F9)
]]

OnInit.final("Quests", function(Require)
    Require('ItemLookup')
    Require('Units')

    GODS_QUEST_MARKER = AddSpecialEffectTarget("Abilities\\Spells\\Other\\TalkToMe\\TalkToMe.mdl", god_angel, "overhead")
    Evil_Shopkeeper_Quest_1 = CreateQuestBJ(bj_QUESTTYPE_OPT_UNDISCOVERED, "The Evil Shopkeeper", "The greedy Evil Shopkeeper finally has a bounty on his head! After mercilessly selling stolen n' smuggled items at outrageous prices and double-crossing everyone that simply crossed his path he has finally got the people angry enough to want him dead. Kill him, and put his evil deeds to and end. But be warned! He is tricky.", "ReplaceableTextures\\CommandButtons\\BTNAcolyte.tga")
    Evil_Shopkeeper_Quest_2 = CreateQuestBJ(bj_QUESTTYPE_OPT_UNDISCOVERED, "The Omega P's Pick", "The Leaders of Team P must be stopped, destroy them and bring back both thier picks as proof to recive the ultimate pick of the Team P hordes.", "ReplaceableTextures\\CommandButtons\\BTNPeon.tga")
    Defeat_The_Horde_Quest  = CreateQuestBJ(bj_QUESTTYPE_OPT_UNDISCOVERED, "The Horde", "The Horde has spread and began to grow in numbers by the second.  They lie in wait, patiently waiting unitl their number are enough to take over the land.  Defeat them before they can organize a full scale attack and desimate the nations of your comrades.", "ReplaceableTextures\\CommandButtons\\BTNThrall.tga")

    -- the goddesses' keys
    do
        Key_Quest = CreateQuestBJ(bj_QUESTTYPE_OPT_UNDISCOVERED, "The Goddesses' Keys", "An angel looking figure stops you in your tracks after you defeated the god slayer, telling you to bring him three keys before he opens up a portal to the gods. One key is hidden in a cave, one is earned by protecting town, and one is held by a troll.", "ReplaceableTextures\\CommandButtons\\BTN3M3.blp")
        local keys = 0

        ITEM_LOOKUP[FourCC('I040')] = function()
            DisplayTextToForce(FORCE_PLAYING, "  - |cff808080Retrieve the Key of Redemption|r")
			StartSound(bj_questItemAcquiredSound)
            keys = keys + 1
        end

        ITEM_LOOKUP[FourCC('I041')] = function()
            DisplayTextToForce(FORCE_PLAYING, "  - |cff808080Retrieve the Key of Valor|r")
			StartSound(bj_questItemAcquiredSound)
            keys = keys + 1
        end

        ITEM_LOOKUP[FourCC('I042')] = function()
            DisplayTextToForce(FORCE_PLAYING, "  - |cff808080Retrieve the Key of Devotion|r")
			StartSound(bj_questItemAcquiredSound)
            keys = keys + 1
        end

        ON_BUY_LOOKUP[FourCC('I00Y')] = function(u, b, pid, itm)
            if IsQuestCompleted(Key_Quest) == false then
                if (PlayerHasItemType(pid, FourCC('I04J')) or PlayerHasItemType(pid, FourCC('I0NJ')) or GetHeroLevel(Hero[pid]) >= 240) or keys == 3 then
                    DisplayTextToForce(FORCE_PLAYING, "|cffffcc00The portal to the gods has opened.|r")
                    QuestSetDiscovered(Key_Quest, true)
                    QuestSetCompleted(Key_Quest, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_UPDATED, "|cffffcc00QUEST COMPLETED:|r\nThe Goddesses' Keys")
                    DestroyEffect(GODS_QUEST_MARKER)
                    TimerQueue:callDelayed(1., OpenGodsPortal)
                end
                if IsQuestDiscovered(Key_Quest) == false then
                    DestroyEffect(GODS_QUEST_MARKER)
                    QuestSetDiscovered(Key_Quest, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_DISCOVERED, "|cff322ce1REQUIRED QUEST|r\nThe Goddesses' Keys\n   - Retrieve the three keys")
                end
            end
        end
    end

    -- the horde
    do
        local horde_complete

        HORDE_QUEST_MARKER = AddSpecialEffectTarget("Abilities\\Spells\\Other\\TalkToMe\\TalkToMe.mdl", gg_unit_n02Q_0382, "overhead")

        local function kroresh_death()
            QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_COMPLETED, "|cffffcc00OPTIONAL QUEST COMPLETE|r\nThe Horde")
            QuestSetCompleted(Defeat_The_Horde_Quest, true)
            HORDE_QUEST_MARKER = AddSpecialEffectTarget("Abilities\\Spells\\Other\\TalkToMe\\TalkToMe.mdl", gg_unit_n02Q_0382, "overhead")
        end

        ---@return boolean
        local function is_orc()
            local uid = GetUnitTypeId(GetFilterUnit()) ---@type integer 

            return (UnitAlive(GetFilterUnit()) and (uid == FourCC('o01I') or uid == FourCC('o008')))
        end

        local function orc_death(killed)
            local uid = GetUnitTypeId(killed)
            --the horde
            if IsQuestDiscovered(Defeat_The_Horde_Quest) and IsQuestCompleted(Defeat_The_Horde_Quest) == false and (uid == FourCC('o01I') or uid == FourCC('o008')) then --Defeat the Horde
                local ug = CreateGroup()
                GroupEnumUnitsOfPlayer(ug, PLAYER_BOSS, Filter(is_orc))

                if BlzGroupGetSize(ug) == 0 and UnitAlive(kroresh) and GetUnitAbilityLevel(kroresh, FourCC('Avul')) > 0 then
                    UnitRemoveAbility(kroresh, FourCC('Avul'))
                    PingMinimap(14500., -15180., 3)
                    SetCinematicScene(GetUnitTypeId(kroresh), GetPlayerColor(PLAYER_BOSS), "Kroresh Foretooth", "You dare slaughter my men? Damn you!", 5, 4)
                    EVENT_ON_UNIT_DEATH:register_unit_action(kroresh, kroresh_death)
                end

                DestroyGroup(ug)
            end
        end

        local function spawn_orcs()
            if IsQuestCompleted(Defeat_The_Horde_Quest) == false and not CHAOS_MODE then
                local ug = CreateGroup()

                GroupEnumUnitsOfPlayer(ug, PLAYER_BOSS, Filter(is_orc))

                if GetUnitAbilityLevel(kroresh, FourCC('Avul')) > 0 and BlzGroupGetSize(ug) < 32 then
                    --bottom side
                    local u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 12687, -15414, 45)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 12866, -15589, 45)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 12539, -15589, 45)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 12744, -15765, 45)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    --top side
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 15048, -12603, 225)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 15307, -12843, 225)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 15299, -12355, 225)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)
                    u = CreateUnit(PLAYER_BOSS, FourCC('o01I'), 15543, -12630, 225)
                    IssuePointOrder(u, "patrol", 668, -2146)
                    EVENT_ON_UNIT_DEATH:register_unit_action(u, orc_death)

                    if UnitAlive(kroresh) then
                        UnitAddAbility(kroresh, FourCC('Avul'))
                    end
                end

                DestroyGroup(ug)

                TimerQueue:callDelayed(30., spawn_orcs)
            end
        end

        ITEM_LOOKUP[FourCC('I00L')] = function(p, pid, u, itm)
            if GetUnitLevel(Hero[pid]) >= 100 then
                if IsQuestDiscovered(Defeat_The_Horde_Quest) == false then
                    DestroyEffect(HORDE_QUEST_MARKER)
                    QuestSetDiscovered(Defeat_The_Horde_Quest, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_DISCOVERED, "|cff322ce1OPTIONAL QUEST|r\nThe Horde")
                    PingMinimap(12577, -15801, 4)
                    PingMinimap(15645, -12309, 4)

                    --orc setup
                    SetUnitPosition(kroresh, 14500, -15200)
                    BlzSetUnitFacingEx(kroresh, 135.)
                    UnitAddAbility(kroresh, FourCC('Avul'))

                    spawn_orcs()
                elseif IsQuestCompleted(Defeat_The_Horde_Quest) == false then
                    DisplayTextToPlayer(p, 0, 0, "Militia: The Orcs are still alive!")
                elseif IsQuestCompleted(Defeat_The_Horde_Quest) == true and not horde_complete then
                    DisplayTextToPlayer(p, 0, 0, "Militia: As promised, the Key of Valor.")
                    PlayerAddItemById(pid, FourCC('I041'))
                    horde_complete = true
                    DestroyEffect(HORDE_QUEST_MARKER)
                end
            else
                DisplayTextToPlayer(p, 0, 0, "You must be level |cffffcc00" .. 100 .. "|r to begin this quest.")
            end
        end
    end

    -- evil shopkeeper necklace quest
    do
        ITEM_LOOKUP[FourCC('I08L')] = function(p, pid, u, itm)
            if IsQuestDiscovered(Evil_Shopkeeper_Quest_1) == false then
                if GetUnitLevel(Hero[pid]) >= 50 then
                    QuestSetDiscovered(Evil_Shopkeeper_Quest_1, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_DISCOVERED, "|cff322ce1OPTIONAL QUEST|r\nThe Evil Shopkeeper")
                else
                    DisplayTextToPlayer(p, 0, 0, "You must be level |cffffcc00" .. 50 .. "|r to begin this quest.")
                end
            else
                itm = GetItemFromPlayer(pid, 'I045')

                if itm then
                    itm:destroy()
                    PlayerAddItemById(pid, 'I03E')
                    QuestSetCompleted(Evil_Shopkeeper_Quest_1, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_COMPLETED, "|cffffcc00OPTIONAL QUEST COMPLETE|r\nThe Evil Shopkeeper")
                end
            end
        end
    end

    -- omega pick quest
    do
        ITEM_LOOKUP[FourCC('I09H')] = function(p, pid, u, itm)
            if IsQuestDiscovered(Evil_Shopkeeper_Quest_2) == false then
                if GetUnitLevel(Hero[pid]) >= 75 then
                    QuestSetDiscovered(Evil_Shopkeeper_Quest_2, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_DISCOVERED, "|cff322ce1OPTIONAL QUEST|r\nOmega P's Pick")
                else
                    DisplayTextToPlayer(p, 0, 0, "You must be level |cffffcc00" .. 75 .. "|r to begin this quest.")
                end
            else
                itm = GetItemFromPlayer(pid, 'I02Y')
                local itm2 = GetItemFromPlayer(pid, 'I02X')

                if itm and itm2 then
                    itm:destroy()
                    itm2:destroy()
                    PlayerAddItemById(pid, 'I043')
                    QuestSetCompleted(Evil_Shopkeeper_Quest_2, true)
                    QuestMessageBJ(FORCE_PLAYING, bj_QUESTMESSAGE_COMPLETED, "|cffffcc00OPTIONAL QUEST COMPLETE|r\nOmega P's Pick")
                end
            end
        end
    end

    -- shopkeeper gossip
    do
        ITEM_LOOKUP[FourCC('I0OV')] = function()
            local x, y = GetUnitX(evilshopkeeper), GetUnitY(evilshopkeeper)
            local direction = {}

            if x > MAIN_MAP.maxX then -- in tavern
                DisplayTextToForce(FORCE_PLAYING, "|cffffcc00Evil Shopkeeper's Brother:|r I don't know where he is.")
            else
                if x < MAIN_MAP.centerX and y > MAIN_MAP.centerY then
                    direction[0] = "|cffffcc00North West|r"
                elseif x > MAIN_MAP.centerX and y > MAIN_MAP.centerY then
                    direction[0] = "|cffffcc00North East|r"
                elseif x < MAIN_MAP.centerX and y < MAIN_MAP.centerY then
                    direction[0] = "|cffffcc00South West|r"
                else
                    direction[0] = "|cffffcc00South East|r"
                end

                direction[1] = "|cffffcc00Evil Shopkeeper's Brother:|r My brother is currently heading " .. direction[0] .. " to expand his business."
                direction[2] = "|cffffcc00Evil Shopkeeper's Brother:|r I last heard that he was spotted traveling " .. direction[0] .. " to negotiate with some suppliers."
                direction[3] = "|cffffcc00Evil Shopkeeper's Brother:|r My brother is rumored to have traveled " .. direction[0] .. " to seek new markets for his products."
                direction[4] = "|cffffcc00Evil Shopkeeper's Brother:|r I haven't seen him for a while, but I suspect he might be up " .. direction[0] .. " hunting for rare items to sell."
                direction[5] = "|cffffcc00Evil Shopkeeper's Brother:|r He is never in one place for too long. He's probably moved " .. direction[0] .. " by now."
                direction[6] = "|cffffcc00Evil Shopkeeper's Brother:|r If I had to guess, I'd say he is currently located in the " .. direction[0] .. " part of the city."
                direction[7] = "|cffffcc00Evil Shopkeeper's Brother:|r I'm not sure where he is, but he usually heads " .. direction[0] .. " when he wants to avoid trouble."
                direction[8] = "|cffffcc00Evil Shopkeeper's Brother:|r I heard that my brother is hiding to the " .. direction[0] .. " of town."
                direction[9] = "|cffffcc00Evil Shopkeeper's Brother:|r He often travels to the " .. direction[0] .. ", looking for new opportunities to make a profit."
                direction[10] = "|cffffcc00Evil Shopkeeper's Brother:|r He is always on the move. He could be anywhere, but my guess is he's headed due " .. direction[0] .. "."

                DisplayTextToForce(FORCE_PLAYING, direction[math.random(1, 10)])
            end
        end
    end

    -- headhunter
    do
        local NERUBIAN_QUEST = FourCC('I04M')
        local POLARBEAR_QUEST = FourCC('I092')

        local REWARDS = {
            --spider armors
            [NERUBIAN_QUEST] = {
                Head = FourCC('I01E'),
                Reward = {
                    FourCC('I0B8'),
                    FourCC('I0BA'),
                    FourCC('I0B4'),
                    FourCC('I0B6'),
                },
                Level = 15,
                XP = 2500,
            },
            --polar bear items
            [POLARBEAR_QUEST] = {
                Head = FourCC('I04A'),
                Reward = {
                    FourCC('I0MC'),
                    FourCC('I0MD'),
                    FourCC('I0FB'),
                    FourCC('I05Q'),
                },
                Level = 25,
                XP = 5000,
            },
            --Hydra Head
            [FourCC('I03G')] = {
                Head = FourCC('I044'),
                Reward = FourCC('I0F8'),
                Level = 50,
                XP = 7500
            },
            --King of Ogres Head
            [FourCC('I049')] = {
                Head = FourCC('I02M'),
                Reward = FourCC('I04C'),
                Level = 50,
                XP = 10000
            },
            --Yeti Head
            [FourCC('I05N')] = {
                Head = FourCC('I05R'),
                Reward = FourCC('I03O'),
                Level = 60,
                XP = 10000
            },
        }

        local function reward_item()
            local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
            local dw    = DialogWindow[pid] ---@type DialogWindow 
            local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

            if index ~= -1 then
                PlayerAddItemById(pid, dw.data[index])

                dw:destroy()
            end

            return false
        end

        local function turn_in(pid, id)
            if REWARDS[id].Level <= GetHeroLevel(Hero[pid]) then
                local head = GetItemFromPlayer(pid, REWARDS[id].Head)

                if head then
                    head:destroy()

                    local reward = REWARDS[id].Reward

                    if type(reward) == "table" then
                        local dw = DialogWindow.create(pid, "Choose a reward", reward_item) ---@type DialogWindow
                        dw.cancellable = false

                        for _, v in ipairs(reward) do
                            if HasProficiency(pid, PROF[ItemData[v][ITEM_TYPE]]) then
                                dw:addButton(GetObjectName(v) .. " [" .. TYPE_NAME[ItemData[v][ITEM_TYPE]] .. "]", v)
                            end
                        end

                        dw:display()
                    else
                        PlayerAddItemById(pid, reward)
                    end

                    local XP = REWARDS[id].XP * XP_Rate[pid] * 0.01
                    AwardXP(pid, XP)
                else
                    DisplayTextToPlayer(Player(pid - 1), 0, 0, "You do not have the head.")
                end
            else
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You must be level |cffffcc00" .. (REWARDS[id].Level) .. "|r to complete this quest.")
            end
        end

        -- nerubian turn in
        ITEM_LOOKUP[NERUBIAN_QUEST] = function(p, pid, u, itm)
            turn_in(pid, itm.id)
        end

        ITEM_LOOKUP[POLARBEAR_QUEST] = function(p, pid, u, itm)
            turn_in(pid, itm.id)
        end

        -- item preload
        local nerub = REWARDS[NERUBIAN_QUEST].Reward ---@type table
        for i = 1, #nerub do
            CreateItem(nerub[i], 30000., 30000., 0.01)
        end

        local polarbear = REWARDS[POLARBEAR_QUEST].Reward ---@type table
        for i = 1, #polarbear do
            CreateItem(polarbear[i], 30000., 30000., 0.01)
        end
    end

    -- kill quests
    do
        local function on_death(pid, killed, killer)
            local uid      = GetUnitTypeId(killed)
            local unitType = GetType(uid)
            local kpid     = GetPlayerId(GetOwningPlayer(killer)) + 1

            if unitType > 0 and KillQuest[unitType].status == 1 and GetHeroLevel(Hero[kpid]) <= KillQuest[unitType].max + LEECH_CONSTANT then
                KillQuest[unitType].count = KillQuest[unitType].count + 1
                FloatingTextUnit(KillQuest[unitType].name .. " " .. (KillQuest[unitType].count) .. "/" .. (KillQuest[unitType].goal), killed, 3.1 ,80, 90, 9, 125, 200, 200, 0, true)

                if KillQuest[unitType].count >= KillQuest[unitType].goal then
                    KillQuest[unitType].status = 2
                    KillQuest[unitType].last = uid
                    DisplayTimedTextToForce(FORCE_PLAYING, 12, KillQuest[unitType].name .. " quest completed, talk to the Huntsman for your reward.")
                end
            end
        end

        EVENT_ON_DEATH:register_action(CREEP_ID, on_death)
    end

        -- F9 info
        CreateQuestBJ(bj_QUESTTYPE_REQ_DISCOVERED, "|c008000ffNevermore|r", [[The Nevermore Series is developed by: Mayday & lcm.

Thanks to previous contributors:
Waugriff
darkchaos
Hotwer
afis
CanFight]], "ReplaceableTextures\\CommandButtons\\BTNTheCaptain.blp")
    CreateQuestBJ(bj_QUESTTYPE_REQ_DISCOVERED, "|c00ff0000Beta Testers|r", [[Special thanks to the Nevermore Beta Testers:
|cff0b6623Kristian
Bud-Bus-|r
|cff7c0a02Ash
Sagmariasus
AruAzif
Orion
AgentCody
Anna Kendrick
Charles Barkley's Tulpa
Peacee'
ReefyPuffs
Saken
Samaki1000
Triggis
Maiev|r]], "ReplaceableTextures\\CommandButtons\\BTNJaina.blp")

    CreateQuestBJ(bj_QUESTTYPE_REQ_DISCOVERED, "Commands", [[-info (displays information submenu)
-stats # (displays hero stats)
-cam # (L to lock, i.e. -cam 3000L)
-zm (L to lock, i.e. -zml will set your camera to 2500, locked distance)
-lock (locks camera distance)
-unlock (unlock camera distance so that it can be reset by scroll wheel)
-roll (rolls a number 1-100 for an item)
-suicide (kills your hero if you get stuck)
-clear (clears text on screen)
-pf (proficiencies)
-save (saves your character, this game uses a codeless save system)
-load (loads your profile/heroes to be selected from in your current game)
-autosave (automatically saves your hero every 30 minutes)
-savetime (time until you can save again)
-restime (time until you can recharge your ankh again)
-st (show time until next save)
-flee (leave an instance)
-hints (enables hint messages)
-nohints (disables hint messages)
-color # (changes your player color)
-unstuck (uhh)
-tome (displays how many tomes can be bought)]]
, "ReplaceableTextures\\PassiveButtons\\PASBTNStatUp.blp")

    CreateQuestBJ(bj_QUESTTYPE_REQ_DISCOVERED, "Colors", [[1 |c00FF0303Red|r
2 |c000042FFBlue|r
3 |c001CE6B9Teal|r
4 |c00540081Purple|r
5 |c00FFFC01Yellow|r
6 |c00fEBA0EOrange|r
7 |c0020C000Green|r
8 |c00E55BB0Pink|r
9 |c00959697Gray|r
10 |c007EBFF1Light Blue|r
11 |c00106246Dark Green|r
12 |c004E2A04Brown|r
13 |cff9B0000Maroon|r
14 |cff0000C3Navy|r
15 |cff00EAFFTurquoise|r
16 |cffBE00FEViolet|r
17 |cffEBCD87Wheat|r
18 |cffF8A48BPeach|r
19 |cffBFFF80Mint|r
20 |cffDCB9EBLavender|r
21 |cff282828Coal|r
22 |cffEBF0FFSnow|r
23 |cff00781EEmerald|r
24 |cffA46F33Peanut|r
25 Black]], "ReplaceableTextures\\PassiveButtons\\PASBTNScatterRockets.blp")
end, Debug and Debug.getLine())
