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

    local TQ = TimerQueue
    local GetRandomInt, DisplayTimedTextToForce = GetRandomInt, DisplayTimedTextToForce
    local SetCameraField, SetCameraQuickPosition = SetCameraField, SetCameraQuickPosition
    local GetPlayerId, GetLocalPlayer = GetPlayerId, GetLocalPlayer
    local GetUnitX, GetUnitY = GetUnitX, GetUnitY
    local GetWidgetLife, SetWidgetLife = GetWidgetLife, SetWidgetLife
    local GetUnitState, SetUnitState = GetUnitState, SetUnitState
    local BlzGetUnitMaxHP, BlzGetUnitMaxMana = BlzGetUnitMaxHP, BlzGetUnitMaxMana
    local AddSpecialEffectTarget, DestroyEffect = AddSpecialEffectTarget, DestroyEffect

    local User, Profile, Hero, Backpack, Unit = User, Profile, Hero, Backpack, Unit
    local BOOST, LBOOST, ZOOM = BOOST, LBOOST, ZOOM
    local UNIT_STATE_MANA, UNIT_STATE_MAX_MANA = UNIT_STATE_MANA, UNIT_STATE_MAX_MANA
    local CAMERA_FIELD_TARGET_DISTANCE = CAMERA_FIELD_TARGET_DISTANCE

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
        is_camera_locked[pid] = lock
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
                ExperienceControl(U.id)
            end
            U = U.next
        end
    end

    local fountain = function(u)
        local maxhp = BlzGetUnitMaxHP(u)
        local maxmp = BlzGetUnitMaxMana(u)
        local hp = GetWidgetLife(u)
        local mp = GetUnitState(u, UNIT_STATE_MANA)

        if hp < maxhp * 0.99 then
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", u, "origin"))
            SetWidgetLife(u, hp + maxhp)
        end

        if mp < maxmp * 0.99 and Unit[u].nomanaregen == false then
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIma\\AImaTarget.mdl", u, "origin"))
            SetUnitState(u, UNIT_STATE_MANA, mp + maxmp)
        end
    end

    local function RefreshHeroes()
        local U = User.first

        while U do
            local uid = U.id
            local profile = Profile[uid]

            if profile and profile.playing then
                local hero = Hero[uid]
                local unit = Unit[hero]
                local backpack = Backpack[uid]
                local x, y = GetUnitX(hero), GetUnitY(hero)

                -- update boost variance every second
                BOOST[uid] = 1. + unit.spellboost + SpellboostVariance()
                LBOOST[uid] = 1. + 0.5 * unit.spellboost

                -- keep track of hero positions
                unit.proxy.x = x
                unit.proxy.y = y

                local hp = GetWidgetLife(hero) / BlzGetUnitMaxHP(hero)

                -- backpack hp/mp percentage and movespeed
                if hp >= 0.01 then
                    SetWidgetLife(backpack, BlzGetUnitMaxHP(backpack) * hp)

                    local mp = GetUnitState(hero, UNIT_STATE_MANA) / GetUnitState(hero, UNIT_STATE_MAX_MANA)
                    SetUnitState(backpack, UNIT_STATE_MANA, GetUnitState(backpack, UNIT_STATE_MAX_MANA) * mp)
                end
            end

            U = U.next
        end
    end

    local function OneSecond()
        -- set space bar camera to town
        SetCameraQuickPosition(TOWN_CENTER_X, TOWN_CENTER_Y)

        -- fountain regeneration
        ALICE_ForAllObjectsInRangeDo(fountain, -260., 350., 600., "unit")

        -- refresh auras, mana costs, etc.
        RefreshHeroes()
    end

    TQ:callPeriodically(0.35, nil, Periodic)
    TQ:callPeriodically(1.0, nil, OneSecond)
    TQ:callPeriodically(60., nil, OneMinute)
    TQ:callPeriodically(240., nil, DisplayHint)

    HUNT_TIMER = TQ:callDelayed(2040. - (User.AmountPlaying * 240), ShadowStepExpire)
end, Debug and Debug.getLine())
