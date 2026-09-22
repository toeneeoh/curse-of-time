-- Compatibility constants and shared runtime state that do not yet have a
-- narrower subsystem owner.

OnInit.global("Variables", function(Require)
    Require('ItemSchema')
    Require('Rawcodes')
    Require('StatSchema')
    Require('HeroDefinitions')
    Require('BossSchema')
    Require('MainMap')

    DEV_ENABLED = false
    DEV_LOG_ENABLED = true -- Disable after the current in-engine verification pass.
    MAP_NAME = "CoT Nevermore"
    PROFILE_SAVE_VERSION = 1
    CHARACTER_SAVE_VERSION = 1
    SAVE_SCRAMBLE_VERSION = 1

    DUMMY_UNIT = gg_unit_h05E_0717
    PLAYER_CAP = 6
    MAX_LEVEL = 500
    LEECH_CONSTANT = 50
    BOSS_RESPAWN_TIME = 600
    MIN_LIFE = 0.406
    ORDER_ID_SMART = 851971
    ORDER_ID_HOLD_POSITION = 851972
    ORDER_ID_ATTACK = 851983
    ORDER_ID_MOVE = 851986
    ORDER_ID_STOP = 851993
    ORDER_ID_UNDEFEND = 852056
    ORDER_ID_IMMOLATION = 852177
    ORDER_ID_UNIMMOLATION = 852178
    ORDER_ID_MANA_SHIELD = 852589
    PLAYER_CREEP = Player(PLAYER_NEUTRAL_AGGRESSIVE)
    PLAYER_TOWN = 8
    PLAYER_BOSS = Player(11)
    CREEP_ID = PLAYER_NEUTRAL_AGGRESSIVE + 1
    BOSS_ID = 12
    TOWN_ID = 9
    FPS_32 = 0.03125
    INT_32_LIMIT = 2147483647

    PLAYER_SUMMONS = {} ---@type unit[]
    PLATINUM_TAG = "|cffccccccPlatinum Coins|r: "
    CRYSTAL_TAG = "|cff6969FFCrystals: |r"
    CHAOS_MODE = false
    CHAOS_LOADING = false

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
    DEFAULT_LIGHTING = "Environment\\DNC\\DNCAshenvale\\DNCAshenValeTerrain\\DNCAshenValeTerrain.mdx"
    BANISH_FLAG = false

end, Debug and Debug.getLine())
