--[[
    drop_table.lua

    Defines item drop tables for units, adjusts rates to equalize drop chances
]] OnInit.final("DropTable", function(Require)
    Require('PotionService')
    Require('UnitTable')

    ItemDrops = array2d(0)
    Rates = __jarray(0)

    local COLOSSEUM_TICKET = FourCC('I008')
    local COLOSSEUM_TICKET_CHANCE = 0.0025
    local COLOSSEUM_ELITE_TICKET_CHANCE = 0.01
    local PRECHAOS_FLASK_CHANCE = 0.002
    local PRECHAOS_ELITE_FLASK_CHANCE = 0.02

    ---@class DropTable
    ---@field pickItem function
    ---@field getItemDistribution fun(self: DropTable, id: integer): number[], integer
    ---@field rollColosseumTicket fun(self: DropTable, x: number, y: number, chance: number): boolean
    ---@field registerBossDropSource fun(self: DropTable, source: BossDropSource): boolean
    ---@field getBossDropEntries fun(self: DropTable, boss: Boss, multiplier: number): BossDropEntry[]
    ---@field rollBossDrops fun(self: DropTable, boss: Boss, x: number, y: number, multiplier: number)
    DropTable = {}
    do
        local thistype = DropTable
        local MAX_ITEM_COUNT = 100
        local ADJUST_RATE = 0.05
        local boss_drop_sources = {}

        ---@class BossDropEntry
        ---@field key string
        ---@field item_id? integer
        ---@field name? string
        ---@field icon? string
        ---@field tooltip? string
        ---@field chance number Unconditional chance of at least one copy.
        ---@field pool_share? number Conditional equipment-pool share.

        ---@class BossDropSource
        ---@field key string
        ---@field available? fun(boss: Boss): boolean
        ---@field describe fun(boss: Boss, multiplier: number): BossDropEntry[]
        ---@field roll fun(boss: Boss, x: number, y: number, multiplier: number)

        -- adjusts the drop rates of all items in a pool after a drop
        ---@type fun(id: integer, i: integer)
        local function adjust_rate(id, index)
            local drop = ItemDrops[id]
            local max = drop[MAX_ITEM_COUNT]

            if max <= 1 then return end

            local adjust = 1. / max * ADJUST_RATE
            local balance = adjust / (max - 1.)

            for i = 1, max do
                if drop[i] == drop[index] then
                    drop[i .. "%"] = drop[i .. "%"] - adjust
                else
                    drop[i .. "%"] = drop[i .. "%"] + balance
                end
            end
        end

        --[[selects an item from a unit type item pool
            starts at a random index and increments by 1]]
        ---@type fun(self: DropTable, id: integer):integer
        function thistype:pickItem(id)
            local drop = ItemDrops[id]
            local max = drop[MAX_ITEM_COUNT]
            local i = GetRandomInt(1, max)

            while true do
                if GetRandomReal(0., 1.) < drop[i .. "%"] then
                    adjust_rate(id, i)
                    break
                end

                if i >= max then
                    i = 1
                else
                    i = i + 1
                end
            end

            return ItemDrops[id][i]
        end

        ---Returns each item's actual probability of being selected by pickItem.
        ---The picker starts at a random slot and tests each adaptive acceptance
        ---rate in order, so these probabilities are not generally the raw rates.
        ---@param id integer
        ---@return number[] distribution
        ---@return integer count
        function thistype:getItemDistribution(id)
            local drop = ItemDrops[id]
            local count = drop[MAX_ITEM_COUNT]
            local distribution = {}
            if count <= 0 then return distribution, 0 end

            local failure_cycle = 1.
            for index = 1, count do
                local acceptance = math.min(1., math.max(0.,
                                            drop[index .. "%"] or 0.))
                failure_cycle = failure_cycle * (1. - acceptance)
            end
            local eventual_success = 1. - failure_cycle
            if eventual_success <= 0. then
                local equal = 1. / count
                for index = 1, count do distribution[index] = equal end
                return distribution, count
            end

            for target = 1, count do
                local acceptance = math.min(1., math.max(0.,
                                            drop[target .. "%"] or 0.))
                local probability = 0.
                for start = 1, count do
                    local reach = 1.
                    local index = start
                    while index ~= target do
                        local tested = math.min(1., math.max(0.,
                                                drop[index .. "%"] or 0.))
                        reach = reach * (1. - tested)
                        index = index >= count and 1 or index + 1
                    end
                    probability = probability + reach * acceptance /
                                      eventual_success
                end
                distribution[target] = probability / count
            end
            return distribution, count
        end

        local function clamp_chance(chance)
            return math.min(1., math.max(0., chance or 0.))
        end

        ---Registers a self-contained boss reward provider. Both reward rolls
        ---and multiboard entries are obtained from this same definition.
        function thistype:registerBossDropSource(source)
            if type(source) ~= "table" or type(source.key) ~= "string" or
                type(source.describe) ~= "function" or
                type(source.roll) ~= "function" then return false end
            boss_drop_sources[#boss_drop_sources + 1] = source
            return true
        end

        local function source_available(source, boss)
            return not source.available or source.available(boss)
        end

        function thistype:getBossDropEntries(boss, multiplier)
            local result = {}
            multiplier = math.max(0., multiplier or 1.)
            for source_index = 1, #boss_drop_sources do
                local source = boss_drop_sources[source_index]
                if source_available(source, boss) then
                    local entries = source.describe(boss, multiplier) or {}
                    for entry_index = 1, #entries do
                        local entry = entries[entry_index]
                        entry.chance = clamp_chance(entry.chance)
                        result[#result + 1] = entry
                    end
                end
            end
            return result
        end

        function thistype:rollBossDrops(boss, x, y, multiplier)
            multiplier = math.max(0., multiplier or 1.)
            for index = 1, #boss_drop_sources do
                local source = boss_drop_sources[index]
                if source_available(source, boss) then
                    source.roll(boss, x, y, multiplier)
                end
            end
        end

        ---Returns the chance for one equipment roll and at least one equipment
        ---drop across the boss's configured difficulty rolls.
        function thistype:getBossEquipmentChance(boss, multiplier)
            local base = (Rates[boss.id] or 0) +
                             (boss.first_drop and 25 or 0)
            local per_roll = clamp_chance(base * math.max(0., multiplier or 1.) *
                                              0.01)
            local rolls = math.max(1, math.floor(boss.difficulty or 1))
            return per_roll, 1. - (1. - per_roll) ^ rolls
        end

        ---Rolls an explicit ticket chance. Callers define eligibility by invoking
        ---this only from permanent overworld creep and boss reward pathways.
        ---@param x number
        ---@param y number
        ---@param chance number
        ---@return boolean
        function thistype:rollColosseumTicket(x, y, chance)
            if math.random() < chance then
                ItemRuntime.create(COLOSSEUM_TICKET, x, y, 600.)
                return true
            end
            return false
        end

        -- Pre-chaos flasks are uncommon permanent progression drops rather
        -- than another entry in equipment pools. Enemy level selects the
        -- current 50/110/170 band, while the independent chance suits overworld
        -- pack clearing without a pity counter. Elites provide a noticeably
        -- better opportunity. Chaos affix donors and two-slot bases are kept
        -- out of ordinary enemy tables and awarded by bosses instead.
        local function roll_prechaos_flask(level, x, y, elite, multiplier)
            if level < 50 or level >= 200 then return false end
            local chance = elite and PRECHAOS_ELITE_FLASK_CHANCE or
                               PRECHAOS_FLASK_CHANCE
            if math.random() >= chance * multiplier then return false end

            local key = PotionService.getPrechaosDropKey(level)
            if not key then return false end
            return PotionService.create(key, x, y, 600.) ~= nil
        end

        thistype:registerBossDropSource({
            key = "equipment",
            describe = function(boss, multiplier)
                local distribution, count =
                    thistype:getItemDistribution(boss.id)
                local per_roll =
                    thistype:getBossEquipmentChance(boss, multiplier)
                local rolls = math.max(1, math.floor(boss.difficulty or 1))
                local entries = {}
                for index = 1, count do
                    local share = distribution[index] or 0.
                    entries[index] = {
                        key = "equipment_" .. index,
                        item_id = ItemDrops[boss.id][index],
                        chance = 1. - (1. - per_roll * share) ^ rolls,
                        pool_share = share,
                    }
                end
                return entries
            end,
            roll = function(boss, x, y, multiplier)
                local per_roll =
                    thistype:getBossEquipmentChance(boss, multiplier)
                local rolls = math.max(1, math.floor(boss.difficulty or 1))
                for _ = 1, rolls do
                    if GetRandomReal(0., 1.) < per_roll then
                        local item = ItemRuntime.create(
                                         thistype:pickItem(boss.id), x, y, 600.)
                        if item then
                            item:lvl(math.max(0,
                                ItemData[item.id][ITEM_UPGRADE_MAX] -
                                    math.random(ITEM_MIN_LEVEL_VARIANCE,
                                                ITEM_MAX_LEVEL_VARIANCE)))
                        end
                    end
                end
                boss.first_drop = false
            end,
        })

        thistype:registerBossDropSource({
            key = "colosseum_ticket",
            describe = function(_boss, multiplier)
                return {{
                    key = "colosseum_ticket",
                    item_id = COLOSSEUM_TICKET,
                    chance = 0.05 * multiplier,
                }}
            end,
            roll = function(_boss, x, y, multiplier)
                thistype:rollColosseumTicket(x, y, 0.05 * multiplier)
            end,
        })

        thistype:registerBossDropSource({
            key = "chaos_affix_donor",
            available = function() return CHAOS_MODE end,
            describe = function(boss, multiplier)
                local donor = PotionService.getChaosBossDropChances(
                                  boss.level, boss.difficulty)
                local name, icon, tooltip =
                    PotionService.getChaosDonorPresentation()
                return {{
                    key = "chaos_affix_donor",
                    name = name,
                    icon = icon,
                    tooltip = tooltip,
                    chance = donor * multiplier,
                }}
            end,
            roll = function(boss, x, y, multiplier)
                local donor = PotionService.getChaosBossDropChances(
                                  boss.level, boss.difficulty)
                if GetRandomReal(0., 1.) < donor * multiplier then
                    PotionService.createChaosDonor(x, y, 600.)
                end
            end,
        })

        thistype:registerBossDropSource({
            key = "legendary_chaos_flask",
            available = function() return CHAOS_MODE end,
            describe = function(boss, multiplier)
                local _, legendary = PotionService.getChaosBossDropChances(
                                          boss.level, boss.difficulty)
                local name, icon, tooltip =
                    PotionService.getLegendaryChaosPresentation()
                return {{
                    key = "legendary_chaos_flask",
                    name = name,
                    icon = icon,
                    tooltip = tooltip,
                    chance = legendary * multiplier,
                }}
            end,
            roll = function(boss, x, y, multiplier)
                local _, legendary = PotionService.getChaosBossDropChances(
                                          boss.level, boss.difficulty)
                if GetRandomReal(0., 1.) < legendary * multiplier then
                    PotionService.create(PotionService.LEGENDARY_CHAOS_KEY,
                                         x, y, 600.)
                end
            end,
        })

        thistype:registerBossDropSource({
            key = "chaos_flask",
            available = function() return CHAOS_MODE end,
            describe = function(boss, multiplier)
                local _, _, chance = PotionService.getChaosBossDropChances(
                                         boss.level, boss.difficulty)
                if chance <= 0. then return {} end
                local name, icon, tooltip =
                    PotionService.getChaosFlaskPresentation()
                return {{
                    key = "chaos_flask",
                    name = name,
                    icon = icon,
                    tooltip = tooltip,
                    chance = chance * multiplier,
                }}
            end,
            roll = function(boss, x, y, multiplier)
                local _, _, chance = PotionService.getChaosBossDropChances(
                                         boss.level, boss.difficulty)
                if GetRandomReal(0., 1.) < chance * multiplier then
                    PotionService.create(PotionService.CHAOS_FLASK_KEY,
                                         x, y, 600.)
                end
            end,
        })

        ---@type fun(id: integer, ...)
        local function setup_rates(id, ...)
            local t = table.pack(...)
            local rate = 1. / t.n
            ItemDrops[id][MAX_ITEM_COUNT] = t.n

            for i, v in ipairs(t) do
                ItemDrops[id][i] = FourCC(v)
                ItemDrops[id][i .. "%"] = rate
            end
        end

        local function killer_drop_rate(killer)
            if not killer then return 1. end
            local pid = GetPlayerId(GetOwningPlayer(killer)) + 1
            local hero = pid <= PLAYER_CAP and Hero[pid] or nil
            return hero and math.max(0., Unit[hero].drop_rate) or 1.
        end

        function RewardItem(killed, killer)
            local uid = GetType(killed)
            local rand = math.random(0, 99)
            local x, y = GetUnitX(killed), GetUnitY(killed)
            local lvl = GetUnitLevel(killed)
            local drop_rate = killer_drop_rate(killer)
            if rand < Rates[uid] * drop_rate then
                ItemRuntime.create(thistype:pickItem(uid), x, y, 600.)
            end

            -- iron golem ore
            -- chaotic ore

            rand = math.random(0, 99)
            if lvl > 45 and lvl < 85 and rand < (0.05 * lvl) * drop_rate then
                ItemRuntime.create(FourCC('I02Q'), x, y, 600.)
            elseif lvl > 265 and lvl < 305 and
                rand < (0.02 * lvl) * drop_rate then
                ItemRuntime.create(FourCC('I04Z'), x, y, 600.)
            end

            local ticket_chance = IsUnitType(killed, UNIT_TYPE_HERO) and
                                      COLOSSEUM_ELITE_TICKET_CHANCE or
                                      COLOSSEUM_TICKET_CHANCE
            thistype:rollColosseumTicket(x, y, ticket_chance * drop_rate)
            roll_prechaos_flask(lvl, x, y,
                                IsUnitType(killed, UNIT_TYPE_HERO), drop_rate)
        end

        local id = 69 -- destructables
        setup_rates(id, 'I00O', 'I00Q', 'I00R', 'I01C', 'I01F', 'I01G', 'I01H',
                    'I01I', 'I01K', 'I01V', 'I021', 'I02R', 'I02T', 'I04O',
                    'I01X', 'I06F', 'I06G', 'I090', 'I01Z', 'I0FJ')

        id = FourCC('n0tb') -- troll
        Rates[id] = 40
        -- claws of lightning, iron broadsword, iron sword, iron dagger, chipped shield, short bow, wooden staff, iron shield, belt of the giant, boots of the ranger, sigil of magic
        -- gauntlets of strength, slippers of agility, seven league boots, leather jacket, sword of revival, medallion of courage, medallion of vitality, ring of regeneration
        -- crystal ball, talisman of evasion, sparky orb, tattered cloth
        setup_rates(id, 'I01Z', 'I01F', 'I01I', 'I01G', 'I0FJ', 'I02H', 'I04O',
                    'I01H', 'I00Q', 'I00R', 'I02R', 'I01C', 'I02T', 'I01S',
                    'I01K', 'I01X', 'I01V', 'I021', 'I02D', 'I06F', 'I06G',
                    'I090', 'I04D')

        id = FourCC('n0ts') -- tuskarr
        Rates[id] = 40
        setup_rates(id, 'I01Z', 'I01X', 'I01V', 'I021', 'I02D', 'I06F', 'I06G',
                    'I090', 'I01S', 'I04D', 'I03A', 'I03W', 'I00O', 'I03S',
                    'I01L', 'I03K', 'I08Y', 'I03Q')

        id = FourCC('n0ss') -- spider
        Rates[id] = 35
        setup_rates(id, 'I03A', 'I03W', 'I00O', 'I03K', 'I01L', 'I03S', 'I08Y',
                    'I03Q', 'I0FK', 'I00F', 'I010', 'I00N', 'I0FM', 'I0FL',
                    'I025')

        id = FourCC('n0uw') -- ursa
        Rates[id] = 30
        setup_rates(id, 'I028', 'I025', 'I02L', 'I06T', 'I034', 'I0FG', 'I06R',
                    'I0FT')

        id = FourCC('n0dm') -- dire mammoth
        Rates[id] = 30
        setup_rates(id, 'I035', 'I0FO', 'I07O', 'I0FQ')

        id = FourCC('n01G') -- ogre tauren
        Rates[id] = 25
        setup_rates(id, 'I02L', 'I08I', 'I0FE', 'I07W', 'I08B', 'I0FD', 'I08R',
                    'I08E', 'I08F', 'I07Y', 'I00B')

        id = FourCC('n0ud') -- unbroken
        Rates[id] = 25
        setup_rates(id, 'I0FS', 'I0FR', 'I0FY', 'I01W', 'I0MB')

        id = FourCC('n0hs') -- hellfire hellhound
        Rates[id] = 25
        setup_rates(id, 'I00Z', 'I00S', 'I011', 'I02E', 'I023', 'I0MA')

        id = FourCC('n024') -- centaur
        Rates[id] = 25
        setup_rates(id, 'I06J', 'I06I', 'I06L', 'I06K', 'I07H')

        id = FourCC('n01M') -- magnataur forgotten one
        Rates[id] = 20
        setup_rates(id, 'I01Q', 'I01N', 'I015', 'I019')

        id = FourCC('n02P') -- frost dragon frost drake
        Rates[id] = 20
        setup_rates(id, 'I056', 'I04X', 'I05Z')

        id = FourCC('n099') -- frost elder dragon
        Rates[id] = 40
        setup_rates(id, 'I056', 'I04X', 'I05Z')

        id = FourCC('n02L') -- devourers
        Rates[id] = 20
        setup_rates(id, 'I02W', 'I00W', 'I017', 'I013', 'I02I', 'I01P', 'I006',
                    'I02V', 'I009')

        id = FourCC('n01H') -- ancient hydra
        Rates[id] = 25
        setup_rates(id, 'I07N', 'I044')

        id = FourCC('n034') -- demons
        Rates[id] = 20
        setup_rates(id, 'I073', 'I075', 'I06Z', 'I06W', 'I04T', 'I06S', 'I06U',
                    'I06O', 'I06Q')

        id = FourCC('n03A') -- horror
        Rates[id] = 20
        setup_rates(id, 'I07K', 'I05D', 'I07E', 'I07I', 'I07G', 'I07C', 'I07A',
                    'I07M', 'I07L', 'I07P', 'I077')

        id = FourCC('n03F') -- despair
        Rates[id] = 20
        setup_rates(id, 'I05P', 'I087', 'I089', 'I083', 'I081', 'I07X', 'I07V',
                    'I07Z', 'I07R', 'I07T', 'I05O')

        id = FourCC('n08N') -- abyssal
        Rates[id] = 20
        setup_rates(id, 'I06C', 'I06B', 'I0A0', 'I0A2', 'I09X', 'I0A5', 'I09N',
                    'I06D', 'I06A')

        id = FourCC('n031') -- void
        Rates[id] = 20
        setup_rates(id, 'I04Y', 'I08C', 'I08D', 'I08G', 'I08H', 'I08J', 'I055',
                    'I08M', 'I08N', 'I08O', 'I08S', 'I08U', 'I04W')

        id = FourCC('n020') -- nightmare
        Rates[id] = 20
        setup_rates(id, 'I09S', 'I0AB', 'I09R', 'I0A9', 'I09V', 'I0AC', 'I0A7',
                    'I09T', 'I09P', 'I04Z')

        id = FourCC('n03D') -- hell
        Rates[id] = 20
        setup_rates(id, 'I097', 'I05H', 'I098', 'I095', 'I08W', 'I05G', 'I08Z',
                    'I091', 'I093', 'I05I')

        id = FourCC('n03J') -- existence
        Rates[id] = 20
        setup_rates(id, 'I09Y', 'I09U', 'I09W', 'I09Q', 'I09O', 'I09M', 'I09K',
                    'I09I', 'I09G', 'I09E')

        id = FourCC('n03M') -- astral
        Rates[id] = 20
        setup_rates(id, 'I0AL', 'I0AN', 'I0AA', 'I0A8', 'I0A6', 'I0A3', 'I0A1',
                    'I0A4', 'I09Z')

        id = FourCC('n026') -- plainswalker
        Rates[id] = 20
        setup_rates(id, 'I0AY', 'I0B0', 'I0B2', 'I0B3', 'I0AQ', 'I0AO', 'I0AT',
                    'I0AR', 'I0AW')

        id = FourCC('n02U') -- nerubian
        Rates[id] = 100
        setup_rates(id, 'I01E')

        id = FourCC('n0pb') -- giant polar bear
        Rates[id] = 100
        setup_rates(id, 'I04A')

        id = FourCC('n03L') -- king of ogres
        Rates[id] = 100
        setup_rates(id, 'I02M')

        id = FourCC('n02H') -- yeti
        Rates[id] = 100
        setup_rates(id, 'I05R')

        id = FourCC('H02H') -- paladin
        Rates[id] = 80
        setup_rates(id, 'I0F9', 'I03P', 'I0C0', 'I0FX')

        id = FourCC('O002') -- minotaur
        Rates[id] = 70
        setup_rates(id, 'I03T', 'I0FW', 'I07U', 'I076', 'I078')

        id = FourCC('H020') -- lady vashj
        Rates[id] = 70
        setup_rates(id, 'I09F', 'I09L')

        id = FourCC('H01V') -- dwarven
        Rates[id] = 70
        setup_rates(id, 'I079', 'I07B', 'I0FC')

        id = FourCC('H040') -- death knight
        Rates[id] = 80
        setup_rates(id, 'I02O', 'I029', 'I02C', 'I02B')

        id = FourCC('U00G') -- tri fire
        Rates[id] = 70
        setup_rates(id, 'I0FA', 'I0FU', 'I00V', 'I03Y')

        id = FourCC('H045') -- mystic
        Rates[id] = 70
        setup_rates(id, 'I03U', 'I0F3', 'I07F')

        id = FourCC('O01B') -- dragoon
        Rates[id] = 70
        setup_rates(id, 'I0EX', 'I0EY', 'I074', 'I04N')

        id = FourCC('E00B') -- goddess of hate
        Rates[id] = 100
        setup_rates(id, 'I02Z')

        id = FourCC('E00D') -- goddess of love
        Rates[id] = 100
        setup_rates(id, 'I030')

        id = FourCC('E00C') -- goddess of knowledge
        Rates[id] = 100
        setup_rates(id, 'I031')

        id = FourCC('H04Q') -- goddess of life
        Rates[id] = 100
        setup_rates(id, 'I04I')

        id = FourCC('H00O') -- arkaden
        Rates[id] = 80
        setup_rates(id, 'I02O', 'I02C', 'I02B', 'I036')

        id = FourCC('N038') -- demon prince
        Rates[id] = 100
        setup_rates(id, 'I04Q')

        id = FourCC('N017') -- absolute horror
        Rates[id] = 85
        setup_rates(id, 'I0N7', 'I0N8', 'I0N9')

        id = FourCC('O02B') -- slaughter
        Rates[id] = 85
        setup_rates(id, 'I0AE', 'I04F', 'I0AF', 'I0AD', 'I0AG')

        id = FourCC('O02H') -- dark soul
        Rates[id] = 70
        setup_rates(id, 'I05A', 'I0AH', 'I0AP', 'I0AI')

        id = FourCC('O02I') -- satan
        Rates[id] = 65
        setup_rates(id, 'I0BX', 'I05J')

        id = FourCC('O02K') -- thanatos
        Rates[id] = 65
        setup_rates(id, 'I04E', 'I0MR')

        id = FourCC('H04R') -- legion
        Rates[id] = 60
        setup_rates(id, 'I0B5', 'I0B7', 'I0B1', 'I0AU', 'I04L', 'I0AJ', 'I0AZ',
                    'I0AS', 'I0AV', 'I0AX')

        id = FourCC('O02M') -- existence
        Rates[id] = 60
        setup_rates(id, 'I018', 'I0BY')

        id = FourCC('O03G') -- xallarath
        Rates[id] = 30
        setup_rates(id, 'I0OB', 'I0O1', 'I0CH')

        id = FourCC('O02T') -- azazoth
        Rates[id] = 60
        setup_rates(id, 'I0BS', 'I0BV', 'I0BK', 'I0BI', 'I0BB', 'I0BC', 'I0BE',
                    'I0B9', 'I0BG', 'I06M')
    end
end, Debug and Debug.getLine())
