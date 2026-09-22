-- Cave Voyagers faction definition, quests, and blessing scaling.

OnInit.final("CaveVoyagers", function(Require)
    Require('Faction')
    Require('BuffsWorldFactions')
    Require('Variables')

    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3

    local cave_voyagers = Faction.create(
        1,
        "Cave Voyagers",
        15000.,
        10500.,
        HardHatBuff,
        "The Cave Voyagers are a mining faction that provide access to earth materials and a special defensive buff.|n|n|cffffcc00Membership, reputation, and unspent Faction Points are saved with this character.|r|n|nWill you join us?"
    )
    cave_voyagers:addQuest(Quest.create(
        "Prospector's Route",
        "Mine 3 ore deposits.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_EASY,
        "mine_any", 3, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Arena Survey",
        "Enter the Colosseum.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp",
        QUEST_DIFF_EASY,
        "colosseum_enter", 1, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Stone Samples",
        "Recover 8 ore samples from deposits. Rich and rare deposits provide more samples.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        QUEST_DIFF_EASY,
        "mine_ore", 8, 5, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Rich Veins",
        "Mine 2 rich ore deposits.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNGem.blp",
        QUEST_DIFF_MEDIUM,
        "mine_rich", 2, 10, 10, 2
    ))
    cave_voyagers:addQuest(Quest.create(
        "Endless Excavation",
        "Clear 10 waves of the Infinite Struggle.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNPickUpItem.blp",
        QUEST_DIFF_MEDIUM,
        "struggle_wave", 10, 10, 10
    ))
    cave_voyagers:addQuest(Quest.create(
        "Cave-In Cleanup",
        "Defeat 2 golems awakened by mining operations. Nearby Cave Voyagers share credit.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHeroMountainKing.blp",
        QUEST_DIFF_MEDIUM,
        "mining_guardian", 2, 10, 10
    ))
    cave_voyagers:addQuest(Quest.create(
        "Unbroken Extraction",
        "Complete a rare deposit's 30-second extraction without being interrupted.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNHumanBuild.blp",
        QUEST_DIFF_HARD,
        "rare_extraction", 1, 20, 20, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Awakened Colossus",
        "Defeat a golem awakened by a rare deposit.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNStoneGiant.blp",
        QUEST_DIFF_HARD,
        "rare_guardian", 1, 20, 20, 5
    ))
    cave_voyagers:addQuest(Quest.create(
        "Deep Survey",
        "Mine deposits in 3 distinct Chaos regions.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNSpy.blp",
        QUEST_DIFF_HARD,
        "mining_region", 3, 20, 20
    ))
    cave_voyagers:addQuest(Quest.create(
        "Champion's Commission",
        "Complete all 20 Colosseum waves.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
        QUEST_DIFF_HARD,
        "colosseum_clear", 1, 20, 20
    ))
    cave_voyagers:addGenericQuests()

    HardHatBuff.getFactionReduction = function(target)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        local rank = Faction.getRank(Faction.getReputation(pid, 1))
        if rank >= 7 then return 0.15 end
        if rank >= 4 then return 0.11 end
        return 0.08
    end
end, Debug and Debug.getLine())
