-- Dungeon-specific content; the shared queue/lifecycle lives in gameplay/dungeons/dungeon.lua.
OnInit.final('NagaDungeon', function(Require)
    Require('Dungeons')
    Require('Perks')
    Require('WorldTransitions')

    ---@type fun(tbl: table, x: number, y: number)
    local function dungeon_move_expire(tbl, x, y)
        for _, pid in ipairs(tbl) do
            pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
            MoveHero(pid, x, y)
        end
    end

    ---@type fun(tbl: table, x: number, y:number, delay: number)
    local function dungeon_move(tbl, x, y, delay)
        TimerQueue:callDelayed(delay, dungeon_move_expire, tbl, x, y)
    end

    DUNGEON_NAGA = Dungeon.define('I0JU')
    do
        local thistype = DUNGEON_NAGA
        thistype.level = 400
        thistype.name = "Naga Dungeon"
        thistype.queue_x = -12363.
        thistype.queue_y = -1185.
        thistype.entrance_x = -20000.
        thistype.entrance_y = -4600.
        thistype.exit_x = -250.
        thistype.exit_y = 60.
        thistype.chest = nil

        thistype.playerDeath = function(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            TableRemove(thistype.players, pid)

            if #thistype.players <= 0 then
                thistype:destroy()
            end

            EVENT_GRAVE_DEATH:unregister_unit_action(u, thistype.playerDeath)
        end

        local function onComplete()
            StartSound(bj_questCompletedSound)

            for index = 1, #thistype.players do
                Perks.completeMilestone(thistype.players[index], "naga")
            end

            thistype.chest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h002'), -22141, -10500, 0)
            DisplayTextToTable(thistype.players, "You have vanquished the Ancient Nagas!")
            if thistype.timer then
                thistype.timer:destroy()
                thistype.timer = nil
            end

            thistype:endDungeon()
        end

        ---@type fun(killed: unit)
        local function creepDeath(killed)
            TableRemove(thistype.enemies, killed)

            if #thistype.enemies <= 0 and thistype.floor < 3 then
                thistype.chest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h002'), -23000, -3750, 270)
                MovePlayers(thistype.players, -24000, -4700)
            end
        end

        local create_unit = function(...)
            local u = thistype:createUnit(...)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, creepDeath)
            Unit[u].dr = (1 - #thistype.players * 0.1)
            return u
        end

        local enemy_types = {
            FourCC('n01L'),
            FourCC('n005'),
            FourCC('O006'),
        }

        local function spawn_floor()
            local pcount = #thistype.players

            thistype.floor = thistype.floor + 1
            local type = enemy_types[thistype.floor]

            if thistype.floor == 1 then
                create_unit(type, -20607, -3733, 335)
                create_unit(type, -22973, -2513, 0)
                create_unit(type, -25340, -4218, 45)
                create_unit(type, -24980, -6070, 335)
                create_unit(type, -23087, -6656, 0)
                create_unit(type, -20567, -5402, 45)
            elseif thistype.floor == 2 then
                UnitAddBonus(create_unit(type, -20607, -3733, 335), BONUS_DAMAGE, 200000 * pcount)
                UnitAddBonus(create_unit(type, -22973, -2513, 0), BONUS_DAMAGE, 200000 * pcount)
                UnitAddBonus(create_unit(type, -25340, -4218, 45), BONUS_DAMAGE, 200000 * pcount)
                UnitAddBonus(create_unit(type, -24980, -6070, 335), BONUS_DAMAGE, 200000 * pcount)
                UnitAddBonus(create_unit(type, -23087, -6656, 0), BONUS_DAMAGE, 200000 * pcount)
                UnitAddBonus(create_unit(type, -20567, -5402, 45), BONUS_DAMAGE, 200000 * pcount)
            elseif thistype.floor == 3 then
                thistype.boss = create_unit(type, -20828, -10500, 180)
                AddSpecialEffectTarget("LightYellow30.mdl", thistype.boss, "origin")
                SetHeroLevel(thistype.boss, 500, false)
                EVENT_ON_UNIT_DEATH:register_unit_action(thistype.boss, onComplete)
            end
        end

        ON_BUY_LOOKUP[FourCC('I0NM')] = function(u, p, pid, itm)
            TimerQueue:callDelayed(2.5, RemoveUnit, u)
            DestroyEffect(AddSpecialEffectTarget("UI\\Feedback\\GoldCredit\\GoldCredit.mdl", u, "origin"))
            Fade(u, 2., true)

            if thistype.floor == 1 then
                BlackMask(thistype.players, 2, 2)
                dungeon_move(thistype.players, -20000, -4600, 2)
                spawn_floor()
            elseif thistype.floor == 2 then
                BlackMask(thistype.players, 2, 2)
                dungeon_move(thistype.players, -24192, -10500, 2)
                spawn_floor()
            elseif thistype.floor == 3 then
                if thistype.token_flag then
                    -- TODO: Replace with special reward
                end
            end

            local pcount  = #thistype.players ---@type integer
            local plat    = 130 + pcount * 10 ---@type integer
            local crystal = 40 + pcount * 5 ---@type integer

            DisplayTimedTextToTable(thistype.players, 7.5, "|cffffcc00You have been rewarded:|r \n|cffe3e2e2" .. (plat) .. " Platinum|r \n|cff6969FF" .. (crystal) .. " Crystals|r")

            for _, v in ipairs(thistype.players) do
                AddCurrency(v, PLATINUM, plat)
                AddCurrency(v, CRYSTAL, crystal)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl", GetUnitX(Hero[v]), GetUnitY(Hero[v])))
            end
        end

        local function timer_expire()
            thistype.token_flag = false
            thistype.timer = nil
            DisplayTextToTable(thistype.players, "Special reward will no longer drop.")
        end

        function thistype:onStart()
            spawn_floor()

            self.token_flag = true
            self.timer = TimerFrame.create("Special reward available:", 1800, timer_expire, self.players)
        end
    end
end, Debug and Debug.getLine())
