-- Development encounter only: no automatic spawn, access cost, or rewards.
OnInit.final('ScarabBoss', function(Require)
    Require('ScarabCrawl')
    Require('ScarabCombat')
    Require('RuntimeSpells')
    Require('PlayerCamera')
    Require('PlayerLifecycle')
    Require('TimerQueue')
    Require('Events')
    Require('UnitTable')
    Require('Damage')
    Require('BuffSystem')

    ScarabBoss = {}
    local step = .1
    local encounter
    local SLAM, BROOD = 'scarab.frontal_slam', 'scarab.brood_discharge'
    -- Provisional values for testing with max-upgrade Azazoth equipment.
    ScarabBoss.spec = {health = 1500000000, damage = 1500000, armor = 650,
        sting_damage = 4000000, sting_range = 1000, sting_half_angle = math.pi / 3,
        sting_warning = 1.5, sting_interval = 8, brood_interval = 22, brood_cap = 12,
        reset_grace = 5, camera_inset = 850}

    RuntimeSpells.define(SLAM, {
        name = 'Frontal Slam', icon = 'ReplaceableTextures\\CommandButtons\\BTNImpale.blp', position = 0,
        cooldown = ScarabBoss.spec.sting_interval, range = ScarabBoss.spec.sting_range,
        description = function()
            local spec = ScarabBoss.spec
            return string.format('After a |cffffcc00%.1f|r second warning, slams a |cffffcc00120-degree|r cone reaching |cffffcc00%d|r units, dealing |cffffcc00%.0f|r spell damage.\nThe cone does not follow its target. Move behind the Scarab or outside the marked area.',
                spec.sting_warning, spec.sting_range, spec.sting_damage)
        end,
        remaining = function(_, e) return e.active and not e.dead and math.max(0, e.next_sting - e.time) or 0 end,
    })
    RuntimeSpells.define(BROOD, {
        name = 'Brood Discharge', icon = 'ReplaceableTextures\\CommandButtons\\BTNLocustSwarm.blp', position = 1,
        cooldown = ScarabBoss.spec.brood_interval,
        description = function()
            return string.format('After a |cffffcc002|r second wind-up, releases up to |cffffcc006|r Scarab Broodlings. At most |cffffcc00%d|r can be alive at once.\nBroodlings pursue players throughout the arena. Killing them makes room for later waves.', ScarabBoss.spec.brood_cap)
        end,
        remaining = function(_, e) return e.active and not e.dead and math.max(0, e.next_brood - e.time) or 0 end,
    })

    local function animate(e, animation)
        SetUnitAnimation(e.unit, animation)
    end

    function ScarabBoss.inCone(x, y, origin_x, origin_y, angle)
        local dx, dy = x - origin_x, y - origin_y
        local spec = ScarabBoss.spec
        if dx * dx + dy * dy > spec.sting_range ^ 2 then return false end
        if dx == 0 and dy == 0 then return true end
        return (dx * math.cos(angle) + dy * math.sin(angle)) / math.sqrt(dx * dx + dy * dy)
            >= math.cos(spec.sting_half_angle)
    end

    local function inside(e, unit)
        return GetUnitX(unit) >= e.min_x + 128 and GetUnitX(unit) <= e.max_x - 128
            and GetUnitY(unit) >= e.min_y + 128 and GetUnitY(unit) <= e.max_y - 128
    end
    local function message(e, text)
        for pid in pairs(e.members) do DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 8, text) end
    end
    local function remove_effect(effect)
        if not effect then return end
        BlzSetSpecialEffectAlpha(effect, 0)
        DestroyEffect(effect)
    end
    local function clear_cast(e)
        if e.cast then remove_effect(e.cast.indicator); e.cast = nil end
        if UnitAlive(e.unit) then PauseUnit(e.unit, false) end
    end
    local function clear_brood(e)
        for _, unit in ipairs(e.brood) do RemoveUnit(unit) end
        e.brood = {}
    end
    local function configure(unit, health, damage, armor, speed)
        local data = Unit[unit]
        data.bonus_hp = data.bonus_hp + health - BlzGetUnitMaxHP(unit)
        data.bonus_damage = damage - BlzGetUnitBaseDamage(unit, 0)
        data.regen_flat, data.regen_max = 0, 0
        data.ms_flat, data.base_bat = speed, 1.6
        BlzSetUnitIntegerField(unit, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
        BlzSetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
        BlzSetUnitArmor(unit, armor)
        -- Retain template collision; the purported collision-size field is not
        -- a Warcraft constant. Do not disable terrain pathing as a substitute.
        SetWidgetLife(unit, health)
    end
    local function scale(e)
        -- Same incoming-damage convention as the crawl/Naga; high-water mark
        -- persists for a pull, but resets between genuinely abandoned attempts.
        local spec, data = ScarabBoss.spec, Unit[e.unit]
        data.dr = math.max(.4, 1 - .1 * e.party_size)
        data.bonus_damage = spec.damage * (1 + .2 * (e.party_size - 1)) - BlzGetUnitBaseDamage(e.unit, 0)
        for _, unit in ipairs(e.brood) do
            if UnitAlive(unit) then
                Unit[unit].dr = data.dr
                Unit[unit].bonus_damage = 300000 + 200000 * (e.party_size - 1) - BlzGetUnitBaseDamage(unit, 0)
            end
        end
    end
    local function reset(e)
        clear_cast(e)
        clear_brood(e)
        Buff.dispelAll(e.unit, true)
        IssueImmediateOrder(e.unit, 'stop')
        SetUnitXBounded(e.unit, e.x); SetUnitYBounded(e.unit, e.y)
        SetWidgetLife(e.unit, BlzGetUnitMaxHP(e.unit))
        UnitAddAbility(e.unit, ABIL_AVUL)
        e.active, e.time, e.empty_time, e.party_size = false, 0, 0, 1
        e.next_ai = 0
        PauseUnit(e.unit, true)
        e.next_sting, e.next_brood = ScarabBoss.spec.sting_interval, ScarabBoss.spec.brood_interval
        scale(e)
        animate(e, 'stand')
        message(e, 'The Scarab returns to its nest. The encounter has reset.')
    end
    local function targets(e)
        local result = {}
        for pid = 1, PLAYER_CAP do
            local member = e.members[pid]
            local hero = Hero[pid]
            if member and hero == member.hero and UnitAlive(hero) and inside(e, hero)
                and GetUnitAbilityLevel(hero, ABIL_AVUL) == 0 then
                result[#result + 1] = hero
            end
        end
        return result
    end
    local function begin_sting(e, target)
        local x, y = GetUnitX(e.unit), GetUnitY(e.unit)
        local angle = math.atan(GetUnitY(target) - y, GetUnitX(target) - x)
        -- Freeze direction/origin at warning time. It does not track the victim.
        PauseUnit(e.unit, true)
        BlzSetUnitFacingEx(e.unit, angle * 180 / math.pi)
        local indicator = AddSpecialEffect('Indicators\\wide cone.mdx', x, y)
        BlzSetSpecialEffectYaw(indicator, angle)
        -- Same asset as Azazoth: roughly +/-60 degrees and a 1,100-unit
        -- decorative outer edge. Match gameplay rather than a guessed 60° cone.
        BlzSetSpecialEffectScale(indicator, ScarabBoss.spec.sting_range / 1100.)
        BlzSetSpecialEffectColor(indicator, 255, 80, 40)
        animate(e, 'spell slam')
        e.cast = {kind = 'sting', remaining = ScarabBoss.spec.sting_warning,
            x = x, y = y, angle = angle, indicator = indicator}
        message(e, '|cffff8040Frontal Slam — move out of the cone!|r')
    end
    local function begin_brood(e)
        PauseUnit(e.unit, true)
        animate(e, 'spell throw')
        e.cast = {kind = 'brood', remaining = 2.}
        message(e, '|cffffcc00The Scarab is releasing its brood!|r')
    end
    local function resolve_cast(e, heroes)
        local cast = e.cast
        if cast.kind == 'sting' then
            for _, hero in ipairs(heroes) do
                if ScarabBoss.inCone(GetUnitX(hero), GetUnitY(hero), cast.x, cast.y, cast.angle) then
                    DamageTarget(e.unit, hero, ScarabBoss.spec.sting_damage,
                        ATTACK_TYPE_NORMAL, MAGIC, 'Frontal Slam')
                end
            end
        else
            -- Cull dead/removed summons before applying the hard population cap.
            local alive = {}
            for _, unit in ipairs(e.brood) do
                if UnitAlive(unit) then alive[#alive + 1] = unit else RemoveUnit(unit) end
            end
            e.brood = alive
            local count = math.min(6, ScarabBoss.spec.brood_cap - #alive)
            for index = 1, count do
                local angle = index * math.pi / 3
                local unit = BlzCreateUnitWithSkin(PLAYER_CREEP, FourCC('n0sl'),
                    e.x + 400 * math.cos(angle), e.y + 400 * math.sin(angle), angle * 180 / math.pi, FourCC('u002'))
                configure(unit, 40000000, 300000, 550, 340)
                ScarabCombat.prepare(unit, true)
                BlzSetUnitName(unit, 'Scarab Broodling')
                e.brood[#e.brood + 1] = unit
                if #heroes > 0 then IssueTargetOrder(unit, 'attack', heroes[(index - 1) % #heroes + 1]) end
            end
            scale(e)
        end
        clear_cast(e)
        ResetUnitAnimation(e.unit)
    end
    local function poll(e)
        -- TimerQueue invokes callbacks once before checking their stop condition.
        if encounter ~= e then return end
        for pid = 1, PLAYER_CAP do
            local member = e.members[pid]
            if member and (Hero[pid] ~= member.hero or not UnitAlive(member.hero) or not inside(e, member.hero)) then
                ScarabBoss.leave(pid, false)
            end
        end
        if e.dead then return end
        if not UnitAlive(e.unit) then
            e.dead, e.active = true, false
            clear_cast(e); clear_brood(e)
            message(e, 'Scarab prototype defeated. Rewards are not enabled.')
            return
        end
        local heroes = targets(e)
        if e.active then
            e.party_size = math.max(e.party_size, #heroes, 1)
            scale(e)
            e.empty_time = #heroes == 0 and e.empty_time + step or 0
            if e.empty_time >= ScarabBoss.spec.reset_grace or not inside(e, e.unit) then reset(e); return end
            e.time = e.time + step
            if e.cast then
                e.cast.remaining = e.cast.remaining - step
                if e.cast.remaining <= .00001 then resolve_cast(e, heroes) end
            elseif #heroes > 0 then
                if e.time >= e.next_brood then
                    e.next_brood = e.time + ScarabBoss.spec.brood_interval
                    begin_brood(e)
                elseif e.time >= e.next_sting then
                    e.next_sting = e.time + ScarabBoss.spec.sting_interval
                    begin_sting(e, heroes[1])
                else ScarabCombat.pursue(e.unit, heroes) end
            end
            for _, unit in ipairs(e.brood) do
                if UnitAlive(unit) and not inside(e, unit) then
                    SetUnitXBounded(unit, e.x); SetUnitYBounded(unit, e.y)
                end
                if UnitAlive(unit) and e.time >= (e.next_ai or 0) then ScarabCombat.pursue(unit, heroes) end
            end
            if e.time >= (e.next_ai or 0) then e.next_ai = e.time + .5 end
        end
    end

    function ScarabBoss.enter(pid)
        if type(pid) ~= 'number' or pid % 1 ~= 0 or pid < 1 or pid > PLAYER_CAP then
            return false, 'Invalid participant.'
        end
        if not Hero[pid] or not UnitAlive(Hero[pid]) then return false, 'A living hero is required.' end
        local arena = rawget(_G, 'gg_rct_Scarab_Boss_Arena')
        if not arena then return false, 'The saved Scarab boss arena region is missing.' end
        if encounter and encounter.members[pid] then return false, 'Already in the Scarab arena.' end
        if encounter and encounter.dead then return false, 'Stop the defeated prototype before starting another test.' end
        -- For now testing is independent of crawl access. Restore its old view
        -- and location first; never leave a stale crawl member polling this hero.
        ScarabCrawl.leave(pid)
        if not encounter then
            local x, y = GetRectCenterX(arena), GetRectCenterY(arena)
            local e = {x = x, y = y, min_x = GetRectMinX(arena), max_x = GetRectMaxX(arena),
                min_y = GetRectMinY(arena), max_y = GetRectMaxY(arena), members = {}, brood = {},
                party_size = 1, time = 0, last_x = x, last_y = y}
            local inset = ScarabBoss.spec.camera_inset
            e.camera = Rect(e.min_x + inset, e.min_y + inset, e.max_x - inset, e.max_y - inset)
            REGION_DATA[e.camera] = {vision = e.camera, hide_minimap = true}
            -- Use the existing boss object directly: its model owns selection,
            -- targeting, movement and attack animations. No attached proxy.
            e.unit = CreateUnit(PLAYER_CREEP, FourCC('U000'), x, y, 270)
            configure(e.unit, ScarabBoss.spec.health, ScarabBoss.spec.damage, ScarabBoss.spec.armor, 260)
            ScarabCombat.prepare(e.unit, false)
            BlzSetUnitWeaponRealField(e.unit, UNIT_WEAPON_RF_ATTACK_RANGE, 0, 170.)
            BlzSetUnitRealField(e.unit, UNIT_RF_ACQUISITION_RANGE, 1800.)
            BlzSetUnitName(e.unit, 'Scarab (Encounter Prototype)')
            encounter = e
            RuntimeSpells.bind(e.unit, {SLAM, BROOD}, e)
            reset(e)
            TimerQueue:callPeriodically(step, function()
                return encounter ~= e or (e.dead and not next(e.members))
            end, poll, e)
        end
        local e, hero = encounter, Hero[pid]
        e.members[pid] = {hero = hero, x = GetUnitX(hero), y = GetUnitY(hero)}
        MoveHero(pid, e.x, e.min_y + 650)
        if Backpack[pid] then SetUnitXBounded(Backpack[pid], e.x); SetUnitYBounded(Backpack[pid], e.min_y + 650) end
        PreviewPlayerCamera(pid, e.camera, e.x, e.min_y + 650, true)
        return true, 'Scarab arena ready. Use -scarabboss fight when everyone is ready. No rewards or access cost.'
    end
    function ScarabBoss.fight(pid)
        local e = encounter
        if not e or not e.members[pid] or e.dead or not UnitAlive(e.members[pid].hero)
            or not inside(e, e.members[pid].hero) then return false, 'Enter the arena with a living hero first.' end
        if e.active then return false, 'The encounter is already active.' end
        e.active, e.party_size = true, math.max(1, #targets(e))
        scale(e)
        UnitRemoveAbility(e.unit, ABIL_AVUL)
        ResetUnitAnimation(e.unit)
        PauseUnit(e.unit, false)
        IssueTargetOrder(e.unit, 'attack', e.members[pid].hero)
        return true, 'Scarab encounter started.'
    end
    function ScarabBoss.previewAnimation(pid, name)
        local e = encounter
        if not e or not e.members[pid] or e.active or e.dead then
            return false, 'Animation preview requires a staged Scarab arena.'
        end
        local animations = {
            stand = 'stand', walk = 'walk', spell = 'spell',
            slam = 'spell slam', throw = 'spell throw', channel = 'stand channel',
        }
        local animation = animations[name]
        if not animation then return false, 'Use -scarabboss anim stand / walk / spell / slam / throw / channel.' end
        animate(e, animation)
        return true, 'Scarab animation preview: ' .. name .. '.'
    end
    function ScarabBoss.leave(pid, relocate)
        local e = encounter
        local member = e and e.members[pid]
        if not member then return false end
        e.members[pid] = nil
        RestorePlayerCameraPreview(pid)
        if relocate ~= false and Hero[pid] == member.hero and UnitAlive(member.hero) then
            MoveHero(pid, member.x, member.y)
            if Backpack[pid] then SetUnitXBounded(Backpack[pid], member.x); SetUnitYBounded(Backpack[pid], member.y) end
        end
        return true
    end
    function ScarabBoss.stop()
        local e = encounter
        if not e then return end
        for pid = 1, PLAYER_CAP do ScarabBoss.leave(pid) end
        encounter = nil
        clear_cast(e); clear_brood(e)
        RuntimeSpells.unbind(e.unit)
        RemoveUnit(e.unit)
        REGION_DATA[e.camera] = nil; RemoveRect(e.camera)
    end
    function ScarabBoss.status()
        local e = encounter
        if not e then return 'No Scarab boss prototype is running.' end
        return string.format('Scarab: %s | %.1fs | Party scaling %d | Brood %d',
            e.dead and 'defeated' or e.active and 'fighting' or 'staged', e.time, e.party_size, #e.brood)
    end
    for pid = 1, PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid, function(id) ScarabBoss.leave(id, false) end)
    end
end, Debug and Debug.getLine())
