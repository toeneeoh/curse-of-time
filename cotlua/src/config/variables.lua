--[[
    variables.lua

    Assorted defined globals / constants
]]

OnInit.global("Variables", function(Require)
    Require('ItemSchema')
    Require('Rawcodes')
    Require('StatSchema')

    local FourCC = FourCC

    DEV_ENABLED            = false -- not necessary for release
    DEV_LOG_ENABLED        = true  -- disable after the current in-engine verification pass
    MAP_NAME               = "CoT Nevermore"
    PROFILE_SAVE_VERSION   = 1
    CHARACTER_SAVE_VERSION = 1
    SAVE_SCRAMBLE_VERSION  = 1

    DUMMY_UNIT                         = gg_unit_h05E_0717
    PLAYER_CAP                         = 6
    MAX_LEVEL                          = 500
    LEECH_CONSTANT                     = 50
    BOSS_RESPAWN_TIME                  = 600
    MIN_LIFE                           = 0.406
    ORDER_ID_SMART                     = 851971
    ORDER_ID_HOLD_POSITION             = 851972
    ORDER_ID_ATTACK                    = 851983
    ORDER_ID_MOVE                      = 851986
    ORDER_ID_STOP                      = 851993
    ORDER_ID_UNDEFEND                  = 852056
    ORDER_ID_IMMOLATION                = 852177
    ORDER_ID_UNIMMOLATION              = 852178
    ORDER_ID_MANA_SHIELD               = 852589
    PLAYER_CREEP                       = Player(PLAYER_NEUTRAL_AGGRESSIVE)
    PLAYER_TOWN                        = 8
    PLAYER_BOSS                        = Player(11)
    CREEP_ID                           = PLAYER_NEUTRAL_AGGRESSIVE + 1
    BOSS_ID                            = 12
    TOWN_ID                            = 9
    FPS_32                             = 0.03125
    INT_32_LIMIT                       = 2147483647
    HERO_TOTAL                         = 19

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
        stars        = {2, 3, 2, 1, 2.5}
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
        skills       = {"A0GO", "A08Z", "A019", "A074", "A013", "A00C"},
        stars        = {1, 3, 3, 0.5, 1.5}
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
        skills       = {"A022", "A0KF", "A0KH", "A0KG", "A0K1", "A002"},
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
        skills       = {"A01Q", "A06I", "A06U", "A05D", "A0J4", "A06V"},
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
        range        = "700",
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
    PLATINUM_TAG    = "|cffccccccPlatinum Coins|r: " ---@type string 
    CRYSTAL_TAG = "|cff6969FFCrystals: |r" ---@type string 
    CHAOS_MODE = false ---@type boolean 
    CHAOS_LOADING = false ---@type boolean 

    INTERNAL_AI_COOLDOWN = 4

    MIN_SPELLBOOST_VARIANCE = -0.1
    MAX_SPELLBOOST_VARIANCE = 0.1

    ZOOM = __jarray(0) ---@type integer[]

    Hero = {} ---@type unit[] 
    HeroGrave = {} ---@type unit[] 
    Backpack = {} ---@type unit[] 

    BOOST = __jarray(1) ---@type number[] 
    LBOOST = __jarray(1) ---@type number[] 

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
        "|cffc0c0c0Spellboost innately affects the damage of your spells by plus or minus 10%.|r",
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
