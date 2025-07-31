--[[
    dungeons.lua

    This module contains dungeon related globals and functions.
]]

OnInit.final("Dungeons", function(Require)
    Require('Variables')
    Require('Units')
    Require('ItemLookup')
    Require('Death')
    Require('Gluebutton')

    QUEUE_DUNGEON = false
    QUEUE_GROUP   = {} ---@type player[]
    QUEUE_READY   = {} ---@type boolean[] 

    ---@class Dungeon
    ---@field started boolean
    ---@field name string
    ---@field players integer[]
    ---@field chest unit
    ---@field enemies unit[]
    ---@field creepDeath function
    ---@field define function
    ---@field endDungeon function
    ---@field entrance_x number
    ---@field entrance_y number
    ---@field exit_x number
    ---@field exit_y number
    ---@field timer TimerFrame
    ---@field playerDeath function
    Dungeon = {}
    do
        local thistype = Dungeon
        local mt = { __index = thistype }

        local function onBuy(p, pid, u, itm)
            thistype[itm.id]:queue(pid)
        end

        ---@param id integer
        ---@return Dungeon
        function thistype.define(id)
            local self = {
                id = FourCC(id),
                players = {},
                enemies = {},
                floor = 0,
            }

            setmetatable(self, mt)

            -- setup item onbuy event
            ITEM_LOOKUP[self.id] = onBuy
            thistype[self.id] = self

            return self
        end

        ---@type fun(id: integer, x: number, y: number, facing: number, dmgr: integer, g: table):unit
        function thistype:createUnit(id, x, y, facing)
            local u = CreateUnit(PLAYER_CREEP, id, x, y, facing)
            self.enemies[#self.enemies + 1] = u

            if self.creepDeath then
                EVENT_ON_UNIT_DEATH:register_unit_action(u, self.creepDeath)
            end

            return u
        end

        function thistype:destroy()
            self.floor = 0
            self.started = false

            if self.timer then
                self.timer:destroy()
            end

            if self.exit_timer then
                self.exit_timer:destroy()
            end

            if self.chest then
                RemoveUnit(self.chest)
            end

            for i = 1, #self.enemies do
                RemoveUnit(self.enemies[i])
                self.enemies[i] = nil
            end
        end

        -- dungeon end ui
        function thistype:endDungeon()

            -- reenable items immediately for players
            for i = 1, #self.players do
                local pid = self.players[i]
                DisableItems(pid, false)
                if self.playerDeath then
                    EVENT_GRAVE_DEATH:unregister_unit_action(Hero[pid], self.playerDeath)
                end
            end

            -- timer runs out, dungeon closes
            local function close()
                for i = 1, #self.players do
                    local pid = self.players[i]
                    DisableBackpackTeleports(pid, false)
                    MoveHero(pid, self.exit_x, self.exit_y)
                    self.players[i] = nil
                end

                self:destroy()
            end
            self.exit_timer = TimerFrame.create("Dungeon closing in: ", 120., close, self.players)

            -- player presses EXIT
            local exit = function()
                local p = GetTriggerPlayer()
                local pid = GetPlayerId(p) + 1

                TableRemove(self.players, pid)
                DisableBackpackTeleports(pid, false)
                MoveHero(pid, self.exit_x, self.exit_y)

                if GetLocalPlayer() == p then
                    BlzFrameSetVisible(self.exit_timer.minimize, false)
                end

                if #self.players == 0 then
                    self:destroy()
                end
            end
            SimpleButton.create(self.exit_timer.frame, "war3mapImported\\ExitButton.blp", 0.03, 0.015, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., 0.015, exit)
        end

        local function start(self)
            local mb = MULTIBOARD.QUEUE

            for i = 1, #QUEUE_GROUP do
                MoveHero(QUEUE_GROUP[i], self.entrance_x, self.entrance_y)
                self.players[#self.players + 1] = QUEUE_GROUP[i]

                -- disable items / teleports
                DisableItems(QUEUE_GROUP[i], true)
                DisableBackpackTeleports(QUEUE_GROUP[i], true)

                mb.last_row = mb.last_row - 1
                mb:showRow(mb.last_row, false)
                mb.available[QUEUE_GROUP[i]] = false
                MULTIBOARD.MAIN:display(QUEUE_GROUP[i])

                if self.playerDeath then
                    EVENT_GRAVE_DEATH:register_unit_action(Hero[QUEUE_GROUP[i]], self.playerDeath)
                end

                QUEUE_READY[QUEUE_GROUP[i]] = false
                QUEUE_GROUP[i] = nil
            end

            QUEUE_DUNGEON = false

            self:onStart()
        end

        local function ready_check()
            for _, v in ipairs(QUEUE_GROUP) do
                if not QUEUE_READY[v] then
                    return false
                end
            end

            return true
        end

        -- add & remove players to dungeon queue
        local function queue_check(self)
            if not self.started then
                local U = User.first
                local mb = MULTIBOARD.QUEUE

                while U do
                    if IsUnitInRangeXY(Hero[U.id], self.queue_x, self.queue_y, 750.) and UnitAlive(Hero[U.id]) and not Unit[Hero[U.id]].busy then
                        if TableHas(QUEUE_GROUP, U.id) == false and GetHeroLevel(Hero[U.id]) >= self.level then
                            QUEUE_GROUP[#QUEUE_GROUP + 1] = U.id
                            mb.player_lookup[U.id] = mb.last_row
                            mb:get(mb.last_row, 1).text = {0.02, 0, 0.09, 0.011}
                            mb:get(mb.last_row, 2).icon = {0.26, 0, 0.011, 0.011}
                            mb.available[U.id] = true
                            mb:display(U.id)
                            mb.last_row = mb.last_row + 1
                        end
                    elseif TableHas(QUEUE_GROUP, U.id) then
                        TableRemove(QUEUE_GROUP, U.id)
                        QUEUE_READY[U.id] = false
                        mb.player_lookup[mb.last_row + 1] = mb.player_lookup[U.id]
                        mb.showRow(mb.player_lookup[U.id], false)
                        mb.last_row = mb.last_row - 1
                        mb.available[U.id] = false
                        MULTIBOARD.MAIN:display(U.id)
                    end

                    U = U.next
                end

                if #QUEUE_GROUP == 0 then
                    QUEUE_DUNGEON = false
                else
                    TimerQueue:callDelayed(1., queue_check, self)
                end
            end
        end

        ---@param pid integer
        function thistype:queue(pid)
            if self.started then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "This dungeon is already in progress!")
            else
                if not QUEUE_DUNGEON then
                    QUEUE_DUNGEON = self
                    MULTIBOARD.QUEUE.title = self.name
                    queue_check(self)
                elseif QUEUE_DUNGEON == self then
                    if ready_check() then
                        self.started = true
                        BlackMask(QUEUE_GROUP, 2, 2)
                        TimerQueue:callDelayed(2., start, self)
                    else
                        DisplayTextToTable(QUEUE_GROUP, "Not all players are ready to start the dungeon!")
                    end
                else
                    DisplayTextToPlayer(Player(pid - 1), 0, 0, "Please wait while another dungeon is queueing!")
                end
            end
        end

        -- stubs

        -- called when dungeon begins
        function thistype:onStart() end
    end

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

    DUNGEON_AZAZOTH = Dungeon.define('I08T')
    do
        local thistype = DUNGEON_AZAZOTH

        thistype.level = 360
        thistype.name = "Azazoth's Lair"
        thistype.queue_x = -1408.
        thistype.queue_y = -15246.
        thistype.entrance_x = -2036.
        thistype.entrance_y = -28236.
        thistype.exit_x = -250.
        thistype.exit_y = 60.

        thistype.playerDeath = function(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            TableRemove(thistype.players, pid)

            if UnitAlive(thistype.boss) then
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20.00, "|c00ff3333Azazoth: Mortal weakling, begone! Your flesh is not even worth annihilation.")
            end

            if #thistype.players <= 0 then
                thistype:destroy()
                Buff.dispelAll(thistype.boss)
                SetUnitLifePercentBJ(thistype.boss, 100)
                SetUnitManaPercentBJ(thistype.boss, 100)
                SetUnitPosition(thistype.boss, GetRectCenterX(gg_rct_Azazoth_Boss_Spawn), GetRectCenterY(gg_rct_Azazoth_Boss_Spawn))
                BlzSetUnitFacingEx(thistype.boss, 90.00)
            end

            EVENT_GRAVE_DEATH:unregister_unit_action(u, thistype.playerDeath)
        end

        local function onComplete()
            StartSound(bj_questCompletedSound)

            -- wait for azazoth to respawn before able to enter again
            RemoveItemFromStock(god_portal, FourCC('I08T'))

            thistype:endDungeon()
        end

        local function unpause_boss(go)
            if not go then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl", thistype.boss, "origin"))
                TimerQueue:callDelayed(2., unpause_boss, true)
            else
                PauseUnit(thistype.boss, false)
                SetUnitTimeScale(thistype.boss, 1.)
            end
        end

        function thistype:onStart()
            thistype.boss = Boss[BOSS_AZAZOTH].unit
            PauseUnit(thistype.boss, true)
            SetUnitTimeScale(thistype.boss, 0.)
            TimerQueue:callDelayed(5., unpause_boss, false)

            EVENT_ON_UNIT_DEATH:register_unit_action(Boss[BOSS_AZAZOTH].unit, onComplete)
        end
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

            thistype.chest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('h002'), -22141, -10500, 0)
            DisplayTextToTable(thistype.players, "You have vanquished the Ancient Nagas!")
            if thistype.timer then
                thistype.timer:destroy()
            end
            --[[for _, pid in ipairs(thistype.players) do
                local XP = R2I(EXPERIENCE_TABLE[300] * XP_Rate[pid])
                AwardXP(pid, XP)
            end]]

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
            local plat    = math.random(22, 25) + pcount * 3 ---@type integer 
            local crystal = math.random(12, 15) + pcount * 3 ---@type integer 

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
