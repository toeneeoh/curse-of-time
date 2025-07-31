--[[
    timers.lua

    A library that initializes misc functions that should run periodically.
    Notable functions:
    Periodic() - executes 3 times per second

    Ideally this file is 0 lines
]]

OnInit.final("Timers", function(Require)
    Require('Units')
    Require('MapSetup')
    Require('Buffs')
    Require('Frames')

    local function DisplayHint()
        local rand = GetRandomInt(2, #HINT_TOOLTIP) ---@type integer 

        if LAST_HINT < 2 then
            LAST_HINT = LAST_HINT + 1
        else
            LAST_HINT = rand
        end

        DisplayTimedTextToForce(FORCE_HINT, 15, HINT_TOOLTIP[LAST_HINT])
        if rand ~= LAST_HINT then
            LAST_HINT = rand
        else
            LAST_HINT = LAST_HINT + 1
        end
        if LAST_HINT > #HINT_TOOLTIP then
            LAST_HINT = 1
        end
    end

    local setcamerafield = SetCameraField
    local gpi, glp = GetPlayerId, GetLocalPlayer

    local is_camera_locked = {} ---@type boolean[] 
    local zoom = ZOOM

    function SetCameraLocked(pid, lock)
        if not is_camera_locked[pid] then
            is_camera_locked[pid] = lock
        end
    end

    local function Periodic()
        local pid = gpi(glp()) + 1

        -- camera lock
        if is_camera_locked[pid] then
            setcamerafield(CAMERA_FIELD_TARGET_DISTANCE, zoom[pid], 0)
        end
    end

    local function OneMinute()
        local U = User.first

        while U do
            local profile = Profile[U.id]
            if profile and profile.playing then
                profile.hero.time = profile.hero.time + 1
                profile.total_time = profile.total_time + 1
            end

            ExperienceControl(U.id)
            U = U.next
        end
    end

    local fountain = function(u)
        local hp, mp = GetWidgetLife(u), GetUnitState(u, UNIT_STATE_MANA)

        if hp < BlzGetUnitMaxHP(u) * 0.99 then
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", u, "origin"))
            SetWidgetLife(u, hp + BlzGetUnitMaxHP(u))
        end

        if mp < BlzGetUnitMaxMana(u) * 0.99 and Unit[u].nomanaregen == false then
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIma\\AImaTarget.mdl", u, "origin"))
            SetUnitState(u, UNIT_STATE_MANA, mp + BlzGetUnitMaxMana(u))
        end
    end

    local function RefreshHeroes()
        local U = User.first

        while U do
            if Profile[U.id] and Profile[U.id].playing then
                local hero = Hero[U.id]
                local x, y = GetUnitX(hero), GetUnitY(hero)

                -- update boost variance every second
                BOOST[U.id] = 1. + Unit[hero].spellboost + GetRandomReal(-0.2, 0.2)
                LBOOST[U.id] = 1. + 0.5 * Unit[hero].spellboost

                -- keep track of hero positions
                Unit[hero].proxy.x = x
                Unit[hero].proxy.y = y

                local hp = GetWidgetLife(hero) / BlzGetUnitMaxHP(hero)

                -- backpack hp/mp percentage and movespeed
                if hp >= 0.01 then
                    SetWidgetLife(Backpack[U.id], BlzGetUnitMaxHP(Backpack[U.id]) * hp)
                    local mp = GetUnitState(hero, UNIT_STATE_MANA) / GetUnitState(hero, UNIT_STATE_MAX_MANA)
                    SetUnitState(Backpack[U.id], UNIT_STATE_MANA, GetUnitState(Backpack[U.id], UNIT_STATE_MAX_MANA) * mp)
                    --SetUnitMoveSpeed(Backpack[U.id], Unit[hero].ms_flat * Unit[hero].ms_percent)
                end
            end

            U = U.next
        end
    end

    local function OneSecond()
        -- set space bar camera to town
        SetCameraQuickPositionLoc(TOWN_CENTER)

        -- fountain regeneration
        ALICE_ForAllObjectsInRangeDo(fountain, -260., 350., 600., "unit")

        -- refresh auras, mana costs, etc.
        RefreshHeroes()
    end

    TimerQueue:callPeriodically(0.35, nil, Periodic)
    TimerQueue:callPeriodically(1.0, nil, OneSecond)
    TimerQueue:callPeriodically(60., nil, OneMinute)
    TimerQueue:callPeriodically(240., nil, DisplayHint)

    HUNT_TIMER = TimerQueue:callDelayed(2040. - (User.AmountPlaying * 240), ShadowStepExpire)
end, Debug and Debug.getLine())
