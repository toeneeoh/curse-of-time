OnInit.final("PerfectBeing", function(Require)
    Require('BossSchema')
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")

    local EXTERMINATION = Spell.define("A073")
    local IMPLOSION = Spell.define("A07F")
    local EXPLOSION = Spell.define("A07Q")
    local PROTECTED_EXISTENCE = Spell.define("A07X")

    local OFFENSIVE_SPELLS = {
        EXTERMINATION.id,
        IMPLOSION.id,
        EXPLOSION.id,
    }
    local SHARED_COOLDOWN = 10.
    local TAU = 2. * bj_PI

    ---@param boss unit
    ---@param damage number
    ---@param radius number
    ---@param model string
    ---@param tag string
    local function innerRing(boss, damage, radius, model, tag)
        local x = GetUnitX(boss)
        local y = GetUnitY(boss)

        for i = 0, 6 do
            local angle = bj_PI * i / 3.

            DestroyEffect(AddSpecialEffect(model, x + radius * 0.4 * math.cos(angle), y + radius * 0.4 * math.sin(angle)))
            DestroyEffect(AddSpecialEffect(model, x + radius * 0.8 * math.cos(angle), y + radius * 0.8 * math.sin(angle)))
        end

        local ug = CreateGroup()
        GroupEnumUnitsInRange(ug, x, y, radius, Condition(ishostileEnemy))

        for target in each(ug) do
            DamageTarget(boss, target, damage, ATTACK_TYPE_NORMAL, MAGIC, tag)
        end

        DestroyGroup(ug)
    end

    ---@param boss unit
    ---@param damage number
    ---@param inner_radius number
    ---@param outer_radius number
    ---@param model string
    ---@param tag string
    local function outerRing(boss, damage, inner_radius, outer_radius, model, tag)
        local x = GetUnitX(boss)
        local y = GetUnitY(boss)
        local width = outer_radius - inner_radius

        for i = 0, 10 do
            local angle = bj_PI * i / 5.

            DestroyEffect(AddSpecialEffect(model, x + (inner_radius + width / 6.) * math.cos(angle), y + (inner_radius + width / 6.) * math.sin(angle)))
            DestroyEffect(AddSpecialEffect(model, x + (outer_radius - width / 6.) * math.cos(angle), y + (outer_radius - width / 6.) * math.sin(angle)))
        end

        local ug = CreateGroup()
        GroupEnumUnitsInRange(ug, x, y, outer_radius, Condition(ishostileEnemy))

        for target in each(ug) do
            local dx = GetUnitX(target) - x
            local dy = GetUnitY(target) - y

            if SquareRoot(dx * dx + dy * dy) > inner_radius then
                DamageTarget(boss, target, damage, ATTACK_TYPE_NORMAL, MAGIC, tag)
            end
        end

        DestroyGroup(ug)
    end

    local extermination_missile = {
        selfInteractions = {
            CAT_MoveAutoHeight,
            CAT_Orient2D,
            MISSILE_DISTANCE,
        },
        identifier = "missile",
        visualZ = 75.,
        speed = 1100.,
    }
    extermination_missile.__index = extermination_missile

    ---@param boss unit
    local function dealExterminationDamage(boss)
        local x = GetUnitX(boss)
        local y = GetUnitY(boss)
        local ug = CreateGroup()

        GroupEnumUnitsInRange(ug, x, y, 800., Condition(ishostileEnemy))

        for target in each(ug) do
            local dx = GetUnitX(target) - x
            local dy = GetUnitY(target) - y
            local dist = SquareRoot(dx * dx + dy * dy)
            local damage = 1500000.

            if dist >= 150. then
                damage = damage / (dist / 200.)
            end

            DamageTarget(boss, target, damage, ATTACK_TYPE_NORMAL, MAGIC, EXTERMINATION.tag)
        end

        DestroyGroup(ug)
    end

    ---@param boss unit
    local function showExtermination(boss)
        local x = GetUnitX(boss)
        local y = GetUnitY(boss)

        for i = 0, 17 do
            local angle = TAU * i / 18.
            local missile = setmetatable({
                source = boss,
                owner = GetOwningPlayer(boss),
                x = x,
                y = y,
                dist = 800.,
                vx = extermination_missile.speed * math.cos(angle),
                vy = extermination_missile.speed * math.sin(angle),
                visual = AddSpecialEffect("Abilities\\Spells\\Undead\\CarrionSwarm\\CarrionSwarmMissile.mdl", x, y),
            }, extermination_missile)

            BlzSetSpecialEffectScale(missile.visual, 1.2)
            ALICE_Create(missile)
        end
    end

    ---@param pt PlayerTimer
    local function resolveExtermination(pt)
        if UnitAlive(pt.source) then
            showExtermination(pt.source)
            dealExterminationDamage(pt.source)
        end
    end

    ---@param pt PlayerTimer
    local function resolveImplosion(pt)
        if UnitAlive(pt.source) then
            innerRing(pt.source, 1000000., 400., "Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", IMPLOSION.tag)
        end
    end

    ---@param pt PlayerTimer
    local function resolveExplosion(pt)
        if UnitAlive(pt.source) then
            outerRing(pt.source, 500000., 400., 900., "war3mapImported\\NeutralExplosion.mdx", EXPLOSION.tag)
        end
    end

    ---@param boss unit
    local function startSharedCooldown(boss)
        for _, id in ipairs(OFFENSIVE_SPELLS) do
            BlzStartUnitAbilityCooldown(boss, id, SHARED_COOLDOWN)
        end
    end

    ---@param target unit
    ---@param source unit
    local function castOffensiveSpell(target, source)
        local spell
        local resolve
        local delay

        if math.random(0, 1) == 0 then
            spell = EXTERMINATION
            resolve = resolveExtermination
            delay = 2.5
        elseif UnitDistance(source, target) <= 400. then
            spell = IMPLOSION
            resolve = resolveImplosion
            delay = 1.5
        else
            spell = EXPLOSION
            resolve = resolveExplosion
            delay = 1.5
        end

        if CastSpell(target, spell.id, 1.5, 4, 1.5) then
            if spell == IMPLOSION then
                FloatingTextUnit(spell.tag, target, 3, 70, 0, 12, 68, 68, 255, 0, true)
            elseif spell == EXPLOSION then
                FloatingTextUnit(spell.tag, target, 3, 70, 0, 12, 255, 100, 50, 0, true)
            else
                FloatingTextUnit(spell.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)
            end
            startSharedCooldown(target)

            local pt = TimerList[BOSS_ID]:add(target)
            pt.source = target
            pt:after(delay, resolve)
        end
    end

    function EXTERMINATION.onSetup(u)
        EVENT_ENEMY_AI:register_unit_action(u, castOffensiveSpell)
    end

    do
        local thistype = PROTECTED_EXISTENCE

        local function onStruck(target)
            if CastSpell(target, thistype.id, 1.5, 4, 1.5) then
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 100, 255, 100, 0, true)

                local buff = ProtectedExistenceBuff:get(nil, target)

                if buff then
                    buff:refresh()
                else
                    buff = ProtectedExistenceBuff:add(target, target)
                end

                buff:duration(10.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
