--[[
    cosmetics.lua

    A module that defines both unlockable and donator cosmetics in the game.
]]

OnInit.final("Cosmetics", function(Require)
    Require('Users')
    Require('Variables')
    Require('MapSetup')
    Require('Honor')

    Cosmetics = {}
    CosmeticTable = array2d(0) ---@type table
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
        local name, skinFlags, auraFlags = donator[i]:match("(%S+) (%S+) (%S+)")

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
        { name = "Black Dragon Whelp", id = FourCC('H031'), honor = 5 },
        { name = "Shadow Mephit", id = FourCC('H03C'), honor = 15 },
        { name = "Red Dragon Whelp", id = FourCC('H03E'), honor = 5 },
        { name = "Fire Mephit", id = FourCC('H03L'), honor = 15 },
        { name = "Green Dragon Whelp", id = FourCC('H03U'), honor = 5 },
        { name = "Venom Mephit", id = FourCC('H03Z'), honor = 15 },
        { name = "Blue Dragon Whelp", id = FourCC('H041'), honor = 5 },
        { name = "Ice Mephit", id = FourCC('H042'), honor = 15 },
        { name = "Wyvern", id = FourCC('H04E'), honor = 30 },
        { name = "Nether Dragon", id = FourCC('H04L'), honor = 50 },
        { name = "Owl", id = FourCC('H04O'), honor = 100 },
        { name = "Spirit Owl", id = FourCC('H04P'), honor = 200 },
        { name = "Phase Bat", id = FourCC('H058'), honor = 350 },
        { name = "Yellow Dragon Whelp", id = FourCC('H05I'), honor = 500 },
        { name = "Earth Mephit", id = FourCC('H05K'), honor = 750 },
        { name = "Elder Shadow Dragon", id = FourCC('H066'), honor = 1000 },
        { name = "Sin", id = FourCC('H06W'), honor = 10000 },
    }

    PUBLIC_SKINS = 24
    TOTAL_SKINS = #CosmeticTable.skins

    ---@param pid integer
    ---@param index integer
    ---@return boolean
    function Cosmetics.isSkinUnlocked(pid, index)
        local skin = CosmeticTable.skins[index]
        if not skin then return false end

        local name = User[pid - 1].name
        return skin.public == true
            or CosmeticTable[name][index] > 0
            or (skin.honor ~= nil and Honor.getTotal(pid) >= skin.honor)
    end

    ---@param index integer
    ---@return string
    function Cosmetics.getSkinRequirement(index)
        local skin = CosmeticTable.skins[index]
        if skin and skin.honor then
            return "Requires |cffffcc00" .. skin.honor .. " Honor|r."
        end
        return "This backpack skin is not unlocked."
    end

    ---@param pid integer
    ---@return integer, integer
    function Cosmetics.getBackpackProgress(pid)
        local unlocked = 0
        local total = 0
        for index = 1, #CosmeticTable.skins do
            if CosmeticTable.skins[index].honor then
                total = total + 1
                if Cosmetics.isSkinUnlocked(pid, index) then
                    unlocked = unlocked + 1
                end
            end
        end
        return unlocked, total
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
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                    UnitRemoveAbility(Hero[pid], FourCC('A04T'))
                else
                    SetUnitScale(Hero[pid], 1.4, 1.4, 1.4)
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\ArchAngelArcana2.mdx", "overhead")
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
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAura.mdl", "origin")
                    BlzSetSpecialEffectScale(self[pid .. self.name].effect, 0.75)
                    BlzSetSpecialEffectColor(self[pid .. self.name].effect, 255, 0, 0)
                end
            end
        },
        {
            name = "Blood Ritual",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\Blood Ritual.mdx", "origin")
                end
            end
        },
        {
            name = "Soul Armor",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\Soul Armor Cosmic_opt.mdx", "origin")
                end
            end
        },
        {
            name = "Orange Radiance",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\Radiance_Orange.mdx", "origin")
                end
            end
        },
        {
            name = "Liberty Green",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\Liberty Green.mdx", "chest")
                end
            end
        },
        {
            name = "Running Flame",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\s_RunningFlame Aura.mdx", "origin")
                end
            end
        },
        {
            name = "Grudge Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\GrudgeAura.mdx", "origin")
                end
            end
        },
        {
            name = "Nuke Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\AuraNuke.mdx", "origin")
                end
            end
        },
        {
            name = "Runic Aura",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\RunicAura.mdx", "origin")
                end
            end
        },
        {
            name = "Void Disc",
            effect = function(self, pid)
                if self[pid .. self.name] then
                    Unit[Hero[pid]]:removeEffect(self[pid .. self.name])
                    self[pid .. self.name] = nil
                else
                    self[pid .. self.name] = Unit[Hero[pid]]:addEffect("war3mapImported\\Void Disc.mdx", "origin")
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
