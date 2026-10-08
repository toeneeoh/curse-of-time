-- Logical item definitions backed by reusable native carrier items.
OnInit.final("RuntimeItemDefinitions", function(Require)
    Require('ItemHelpers')
    Require('Items')

    ---@class RuntimeLogicalItemSpec
    ---@field id integer Stable 16-bit save identifier.
    ---@field code? string Optional four-character virtual display code. This
    ---does not need or create a corresponding object-editor record.
    ---@field carrier string|integer Existing object-editor item used as the native handle.
    ---@field name string
    ---@field icon string
    ---@field world_skin? string|integer Native item skin used for the dropped-world model.
    ---@field tooltip string Standard item bracket-formula tooltip.
    ---@field item_type? integer Inventory/proficiency type index.
    ---@field faction_rank_requirement? integer Faction rank shown alongside the level requirement.
    ---@field display_rarity? integer Rarity presentation without an upgrade level.
    ---@field metadata? table Gameplay data owned by the defining subsystem.
    ---@field inherit_stats? integer[] Formula stats copied from the carrier.
    ---@field prepare_data? fun(data: table, carrier_data: table)
    ---@field adjust_cached_stats? fun(item: Item): table<integer, integer>?
    ---@field append_stats? fun(item: Item, text: string[], alt_text: string[])
    ---@field initialize_item? fun(item: Item)
    ---@field restore_item? fun(item: Item) Rebuild subsystem presentation after decode.

    ---@class RuntimeLogicalItemDefinition: RuntimeLogicalItemSpec
    ---@field key string
    ---@field carrier_id integer
    ---@field world_skin_id? integer
    ---@field data table

    RuntimeItemDefinitions = {}

    ---@type table<integer, RuntimeLogicalItemDefinition>
    local by_id = {}
    ---@type table<string, RuntimeLogicalItemDefinition>
    local by_key = {}
    ---@type table<string, RuntimeLogicalItemDefinition>
    local by_code = {}
    ---@type RuntimeLogicalItemDefinition[]
    local definitions = {}
    -- Runtime identity remains in extra[2]. Subsystem state now lives in the
    -- extensible per-item persistence vector rather than sharing these bits.
    local DEFINITION_MASK = 0xFFFF

    local function saved_definition_id(value)
        return (value or 0) & DEFINITION_MASK
    end

    ---@param key string|integer|RuntimeLogicalItemDefinition
    ---@return RuntimeLogicalItemDefinition?
    local function resolve(key)
        if type(key) == "table" then return key end
        if type(key) == "number" then return by_id[key] end
        return by_key[key] or by_code[key]
    end

    ---Returns a registered logical definition without exposing the registries.
    ---@param key string|integer|RuntimeLogicalItemDefinition
    ---@return RuntimeLogicalItemDefinition?
    function RuntimeItemDefinitions.get(key) return resolve(key) end

    ---Returns the stable identity used by recipes and other item comparisons.
    ---Native items retain their ordinary shop key; logical items use their
    ---definition key so shared carrier rawcodes cannot satisfy one another.
    ---@param item Item
    ---@return string
    function RuntimeItemDefinitions.identityKey(item)
        if item.runtime_definition then
            return "@" .. item.runtime_definition.key
        end
        return GetItem(item.id)
    end

    ---Matches an inventory item against a recipe identity. Logical recipe
    ---components may append `:level` to require that upgrade level or higher;
    ---native recipe identities retain their existing exact-level behavior.
    ---@param item Item
    ---@param identity string
    ---@return boolean
    function RuntimeItemDefinitions.matchesRecipeIdentity(item, identity)
        if type(identity) ~= "string" or identity:sub(1, 1) ~= "@" then
            return RuntimeItemDefinitions.identityKey(item) == identity
        end
        local key, minimum = identity:match("^@([^:]+):?(%d*)$")
        local definition = key and resolve(key) or nil
        if not definition or item.runtime_definition ~= definition then
            return false
        end
        return minimum == "" or item.level >= (tonumber(minimum) or 0)
    end

    ---Registers a logical item. Its tooltip uses the same parser, stat
    ---calculator, and formatter as an object-editor item description.
    ---@param key string
    ---@param spec RuntimeLogicalItemSpec
    ---@return RuntimeLogicalItemDefinition?
    function RuntimeItemDefinitions.define(key, spec)
        local invalid_code = spec.code ~= nil and
                                 (type(spec.code) ~= "string" or
                                     spec.code:len() ~= 4 or by_code[spec.code])
        if type(key) ~= "string" or spec.id <= 0 or spec.id > DEFINITION_MASK or
            by_key[key] or by_id[spec.id] or invalid_code then
            print("Invalid or duplicate runtime item definition: " ..
                      tostring(key))
            return nil
        end

        local definition = spec
        ---@cast definition RuntimeLogicalItemDefinition
        definition.key = key
        definition.carrier_id = type(spec.carrier) == "string" and
                                    FourCC(spec.carrier) or spec.carrier
        definition.world_skin_id = type(spec.world_skin) == "string" and
                                       FourCC(spec.world_skin) or
                                       spec.world_skin
        definition.data =
            ParseItemDefinition(spec.name, spec.icon, spec.tooltip)
        if spec.item_type ~= nil then
            definition.data[ITEM_TYPE] = spec.item_type
            definition.data[ITEM_TYPE .. "fixed"] = 1
        end
        by_key[key] = definition
        by_id[spec.id] = definition
        if spec.code then by_code[spec.code] = definition end
        definitions[#definitions + 1] = definition
        return definition
    end

    ---Returns definitions in stable registration order for search/catalog UI.
    ---The returned records are definitions and must not be mutated.
    ---@return RuntimeLogicalItemDefinition[]
    function RuntimeItemDefinitions.getAll() return definitions end

    ---@param item Item
    ---@param key string|integer|RuntimeLogicalItemDefinition
    ---@param initialize boolean? Reset charges to the definition maximum.
    ---@return boolean
    function RuntimeItemDefinitions.apply(item, key, initialize)
        local definition = resolve(key)
        if not definition or not item or item.id ~= definition.carrier_id then
            return false
        end

        local carrier_data = ItemData[definition.carrier_id]
        for _, stat in ipairs(definition.inherit_stats or {}) do
            definition.data[stat] = carrier_data[stat]
            definition.data[stat .. "fixed"] = carrier_data[stat .. "fixed"]
            definition.data[stat .. "range"] = carrier_data[stat .. "range"]
            definition.data[stat .. "fpl"] = carrier_data[stat .. "fpl"]
            definition.data[stat .. "fpr"] = carrier_data[stat .. "fpr"]
            definition.data[stat .. "percent"] = carrier_data[stat .. "percent"]
            definition.data[stat .. "unlock"] = carrier_data[stat .. "unlock"]
        end
        if definition.prepare_data then
            definition.prepare_data(definition.data, carrier_data)
        end

        if initialize then item.persistent_state = {} end
        item.runtime_definition = definition
        item.extra[2] = definition.id
        if definition.world_skin_id then
            BlzSetItemSkin(item.obj, definition.world_skin_id)
        end
        ItemRuntime.applyData(item, definition.data, initialize == true)
        if initialize and definition.initialize_item then
            definition.initialize_item(item)
        end
        item:update(true)
        if initialize and item.type == TYPE_POTION_INDEX then
            item.charges = item.cached_stats[ITEM_CHARGES]
        end
        return true
    end

    ---Returns a logical item to its carrier's ordinary definition.
    ---@param item Item
    function RuntimeItemDefinitions.clear(item)
        if not item then return end
        item.runtime_definition = nil
        item.extra[2] = 0
        item.persistent_state = {}
        BlzSetItemSkin(item.obj, item.id)
        ItemRuntime.applyData(item, ItemData[item.id], false)
        item:update(true)
    end

    ---Restores logical identity after the saved extra field is decoded.
    ---@param item Item
    ---@return boolean
    function RuntimeItemDefinitions.restore(item)
        local definition = by_id[saved_definition_id(item.extra[2])]
        if not definition or definition.carrier_id ~= item.id then
            return false
        end
        return RuntimeItemDefinitions.apply(item, definition, false)
    end

    ---@param item Item
    ---@param key string|integer
    ---@return boolean
    function RuntimeItemDefinitions.is(item, key)
        local definition = resolve(key)
        return definition ~= nil and item ~= nil and item.runtime_definition ==
                   definition
    end

    ---Logical items may share a native carrier without being the same item.
    ---Ordinary object-editor items retain their rawcode identity.
    ---@param first Item?
    ---@param second Item?
    ---@return boolean
    function RuntimeItemDefinitions.sameIdentity(first, second)
        if not first or not second or first.id ~= second.id then return false end
        local first_definition = first.runtime_definition
        local second_definition = second.runtime_definition
        if not first_definition and not second_definition then return true end
        return first_definition ~= nil and
                   first_definition == second_definition
    end

    ---@param key string|integer
    ---@param x number?
    ---@param y number?
    ---@param expire number?
    ---@return Item?
    function RuntimeItemDefinitions.create(key, x, y, expire)
        local definition = resolve(key)
        if not definition then return nil end
        local item = ItemRuntime.create(definition.carrier_id, x, y, expire)
        RuntimeItemDefinitions.apply(item, definition, true)
        return item
    end

    ---Resolves presentation without constructing a native item handle.
    ---@param carrier_id integer
    ---@param encoded_extra integer
    ---@return RuntimeLogicalItemDefinition?
    function RuntimeItemDefinitions.fromSaved(carrier_id, encoded_extra)
        local id = saved_definition_id((encoded_extra or 0) & 0xFFFF)
        local definition = by_id[id]
        if definition and definition.carrier_id == carrier_id then
            return definition
        end
        return nil
    end
end, Debug and Debug.getLine())
