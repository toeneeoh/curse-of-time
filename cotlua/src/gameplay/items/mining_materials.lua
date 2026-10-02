-- Physical Cave Voyager mining yields and material accounting.

OnInit.final("MiningMaterials", function(Require)
    Require('ItemHelpers')
    Require('RuntimeItemDefinitions')

    MiningMaterials = {}

    local definitions = {}
    local order = { "ironstone", "prismatic_ore", "forgotten_crystal" }

    local function define(key, id, name, icon, tier, flavor)
        local definition = RuntimeItemDefinitions.define("mineral_" .. key, {
            id = id,
            carrier = 'I02Q',
            world_skin = 'I02Q',
            name = name,
            icon = icon,
            tooltip = "[tier " .. tier .. "] [type 13] [charges 1] [stack 99] [nocraft*1]"
                .. "|n|n|cff808080" .. flavor .. "|r",
            item_type = TYPE_CONSUMABLE_INDEX,
            metadata = { mineral_key = key },
            initialize_item = function(item)
                item.charges = 1
                SetItemCharges(item.obj, 1)
            end,
        })
        definitions[key] = definition
        return definition
    end

    define("ironstone", 200, "Ironstone",
           "ReplaceableTextures\\CommandButtons\\BTNRockGolem.blp", 1,
           "Dense ore prized as a dependable foundation for delicate settings.")
    define("prismatic_ore", 201, "Prismatic Ore",
           "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", 3,
           "Its shifting veins accept enchantments that ordinary metal rejects.")
    define("forgotten_crystal", 202, "Forgotten Crystal",
           "ReplaceableTextures\\CommandButtons\\BTN_CR_wGem.blp", 5,
           "A mineral memory drawn from seams untouched since the world was young.")

    MiningMaterials.IRONSTONE = "ironstone"
    MiningMaterials.PRISMATIC_ORE = "prismatic_ore"
    MiningMaterials.FORGOTTEN_CRYSTAL = "forgotten_crystal"

    local function is_material(item, key)
        return item and definitions[key] and item.runtime_definition == definitions[key]
    end

    ---@param pid integer
    ---@param key string
    ---@return integer
    function MiningMaterials.count(pid, key)
        local total = 0
        local profile = Profile[pid]
        local items = profile and profile.hero and profile.hero.items
        if not items then return 0 end
        for slot = 1, MAX_INVENTORY_SLOTS do
            local item = items[slot]
            if is_material(item, key) then
                total = total + math.max(1, item.charges)
            end
        end
        return total
    end

    ---@param pid integer
    ---@param costs table<string, integer>
    ---@return boolean, string?
    function MiningMaterials.canAfford(pid, costs)
        for key, amount in pairs(costs) do
            local owned = MiningMaterials.count(pid, key)
            if owned < amount then
                local definition = definitions[key]
                return false, "REQUIRES " .. amount .. " " ..
                                  (definition and definition.name:upper() or key:upper())
            end
        end
        return true
    end

    ---Consumes a complete recipe atomically after validating every material.
    ---@param pid integer
    ---@param costs table<string, integer>
    ---@return boolean
    function MiningMaterials.consume(pid, costs)
        if not MiningMaterials.canAfford(pid, costs) then return false end
        local items = Profile[pid].hero.items
        for key, amount in pairs(costs) do
            local remaining = amount
            for slot = MAX_INVENTORY_SLOTS, 1, -1 do
                local item = items[slot]
                if remaining > 0 and is_material(item, key) then
                    local available = math.max(1, item.charges)
                    local consumed = math.min(available, remaining)
                    if consumed >= available then
                        item:destroy()
                    else
                        item.charges = available - consumed
                        SetItemCharges(item.obj, item.charges)
                    end
                    remaining = remaining - consumed
                end
            end
        end
        NotifyItemChanged(pid)
        return true
    end

    ---@param pid integer
    ---@param key string
    ---@param amount integer
    ---@return Item?
    function MiningMaterials.grant(pid, key, amount)
        local definition = definitions[key]
        local hero = Hero[pid]
        if not definition or not hero or amount < 1 then return nil end
        local item = RuntimeItemDefinitions.create(definition,
            GetUnitX(hero), GetUnitY(hero))
        if not item then return nil end
        item.charges = amount
        SetItemCharges(item.obj, amount)
        PlayerAddItem(pid, item)
        return item
    end

    function MiningMaterials.getPresentation(key)
        local definition = definitions[key]
        if not definition then return nil end
        return definition.name, definition.icon, definition.data.tooltip
    end

    function MiningMaterials.getAllKeys()
        local result = {}
        for index, key in ipairs(order) do result[index] = key end
        return result
    end
end, Debug and Debug.getLine())
