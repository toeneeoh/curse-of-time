--[[
    cosmetics.lua

    A module that defines both unlockable and donator cosmetics in the game.
]]

OnInit.final("Cosmetics", function(Require)
    Require('Users')
    Require('Variables')
    Require('MapSetup')

    DONATOR_AURA_OFFSET = 1000 ---@type integer 

    IS_DONATOR = {} ---@type boolean[] 
    local donator = {
        "lcm#1458 11111111111111111111111 1111111111111111111",
        "Mayday#12613 01 0",
        "gnta#1220 001 0",
        "Gingusa#1768 0001 0000000000001",
        "Demon#24174 00001 000001",
        "Veridian#1582 000001 001",
        "Baraghmarus#1362 0000001 0",
        "DarkSideGami#1825 00000001 000000001",
        "CanFight#2771 000000001 0",
        "DivineEvil#1601 0000000001 0",
        "Ash#14387 00000000001 0",
        "YeOldTurnip#1512 000000000001 0",
        "Anarak#11980 0000000000001 01",
        "ThayldDrekka#1293 00000000000001 0000001",
        "Wyce#21518 000000000000001 00000000001",
        "SilverHand#11103 0000000000000001 0",
        "Kris#2648 00000000000000001 0",
        "Diablo89#1701 000000000000000001 000000000001",
        "Luglug#1434 0000000000000000001 00000000000001",
        "Peacee#21451 00000000000000000001 0",
        "DarkMatter#12814 0 00011",
        "xriderx#1392 0 0000000001",
        "Dynasty3990#1468 000000000000000000001 000000000001",
        "Rshdan#2718 0000000000000000000001 000000000000001",
        "Prove#21949 00000000000000000000001 0000000000000001",
        "AruAzif#2174 01 0",
    }

    for i = 1, #donator do
        local name, skinFlags, auraFlags = donator[i]:match("(\x25S+) (\x25S+) (\x25S+)")

        --flag as donator
        CosmeticTable[name][0] = 1

        --set skin flags
        for j = 1, #skinFlags do
            CosmeticTable[name][j] = tonumber(skinFlags:sub(j, j))
        end

        --set aura flags
        for j = 1, #auraFlags do
            CosmeticTable[name][DONATOR_AURA_OFFSET + j] = tonumber(auraFlags:sub(j, j))
        end
    end

    --used to unlock backpack skins
    PrestigeSkins = {
        {HERO_MARKSMAN, HERO_PHOENIX_RANGER, HERO_BLOODZERKER},     --atk prestige 1
        {HERO_MARKSMAN, HERO_PHOENIX_RANGER, HERO_BLOODZERKER},     --atk prestige 2
        {HERO_SAVIOR, HERO_OBLIVION_GUARD, HERO_WARRIOR},           --str prestige 1
        {HERO_SAVIOR, HERO_OBLIVION_GUARD, HERO_WARRIOR},           --str prestige 2
        {HERO_ASSASSIN, HERO_MASTER_ROGUE, HERO_VAMPIRE},           --agi prestige 1
        {HERO_ASSASSIN, HERO_MASTER_ROGUE, HERO_VAMPIRE},           --agi prestige 2
        {HERO_HYDROMANCER, HERO_DARK_SAVIOR, HERO_DARK_SUMMONER},   --int prestige 1
        {HERO_HYDROMANCER, HERO_DARK_SAVIOR, HERO_DARK_SUMMONER},   --int prestige 2
        {HERO_CRUSADER, HERO_ROYAL_GUARDIAN},                       --dr prestige 1
        {HERO_CRUSADER, HERO_ROYAL_GUARDIAN},                       --dr prestige 2
        {HERO_ARCANIST, HERO_ELEMENTALIST, HERO_THUNDERBLADE},      --spellboost prestige 1
        {HERO_ARCANIST, HERO_ELEMENTALIST, HERO_THUNDERBLADE},      --spellboost prestige 2
        {HERO_ARCANIST, HERO_ELEMENTALIST, HERO_THUNDERBLADE},      --spellboost prestige 3
        {HERO_HIGH_PRIEST, HERO_BARD},                              --regen prestige 1
        {HERO_HIGH_PRIEST, HERO_BARD},                              --regen prestige 2
        {HERO_ARCANIST, HERO_ASSASSIN, HERO_MARKSMAN, HERO_HYDROMANCER, HERO_PHOENIX_RANGER, HERO_ELEMENTALIST, HERO_HIGH_PRIEST, HERO_MASTER_ROGUE,
        HERO_SAVIOR, HERO_BARD, HERO_CRUSADER, HERO_BLOODZERKER, HERO_DARK_SAVIOR, HERO_DARK_SUMMONER, HERO_OBLIVION_GUARD, HERO_ROYAL_GUARDIAN,
        HERO_THUNDERBLADE, HERO_WARRIOR, HERO_VAMPIRE},            --prestige 10
        {HERO_ARCANIST, HERO_ASSASSIN, HERO_MARKSMAN, HERO_HYDROMANCER, HERO_PHOENIX_RANGER, HERO_ELEMENTALIST, HERO_HIGH_PRIEST, HERO_MASTER_ROGUE,
        HERO_SAVIOR, HERO_BARD, HERO_CRUSADER, HERO_BLOODZERKER, HERO_DARK_SAVIOR, HERO_DARK_SUMMONER, HERO_OBLIVION_GUARD, HERO_ROYAL_GUARDIAN,
        HERO_THUNDERBLADE, HERO_WARRIOR, HERO_VAMPIRE},            --prestige all
    }

    CosmeticTable.skins = {
        { name = "Malthael", id = FourCC('H013'), public = false },
        { name = "Faerie Dragon", id = FourCC('H014'), public = false },
        { name = "Pestilant Prince", id = FourCC('H015'), public = false },
        { name = "Reaper", id = FourCC('H021'), public = false },
        { name = "Evil Eye", id = FourCC('H022'), public = false },
        { name = "Undead Batrider", id = FourCC('H024'), public = false },
        { name = "Spectre", id = FourCC('H026'), public = false },
        { name = "Demoness", id = FourCC('H00J'), public = false },
        { name = "Peasant", id = FourCC('H028'), public = false },
        { name = "Nightmare Sheep", id = FourCC('H02C'), public = false },
        { name = "Frost Wyrm", id = FourCC('H02K'), public = false },
        { name = "Obsidian Destroyer", id = FourCC('H02O'), public = false },
        { name = "Spider", id = FourCC('H02R'), public = false },
        { name = "Scavenger", id = FourCC('H06X'), public = false },
        { name = "Succubus", id = FourCC('H03O'), public = false },
        { name = "Lich", id = FourCC('H03P'), public = false },
        { name = "Polar Bear", id = FourCC('H03Q'), public = false },
        { name = "Diablo", id = FourCC('H03R'), public = false },
        { name = "Gnome Dragonrider", id = FourCC('H00A'), public = false },
        { name = "Explosive Sheep", id = FourCC('H03S'), public = false },
        { name = "Phoenix", id = FourCC('H00H'), public = false },
        { name = "Demon Taskmaster", id = FourCC('H000'), public = false },
        { name = "Robincoon", id = FourCC('H00L'), public = false },
        --obtainable skins
        { name = "None", id = DUMMY_VISION, public = true },
        { name = "Wisp", id = FourCC('H011'), public = true },
        { name = "Black Dragon Whelp", id = FourCC('H031'), public = true, req = 1 }, --atk prestige 1
        { name = "Shadow Mephit", id = FourCC('H03C'), public = true, req = 2 }, --atk prestige 2
        { name = "Red Dragon Whelp", id = FourCC('H03E'), public = true, req = 1 }, --str prestige 1
        { name = "Fire Mephit", id = FourCC('H03L'), public = true, req = 2 }, --str prestige 2
        { name = "Green Dragon Whelp", id = FourCC('H03U'), public = true, req = 1 }, --agi prestige 1
        { name = "Venom Mephit", id = FourCC('H03Z'), public = true, req = 2 }, --agi prestige 2
        { name = "Blue Dragon Whelp", id = FourCC('H041'), public = true, req = 1 }, --int prestige 1
        { name = "Ice Mephit", id = FourCC('H042'), public = true, req = 2 }, --int prestige 2
        { name = "Wyvern", id = FourCC('H04E'), public = true, req = 1 }, --dmg prestige 1
        { name = "Nether Dragon", id = FourCC('H04L'), public = true, req = 2 }, --dmg prestige 2
        { name = "Owl", id = FourCC('H04O'), public = true, req = 1 }, --spellboost prestige 1
        { name = "Spirit Owl", id = FourCC('H04P'), public = true, req = 2 }, --spellboost prestige 2
        { name = "Phase Bat", id = FourCC('H058'), public = true, req = 3 }, --spellboost prestige 3
        { name = "Yellow Dragon Whelp", id = FourCC('H05I'), public = true, req = 1 }, --regen prestige 1
        { name = "Earth Mephit", id = FourCC('H05K'), public = true, req = 2 }, --regen prestige 2
        { name = "Elder Shadow Dragon", id = FourCC('H066'), public = true, req = 10 }, --prestige 10 chars
        { name = "Sin", id = FourCC('H06W'), public = true, req = HERO_TOTAL }, --all chars prestiged
    }

    PUBLIC_SKINS = 24
    TOTAL_SKINS = #CosmeticTable.skins

    --generate error messages
    local count = 1
    for i = PUBLIC_SKINS + 2, TOTAL_SKINS do
        local requirements = ""

        for _, j in ipairs(PrestigeSkins[count]) do
            requirements = requirements .. GetObjectName(j) .. ", "
        end
        requirements = requirements:gsub(", $", "")
        CosmeticTable.skins[i].error = "|cffff0000You need atleast " .. CosmeticTable.skins[i].req .. " prestige" .. ((CosmeticTable.skins[i].req > 1 and "s") or "") .. " from (" .. requirements .. ")"

        count = count + 1
    end

    --auras
    CosmeticTable.cosmetics = {
        {
            name = "Giant + Blue Flame",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A04O')) > 0 then
                    SetUnitScale(Hero[pid], BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE))
                    UnitRemoveAbility(Hero[pid], FourCC('A04O'))
                else
                    SetUnitScale(Hero[pid], 1.5, 1.5, 1.5)
                    DestroyEffect(AddSpecialEffectTarget("war3mapImported\\FlameBomb.mdx", Hero[pid], "chest"))
                    UnitAddAbility(Hero[pid], FourCC('A04O'))
                end
            end
        },
        {
            name = "Giant + Holy Trail",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A04T')) > 0 then
                    SetUnitScale(Hero[pid], BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE))
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                    UnitRemoveAbility(Hero[pid], FourCC('A04T'))
                else
                    SetUnitScale(Hero[pid], 1.4, 1.4, 1.4)
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\ArchAngelArcana2.mdx", Hero[pid], "overhead")
                    UnitAddAbility(Hero[pid], FourCC('A04T'))
                end
            end
        },
        {
            name = "Orange Pentagram",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A053')) > 0 then
                    UnitRemoveAbility(Hero[pid], FourCC('A053'))
                else
                    UnitAddAbility(Hero[pid], FourCC('A053'))
                end
            end
        },
        {
            name = "Giant + Kingstride Aura",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A054')) > 0 then
                    SetUnitScale(Hero[pid], BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(Hero[pid], UNIT_RF_SCALING_VALUE))
                    UnitRemoveAbility(Hero[pid], FourCC('A054'))
                else
                    SetUnitScale(Hero[pid], 1.4, 1.4, 1.4)
                    UnitAddAbility(Hero[pid], FourCC('A054'))
                end
            end
        },
        {
            name = "Holy Aurora",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A05A')) > 0 then
                    UnitRemoveAbility(Hero[pid], FourCC('A05A'))
                else
                    UnitAddAbility(Hero[pid], FourCC('A05A'))
                end
            end
        },
        {
            name = "Spiral Aura",
            effect = function(self, pid)
                if GetUnitAbilityLevel(Hero[pid], FourCC('A05L')) > 0 then
                    UnitRemoveAbility(Hero[pid], FourCC('A05L'))
                else
                    UnitAddAbility(Hero[pid], FourCC('A05L'))
                end
            end
        },
        {
            name = "Vampiric Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAura.mdl", Hero[pid], "origin")
                    BlzSetSpecialEffectScale(self[pid .. self.name], 0.75)
                    BlzSetSpecialEffectColor(self[pid .. self.name], 255, 0, 0)
                end
            end
        },
        {
            name = "Blood Ritual",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\Blood Ritual.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Soul Armor",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\Soul Armor Cosmic_opt.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Orange Radiance",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\Radiance_Orange.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Liberty Green",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\Liberty Green.mdx", Hero[pid], "chest")
                end
            end
        },
        {
            name = "Running Flame",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\s_RunningFlame Aura.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Grudge Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\GrudgeAura.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Nuke Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\AuraNuke.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Runic Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\RunicAura.mdx", Hero[pid], "origin")
                end
            end
        },
        {
            name = "Void Disc",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    DestroyEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = AddSpecialEffectTarget("war3mapImported\\Void Disc.mdx", Hero[pid], "origin")
                end
            end
        },
    }

    local u = User.first

    while u do
        if CosmeticTable[u.name][0] > 0 then
            IS_DONATOR[u.id] = true
        end

        u = u.next
    end

end, Debug and Debug.getLine())
