-- Logical item definitions backed by reusable native carrier items.
OnInit.final("RuntimeItemDefinitions", function(Require)
    Require('ItemHelpers')
    Require('Items')

    ---@class RuntimeLogicalItemSpec
    ---@field id integer Stable 16-bit save identifier.
    ---@field carrier string|integer Existing object-editor item used as the native handle.
    ---@field name string
    ---@field icon string
    ---@field world_skin? string|integer Native item skin used for the dropped-world model.
    ---@field tooltip string Standard item bracket-formula tooltip.
    ---@field item_type? integer Inventory/proficiency type index.
    ---@field faction_rank_requirement? integer Faction rank shown alongside the level requirement.
    ---@field metadata? table Gameplay data owned by the defining subsystem.
    ---@field inherit_stats? integer[] Formula stats copied from the carrier.
    ---@field prepare_data? fun(data: table, carrier_data: table)
    ---@field adjust_cached_stats? fun(item: Item): table<integer, integer>?
    ---@field initialize_item? fun(item: Item)

    ---@class RuntimeLogicalItemDefinition: RuntimeLogicalItemSpec
    ---@field key string
    ---@field carrier_id integer
    ---@field world_skin_id? integer
    ---@field data table

    RuntimeItemDefinitions = {}

    local by_id = {}
    local by_key = {}
    local definitions = {}
    -- New runtime-item saves may use the upper half of extra[2] for
    -- subsystem-owned state. Old saves contain the bare definition id and
    -- continue to decode unchanged. The current catalog is deliberately
    -- limited to eight-bit ids while this compact representation is in use.
    local PACKED_MARKER = 0x8000
    local DEFINITION_MASK = 0x00FF
    local METADATA_MASK = 0x007F

    local function saved_definition_id(value)
        value = value or 0
        if (value & PACKED_MARKER) ~= 0 then return value & DEFINITION_MASK end
        return value
    end

    local function saved_metadata(value)
        value = value or 0
        if (value & PACKED_MARKER) == 0 then return 0 end
        return (value >> 8) & METADATA_MASK
    end

    local function resolve(key)
        if type(key) == "table" then return key end
        if type(key) == "number" then return by_id[key] end
        return by_key[key]
    end

    ---Registers a logical item. Its tooltip uses the same parser, stat
    ---calculator, and formatter as an object-editor item description.
    ---@param key string
    ---@param spec RuntimeLogicalItemSpec
    ---@return RuntimeLogicalItemDefinition?
    function RuntimeItemDefinitions.define(key, spec)
        if type(key) ~= "string" or spec.id <= 0 or spec.id > DEFINITION_MASK or
            by_key[key] or by_id[spec.id] then
            print("Invalid or duplicate runtime item definition: " ..
                      tostring(key))
            return nil
        end

        local definition = spec
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

        item.runtime_definition = definition
        local metadata = saved_metadata(item.extra[2])
        item.extra[2] = metadata == 0 and definition.id or
                            (PACKED_MARKER | definition.id | (metadata << 8))
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

    ---Returns subsystem state stored beside a runtime definition. Values are
    ---limited to seven bits and survive ordinary apply/restore operations.
    ---@param item Item
    ---@return integer
    function RuntimeItemDefinitions.getMetadata(item)
        return item and saved_metadata(item.extra[2]) or 0
    end

    ---@param item Item
    ---@param value integer
    ---@return boolean
    function RuntimeItemDefinitions.setMetadata(item, value)
        local definition = item and item.runtime_definition
        if not definition then return false end
        value = math.max(0, math.min(METADATA_MASK, math.floor(value or 0)))
        item.extra[2] = value == 0 and definition.id or
                            (PACKED_MARKER | definition.id | (value << 8))
        return true
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
