OnInit.global("ItemSchema", function()
    PROF_PLATE = 0x1
    PROF_FULLPLATE = 0x2
    PROF_LEATHER = 0x4
    PROF_CLOTH = 0x8
    PROF_SHIELD = 0x10
    PROF_HEAVY = 0x20
    PROF_SWORD = 0x40
    PROF_DAGGER = 0x80
    PROF_BOW = 0x100
    PROF_STAFF = 0x200
    PROF_POTION = 0x400
    PROF_SOCKETABLE = 0x800

    MAX_REINCARNATION_CHARGES = 3
    ITEM_MIN_LEVEL_VARIANCE = 8
    ITEM_MAX_LEVEL_VARIANCE = 11
    QUALITY_SAVED = 7
    MAX_SOCKETS = 3

    TOTAL_STATS = enum(
        "ITEM_LEVEL",
        "ITEM_HEALTH",
        "ITEM_MANA",
        "ITEM_DAMAGE",
        "ITEM_ARMOR",
        "ITEM_STRENGTH",
        "ITEM_AGILITY",
        "ITEM_INTELLIGENCE",
        "ITEM_REGENERATION",
        "ITEM_MANA_REGENERATION",
        "ITEM_DAMAGE_RESIST",
        "ITEM_MAGIC_RESIST",
        "ITEM_DAMAGE_MULT",
        "ITEM_MAGIC_MULT",
        "ITEM_MOVESPEED",
        "ITEM_EVASION",
        "ITEM_SPELLBOOST",
        "ITEM_CRIT_CHANCE",
        "ITEM_CRIT_DAMAGE",
        "ITEM_CRIT_CHANCE_MULT",
        "ITEM_CRIT_DAMAGE_MULT",
        "ITEM_BASE_ATTACK_SPEED",
        "ITEM_GOLD_GAIN",
        "ITEM_FLAT_HEAL",
        "ITEM_PERCENT_HEAL",
        "ITEM_FLAT_MANA",
        "ITEM_PERCENT_MANA",
        "ITEM_CHARGES",
        "ITEM_ABILITY",
        "ITEM_ABILITY2",
        "ITEM_NOCRAFT",
        "ITEM_TIER",
        "ITEM_TYPE",
        "ITEM_UPGRADE_MAX",
        "ITEM_LEVEL_REQUIREMENT",
        "ITEM_LIMIT",
        "ITEM_COST",
        "ITEM_DISCOUNT",
        "ITEM_STACK",
        "ITEM_RARITY",
        "TOTAL_ATTACK_SPEED",
        "XP_RATE",
        "HERO_TIME",
        "PLAYER_TIME"
    )

    CUSTOM_ITEM_OFFSET = FourCC('I000')

    PROF = {
        PROF_PLATE,
        PROF_FULLPLATE,
        PROF_LEATHER,
        PROF_CLOTH,
        PROF_SHIELD,
        PROF_HEAVY,
        PROF_SWORD,
        PROF_DAGGER,
        PROF_BOW,
        PROF_STAFF,
        PROF_POTION,
        PROF_SOCKETABLE,
    }
    PROF[0] = 0

    ItemData = array2d(0)

    TIER_NAME = {
        [0] = "",
        "Common",
        "|cffbbbbbbUncommon|r",
        "|cffffff00Quest|r",
        "|cff999999Ursa|r",
        "|cff999999Ogre|r",
        "|cff999999Unbroken|r",
        "|cff999999Magnataur|r",
        "|cff55ff44Set|r",
        "|cffba0505Boss|r",
        "|cff01b9f5Divine|r",
        "|cffff5050Chaotic Quest|r",
        "Demon",
        "Horror",
        "Despair",
        "Abyssal",
        "Void",
        "Nightmare",
        "Hell",
        "Existence",
        "Astral",
        "Dimensional",
        "|cff05aa05Chaotic Set|r",
        "|cff700909Chaotic Boss|r",
        "|cffa0a0a0Forgotten|r",
        "|cff999999Devourer|r",
    }

    TYPE_NAME = {
        [0] = "All",
        "Plate",
        "Fullplate",
        "Leather",
        "Cloth",
        "Shield",
        "Heavy",
        "Sword",
        "Dagger",
        "Bow",
        "Staff",
        "Potion",
        "Socketable",
    }
    TYPE_ALL = 0x1FFF
    TYPE_EQUIPPABLE = 0x3FF
    TYPE_POTION = 0x400

    ITEM_MODEL = {
        FourCC('rar1'),
        FourCC('rar2'),
        FourCC('rar3'),
        FourCC('rar4'),
        FourCC('rar5'),
    }

    RARITY_NAME = {
        [0] = "",
        "|cff40bf5fRefined|r",
        "|cff4087bfRare|r",
        "|cff7040bfEpic|r",
        "|cffbf6b40Legendary|r",
        "|cffc41919Chaos|r",
    }

    SPRITE_RARITY = {
        [0] = "war3mapImported\\CommonBorder.dds",
        "war3mapImported\\RefinedBorder.dds",
        "war3mapImported\\RefinedBorder.dds",
        "war3mapImported\\RefinedBorder.dds",
        "war3mapImported\\RefinedBorder.dds",
        "war3mapImported\\RareBorder.dds",
        "war3mapImported\\RareBorder.dds",
        "war3mapImported\\RareBorder.dds",
        "war3mapImported\\RareBorder.dds",
        "war3mapImported\\EpicBorder.dds",
        "war3mapImported\\EpicBorder.dds",
        "war3mapImported\\EpicBorder.dds",
        "war3mapImported\\EpicBorder.dds",
        "war3mapImported\\LegendaryBorder.dds",
        "war3mapImported\\LegendaryBorder.dds",
        "war3mapImported\\LegendaryBorder.dds",
        "war3mapImported\\LegendaryBorder.dds",
        "war3mapImported\\ChaosBorder.dds",
        "war3mapImported\\ChaosBorder.dds",
        "war3mapImported\\ChaosBorder.dds",
        "war3mapImported\\ChaosBorder.dds",
    }

    ITEM_STAT_MULTIPLIER = {
        [0] = 0,
        0.2, 0.4, 0.6, 0.8,
        1.2, 1.6, 2., 2.4,
        3.2, 4., 4.8, 5.6,
        7., 8.4, 9.8, 11.2,
        13.4, 15.6, 17.8,
    }

    CRYSTAL_PRICE = {
        [0] = 1,
        1, 2, 2, 3, 3, 4, 5, 6, 8,
        12, 16, 24, 32, 48, 64, 80, 96, 128, 160,
    }

    LIMIT_STRING = {
        "You can only wear one of this item.",
        "You only have two feet",
        "A second set of wings won't help you fly better",
        "You can only wear one Bloody armor",
        "You can only use one Bloody weapon",
        "You can only wear one Absolute Horror armor",
        "You can only use one Absolute Horror weapon",
        "You can only wear one Legion armor",
        "You can only use one Legion weapon",
        "You can only wear one Azazoth armor",
        "You can only use one Azazoth weapon",
        "You can only use one Slaughterer weapon",
        "You can only hold one Forgotten gem",
        "You can only wear one Ursine Set",
        "You can only wear one Ogre Set",
        "You can only wear one Unbroken Set",
        "You can only wear one Magnataur Set",
        "You can only wear one Demon Set",
        "You can only wear one Horror Set",
        "You can only wear one Despair Set",
        "You can only wear one Abyssal Set",
        "You can only wear one Void Set",
        "You can only wear one Nightmare Set",
        "You can only wear one Hell Set",
        "You can only wear one Existence Set",
        "You can only wear one Astral Set",
        "You can only wear one Dimensional Set",
        "You can only wear one Devourer Set",
    }
end, Debug and Debug.getLine())
