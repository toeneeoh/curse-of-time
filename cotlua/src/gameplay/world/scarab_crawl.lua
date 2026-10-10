-- Development-only exploration slice. Nothing is generated at map startup.
OnInit.final("ScarabCrawl", function(Require)
    Require('ScarabLayout')
    Require('PlayerLifecycle')
    Require('PlayerCamera')
    Require('TimerQueue')
    Require('Events')
    ScarabCrawl = {}
    -- Standard Warcraft doodad models, not the tiny imported pebble mesh.
    -- The prepared editor floor is retained; no runtime terrain texture edits.
    ScarabCrawl.art = {wall = "Doodads\\LordaeronSummer\\Rocks\\Lords_Rock\\Lords_Rock0.mdx", scale = 1.7,
        lamp = "LightYellow30.mdx"}
    -- Optional natives must bypass strict-global warnings. Reading a missing
    -- global once per rock used to print AND flush the entire log per cleanup.
    local remove_native = rawget(_G, 'BlzRemoveEffect')
    local run, participants, prepared, restoring = nil, {}, false, false
    local poll
    local cell, width, height = ScarabLayout.cell, ScarabLayout.width, ScarabLayout.height
    local walk, fly = PATHING_TYPE_WALKABILITY, PATHING_TYPE_FLYABILITY
    local function message(pid, text) DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 8, text) end
    local function coords(slot, x, y)
        return slot.x + (x - 21) * cell, slot.y + (y - 25) * cell
    end
    function ScarabCrawl.setPrepared(value)
        if run or restoring then return false, "Stop the crawl and wait for cleanup before changing area readiness." end
        prepared = value == true
        return true, prepared and "Scarab staging area marked ready for this lobby." or "Scarab staging area disabled."
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
            BlzSetUnitRealField(member.hero, UNIT_RF_SIGHT_RADIUS, enabled and 700 or 192)
            if enabled then member.lamp = AddSpecialEffectTarget(ScarabCrawl.art.lamp, member.hero, 'origin') end
        end
        return true, enabled and "Scarab test lamp ON." or "Scarab test lamp OFF."
    end
    local function release(slot)
        slot.generation = slot.generation + 1
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
            PreviewPlayerCamera(pid, slot.rect, x, y)
            member.camera_captured = true
        end
        MoveHero(pid, x, y)
        if Backpack[pid] then SetUnitXBounded(Backpack[pid], x); SetUnitYBounded(Backpack[pid], y) end
        PreviewPlayerCamera(pid, slot.rect, x, y)
        member.arrived, member.entering = true, nil
        SetPlayerLightingOverride(pid, 'blacklight.mdx')
        if member.backpack then BlzSetUnitRealField(member.backpack, UNIT_RF_SIGHT_RADIUS, 0) end
        ScarabCrawl.setLamp(pid, member.lamp_enabled == true)
        local exits = {}
        for _, d in ipairs(ScarabLayout.directions) do if slot.layout.portals[d[1]] then exits[#exits + 1] = string.upper(d[1]) end end
        message(pid, "Scarab chamber " .. slot.room .. " | Exits: " .. table.concat(exits, ", "))
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
        local generation, active_run, row = slot.generation, run, 1
        local function tick()
            if run ~= active_run or generation ~= slot.generation then return end
            for y = row, row do
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
            row = row + 1
            if row <= height then TimerQueue:callDelayed(.02, tick); return end
            -- Every blocked boundary cell needs a visible rock. A global cap
            -- used to skip arbitrary cells, leaving invisible collision edges.
            local walls = slot.layout.walls
            local art, next_wall = ScarabCrawl.art, 1
            local function decorate()
                if run ~= active_run or generation ~= slot.generation then return end
                for _ = 1, 6 do
                    local point = walls[next_wall]
                    if not point then break end
                    local x, y = coords(slot, point.x, point.y)
                    local effect = AddSpecialEffect(art.wall, x, y)
                    BlzSetSpecialEffectScale(effect, art.scale)
                    BlzSetSpecialEffectYaw(effect, next_wall * 2.39996)
                    slot.effects[#slot.effects + 1] = effect
                    next_wall = next_wall + 1
                end
                if next_wall <= #walls then TimerQueue:callDelayed(.02, decorate); return end
                slot.ready = true
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
        if restoring then return false, "Scarab pathing is still being restored; try again shortly." end
        if not seed then seed = 1 end
        if type(seed) ~= "number" or seed ~= seed or seed % 1 ~= 0 or math.abs(seed) >= 2147483647 then
            return false, "Invalid Scarab seed."
        end
        if pid < 1 or pid > PLAYER_CAP or pid % 1 ~= 0 then return false, "Invalid participant." end
        if not prepared then return false, "Clear/flatten the corner first, then use -scarab ready." end
        if not Hero[pid] or not UnitAlive(Hero[pid]) then return false, "A living hero is required." end
        if participants[pid] then return false, "Already exploring the Scarab crawl." end
        if not run then
            run = ScarabLayout.generate(seed or 1)
            run.room_slots, run.slots = {}, {}
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
        attach(pid, run.start)
        return true, "Generating Scarab crawl, seed " .. run.seed .. ". Walk into an exit or use -scarab n/e/s/w."
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
