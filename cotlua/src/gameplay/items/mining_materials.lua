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
            tooltip = "[tier " .. tier .. "] [type 13] [charges 1] [stack 99]"
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
