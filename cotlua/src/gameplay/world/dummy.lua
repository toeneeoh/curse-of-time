--[[
    dummy.lua

    A module used to create and recycle dummies for spell casting and projectile effects.
    Includes globals / helpers for DPS testing.
]]

OnInit.final("Dummy", function(Require)
    PUNCHING_BAG = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), FourCC('h02D'), GetRectCenterX(gg_rct_Punching_Bag), GetRectCenterY(gg_rct_Punching_Bag), 0.)

    Require("TimerQueue")
    Require("Events")
    Require("Units")
    Require('Frames')
    Require('CircularArrayList')

    local TQ = TimerQueue
    local atan = math.atan
    local FPS_32 = FPS_32

    DUMMY_COUNT = 0

    local reset
    local player_reset = {}

    local DUMMY_STACK = {}
    local DUMMY_RECYCLE_TIME = 5.

    local DPS_TIMER          = TQ.create()
    local DPS_STOPWATCH      = Stopwatch.create(false) ---@type Stopwatch
    local DPS_TOTAL_PHYSICAL = 0.
    local DPS_TOTAL_MAGIC    = 0.
    local DPS_TOTAL          = 0.
    local DPS_LAST           = 0.
    local DPS_CURRENT        = 0.
    local DPS_PEAK           = 0.
    local DPS_STORAGE        = CircularArrayList.create(30) ---@type CircularArrayList 
    local IATK               = FourCC('IATK')

    ---@class Dummy
    ---@field unit unit
    ---@field abil integer
    ---@field recycle function
    ---@field create function
    ---@field cast function
    ---@field source unit
    ---@field spell_source unit?
    ---@field spell_tag string?
    ---@field attack function
    ---@field lightning function
    Dummy = {} ---@type Dummy|Dummy[]
    do
        local thistype = Dummy
        local mt = { __index = thistype }

        ---@param source unit
        ---@param target unit
        local function attack_delay(source, target)
            BlzSetUnitWeaponBooleanField(source, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, true)
            IssueTargetOrderById(source, 852173, target)
        end

        ---@param source unit
        ---@param target unit
        local function instant_attack(source, target)
            UnitAddAbility(source, IATK)
            TQ:callDelayed(FPS_32, attack_delay, source, target)
        end

        ---Issues an immediate, unit-targeted, or point-targeted spell order.
        ---When spell_source is supplied, native spell damage is attributed to
        ---that unit instead of being suppressed as a dummy attack.
        ---@param owner player
        ---@param order string
        ---@param a unit|number?
        ---@param b number?
        ---@param spell_source unit?
        ---@param spell_tag string?
        ---@return boolean
        function thistype:cast(owner, order, a, b, spell_source, spell_tag)
            SetUnitOwner(self.unit, owner, true)
            self.spell_source = spell_source
            self.spell_tag = spell_tag

            -- self cast
            if a == nil then
                return IssueImmediateOrder(self.unit, order)
            -- target cast
            elseif type(a) == "userdata" then
                BlzSetUnitFacingEx(self.unit, bj_RADTODEG * atan(GetUnitY(a) - GetUnitY(self.unit), GetUnitX(a) - GetUnitX(self.unit)))
                return IssueTargetOrder(self.unit, order, a)
            -- point cast
            elseif type(a) == "number" then
                BlzSetUnitFacingEx(self.unit, bj_RADTODEG * atan(b - GetUnitY(self.unit), a - GetUnitX(self.unit)))
                return IssuePointOrder(self.unit, order, a, b)
            end

            return false
        end

        function thistype:lightning(x, y)
            local dummy = thistype.create(x, y, 0, 0, 1.)
            UnitRemoveAbility(dummy.unit, ABIL_AVUL)
            UnitRemoveAbility(dummy.unit, ABIL_ALOC)
            self:attack(dummy.unit)
        end

        ---@type fun(self: Dummy)
        function thistype:recycle()
            UnitRemoveAbility(self.unit, self.abil)
            self.abil = 0
            self.source = nil
            self.spell_source = nil
            self.spell_tag = nil

            SetUnitAnimation(self.unit, "stand")
            SetUnitPropWindow(self.unit, bj_DEGTORAD * 180.)
            BlzSetUnitName(self.unit, " ")
            BlzSetUnitWeaponBooleanField(self.unit, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
            SetUnitOwner(self.unit, Player(PLAYER_NEUTRAL_PASSIVE), true)
            BlzSetUnitSkin(self.unit, DUMMY_CASTER)
            SetUnitXBounded(self.unit, 30000.)
            SetUnitYBounded(self.unit, 30000.)
            UnitAddAbility(self.unit, ABIL_ALOC)
            UnitAddAbility(self.unit, ABIL_AVUL)
            SetUnitFlyHeight(self.unit, GetUnitDefaultFlyHeight(self.unit), 0)
            SetUnitScale(self.unit, 1, 1, 1)
            SetUnitVertexColor(self.unit, 255, 255, 255, 255)
            SetUnitTimeScale(self.unit, 1.)
            BlzUnitClearOrders(self.unit, false)
            BlzUnitDisableAbility(self.unit, FourCC('Amov'), false, false)
            PauseUnit(self.unit, true)
            BlzSetUnitAttackCooldown(self.unit, 0.01, 0)
            UnitAddBonus(self.unit, BONUS_ATTACK_SPEED, 4.)
            DUMMY_STACK[#DUMMY_STACK + 1] = self
            EVENT_DUMMY_ON_HIT:unregister_unit_action(self.unit)
        end

        local function onAggro(source, target)
            BlzSetUnitWeaponBooleanField(source, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
        end

        ---@type fun(x: number, y: number, abil: integer, ablev: integer, dur: any): Dummy
        function Dummy.create(x, y, abil, ablev, dur)
            local self = DUMMY_STACK[#DUMMY_STACK]

            -- available list is empty
            if self == nil then
                DUMMY_COUNT = DUMMY_COUNT + 1
                self = {
                    unit = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), DUMMY_CASTER, x, y, 0),
                    abil = 0,
                }
                UnitAddAbility(self.unit, FourCC('Amrf'))
                UnitRemoveAbility(self.unit, FourCC('Amrf'))
                UnitAddAbility(self.unit, ABIL_ALOC)
                SetUnitPathing(self.unit, false)
                TriggerRegisterUnitEvent(ACQUIRE_TRIGGER, self.unit, EVENT_UNIT_ACQUIRED_TARGET)
                EVENT_ON_AGGRO:register_unit_action(self.unit, onAggro)

                Dummy[self.unit] = self

                setmetatable(self, mt)
            -- use an existing available dummy
            else
                DUMMY_STACK[#DUMMY_STACK] = nil
                PauseUnit(self.unit, false)
            end

            if UnitAddAbility(self.unit, abil) then
                SetUnitAbilityLevel(self.unit, abil, ablev)
                self.abil = abil
            end

            if type(dur) == "number" then
                if dur > 0 then
                    TQ:callDelayed(dur, thistype.recycle, self)
                end
            else
                TQ:callDelayed(DUMMY_RECYCLE_TIME, thistype.recycle, self)
            end

            -- reset attack cooldown
            BlzSetUnitAttackCooldown(self.unit, 0.01, 0)
            UnitSetBonus(self.unit, BONUS_ATTACK_SPEED, 4.)

            SetUnitXBounded(self.unit, x)
            SetUnitYBounded(self.unit, y)

            return self
        end

        ---@type fun(self: Dummy, enemy: unit, source: unit, func: function)
        function thistype:attack(enemy, source, func)
            BlzSetUnitFacingEx(self.unit, bj_RADTODEG * atan(GetUnitY(enemy) - GetUnitY(self.unit), GetUnitX(enemy) - GetUnitX(self.unit)))
            UnitDisableAbility(self.unit, FourCC('Amov'), true)
            self.source = source or self.unit
            SetUnitOwner(self.unit, GetOwningPlayer(source), false)
            if func then
                EVENT_DUMMY_ON_HIT:register_unit_action(source, func)
            end
            instant_attack(self.unit, enemy)
        end

        -- exclude from ALICE
        ALICE_ExcludeTypes(DUMMY_CASTER)
    end

    -- Punching Bag helper functions
    local function dps_hide_text(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(DPS_FRAME, false)
        end
    end

    function DPS_RESET()
        DPS_TOTAL_PHYSICAL = 0.
        DPS_TOTAL_MAGIC = 0.
        DPS_TOTAL = 0.
        DPS_LAST = 0.
        DPS_CURRENT = 0.
        DPS_PEAK = 0.
        DPS_STORAGE:wipe()
        DPS_TIMER:reset()
        BlzFrameSetText(DPS_FRAME_TEXTVALUE, "0\n0\n0\n0\n0\n0\n0s")
    end

    local function calc_peak_dps()
        local i = DPS_STORAGE.START ---@type integer 
        local output = 0.
        local dps = 0.
        local count = DPS_STORAGE.count

        while count > 0 and DPS_STORAGE.data[i] do
            dps = dps + DPS_STORAGE.data[i]
            i = ModuloInteger((i + 1), DPS_STORAGE.MAXSIZE)
            count = count - 1
        end

        if dps > output then
            output = dps
        end

        return output
    end

    local function dps_peak_update()
        local time = DPS_STOPWATCH:getElapsed()
        local calc = calc_peak_dps()

        DPS_CURRENT = (DPS_TOTAL / math.ceil(time))
        if calc > DPS_PEAK then
            DPS_PEAK = calc
        end
        if DPS_CURRENT > DPS_PEAK then
            DPS_PEAK = DPS_CURRENT
        end
    end

    local function dps_update()
        local time = DPS_STOPWATCH:getElapsed()

        BlzFrameSetText(DPS_FRAME_TEXTVALUE, RealToString(DPS_LAST) .. "\n" .. RealToString(DPS_TOTAL_PHYSICAL) .. "\n" .. RealToString(DPS_TOTAL_MAGIC) .. "\n" .. RealToString(DPS_TOTAL) .. "\n" .. RealToString(DPS_CURRENT) .. "\n" .. RealToString(DPS_PEAK) .. "\n" .. RealToString(time) .. "s")
    end

    local function dps_on_hit(target, source, amount, amount_after_red, damage_type)
        local pid = GetPlayerId(GetOwningPlayer(source)) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(DPS_FRAME, true)
        end

        if player_reset[pid] then
            TQ:disableCallback(player_reset[pid])
        end
        player_reset[pid] = TQ:callDelayed(10., dps_hide_text, pid)

        if DPS_TOTAL <= 0 then
            DPS_STOPWATCH:start()
            DPS_TIMER:reset()
            DPS_TIMER:callPeriodically(0.2, nil, dps_update)
            DPS_TIMER:callPeriodically(1., nil, dps_peak_update)
        end

        DPS_LAST = amount_after_red

        if damage_type == PHYSICAL then
            DPS_TOTAL_PHYSICAL = (DPS_TOTAL_PHYSICAL + DPS_LAST)
        elseif damage_type == MAGIC then
            DPS_TOTAL_MAGIC = (DPS_TOTAL_MAGIC + DPS_LAST)
        end
        DPS_TOTAL = (DPS_TOTAL + DPS_LAST)

        DPS_STORAGE:add_timed(DPS_LAST, 1., 0.)
        if reset then
            DPS_TIMER:disableCallback(reset)
        end
        reset = DPS_TIMER:callDelayed(7.5, DPS_RESET)
        amount.display = amount_after_red
        amount.value = 0.
        SetWidgetLife(target, BlzGetUnitMaxHP(target))
    end

    EVENT_ON_STRUCK_FINAL:register_unit_action(PUNCHING_BAG, dps_on_hit)

    local function dps_open_ui(pid, u)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(PUNCHING_BAG_UI, u == PUNCHING_BAG)
        end
    end

    local U = User.first
    while U do
        EVENT_ON_SELECT:register_action(U.id, dps_open_ui)
        U = U.next
    end

end, Debug and Debug.getLine())
