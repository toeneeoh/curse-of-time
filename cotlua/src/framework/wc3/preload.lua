OnInit.global("Preloader", function()
    local preload = Preload
    --set preplaced unit globals
    Trig_map_preplaced_Actions()
    Trig_map_preplaced_Actions = nil
    DestroyTrigger(gg_trg_map_preplaced)
    gg_trg_map_preplaced = nil

    preload("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdx")
    preload("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdx")
    preload("Abilities\\Weapons\\Bolt\\BoltImpact.mdx")
    preload("war3mapImported\\FrozenOrb.MDX")
    preload("war3mapImported\\Death Nova.mdx")
    preload("war3mapImported\\Lightnings Long.mdx")
    preload("war3mapImported\\NeutralExplosion.mdx")
    preload("war3mapImported\\NewMassiveEX.mdx")
    preload("Abilities\\Spells\\Human\\Resurrect\\ResurrectCaster.mdx")
    preload("war3mapImported\\Call of Dread Red.mdx")
    preload("war3mapImported\\Lava_Slam.mdx")
    preload("war3mapImported\\AnnihilationTarget.mdx")
    preload("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdx")
    preload("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdx")
    preload("Abilities\\Spells\\Human\\Blizzard\\BlizzardTarget.mdx")
    preload("Abilities\\Spells\\Other\\FrostBolt\\FrostBoltMissile.mdl")
    preload("Abilities\\Spells\\Human\\StormBolt\\StormBoltMissile.mdx")
    preload("war3mapImported\\Coup de Grace.mdx")
    preload("Abilities\\Weapons\\GyroCopter\\GyroCopterMissile.mdl")
    preload("war3mapImported\\HighSpeedProjectile_ByEpsilon.mdx")
    preload("Abilities\\Spells\\Other\\AcidBomb\\BottleMissile.mdl")
    preload("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl")
    preload("war3mapImported\\Armor Penetration Orange.mdx")
    preload("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl")
    preload("Abilities\\Weapons\\GlaiveMissile\\GlaiveMissile.mdl")
    preload("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl")
    preload("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl")
    preload("war3mapImported\\Buff_Shield_Non.mdx")
    preload("Units\\Demon\\Infernal\\InfernalBirth.mdl")
    preload("war3mapImported\\Reapers Claws Red.mdx")
    preload("Abilities\\Spells\\Orc\\Devour\\DevourEffectArt.mdl")
    preload("war3mapImported\\DustWindFaster3.mdx")
    preload("UnbrilliantGloryWhite.mdx")
    preload("war3mapImported\\SuperLightningBall.mdl")
    preload("war3mapImported\\EMPBubble.mdx")
    preload("war3mapImported\\Haunt_v2_Portrait.mdl")
    preload("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl")
    preload("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdx")
    preload("Abilities\\Spells\\NightElf\\BattleRoar\\RoarCaster.mdl")
    preload("war3mapImported\\BlackWingVR.mdx")
    preload("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl")
    preload("Abilities\\Spells\\Human\\FlameStrike\\FlameStrikeDamageTarget.mdl")
    preload("Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl")
    preload("Fonts\\diablo.ttf")

    local summon_abilities = {
        {
            unit_id = SUMMON_REAVER,
            abilities = {
                FourCC('A06C'), -- Infuse Essence
                FourCC('A071'), -- Reclaim Essence
                FourCC('A063'), -- Summon Essence
                FourCC('A06Q'), -- Summoning Improvement
                FourCC('A0K2'), -- War Cry
            },
        },
        {
            unit_id = SUMMON_GOLEM,
            abilities = {
                FourCC('A06C'),
                FourCC('A071'),
                FourCC('A063'),
                FourCC('A06Q'),
                FourCC('A0KI'), -- Taunt
                FourCC('A0B0'), -- Thunder Clap
                FourCC('A06O'), -- Magnetic Force
                FourCC('A0IQ'), -- Wing visual
            },
        },
        {
            unit_id = SUMMON_DESTROYER,
            abilities = {
                FourCC('A06C'),
                FourCC('A071'),
                FourCC('A063'),
                FourCC('A06Q'),
                FourCC('A02D'), -- Annihilation
                FourCC('A06J'),
                FourCC('A061'), -- Blink
                FourCC('A03B'), -- Critical strike
                FourCC('A0IQ'), -- Wing visual
            },
        },
    }

    -- Preload(path) warms model files, but not the unit and ability object data
    -- Warcraft initializes on first creation. Create disposable summons before
    -- gameplay hooks are installed so that cost is paid during map startup.
    for i = 1, #summon_abilities do
        local preload_data = summon_abilities[i]
        local summon = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), preload_data.unit_id, 0., 0., 0.)
        ShowUnit(summon, false)

        for j = 1, #preload_data.abilities do
            UnitAddAbility(summon, preload_data.abilities[j])
        end

        RemoveUnit(summon)
    end

    SetMapFlag(MAP_FOG_HIDE_TERRAIN, false)
    SetMapFlag(MAP_FOG_MAP_EXPLORED, true)
    SetMapFlag(MAP_FOG_ALWAYS_VISIBLE, false)
end, Debug and Debug.getLine())
