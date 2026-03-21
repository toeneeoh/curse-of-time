--[[
    variables.lua

    Assorted defined globals / constants
]]

OnInit.global("Variables", function()
    DEV_ENABLED         = false
    MAP_NAME            = "CoT Nevermore"
    SAVE_LOAD_VERSION   = 1

    DUMMY_UNIT                         = gg_unit_h05E_0717
    PLAYER_CAP                         = 6
    MAX_LEVEL                          = 500
    LEECH_CONSTANT                     = 50
    BOSS_RESPAWN_TIME                  = 600
    MIN_LIFE                           = 0.406
    PLAYER_CREEP                       = Player(PLAYER_NEUTRAL_AGGRESSIVE)
    PLAYER_TOWN                        = 8
    PLAYER_BOSS                        = Player(11)
    CREEP_ID                           = PLAYER_NEUTRAL_AGGRESSIVE + 1
    BOSS_ID                            = 12
    TOWN_ID                            = 9
    FPS_32                             = 0.03125
    DETECT_LEAVE_ABILITY               = FourCC('uDex') ---@type integer 
    INT_32_LIMIT                       = 2147483647

    -- units
    DUMMY_CASTER                       = FourCC('e011')
    DUMMY_VISION                       = FourCC('eRez')
    GRAVE                              = FourCC('H01G')
    BACKPACK                           = FourCC('H05D')
    HERO_PHOENIX_RANGER                = FourCC('E00X')
    HERO_ROYAL_GUARDIAN                = FourCC('H04Z')
    HERO_CRUSADER                      = FourCC('H05B')
    HERO_MASTER_ROGUE                  = FourCC('E015')
    HERO_ELEMENTALIST                  = FourCC('E00W')
    HERO_HIGH_PRIEST                   = FourCC('E012')
    HERO_DARK_SUMMONER                 = FourCC('O02S')
    HERO_SAVIOR                        = FourCC('H01N')
    HERO_DARK_SAVIOR                   = FourCC('H01S')
    HERO_ASSASSIN                      = FourCC('E002')
    HERO_BARD                          = FourCC('H00R')
    HERO_ARCANIST                      = FourCC('H029')
    HERO_OBLIVION_GUARD                = FourCC('H02A')
    HERO_THUNDERBLADE                  = FourCC('O03J')
    HERO_BLOODZERKER                   = FourCC('H03N')
    HERO_MARKSMAN                      = FourCC('E008')
    HERO_HYDROMANCER                   = FourCC('E00G')
    HERO_WARRIOR                       = FourCC('H012')
    HERO_DRUID                         = FourCC('O018')
    HERO_DARK_SAVIOR_DEMON             = FourCC('E01M')
    HERO_MARKSMAN_SNIPER               = FourCC('E00F')
    HERO_VAMPIRE                       = FourCC('U003')
    HERO_TOTAL                         = 19
    SUMMON_DESTROYER                   = FourCC('E014')
    SUMMON_HOUND                       = FourCC('H05F')
    SUMMON_GOLEM                       = FourCC('H05G')

    -- proficiencies
    PROF_PLATE                         = 0x1
    PROF_FULLPLATE                     = 0x2
    PROF_LEATHER                       = 0x4
    PROF_CLOTH                         = 0x8
    PROF_SHIELD                        = 0x10
    PROF_HEAVY                         = 0x20
    PROF_SWORD                         = 0x40
    PROF_DAGGER                        = 0x80
    PROF_BOW                           = 0x100
    PROF_STAFF                         = 0x200
    PROF_POTION                        = 0x400

    HERO_STATS = {
        [HERO_OBLIVION_GUARD] = {
        model        = "InfernalSprite.mdx",
        prof         = PROF_HEAVY + PROF_PLATE + PROF_FULLPLATE,
        phys_resist  = 1.0,
        magic_resist = 1.3,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0HQ'),
        select       = FourCC('A07S'),
        armor        = 5,
        str          = 17,
        agi          = 4,
        int          = 9,
        str_gain     = 3.5,
        agi_gain     = 0.5,
        int_gain     = 1.5,
        main         = "str",
        range        = "Melee",
        skills       = {"A07R", "A07O", "A076", "A05S", "A047", "A0GJ"},
        stars        = {3, 1, 0, 0, 1}
        },
        [HERO_BLOODZERKER] = {
        model        = "BloodzerkerSprite.mdx",
        prof         = PROF_HEAVY + PROF_SWORD + PROF_PLATE,
        phys_resist  = 1.6,
        magic_resist = 1.8,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A06N'),
        select       = FourCC('A07T'),
        armor        = 1,
        str          = 17,
        agi          = 10,
        int          = 5,
        str_gain     = 3.5,
        agi_gain     = 1.4,
        int_gain     = 0.5,
        main         = "str",
        range        = "Melee",
        skills       = {"A05Y", "A05Z", "A06H", "A05X", "A0GZ", "A0AD"},
        stars        = {1, 3, 1, 1, 1}
        },
        [HERO_ROYAL_GUARDIAN] = {
        model        = "RoyalGuardianSprite.mdx",
        prof         = PROF_HEAVY + PROF_SWORD + PROF_PLATE + PROF_FULLPLATE,
        phys_resist  = 0.9,
        magic_resist = 1.5,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I5'),
        select       = FourCC('A07U'),
        armor        = 7,
        str          = 18,
        agi          = 4,
        int          = 2,
        str_gain     = 3.7,
        agi_gain     = 0.9,
        int_gain     = 0.5,
        main         = "str",
        range        = "Melee",
        skills       = {"A06B", "A0HT", "A0EG", "A04Y", "A0HS", "A09E"},
        stars        = {3, 0, 0, 1, 0}
        },
        [HERO_WARRIOR] = {
        model        = "WarriorSprite.mdx",
        prof         = PROF_HEAVY + PROF_SWORD + PROF_PLATE,
        phys_resist  = 1.1,
        magic_resist = 1.5,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0IE'),
        select       = FourCC('A07V'),
        armor        = 1,
        str          = 17,
        agi          = 10,
        int          = 5,
        str_gain     = 3.5,
        agi_gain     = 1.4,
        int_gain     = 0.5,
        main         = "str",
        range        = "Melee",
        skills       = {"A0AI", "A0EE", "A00L", "A001", "A0AH", "A02R"},
        stars        = {1, 1, 3, 1, 2}
        },
        [HERO_VAMPIRE] = {
        model        = "VampireLordSprite.mdx",
        prof         = PROF_HEAVY + PROF_PLATE + PROF_DAGGER + PROF_LEATHER,
        phys_resist  = 1.5,
        magic_resist = 1.5,
        phys_damage  = 1.25,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A05E'),
        select       = FourCC('A029'),
        armor        = 2,
        str          = 10,
        agi          = 10,
        int          = 5,
        str_gain     = 2.0,
        agi_gain     = 2.0,
        int_gain     = 1.0,
        main         = "str",
        range        = "Melee",
        skills       = {"A07K", "A07A", "A09B", "A093", "A09A", "A097"},
        stars        = {3, 2, 2, 0, 3}
        },
        [HERO_SAVIOR] = {
        model        = "SaviorSprite.mdx",
        prof         = PROF_SWORD + PROF_PLATE + PROF_HEAVY + PROF_FULLPLATE,
        phys_resist  = 1.2,
        magic_resist = 1.3,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0HW'),
        select       = FourCC('A07W'),
        armor        = 4,
        str          = 14,
        agi          = 7,
        int          = 5,
        str_gain     = 2.4,
        agi_gain     = 1.0,
        int_gain     = 0.4,
        main         = "str",
        range        = "Melee",
        skills       = {"A07C", "A038", "A0KU", "A0AT", "A0GG", "A08R"},
        stars        = {2, 3, 2, 1, 3}
        },
        [HERO_DARK_SAVIOR] = {
        model        = "DarkSaviorSprite.mdx",
        prof         = PROF_SWORD + PROF_PLATE + PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.6,
        magic_resist = 1.0,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0DL'),
        select       = FourCC('A07Z'),
        armor        = 3,
        str          = 12,
        agi          = 8,
        int          = 18,
        str_gain     = 1.5,
        agi_gain     = 0.7,
        int_gain     = 2.5,
        main         = "int",
        range        = "Melee",
        skills       = {"A0GO", "A08Z", "A019", "A074", "AEim", "A02S"},
        stars        = {1, 3, 3, 1, 1}
        },
        [HERO_CRUSADER] = {
        model        = "CrusaderSprite.mdx",
        prof         = PROF_HEAVY + PROF_FULLPLATE + PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.1,
        magic_resist = 1.1,
        phys_damage  = 1.2,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I4'),
        select       = FourCC('A080'),
        armor        = 4,
        str          = 13,
        agi          = 7,
        int          = 16,
        str_gain     = 1.25,
        agi_gain     = 0.4,
        int_gain     = 2.1,
        main         = "int",
        range        = "Melee",
        skills       = {"A06A", "A0KD", "A06D", "A07D", "A06E", "A07P"},
        stars        = {1, 0, 1, 3, 0}
        },
        [HERO_ARCANIST] = {
        model        = "ArcanistSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0EY'),
        select       = FourCC('A081'),
        armor        = 0,
        str          = 4,
        agi          = 10,
        int          = 22,
        str_gain     = 0.25,
        agi_gain     = 0.5,
        int_gain     = 4,
        main         = "int",
        range        = "600",
        skills       = {"A00W", "A05Q", "A02N", "A078", "A075", "A079"},
        stars        = {0, 2, 2, 1, 0}
        },
        [HERO_DARK_SUMMONER] = {
        model        = "DarkSummonerSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I0'),
        select       = FourCC('A082'),
        armor        = 0,
        str          = 8,
        agi          = 8,
        int          = 19,
        str_gain     = 1.4,
        agi_gain     = 0.7,
        int_gain     = 6.5,
        main         = "int",
        range        = "600",
        skills       = {"A022", "A0KF", "A0KH", "A0KG", "A063", "A0K1"},
        stars        = {2.5, 2.5, 1, 0, 2}
        },
        [HERO_BARD] = {
        model        = "BardSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0HV'),
        select       = FourCC('A084'),
        armor        = 0,
        str          = 8,
        agi          = 11,
        int          = 21,
        str_gain     = 0.9,
        agi_gain     = 0.5,
        int_gain     = 2.2,
        main         = "int",
        range        = "400",
        skills       = {"A02F", "A0AZ", "A02H", "A09Y", "A06Y", "A02K"},
        stars        = {0, 1, 1, 3, 0}
        },
        [HERO_HYDROMANCER] = {
        model        = "JainaProudmooreSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0EC'),
        select       = FourCC('A086'),
        armor        = 0,
        str          = 3,
        agi          = 6,
        int          = 21,
        str_gain     = 0.6,
        agi_gain     = 0.6,
        int_gain     = 4.0,
        main         = "int",
        range        = "600",
        skills       = {"A0DY", "A0GI", "A03X", "A077", "A08E", "A098"},
        stars        = {0, 1, 3, 3, 1}
        },
        [HERO_HIGH_PRIEST] = {
        model        = "HighPriestessSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I2'),
        select       = FourCC('A087'),
        armor        = 0,
        str          = 5,
        agi          = 4,
        int          = 18,
        str_gain     = 1.7,
        agi_gain     = 0.6,
        int_gain     = 3.8,
        main         = "int",
        range        = "700",
        skills       = {"A0DU", "A0JE", "A0JG", "A0JD", "A0J3", "A048"},
        stars        = {0, 0.5, 0, 3, 0}
        },
        [HERO_ELEMENTALIST] = {
        model        = "ElementalistSprite.mdx",
        prof         = PROF_STAFF + PROF_CLOTH,
        phys_resist  = 1.8,
        magic_resist = 1.6,
        phys_damage  = 1.0,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I3'),
        select       = FourCC('A089'),
        armor        = 2,
        str          = 1,
        agi          = 3,
        int          = 40,
        str_gain     = 0.4,
        agi_gain     = 0.,
        int_gain     = 8.4,
        main         = "int",
        range        = "600",
        skills       = {"A0J5", "A0GV", "A011", "A032", "A01U", "A04H"},
        stars        = {0, 2, 3, 1, 2}
        },
        [HERO_ASSASSIN] = {
        model          = "AssassinSprite.mdx",
        prof           = PROF_DAGGER + PROF_LEATHER,
        phys_resist    = 1.6,
        magic_resist   = 1.8,
        phys_damage    = 1.25,
        crit_chance    = 5.,
        crit_damage    = 100.,
        mana_regen_max = 2,
        passive        = FourCC('A01N'),
        select         = FourCC('A07J'),
        armor          = 0,
        str            = 8,
        agi            = 17,
        int            = 8,
        str_gain       = 0.6,
        agi_gain       = 3.6,
        int_gain       = 1.5,
        main           = "agi",
        range          = "Melee",
        skills         = {"A0AQ", "A0BG", "A00T", "A01E", "A00P", "A07Y"},
        stars          = {0, 2, 1, 1, 0}
        },
        [HERO_THUNDERBLADE] = {
        model        = "ThunderBladeSprite.mdx",
        prof         = PROF_DAGGER + PROF_LEATHER,
        phys_resist  = 1.6,
        magic_resist = 1.8,
        phys_damage  = 1.25,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A039'),
        select       = FourCC('A01P'),
        armor        = 0,
        str          = 6,
        agi          = 15,
        int          = 11,
        str_gain     = 1.0,
        agi_gain     = 3.4,
        int_gain     = 1.4,
        main         = "agi",
        range        = "Melee",
        skills       = {"A096", "A095", "A03O", "A0MN", "A0os", "A01L"},
        stars        = {0, 2, 2, 0, 0}
        },
        [HERO_MASTER_ROGUE] = {
        model        = "MasterRogueSprite.mdx",
        prof         = PROF_DAGGER + PROF_LEATHER,
        phys_resist  = 1.6,
        magic_resist = 1.8,
        phys_damage  = 1.25,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I1'),
        select       = FourCC('A07L'),
        armor        = 0,
        str          = 6,
        agi          = 15,
        int          = 6,
        str_gain     = 0.8,
        agi_gain     = 3.5,
        int_gain     = 0.1,
        main         = "agi",
        range        = "Melee",
        skills       = {"A0QQ", "A0QV", "A0F5", "A0F7", "A0QP", "A0QU"},
        stars        = {0, 3, 0, 1, 0}
        },
        [HERO_MARKSMAN] = {
        model        = "EliteMarksmanSprite.mdx",
        prof         = PROF_BOW + PROF_LEATHER,
        phys_resist  = 2.0,
        magic_resist = 1.8,
        phys_damage  = 1.3,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A070'),
        select       = FourCC('A07M'),
        armor        = -5,
        str          = 2,
        agi          = 21,
        int          = 4,
        str_gain     = 0.6,
        agi_gain     = 3.0,
        int_gain     = 0.5,
        main         = "agi",
        range        = "650",
        skills       = {"A049", "A06I", "A06U", "A05D", "A0J4", "A06V"},
        stars        = {0, 3, 2, 0, 0}
        },
        [HERO_PHOENIX_RANGER] = {
        model        = "PhoenixRangerSprite.mdx",
        prof         = PROF_BOW + PROF_LEATHER,
        phys_resist  = 2.0,
        magic_resist = 1.8,
        phys_damage  = 1.3,
        crit_chance  = 5.,
        crit_damage  = 100.,
        mana_regen_max = 0,
        passive      = FourCC('A0I6'),
        select       = FourCC('A07N'),
        armor        = -3,
        str          = 1,
        agi          = 20,
        int          = 3,
        str_gain     = 0.6,
        agi_gain     = 2.5,
        int_gain     = 0.5,
        main         = "agi",
        range        = "650",
        skills       = {"A05T", "A05R", "A0FT", "A0IB", "A090", "A0F6"},
        stars        = {0, 3, 2, 0, 0}
        },
    }

    -- default stats for other units
    local default_stats = {phys_resist = 1., magic_resist = 1., phys_damage = 1., crit_chance = 0., crit_damage = 100., mana_regen_max = 0.}
    setmetatable(HERO_STATS, { __index = function(tbl, key)
        return default_stats
    end})

    -- bosses
    BOSS_TAUREN                        = 1
    BOSS_MYSTIC                        = 2
    BOSS_HELLFIRE                      = 3
    BOSS_DWARF                         = 4
    BOSS_PALADIN                       = 5
    BOSS_DRAGOON                       = 6
    BOSS_DEATH_KNIGHT                  = 7
    BOSS_VASHJ                         = 8
    BOSS_YETI                          = 9
    BOSS_OGRE                          = 10
    BOSS_NERUBIAN                      = 11
    BOSS_POLAR_BEAR                    = 12
    BOSS_LIFE                          = 13
    BOSS_HATE                          = 14
    BOSS_LOVE                          = 15
    BOSS_KNOWLEDGE                     = 16
    BOSS_ARKADEN                       = 17

    BOSS_DEMON_PRINCE                  = 18
    BOSS_ABSOLUTE_HORROR               = 19
    BOSS_ORSTED                        = 20
    BOSS_SLAUGHTER_QUEEN               = 21
    BOSS_SATAN                         = 22
    BOSS_DARK_SOUL                     = 23
    BOSS_LEGION                        = 24
    BOSS_THANATOS                      = 25
    BOSS_EXISTENCE                     = 26
    BOSS_AZAZOTH                       = 27
    BOSS_XALLARATH                     = 28

    -- item variables
    MAX_REINCARNATION_CHARGES          = 3
    ITEM_MIN_LEVEL_VARIANCE            = 8
    ITEM_MAX_LEVEL_VARIANCE            = 11
    QUALITY_SAVED                      = 7

    TOTAL_STATS = enum(
        -- item stats
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
        -- potion stats
        "ITEM_FLAT_HEAL",
        "ITEM_PERCENT_HEAL",
        "ITEM_FLAT_MANA",
        "ITEM_PERCENT_MANA",
        "ITEM_CHARGES",
        "ITEM_ABILITY",
        -- end of item stats
        "ITEM_ABILITY2",
        -- not part of body
        "ITEM_NOCRAFT",
        "ITEM_TIER",
        "ITEM_TYPE",
        "ITEM_UPGRADE_MAX",
        "ITEM_LEVEL_REQUIREMENT",
        "ITEM_LIMIT",
        "ITEM_COST",
        "ITEM_DISCOUNT",
        "ITEM_STACK",
        "TOTAL_ATTACK_SPEED",
        "XP_RATE",
        "HERO_TIME",
        "PLAYER_TIME"
    )

    CUSTOM_ITEM_OFFSET = FourCC('I000') ---@type integer 

    MAIN_MAP = {
        rect = gg_rct_Main_Map,
        vision = gg_rct_Main_Map_Vision,
        minX = GetRectMinX(gg_rct_Main_Map),
        minY = GetRectMinY(gg_rct_Main_Map),
        maxX = GetRectMaxX(gg_rct_Main_Map),
        maxY = GetRectMaxY(gg_rct_Main_Map),
        region = CreateRegion()
    }

    RegionAddRect(MAIN_MAP.region, MAIN_MAP.rect)

    MAIN_MAP.centerX = (MAIN_MAP.minX + MAIN_MAP.maxX) / 2.00
    MAIN_MAP.centerY = (MAIN_MAP.minY + MAIN_MAP.maxY) / 2.00

    PLAYER_SUMMONS = {} ---@type unit[]
    DAMAGE_TAG = {}
    PLATINUM_TAG    = "|cffccccccPlatinum Coins|r: " ---@type string 
    CRYSTAL_TAG = "|cff6969FFCrystals: |r" ---@type string 
    CHAOS_MODE = false ---@type boolean 
    CHAOS_LOADING = false ---@type boolean 

    ItemData = array2d(0) ---@type table

    ZOOM = __jarray(0) ---@type integer[]

    Hero={} ---@type unit[] 
    HeroGrave={} ---@type unit[] 
    Backpack={} ---@type unit[] 
    HeroID=__jarray(0) ---@type integer[] 

    BOOST=__jarray(1) ---@type number[] 
    LBOOST=__jarray(1) ---@type number[] 

    TOWN_CENTER_X = -250.
    TOWN_CENTER_Y = 160.
    STRUGGLE_CENTER_X = 28030.
    STRUGGLE_CENTER_Y = 4361.

    DEFAULT_LIGHTING = "Environment\\DNC\\DNCAshenvale\\DNCAshenValeTerrain\\DNCAshenValeTerrain.mdx" ---@type string 

    BANISH_FLAG = false ---@type boolean 

    EXPERIENCE_TABLE = {}
    GOLD_TABLE = {}
    BASE_XP_RATE = __jarray(0) ---@type number[]

    for i = 1, 500 do
        EXPERIENCE_TABLE[i] = math.floor(20 + 13. * i * 1.4 ^ (i / 20))
        GOLD_TABLE[i] = EXPERIENCE_TABLE[i] ^ 0.94
    end

    for i = 0, 400 do
        BASE_XP_RATE[i] = (i <= 1 and 100) or (BASE_XP_RATE[i - 1] * 0.988)
    end

    INFO_STRING = {}
    INFO_STRING[0] = "Use -info # for see more info about your chosen catagory\n\n -info 1, Unit Respawning\n -info 2, Boss Respawning\n -info 3, Safezone\n -info 4, Hardcore\n -info 5, Perks\n -info 6, Proficiency"
    INFO_STRING[1] = "Units in the overworld will attempt to revive where they died 30 seconds after death. If a player hero/unit is within 800 range they will spawn frozen and invulnerable until no players are around."
    INFO_STRING[2] = "Bosses respawn after 10 minutes and non-hero bosses respawn after 5 minutes, players may choose to fight a stronger version of the boss after defeating them once.%"
    INFO_STRING[3] = "The town is protected from enemy invasion and any entering enemy will be teleported back to their original spawn."
    INFO_STRING[4] = [[Hardcore players that die without a reincarnation item/spell will be removed from the game and cannot save/load or start a new character. 
    A hardcore hero can only save every 30 minutes- the timer starts upon saving OR upon loading your hardcore hero. 
    Hardcore heroes receive double the bonus from prestiging.]]
    INFO_STRING[5] = "Perk Points are earned by completing specific trials for the first time on a character and will apply to ALL of your existing characters when spent."
    INFO_STRING[6] = [[Most items in this game have a proficiency requirement in their description.
    While any hero can equip them regardless of proficiency, those lacking proficiency receive 75% of the stats.
    Check your hero's proficiency with -pf.]]

    --TODO: expand channel fields?
    SPELL_FIELD = {} ---@type abilityreallevelfield[] 
    SPELL_FIELD[0] = ABILITY_RLF_ART_DURATION
    SPELL_FIELD[1] = ABILITY_RLF_AREA_OF_EFFECT
    SPELL_FIELD[2] = ABILITY_RLF_CAST_RANGE
    SPELL_FIELD[3] = ABILITY_RLF_CASTING_TIME
    SPELL_FIELD[4] = ABILITY_RLF_COOLDOWN
    SPELL_FIELD[5] = ABILITY_RLF_DURATION_HERO
    SPELL_FIELD[6] = ABILITY_RLF_DURATION_NORMAL
    SPELL_FIELD_TOTAL = 6 ---@type integer 

    TIER_NAME = {} ---@type string[] 
    TYPE_NAME = {} ---@type string[] 
    ITEM_MODEL = {} ---@type integer[] 
    LEVEL_PREFIX = {} ---@type string[] 
    SPRITE_RARITY = {} ---@type string[] 
    ITEM_STAT_MULTIPLIER = {} ---@type number[] 
    CRYSTAL_PRICE = {} ---@type integer[] 

    TIER_NAME[0] = ""
    TIER_NAME[1] = "Common"
    TIER_NAME[2] = "|cffbbbbbbUncommon|r"
    TIER_NAME[3] = "|cffffff00Quest|r"
    TIER_NAME[4] = "|cff999999Ursa|r"
    TIER_NAME[5] = "|cff999999Ogre|r"
    TIER_NAME[6] = "|cff999999Unbroken|r"
    TIER_NAME[7] = "|cff999999Magnataur|r"
    TIER_NAME[8] = "|cff55ff44Set|r"
    TIER_NAME[9] = "|cffba0505Boss|r"
    TIER_NAME[10] = "|cff01b9f5Divine|r"
    TIER_NAME[11] = "|cffff5050Chaotic Quest|r"
    TIER_NAME[12] = "Demon"
    TIER_NAME[13] = "Horror"
    TIER_NAME[14] = "Despair"
    TIER_NAME[15] = "Abyssal"
    TIER_NAME[16] = "Void"
    TIER_NAME[17] = "Nightmare"
    TIER_NAME[18] = "Hell"
    TIER_NAME[19] = "Existence"
    TIER_NAME[20] = "Astral"
    TIER_NAME[21] = "Dimensional"
    TIER_NAME[22] = "|cff05aa05Chaotic Set|r"
    TIER_NAME[23] = "|cff700909Chaotic Boss|r"
    TIER_NAME[24] = "|cffa0a0a0Forgotten|r"
    TIER_NAME[25] = "|cff999999Devourer|r"
    --...
    TYPE_NAME[0] = "All"
    TYPE_NAME[1] = "Plate"
    TYPE_NAME[2] = "Fullplate"
    TYPE_NAME[3] = "Leather"
    TYPE_NAME[4] = "Cloth"
    TYPE_NAME[5] = "Shield"
    TYPE_NAME[6] = "Heavy"
    TYPE_NAME[7] = "Sword"
    TYPE_NAME[8] = "Dagger"
    TYPE_NAME[9] = "Bow"
    TYPE_NAME[10] = "Staff"
    TYPE_NAME[11] = "Potion"
    TYPE_ALL = 0xFFF
    TYPE_EQUIPPABLE = 0x3FF
    TYPE_POTION = 0x400
    --...
    ITEM_MODEL[1] = FourCC('rar1')
    ITEM_MODEL[2] = FourCC('rar1')
    ITEM_MODEL[3] = FourCC('rar1')
    ITEM_MODEL[4] = FourCC('rar1')
    ITEM_MODEL[5] = FourCC('rar2')
    ITEM_MODEL[6] = FourCC('rar2')
    ITEM_MODEL[7] = FourCC('rar2')
    ITEM_MODEL[8] = FourCC('rar2')
    ITEM_MODEL[9] = FourCC('rar3')
    ITEM_MODEL[10] = FourCC('rar3')
    ITEM_MODEL[11] = FourCC('rar3')
    ITEM_MODEL[12] = FourCC('rar3')
    ITEM_MODEL[13] = FourCC('rar4')
    ITEM_MODEL[14] = FourCC('rar4')
    ITEM_MODEL[15] = FourCC('rar4')
    ITEM_MODEL[16] = FourCC('rar4')
    ITEM_MODEL[17] = FourCC('rar5')
    ITEM_MODEL[18] = FourCC('rar5')
    ITEM_MODEL[19] = FourCC('rar5')
    ITEM_MODEL[20] = FourCC('rar5')
    --...
    LEVEL_PREFIX[1] = "|cff40bf5fRefined|r"
    LEVEL_PREFIX[2] = "|cff40bf5fRefined|r"
    LEVEL_PREFIX[3] = "|cff40bf5fRefined|r"
    LEVEL_PREFIX[4] = "|cff40bf5fRefined|r"
    LEVEL_PREFIX[5] = "|cff4087bfRare|r"
    LEVEL_PREFIX[6] = "|cff4087bfRare|r"
    LEVEL_PREFIX[7] = "|cff4087bfRare|r"
    LEVEL_PREFIX[8] = "|cff4087bfRare|r"
    LEVEL_PREFIX[9] = "|cff7040bfEpic|r"
    LEVEL_PREFIX[10] = "|cff7040bfEpic|r"
    LEVEL_PREFIX[11] = "|cff7040bfEpic|r"
    LEVEL_PREFIX[12] = "|cff7040bfEpic|r"
    LEVEL_PREFIX[13] = "|cffbf6b40Legendary|r"
    LEVEL_PREFIX[14] = "|cffbf6b40Legendary|r"
    LEVEL_PREFIX[15] = "|cffbf6b40Legendary|r"
    LEVEL_PREFIX[16] = "|cffbf6b40Legendary|r"
    LEVEL_PREFIX[17] = "|cffc41919Chaos|r"
    LEVEL_PREFIX[18] = "|cffc41919Chaos|r"
    LEVEL_PREFIX[19] = "|cffc41919Chaos|r"
    LEVEL_PREFIX[20] = "|cffc41919Chaos|r"
    --...
    SPRITE_RARITY[0] = "war3mapImported\\CommonBorder.dds"
    SPRITE_RARITY[1] = "war3mapImported\\RefinedBorder.dds"
    SPRITE_RARITY[2] = "war3mapImported\\RefinedBorder.dds"
    SPRITE_RARITY[3] = "war3mapImported\\RefinedBorder.dds"
    SPRITE_RARITY[4] = "war3mapImported\\RefinedBorder.dds"
    SPRITE_RARITY[5] = "war3mapImported\\RareBorder.dds"
    SPRITE_RARITY[6] = "war3mapImported\\RareBorder.dds"
    SPRITE_RARITY[7] = "war3mapImported\\RareBorder.dds"
    SPRITE_RARITY[8] = "war3mapImported\\RareBorder.dds"
    SPRITE_RARITY[9] = "war3mapImported\\EpicBorder.dds"
    SPRITE_RARITY[10] = "war3mapImported\\EpicBorder.dds"
    SPRITE_RARITY[11] = "war3mapImported\\EpicBorder.dds"
    SPRITE_RARITY[12] = "war3mapImported\\EpicBorder.dds"
    SPRITE_RARITY[13] = "war3mapImported\\LegendaryBorder.dds"
    SPRITE_RARITY[14] = "war3mapImported\\LegendaryBorder.dds"
    SPRITE_RARITY[15] = "war3mapImported\\LegendaryBorder.dds"
    SPRITE_RARITY[16] = "war3mapImported\\LegendaryBorder.dds"
    SPRITE_RARITY[17] = "war3mapImported\\ChaosBorder.dds"
    SPRITE_RARITY[18] = "war3mapImported\\ChaosBorder.dds"
    SPRITE_RARITY[19] = "war3mapImported\\ChaosBorder.dds"
    SPRITE_RARITY[20] = "war3mapImported\\ChaosBorder.dds"
    --...
    ITEM_STAT_MULTIPLIER[0] = 0
    ITEM_STAT_MULTIPLIER[1] = 0.2
    ITEM_STAT_MULTIPLIER[2] = 0.4
    ITEM_STAT_MULTIPLIER[3] = 0.6
    ITEM_STAT_MULTIPLIER[4] = 0.8
    ITEM_STAT_MULTIPLIER[5] = 1.2
    ITEM_STAT_MULTIPLIER[6] = 1.6
    ITEM_STAT_MULTIPLIER[7] = 2.
    ITEM_STAT_MULTIPLIER[8] = 2.4
    ITEM_STAT_MULTIPLIER[9] = 3.2
    ITEM_STAT_MULTIPLIER[10] = 4.
    ITEM_STAT_MULTIPLIER[11] = 4.8
    ITEM_STAT_MULTIPLIER[12] = 5.6
    ITEM_STAT_MULTIPLIER[13] = 7.
    ITEM_STAT_MULTIPLIER[14] = 8.4
    ITEM_STAT_MULTIPLIER[15] = 9.8
    ITEM_STAT_MULTIPLIER[16] = 11.2
    ITEM_STAT_MULTIPLIER[17] = 13.4
    ITEM_STAT_MULTIPLIER[18] = 15.6
    ITEM_STAT_MULTIPLIER[19] = 17.8
    --...
    CRYSTAL_PRICE[0] = 1
    CRYSTAL_PRICE[1] = 1
    CRYSTAL_PRICE[2] = 2
    CRYSTAL_PRICE[3] = 2
    CRYSTAL_PRICE[4] = 3
    CRYSTAL_PRICE[5] = 3
    CRYSTAL_PRICE[6] = 4
    CRYSTAL_PRICE[7] = 5
    CRYSTAL_PRICE[8] = 6
    CRYSTAL_PRICE[9] = 8
    CRYSTAL_PRICE[10] = 12
    CRYSTAL_PRICE[11] = 16
    CRYSTAL_PRICE[12] = 24
    CRYSTAL_PRICE[13] = 32
    CRYSTAL_PRICE[14] = 48
    CRYSTAL_PRICE[15] = 64
    CRYSTAL_PRICE[16] = 80
    CRYSTAL_PRICE[17] = 96
    CRYSTAL_PRICE[18] = 128
    CRYSTAL_PRICE[19] = 160
    --...
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
    }
    PROF[0] = 0

    --priority: 1 - power, 2 - utility, 3 - player only, 4 - hidden
    STAT_TAG = {
        [ITEM_LEVEL] = { tag = "Level", priority = 1 },
        [ITEM_HEALTH] = { tag = "|cffff0000Health|r", priority = 1, syntax = "health" },
        [ITEM_MANA] = { tag = "|cff6699ffMana|r", priority = 1, syntax = "mana" },
        [ITEM_DAMAGE] = { tag = "|cffff6600Damage|r", priority = 1, syntax = "damage" },
        [ITEM_ARMOR] = { tag = "|cffa4a4feArmor|r", priority = 1, syntax = "armor" },
        [ITEM_STRENGTH] = { tag = "|cffbb0000Strength|r", priority = 1, syntax = "str" },
        [ITEM_AGILITY] = { tag = "|cff008800Agility|r", priority = 1, syntax = "agi" },
        [ITEM_INTELLIGENCE] = { tag = "|cff2255ffIntelligence|r", priority = 1, syntax = "int" },
        [ITEM_REGENERATION] = { tag = "|cffa00070Regeneration|r", priority = 1, syntax = "regen" },
        [ITEM_MANA_REGENERATION] = { tag = "|cff1144ddMana Regen|r", priority = 1, syntax = "manaregen" },
        [ITEM_DAMAGE_RESIST] = { tag = "|cffff8040Damage Resist|r", alternate = "|cffff8040Physical Taken|r", priority = 1, suffix = "%", syntax = "dr" },
        [ITEM_MAGIC_RESIST] = { tag = "|cff8000ffMagic Resist|r", alternate = "|cff8000ffMagical Taken|r", priority = 1, suffix = "%", syntax = "mr" },
        [ITEM_DAMAGE_MULT] = { tag = "|cffff8040Physical Dealt|r", priority = 1, suffix = "%", syntax = "dm" },
        [ITEM_MAGIC_MULT] = { tag = "|cff8000ffMagic Dealt|r", priority = 1, suffix = "%", syntax = "mm" },
        [ITEM_MOVESPEED] = { tag = "|cff888888Movespeed|r", priority = 2, syntax = "ms" },
        [ITEM_EVASION] = { tag = "|cff008080Evasion|r", priority = 2, suffix = "%", syntax = "evasion" },
        [ITEM_SPELLBOOST] = { tag = "|cff80ffffSpellboost|r", priority = 1, suffix = "%", syntax = "spellboost" },
        [ITEM_CRIT_CHANCE] = { tag = "|cffffcc00Critical Chance|r", priority = 1, suffix = "%", syntax = "cc" },
        [ITEM_CRIT_DAMAGE] = { tag = "|cffffcc00Critical Damage|r", priority = 1, suffix = "%", syntax = "cd" },
        [ITEM_CRIT_CHANCE_MULT] = { tag = "|cffffcc00Critical Chance Multiplier|r", priority = 4, suffix = "%", syntax = "cc_percent" },
        [ITEM_CRIT_DAMAGE_MULT] = { tag = "|cffffcc00Critical Damage Multiplier|r", priority = 4, suffix = "%", syntax = "cd_percent" },
        [ITEM_BASE_ATTACK_SPEED] = { tag = "|cff446600Base Attack Speed|r", priority = 1, item_suffix = "%", syntax = "bat" },
        [ITEM_GOLD_GAIN] = { tag = "|cffffff00Gold Find|r", priority = 3, suffix = "%", syntax = "gold" },
        [ITEM_FLAT_HEAL] = { tag = "|rHealth Restored", priority = 4, syntax = "fheal" },
        [ITEM_PERCENT_HEAL] = { tag = "|rPercent Health Restored", priority = 4, syntax = "pheal", suffix = "%" },
        [ITEM_FLAT_MANA] = { tag = "|rMana Restored", priority = 4, syntax = "fmana" },
        [ITEM_PERCENT_MANA] = { tag = "|rPercent Mana Restored", priority = 4, syntax = "pmana", suffix = "%" },
        [ITEM_CHARGES] = { tag = "|rCharges", priority = 4, syntax = "charges" },
        [ITEM_ABILITY] = { priority = 4, syntax = "abil" },
        [ITEM_ABILITY2] = { priority = 4, syntax = "abiltwo" },
        [ITEM_NOCRAFT] = { priority = 4, syntax = "nocraft" },
        [ITEM_TIER] = { priority = 4, syntax = "tier" },
        [ITEM_TYPE] = { priority = 4, syntax = "type" },
        [ITEM_UPGRADE_MAX] = { priority = 4, syntax = "upg" },
        [ITEM_LEVEL_REQUIREMENT] = { priority = 4, syntax = "req" },
        [ITEM_LIMIT] = { priority = 4, syntax = "limit" },
        [ITEM_COST] = { priority = 4, syntax = "cost" },
        [ITEM_DISCOUNT] = { priority = 4, syntax = "discount" },
        [ITEM_STACK] = { priority = 4, syntax = "stack" },
        [TOTAL_ATTACK_SPEED] = { tag = "|cff446600Total Attack Speed|r", priority = 1 },
        [XP_RATE] = { tag = "|cff808080Experience Rate|r", priority = 3, suffix = "%" },
        [HERO_TIME] = { tag = "|cff808000Hero Time Played|r", priority = 3 },
        [PLAYER_TIME] = { tag = "|cff808000Total Time Played|r", priority = 3 }
    }

    local format = string.format

    -- getters and breakdowns for stats
    STAT_TAG[ITEM_LEVEL].breakdown = function(u)
        local lvl = GetUnitLevel(u)
        local s = ""
        if IsUnitType(u, UNIT_TYPE_HERO) then
            s = "XP: " .. GetHeroXP(u) .. "/" .. RequiredXP(lvl)
        end
        return s
    end
    STAT_TAG[ITEM_LEVEL].getter = function(u)
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
            "\n|cffffcc00Percent Bonus:|r " .. format("%.3f", (Unit[u].damage_percent - 1.) * 100.) .. "%" .. " (" .. format("%.3f", Unit[u].damage - Unit[u].bonus_damage - BlzGetUnitBaseDamage(u, 0)) .. ")" ..
            "\n|cffffcc00Total Damage:|r " .. (Unit[u].damage + 1)
    end
    STAT_TAG[ITEM_ARMOR].getter = function(u) return RealToString(BlzGetUnitArmor(u)) end
    STAT_TAG[ITEM_STRENGTH].getter = function(u) return RealToString(GetHeroStr(u, true)) end
    STAT_TAG[ITEM_AGILITY].getter = function(u) return RealToString(GetHeroAgi(u, true)) end
    STAT_TAG[ITEM_INTELLIGENCE].getter = function(u) return RealToString(GetHeroInt(u, true)) end
    STAT_TAG[ITEM_REGENERATION].getter = function(u) return RealToString(Unit[u].regen) end
    STAT_TAG[ITEM_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].regen_flat ..
            "\n|cffffcc00Percent Regeneration:|r " .. format("%.3f", Unit[u].regen_max) .. "%" .. " (" .. format("%.3f", Unit[u].regen_max * Unit[u].hp * 0.01) .. ")" ..
            "\n|cffffcc00Healing Received:|r " .. format("%.3f", Unit[u].regen_percent * 100.) .. "%" ..
            "\n|cffffcc00Total Regeneration:|r " .. Unit[u].regen
    end
    STAT_TAG[ITEM_MANA_REGENERATION].getter = function(u) return RealToString(Unit[u].mana_regen) end
    STAT_TAG[ITEM_MANA_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].mana_regen_flat ..
            "\n|cffffcc00Intelligence Regeneration:|r " .. GetHeroInt(u, true) * 0.05 ..
            "\n|cffffcc00Percent Regeneration:|r " .. format("%.2f", Unit[u].mana_regen_max) .. "%" .. " (" .. Unit[u].mana_regen_max * Unit[u].mana * 0.01 .. ")" ..
            "\n|cffffcc00Mana Received:|r " .. format("%.2f", Unit[u].mana_regen_percent * 100.) .. "%" ..
            "\n|cffffcc00Total Regeneration:|r " .. Unit[u].mana_regen
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].breakdown = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduc == 0.03 and "\n|cffffcc00Chaos Reduction:|r " .. format("%.3f", (1. - chaos_reduc) * 100) .. "%" or "")
        return "|cffffcc00Base Reduction:|r " .. format("%.3f", 100. - (HERO_STATS[GetType(u)].phys_resist) * 100.)  .. "%" ..
            "\n|cffffcc00Spell/Item Reduction:|r " .. format("%.3f", 100. - (Unit[u].dr * Unit[u].pr) / HERO_STATS[GetType(u)].phys_resist * 100.)  .. "%" ..
            "\n|cffffcc00Armor Reduction:|r " .. format("%.3f", ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u))) * 100.)  .. "%" ..
            chaos ..
            "\n|cffffcc00Total Reduction:|r " .. format("%.3f", 100. - (Unit[u].dr * Unit[u].pr) * 100. * (1. - ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u)))) * chaos_reduc) .. "%"
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].getter = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return format("%.3f", (Unit[u].dr * Unit[u].pr) * 100. * (1. - ((0.05 * BlzGetUnitArmor(u)) / (1. + 0.05 * BlzGetUnitArmor(u)))) * chaos_reduc)
    end

    STAT_TAG[ITEM_MAGIC_RESIST].breakdown = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduc == 0.03 and "\n|cffffcc00Chaos Reduction:|r " .. format("%.3f", (1. - chaos_reduc) * 100) .. "%" or "")
        return "|cffffcc00Base Reduction:|r " .. format("%.3f", 100. - (HERO_STATS[GetType(u)].magic_resist) * 100.)  .. "%" ..
            "\n|cffffcc00Spell/Item Reduction:|r " .. format("%.3f", 100. - (Unit[u].dr * Unit[u].mr) / HERO_STATS[GetType(u)].magic_resist * 100.)  .. "%" ..
            chaos ..
            "\n|cffffcc00Total Reduction:|r " .. format("%.3f", 100. - (Unit[u].dr * Unit[u].mr) * 100. * chaos_reduc) .. "%"
    end

    STAT_TAG[ITEM_MAGIC_RESIST].getter = function(u)
        local dtype = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduc = (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return format("%.3f", (Unit[u].dr * Unit[u].mr) * 100. * chaos_reduc)
    end

    STAT_TAG[ITEM_DAMAGE_MULT].getter = function(u) return format("%.3f", (Unit[u].dm * Unit[u].pm) * 100.) end
    STAT_TAG[ITEM_MAGIC_MULT].getter = function(u) return format("%.3f", (Unit[u].dm * Unit[u].mm) * 100.) end
    STAT_TAG[ITEM_MOVESPEED].getter = function(u) return RealToString(Unit[u].movespeed) end
    STAT_TAG[ITEM_EVASION].getter = function(u) return math.min(100, (Unit[u].evasion)) end
    STAT_TAG[ITEM_SPELLBOOST].getter = function(u) return format("%.3f", Unit[u].spellboost * 100.) end
    STAT_TAG[ITEM_CRIT_CHANCE].getter = function(u) return format("%.2f", Unit[u].cc) end
    STAT_TAG[ITEM_CRIT_DAMAGE].getter = function(u) return format("%.2f", Unit[u].cd) end
    STAT_TAG[ITEM_CRIT_CHANCE_MULT].getter = function(u) return format("%.2f", Unit[u].cc) end
    STAT_TAG[ITEM_CRIT_DAMAGE_MULT].getter = function(u) return format("%.2f", Unit[u].cd * 100.) end
    STAT_TAG[ITEM_BASE_ATTACK_SPEED].getter = function(u) local as = BlzGetUnitWeaponBooleanField(u, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0) and 1. / Unit[u].bat or 0 return format("%.2f", as) .. " attacks per second" end
    STAT_TAG[ITEM_GOLD_GAIN].getter = function(u) return Unit[u].gold_rate end
    STAT_TAG[TOTAL_ATTACK_SPEED].getter = function(u) local as = BlzGetUnitWeaponBooleanField(u, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0) and (1. / Unit[u].bat) * (1 + math.min(GetHeroAgi(u, true), 400) * 0.01) or 0 return format("%.2f", as) .. " attacks per second" end
    STAT_TAG[XP_RATE].getter = function(u) return format("%.2f", Unit[u].xp_rate) end
    STAT_TAG[HERO_TIME].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return (Profile[pid].hero.time // 60) .. " hours and " .. ModuloInteger(Profile[pid].hero.time, 60) .. " minutes" end
    STAT_TAG[PLAYER_TIME].getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return (Profile[pid].total_time) // 60 .. " hours and " .. ModuloInteger(Profile[pid].total_time, 60) .. " minutes" end

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

    --hints
    HINT_TOOLTIP = { ---@type string[]
        "|cffc0c0c0Did you know?|r |cff9966ffCoT RPG|r |cffc0c0c0has a discord!|r |cff9ebef5https://discord.gg/peSTvTd|r",
        "|cffc0c0c0Game too easy for you? Select|r |cff9966ffHardcore|r |cffc0c0c0on character creation to increase difficulty & increase benefits.|r",
        "|cffc0c0c0Type|r |cff9966ff-info|r |cffc0c0c0or|r check |cff9966ffF9|r |cffc0c0c0to for important game information, especially if you are new.|r",
        "|cffc0c0c0After an item drops it will be removed after 10 minutes, but don’t worry if you’ve already picked it up or bound it with your hero as they will not delete.|r",
        "|cffc0c0c0Game too difficult? We recommend playing with 2+ players. If you are playing solo, consider playing online with friends or others.|r",
        "|cffc0c0c0Enemies that respawn will appear as ghosts if you are too close, however if you walk away they will return to normal.|r",
        "|cffc0c0c0You can type|r |cff9966ff-hints|r or |cff9966ff-nohints|r |cffc0c0c0to toggle these messages on and off.|r",
        "|cffc0c0c0Once you challenge the gods you cannot flee.|r",
        "|cffc0c0c0Some artifacts remain frozen in ice, waiting to be recovered...|r",
        "|cffc0c0c0Spellboost innately affects the damage of your spells by plus or minus 20%.|r",
        "|cffc0c0c0Critical strike items and spells can stack their effect, the multipliers are additive.|r",
        "|cffc0c0c0The settings menu (Q on your backpack) provides many useful features such as displaying allied hero portraits on the left.|r",
        "|cffc0c0c0You can toggle off your auto attacks with CTRL + A.|r",
        "|cffc0c0c0Hotkeys for certain things may be changed in the settings menu (Q on your backpack).|r",
        "|cffc0c0c0If you meant to load another hero and you haven't left the church, you can type|r |cff9966ff-repick|r |cffc0c0c0and then|r |cff9966ff-load|r |cffc0c0c0to load another hero.|r",
        "|cffc0c0c0Hold |cff9966ffLeft Alt|r |cffc0c0c0while viewing your abilites to see how they are affected by Spellboost.|r"
    }

    LAST_HINT = 0
    FORCE_HINT = CreateForce() ---@type force 
    PrestigeTable = array2d(0) ---@type table
end, Debug and Debug.getLine())
