-- Runtime-authored boss equipment. This avoids fragile binary object edits
-- while retaining the normal item parser, upgrading, saving, and tooltips.

OnInit.final("BossEquipment", function(Require)
    Require('RuntimeItemDefinitions')

    BossEquipment = {}
    local pools = {}

    local function define(boss_id, key, spec)
        local definition = RuntimeItemDefinitions.define(key, spec)
        if not definition then return end
        definition.preview_tooltip = spec.preview_tooltip
        local pool = pools[boss_id]
        if not pool then
            pool = {}
            pools[boss_id] = pool
        end
        pool[#pool + 1] = definition
    end

    local orsted = FourCC('N00F')
    define(orsted, "orsted_ruin", {
        id = 220, carrier = 'I03P', world_skin = 'I03P',
        name = "Orsted's Ruin",
        icon = "ReplaceableTextures\\CommandButtons\\BTNOmegaBlade.blp",
        preview_tooltip = "Requires Level 250|n18,000 Damage|n4,600 Strength|n4 Spellboost|n|n|cff808080A crushing relic shaped by the endless wars of the King of Despair.|r",
        tooltip = "[tier 23] [cost*1000000=2000000] [type 6] [upg 6]|n[req 250]|n[damage 18000] [str 4600] [spellboost*4]|n|n|cff808080A crushing relic shaped by the endless wars of the King of Despair.|r",
    })
    define(orsted, "edge_of_despair", {
        id = 221, carrier = 'I02B', world_skin = 'I02B',
        name = "Edge of Despair",
        icon = "ReplaceableTextures\\CommandButtons\\BTNDarkSword1.blp",
        preview_tooltip = "Requires Level 250|n47,000 Damage|n1,450 Strength|n4 Spellboost|n|n|cff808080A royal blade whose edge has outlived every oath sworn before it.|r",
        tooltip = "[tier 23] [cost*1000000=2000000] [type 7] [upg 6]|n[req 250]|n[damage 47000] [str 1450] [spellboost*4]|n|n|cff808080A royal blade whose edge has outlived every oath sworn before it.|r",
    })
    define(orsted, "despairs_talon", {
        id = 222, carrier = 'I074', world_skin = 'I074',
        name = "Despair's Talon",
        icon = "ReplaceableTextures\\CommandButtons\\BTNChaosDagger.blp",
        preview_tooltip = "Requires Level 250|n23,500 Damage|n10,300 Agility|n4 Spellboost|n|n|cff808080A cruel sliver of steel once hidden beneath Orsted's dark regalia.|r",
        tooltip = "[tier 23] [cost*1000000=2000000] [type 8] [upg 6]|n[req 250]|n[damage 23500] [agi 10300] [spellboost*4]|n|n|cff808080A cruel sliver of steel once hidden beneath Orsted's dark regalia.|r",
    })
    define(orsted, "despairs_reach", {
        id = 223, carrier = 'I0EY', world_skin = 'I0EY',
        name = "Despair's Reach",
        icon = "ReplaceableTextures\\CommandButtons\\BTNPurpleBow2.blp",
        preview_tooltip = "Requires Level 250|n44,500 Damage|n4,400 Agility|n4 Spellboost|n|n|cff808080No distance offered refuge from the gaze of the fallen king.|r",
        tooltip = "[tier 23] [cost*1000000=2000000] [type 9] [upg 6]|n[req 250]|n[damage 44500] [agi 4400] [spellboost*4]|n|n|cff808080No distance offered refuge from the gaze of the fallen king.|r",
    })
    define(orsted, "scepter_of_despair", {
        id = 224, carrier = 'I03U', world_skin = 'I03U',
        name = "Scepter of Despair",
        icon = "ReplaceableTextures\\CommandButtons\\BTNDeadProphetStaff.blp",
        preview_tooltip = "Requires Level 250|n8,500 Damage|n11,900 Intelligence|n7 Spellboost|n|n|cff808080A blackened scepter that answers only to grief and conquest.|r",
        tooltip = "[tier 23] [cost*1000000=2000000] [type 10] [upg 6]|n[req 250]|n[damage 8500] [int 11900] [spellboost*7]|n|n|cff808080A blackened scepter that answers only to grief and conquest.|r",
    })

    local xallarath = FourCC('O03G')
    define(xallarath, "forgotten_carapace", {
        id = 225, carrier = 'I02C', world_skin = 'I02C',
        name = "Forgotten Carapace",
        icon = "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp",
        preview_tooltip = "Requires Level 360|n15,000 Armor|n8,000 Strength|n4,000 Health Regeneration|n|n|cff808080Its plates remember a war whose victors have long since vanished.|r",
        tooltip = "[tier 24] [cost*100000000=20000000] [type 1] [upg 16]|n[req 360]|n[armor 15000] [str 8000] [regen 4000]|n|n|cff808080Its plates remember a war whose victors have long since vanished.|r",
    })
    define(xallarath, "xallaraths_bulwark", {
        id = 226, carrier = 'I079', world_skin = 'I079',
        name = "Xallarath's Bulwark",
        icon = "ReplaceableTextures\\CommandButtons\\BTNThoriumArmor.blp",
        preview_tooltip = "Requires Level 360|n22,000 Armor|n2,000,000 Health|n5,000 Health Regeneration|n|n|cff808080A silent weight presses outward from beneath its ancient metal.|r",
        tooltip = "[tier 24] [cost*100000000=20000000] [type 2] [upg 16]|n[req 360]|n[armor 22000] [health 2000000] [regen 5000]|n|n|cff808080A silent weight presses outward from beneath its ancient metal.|r",
    })
    define(xallarath, "torturers_hide", {
        id = 227, carrier = 'I074', world_skin = 'I074',
        name = "Torturer's Hide",
        icon = "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeThree.blp",
        preview_tooltip = "Requires Level 360|n13,000 Armor|n13,500 Agility|n4 Magic Resistance|n|n|cff808080Every seam was drawn tight by hands that delighted in suffering.|r",
        tooltip = "[tier 24] [cost*100000000=20000000] [type 3] [upg 16]|n[req 360]|n[armor 13000] [agi 13500] [mr*4=1]|n|n|cff808080Every seam was drawn tight by hands that delighted in suffering.|r",
    })
    define(xallarath, "vestment_of_oblivion", {
        id = 228, carrier = 'I07F', world_skin = 'I07F',
        name = "Vestment of Oblivion",
        icon = "ReplaceableTextures\\CommandButtons\\BTNRobeOfTheMagi.blp",
        preview_tooltip = "Requires Level 360|n11,000 Armor|n15,000 Intelligence|n3,000 Health Regeneration|n|n|cff808080Words fade from memory when spoken beneath its shrouded folds.|r",
        tooltip = "[tier 24] [cost*100000000=20000000] [type 4] [upg 16]|n[req 360]|n[armor 11000] [int 15000] [regen 3000]|n|n|cff808080Words fade from memory when spoken beneath its shrouded folds.|r",
    })
    define(xallarath, "heart_of_the_forgotten", {
        id = 229, carrier = 'I0F9', world_skin = 'I0F9',
        name = "Heart of the Forgotten",
        icon = "ReplaceableTextures\\CommandButtons\\BTNHeartOfAszune.blp",
        preview_tooltip = "Requires Level 360|n6,000 Strength|n6,000 Agility|n6,000 Intelligence|n1,000,000 Health|n|n|cff808080It beats only when no living soul remembers the name it once bore.|r",
        tooltip = "[tier 24] [cost*100000000=20000000] [type 5] [upg 16]|n[req 360]|n[str 6000] [agi 6000] [int 6000] [health 1000000]|n|n|cff808080It beats only when no living soul remembers the name it once bore.|r",
    })

    function BossEquipment.getPool(boss_id)
        return pools[boss_id]
    end

    function BossEquipment.create(definition, x, y, expire)
        return RuntimeItemDefinitions.create(definition, x, y, expire)
    end
end, Debug and Debug.getLine())
