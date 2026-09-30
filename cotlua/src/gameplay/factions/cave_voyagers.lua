-- Cave Voyagers faction definition, quests, and blessing scaling.

OnInit.final("CaveVoyagers", function(Require)
    Require('Faction')
    Require('FactionMining')
    Require('BuffsWorldFactions')
    Require('Users')
    Require('Variables')

    local CAVE_VOYAGERS_ID = 1
    local SHARED_BLESSING_DURATION = 300.
    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3

    local cave_voyagers = Faction.create(
        CAVE_VOYAGERS_ID,
        "Cave Voyagers",
        15000.,
        10500.,
        HardHatBuff,
        "The Cave Voyagers are a mining faction that provide access to earth materials and a special defensive buff.|n|n|cffffcc00Membership, rank progress, and unspent Faction Points are saved with this character.|r|n|nWill you join us?",
        "war3mapImported\\BTNDiamondPickaxe.blp"
    )
    cave_voyagers:addQuest(Quest.create(
        "Prospector's Route",
        "Mine 3 ore deposits.\n\n|cffffcc00Reward:|r 5 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_EASY,
        "mine_any", 3, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Arena Survey",
        "Enter the Colosseum.\n\n|cffffcc00Reward:|r 5 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp",
        QUEST_DIFF_EASY,
        "colosseum_enter", 1, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Stone Samples",
        "Recover 8 ore samples from deposits. Rich and rare deposits provide more samples.\n\n|cffffcc00Reward:|r 5 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        QUEST_DIFF_EASY,
        "mine_ore", 8, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Rich Veins",
        "Mine 2 rich ore deposits.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNGem.blp",
        QUEST_DIFF_MEDIUM,
        "mine_rich", 2, 10, 10, 2
    ))
    cave_voyagers:addQuest(Quest.create(
        "Endless Excavation",
        "Clear 10 waves of the Infinite Struggle.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_MEDIUM,
        "struggle_wave", 10, 10, 10
    ))
    cave_voyagers:addQuest(Quest.create(
        "Cave-In Cleanup",
        "Defeat 2 golems awakened by mining operations. Nearby Cave Voyagers share credit.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNHeroMountainKing.blp",
        QUEST_DIFF_MEDIUM,
        "mining_guardian", 2, 10, 10
    ))
    cave_voyagers:addQuest(Quest.create(
        "Unbroken Extraction",
        "Complete a rare deposit's 30-second extraction without being interrupted.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNHumanBuild.blp",
        QUEST_DIFF_HARD,
        "rare_extraction", 1, 20, 20, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Awakened Colossus",
        "Defeat a golem awakened by a rare deposit.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNStoneGiant.blp",
        QUEST_DIFF_HARD,
        "rare_guardian", 1, 20, 20, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Deep Survey",
        "Mine deposits in 3 distinct Chaos regions.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNSpy.blp",
        QUEST_DIFF_HARD,
        "mining_region", 3, 20, 20
    ))
    cave_voyagers:addQuest(Quest.create(
        "Champion's Commission",
        "Complete all 20 Colosseum waves.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
        QUEST_DIFF_HARD,
        "colosseum_clear", 1, 20, 20
    ))
    cave_voyagers:addGenericQuests()

    local function rank_reduction(rank)
        if rank >= 7 then return 0.15 end
        if rank >= 4 then return 0.11 end
        return 0.08
    end

    HardHatBuff.getFactionReduction = function(target)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        return rank_reduction(Faction.getRank(
                                  Faction.getReputation(pid,
                                                        CAVE_VOYAGERS_ID)))
    end
    SharedHardHatBuff.getRankReduction = rank_reduction

    CaveVoyagersServices = {}

    function CaveVoyagersServices.shareBlessing(pid)
        local success, shared = Faction.shareBlessing(
                                    pid, CAVE_VOYAGERS_ID,
                                    SharedHardHatBuff,
                                    SHARED_BLESSING_DURATION)
        if not success then return false end
        DisplayTimedTextToForce(FORCE_PLAYING, 15.,
            User[pid - 1].nameColored ..
                " shared their Cave Voyagers blessing with " .. shared ..
                " allied hero" .. (shared == 1 and "." or "es."))
        return true
    end

    function CaveVoyagersServices.rerollDeposits(pid)
        local faction = Faction.getFaction(pid)
        if not faction or faction.id ~= CAVE_VOYAGERS_ID then return false end
        local refreshed = FactionMining.refreshDeposits()
        if not refreshed then return false end
        DisplayTimedTextToForce(FORCE_PLAYING, 15.,
            User[pid - 1].nameColored .. " triggered a seismic survey. " ..
                refreshed .. " unclaimed deposit" ..
                (refreshed == 1 and " was" or "s were") .. " relocated.")
        return true
    end
end, Debug and Debug.getLine())
