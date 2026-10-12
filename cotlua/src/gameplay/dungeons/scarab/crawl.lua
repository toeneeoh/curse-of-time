-- Development-only exploration slice. Nothing is generated at map startup.
OnInit.final("ScarabCrawl", function(Require)
    Require('ScarabLayout')
    Require('PlayerLifecycle')
    Require('PlayerCamera')
    Require('TimerQueue')
    Require('Events')
    Require('UnitTable')
    Require('Damage')
    Require('ScarabCombat')
    ScarabCrawl = {}
    -- Sight must fit the lamp's useful bright core, not its faint outer glow.
    -- Provisional calibration: native fog uses cells, not a pixel-exact circle.
    ScarabCrawl.vision = {dark = 192, lamp = 384}
    local leave_listeners = {}
    function ScarabCrawl.subscribeLeave(callback)
        leave_listeners[#leave_listeners + 1] = callback
    end
    -- Standard Warcraft doodad models, not the tiny imported pebble mesh.
    -- The prepared editor floor is retained; no runtime terrain texture edits.
    ScarabCrawl.art = {wall = "Doodads\\LordaeronSummer\\Rocks\\Lords_Rock\\Lords_Rock0.mdx", scale = 1.49,
        wall_offset = 48, lamp = "LightYellow30.mdx"}
    -- Existing insect units are visual/attack templates, not new editor objects.
    -- Provisional solo combat values; no XP, loot, respawns, or boss access yet.
    ScarabCrawl.enemies = {
        swarm = {id = FourCC('n0sl'), skin = FourCC('u002'), name = 'Scarab Broodling', health = 40000000, damage = 300000,
            armor = 550, attack_time = 1., speed = 340, range = 90., scale = .65},
        guard = {id = FourCC('n0sl'), skin = FourCC('u002'), name = 'Hive Guard', health = 150000000, damage = 850000,
            armor = 650, attack_time = 1.6, speed = 300, range = 128., scale = 1.05},
        spitter = {id = FourCC('n0ss'), skin = FourCC('u002'), name = 'Tunnel Spitter', health = 60000000, damage = 450000,
            armor = 550, attack_time = 1.4, speed = 300, range = 550., scale = .85,
            projectile = 'Abilities\\Weapons\\ChimaeraAcidMissile\\ChimaeraAcidMissile.mdl'}
    }
    -- Optional natives must bypass strict-global warnings. Reading a missing
    -- global once per rock used to print AND flush the entire log per cleanup.
    local remove_native = rawget(_G, 'BlzRemoveEffect')
    local run, participants, prepared, restoring = nil, {}, false, false
    local area_owner
    function ScarabCrawl.reserveArea(owner)
        local ok, reason = ScarabCrawl.canStart()
        if not ok then return false, reason end
        area_owner = owner
        return true
    end
    function ScarabCrawl.releaseArea(owner)
        if area_owner ~= owner then return false end
        area_owner = nil
        return true
    end
    function ScarabCrawl.canStart()
        if area_owner then return false, 'The cave-kit preview is using the Scarab staging area.' end
        if not prepared then return false, 'The Scarab staging area is not ready.' end
        if restoring then return false, 'The previous Scarab crawl is still closing.' end
        if run then return false, 'A Scarab crawl is already in progress.' end
        return true
    end
    function ScarabCrawl.participantCount()
        local count = 0
        for _ in pairs(participants) do count = count + 1 end
        return count
    end
    local poll
    local cell, width, height = ScarabLayout.cell, ScarabLayout.width, ScarabLayout.height
    local encounters_enabled = true
    local walk, fly = PATHING_TYPE_WALKABILITY, PATHING_TYPE_FLYABILITY
    local function message(pid, text) DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 8, text) end
    local function coords(slot, x, y)
        return slot.x + (x - 21) * cell, slot.y + (y - 25) * cell
    end
    function ScarabCrawl.setPrepared(value)
        if run or restoring or area_owner then return false, "Stop the crawl or preview and wait for cleanup before changing area readiness." end
        prepared = value == true
        return true, prepared and "Scarab staging area marked ready for this lobby." or "Scarab staging area disabled."
    end
    function ScarabCrawl.setEncounters(value)
        if run then return false, "Stop the crawl before changing encounters." end
        encounters_enabled = value == true
        return true, encounters_enabled and "Scarab encounters ON (prototype combat; no rewards)." or "Scarab encounters OFF."
    end
    local function scale_enemy(entry)
        local data, spec = Unit[entry.unit], ScarabCrawl.enemies[entry.state.role]
        -- Naga uses 1 - .1 * party size incoming damage and +200k damage per
        -- player on its second floor. Preserve solo base damage here.
        data.dr = math.max(.4, 1. - .1 * run.party_size)
        data.bonus_damage = spec.damage + 200000 * (run.party_size - 1) - BlzGetUnitBaseDamage(entry.unit, 0)
    end
    local function update_party_size()
        local count = 0
        for _ in pairs(participants) do count = count + 1 end
        -- A run-wide high-water mark: moving apart/leaving cannot weaken packs.
        if count <= run.party_size then return end
        run.party_size = count
        for _, slot in ipairs(run.slots) do
            for _, entry in ipairs(slot.enemies or {}) do if UnitAlive(entry.unit) then scale_enemy(entry) end end
        end
    end
    local function clear_enemies(slot)
        for _, entry in ipairs(slot.enemies or {}) do
            local unit, state = entry.unit, entry.state
            if not state.dead and UnitAlive(unit) then
                state.health = GetWidgetLife(unit) / BlzGetUnitMaxHP(unit)
            else state.dead = true end
            -- Remove, rather than kill: recycling must not trigger rewards/deaths.
            EVENT_ON_UNIT_DEATH:unregister_unit_action(unit, entry.on_death)
            RemoveUnit(unit)
        end
        slot.enemies = {}
    end
    local function spawn_enemies(slot, room)
        slot.enemies = {}
        if not encounters_enabled then return end
        room.encounter = room.encounter or ScarabLayout.encounter(room, room.layout)
        for _, state in ipairs(room.encounter) do
            if not state.dead then
                local spec = ScarabCrawl.enemies[state.role]
                local x, y = coords(slot, state.x, state.y)
                -- u002 is the existing Naga swarm's Carrion Beetle (ucs1 base).
                -- Create with a presentation skin; preserve the attack template.
                local unit = BlzCreateUnitWithSkin(PLAYER_CREEP, spec.id, x, y, state.facing, spec.skin)
                local data = Unit[unit]
                ScarabCombat.prepare(unit, state.role ~= 'spitter')
                data.bonus_hp = data.bonus_hp + spec.health - BlzGetUnitMaxHP(unit)
                data.regen_flat = 0
                BlzSetUnitIntegerField(unit, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
                BlzSetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
                BlzSetUnitArmor(unit, spec.armor)
                data.base_bat = spec.attack_time
                data.ms_flat = spec.speed
                BlzSetUnitWeaponRealField(unit, UNIT_WEAPON_RF_ATTACK_RANGE, 0, spec.range)
                if spec.projectile then
                    BlzSetUnitWeaponStringField(unit, UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART, 0, spec.projectile)
                end
                BlzSetUnitRealField(unit, UNIT_RF_ACQUISITION_RANGE, 650.)
                -- Ghost (Visible) handles melee overlap without bypassing walls.
                BlzSetUnitName(unit, spec.name)
                SetUnitScale(unit, spec.scale, spec.scale, spec.scale)
                SetWidgetLife(unit, spec.health * (state.health or 1))
                -- Enemies cannot wander across recycled buffers; polling leashes them.
                local entry = {unit = unit, state = state, x = x, y = y}
                scale_enemy(entry)
                entry.on_death = function()
                    if state.dead then return end
                    state.dead, state.health = true, 0
                    SetUnitPathing(unit, false)
                    local remaining = 0
                    for _, enemy in ipairs(room.encounter) do if not enemy.dead then remaining = remaining + 1 end end
                    if remaining == 0 then
                        for pid in pairs(slot.members) do message(pid, "Scarab chamber cleared.") end
                    end
                end
                EVENT_ON_UNIT_DEATH:register_unit_action(unit, entry.on_death)
                slot.enemies[#slot.enemies + 1] = entry
            end
        end
    end
    local function remove_effect(effect)
        -- DestroyEffect plays death animations, which can survive buffer reuse.
        if type(remove_native) == 'function' then remove_native(effect)
        else
            BlzSetSpecialEffectAlpha(effect, 0)
            BlzSetSpecialEffectZ(effect, -10000) -- Hide any attached light/particles too.
            DestroyEffect(effect)
        end
    end
    local function clear_effects(slot)
        for _, effect in ipairs(slot.effects) do remove_effect(effect) end
        slot.effects = {}
    end
    function ScarabCrawl.setLamp(pid, enabled)
        local member = participants[pid]
        if not member then return false, "Enter the Scarab crawl before testing a lamp." end
        if enabled == nil then enabled = not member.lamp_enabled end
        member.lamp_enabled = enabled
        if member.lamp then remove_effect(member.lamp); member.lamp = nil end
        if member.arrived then
            BlzSetUnitRealField(member.hero, UNIT_RF_SIGHT_RADIUS,
                enabled and ScarabCrawl.vision.lamp or ScarabCrawl.vision.dark)
            if enabled then member.lamp = AddSpecialEffectTarget(ScarabCrawl.art.lamp, member.hero, 'origin') end
        end
        return true, enabled and "Scarab test lamp ON." or "Scarab test lamp OFF."
    end
    local function release(slot)
        slot.generation = slot.generation + 1
        clear_enemies(slot)
        clear_effects(slot)
        if slot.room then run.room_slots[slot.room] = nil end
        slot.room, slot.layout, slot.ready = nil, nil, false
    end
    local function move(pid, slot, direction)
        local member = participants[pid]
        if not member or member.slot ~= slot or not slot.ready or not UnitAlive(Hero[pid]) then return end
        local portal = direction and slot.layout.portals[direction]
        -- Spawn further inside than the trigger radius so returning never bounces.
        local x, y = portal and portal.x or 21, portal and portal.y or 25
        if direction == 'n' then y = y - 4 elseif direction == 's' then y = y + 4
        elseif direction == 'e' then x = x - 4 elseif direction == 'w' then x = x + 4 end
        x, y = coords(slot, x, y)
        -- MoveHero can apply a regional camera; capture the old view first.
        if not member.camera_captured then
            PreviewPlayerCamera(pid, slot.rect, x, y, true)
            member.camera_captured = true
        end
        MoveHero(pid, x, y)
        if Backpack[pid] then SetUnitXBounded(Backpack[pid], x); SetUnitYBounded(Backpack[pid], y) end
        PreviewPlayerCamera(pid, slot.rect, x, y, true)
        member.arrived, member.entering = true, nil
        SetPlayerLightingOverride(pid, 'blacklight.mdx')
        if member.backpack then BlzSetUnitRealField(member.backpack, UNIT_RF_SIGHT_RADIUS, 0) end
        ScarabCrawl.setLamp(pid, member.lamp_enabled == true)
        local exits = {}
        for _, d in ipairs(ScarabLayout.directions) do if slot.layout.portals[d[1]] then exits[#exits + 1] = string.upper(d[1]) end end
        message(pid, "Scarab chamber " .. slot.room .. " | Exits: " .. table.concat(exits, ", "))
        run.visited[slot.room] = true
        if slot.room == run.approach and not run.approach_found then
            run.approach_found = true
            run.approach_time = run.stopwatch:getElapsed()
            for id in pairs(participants) do
                message(id, "The Scarab's approach has been discovered! Boss access is not implemented yet.")
            end
        end
    end
    local function build(slot, room)
        slot.room, slot.layout, slot.ready = room.id, room.layout, false
        run.room_slots[room.id] = slot
        slot.generation = slot.generation + 1
        -- Restrict camera targets to the chamber, not the entire staging buffer.
        local min_x, min_y, max_x, max_y = width, height, 1, 1
        for index in pairs(slot.layout.floor) do
            local x, y = (index - 1) % width + 1, math.floor((index - 1) / width) + 1
            min_x, min_y, max_x, max_y = math.min(min_x, x), math.min(min_y, y), math.max(max_x, x), math.max(max_y, y)
        end
        local left, bottom = coords(slot, min_x, min_y)
        local right, top = coords(slot, max_x, max_y)
        local inset_x, inset_y = math.min(384, (right - left) * .25), math.min(256, (top - bottom) * .25)
        SetRect(slot.camera_rect, left + inset_x, bottom + inset_y, right - inset_x, top - inset_y)
        local generation, active_run = slot.generation, run
        local function tick()
            if run ~= active_run or generation ~= slot.generation then return end
            -- Delta pathing/art rebuild finishes in this same transition callback,
            -- so no rendered frame shows the old chamber with its rocks removed.
            for y = 1, height do
                for x = 1, width do
                    local cx, cy = coords(slot, x, y)
                    local pathable = slot.layout.floor[(y - 1) * width + x] == true
                    for sy = -16, 16, 32 do for sx = -16, 16, 32 do
                        local px, py = cx + sx, cy + sy
                        local key = (y - 1) * width * 4 + (x - 1) * 4 + (sy + 16) / 16 + (sx + 16) / 32 + 1
                        if not slot.original[key] then
                            slot.original[key] = {px, py, not IsTerrainPathable(px, py, walk), not IsTerrainPathable(px, py, fly)}
                            slot.current[key] = {slot.original[key][3], slot.original[key][4]}
                        end
                        local current = slot.current[key]
                        if current[1] ~= pathable then
                            SetTerrainPathable(px, py, walk, pathable); current[1] = pathable
                        end
                        if current[2] ~= pathable then
                            SetTerrainPathable(px, py, fly, pathable); current[2] = pathable
                        end
                    end end
                end
            end
            -- Every blocked boundary cell needs a visible rock. A global cap
            -- used to skip arbitrary cells, leaving invisible collision edges.
            local walls = slot.layout.walls
            local art, next_wall = ScarabCrawl.art, 1
            local function decorate()
                if run ~= active_run or generation ~= slot.generation then return end
                for _ = 1, #walls do
                    local point = walls[next_wall]
                    if not point then break end
                    local x, y = coords(slot, point.x, point.y)
                    x, y = x + point.nx * art.wall_offset, y + point.ny * art.wall_offset
                    local effect = AddSpecialEffect(art.wall, x, y)
                    BlzSetSpecialEffectScale(effect, art.scale)
                    BlzSetSpecialEffectYaw(effect, next_wall * 2.39996)
                    slot.effects[#slot.effects + 1] = effect
                    next_wall = next_wall + 1
                end
                slot.ready = true
                spawn_enemies(slot, room)
                for pid in pairs(slot.members) do move(pid, slot, participants[pid] and participants[pid].entering) end
            end
            -- No glowing exit effects: illumination comes only from the lamp.
            decorate()
        end
        tick()
    end
    local function attach(pid, room_id, direction)
        local member, target = participants[pid], run.room_slots[room_id]
        local previous = member.slot
        if previous then
            previous.members[pid] = nil
            if not next(previous.members) then release(previous) end
        end
        if not target then
            for _, slot in ipairs(run.slots) do if not slot.room then target = slot; break end end
        end
        assert(target, "Scarab buffer pool exhausted")
        member.slot, member.arrived, member.entering = target, false, direction
        target.members[pid] = true
        if target.room then move(pid, target, direction) else build(target, run.rooms[room_id]) end
    end
    function ScarabCrawl.enter(pid, seed)
        if area_owner then return false, 'Close the cave-kit preview before entering the crawl.' end
        if restoring then return false, "Scarab pathing is still being restored; try again shortly." end
        if not seed then seed = 1 end
        if type(seed) ~= "number" or seed ~= seed or seed % 1 ~= 0 or math.abs(seed) >= 2147483647 then
            return false, "Invalid Scarab seed."
        end
        if pid < 1 or pid > PLAYER_CAP or pid % 1 ~= 0 then return false, "Invalid participant." end
        if not prepared then return false, "Clear/flatten the corner first, then use -scarab ready." end
        if not Hero[pid] or not UnitAlive(Hero[pid]) then return false, "A living hero is required." end
        if participants[pid] then return false, "Already exploring the Scarab crawl." end
        -- Fog is global: warn rather than changing visibility for other players.
        -- Ambient darkness alone cannot conceal enemies when -vision is active.
        if not IsFogEnabled() or not IsFogMaskEnabled() then
            message(pid, '|cffffcc00Fog is disabled: enemies remain visible outside your light. Use -novision to test normal dungeon visibility.|r')
        end
        if not run then
            run = ScarabLayout.generate(seed or 1)
            run.room_slots, run.slots, run.visited, run.party_size = {}, {}, {}, 1
            run.stopwatch = Stopwatch.create(true)
            for _, room in ipairs(run.rooms) do room.layout = ScarabLayout.chamber(room) end
            for _, center in ipairs(ScarabLayout.buffers()) do
                local slot = {x = center.x, y = center.y, members = {}, original = {}, current = {}, effects = {}, generation = 0}
                slot.rect = Rect(slot.x - width * cell / 2, slot.y - height * cell / 2,
                    slot.x + width * cell / 2, slot.y + height * cell / 2)
                slot.camera_rect = Rect(slot.x - 640, slot.y - 640, slot.x + 640, slot.y + 640)
                REGION_DATA[slot.rect] = {vision = slot.camera_rect, hide_minimap = true}
                run.slots[#run.slots + 1] = slot
            end
            local active_run = run
            TimerQueue:callPeriodically(.2, function() return run ~= active_run end, poll)
        end
        participants[pid] = {x = GetUnitX(Hero[pid]), y = GetUnitY(Hero[pid]), hero = Hero[pid], backpack = Backpack[pid],
            sight = BlzGetUnitRealField(Hero[pid], UNIT_RF_SIGHT_RADIUS),
            backpack_sight = Backpack[pid] and BlzGetUnitRealField(Backpack[pid], UNIT_RF_SIGHT_RADIUS)}
        update_party_size()
        attach(pid, run.start)
        return true, "Scarab crawl, seed " .. run.seed .. ". Walk into an exit or use -scarab n/e/s/w. Prototype enemies have no rewards."
    end
    function ScarabCrawl.travel(pid, direction)
        local member = participants[pid]
        if not member or not member.arrived then return false, "Not in a ready Scarab chamber." end
        local portal = member.slot.layout.portals[direction]
        if not portal then return false, "There is no exit in that direction." end
        if not UnitAlive(Hero[pid]) then return false, "A living hero is required." end
        attach(pid, portal.target, portal.opposite)
        return true
    end
    function ScarabCrawl.status()
        if not run then return "No active Scarab crawl." end
        local visited, cleared = 0, 0
        for _ in pairs(run.visited) do visited = visited + 1 end
        for _, room in ipairs(run.rooms) do
            if room.encounter and #room.encounter > 0 then
                local alive = false
                for _, enemy in ipairs(room.encounter) do if not enemy.dead then alive = true; break end end
                if not alive then cleared = cleared + 1 end
            end
        end
        local seconds = math.floor(run.stopwatch:getElapsed())
        local approach = run.approach_found and ("found at " .. math.floor(run.approach_time) .. "s") or "not found"
        return string.format("Scarab %d | %d:%02d | Visited %d/%d | Cleared %d | Party scaling %d | Approach %s",
            run.seed, seconds // 60, seconds % 60, visited, #run.rooms, cleared, run.party_size, approach)
    end
    -- Read-only diagnostics: distinguish overgenerous sight from other reveal
    -- sources/engine fog sampling. No local hiding or targeting-state changes.
    function ScarabCrawl.visibility(pid)
        local member = participants[pid]
        if not member or not member.arrived then return 'Not in a ready Scarab chamber.' end
        local hero, player = member.hero, Player(pid - 1)
        local radius = member.lamp_enabled and ScarabCrawl.vision.lamp or ScarabCrawl.vision.dark
        local lines = {string.format('Scarab visibility | Lamp %s | Intended sight %d | Native sight %.0f | Backpack sight %.0f | Fog %s / Mask %s',
            member.lamp_enabled and 'ON' or 'OFF', radius, BlzGetUnitRealField(hero, UNIT_RF_SIGHT_RADIUS),
            member.backpack and BlzGetUnitRealField(member.backpack, UNIT_RF_SIGHT_RADIUS) or 0,
            IsFogEnabled() and 'ON' or 'OFF', IsFogMaskEnabled() and 'ON' or 'OFF')}
        local enemies = {}
        for index, entry in ipairs(member.slot.enemies or {}) do
            if UnitAlive(entry.unit) then
                local dx, dy = GetUnitX(entry.unit) - GetUnitX(hero), GetUnitY(entry.unit) - GetUnitY(hero)
                enemies[#enemies + 1] = {entry = entry, distance = math.sqrt(dx * dx + dy * dy), index = index}
            end
        end
        table.sort(enemies, function(a, b)
            return a.distance < b.distance or (a.distance == b.distance and a.index < b.index)
        end)
        for i = 1, math.min(6, #enemies) do
            local info = enemies[i]
            lines[#lines + 1] = string.format('%s | Distance %.0f | %s sight radius | %s | Fog sample %.0f',
                ScarabCrawl.enemies[info.entry.state.role].name, info.distance,
                info.distance <= radius and 'INSIDE' or 'OUTSIDE',
                IsUnitVisible(info.entry.unit, player) and 'VISIBLE' or 'HIDDEN',
                BlzGetUnitRealField(info.entry.unit, UNIT_RF_FOG_OF_WAR_SAMPLE_RADIUS))
        end
        return table.concat(lines, '\n')
    end
    function ScarabCrawl.leave(pid, relocate)
        local member = participants[pid]
        if not member then return false end
        local slot = member.slot
        participants[pid] = nil
        slot.members[pid] = nil
        if relocate ~= false and Hero[pid] and UnitAlive(Hero[pid]) then
            MoveHero(pid, member.x, member.y)
            if Backpack[pid] then SetUnitXBounded(Backpack[pid], member.x); SetUnitYBounded(Backpack[pid], member.y) end
        end
        RestorePlayerCameraPreview(pid)
        if member.lamp then remove_effect(member.lamp) end
        BlzSetUnitRealField(member.hero, UNIT_RF_SIGHT_RADIUS, member.sight)
        if member.backpack then BlzSetUnitRealField(member.backpack, UNIT_RF_SIGHT_RADIUS, member.backpack_sight) end
        SetPlayerLightingOverride(pid, nil)
        if not next(slot.members) then release(slot) end
        for _, callback in ipairs(leave_listeners) do callback(pid) end
        return true
    end
    function ScarabCrawl.stop()
        if not run then return end
        local saved_pathing = {}
        for pid = 1, PLAYER_CAP do ScarabCrawl.leave(pid) end
        for _, slot in ipairs(run.slots) do
            release(slot)
            for key, saved in pairs(slot.original) do
                local current = slot.current[key]
                if current[1] ~= saved[3] or current[2] ~= saved[4] then
                    saved_pathing[#saved_pathing + 1] = {saved[1], saved[2], saved[3], saved[4], current[1], current[2]}
                end
            end
            REGION_DATA[slot.rect] = nil
            RemoveRect(slot.rect)
            RemoveRect(slot.camera_rect)
        end
        run.stopwatch:destroy()
        run = nil
        restoring = true
        local index = 1
        local function restore()
            for current = index, math.min(index + 255, #saved_pathing) do
                local saved = saved_pathing[current]
                if saved[5] ~= saved[3] then SetTerrainPathable(saved[1], saved[2], walk, saved[3]) end
                if saved[6] ~= saved[4] then SetTerrainPathable(saved[1], saved[2], fly, saved[4]) end
            end
            index = index + 256
            if index <= #saved_pathing then TimerQueue:callDelayed(.02, restore) else restoring = false end
        end
        restore()
    end
    for pid = 1, PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid, function(id) ScarabCrawl.leave(id, false) end)
    end
    poll = function()
        if not run then return end
        for _, slot in ipairs(run.slots) do
            slot.ai_ticks = (slot.ai_ticks or 0) + 1
            local heroes = {}
            if slot.ai_ticks % 3 == 0 then
                for pid = 1, PLAYER_CAP do
                    local member = participants[pid]
                    if member and member.slot == slot and member.arrived and Hero[pid] == member.hero
                        and UnitAlive(member.hero) then heroes[#heroes + 1] = member.hero end
                end
            end
            for _, entry in ipairs(slot.enemies or {}) do
                if UnitAlive(entry.unit) and not RectContainsCoords(slot.rect, GetUnitX(entry.unit), GetUnitY(entry.unit)) then
                    IssueImmediateOrderById(entry.unit, ORDER_ID_STOP)
                    SetUnitXBounded(entry.unit, entry.x)
                    SetUnitYBounded(entry.unit, entry.y)
                end
                if UnitAlive(entry.unit) and slot.ai_ticks % 3 == 0 then ScarabCombat.pursue(entry.unit, heroes) end
            end
        end
        for pid = 1, PLAYER_CAP do
            local member = participants[pid]
            if member then
                local hero = Hero[pid]
                if not hero or not UnitAlive(hero) then ScarabCrawl.leave(pid, false)
                elseif member.arrived then
                    local x, y = GetUnitX(hero), GetUnitY(hero)
                    if not RectContainsCoords(member.slot.rect, x, y) then
                        ScarabCrawl.leave(pid, false)
                    else
                        for _, d in ipairs(ScarabLayout.directions) do
                            local portal = member.slot.layout.portals[d[1]]
                            if portal then
                                local px, py = coords(member.slot, portal.x, portal.y)
                                if (x - px)^2 + (y - py)^2 <= 100^2 then ScarabCrawl.travel(pid, d[1]); break end
                            end
                        end
                    end
                end
            end
        end
    end
end, Debug and Debug.getLine())
