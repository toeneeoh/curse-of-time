-- Read-only Spell View definitions for scripted abilities without editor IDs.
-- Gameplay owns casts/timers; these definitions never attach native abilities.
OnInit.global('RuntimeSpells', function()
    RuntimeSpells = {}
    local definitions, bindings = {}, {}
    local revision = 0
    ---@class RuntimeSpellSpec
    ---@field name string
    ---@field icon string
    ---@field description string|fun(unit: unit, context: table): string
    ---@field cooldown number?
    ---@field remaining? fun(unit: unit, context: table): number
    ---@field range number?
    ---@field area number?
    ---@field mana number?
    ---@field position integer?
    ---@field passive boolean?
    ---@param key string
    ---@param spec RuntimeSpellSpec
    function RuntimeSpells.define(key, spec)
        assert(type(key) == 'string' and key ~= '' and not definitions[key], 'Duplicate/invalid runtime spell key')
        assert(type(spec.name) == 'string' and type(spec.icon) == 'string', 'Runtime spells require a name and icon')
        assert(type(spec.description) == 'string' or type(spec.description) == 'function', 'Missing runtime spell description')
        assert(not spec.position or (spec.position % 1 == 0 and spec.position >= 0 and spec.position <= 11), 'Invalid runtime spell position')
        definitions[key] = spec
    end
    function RuntimeSpells.bind(unit, keys, context)
        assert(unit and type(keys) == 'table' and #keys <= 12, 'Invalid runtime spell binding')
        local copy, seen = {}, {}
        for index, key in ipairs(keys) do
            assert(definitions[key] and not seen[key], 'Unknown/duplicate runtime spell binding')
            copy[index], seen[key] = key, true
        end
        revision = revision + 1
        bindings[unit] = {keys = copy, context = context or {}, revision = revision}
    end
    function RuntimeSpells.unbind(unit) bindings[unit] = nil end
    function RuntimeSpells.get(unit) return bindings[unit] end
    function RuntimeSpells.view(unit, key)
        local binding, spec = bindings[unit], definitions[key]
        if not binding or not spec then return nil end
        local found = false
        for _, candidate in ipairs(binding.keys) do if candidate == key then found = true; break end end
        if not found then return nil end
        local text = type(spec.description) == 'function' and spec.description(unit, binding.context) or spec.description
        local remaining = spec.remaining and spec.remaining(unit, binding.context) or 0
        return {Key = key, Name = spec.name, Icon = spec.icon, Text = text, Level = 1,
            Mana = spec.mana or 0, Cool = math.max(0, spec.cooldown or 0),
            Remaining = math.max(0, remaining), Range = spec.range or 0, Area = spec.area or 0,
            Position = spec.position, Passive = spec.passive == true}
    end
end, Debug and Debug.getLine())
