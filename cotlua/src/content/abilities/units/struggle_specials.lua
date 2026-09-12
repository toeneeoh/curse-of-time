--[[
    struggle_specials.lua

    Runtime behaviors for the priority enemies mixed into Struggle waves.
]]

OnInit.final("StruggleSpecials", function(Require)
    Require('AbilityCasting')
    Require('BuffsCommon')
    Require('BuffsWorldStruggle')
    Require('Chain')
    Require('Events')
    Require('SpellTools')
    Require('TimerQueue')

    StruggleSpecials = {}

    local ABYSSAL_HOOK = FourCC('A03C')
    local VOLATILE_RUPTURE = FourCC('A03I')
    local CORROSIVE_MIASMA = FourCC('A03J')
    local HOOK_RANGE = 1800.
    local HOOK_PULL = 700.
    local RUPTURE_RANGE = 350.
    local RUPTURE_RADIUS = 325.
    local MIASMA_RANGE = 1600.
    local MIASMA_RADIUS = 350.
    local MIASMA_DURATION = 6
    local states = setmetatable({}, { __mode = 'k' })

    local definitions = {
        hook = { id = ABYSSAL_HOOK, cooldown = 12. },
        rupture = { id = VOLATILE_RUPTURE, cooldown = 10. },
        miasma = { id = CORROSIVE_MIASMA, cooldown = 14. },
    }

    local function schedule(state, delay, callback, ...)
        if not state.active then return nil end
        local id = TimerQueue:callDelayed(delay, callback, state, ...)
        state.callbacks[#state.callbacks + 1] = id
        return id
    end

    local function valid(state)
        return state.active and UnitAlive(state.source)
    end

    local function distance_between(a, b)
        local dx = GetUnitX(b) - GetUnitX(a)
        local dy = GetUnitY(b) - GetUnitY(a)
        return SquareRoot(dx * dx + dy * dy)
    end

    local function ability_cooldown(source, definition)
        local cooldown = BlzGetUnitAbilityCooldown(source, definition.id, 0)
        if cooldown < 1. then
            cooldown = definition.cooldown
            BlzSetUnitAbilityCooldown(source, definition.id, 0, cooldown)
        end
        return cooldown
    end

    local function update_hook(state, remaining)
        local chain = state.chain
        if not valid(state) or not chain or not UnitAlive(chain:get_target_unit()) then
            if chain then chain:destroy() end
            state.chain = nil
            return
        end

        chain:update()
        remaining = remaining - FPS_32
        if remaining > 0. then
            schedule(state, FPS_32, update_hook, remaining)
        else
            chain:destroy()
            state.chain = nil
        end
    end

    local function land_hook(state, target)
        if not valid(state) or not UnitAlive(target) then return end

        local distance = distance_between(state.source, target)
        local pull = math.min(HOOK_PULL, math.max(0., distance - 250.))
        if pull <= 0. then return end

        if state.chain then state.chain:destroy() end
        state.chain = Chain.create({
            source = Chain.unit(state.source, 100.),
            target = Chain.unit(target, 100.),
            length = distance,
            segments = 5,
            texture = "DRAL",
            leash = false,
            color = { 0.45, 0.1, 0.65, 1. },
        })
        state.chain:yank(pull, 2, 0.75)
        update_hook(state, 1.)
    end

    local function cast_hook(state)
        if not valid(state) then return end
        local target = state.target_provider()
        local retry = 1.

        if target and UnitAlive(target) and distance_between(state.source, target) <= HOOK_RANGE
            and CastSpell(state.source, ABYSSAL_HOOK, 0.75, -1, 1.) then
            FloatingTextUnit("Abyssal Hook", state.source, 2., 70., 0., 11., 190, 80, 255, 0, true)
            schedule(state, 0.75, land_hook, target)
            retry = ability_cooldown(state.source, definitions.hook)
        elseif target then
            IssueTargetOrder(state.source, "attack", target)
        end

        schedule(state, retry, cast_hook)
    end

    local function detonate(state)
        if not valid(state) then return end
        local source = state.source
        local group = CreateGroup()
        MakeGroupInRange(BOSS_ID, group, GetUnitX(source), GetUnitY(source), RUPTURE_RADIUS, Condition(FilterEnemy))

        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",
            GetUnitX(source), GetUnitY(source)))
        for target in each(group) do
            if IsUnitType(target, UNIT_TYPE_HERO) then
                DamageTarget(source, target, BlzGetUnitBaseDamage(source, 0) * 10.,
                    ATTACK_TYPE_NORMAL, MAGIC, "Volatile Rupture")
                Silence:add(source, target):duration(2.)
            end
        end
        DestroyGroup(group)
        KillUnit(source)
    end

    local function cast_rupture(state)
        if not valid(state) then return end
        local target = state.target_provider()
        local retry = 1.

        if target and UnitAlive(target) then
            if distance_between(state.source, target) <= RUPTURE_RANGE
                and CastSpell(state.source, VOLATILE_RUPTURE, 0.8, -1, 1.) then
                FloatingTextUnit("Volatile Rupture", state.source, 2., 70., 0., 11., 255, 90, 30, 0, true)
                schedule(state, 0.8, detonate)
                retry = ability_cooldown(state.source, definitions.rupture)
            else
                IssueTargetOrder(state.source, "attack", target)
            end
        end

        schedule(state, retry, cast_rupture)
    end

    local function miasma_tick(state, zone, remaining)
        if not state.active then
            state.effects[zone.effect] = nil
            DestroyEffect(zone.effect)
            return
        end

        local group = CreateGroup()
        MakeGroupInRange(BOSS_ID, group, zone.x, zone.y, MIASMA_RADIUS, Condition(FilterEnemy))
        for target in each(group) do
            if IsUnitType(target, UNIT_TYPE_HERO) then
                DamageTarget(state.source, target, BlzGetUnitBaseDamage(state.source, 0) * 0.5,
                    ATTACK_TYPE_NORMAL, MAGIC, "Corrosive Miasma")
                CorrosiveMiasmaDebuff:add(state.source, target):duration(1.1)
            end
        end
        DestroyGroup(group)

        remaining = remaining - 1
        if remaining > 0 then
            schedule(state, 1., miasma_tick, zone, remaining)
        else
            state.effects[zone.effect] = nil
            DestroyEffect(zone.effect)
        end
    end

    local function create_miasma(state, indicator, x, y)
        state.effects[indicator] = nil
        DestroyEffect(indicator)
        if not valid(state) then return end

        local zone = {
            x = x,
            y = y,
            effect = AddSpecialEffect("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", x, y),
        }
        BlzSetSpecialEffectScale(zone.effect, 1.5)
        state.effects[zone.effect] = true
        miasma_tick(state, zone, MIASMA_DURATION)
    end

    local function cast_miasma(state)
        if not valid(state) then return end
        local target = state.target_provider()
        local retry = 1.

        if target and UnitAlive(target) and distance_between(state.source, target) <= MIASMA_RANGE
            and CastSpell(state.source, CORROSIVE_MIASMA, 0.75, -1, 1.) then
            local x, y = GetUnitX(target), GetUnitY(target)
            local indicator = AddSpecialEffect("Indicators\\circle.mdl", x, y)
            --BlzSetSpecialEffectScale(indicator, MIASMA_RADIUS / 325.)
            state.effects[indicator] = true
            FloatingTextUnit("Corrosive Miasma", state.source, 2., 70., 0., 11., 80, 255, 80, 0, true)
            schedule(state, 0.75, create_miasma, indicator, x, y)
            retry = ability_cooldown(state.source, definitions.miasma)
        elseif target then
            IssueTargetOrder(state.source, "attack", target)
        end

        schedule(state, retry, cast_miasma)
    end

    local start = {
        hook = cast_hook,
        rupture = cast_rupture,
        miasma = cast_miasma,
    }

    ---@param source unit
    ---@param kind "hook"|"rupture"|"miasma"
    ---@param target_provider fun(): unit?
    function StruggleSpecials.setup(source, kind, target_provider)
        local definition = definitions[kind]
        if not definition then return false end

        UnitAddAbility(source, definition.id)
        local state = {
            source = source,
            kind = kind,
            target_provider = target_provider,
            callbacks = {},
            effects = {},
            active = true,
        }
        states[source] = state
        schedule(state, GetRandomReal(2.5, 5.), start[kind])
        return true
    end

    function StruggleSpecials.cleanup(source)
        local state = states[source]
        if not state then return end

        state.active = false
        for index = 1, #state.callbacks do
            TimerQueue:disableCallback(state.callbacks[index])
        end
        if state.chain then
            state.chain:destroy()
            state.chain = nil
        end
        for effect in pairs(state.effects) do
            DestroyEffect(effect)
        end
        states[source] = nil
    end
end, Debug and Debug.getLine())
