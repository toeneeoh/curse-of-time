OnInit.final("Colosseum", function(Require)
    Require('ItemLookup')

    local ticket_id = 'I008'
    local unit_id = FourCC('n002')
    local boss_id = FourCC('N003')
    local colo_x = 21746
    local colo_y = -4347
    local random = math.random
    local FPS_32 = FPS_32
    local colo_spawn = {}
    colo_spawn[1] = GetRectCenter(gg_rct_Colosseum_Monster_Spawn)
    colo_spawn[2] = GetRectCenter(gg_rct_Colosseum_Monster_Spawn_2)
    colo_spawn[3] = GetRectCenter(gg_rct_Colosseum_Monster_Spawn_3)
    local Encounter, Augment

    local melee_skins = {
        "uske",
        "ugho",
        "nmpe",
        "nban",
        "nsty",
        "nwlt",
    }
    local ranged_skins = {
        "nska",
    }
    local elite_skins = {
        "e000",
        "Nplh",
        "Nfir",
        "Nbst",
        "Nalc",
        "Npbm",
        "Edem",
    }

    local bosses
    local players = {}
    local wave = 1
    local unit_count = 0
    local is_entry_open = false
    local colo_active = false
    local start_timer

    -- formula data
    local total_level = 0
    local average_level = 0
    local max_level = 0
    local player_mult = 0
    local num_spawned = 0
    local gold_earned = 0
    local advance_wave, end_colosseum

    -- constants
    local MAX_WAVES = 20
    local BASE_DAMAGE = 5
    local BASE_HP = 50
    local BASE_ARMOR = 0.75
    local GOLD_DROP_CHANCE = 10

    local BOSS_HP = 500
    local BOSS_DAMAGE = 50
    local BOSS_ARMOR = 2

    -- unit stats
    local stat_hp = 0
    local stat_dmg = 0
    local stat_armor = 0

    function InColosseum(pid)
        return TableHas(players, pid)
    end

    local animate, coin_effect

    do
        local GRAVITY = 900
        local HORIZ_SPEED_MIN = 120
        local HORIZ_SPEED_MAX = 180
        local LIFETIME = 1.5
        local MODEL = "Objects\\InventoryItems\\PotofGold\\PotofGold.mdl"
        animate = function(sfx, time, angle, speed, zVel, x, y, z)
            time = time - FPS_32
            if time <= 0 then
                DestroyEffect(sfx)
                return
            end

            -- horizontal drift
            x = x + math.cos(angle) * speed * FPS_32
            y = y + math.sin(angle) * speed * FPS_32

            -- vertical arc under gravity
            zVel = zVel - GRAVITY * FPS_32
            z    = z + zVel * FPS_32

            BlzSetSpecialEffectX(sfx, x)
            BlzSetSpecialEffectY(sfx, y)
            BlzSetSpecialEffectZ(sfx, z)

            TimerQueue:callDelayed(FPS_32, animate, sfx, time, angle, speed, zVel, x, y, z)
        end

        coin_effect = function(u, num_coins)
            local x = GetUnitX(u)
            local y = GetUnitY(u)
            local z = BlzGetUnitZ(u)
            num_coins = num_coins or random(3, 4)

            for _ = 1, num_coins do
                local sfx   = AddSpecialEffect(MODEL, x, y)
                local angle = GetRandomReal(0, 2 * bj_PI)
                local speed = GetRandomReal(HORIZ_SPEED_MIN, HORIZ_SPEED_MAX)
                local zVel  = GRAVITY * (LIFETIME / 2)

                BlzPlaySpecialEffect(sfx, ANIM_TYPE_STAND)
                BlzSetSpecialEffectZ(sfx, z)
                BlzSetSpecialEffectScale(sfx, 1.5)
                TimerQueue:callDelayed(FPS_32, animate, sfx, LIFETIME, angle, speed, zVel, x, y, z)
            end
        end
    end

    local on_kill = function(killed)
        unit_count = unit_count - 1
        if random() * 100 < GOLD_DROP_CHANCE + (5 / num_spawned) * 18 then
            SoundHandler("Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac", true, nil, killed)
            gold_earned = gold_earned + 1
            coin_effect(killed)
        end

        if unit_count <= 0 then
            wave = wave + 1
            Encounter.call(wave, "pause")

            TimerFrame.create("Wave " .. wave .. " beginning in:", 15, advance_wave, players)
        end
    end

    local on_boss_kill = function(killed)
        gold_earned = gold_earned + 5
        coin_effect(killed, 10)

        wave = wave + 1
        Encounter.call(wave, "pause")

        if wave <= MAX_WAVES then
            Augment.display()
        else
            end_colosseum()
        end
    end

    local setup_unit = function(u, spawn, skin, dmg, hp, armor)
        SetUnitXBounded(u, GetLocationX(colo_spawn[spawn]))
        SetUnitYBounded(u, GetLocationY(colo_spawn[spawn]))

        BlzSetUnitName(u, GetObjectName(FourCC(skin)))
        BlzSetHeroProperName(u, GetObjectName(FourCC(skin)))

        -- setup stats
        BlzSetUnitBaseDamage(u, dmg, 0)
        BlzSetUnitMaxHP(u, hp)
        BlzSetUnitArmor(u, armor)
        SetWidgetLife(u, BlzGetUnitMaxHP(u))

        -- attack random player
        local p = random(1, #players)
        IssueTargetOrder(u, "smart", Hero[players[p]])

        -- apply any encounter effects
        Encounter.call(wave, "spawn", u)
    end

    local spawn_boss = function()
        local skin = bosses[wave // 5]
        local u = BlzCreateUnitWithSkin(PLAYER_BOSS, boss_id, colo_x, colo_y, 270., FourCC(skin))
        local spawn = 2
        local wave_mult = (0.95 + wave * 0.05)
        local dmg = R2I(stat_dmg + total_level * BOSS_DAMAGE * wave_mult * player_mult)
        local hp = R2I(stat_hp + total_level * BOSS_HP * wave_mult * player_mult)
        local armor = stat_armor + total_level * BOSS_ARMOR * wave_mult * player_mult

        setup_unit(u, spawn, skin, dmg, hp, armor)

        EVENT_ON_UNIT_DEATH:register_unit_action(u, on_boss_kill)
    end

    local spawn_units = function()
        num_spawned = random(2, 10)
        unit_count = num_spawned
        local num_mult = 10 / num_spawned
        local wave_mult = (0.95 + wave * 0.05)
        local skin = melee_skins[random(1, #melee_skins)]

        for _ = 1, num_spawned do
            local spawn = random(1, 3)
            local u = BlzCreateUnitWithSkin(PLAYER_BOSS, unit_id, colo_x, colo_y, 270., FourCC(skin))
            local dmg = R2I(stat_dmg + total_level * BASE_DAMAGE * wave_mult * player_mult * num_mult)
            local hp = R2I(stat_hp + total_level * BASE_HP * wave_mult * player_mult * num_mult)
            local armor = stat_armor + total_level * BASE_ARMOR * wave_mult * player_mult

            setup_unit(u, spawn, skin, dmg, hp, armor)

            Unit[u].ms_percent = Unit[u].ms_percent + 0.05 * wave

            EVENT_ON_UNIT_DEATH:register_unit_action(u, on_kill)
        end
    end

    advance_wave = function()
        if math.fmod(wave, 5) == 0 then
            spawn_boss()
        else
            spawn_units()
        end
        Encounter.call(wave, "resume")
    end

    local begin_colosseum = function()
        average_level = total_level / #players
        player_mult = 1 + .5 * (#players - 1)
        colo_active = true
        is_entry_open = false
        SoundHandler("Sound\\Interface\\BattleNetDoorsStereo2.flac", false)
        TimerFrame.create("Wave " .. wave .. " beginning in:", 15, advance_wave, players)
        Augment.pickAugments()
        Encounter.pickEncounters()
        bosses = pickN(4, elite_skins)
    end

    -- reward gold to player at whatever current value is
    local colo_reward = function(pid)
    end

    local colo_cleanup = function(pid)
        colo_reward(pid)
        TableRemove(players, pid)
    end

    -- cleanup
    local colo_on_death = function(killed)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1

        RevivePlayer(pid, GetLocationX(TOWN_CENTER), GetLocationY(TOWN_CENTER), 1, 1)
        colo_cleanup(pid)
    end

    local enter_colosseum = function(pid)
        players[#players + 1] = pid

        -- adjust difficulty
        total_level = total_level + GetUnitLevel(Hero[pid])
        max_level = (GetUnitLevel(Hero[pid]) > max_level and max_level) or max_level
        stat_hp = stat_hp + Unit[Hero[pid]].str + Unit[Hero[pid]].agi + Unit[Hero[pid]].int
        stat_armor = stat_armor + (Unit[Hero[pid]].agi + Unit[Hero[pid]].int) * 0.1
        stat_dmg = stat_dmg + Unit[Hero[pid]].str + Unit[Hero[pid]].agi

        DisableItems(pid, true)
        MoveHero(pid, colo_x, colo_y)

        -- skip 60 second wait if all players join
        if #players >= User.AmountPlaying then
            TimerQueue:disableCallback(start_timer)
            begin_colosseum()
        end

        EVENT_ON_CLEANUP:register_action(pid, colo_cleanup)
        EVENT_GRAVE_DEATH:register_unit_action(Hero[pid], colo_on_death)
    end

    end_colosseum = function()
        colo_active = false
        wave = 1
        total_level = 0
        stat_hp = 0
        stat_armor = 0
        stat_damage = 0

        while #players > 0 do
            local pid = players[i]
            MoveHeroLoc(pid, TOWN_CENTER)
            DisableItems(pid, false)
            colo_reward(pid)
            print("removed player")

            players[i] = players[#players]
            players[#players] = nil
        end
    end

    -- frame setup
    local encounter_frame = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
    BlzFrameSetSize(encounter_frame, 0.001, 0.001)
    BlzFrameSetAbsPoint(encounter_frame, FRAMEPOINT_TOPLEFT, 0.15, 0.55)
    BlzFrameSetEnable(encounter_frame, false)
    BlzFrameSetVisible(encounter_frame, false)

    local encounter_icons = {}
    for i = 1, 3 do
        encounter_icons[i] = SimpleButton.create(encounter_frame, "", 0.025, 0.025, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.12 * i, 0)
        encounter_icons[i]:makeTooltip(nil, 0.25)
        encounter_icons[i]:point(FRAMEPOINT_TOP, FRAMEPOINT_BOTTOM, 0, 0)
    end
    --

    ---@class Encounter
    ---@field create function
    ---@field call function
    ---@field pickEncounters function
    Encounter = {}
    do
        local thistype = Encounter
        local list = {}
        local active

        ---@type fun(n: integer, func: string, ...)
        function thistype.call(n, func, ...)
            for i, v in ipairs(active) do
                -- only execute after appropriate wave count
                if n // (i * 5) > 0 then
                    local f = v[func]
                    if f then
                        f(...)
                    end
                end
            end
        end

        function thistype.pickEncounters()
            active = pickN(3, list)

            -- set icon / tooltip
            for i = 1, 3 do
                encounter_icons[i]:icon(active[i].icon)
                encounter_icons[i]:setTooltipIcon(active[i].icon)
                encounter_icons[i]:setTooltipName(active[i].name)
                encounter_icons[i]:setTooltipText(active[i].desc)
            end

            -- display frame
            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(players, pid) then
                BlzFrameSetVisible(encounter_frame, true)
            end
        end

        ---@return Encounter
        function thistype.create(name, desc, icon)
            local self = {}

            self.name = name
            self.desc = desc
            self.icon = icon

            list[#list + 1] = self

            return self
        end
    end

    local spikes = Encounter.create("Spikes", "Every |cffffcc0010|r seconds, players will be targeted by spikes that will impale them after |cffffcc002|r seconds for |cffffcc00" .. "99" .. "%|r max health magic damage."
    , "ReplaceableTextures\\CommandButtons\\BTNImpale.blp")
    do
        local callback
        local model = "war3mapImported\\indicators (1).mdl"
        local function impale(sfx, x, y)
            local ug = CreateGroup()
            MakeGroupInRange(BOSS_ID, ug, x, y, 200., Condition(FilterEnemy))
            for player in each(ug) do
                DamageTarget(DUMMY_UNIT, player, BlzGetUnitMaxHP(player) * 0.99, ATTACK_TYPE_NORMAL, MAGIC, "Spikes")
            end
            DestroyEffect(sfx)
            sfx = AddSpecialEffect("Abilities\\Spells\\Undead\\Impale\\ImpaleHitTarget.mdl", x, y)
            BlzSetSpecialEffectScale(sfx, 2.0)
            DestroyEffect(sfx)
        end
        local function spike_wave()
            for _, pid in ipairs(players) do
                local x, y = GetUnitX(Hero[pid]), GetUnitY(Hero[pid])
                local sfx = AddSpecialEffect(model, x, y)
                BlzSetSpecialEffectScale(sfx, 0.4)
                TimerQueue:callDelayed(2., impale, sfx, x, y)
            end
            callback = TimerQueue:callDelayed(10., spike_wave)
        end
        spikes.pause = function()
            TimerQueue:disableCallback(callback)
        end
        spikes.resume = function()
            callback = TimerQueue:callDelayed(10., spike_wave)
        end
    end
    local martyrdom = Encounter.create("Martyrdom", "Enemies explode on death, dealing |cffffcc00" .. "15" .. "%|r max health magic damage to nearby players."
    , "ReplaceableTextures\\CommandButtons\\BTNTemp.blp")
    do

        local function explode(killed)
            local ug = CreateGroup()
            MakeGroupInRange(BOSS_ID, ug, GetUnitX(killed), GetUnitY(killed), 200., Condition(FilterEnemy))
            DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Undead\\UndeadLargeDeathExplode\\UndeadLargeDeathExplode.mdl", killed, "origin"))

            for player in each(ug) do
                DamageTarget(killed, player, BlzGetUnitMaxHP(player) * 0.15, ATTACK_TYPE_NORMAL, MAGIC, "Martyrdom")
            end

            DestroyGroup(ug)
        end
        martyrdom.spawn = function(u)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, explode)
        end
    end
    local earthquake = Encounter.create("Earthquake", "Players have a |cffffcc00" .. "50" .. "%|r movespeed and healing reduction."
    , "ReplaceableTextures\\CommandButtons\\BTNEarthquake.blp")
    do
        earthquake.pause = function()
            for _, v in ipairs(players) do
                EarthquakeDebuff:dispel(nil, Hero[v])
            end
        end
        earthquake.resume = function()
            for _, v in ipairs(players) do
                EarthquakeDebuff:add(Hero[v], Hero[v])
            end
        end
    end

    ---@class Augment
    ---@field display function
    ---@field create function
    ---@field pickAugments function
    Augment = {}
    do
        local thistype = Augment
        local list = {}
        local player_choices = {}

        -- frame setup
        local frame = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetSize(frame, 0.001, 0.001)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, 0.4, 0.53)
        BlzFrameSetEnable(frame, false)
        BlzFrameSetVisible(frame, false)
        --

        function thistype.pickAugments()
            for _, pid in ipairs(players) do
                player_choices[pid] = pickN(9, list)
            end
        end

        function thistype.display()
            local pid = GetPlayerId(GetLocalPlayer()) + 1

            if TableHas(players, pid) then
                BlzFrameSetVisible(encounter_frame, true)
            end
        end

        ---@type fun(name: string, desc: string): Augment
        function thistype.create(name, desc)
            local self = {}

            self.name = name
            self.desc = desc

            return self
        end
    end

    ITEM_LOOKUP[FourCC('I0ER')] = function(p, pid)
        -- if colo is already active
        if colo_active then
            DisplayTextToPlayer(p, 0., 0., "Colosseum is already active!")
            return
        end

        if is_entry_open and not TableHas(players, pid) then
            enter_colosseum(pid)
        else
            -- check for ticket
            local itm = GetItemFromPlayer(pid, ticket_id)
            if itm then
                DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has opened the Colosseum for all players to enter. The gate will close in 60 seconds.")
                is_entry_open = true
                itm:destroy()
                start_timer = TimerQueue:callDelayed(60., begin_colosseum)
                enter_colosseum(pid)
            else
                DisplayTextToPlayer(p, 0, 0, "|cffff0000You do not have a Colosseum ticket!")
            end
        end
    end
end, Debug and Debug.getLine())
