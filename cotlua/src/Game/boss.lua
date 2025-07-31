--[[
    boss.lua

    This library defines bosses with unique handling of AI, difficulty, respawns, stat tracking, etc.
]]

OnInit.final("Boss", function(Require)
    Require('Variables')
    Require('ItemLookup')

    local NEARBY_BOSS_RANGE = 2500.
    BOSS_OFFSET = 1

    ---@class Boss
    ---@field index integer
    ---@field revive function
    ---@field id integer
    ---@field loc location
    ---@field facing number
    ---@field difficulty integer
    ---@field unit unit
    ---@field name string
    ---@field level integer
    ---@field item integer[]
    ---@field crystal integer
    ---@field leash number
    ---@field total_damage number
    ---@field damage number[]
    ---@field difficulty_vote integer[]
    ---@field respawn_modifier number
    ---@field first_drop boolean
    ---@field nearby_count integer
    ---@field target Unit
    ---@field init function
    ---@field reward function
    ---@field trigger trigger
    ---@field setup_range_event function
    ---@field timer TimerQueue
    ---@field switch_target function
    ---@field vote function
    Boss = {}
    do
        local thistype = Boss
        local mt = { __index = Boss }

        local function check_multiboard(boss)
            if type(boss) ~= "table" then
                boss = IsBoss(boss)
            end

            local mb = MULTIBOARD.BOSS
            local U = User.first
            local found_player

            while U do
                if (UnitAlive(boss.unit) and IsUnitInRange(Hero[U.id], boss.unit, NEARBY_BOSS_RANGE)) then
                    mb.viewing[U.id] = boss
                    mb.update_items(U.player)
                    if not mb.available[U.id] then
                        mb.available[U.id] = true
                        mb:display(U.id)
                    end
                    found_player = true
                elseif PLAYER_SELECTED_UNIT[U.id] ~= boss.unit then
                    if mb.viewing[U.id] == boss then
                        mb.viewing[U.id] = nil
                    end
                    mb.available[U.id] = false
                end
                U = U.next
            end

            if found_player then
                mb:update()
                TimerQueue:callDelayed(1., check_multiboard, boss)
            end
        end

        local function start_boss_threat(boss, unit)
            boss = IsBoss(boss)

            if not boss.target then
                local mb = MULTIBOARD.BOSS
                local pid = GetPlayerId(GetOwningPlayer(unit)) + 1
                boss.time = 0
                boss.target = Unit[unit]
                mb.viewing[pid] = boss
                mb.available[pid] = false
                mb.update_items(Player(pid - 1))
                mb.close_items(Player(pid - 1), true)
                check_multiboard(boss)
                mb:threat(boss)
            else
                IssueTargetOrderById(boss.unit, ORDER_ID_SMART, boss.target.unit)
            end
        end

        local function revive_gods()
            local ug = CreateGroup()

            GroupEnumUnitsInRect(ug, gg_rct_Gods_Arena, Filter(isplayerunitRegion))

            for target in each(ug) do
                local pid = GetPlayerId(GetOwningPlayer(target)) + 1

                if target == Hero[pid] then
                    TableRemove(GODS_GROUP, GetOwningPlayer(target))
                    MoveHeroLoc(pid, TOWN_CENTER)
                else
                    SetUnitPositionLoc(target, TOWN_CENTER)
                end
            end

            DestroyGroup(ug)

            RemoveUnit(power_crystal)

            Boss[BOSS_LIFE]:revive()

            PauseUnit(Boss[BOSS_LIFE].unit, true)
            ShowUnit(Boss[BOSS_LIFE].unit, false)

            Boss[BOSS_HATE]:revive()
            Boss[BOSS_LOVE]:revive()
            Boss[BOSS_KNOWLEDGE]:revive()

            DeadGods = 0
        end

        local function boss_respawn(uid, flag)
            if flag ~= CHAOS_MODE then
                return
            end

            local boss = IsBoss(uid)

            if boss then
                -- revive gods
                if boss.index == BOSS_LIFE then
                    revive_gods()
                    DisplayTimedTextToForce(FORCE_PLAYING, 20, "|cffffcc00" .. boss.name .. " have revived.|r")
                else
                    -- death knight / legion
                    if boss.id == BOSS_DEATH_KNIGHT or boss.id == BOSS_LEGION then
                        local x, y
                        repeat
                            x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
                            y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)
                        until IsTerrainWalkable(x, y) and RectContainsCoords(gg_rct_Town_Main, x, y) == false
                        boss.loc = Location(x, y)
                    elseif boss.index == BOSS_AZAZOTH then
                        AddItemToStock(god_portal, FourCC('I08T'), 1, 1)
                    end

                    boss:revive()
                    DestroyEffect(AddSpecialEffectLoc("Abilities\\Spells\\Orc\\Reincarnation\\ReincarnationTarget.mdl", boss.loc))
                end
            end
        end

        local special_case = {
            [FourCC('E00B')] = function()
                DeadGods = DeadGods + 1

                if DeadGods == 3 then --spawn goddess of life
                    if GodsRepeatFlag == false then
                        GodsRepeatFlag = true
                        SetCinematicScene(Boss[BOSS_LIFE].id, GetPlayerColor(Player(PLAYER_NEUTRAL_PASSIVE)), "Goddess of Life", "This is your last chance", 6, 5)
                    end

                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl", GetUnitX(Boss[BOSS_LIFE].unit), GetUnitY(Boss[BOSS_LIFE].unit)))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrect\\ResurrectCaster.mdl", GetUnitX(Boss[BOSS_LIFE].unit), GetUnitY(Boss[BOSS_LIFE].unit)))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl", GetUnitX(Boss[BOSS_LIFE].unit), GetUnitY(Boss[BOSS_LIFE].unit)))
                    ShowUnit(Boss[BOSS_LIFE].unit, true)
                    PauseUnit(Boss[BOSS_LIFE].unit, true)
                    UnitAddAbility(Boss[BOSS_LIFE].unit, FourCC('Avul'))
                    UnitAddAbility(Boss[BOSS_LIFE].unit, FourCC('A08L')) --life aura
                    TimerQueue:callDelayed(6., GoddessOfLife)
                end

                return true
            end,

            [FourCC('H04Q')] = function()
                DeadGods = 4
                DisplayTimedTextToForce(FORCE_PLAYING, 10, "You may now -flee.")
                power_crystal = CreateUnit(PLAYER_CREEP, FourCC('h04S'), -2026.936, -27753.830, bj_UNIT_FACING)
                EVENT_ON_UNIT_DEATH:register_unit_action(power_crystal, BeginChaos)

                return false
            end,
        }

        special_case[FourCC('E00C')] = special_case[FourCC('E00B')]
        special_case[FourCC('E00D')] = special_case[FourCC('E00B')]

        local function spawn_select_difficulty(boss, killed, flag)
            if flag ~= CHAOS_MODE then
                return
            end

            local x, y = GetUnitX(killed), GetUnitY(killed)
            local u = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n00B'), x, y, 0.)
            Unit[u].boss = boss

            SetUnitAnimation(u, "birth")

            TimerQueue:callDelayed(50., SetUnitAnimation, u, "stand work")
            TimerQueue:callDelayed(60., RemoveUnit, u)

            RemoveUnit(killed)
        end

        local function on_boss_death(killed, killer)
            local boss = IsBoss(killed)
            local uid = GetType(killed)
            local x, y = GetUnitX(killed), GetUnitY(killed)

            -- rewards
            RewardXPGold(killed, killer)
            boss:reward(x, y)

            if CHAOS_LOADING then
                return
            end

            TimerQueue:callDelayed(3., spawn_select_difficulty, boss, killed, CHAOS_MODE)

            local delay = BOSS_RESPAWN_TIME

            if IsUnitIdType(uid, UNIT_TYPE_HERO) == false then
                delay = delay // 2
            end

            if special_case[uid] then
                if special_case[uid]() then
                    return
                end
            end

            delay = delay * boss.respawn_modifier

            TimerQueue:callDelayed(delay, boss_respawn, uid, CHAOS_MODE)
        end

        ON_BUY_LOOKUP[FourCC('I05V')] = function(u, b, pid, itm)
            Unit[u].boss:vote(pid, 1)
        end

        ON_BUY_LOOKUP[FourCC('I05W')] = function(u, b, pid, itm)
            Unit[u].boss:vote(pid, 2)
        end

        local function boss_safe_zone(u)
            local boss = IsBoss(u)
            SetUnitXBounded(u, GetLocationX(boss.loc))
            SetUnitYBounded(u, GetLocationY(boss.loc))
        end

        -- bosses deal an additional 1 damage to attack count based units
        local function on_boss_hit(source, target)
            if Unit[target].attackCount > 0 then
                Unit[target].attackCount = Unit[target].attackCount - 1
                SetWidgetLife(target, GetWidgetLife(target) - 1)
            end
        end

        ---@type fun(index: integer, loc: location, facing: number, id: integer, name: string, level: integer, crystal: integer, leash: number): unit
        function Boss.create(index, loc, facing, id, name, level, crystal, leash)
            local self = setmetatable({
                index = index,
                loc = loc,
                facing = facing,
                difficulty = 1,
                respawn_modifier = 1,
                id = id,
                name = name,
                level = level,
                crystal = crystal,
                leash = leash,
                total_damage = 0,
                damage = __jarray(0),
                difficulty_vote = {},
                first_drop = true,
                nearby_count = 0,
                target = nil,
                threat = 100,
                time = 0,
            }, mt)

            thistype[index] = self
            self.unit = CreateUnitAtLoc(PLAYER_BOSS, id, loc, facing)

            SetHeroLevel(self.unit, level, false)
            SetUnitCreepGuard(self.unit, true)

            -- boss spell casting
            EVENT_ON_STRUCK_FINAL:register_unit_action(self.unit, BossAI)
            EVENT_ON_UNIT_DEATH:register_unit_action(self.unit, on_boss_death)

            EVENT_ON_AGGRO:register_unit_action(self.unit, start_boss_threat)

            EVENT_ON_HIT_FINAL:register_unit_action(self.unit, on_boss_hit)

            -- safe zone logic
            EVENT_ON_ENTER_SAFE_AREA:register_unit_action(self.unit, boss_safe_zone)

            -- logic for killing zeppelins
            self:setup_range_event()

            return self.unit
        end

        local function on_click(pid, boss)
            boss = IsBoss(boss)
            local mb = MULTIBOARD
            local boss_mb = mb.BOSS
            if boss then
                if not boss_mb.viewing[pid] or boss_mb.viewing[pid].unit ~= boss.unit then
                    boss_mb.viewing[pid] = boss
                    boss_mb.available[pid] = true
                    boss_mb.update_items(Player(pid - 1))
                    boss_mb.close_items(Player(pid - 1), true)
                    boss_mb:display(pid)
                    boss_mb:update()
                end
            elseif mb.lookingAt[pid] == boss_mb.index then
                if boss_mb.viewing[pid] and not IsUnitInRange(Hero[pid], boss_mb.viewing[pid].unit, NEARBY_BOSS_RANGE) then
                    boss_mb.viewing[pid] = nil
                    boss_mb.available[pid] = false
                    mb.bodies[mb.previousMb[pid]]:display(pid)
                end
            end
        end

        local U = User.first
        while U do
            -- on select show multiboard
            EVENT_ON_SELECT:register_action(U.id, on_click)
            U = U.next
        end

        local function valid_target()
            local u = GetFilterUnit()
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1

            return pid <= PLAYER_CAP and
            UnitAlive(u) and
            GetUnitAbilityLevel(u, FourCC('Avul')) == 0 and
            GetUnitAbilityLevel(u, FourCC('Aloc')) == 0
        end

        function thistype:switch_target(unit, delay)
            if unit then
                self.target = unit
            else -- find proximity
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(self.unit), GetUnitY(self.unit), 1800., Filter(valid_target))
                local size = BlzGroupGetSize(ug)
                if size > 1 then -- atleast two units
                    local rand
                    repeat
                        rand = BlzGroupUnitAt(ug, math.random(0, size - 1))
                    until rand ~= self.target.unit

                    self.target = Unit[rand]
                elseif size <= 0 then
                    self.target = nil
                end
                DestroyGroup(ug)
            end

            if self.target then
                MULTIBOARD.BOSS:update()
                TimerQueue:callDelayed(delay or 0., IssueTargetOrderById, self.unit, ORDER_ID_SMART, self.target.unit)
            end
        end

        function thistype:vote(pid, difficulty_level)
            self.difficulty_vote[pid] = difficulty_level
            local U = User.first

            DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has selected " .. (difficulty_level == 2 and "Hard" or "Normal") .. " difficulty for |cffffcc00" .. self.name .. "|r")

            local vote_count = { [1] = 0, [2] = 0 }
            while U do
                local vote = self.difficulty_vote[U.id]
                vote_count[vote] = vote_count[vote] + 1

                U = U.next
            end

            if vote_count[2] > vote_count[1] then
                self.difficulty = 2
                self.respawn_modifier = 0.75
                DisplayTextToForce(FORCE_PLAYING, self.name .. " difficulty level has been set to: |cffffcc00Hard|r")
            elseif vote_count[1] > vote_count[2] then
                self.difficulty = 1
                self.respawn_modifier = 1
                DisplayTextToForce(FORCE_PLAYING, self.name .. " difficulty level has been set to: |cffffcc00Normal|r")
            end
        end

        ---@type fun(boss: table, chance: integer, x: number, y: number)
        local function boss_drop(boss, chance, x, y)
            for _ = 1, boss.difficulty do
                if math.random(0, 99) < chance then
                    local itm = CreateItem(DropTable:pickItem(boss.id), x, y, 600.)
                    itm:lvl(IMaxBJ(0, ItemData[itm.id][ITEM_UPGRADE_MAX] - math.random(ITEM_MIN_LEVEL_VARIANCE, ITEM_MAX_LEVEL_VARIANCE)))
                end
            end
        end

        function thistype:reward(x, y)
            if self.first_drop then
                self.first_drop = false
                boss_drop(self, Rates[self.id] + 25, x, y)
            else
                boss_drop(self, Rates[self.id], x, y)
            end

            local count = self.crystal * self.difficulty ---@type integer 

            if count > 0 then
                local U = User.first

                while U do
                    if IsUnitInRangeXY(Hero[U.id], x, y, NEARBY_BOSS_RANGE) and GetHeroLevel(Hero[U.id]) >= self.level then
                        AddCurrency(U.id, CRYSTAL, count)
                        FloatingTextUnit("+" .. (count) .. (count == 1 and " Crystal" or " Crystals"), Hero[U.id], 2.1, 80, 90, 9, 70, 150, 230, 0, false)
                    end

                    U = U.next
                end
            end
        end

        local function bonus_linger(boss, subtraction)
            boss.nearby_count = boss.nearby_count - subtraction
        end

        ---@type fun(boss: Boss)
        local function return_boss(boss)
            if UnitAlive(boss.unit) and not CHAOS_LOADING then
                if IsUnitInRangeLoc(boss.unit, boss.loc, 100.) then
                    Unit[boss.unit].overmovespeed = nil
                    SetUnitPathing(boss.unit, true)
                    UnitRemoveAbility(boss.unit, FourCC('Amrf'))
                else
                    if GetUnitCurrentOrder(boss.unit) ~= ORDER_ID_MOVE then
                        IssuePointOrder(boss.unit, "move", GetLocationX(boss.loc), GetLocationY(boss.loc))
                    end
                    Buff.dispelAll(boss.unit)
                    TimerQueue:callDelayed(0.25, return_boss, boss)
                end
            end
        end

        local function periodic()
            -- boss regeneration / player scaling / reset
            for i = BOSS_OFFSET, #Boss do
                local boss = Boss[i]

                if boss and UnitAlive(boss.unit) then
                    local bossUnit = Unit[boss.unit]

                    -- death knight / legion exception
                    if boss.id ~= FourCC('H04R') and boss.id ~= FourCC('H040') then
                        if IsUnitInRangeLoc(boss.unit, boss.loc, boss.leash) == false and GetUnitAbilityLevel(boss.unit, FourCC('Amrf')) == 0 then
                            bossUnit.regen_max = 16 -- 16 percent
                            bossUnit.overmovespeed = 750
                            UnitAddAbility(boss.unit, FourCC('Amrf'))
                            SetUnitPathing(boss.unit, false)
                            TimerQueue:callDelayed(0.25, return_boss, boss)
                        end
                    end

                    -- determine number of nearby heroes
                    local numplayers = 0
                    local U = User.first
                    while U do
                        if IsUnitInRange(Hero[U.id], boss.unit, NEARBY_BOSS_RANGE) then
                            numplayers = numplayers + 1
                        end
                        U = U.next
                    end

                    boss.nearby_count = math.max(boss.nearby_count, numplayers)

                    if numplayers < boss.nearby_count then
                        TimerQueue:callDelayed(5., bonus_linger, boss, boss.nearby_count - numplayers)
                    end

                    local hp = 1

                    -- calculate hp regeneration
                    if GetWidgetLife(boss.unit) <= hp * 0.15 then -- 15 percent hp double regen
                        hp = 2
                    end

                    if CHAOS_MODE then
                        hp = hp * (0.01 + 0.04 * boss.nearby_count) -- 0.04 percent per player
                    else
                        hp = hp * 0.2 * boss.nearby_count -- 0.2 percent
                    end

                    if numplayers == 0 then -- out of combat
                        hp = 2 -- 2 percent
                    else -- bonus damage and health
                        if CHAOS_MODE then
                            boss.damage_percent = 100 + (20 * (boss.nearby_count - 1))
                            bossUnit.bonus_str = bossUnit.bonus_str + R2I(bossUnit.str * 20 * (boss.nearby_count - 1))
                        end
                    end

                    -- non-returning hp regeneration
                    if GetUnitAbilityLevel(boss.unit, FourCC('Amrf')) == 0 and hp ~= bossUnit.regen_max then
                        bossUnit.regen_max = hp
                    end
                end
            end
        end

        -- refresh boss regen, threat, etc.
        TimerQueue:callPeriodically(1., nil, periodic)

        local function kill_zeppelin_factory(boss)
            local function f()
                local source = GetTriggerUnit()

                if UnitAlive(boss) and GetUnitTypeId(source) == FourCC('nzep') then
                    ExpireUnit(source)
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(boss), GetUnitY(boss)))
                    SetUnitAnimation(boss, "attack slam")
                end

                return false
            end

            return Filter(f)
        end

        function thistype:setup_range_event()
            -- clean up trigger event
            if self.trigger then
                DestroyTrigger(self.trigger)
            end
            self.trigger = CreateTrigger()
            if CHAOS_MODE then
                TriggerRegisterUnitInRange(self.trigger, self.unit, 900., kill_zeppelin_factory(self.unit))
            end
        end

        function thistype:revive()
            self.unit = CreateUnitAtLoc(PLAYER_BOSS, self.id, self.loc, self.facing)
            EVENT_ON_STRUCK_FINAL:register_unit_action(self.unit, BossAI)
            EVENT_ON_UNIT_DEATH:register_unit_action(self.unit, on_boss_death)

            self:setup_range_event()

            SetHeroLevel(self.unit, self.level, false)
            if self.difficulty == 2 then
                Unit[self.unit].str = Unit[self.unit].str * 2
                BlzSetUnitBaseDamage(self.unit, BlzGetUnitBaseDamage(self.unit, 0) * 2 + 1, 0)
                Buff.dispelAll(self.unit)
                Unit[self.unit].mm = 2.
            end
            DisplayTimedTextToForce(FORCE_PLAYING, 20, "|cffffcc00" .. self.name .. " has revived.|r")

            -- reset multiboard data
            local U = User.first
            while U do
                self.damage[U.id] = 0
                U = U.next
            end
            self.total_damage = 0
        end
    end

    ---@type fun(pt: PlayerTimer)
    function StompPeriodic(pt)
        pt.dur = pt.dur - 1

        if pt.dur <= 0 or UnitAlive(pt.source) == false then
            pt:destroy()
        else
            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, GetUnitX(pt.source), GetUnitY(pt.source), 300., Condition(FilterEnemy))

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(pt.source), GetUnitY(pt.source)))

            for target in each(ug) do
                DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, pt.tag)
            end

            DestroyGroup(ug)

            pt.timer:callDelayed(1., StompPeriodic, pt)
        end
    end

    local function boss_tp(target, x, y)
        SetUnitXBounded(target, x)
        SetUnitYBounded(target, y)
        SetUnitVertexColor(target, BlzGetUnitIntegerField(target, UNIT_IF_TINTING_COLOR_RED), BlzGetUnitIntegerField(target, UNIT_IF_TINTING_COLOR_GREEN), BlzGetUnitIntegerField(target, UNIT_IF_TINTING_COLOR_BLUE), 255)
        PauseUnit(target, false)
        BlzSetUnitFacingEx(target, 270.)
    end

    ---@type fun(target: unit, dur: number)
    function BossTeleport(target, dur)
        local guy = (CHAOS_MODE and Boss[BOSS_LEGION].unit) or Boss[BOSS_DEATH_KNIGHT].unit
        local msg = (CHAOS_MODE and "Shadow Step") or "Death March"
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer 

        if CHAOS_MODE then
            BlzStartUnitAbilityCooldown(guy, FourCC('A0AV'), 2040. - (User.AmountPlaying * 240))
        else
            BlzStartUnitAbilityCooldown(guy, FourCC('A0AU'), 2040. - (User.AmountPlaying * 240))
        end

        if UnitAlive(guy) then
            FloatingTextUnit(msg, guy, 1.75, 100, 0, 12, 154, 38, 158, 0, true)
            PauseUnit(guy, true)
            local x, y = GetUnitX(target), GetUnitY(target)
            TimerQueue:callDelayed(dur, boss_tp, guy, x, y)
            Fade(guy, dur - 0.6, true)
            local dummy = Dummy.create(x, y, 0, 0, dur)
            BlzSetUnitSkin(dummy.unit, GetUnitTypeId(guy))
            SetUnitVertexColor(dummy.unit, BlzGetUnitIntegerField(dummy.unit, UNIT_IF_TINTING_COLOR_RED), BlzGetUnitIntegerField(dummy.unit, UNIT_IF_TINTING_COLOR_GREEN), BlzGetUnitIntegerField(dummy.unit, UNIT_IF_TINTING_COLOR_BLUE), 0)
            Fade(dummy.unit, dur, false)
            BlzSetUnitFacingEx(dummy.unit, 270.)
            PauseUnit(dummy.unit, true)
            if dur >= 4 then
                PlaySound("Sound\\Interface\\CreepAggroWhat1.flac")
                if CHAOS_MODE then
                    DisplayTimedTextToForce(FORCE_PLAYING, 20., "|cffffcc00Legion:|r There is no escape " .. User[pid - 1].nameColored .. "..")
                else
                    DisplayTimedTextToForce(FORCE_PLAYING, 20., "|cffffcc00Death Knight:|r Prepare yourself " .. User[pid - 1].nameColored .. "!")
                end
            end
        end
    end

    ---@return boolean
    function ShadowStepExpire(called)
        local ug  = CreateGroup()
        local g   = CreateGroup()
        local guy = (CHAOS_MODE and Boss[BOSS_LEGION].unit) or Boss[BOSS_DEATH_KNIGHT].unit

        GroupEnumUnitsInRect(ug, MAIN_MAP.rect, Condition(ischar))
        GroupEnumUnitsInRect(g, gg_rct_Town_Main, Condition(ischar))

        for i = BOSS_OFFSET, #Boss do
            GroupEnumUnitsInRangeEx(BOSS_ID, g, GetLocationX(Boss[i].loc), GetLocationY(Boss[i].loc), 2000., Condition(ischar))
        end

        if BlzGroupGetSize(g) > 0 then
            BlzGroupRemoveGroupFast(g, ug)
        end

        GroupEnumUnitsInRange(g, GetUnitX(guy), GetUnitY(guy), 1500., Condition(ischar))

        -- if there are no nearby players and there exists a valid player to teleport to on the map
        if BlzGroupGetSize(ug) > 0 and BlzGroupGetSize(g) == 0 then
            guy = BlzGroupUnitAt(ug, GetRandomInt(0, BlzGroupGetSize(ug) - 1))

            if guy then
                local sfx = AddSpecialEffect("war3mapImported\\BlackSmoke.mdx", GetUnitX(guy), GetUnitY(guy))
                BlzSetSpecialEffectTimeScale(sfx, 0.75)
                BlzSetSpecialEffectScale(sfx, 1.)
                TimerQueue:callDelayed(3., DestroyEffect, sfx)

                BossTeleport(guy, 4.)
            end
        end

        DestroyGroup(ug)
        DestroyGroup(g)

        if not called then
            HUNT_TIMER = TimerQueue:callDelayed(2040. - (User.AmountPlaying * 240), ShadowStepExpire)
        end

        return false
    end

    local function BossWander()
        local x ---@type number 
        local y ---@type number 
        local x2 ---@type number 
        local y2 ---@type number 
        local count = 0 ---@type integer 
        local id    = (CHAOS_MODE and BOSS_LEGION) or BOSS_DEATH_KNIGHT

        if CHAOS_LOADING then
            return
        end

        --dk / legion
        if GetUnitTypeId(Boss[id].unit) ~= 0 and UnitAlive(Boss[id].unit) then
            repeat
                x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
                y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)
                x2 = GetUnitX(Boss[id].unit)
                y2 = GetUnitY(Boss[id].unit)
                count = count + 1

            until LineContainsRect(x2, y2, x, y, -4000, -3000, 4000, 5000) == false and IsTerrainWalkable(x, y) and DistanceCoords(x, y, x2, y2) > 2500.

            IssuePointOrder(Boss[id].unit, "patrol", x, y)
        end

        if UnitAlive(udg_SPONSOR) then
            x = GetRandomReal(GetRectMinX(gg_rct_Town_Main) + 500, GetRectMaxX(gg_rct_Town_Main) - 500)
            y = GetRandomReal(GetRectMinY(gg_rct_Town_Main) + 500, GetRectMaxY(gg_rct_Town_Main) - 500)

            IssuePointOrder(udg_SPONSOR, "move", x, y)
        end
    end

    local illusions = {}

    ---@return boolean
    local function PositionLegionIllusions()
        local u = GetSummonedUnit()

        if GetUnitTypeId(u) == FourCC('H04R') and IsUnitIllusion(u) then
            illusions[#illusions + 1] = u
            SetUnitPathing(u, false)
            UnitAddAbility(u, FourCC('Amrf'))
        end

        if #illusions >= 7 then
            local j = 0 -- adjusts distance if valid spot cannot be found
            local count = 0
            local x2 = 0.
            local y2 = 0.
            local x = GetLocationX(Boss[BOSS_LEGION].loc)
            local y = GetLocationY(Boss[BOSS_LEGION].loc)
            local rand = GetRandomInt(0, 359)

            repeat
                x2 = x + (700 - j) * math.cos(bj_DEGTORAD * rand)
                y2 = y + (700 - j) * math.sin(bj_DEGTORAD * rand)

                rand = GetRandomInt(0, 359)
                count = count + 1

                if count > 150 then
                    j = j + 50
                end
            until IsTerrainWalkable(x2, y2) and RectContainsCoords(gg_rct_Town_Main, x2, y2) == false

            SetUnitXBounded(Boss[BOSS_LEGION].unit, x2)
            SetUnitYBounded(Boss[BOSS_LEGION].unit, y2)
            SetUnitPathing(Boss[BOSS_LEGION].unit, false)
            SetUnitPathing(Boss[BOSS_LEGION].unit, true)
            BlzSetUnitFacingEx(Boss[BOSS_LEGION].unit, bj_RADTODEG * math.atan(y2 - y, x2 - x))
            IssuePointOrder(Boss[BOSS_LEGION].unit, "attack", x, y)

            for i = 1, #illusions do
                local target = illusions[i]
                x2 = x + (700 - j) * math.cos(bj_DEGTORAD * (rand + i * 45))
                y2 = y + (700 - j) * math.sin(bj_DEGTORAD * (rand + i * 45))

                SetUnitXBounded(target, x2)
                SetUnitYBounded(target, y2)
                BlzSetUnitFacingEx(target, bj_RADTODEG * math.atan(y2 - y, x2 - x))
                IssuePointOrder(target, "attack", x, y)
            end
        end

        return false
    end

    ---@type fun(target: unit, source: unit, amount: table, amount_after_red: number, damage_type: damagetype)
    function BossAI(target, source, amount, amount_after_red, damage_type)
        local pid = GetPlayerId(GetOwningPlayer(source)) + 1
        local boss = IsBoss(target)

        -- keep track of boss damage
        boss.damage[pid] = boss.damage[pid] + amount_after_red
        boss.total_damage = boss.total_damage + amount_after_red
    end

    local t = CreateTrigger()

    TriggerRegisterPlayerUnitEvent(t, PLAYER_BOSS, EVENT_PLAYER_UNIT_SUMMON, nil)
    TriggerAddCondition(t, Filter(PositionLegionIllusions))

    TimerQueue:callPeriodically(15., nil, BossWander)

end, Debug and Debug.getLine())
