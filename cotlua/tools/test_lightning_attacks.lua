-- Offline checks of actual spell helpers against the map's binary object data.
-- These do not establish native rendering, sound parity, or multiplayer safety.
local env = setmetatable({}, {__index = _G})
local _ENV = env
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local data = file:read('*a')
    file:close()
    return data
end
local map = arg[1] or 'B:/cothub/builder/CoTN-RPG-1.36.w3x'
local records = {}
local function parse(path)
    local data, offset = read(path), 1
    local function int()
        local value
        value, offset = string.unpack('<i4', data, offset)
        return value
    end
    local function raw()
        local value = data:sub(offset, offset + 3)
        offset = offset + 4
        return value
    end
    local version = int()
    for _ = 1, 2 do
        local count = int()
        for _ = 1, count do
            local base, id = raw(), raw()
            if version >= 3 then int(); int() end
            local fields = records[id] or {base = base}
            records[id] = fields
            local modifications = int()
            for _ = 1, modifications do
                local field, kind = raw(), int()
                int(); int() -- level and data pointer
                local value
                if kind == 0 then value = int()
                elseif kind == 1 or kind == 2 then
                    value, offset = string.unpack('<f', data, offset)
                else
                    local last = assert(data:find('\0', offset, true))
                    value, offset = data:sub(offset, last - 1), last + 1
                end
                raw() -- object end token
                fields[field] = value
            end
        end
    end
    assert(offset == #data + 1, 'Object parser did not consume the whole file')
end
parse(map .. '/war3map.w3a')
parse(map .. '/war3mapSkin.w3a')
local beams, scheduled, impacts = {}, {}, {}
OnInit = {final = function(_, callback) callback(function() end) end}
GetUnitX, GetUnitY, GetUnitZ = function(u) return u.x end, function(u) return u.y end, function(u) return u.z end
GetTerrainZ = function(x, y) return x + y end
AddLightningEx = function(kind, visible, x1, y1, z1, x2, y2, z2)
    local beam = {kind = kind, x1 = x1, y1 = y1, z1 = z1, x2 = x2, y2 = y2, z2 = z2}
    assert(visible)
    beams[#beams + 1] = beam
    return beam
end
DestroyLightning = function(beam) assert(not beam.destroyed); beam.destroyed = true end
TimerQueue = {callDelayed = function(_, duration, callback, beam)
    scheduled[#scheduled + 1] = {duration = duration, callback = callback, beam = beam}
end}
AddSpecialEffectTarget = function(path, target, attachment)
    local impact = {path = path, target = target, attachment = attachment}
    impacts[#impacts + 1] = impact
    return impact
end
DestroyEffect = function(effect) effect.destroyed = true end
assert(load(read('cotlua/src/gameplay/abilities/tools.lua'), 'SpellTools', 't', env))()
local source, target = {x = 10, y = 20, z = 30, dead = true}, {x = 40, y = 50, z = 60}
for _, id in ipairs({'A01Y', 'A09D', 'A09Q', 'A09R', 'A09W', 'A0A1'}) do
    local impact_count = #impacts
    local beam = LightningAttackVisual(id, source, target)
    local object, cleanup = assert(records[id]), scheduled[#scheduled]
    assert(object.base == 'Alit' and object.Lit1 == 0)
    assert(beam.kind == object.alig and cleanup.duration == object.Lit2, id .. ': wrong type or duration')
    assert(beam.x1 == 10 and beam.y1 == 20 and beam.z1 == 105 and beam.z2 == 135)
    if object.atat ~= '' then
        local impact = impacts[#impacts]
        assert(#impacts == impact_count + 1 and impact.path == object.atat)
        assert(impact.target == target and impact.attachment == object.ata0 and impact.destroyed)
    else assert(#impacts == impact_count) end
end
local seal_beam = LightningAttackVisual('A01Y', source, target, 100, 200)
assert(seal_beam.x1 == 100 and seal_beam.y1 == 200 and seal_beam.z1 == 375)
local rail = LightningAttackBeam('A010', 1, 2, 3, 4, 5, 6)
assert(rail.kind == records.A010.alig and scheduled[#scheduled].duration == 1.5)
local dummy_source = read('cotlua/src/gameplay/world/dummy.lua'):gsub('\r\n', '\n')
local first = assert(dummy_source:find('        function thistype:lightning(x, y)', 1, true))
local last = assert(dummy_source:find('        ---@type fun(self: Dummy)', first, true))
thistype = {create = function() error('Point beam created a target dummy') end}
assert(load(dummy_source:sub(first, last - 1), 'Dummy point beam', 't', env))()
local point_beam = thistype.lightning({unit = source, abil = string.unpack('>I4', 'A010'),
    attack = function() error('Point beam issued a dummy attack') end}, 70, 80)
assert(point_beam.kind == 'RAIL' and point_beam.x2 == 70 and point_beam.y2 == 80)
assert(point_beam.z2 == 225 and scheduled[#scheduled].duration == 1.5)
for _, cleanup in ipairs(scheduled) do cleanup.callback(cleanup.beam); assert(cleanup.beam.destroyed) end
print('PASS (mocked native calls): lightning settings match object data with the requested 1.5-second Railgun override; cleanup, corpse sources and seal coordinates work.')

for _, path in ipairs({
    'heroes/dark_savior.lua', 'heroes/thunderblade.lua', 'heroes/vampire.lua',
    'heroes/high_priestess.lua', 'buffs/heroes/elementalist.lua',
    'buffs/heroes/vampire.lua', 'bosses/naga.lua',
}) do
    local source_text = read('cotlua/src/content/abilities/' .. path)
    assert(not source_text:find(':attack(', 1, true), path .. ': dummy attack remains')
end
print('PASS (source audit): all former lightning attack call sites use native visuals, not dummy attacks.')
