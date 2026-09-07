OnInit.global("HelpText", function()
    INFO_STRING = {
        [0] = "Use -info # for see more info about your chosen catagory\n\n -info 1, Unit Respawning\n -info 2, Boss Respawning\n -info 3, Safezone\n -info 4, Hardcore\n -info 5, Perks\n -info 6, Proficiency",
        "Units in the overworld will attempt to revive where they died 30 seconds after death. If a player hero/unit is within 800 range they will spawn frozen and invulnerable until no players are around.",
        "Bosses respawn after 10 minutes and non-hero bosses respawn after 5 minutes, players may choose to fight a stronger version of the boss after defeating them once.%",
        "The town is protected from enemy invasion and any entering enemy will be teleported back to their original spawn.",
        [[Hardcore players that die without a reincarnation item/spell will be removed from the game and cannot save/load or start a new character.
    A hardcore hero can only save every 30 minutes- the timer starts upon saving OR upon loading your hardcore hero.
    Hardcore heroes receive double the bonus from prestiging.]],
        "Perk Points are earned by completing specific trials for the first time on a character and will apply to ALL of your existing characters when spent.",
        [[Most items in this game have a proficiency requirement in their description.
    While any hero can equip them regardless of proficiency, those lacking proficiency receive 75% of the stats.
    Check your hero's proficiency with -pf.]],
    }
end, Debug and Debug.getLine())
