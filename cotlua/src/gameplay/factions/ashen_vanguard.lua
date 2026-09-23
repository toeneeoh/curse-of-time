-- Ashen Vanguard faction definition, hunting quests, and blessing scaling.

OnInit.final("AshenVanguard", function(Require)
    Require('Faction')
    Require('BuffsWorldFactions')

    local ASHEN_VANGUARD_ID = 3
    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3

    local ashen_vanguard = Faction.create(
        ASHEN_VANGUARD_ID,
        "Ashen Vanguard",
        -8800.,
        -13124.,
        AshenVanguardBuff,
        "The Ashen Vanguard hunt the most dangerous creatures unleashed by Chaos and reward those who seek varied, formidable quarry.|n|n|cffffcc00Membership, rank progress, and unspent Faction Points are saved with this character.|r"
    )

    ashen_vanguard:addQuest(Quest.create(
        "Varied Quarry",
        "Defeat 4 different enemy types that grant at least 50% rewards.\n\n|cffffcc00Reward:|r 5 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNSpy.blp",
        QUEST_DIFF_EASY,
        "distinct_enemy_types", 4, 5, 5
    ))
    ashen_vanguard:addQuest(Quest.create(
        "Dangerous Game",
        "Help defeat 2 different bosses within 20 levels of your hero. Endgame bosses always count.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNMarkOfFire.blp",
        QUEST_DIFF_MEDIUM,
        "distinct_bosses", 2, 10, 10
    ))
    ashen_vanguard:addQuest(Quest.create(
        "Vanguard's Ledger",
        "Help defeat 4 different bosses within 20 levels of your hero. Endgame bosses always count.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNCriticalStrike.blp",
        QUEST_DIFF_HARD,
        "distinct_bosses", 4, 20, 20, 3
    ))
    ashen_vanguard:addGenericQuests()

    AshenVanguardBuff.getFactionDamage = function(target)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        local rank = Faction.getRank(
            Faction.getReputation(pid, ASHEN_VANGUARD_ID))
        if rank >= 7 then return 0.12 end
        if rank >= 4 then return 0.08 end
        return 0.05
    end
end, Debug and Debug.getLine())
