OnInit.final("Azazoth", function(Require)
    Require("Spells")

    -- model animation indexes
    local CHANNEL_ANIM = 21
    local SPELL_ANIM = 12
    local SPELL_THROW_ANIM = 13
    local STUNNED_ANIM = 23

    local ASTRAL_ANNIHILATION = Spell.define("A00K")
    do
        local thistype = ASTRAL_ANNIHILATION
        local TAU = 2. * bj_PI
        local SAFE_ARC = TAU / 3.
        local RINGS = 4
        local SPOKES = 16
        local RADIUS_STEP = 150.
        local INDICATOR_MODEL = "Indicators\\wide cone.mdx"

        local function angleDiff(a, b)
            return math.atan(math.sin(a - b), math.cos(a - b))
        end

        local function angleInSafeZone(angle, safe_center)
            return math.abs(angleDiff(angle, safe_center)) <= SAFE_ARC * 0.5
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function explosion(pt)
            local x = GetUnitX(pt.source)
            local y = GetUnitY(pt.source)

            local safe_center = pt.safe_angle

            for i = 0, SPOKES - 1 do
                local angle = TAU * i / SPOKES

                if not angleInSafeZone(angle, safe_center) then
                    for j = 1, RINGS do
                        local r = RADIUS_STEP * j
                        DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x + r * math.cos(angle), y + r * math.sin(angle)))
                    end
                end
            end

            local ug = CreateGroup()
            MakeGroupInRange(pt.pid, ug, x, y, 900., Filter(FilterEnemy))

            for target in each(ug) do
                local tx = GetUnitX(target)
                local ty = GetUnitY(target)
                local angle = math.atan(ty - y, tx - x)

                if not angleInSafeZone(angle, safe_center) then
                    DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            end

            DestroyGroup(ug)

            return false
        end

        local function charm_effect(pt)
            pt.dur = pt.dur - 1

            if pt.dur >= 0 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", pt.source, "origin"))

                return true
            end

            DestroyEffect(pt.sfx)
            DestroyEffect(pt.sfx2)
            SetUnitAnimationByIndex(pt.source, SPELL_THROW_ANIM)

            return false
        end

        local function onStruck(target)
            local hp = GetWidgetLife(target)
            local maxhp = BlzGetUnitMaxHP(target)
            local animation_time = MathClamp(hp / maxhp, 0.35, 0.75)

            if CastSpell(target, thistype.id, animation_time * 4., CHANNEL_ANIM, 1.) then
                -- adjust cooldown based on HP
                local cd = 25. + R2I(hp / maxhp * 25.)
                BlzSetUnitAbilityCooldown(target, thistype.id, 0, cd)
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)

                local pt = TimerList[BOSS_ID]:add()
                pt.dmg = 2000000.
                pt.source = target
                pt.safe_angle = GetRandomReal(0., TAU)
                pt:after(animation_time * 4, explosion)

                local x = GetUnitX(target)
                local y = GetUnitY(target)
                local telegraph = TimerList[BOSS_ID]:add()
                telegraph.source = target
                telegraph.dur = 4
                telegraph.sfx = AddSpecialEffect(INDICATOR_MODEL, x, y)
                BlzSetSpecialEffectYaw(telegraph.sfx, pt.safe_angle - bj_PI * 2 / 3)
                BlzSetSpecialEffectScale(telegraph.sfx, 0.8)
                telegraph.sfx2 = AddSpecialEffect(INDICATOR_MODEL, x, y)
                BlzSetSpecialEffectYaw(telegraph.sfx2, pt.safe_angle + bj_PI * 2 / 3)
                BlzSetSpecialEffectScale(telegraph.sfx2, 0.8)
                telegraph:startLoop(animation_time, charm_effect)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    ASTRAL_FREEZE = Spell.define('A01B')
    do
        local thistype = ASTRAL_FREEZE
        local INDICATOR_MODEL = "Indicators\\line open ended.mdx"

        function thistype.effect(pt)
            local ug = CreateGroup()
            local playerBonus = 0
            local x = GetUnitX(pt.source)
            local y = GetUnitY(pt.source)

            if pt.pid ~= BOSS_ID then
                playerBonus = 20
            else
                PauseUnit(pt.source, false)
            end

            for i = 1, 8 do
                for i2 = -1, 1 do
                    local x2 = x + (150 * i) * math.cos(bj_DEGTORAD * (pt.angle + 40 * i2))
                    local y2 = y + (150 * i) * math.sin(bj_DEGTORAD * (pt.angle + 40 * i2))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", x2, y2))
                    if i2 == 0 and playerBonus > 0 then
                        GroupEnumUnitsInRangeEx(pt.pid, ug, x2, y2, 130. + playerBonus, Condition(FilterEnemy))
                        playerBonus = playerBonus + 40
                    else
                        GroupEnumUnitsInRangeEx(pt.pid, ug, x2, y2, 130., Condition(FilterEnemy))
                    end
                end
            end

            for target in each(ug) do
                DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function charm_effect(pt)
            pt.dur = pt.dur - 1

            if pt.dur >= 0 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", pt.source, "origin"))

                return true
            end

            DestroyEffect(pt.sfx)
            DestroyEffect(pt.sfx2)
            DestroyEffect(pt.sfx3)
            SetUnitAnimationByIndex(pt.source, SPELL_THROW_ANIM)

            return false
        end

        local function onStruck(target)
            local hp = GetWidgetLife(target)
            local maxhp = BlzGetUnitMaxHP(target)
            local animation_time = MathClamp(hp / maxhp, 0.35, 0.75)

            if CastSpell(target, thistype.id, animation_time * 4, CHANNEL_ANIM, 1.) then
                -- adjust cooldown based on HP
                local cd = 15. + R2I(hp / maxhp * 15.)
                BlzSetUnitAbilityCooldown(target, thistype.id, 0, cd)
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)

                local pt = TimerList[BOSS_ID]:add()
                pt.source = target
                pt.dmg = 4000000.
                pt.angle = GetUnitFacing(target)
                pt:after(animation_time * 4, thistype.effect)

                local x = GetUnitX(target)
                local y = GetUnitY(target)
                local telegraph = TimerList[BOSS_ID]:add()
                telegraph.dur = 4
                telegraph.source = target
                telegraph.sfx = AddSpecialEffect(INDICATOR_MODEL, x, y)
                BlzSetSpecialEffectYaw(telegraph.sfx, bj_DEGTORAD * (pt.angle))
                telegraph.sfx2 = AddSpecialEffect(INDICATOR_MODEL, x, y)
                BlzSetSpecialEffectYaw(telegraph.sfx2, bj_DEGTORAD * (pt.angle + 40.))
                telegraph.sfx3 = AddSpecialEffect(INDICATOR_MODEL, x, y)
                BlzSetSpecialEffectYaw(telegraph.sfx3, bj_DEGTORAD * (pt.angle - 40.))
                telegraph:startLoop(animation_time, charm_effect)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local ASTRAL_SHIELD = Spell.define("A01C")
    do
        local thistype = ASTRAL_SHIELD

        local function onStruck(target)
            if CastSpell(target, thistype.id, 1., SPELL_ANIM, 1.) then
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)
                local buff = AstralShieldBuff:get(nil, target)
                if buff then
                    buff:refresh()
                else
                    buff = AstralShieldBuff:add(target, target)
                end
                buff:duration(13.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local ASTRAL_PRISON = Spell.define("A00X")
    do
        local thistype = ASTRAL_PRISON
        local HP_PER_HERO = 25
        local SPIRE_SPAWN_RADIUS = 500.
        local ANGLE_FACING_DOWN = 306.

        local function on_death()
            AstralChainsDebuff:removeAll()
            AstralPrisonDebuff:removeAll()
        end

        local function onStruck(target)
            if CastSpell(target, thistype.id, 1., SPELL_ANIM, 1.) then
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)
                local angle = math.random() * 2 * bj_PI

                local buff = AstralPrisonDebuff:add(target, target)
                buff:duration(60.)
                buff.spire = CreateUnit(PLAYER_BOSS, FourCC('nTOM'), GetUnitX(target) + SPIRE_SPAWN_RADIUS * math.cos(angle), GetUnitY(target) + SPIRE_SPAWN_RADIUS * math.sin(angle), ANGLE_FACING_DOWN)
                SetUnitAnimation(buff.spire, "birth")

                local nearby_heroes = 1
                local total_hp = HP_PER_HERO * nearby_heroes
                BlzSetUnitMaxHP(buff.spire, total_hp)
                SetWidgetLife(buff.spire, total_hp)
                Unit[buff.spire].hit_based_health = true

                EVENT_ON_UNIT_DEATH:register_unit_action(buff.spire, on_death)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, on_death)
        end
    end

    local ASTRAL_CHAINS = Spell.define("A016")
    do
        local thistype = ASTRAL_CHAINS
        local INDICATOR = "Indicators\\circle.mdl"
        local CHAIN_IMPALE = "Chain Impale.mdx"

        local valid_chain_target = function(object, player)
            return UnitAlive(object) and IsUnitEnemy(object, player) and not AstralChainsDebuff:has(nil, object)
        end

        local function apply_debuff(source, target)
            if UnitAlive(source) then
                AstralChainsDebuff:add(source, target)
            end
        end

        local function spike(sfx, x, y, spire)
            local nearby_heroes = ALICE_EnumObjectsInRange(x, y, 100., "hero", valid_chain_target, PLAYER_BOSS)

            if #nearby_heroes > 0 then
                local target = nearby_heroes[1]
                DamageTarget(spire, target, BlzGetUnitMaxHP(target) * 0.10, ATTACK_TYPE_NORMAL, MAGIC, "Astral Chains")
                TimerQueue:callDelayed(1., apply_debuff, spire, target)
            end

            DestroyEffect(sfx)
            sfx = AddSpecialEffect(CHAIN_IMPALE, x, y)
            BlzSetSpecialEffectScale(sfx, 2.0)
            DestroyEffect(sfx)
        end

        local function periodic(u)
            if UnitAlive(u) then
                BlzStartUnitAbilityCooldown(u, thistype.id, BlzGetUnitAbilityCooldown(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1))

                local nearby_heroes = ALICE_EnumObjectsInRange(GetUnitX(u), GetUnitY(u), 1500., "hero", valid_chain_target, PLAYER_BOSS)

                if #nearby_heroes > 0 then
                    local hero = nearby_heroes[math.random(1, #nearby_heroes)]
                    local x, y = GetUnitX(hero), GetUnitY(hero)
                    local sfx = AddSpecialEffect(INDICATOR, x, y)
                    BlzSetSpecialEffectScale(sfx, 0.2)

                    TimerQueue:callDelayed(0.75, spike, sfx, x, y, u)
                end

                TimerQueue:callDelayed(10., periodic, u)
            end
        end

        function thistype.onSetup(u)
            TimerQueue:callDelayed(3.0, periodic, u)
        end
    end

    local ASTRAL_CAPTURE = Spell.define("A01D")
    do
        local thistype = ASTRAL_CAPTURE
        local STAND_WORK_ANIM = 1

        local valid_capture_target = function(object, player)
            return UnitAlive(object) and IsUnitEnemy(object, player) and AstralChainsDebuff:has(nil, object)
        end

        local function periodic(u)
            if UnitAlive(u) then
                BlzStartUnitAbilityCooldown(u, thistype.id, BlzGetUnitAbilityCooldown(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1))
                SetUnitAnimationByIndex(u, STAND_WORK_ANIM)
                DelayAnimation(BOSS_ID, u, 1.5, 0, 1., true)
                SoundHandler("Buildings\\Undead\\SlaughterHouse\\SlaughterHouseWhat1.flac", true, nil, u)
                SetUnitTimeScale(u, 1.5)

                local heroes = ALICE_EnumObjectsInRange(GetUnitX(u), GetUnitY(u), 1500., "hero", valid_capture_target, PLAYER_BOSS, u)

                for _, hero in ipairs(heroes) do
                    local buff = AstralChainsDebuff:get(nil, hero)

                    if buff then
                        buff.chain:yank(200., 2)
                        buff:spawn_soul()
                        buff.dist = math.max(100., buff.dist - 200.)
                        UnitRefreshBuff(hero, buff)
                        DamageTarget(u, hero, BlzGetUnitMaxHP(hero) * 0.06, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                TimerQueue:callDelayed(10., periodic, u)
            end
        end

        function thistype.onSetup(u)
            TimerQueue:callDelayed(5.0, periodic, u)
        end
    end

end, Debug and Debug.getLine())
