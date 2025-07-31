--[[
    droptable.lua

    Defines item drop tables for units, adjusts rates to equalize drop chances
]]
OnInit.final("DropTable", function()
    ItemDrops = array2d(0)
    Rates     = __jarray(0)

    ---@class DropTable
    ---@field pickItem function
    DropTable = {}
    do
        local thistype = DropTable
        local MAX_ITEM_COUNT = 100
        local ADJUST_RATE = 0.05

        -- adjusts the drop rates of all items in a pool after a drop
        ---@type fun(id: integer, i: integer)
        local function adjust_rate(id, index)
            local drop = ItemDrops[id]
            local max = drop[MAX_ITEM_COUNT]

            if max <= 1 then
                return
            end

            local adjust = 1. / max * ADJUST_RATE
            local balance = adjust / (max - 1.)

            for i = 1, max do
                if drop[i] == drop[index] then
                    drop[i .. "\x25"] = drop[i .. "\x25"] - adjust
                else
                    drop[i .. "\x25"] = drop[i .. "\x25"] + balance
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
                if GetRandomReal(0., 1.) < drop[i .. "\x25"] then
                    adjust_rate(id, i)
                    break
                end

                if i > max then
                    i = 1
                else
                    i = i + 1
                end
            end

            return ItemDrops[id][i]
        end

        ---@type fun(id: integer, ...)
        local function setup_rates(id, ...)
            local t = table.pack(...)
            local rate = 1. / t.n
            ItemDrops[id][MAX_ITEM_COUNT] = t.n

            for i, v in ipairs(t) do
                ItemDrops[id][i] = FourCC(v)
                ItemDrops[id][i .. "\x25"] = rate
            end
        end

        function RewardItem(killed)
            local uid = GetType(killed)
            local rand = math.random(0, 99)
            local x, y = GetUnitX(killed), GetUnitY(killed)
            local lvl = GetUnitLevel(killed)
            if rand < Rates[uid] then
                CreateItem(thistype:pickItem(uid), x, y, 600.)
            end

            -- iron golem ore
            -- chaotic ore

            rand = math.random(0, 99)
            if lvl > 45 and lvl < 85 and rand < (0.05 * lvl) then
                CreateItem(FourCC('I02Q'), x, y, 600.)
            elseif lvl > 265 and lvl < 305 and rand < (0.02 * lvl) then
                CreateItem(FourCC('I04Z'), x, y, 600.)
            end

            -- colosseum ticket (1%)
            rand = math.random()
            if rand < 0.01 then
                CreateItem(FourCC('I008'), x, y, 600.)
            end
        end

        local id = 69 -- destructables
        setup_rates(id, 'I00O','I00Q','I00R','I01C','I01F','I01G','I01H','I01I','I01K','I01V','I021','I02R','I02T','I04O','I01X','I06F','I06G','I090','I01Z','I0FJ')

        id = FourCC('n0tb') --troll
        Rates[id] = 40
        --claws of lightning, iron broadsword, iron sword, iron dagger, chipped shield, short bow, wooden staff, iron shield, belt of the giant, boots of the ranger, sigil of magic
        --gauntlets of strength, slippers of agility, seven league boots, leather jacket, sword of revival, medallion of courage, medallion of vitality, ring of regeneration
        --crystal ball, talisman of evasion, sparky orb, tattered cloth
        setup_rates(id, 'I01Z','I01F','I01I','I01G','I0FJ','I02H','I04O','I01H','I00Q','I00R','I02R','I01C','I02T','I01S','I01K','I01X','I01V','I021','I02D','I06F','I06G','I090','I04D')

        id = FourCC('n0ts') --tuskarr
        Rates[id] = 40
        setup_rates(id, 'I01Z','I01X','I01V','I021','I02D','I06F','I06G','I090','I01S','I04D','I03A','I03W','I00O','I03S','I01L','I03K','I08Y','I03Q')

        id = FourCC('n0ss') --spider
        Rates[id] = 35
        setup_rates(id, 'I03A','I03W','I00O','I03K','I01L','I03S','I08Y','I03Q','I0FK','I00F','I010','I00N','I0FM','I0FL','I025')

        id = FourCC('n0uw') --ursa
        Rates[id] = 30
        setup_rates(id, 'I028','I025','I02L','I06T','I034','I0FG','I06R','I0FT')

        id = FourCC('n0dm') --dire mammoth
        Rates[id] = 30
        setup_rates(id, 'I035','I0FO','I07O','I0FQ')

        id = FourCC('n01G') -- ogre tauren
        Rates[id] = 25
        setup_rates(id, 'I02L','I08I','I0FE','I07W','I08B','I0FD','I08R','I08E','I08F','I07Y','I00B')

        id = FourCC('n0ud') --unbroken
        Rates[id] = 25
        setup_rates(id, 'I0FS','I0FR','I0FY','I01W','I0MB')

        id = FourCC('n0hs') -- hellfire hellhound
        Rates[id] = 25
        setup_rates(id, 'I00Z','I00S','I011','I02E','I023','I0MA')

        id = FourCC('n024') -- centaur
        Rates[id] = 25
        setup_rates(id, 'I06J','I06I','I06L','I06K','I07H')

        id = FourCC('n01M') -- magnataur forgotten one
        Rates[id] = 20
        setup_rates(id, 'I01Q','I01N','I015','I019')

        id = FourCC('n02P') -- frost dragon frost drake
        Rates[id] = 20
        setup_rates(id, 'I056','I04X','I05Z')

        id = FourCC('n099') -- frost elder dragon
        Rates[id] = 40
        setup_rates(id, 'I056','I04X','I05Z')

        id = FourCC('n02L') -- devourers
        Rates[id] = 20
        setup_rates(id, 'I02W','I00W','I017','I013','I02I','I01P','I006','I02V','I009')

        id = FourCC('n01H') -- ancient hydra
        Rates[id] = 25
        setup_rates(id, 'I07N','I044')

        id = FourCC('n034') --demons
        Rates[id] = 20
        setup_rates(id, 'I073','I075','I06Z','I06W','I04T','I06S','I06U','I06O','I06Q')

        id = FourCC('n03A') --horror
        Rates[id] = 20
        setup_rates(id, 'I07K','I05D','I07E','I07I','I07G','I07C','I07A','I07M','I07L','I07P','I077')

        id = FourCC('n03F') --despair
        Rates[id] = 20
        setup_rates(id, 'I05P','I087','I089','I083','I081','I07X','I07V','I07Z','I07R','I07T','I05O')

        id = FourCC('n08N') --abyssal
        Rates[id] = 20
        setup_rates(id, 'I06C','I06B','I0A0','I0A2','I09X','I0A5','I09N','I06D','I06A')

        id = FourCC('n031') --void
        Rates[id] = 20
        setup_rates(id, 'I04Y','I08C','I08D','I08G','I08H','I08J','I055','I08M','I08N','I08O','I08S','I08U','I04W')

        id = FourCC('n020') --nightmare
        Rates[id] = 20
        setup_rates(id, 'I09S','I0AB','I09R','I0A9','I09V','I0AC','I0A7','I09T','I09P','I04Z')

        id = FourCC('n03D') --hell
        Rates[id] = 20
        setup_rates(id, 'I097','I05H','I098','I095','I08W','I05G','I08Z','I091','I093','I05I')

        id = FourCC('n03J') --existence
        Rates[id] = 20
        setup_rates(id, 'I09Y','I09U','I09W','I09Q','I09O','I09M','I09K','I09I','I09G','I09E')

        id = FourCC('n03M') --astral
        Rates[id] = 20
        setup_rates(id, 'I0AL','I0AN','I0AA','I0A8','I0A6','I0A3','I0A1','I0A4','I09Z')

        id = FourCC('n026') --plainswalker
        Rates[id] = 20
        setup_rates(id, 'I0AY','I0B0','I0B2','I0B3','I0AQ','I0AO','I0AT','I0AR','I0AW')

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
        setup_rates(id, 'I0F9','I03P','I0C0','I0FX')

        id = FourCC('O002') -- minotaur
        Rates[id] = 70
        setup_rates(id, 'I03T','I0FW','I07U','I076','I078')

        id = FourCC('H020') -- lady vashj
        Rates[id] = 70
        setup_rates(id, 'I09F','I09L')

        id = FourCC('H01V') -- dwarven
        Rates[id] = 70
        setup_rates(id, 'I079','I07B','I0FC')

        id = FourCC('H040') -- death knight
        Rates[id] = 80
        setup_rates(id, 'I02O','I029','I02C','I02B')

        id = FourCC('U00G') -- tri fire
        Rates[id] = 70
        setup_rates(id, 'I0FA','I0FU','I00V','I03Y')

        id = FourCC('H045') -- mystic
        Rates[id] = 70
        setup_rates(id, 'I03U','I0F3','I07F')

        id = FourCC('O01B') -- dragoon
        Rates[id] = 70
        setup_rates(id, 'I0EX','I0EY','I074','I04N')

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
        setup_rates(id, 'I02O','I02C','I02B','I036')

        id = FourCC('N038') -- demon prince
        Rates[id] = 100
        setup_rates(id, 'I04Q')

        id = FourCC('N017') -- absolute horror
        Rates[id] = 85
        setup_rates(id, 'I0N7','I0N8','I0N9')

        id = FourCC('O02B') -- slaughter
        Rates[id] = 85
        setup_rates(id, 'I0AE','I04F','I0AF','I0AD','I0AG')

        id = FourCC('O02H') -- dark soul
        Rates[id] = 70
        setup_rates(id, 'I05A','I0AH','I0AP','I0AI')

        id = FourCC('O02I') -- satan
        Rates[id] = 65
        setup_rates(id, 'I0BX','I05J')

        id = FourCC('O02K') -- thanatos
        Rates[id] = 65
        setup_rates(id, 'I04E','I0MR')

        id = FourCC('H04R') -- legion
        Rates[id] = 60
        setup_rates(id, 'I0B5','I0B7','I0B1','I0AU','I04L','I0AJ','I0AZ','I0AS','I0AV','I0AX')

        id = FourCC('O02M') -- existence
        Rates[id] = 60
        setup_rates(id, 'I018','I0BY')

        id = FourCC('O03G') -- xallarath
        Rates[id] = 30
        setup_rates(id, 'I0OB','I0O1','I0CH')

        id = FourCC('O02T') -- azazoth
        Rates[id] = 60
        setup_rates(id, 'I0BS','I0BV','I0BK','I0BI','I0BB','I0BC','I0BE','I0B9','I0BG','I06M')
    end
end, Debug and Debug.getLine())
