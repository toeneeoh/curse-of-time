--[[
    item.lua

    A library that defines a custom item interface
]]

OnInit.final("Items", function(Require)
    Require('Users')
    Require('Variables')
    Require('ItemEventRegistry')
    Require('Hotkeys')
    Require('Currency')
    Require('Events')
    Require('Prices')
    Require('Profile')
    Require('SaveSchema')
    Require('Spells')
    Require('TimerQueue')
    Require('UnitTable')

    CHURCH_DONATION = {} ---@type boolean[] 
    RECHARGE_COOLDOWN = __jarray(0) ---@type number[]
    IS_ITEM_DROP = __jarray(true) ---@type boolean[]

    local get_widget_life, get_unit_state, set_widget_life, set_unit_state = GetWidgetLife, GetUnitState, SetWidgetLife, SetUnitState
    local floor = math.floor
    local concat = table.concat
    local ItemData = ItemData
    local TQ = TimerQueue
    local Unit = Unit
    local Spells = Spells
    local ITEM_ABILITY, ITEM_ABILITY2 = ITEM_ABILITY, ITEM_ABILITY2
    local TYPE_SOCKETABLE = 12

    -- per-stat applicators
    -- sig: applier(unit, mult, value, mod, self_item)
    local STAT_APPLIERS = {}

    STAT_APPLIERS[ITEM_ARMOR] = function(unit, mult, value, mod)
        unit.bonus_armor = unit.bonus_armor + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_DAMAGE] = function(unit, mult, value, mod)
        unit.bonus_damage = unit.bonus_damage + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_HEALTH] = function(unit, mult, value, mod)
        unit.bonus_hp = unit.bonus_hp + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_MANA] = function(unit, mult, value, mod)
        unit.bonus_mana = unit.bonus_mana + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_STRENGTH] = function(unit, mult, value, mod)
        unit.bonus_str = unit.bonus_str + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_AGILITY] = function(unit, mult, value, mod)
        unit.bonus_agi = unit.bonus_agi + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_INTELLIGENCE] = function(unit, mult, value, mod)
        unit.bonus_int = unit.bonus_int + mult * floor(mod * value)
    end

    STAT_APPLIERS[ITEM_GOLD_GAIN] = function(unit, mult, value)
        unit.gold_rate = unit.gold_rate + mult * value
    end

    STAT_APPLIERS[ITEM_SPELLBOOST] = function(unit, mult, value)
        unit.spellboost = unit.spellboost + mult * value * 0.01
    end

    STAT_APPLIERS[ITEM_MOVESPEED] = function(unit, mult, value)
        unit.ms_flat = unit.ms_flat + mult * value
    end

    STAT_APPLIERS[ITEM_REGENERATION] = function(unit, mult, value)
        unit.regen_flat = unit.regen_flat + mult * value
    end

    STAT_APPLIERS[ITEM_EVASION] = function(unit, mult, value)
        unit.evasion = unit.evasion + mult * value
    end

    STAT_APPLIERS[ITEM_CRIT_CHANCE] = function(unit, mult, value)
        unit.cc_flat = unit.cc_flat + mult * value
    end

    STAT_APPLIERS[ITEM_CRIT_DAMAGE] = function(unit, mult, value)
        unit.cd_flat = unit.cd_flat + mult * value
    end

    -- multiplicative / special ones
    STAT_APPLIERS[ITEM_MAGIC_RESIST] = function(unit, mult, value)
        local factor = 1 - value * 0.01
        if mult > 0 then
            unit.mr = unit.mr * factor
        else
            unit.mr = unit.mr / factor
        end
    end

    STAT_APPLIERS[ITEM_DAMAGE_RESIST] = function(unit, mult, value)
        local factor = 1 - value * 0.01
        if mult > 0 then
            unit.dr = unit.dr * factor
        else
            unit.dr = unit.dr / factor
        end
    end

    STAT_APPLIERS[ITEM_BASE_ATTACK_SPEED] = function(unit, mult, value)
        local factor = 1. + value * 0.01
        if mult > 0 then
            unit.bonus_bat = unit.bonus_bat / factor
        else
            unit.bonus_bat = unit.bonus_bat * factor
        end
    end

    local slot_types = {
        TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE,
        TYPE_POTION, TYPE_POTION,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
    }

    ---@type fun(itm: Item)
    ---@return number total, number gold, number plat
    function GetItemSellPrice(itm)
        local total = itm.cached_stats[ITEM_COST] // 2

        if total == 0 then
            local price = GetItemPrice(itm.id, itm.pid)

            if price then
                total = price[GOLD] // 2
            end
        end

        local gold = math.fmod(total, 1000000)
        local plat = total // 1000000

        return total, gold, plat
    end

    ---@type fun(slot: integer, type: integer): boolean
    function VerifySlotForType(slot, type)
        -- convert to a bit format
        if type == 0 then
            type = TYPE_EQUIPPABLE
        else
            type = 1 << (type - 1)
        end

        -- if bitwise AND > 0 then valid
        return ((slot_types[slot] & type) > 0)
    end

    ---@class ItemAbilityRuntime
    ---@field obj item
    ---@field id integer
    ---@field callback? function
    ---@field block_chance? number
    ---@field damage_reduction? number
    ---@field damage? number

    ---@class Item
    ---@field obj item
    ---@field holder unit
    ---@field trig trigger
    ---@field lvl function
    ---@field level integer
    ---@field id integer
    ---@field type integer
    ---@field charges integer
    ---@field x number
    ---@field y number
    ---@field quality integer[]
    ---@field eval conditionfunc
    ---@field consumeCharge function
    ---@field calculateValue function
    ---@field equip function
    ---@field drop function
    ---@field update function
    ---@field encode_id function
    ---@field encode_stats function
    ---@field decode function
    ---@field expire function
    ---@field onDeath function
    ---@field name string
    ---@field restricted boolean
    ---@field create function
    ---@field destroy function
    ---@field owner player
    ---@field sfx effect
    ---@field tooltip string
    ---@field alt_tooltip string
    ---@field stack function
    ---@field equipped boolean
    ---@field spawn integer
    ---@field nocraft boolean
    ---@field pid integer
    ---@field index integer
    ---@field validate_slot function
    ---@field abil integer
    ---@field info function
    ---@field abilities ItemAbilityRuntime[]
    ---@field getAbilityArgument fun(self: Item, index: integer, argument: integer): number
    ---@field cache_stats function
    ---@field sockets Item[]
    ---@field alive boolean
    Item = {} ---@type Item|Item[]
    do
        local thistype = Item
        local hash = InitHashtable()

        ---@param index integer
        ---@param argument integer
        ---@return number
        function thistype:getAbilityArgument(index, argument)
            return tonumber(ItemData[self.id][index .. "data" .. argument]) or 0
        end

        function thistype.onDeath()
            -- typecast widget to item
            SaveWidgetHandle(hash, 0, 0, GetTriggerWidget())
            TQ:callDelayed(2., thistype.destroy, Item[LoadItemHandle(hash, 0, 0)])
            RemoveSavedHandle(hash, 0, 0)
            return false
        end
        thistype.eval = Condition(thistype.onDeath)

        -- object inheritance and method operators
        local mt = {
                __index = function(tbl, key)
                    return (rawget(Item, key) or rawget(tbl.proxy, key))
                end,
                __newindex = function(tbl, key, value)
                    if key == "restricted" then
                        tbl:restrict(value)
                        rawset(tbl.proxy, key, value)
                    else
                        rawset(tbl, key, value)
                    end
                end,
            }

        ---@class ItemRuntime
        ---@field native_create function
        ---@field create fun(id: string|integer|item, x: number?, y: number?, expire: number?): Item
        ---@field wrap fun(handle: item): Item
        ---@field commit_slot fun(self: Item, slot: integer, suppress_refresh: boolean?): boolean
        ItemRuntime = {} ---@type ItemRuntime
        local NativeCreateItem = CreateItem
        ItemRuntime.native_create = NativeCreateItem

        ---@type fun(id: string|integer|item, x: number?, y: number?, expire: number?): Item
        function ItemRuntime.create(id, x, y, expire)
            local lvl = 0
            local itm = id

            -- parse "I000:00" notation, where level / variation is signified by numbers after a colon
            if type(id) == "string" then
                local item_string = id
                id = FourCC(item_string:sub(1, 4))
                lvl = tonumber(item_string:sub(6))
            end

            -- create the item if given an id rather than a handle
            if type(id) ~= "userdata" then
                itm = NativeCreateItem(id, x or 30000., y or 30000.)
            elseif Item[itm] then
                return Item[itm]
            end

            local item_id = GetItemTypeId(itm)
            local self = setmetatable({ ---@type Item
                obj = itm,
                id = item_id,
                level = lvl,
                trig = CreateTrigger(),
                x = GetItemX(itm),
                y = GetItemY(itm),
                quality = __jarray(0),
                extra = __jarray(0),
                owner = nil,
                holder = nil,
                equipped = false,
                alive = true,
                charges = GetItemCharges(itm),
                dummies = nil, -- stores item spells
                sockets = {},
                proxy = {
                    restricted = false,
                },
            }, mt)

            local tbl = ItemData[self.id]

            -- first time setup
            if tbl.tooltip == 0 then
                -- if an item's description exists, use that for parsing (exception for default shops)
                ParseItemTooltip(self.obj, ((BlzGetItemDescription(self.obj):len()) > 1 and BlzGetItemDescription(self.obj)) or "")
            end

            if not rawget(tbl, "quality_index") then
                local quality_index = {}
                local quality_count = 1

                for stat = 1, ITEM_ABILITY2 do
                    if tbl[stat .. "range"] ~= 0 then
                        quality_index[stat] = quality_count
                        quality_count = quality_count + 1
                    end
                end

                tbl.quality_index = quality_index
            end

            local rarity = tbl[ITEM_RARITY]
            self.rarity = rarity == 0 and 4 or rarity
            self.limit = tbl[ITEM_LIMIT]
            self.type = tbl[ITEM_TYPE]

            -- store first ability id for convenience
            self.abil = tbl[ITEM_ABILITY .. "id"]

            -- setup charges (for potions)
            local charges = tbl[ITEM_CHARGES]
            if charges > 0 then
                self.charges = charges
            end

            -- determine if immediately useable in recipes
            self.nocraft = tbl[ITEM_NOCRAFT] ~= 0

            -- determine if saveable (ITEM_TYPE_MISCELLANEOUS yields 6 instead of proper value of 7)
            local type = GetItemType(self.obj)
            if (GetHandleId(type) == 7 or type == ITEM_TYPE_PERMANENT or type == ITEM_TYPE_PURCHASABLE) and self.id > CUSTOM_ITEM_OFFSET then
                SAVE_TABLE.KEY_ITEMS[self.id] = self.id - CUSTOM_ITEM_OFFSET

                -- hide the item according to item drop settings
                if not IS_ITEM_DROP[GetPlayerId(GetLocalPlayer()) + 1] then
                    BlzSetItemSkin(self.obj, FourCC('rar0'))
                end
            end

            -- handle item death
            TriggerRegisterDeathEvent(self.trig, self.obj)
            TriggerAddCondition(self.trig, thistype.eval)

            -- timed life
            if expire then
                TQ:callDelayed(expire, thistype.expire, self)
            end

            -- randomize rolls
            local count = 1
            for i = 1, ITEM_ABILITY2 do
                if tbl[i .. "range"] ~= 0 then
                    self.quality[count] = GetRandomInt(0, 63)
                    count = count + 1
                end

                if count > QUALITY_SAVED then
                    break
                end
            end

            if tbl[ITEM_TIER] ~= 0 then
                self:update()
            else
                self:cache_stats()
            end

            Item[self.obj] = self

            if RuntimeMetrics then
                RuntimeMetrics.items.created = RuntimeMetrics.items.created + 1
                RuntimeMetrics.items.live = RuntimeMetrics.items.live + 1
                RuntimeMetrics.items.peak = math.max(RuntimeMetrics.items.peak, RuntimeMetrics.items.live)
            end

            return self
        end

        ---@param handle item
        ---@return Item
        function ItemRuntime.wrap(handle)
            return Item[handle] or ItemRuntime.create(handle)
        end

        local backpack_allowed = {
            [FourCC('A0E2')] = 1, -- sea ward
            [FourCC('A0D3')] = 1, -- jewel of the horde
            [FourCC('A04I')] = 1, -- drum of war aura
            [FourCC('A03G')] = 1, -- blood horn (unholy aura)
            [FourCC('A03H')] = 1, -- blood shield
            [FourCC('AIcd')] = 1, -- war drums
            [FourCC('Adt1')] = 1, -- gem of true sight
            [FourCC('A03F')] = 1, -- endurance aura
            [FourCC('AIta')] = 1, -- crystal ball reveal
        }

        -- Called on equip to stack with an existing item if applicable
        ---@type fun(self: Item, pid: integer, limit: integer): boolean
        function thistype:stack(pid, limit)
            for i = 1, MAX_INVENTORY_SLOTS do
                local match = Profile[pid].hero.items[i]

                if match and match ~= self and match.id == self.id and match.charges < limit and match.level == self.level then
                    local total = match.charges + self.charges
                    local diff = limit - match.charges

                    if total <= limit then
                        match.charges = total
                        self:destroy()
                        self = match
                    else
                        match.charges = limit
                        self.charges = self.charges - diff
                    end
                    return true
                end
            end

            return false
        end

        -- Adjusts name in tooltip if an item is useable or not
        ---@type fun(self: Item, flag: boolean)
        function thistype:restrict(flag)
            if flag then
                BlzSetItemName(self.obj, self:name() .. "\n|cffFFCC00You are too low level to use this item!|r")
            else
                BlzSetItemName(self.obj, self:name())
            end
        end

        --Generates a proper name string
        ---@type fun(self: Item):string
        function thistype:name()
            local name = GetObjectName(self.id)

            if self.level > 0 then
                return concat({RARITY_NAME[(self.level + 3) // self.rarity], " ", name, " +", self.level})
            end

            return name
        end

        function thistype:info()
            local details = { self.alt_tooltip or self.tooltip or BlzGetItemDescription(self.obj) }
            local maxlvl = ItemData[self.id][ITEM_UPGRADE_MAX]
            local total, gold, plat = GetItemSellPrice(self)

            if maxlvl > 0 then
                details[#details + 1] = "|n|cff999999Maximum Upgrade: +" .. maxlvl .. "|r"
            end

            if total > 0 then
                if plat > 0 then
                    details[#details + 1] = "|n|cffffcc00Sells for:|r " .. plat .. " |cffe3e2e2Platinum|r and " .. gold .. " |cffffcc00Gold|r"
                else
                    details[#details + 1] = "|n|cffffcc00Sells for:|r " .. gold .. " |cffffcc00Gold|r"
                end
            end

            if self.charges > 0 then
                details[#details + 1] = "|n|cffffcc00Charges:|r " .. self.charges
            end

            if ItemToIndex(self.id) then
                details[#details + 1] = "|n|cff00ff33Saveable|r"
            end

            if maxlvl > 0 and self.type ~= TYPE_SOCKETABLE then
                details[#details + 1] = "|n|cff00ff00Socketable|r"
            end

            for i, socket in ipairs(self.sockets) do
                details[#details + 1] = "|n|n|cffffcc00Socket " .. i .. ":|r " .. socket:name()
                details[#details + 1] = "|n" .. (socket.alt_tooltip or socket.tooltip or BlzGetItemDescription(socket.obj))
            end

            return {
                name = self:name(),
                icon = ItemData[self.id].path,
                description = concat(details),
            }
        end

        local function apply_item_stats(self, mult, holder)
            holder = holder or self.holder

            if not holder then
                return
            end

            local u = Hero[self.pid]
            local unit = Unit[u]
            local hp   = get_widget_life(u) ---@type number 
            local mana = get_unit_state(u, UNIT_STATE_MANA) ---@type number 
            local mod  = ItemProfMod(self.id, self.pid) ---@type number 
            local cs = self.cached_stats

            unit.suppress_stat_events = true

            -- apply stats with cooresponding appliers
            for i = 1, TOTAL_STATS do
                local s = STAT_APPLIERS[i]

                if s and cs[i] ~= 0 then
                    s(unit, mult, cs[i], mod)
                end
            end

            set_widget_life(u, math.max(1, hp))
            set_unit_state(u, UNIT_STATE_MANA, mana)

            -- shield
            if ItemData[self.id][ITEM_TYPE] == 5 then
                unit.shield_count = unit.shield_count + mult
            end

            unit.suppress_stat_events = false

            -- profiency warning
            if GetHeroLevel(u) < 15 and mult > 0 and mod < 1 then
                DisplayTimedTextToPlayer(self.owner, 0, 0, 10, "You lack the proficiency (-pf) to use this item, therefore it only gives 75% of most stats.\n|cffFF0000You will stop getting this warning at level 15.|r")
            end
        end

        ---@type fun(itm: Item, index: integer, value: integer): string
        local function ParseItemAbilityTooltip(itm, index, value)
            local data   = ItemData[itm.id][index .. "data"] ---@type string 
            local id     = ItemData[itm.id][index .. "id"] ---@type integer 
            local orig   = BlzGetAbilityExtendedTooltip(id, 0) ---@type string 
            local count  = 1
            local values = {} ---@type integer[] 

            values[0] = value

            -- parse ability data into array
            for v in data:gmatch("(%-?%d+)") do
                values[count] = v
                ItemData[itm.id][index .. "data" .. count] = v
                count = count + 1
            end

            -- parse ability tooltip and fill capture groups
            orig = orig:gsub("%$(%d+)", function(tag)
                return tostring(values[tonumber(tag) - 1])
            end)

            return orig
        end

        ---@type fun(itm: Item)
        local function add_item_abilities(itm)
            if not itm.holder then
                return
            end

            local prof = ItemProfMod(itm.id, itm.pid) >= 1

            for index = ITEM_ABILITY, ITEM_ABILITY2 do
                local abilid = ItemData[itm.id][index .. "id"]
                -- don't add ability if backpack is not allowed
                if GetUnitTypeId(itm.holder) == BACKPACK and not backpack_allowed[abilid] then
                    abilid = 0
                end
                -- ability exists and unlocked and has proficiency
                if abilid ~= 0 and Spells[abilid] and itm.level >= ItemData[itm.id][index .. "unlock"] and prof then
                    if not itm.abilities then
                        itm.abilities = {}
                    end

                    local dummy
                    local desc = ParseItemAbilityTooltip(itm, index, itm.cached_stats[index])

                    -- if no item spell dummy, generate it
                    if not itm.abilities[index] then
                        dummy = MakeDummyCastItem(backpack_allowed[abilid] and Backpack[itm.pid] or Hero[itm.pid])
                        itm.abilities[index] = {obj = dummy, id = abilid}
                    else
                        dummy = itm.abilities[index].obj
                    end

                    -- append tooltip if useable from backpack
                    if backpack_allowed[abilid] then
                        desc = desc .. "\n|cffffcc00This ability may be used from your backpack.|r"
                    end

                    -- dummy may be nil if no spell inventory space remaining
                    if dummy then
                        if Spells[abilid].ACTIVE then
                            BlzItemAddAbility(dummy, abilid)
                        end
                        BlzSetItemIconPath(dummy, BlzGetAbilityIcon(abilid))
                        --BlzSetItemDescription(dummy, desc)
                        BlzSetItemExtendedTooltip(dummy, desc)
                        BlzSetItemName(dummy, GetObjectName(abilid))

                        Spells[abilid].onEquip(itm, abilid, index)
                    end
                end
            end
        end

        function thistype:lvl(lvl)
            if ItemData[self.id][ITEM_UPGRADE_MAX] > 0 then
                if self.equipped then
                    apply_item_stats(self, -1)
                end
                self.level = lvl
                self:update()
                if self.equipped then
                    apply_item_stats(self, 1)
                end

                -- required for spells unlocked by level
                add_item_abilities(self)
            end
        end

        function thistype:consumeCharge()
            self.charges = self.charges - 1

            if self.charges <= 0 then
                self:destroy()
            end
        end

        function Item:cache_stats()
            self.cached_stats = self.cached_stats or {}
            self.cached_base = self.cached_base or {}
            self.cached_lower = self.cached_lower or {}
            self.cached_upper = self.cached_upper or {}

            for stat = 1, TOTAL_STATS do
                local base = self:calculateValue(stat)
                local value = base

                self.cached_base[stat] = base
                if ItemData[self.id][stat .. "range"] ~= 0 then
                    self.cached_lower[stat] = self:calculateValue(stat, 1)
                    self.cached_upper[stat] = self:calculateValue(stat, 2)
                else
                    self.cached_lower[stat] = base
                    self.cached_upper[stat] = base
                end

                for _, socket in ipairs(self.sockets) do
                    value = value + socket:calculateValue(stat)
                end
                self.cached_stats[stat] = value
            end
        end

        -- Calculates the value of a stat given the formula in the tooltip
        -- 1 = lower, 2 = upper
        ---@type fun(self: Item, STAT: integer, flag: integer): number
        function Item:calculateValue(STAT, flag)
            local tbl = ItemData[self.id]
            local unlockat = tbl[STAT .. "unlock"] ---@type number 

            if self.level < unlockat then
                return 0
            end

            local flatPerLevel  = tbl[STAT .. "fpl"] ---@type number 
            local flatPerRarity = tbl[STAT .. "fpr"] ---@type number 
            local percent       = tbl[STAT .. "percent"] ---@type number 
            local fixed         = tbl[STAT .. "fixed"] ---@type number 
            local lower         = tbl[STAT]  ---@type number 
            local upper         = tbl[STAT .. "range"]  ---@type number 
            local hasVariance   = (upper ~= 0) ---@type boolean 
            local pmult         = (percent ~= 0 and percent * 0.01) or 1 ---@type number

            -- calculate values after applying affixes
            lower = lower + ((flatPerLevel * self.level + flatPerRarity * (math.max(self.level - 1, 0) // self.rarity)) * pmult)
            upper = upper + ((flatPerLevel * self.level + flatPerRarity * (math.max(self.level - 1, 0) // self.rarity)) * pmult)

            -- values are not fixed
            if fixed == 0 then
                lower = lower + lower * ITEM_STAT_MULTIPLIER[self.level] * pmult
                upper = upper + upper * ITEM_STAT_MULTIPLIER[self.level] * pmult
            end

            if flag == 1 then
                return (lower < 1 and lower) or floor(lower)
            elseif flag == 2 then
                return (upper < 1 and upper) or floor(upper)
            else
                local final = 0

                if hasVariance then
                    local count = tbl.quality_index[STAT] or 1

                    final = lower + (upper - lower) * 0.015625 * (1 + self.quality[count])
                else
                    final = lower
                end

                -- round to nearest 10s
                if final >= 1000 then
                    final = (final + 5) // 10 * 10
                end

                return (final < 1 and final) or floor(final)
            end
        end

        local function remove_item_ability(self, abil, index)
            if self and (not self.holder or (not backpack_allowed[abil.id] and self.holder == Backpack[self.pid])) then
                set_widget_life(abil.obj, 1.)
                RemoveItem(abil.obj)
                self.abilities[index] = nil
            end
        end

        local function refresh_item_abilities(self, dropped, holder)
            if self.abilities then
                for i = ITEM_ABILITY, ITEM_ABILITY2 do
                    local abil = self.abilities[i]

                    if abil and (not backpack_allowed[abil.id] or dropped) then
                        -- trigger unequip event
                        Spells[abil.id].onUnequip(self, abil.id, i, holder)

                        local orig_spell_owner = backpack_allowed[abil.id] and Backpack[self.pid] or Hero[self.pid]

                        -- remove ability after cooldown expires
                        TQ:callDelayed(BlzGetUnitAbilityCooldownRemaining(orig_spell_owner, abil.id), remove_item_ability, self, abil, i)
                    end
                end
            end
        end

        ---@type fun(itm: Item, itm2: Item): boolean
        local function has_conflict(itm, itm2)
            local same_limit = itm.limit == itm2.limit
            return (same_limit and itm.id == itm2.id) or (same_limit and itm.limit ~= 1)
        end

        ---@param itm Item
        ---@param ignore Item?
        ---@return boolean, string?
        local function is_item_limited(itm, ignore)
            if itm.limit == 0 then
                return false
            end

            local items = Profile[itm.pid].hero.items

            for i = 1, 6 do
                local itm2 = items[i]

                if itm2 and itm2 ~= ignore and itm ~= itm2 then
                    if has_conflict(itm, itm2) then
                        return true, LIMIT_STRING[itm.limit]
                    end

                    if itm2.sockets then
                        for _, socket in ipairs(itm2.sockets) do
                            if has_conflict(itm, socket) then
                                return true, LIMIT_STRING[itm.limit]
                            end
                        end
                    end
                end
            end

            return false
        end

        ---Moves an inventory item into this item's socket list.
        ---@param itm Item
        ---@return boolean
        function thistype:socket(itm)
            if not itm
                or itm == self
                or itm.socketed
                or itm.type ~= TYPE_SOCKETABLE
                or self.type == TYPE_SOCKETABLE
                or itm.pid ~= self.pid
                or not itm.holder
                or not itm.index
                or #self.sockets >= MAX_SOCKETS
                or is_item_limited(self)
            then
                return false
            end

            local was_equipped = self.equipped

            -- Remove exactly the stats that are currently applied. The new
            -- socket-inclusive cache is applied after the mutation.
            if was_equipped then
                apply_item_stats(self, -1)
            end

            -- drop() performs the complete inventory/ability removal. Keep
            -- the backing item handle hidden because it now belongs to self.
            itm:drop(30000., 30000., true)
            SetItemVisible(itm.obj, false)

            itm.parent = self
            itm.socketed = true
            self.sockets[#self.sockets + 1] = itm

            self:update()

            if was_equipped then
                apply_item_stats(self, 1)
            end

            return true
        end

        ---Removes a socket and returns it to inventory, or drops it nearby
        ---when no compatible inventory slot is available.
        ---@param index integer
        ---@return Item?
        function thistype:unsocket(index)
            local socket = self.sockets[index]

            if not socket then
                return nil
            end

            local was_equipped = self.equipped

            if was_equipped then
                apply_item_stats(self, -1)
            end

            self.sockets[index] = self.sockets[#self.sockets]
            self.sockets[#self.sockets] = nil
            socket.parent = nil
            socket.socketed = false

            self:update()

            if was_equipped then
                apply_item_stats(self, 1)
            end

            if not socket:equip() then
                SetItemPosition(socket.obj, GetUnitX(Hero[self.pid]), GetUnitY(Hero[self.pid]))
                SetItemVisible(socket.obj, true)
            end

            return socket
        end

        ---@type fun(itm: Item, pid: integer): boolean
        local function is_item_bound(itm, pid)
            return (itm.owner ~= Player(pid - 1) and itm.owner ~= nil)
        end

        ---@param self Item
        ---@param slot integer
        ---@param ignore Item?
        ---@return boolean
        ---@return string? err
        function ValidateItemSlot(self, slot, ignore)
            if is_item_bound(self, self.pid) and SAVE_TABLE.KEY_ITEMS[self.id] then
                return false, "This item is bound to " .. User[self.owner].nameColored .. "."
            end

            local type = ItemData[self.id][ITEM_TYPE]

            -- restrict by slot type
            if not VerifySlotForType(slot, type) then
                return false, nil
            end

            local lvlreq = ItemData[self.id][ITEM_LEVEL_REQUIREMENT] ---@type integer 
            local lvl = GetHeroLevel(Hero[self.pid])

            if slot <= BACKPACK_INDEX - 1 then
                local limited, err = is_item_limited(self, ignore)

                if lvlreq > lvl then
                    return false, "This item requires at least level |c00FF5555" .. (lvlreq) .. "|r to equip."
                elseif limited then
                    return false, err
                end
            elseif slot >= BACKPACK_INDEX and lvlreq > lvl + 20 then
                return false, "This item requires at least level |c00FF5555" .. (lvlreq - 20) .. "|r to pick up."
            end

            return true
        end

        local function find_empty_slot(self)
            -- set starting slot to backpack if fail limit check
            local slot = (is_item_limited(self) and BACKPACK_INDEX) or 1
            local items = Profile[self.pid].hero.items
            local type = ItemData[self.id][ITEM_TYPE]

            for i = slot, MAX_INVENTORY_SLOTS do
                if not items[i] and VerifySlotForType(i, type) then
                    return i
                end
            end

            return nil
        end

        ---Applies a previously validated slot transition. This function does
        ---not stack or perform validation and is reserved for domain services
        ---that have prepared the complete final inventory state.
        ---@param self Item
        ---@param slot integer
        ---@param suppress_refresh boolean?
        ---@return boolean
        function ItemRuntime.commit_slot(self, slot, suppress_refresh)
            local items = Profile[self.pid].hero.items
            local orig_holder = self.holder
            local orig_index = self.index
            local was_equipped = self.equipped
            local new_holder = (slot <= 6 and Hero[self.pid]) or Backpack[self.pid]

            -- New holder needs to be set before applying stats and abilities.
            self.holder = new_holder

            if orig_index and items[orig_index] == self then
                items[orig_index] = nil
            end

            -- From equipped to backpack.
            if was_equipped and slot > 6 then
                refresh_item_abilities(self, false, orig_holder)
                apply_item_stats(self, -1)
                self.equipped = false
            end

            -- Newly equipped.
            if not was_equipped and slot <= 6 then
                self.equipped = true

                if SAVE_TABLE.KEY_ITEMS[self.id] then
                    self.owner = Player(self.pid - 1)
                end

                apply_item_stats(self, 1)
            end

            items[slot] = self
            self.index = slot

            -- A move within the same holder changes only the slot. Re-running
            -- onEquip in that case can duplicate periodic item effects.
            if orig_holder ~= new_holder then
                add_item_abilities(self)
            end

            SetItemPosition(self.obj, 30000., 30000.)
            SetItemVisible(self.obj, false)

            if not suppress_refresh then
                NotifyItemChanged(self.pid)
            end

            return true
        end

        -- Main equip function with optional target slot
        -- Returns true if successfully moves an item to the slot
        ---@type fun(self: Item, slot: integer?, ignore: Item?, suppress_refresh: boolean?): boolean
        function thistype:equip(slot, ignore, suppress_refresh)
            -- determine the slot
            slot = slot or find_empty_slot(self)

            -- validate it (level check, limited check)
            local valid, err = false, nil
            if slot then
                valid, err = ValidateItemSlot(self, slot, ignore)
            end

            if err then
                DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 15., err)
            end

            -- cannot move item to new slot
            if not valid then
                return false
            end

            -- if item is stackable
            local stack = self.cached_stats[ITEM_STACK]
            if stack > 1 then
                self:stack(self.pid, stack)

                if not self.alive then
                    return true
                end
            end

            return ItemRuntime.commit_slot(self, slot, suppress_refresh)
        end

        local parse_item_stat = {
            [ITEM_ABILITY] = function(self, index, value, lower, upper, valuestr, range)
                local s = ParseItemAbilityTooltip(self, index, value)

                return (s:len() > 0 and concat({"|n", s})) or ""
            end,

            default = function(self, index, value, lower, upper, valuestr, range, posneg)
                local suffix = STAT_TAG[index].item_suffix or STAT_TAG[index].suffix or "|r"

                if range ~= 0 then
                    return concat({"|n + |cffffcc00", lower, "-", upper, suffix, " ", STAT_TAG[index].tag})
                else
                    return concat({"|n ", posneg, valuestr, suffix, " ", STAT_TAG[index].tag})
                end
            end
        }

        parse_item_stat[ITEM_ABILITY2] = parse_item_stat[ITEM_ABILITY]

        function thistype:update()
            local orig = ItemData[self.id].tooltip ---@type string
            local text = {}

            -- first "header" lines: rarity, upg level, tier, type, req level
            if self.level > 0 then
                local rarity_index = (self.level + 3) // self.rarity
                BlzSetItemSkin(self.obj, ITEM_MODEL[rarity_index])

                text[#text + 1] = RARITY_NAME[rarity_index]
                text[#text + 1] = " +"
                text[#text + 1] = self.level
                text[#text + 1] = "|n"
            end

            text[#text + 1] = TIER_NAME[ItemData[self.id][ITEM_TIER]]
            text[#text + 1] = " "
            text[#text + 1] = TYPE_NAME[ItemData[self.id][ITEM_TYPE]]

            local lvl = ItemData[self.id][ITEM_LEVEL_REQUIREMENT]
            if lvl > 0 then
                text[#text + 1] = "|n|cffff0000Level Requirement: |r"
                text[#text + 1] = lvl
            end

            text[#text + 1] = "|n"
            local alt_text = {}
            for i, v in ipairs(text) do
                alt_text[i] = v
            end

            -- cache stats
            self:cache_stats()

            local cs = self.cached_stats

            -- body stats
            for index = 1, ITEM_ABILITY2 do
                local value = cs[index]

                -- write non-zero stats
                if value ~= 0 then
                    local base_value = self.cached_base[index]
                    local socket_value = value - base_value
                    local socket_valuestr = tostring(floor(math.abs(socket_value) + 0.5))
                    local lower = self.cached_lower[index]
                    local upper = self.cached_upper[index]
                    local valuestr = tostring(floor(math.abs(value) + 0.5))
                    local posneg = "+ |cffffcc00"

                    -- handle negative values
                    if value < 0 then
                        posneg = "- |cffcc0000"
                    end

                    -- alt tooltip
                    local range = ItemData[self.id][index .. "range"]
                    if parse_item_stat[index] then
                        alt_text[#alt_text + 1] = parse_item_stat[index](self, index, value, lower, upper, valuestr, range)
                    else
                        alt_text[#alt_text + 1] = parse_item_stat.default(self, index, value, lower, upper, valuestr, range, posneg)

                        if socket_value ~= 0 then
                            alt_text[#alt_text + 1] = " |cff00ff00("
                            alt_text[#alt_text + 1] = socket_value > 0 and "+" or "-"
                            alt_text[#alt_text + 1] = socket_valuestr
                            alt_text[#alt_text + 1] = STAT_TAG[index].item_suffix or STAT_TAG[index].suffix or "|r"
                            alt_text[#alt_text + 1] = "|cff00ff00)|r"
                        end
                    end

                    -- normal tooltip
                    if index == ITEM_ABILITY or index == ITEM_ABILITY2 then
                        text[#text + 1] = parse_item_stat[index](self, index, value, 0, 0)
                    else
                        local suffix = STAT_TAG[index].item_suffix or STAT_TAG[index].suffix or "|r"
                        text[#text + 1] = "|n "

                        if base_value ~= 0 then
                            text[#text + 1] = base_value > 0 and "+ |cffffcc00" or "- |cffcc0000"
                            text[#text + 1] = tostring(math.abs(floor(base_value + 0.5)))
                            text[#text + 1] = suffix
                        end

                        if socket_value ~= 0 then
                            if base_value ~= 0 then
                                text[#text + 1] = " "
                            end

                            text[#text + 1] = socket_value > 0 and "|cff00ff00+ " or "|cff00ff00- "
                            text[#text + 1] = socket_valuestr
                            text[#text + 1] = suffix
                            text[#text + 1] = "|r"
                        end

                        text[#text + 1] = " "
                        text[#text + 1] = STAT_TAG[index].tag
                    end
                end
            end

            -- flavor text
            -- remove bracket pairs, extra spaces, and extra newlines
            local flavor = orig:gsub("(%b[]%s*)", "")
            if flavor:len() > 5 then
                text[#text + 1] = "|n"
                text[#text + 1] = flavor
                alt_text[#alt_text + 1] = "|n"
                alt_text[#alt_text + 1] = flavor
            end

            if self.limit > 0 then
                text[#text + 1] = "|cff808080|nLimit: 1"
                alt_text[#alt_text + 1] = "|cff808080|nLimit: 1"
            end

            self.tooltip = concat(text)
            self.alt_tooltip = concat(alt_text)

            BlzSetItemIconPath(self.obj, ItemData[self.id].path)
            BlzSetItemName(self.obj, ItemData[self.id].name)
            BlzSetItemDescription(self.obj, self.tooltip)
            BlzSetItemExtendedTooltip(self.obj, self.tooltip)

            -- update inventory frames
            if self.pid then
                NotifyItemChanged(self.pid)
            end
        end

        ---@type fun(id: integer, stats: integer, extra: integer): Item|nil
        function thistype.decode(id, stats, extra)
            if id == 0 then
                return nil
            end

            local itemid = id & 0x1FFF
            local itm = ItemRuntime.create(CUSTOM_ITEM_OFFSET + itemid, 30000., 30000.)
            local mask = 0xFE000
            itm.level = (id & mask) >> 13

            mask = 0x3F
            itm.quality[1] = (id >> 20) & 0x3F
            itm.quality[2] = (id >> 26) & 0x3F

            local shift = 0
            for i = 3, QUALITY_SAVED do
                itm.quality[i] = (stats & mask) >> shift

                mask = (mask << 6)
                shift = shift + 6
            end

            mask = 0xFFFF
            itm.extra[1] = (extra >> 16) & mask
            itm.extra[2] = (extra & mask)

            itm:lvl(itm.level)

            return itm
        end

        -- save 5 more quality integers, 6 bits for each
        ---@return integer
        function thistype:encode_stats()
            local id = 0

            for i = 3, 7 do
                id = id + self.quality[i] << ((i - 3) * 6)
            end

            return id
        end

        -- extra item metadata
        ---@type fun(self: Item): integer
        function thistype:encode_extra()
            local extra = (self.extra[1] << 16) + self.extra[2]

            return extra
        end

        -- from least to most significant: first 13 bits for id, next 7 for level, 6 for each quality
        ---@type fun(self: Item): integer
        function thistype:encode_id()
            local id = ItemToIndex(self.id)

            if id == nil then
                return 0
            end

            id = id + (self.level << 13)

            for i = 1, 2 do
                id = id + (self.quality[i] << (14 + i * 6))
            end

            return id
        end

        function thistype:drop(x, y, mute)
            if self.holder == nil or self.index == nil then
                return
            end

            refresh_item_abilities(self, true, self.holder)

            if self.equipped then
                self.equipped = false

                apply_item_stats(self, -1)
            end

            SetItemPosition(self.obj, x or GetUnitX(self.holder), y or GetUnitY(self.holder))
            SetItemVisible(self.obj, true)

            if not mute then
                SoundHandler("Sound\\Interface\\HeroDropItem1.flac", true, self.owner, self.holder)
            end

            Profile[self.pid].hero.items[self.index] = nil
            self.holder = nil
            self.index = nil

            NotifyItemChanged(self.pid)
        end

        function thistype:onDestroy()
            if not self.alive then
                return false
            end

            self.alive = false

            if self.sfx then
                DestroyEffect(self.sfx)
                self.sfx = nil
            end

            if self.pid then
                NotifyItemChanged(self.pid)
            end

            -- Release the strong registry reference before invalidating the handle.
            Item[self.obj] = nil
            DestroyTrigger(self.trig)
            set_widget_life(self.obj, 1.)
            RemoveItem(self.obj)

            self.trig = nil
            self.obj = nil

            if RuntimeMetrics then
                RuntimeMetrics.items.destroyed = RuntimeMetrics.items.destroyed + 1
                RuntimeMetrics.items.live = RuntimeMetrics.items.live - 1
            end

            return true
        end

        function thistype:destroy()
            if not self.alive then
                return false
            end

            self:drop(30000, 30000, true)
            return self:onDestroy()
        end

        ---@type fun(itm: Item)
        function thistype.expire(itm)
            if not itm.holder and not itm.owner then
                itm:destroy()
            end
        end
    end

end, Debug and Debug.getLine())
