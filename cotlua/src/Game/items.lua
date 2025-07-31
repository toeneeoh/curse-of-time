--[[
    items.lua

    A library that defines a custom item interface
]]

OnInit.final("Items", function(Require)
    Require('Users')
    Require('Variables')
    Require('Frames')
    Require('Inventory')
    Require('ItemLookup')

    local shop_prices = {
        [FourCC('I00O')] = 80,
        [FourCC('I01T')] = 15000,
        [FourCC('I01M')] = 1200,
        [FourCC('I00B')] = 1500,
        [FourCC('I00Q')] = 50,
        [FourCC('I00R')] = 70,
        [FourCC('I0FJ')] = 15,
        [FourCC('I01Z')] = 25,
        [FourCC('I06F')] = 30,
        [FourCC('I01A')] = 100,
        [FourCC('I01A')] = 100,
        [FourCC('I01C')] = 35,
        [FourCC('I08V')] = 200,
        [FourCC('I07S')] = 50,
        [FourCC('I08X')] = 400,
        [FourCC('I01D')] = 90,
        [FourCC('I01G')] = 30,
        [FourCC('I01H')] = 30,
        [FourCC('I011')] = 30,
        [FourCC('I01K')] = 150,
        [FourCC('I01L')] = 80,
        [FourCC('I010')] = 500,
        [FourCC('I0FL')] = 500,
        [FourCC('I00F')] = 500,
        [FourCC('I0FK')] = 500,
        [FourCC('I024')] = 50,
        [FourCC('I026')] = 50,
        [FourCC('I01S')] = 110,
        [FourCC('I02H')] = 30,
        [FourCC('I02R')] = 150,
        [FourCC('I02T')] = 50,
        [FourCC('I03A')] = 80,
        [FourCC('I090')] = 30,
        [FourCC('I03K')] = 80,
        [FourCC('I004')] = 150,
        [FourCC('I03S')] = 90,
        [FourCC('I03W')] = 80,
        [FourCC('I01X')] = 1000,
        [FourCC('I06G')] = 40,
        [FourCC('I04D')] = 50,
        [FourCC('I00P')] = 1000,
        [FourCC('I04O')] = 30,
        [FourCC('I01I')] = 30,
        [FourCC('I00H')] = 300,
        [FourCC('I00I')] = 800,
        [FourCC('I06H')] = 500,
        [FourCC('I00G')] = 300,
    }

    ---@type fun(itm: Item)
    ---@return number total, number gold, number plat
    function GetItemSellPrice(itm)
        local total = itm:getValue(ITEM_COST, 0) // 2

        if total == 0 then
            total = shop_prices[itm.id] and shop_prices[itm.id] // 2 or 0
        end

        local gold = math.fmod(total, 1000000)
        local plat = total // 1000000

        return total, gold, plat
    end

    local floor = math.floor
    local log = math.log

    CHURCH_DONATION   = {} ---@type boolean[] 
    RECHARGE_COOLDOWN = __jarray(0) ---@type timer[] 
    IS_ITEM_DROP = __jarray(true) ---@type boolean[]

    local slot_types = {
        TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE, TYPE_EQUIPPABLE,
        TYPE_POTION, TYPE_POTION,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
        TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL, TYPE_ALL,
    }

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

    ---@class Item
    ---@field obj item
    ---@field holder unit
    ---@field trig trigger
    ---@field lvl function
    ---@field level integer
    ---@field id integer
    ---@field charges integer
    ---@field x number
    ---@field y number
    ---@field quality integer[]
    ---@field eval conditionfunc
    ---@field consumeCharge function
    ---@field getValue function
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
    ---@field abilities table
    Item = {} ---@type Item|Item[]
    do
        local thistype = Item
        local hash = InitHashtable()

        function thistype.onDeath()
            -- typecast widget to item
            SaveWidgetHandle(hash, 0, 0, GetTriggerWidget())
            TimerQueue:callDelayed(2., thistype.destroy, Item[LoadItemHandle(hash, 0, 0)])
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

        -- override createitem
        OldCreateItem = CreateItem

        ---@type fun(id: string|integer|item, x: number?, y: number?, expire: number?): Item
        function CreateItem(id, x, y, expire)
            local lvl = 0
            local itm = id

            -- parse "I000:00" notation, where level / variation is signified by numbers after a colon
            if type(id) == "string" then
                id = FourCC(string.sub(id, 1, 4))
                lvl = tonumber(string.sub(id, 6))
            end

            -- create the item if given an id rather than a handle
            if type(id) ~= "userdata" then
                itm = OldCreateItem(id, x or 30000., y or 30000.)
            end

            local self = setmetatable({ ---@type Item
                obj = itm,
                id = GetItemTypeId(itm),
                level = lvl,
                trig = CreateTrigger(),
                x = GetItemX(itm),
                y = GetItemY(itm),
                quality = __jarray(0),
                owner = nil,
                holder = nil,
                equipped = false,
                charges = GetItemCharges(itm),
                dummies = nil, -- stores item spells
                proxy = {
                    restricted = false,
                },
            }, mt)

            -- first time setup
            if ItemData[self.id][ITEM_TOOLTIP] == 0 then
                -- if an item's description exists, use that for parsing (exception for default shops)
                ParseItemTooltip(self.obj, ((BlzGetItemDescription(self.obj):len()) > 1 and BlzGetItemDescription(self.obj)) or "")
            end

            -- store first ability id for convenience
            self.abil = ItemData[self.id][ITEM_ABILITY .. "id"]

            -- setup charges (for potions)
            local charges = ItemData[self.id][ITEM_CHARGES]
            if charges > 0 then
                self.charges = charges
            end

            -- determine if immediately useable in recipes
            self.nocraft = ItemData[self.id][ITEM_NOCRAFT] ~= 0

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
                TimerQueue:callDelayed(expire, thistype.expire, self)
            end

            -- randomize rolls
            local count = 1
            for i = 1, ITEM_ABILITY2 do
                if ItemData[self.id][i .. "range"] ~= 0 then
                    self.quality[count] = GetRandomInt(0, 63)
                    count = count + 1
                end

                if count > QUALITY_SAVED then break end
            end

            if ItemData[self.id][ITEM_TIER] ~= 0 then
                self:update()
            end

            Item[self.obj] = self

            return self
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
            local s = GetObjectName(self.id)

            if self.level > 0 then
                s = LEVEL_PREFIX[self.level] .. " " .. s .. " +" .. self.level
            end

            return s
        end

        function thistype:info(pid)
            local p      = Player(pid - 1)
            local s      = GetObjectName(self.id) ---@type string 
            local maxlvl = ItemData[self.id][ITEM_UPGRADE_MAX] ---@type integer 
            local total, gold, plat = GetItemSellPrice(self)

            if self.level > 0 then
                s = s .. " [" .. LEVEL_PREFIX[self.level] .. " +" .. (self.level) .. "]"
            end

            if maxlvl > 0 then
                s = s .. " |cff999999(MAX +" .. (maxlvl) .. ")|r"
            end

            DisplayTimedTextToPlayer(p, 0, 0, 15., s)

            if total > 0 then
                if plat > 0 then
                    DisplayTimedTextToPlayer(p, 0, 0, 15., "|cffffcc00Sells for|r: " .. RealToString(plat) .. " |cffe3e2e2Platinum|r and " .. RealToString(gold) .. " |cffffcc00Gold|r")
                else
                    DisplayTimedTextToPlayer(p, 0, 0, 15., "|cffffcc00Sells for|r: " .. RealToString(gold) .. " |cffffcc00Gold|r")
                end
            end

            for i = 1, ITEM_ABILITY - 1 do --ignore abilities
                if ItemData[self.id][i] ~= 0 and STAT_TAG[i] then
                    s = STAT_TAG[i].item_suffix or STAT_TAG[i].suffix or ""

                    DisplayTimedTextToPlayer(p, 0, 0, 15., (STAT_TAG[i].tag or "") .. ": " .. RealToString(self:getValue(i, 0)) .. s)
                end
            end

            if ItemToIndex(self.id) then
                DisplayTimedTextToPlayer(p, 0, 0, 15., "|c0000ff33Saveable|r")
            end
        end

        local function apply_item_stats(self, mult)
            if not self.holder then
                return
            end

            local u = Hero[self.pid]
            local unit = Unit[u]
            local hp   = GetWidgetLife(u) ---@type number 
            local mana = GetUnitState(u, UNIT_STATE_MANA) ---@type number 
            local mod  = ItemProfMod(self.id, self.pid) ---@type number 

            UnitAddBonus(u, BONUS_ARMOR, mult * floor(mod * self:getValue(ITEM_ARMOR, 0)))
            unit.bonus_damage = unit.bonus_damage + mult * floor(mod * self:getValue(ITEM_DAMAGE, 0))
            unit.bonus_hp = unit.bonus_hp + mult * floor(mod * self:getValue(ITEM_HEALTH, 0))
            unit.bonus_mana = unit.bonus_mana + mult * floor(mod * self:getValue(ITEM_MANA, 0))
            unit.bonus_str = unit.bonus_str + mult * floor(mod * self:getValue(ITEM_STRENGTH, 0))
            unit.bonus_agi = unit.bonus_agi + mult * floor(mod * self:getValue(ITEM_AGILITY, 0))
            unit.bonus_int = unit.bonus_int + mult * floor(mod * self:getValue(ITEM_INTELLIGENCE, 0))

            SetWidgetLife(u, math.max(1, hp))
            SetUnitState(u, UNIT_STATE_MANA, mana)

            ItemGoldRate[self.pid] = ItemGoldRate[self.pid] + mult * self:getValue(ITEM_GOLD_GAIN, 0)
            unit.spellboost = unit.spellboost + mult * self:getValue(ITEM_SPELLBOOST, 0) * 0.01
            unit.ms_flat = unit.ms_flat + mult * self:getValue(ITEM_MOVESPEED, 0)
            unit.regen_flat = unit.regen_flat + mult * self:getValue(ITEM_REGENERATION, 0)
            unit.evasion = unit.evasion + mult * self:getValue(ITEM_EVASION, 0)
            unit.cc_flat = unit.cc_flat + mult * self:getValue(ITEM_CRIT_CHANCE, 0)
            unit.cd_flat = unit.cd_flat + mult * self:getValue(ITEM_CRIT_DAMAGE, 0)

            -- exceptions
            if mult > 0 then
                unit.mr = unit.mr * (1 - self:getValue(ITEM_MAGIC_RESIST, 0) * 0.01)
                unit.dr = unit.dr * (1 - self:getValue(ITEM_DAMAGE_RESIST, 0) * 0.01)
                unit.bonus_bat = unit.bonus_bat / (1. + self:getValue(ITEM_BASE_ATTACK_SPEED, 0) * 0.01)

                -- profiency warning
                if GetHeroLevel(u) < 15 and mod < 1 then
                    DisplayTimedTextToPlayer(self.owner, 0, 0, 10, "You lack the proficiency (-pf) to use this item, therefore it only gives 75\x25 of most stats.\n|cffFF0000You will stop getting this warning at level 15.|r")
                end
            else
                unit.mr = unit.mr / (1 - self:getValue(ITEM_MAGIC_RESIST, 0) * 0.01)
                unit.dr = unit.dr / (1 - self:getValue(ITEM_DAMAGE_RESIST, 0) * 0.01)
                unit.bonus_bat = unit.bonus_bat * (1. + self:getValue(ITEM_BASE_ATTACK_SPEED, 0) * 0.01)
            end

            -- shield
            if ItemData[self.id][ITEM_TYPE] == 5 then
                ShieldCount[self.pid] = ShieldCount[self.pid] + mult * 1
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
            for v in data:gmatch("(\x25-?\x25d+)") do
                values[count] = v
                ItemData[itm.id][index .. "data" .. count] = v
                count = count + 1
            end

            -- parse ability tooltip and fill capture groups
            orig = orig:gsub("\x25$(\x25d+)", function(tag)
                return values[tonumber(tag) - 1] .. ""
            end)

            return orig
        end

        ---@type fun(itm: Item)
        local function add_item_abilities(itm)
            if not itm.holder then
                return
            end

            for index = ITEM_ABILITY, ITEM_ABILITY2 do
                local abilid = ItemData[itm.id][index .. "id"]
                -- don't add ability if backpack is not allowed
                if GetUnitTypeId(itm.holder) == BACKPACK and not backpack_allowed[abilid] then
                    abilid = 0
                end
                -- ability exists and unlocked
                if abilid ~= 0 and Spells[abilid] and itm.level >= ItemData[itm.id][index .. "unlock"] then
                    if not itm.abilities then
                        itm.abilities = {}
                    end

                    -- generate item spell dummy
                    if not itm.abilities[index] then
                        local dummy
                        local desc = ParseItemAbilityTooltip(itm, index, itm:getValue(index))
                        if backpack_allowed[abilid] then
                            dummy = MakeDummyCastItem(Backpack[itm.pid])
                            desc = desc .. "\n|cffffcc00This ability may be used from your backpack.|r"
                        else
                            dummy = MakeDummyCastItem(Hero[itm.pid])
                        end
                        if Spells[abilid].ACTIVE then
                            BlzItemAddAbility(dummy, abilid)
                        end
                        BlzSetItemIconPath(dummy, BlzGetAbilityIcon(abilid))
                        --BlzSetItemDescription(dummy, desc)
                        BlzSetItemExtendedTooltip(dummy, desc)
                        BlzSetItemName(dummy, GetObjectName(abilid))
                        itm.abilities[index] = {obj = dummy, id = abilid}

                        -- if onequip returns true, dont allocate real fields
                        if not Spells[abilid].onEquip(itm, abilid, index) then
                            local ab = BlzGetItemAbility(dummy, abilid)
                            BlzSetAbilityRealLevelField(ab, SPELL_FIELD[0], 0, itm:getValue(index, 0))
                            for i = 1, SPELL_FIELD_TOTAL do
                                local v = ItemData[itm.id][index .. "data" .. i]
                                if v ~= 0 then
                                    BlzSetAbilityRealLevelField(ab, SPELL_FIELD[i], 0, v)
                                end
                            end
                        end

                        IncUnitAbilityLevel(itm.holder, abilid)
                        DecUnitAbilityLevel(itm.holder, abilid)
                    end
                end
            end
        end

        function thistype:lvl(lvl)
            if ItemData[self.id][ITEM_UPGRADE_MAX] > 0 then
                apply_item_stats(self, -1)
                self.level = lvl
                self:update()
                apply_item_stats(self, 1)

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

        -- Gets the value of a stat from an item, 0 = actual, 1 = lower, 2 = upper
        ---@type fun(self: Item, STAT: integer, flag: integer): number
        function Item:getValue(STAT, flag)
            local unlockat = ItemData[self.id][STAT .. "unlock"] ---@type number 

            if self.level < unlockat then
                return 0
            end

            local flatPerLevel  = ItemData[self.id][STAT .. "fpl"] ---@type number 
            local flatPerRarity = ItemData[self.id][STAT .. "fpr"] ---@type number 
            local percent       = ItemData[self.id][STAT .. "percent"] ---@type number 
            local fixed         = ItemData[self.id][STAT .. "fixed"] ---@type number 
            local lower         = ItemData[self.id][STAT]  ---@type number 
            local upper         = ItemData[self.id][STAT .. "range"]  ---@type number 
            local hasVariance   = (upper ~= 0) ---@type boolean 
            local pmult         = (percent ~= 0 and percent * 0.01) or 1 ---@type number

            --calculate values after applying affixes
            lower = lower + ((flatPerLevel * self.level + flatPerRarity * (math.max(self.level - 1, 0) // 4)) * pmult)
            upper = upper + ((flatPerLevel * self.level + flatPerRarity * (math.max(self.level - 1, 0) // 4)) * pmult)

            --values are not fixed
            if fixed == 0 then
                lower = lower + lower * ITEM_MULT[self.level] * pmult
                upper = upper + upper * ITEM_MULT[self.level] * pmult
            end

            if flag == 1 then
                return (lower < 1 and lower) or floor(lower)
            elseif flag == 2 then
                return (upper < 1 and upper) or floor(upper)
            else
                local final = 0

                if hasVariance then
                    local count = 1

                    --find the quality index
                    for index = 0, STAT - 1 do
                        if ItemData[self.id][index .. "range"] ~= 0 then
                            count = count + 1
                        end
                    end

                    final = lower + (upper - lower) * 0.015625 * (1 + self.quality[count])
                else
                    final = lower
                end

                --round to nearest 10s
                if final >= 1000 then
                    final = (final + 5) // 10 * 10
                end

                return (final < 1 and final) or floor(final)
            end
        end

        local function remove_item_ability(self, abil, index)
            if self and (not self.holder or (not backpack_allowed[abil.id] and self.holder == Backpack[self.pid])) then
                SetWidgetLife(abil.obj, 1.)
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
                        Spells[abil.id].onUnequip(self, abil.id)

                        -- remove ability after cooldown expires
                        TimerQueue:callDelayed(BlzGetUnitAbilityCooldownRemaining(holder and holder or self.holder, abil.id), remove_item_ability, self, abil, i)
                    end
                end
            end
        end

        ---@type fun(itm: Item, pid: integer): boolean
        local function is_item_bound(itm, pid)
            return (itm.owner ~= Player(pid - 1) and itm.owner ~= nil)
        end

        ---@param itm Item
        ---@return boolean, string?
        local function is_item_limited(itm)
            local limit = ItemData[itm.id][ITEM_LIMIT] ---@type integer 

            if limit == 0 then
                return false
            end

            local items = Profile[itm.pid].hero.items

            for i = 1, 6 do
                local itm2 = items[i]

                if itm2 and itm2 ~= itm then
                    if (limit == 1 and itm.id ~= itm2.id) then
                    -- safe case
                    elseif limit == ItemData[itm2.id][ITEM_LIMIT] then
                        return true, LIMIT_STRING[limit]
                    end
                end
            end

            return false
        end

        ---@type fun(self: Item, slot: integer): boolean
        local function validate_slot(self, slot)
            local type = ItemData[self.id][ITEM_TYPE]

            -- restrict by slot type
            if not VerifySlotForType(slot, type) then
                return false
            end

            local lvlreq = ItemData[self.id][ITEM_LEVEL_REQUIREMENT] ---@type integer 
            local lvl = GetHeroLevel(Hero[self.pid])

            if slot <= BACKPACK_INDEX - 1 then
                local limited, err = is_item_limited(self)

                if lvlreq > lvl then
                    DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 15., "This item requires at least level |c00FF5555" .. (lvlreq) .. "|r to equip.")
                    return false
                elseif limited then
                    DisplayTextToPlayer(Player(self.pid - 1), 0, 0, err)
                    return false
                end
            elseif slot >= BACKPACK_INDEX and lvlreq > lvl + 20 then
                DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 15., "This item requires at least level |c00FF5555" .. (lvlreq - 20) .. "|r to pick up.")
                return false
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

        -- Main equip function with optional target slot
        -- Returns true if successfully moves an item to the slot
        ---@type fun(self: Item, slot: integer?): boolean
        function thistype:equip(slot)
            -- check if item is bound
            if is_item_bound(self, self.pid) and SAVE_TABLE.KEY_ITEMS[self.id] then
                DisplayTimedTextToPlayer(Player(self.pid - 1), 0, 0, 30, "This item is bound to " .. User[self.owner].nameColored .. ".")
                return false
            end

            -- determine the slot
            slot = slot or find_empty_slot(self)

            local orig_holder = self.holder
            local valid = false

            -- validate it (level check, limited check)
            if slot and validate_slot(self, slot) then
                self.holder = (slot <= 6 and Hero[self.pid]) or Backpack[self.pid]
                valid = true
            end

            if self.holder and valid then
                local items = Profile[self.pid].hero.items

                -- if item is stackable
                local stack = self:getValue(ITEM_STACK, 0)
                if stack > 1 then
                    self:stack(self.pid, stack)
                end

                -- make sure item is not occupying previous space
                if self.index and items[self.index] == self then
                    items[self.index] = nil
                end

                add_item_abilities(self)

                -- determine whether to add or remove stats
                if not self.equipped and slot <= 6 then
                    self.equipped = true

                    apply_item_stats(self, 1)

                    -- bind item
                    if SAVE_TABLE.KEY_ITEMS[self.id] then
                        self.owner = Player(self.pid - 1)
                    end
                elseif self.equipped and slot > 6 then
                    self.equipped = false

                    refresh_item_abilities(self, false, orig_holder) -- backpack abilities are not removed
                    apply_item_stats(self, -1)
                end

                -- set index
                items[slot] = self
                self.index = slot

                SetItemPosition(self.obj, 30000., 30000.)
                SetItemVisible(self.obj, false)

                INVENTORY.refresh(self.pid)
                Shop.refresh(self.pid)

                return true
            end

            return false
        end

        local parse_item_stat = {
            [ITEM_ABILITY] = function(self, index, value, lower, upper, valuestr, range)
                local s = ParseItemAbilityTooltip(self, index, value)

                return (s:len() > 0 and "|n" .. s) or ""
            end,

            default = function(self, index, value, lower, upper, valuestr, range, posneg)
                local suffix = STAT_TAG[index].item_suffix or STAT_TAG[index].suffix or "|r"

                if range ~= 0 then
                    return "|n + |cffffcc00" .. lower .. "-" .. upper .. suffix .. " " .. STAT_TAG[index].tag
                else
                    return "|n " .. posneg .. valuestr .. suffix .. " " .. STAT_TAG[index].tag
                end
            end
        }

        parse_item_stat[ITEM_ABILITY2] = parse_item_stat[ITEM_ABILITY]

        function thistype:update()
            local orig    = ItemData[self.id][ITEM_TOOLTIP] ---@type string 
            local norm_new   = "" ---@type string 
            local alt_new = "" ---@type string 

            --first "header" lines: rarity, upg level, tier, type, req level
            if self.level > 0 then
                norm_new = norm_new .. (LEVEL_PREFIX[self.level])

                BlzSetItemSkin(self.obj, ITEM_MODEL[self.level])

                norm_new = norm_new .. " +" .. self.level

                norm_new = norm_new .. "|n"
            end

            norm_new = norm_new .. TIER_NAME[ItemData[self.id][ITEM_TIER]] .. " " .. TYPE_NAME[ItemData[self.id][ITEM_TYPE]]

            if ItemData[self.id][ITEM_LEVEL_REQUIREMENT] > 0 then
                norm_new = norm_new .. "|n|cffff0000Level Requirement: |r" .. ItemData[self.id][ITEM_LEVEL_REQUIREMENT]
            end

            norm_new = norm_new .. "|n"
            alt_new = norm_new

            --body stats
            for index = 1, ITEM_ABILITY2 do
                local value = self:getValue(index, 0)

                --write non-zero stats
                if value ~= 0 then
                    local lower = self:getValue(index, 1)
                    local upper = self:getValue(index, 2)
                    local valuestr = tostring(value)
                    local posneg = "+ |cffffcc00"

                    --handle negative values
                    if value < 0 then
                        valuestr = tostring(-value)
                        posneg = "- |cffcc0000"
                    end

                    --alt tooltip
                    local range = ItemData[self.id][index .. "range"]
                    if parse_item_stat[index] then
                        alt_new = alt_new .. parse_item_stat[index](self, index, value, lower, upper, valuestr, range)
                    else
                        alt_new = alt_new .. parse_item_stat.default(self, index, value, lower, upper, valuestr, range, posneg)
                    end

                    --normal tooltip
                    if index == ITEM_ABILITY or index == ITEM_ABILITY2 then
                        norm_new = norm_new .. parse_item_stat[index](self, index, value, 0, 0)
                    else
                        norm_new = norm_new .. "|n " .. posneg .. valuestr .. (STAT_TAG[index].item_suffix or STAT_TAG[index].suffix or "") .. " " .. STAT_TAG[index].tag
                    end
                end
            end

            --flavor text
            --remove bracket pairs, extra spaces, and extra newlines
            orig = "|n" .. orig:gsub("(\x25b[]\x25s*)", "")
            orig = (orig:len() > 5 and ("|n" .. orig)) or ""

            self.tooltip = norm_new .. orig
            self.alt_tooltip = alt_new .. orig

            if ItemData[self.id][ITEM_LIMIT] > 0 then
                self.tooltip = self.tooltip .. "|cff808080|nLimit: 1"
                self.alt_tooltip = self.alt_tooltip .. "|cff808080|nLimit: 1"
            end

            BlzSetItemIconPath(self.obj, ItemData[self.id].path)
            BlzSetItemName(self.obj, ItemData[self.id].name)
            BlzSetItemDescription(self.obj, self.tooltip)
            BlzSetItemExtendedTooltip(self.obj, self.tooltip)

            -- update inventory frames
            if self.pid then
                INVENTORY.refresh(self.pid)
            end
        end

        ---@type fun(id: integer, stats: integer): Item|nil
        function thistype.decode(id, stats)
            if id == 0 then
                return nil
            end

            local itemid = id & 0x1FFF
            local itm = CreateItem(CUSTOM_ITEM_OFFSET + itemid, 30000., 30000.)
            local mask = 0x7E000
            itm.level = (id & mask) >> 13

            for i = 1, 2 do
                mask = mask << 6
                itm.quality[i] = (id & mask)
            end

            local shift = 0
            mask = 0x3F

            for i = 3, QUALITY_SAVED do
                itm.quality[i] = (stats & mask) >> shift

                mask = (mask << 6)
                shift = shift + 6
            end

            itm:lvl(itm.level)

            return itm
        end

        --save 5 more quality integers, 6 bits for each
        ---@return integer
        function thistype:encode_stats()
            local id = 0

            for i = 3, 7 do
                id = id + self.quality[i] << ((i - 3) * 6)
            end

            return id
        end

        --from least to most significant: first 13 bits for id, next 6 for level, 6 for each quality
        ---@type fun(self: Item): integer
        function thistype:encode_id()
            local id = ItemToIndex(self.id)

            if id == nil then
                return 0
            end

            id = id + (self.level << 13)

            for i = 1, 2 do
                id = id + (self.quality[i] << (13 + i * 6))
            end

            return id
        end

        function thistype:drop(x, y, mute)
            if self.holder == nil or self.index == nil then
                return
            end

            refresh_item_abilities(self, true)

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

            INVENTORY.refresh(self.pid)
        end

        function thistype:onDestroy()
            if self.sfx then
                DestroyEffect(self.sfx)
            end

            if self.pid then
                INVENTORY.refresh(self.pid)
            end

            -- proper removal
            DestroyTrigger(self.trig)
            SetWidgetLife(self.obj, 1.)
            RemoveItem(self.obj)
        end

        function thistype:destroy()
            self:drop(30000, 30000, true)
            self:onDestroy()

            self = nil
        end

        ---@type fun(itm: Item)
        function thistype.expire(itm)
            if not itm.holder and not itm.owner then
                itm:destroy()
            end
        end
    end

local function recharge_cd(pid)
    if RECHARGE_COOLDOWN[pid] > 0 then
        RECHARGE_COOLDOWN[pid] = RECHARGE_COOLDOWN[pid] - 1
        TimerQueue:callDelayed(1., recharge_cd, pid)
    end
end

---@return boolean
function RechargeItem()
    local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
    local dw    = DialogWindow[pid] ---@type DialogWindow 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

    if index ~= -1 then
        local itm = GetResurrectionItem(pid, true) ---@type Item?
        local gold, plat = dw.data[index][1], dw.data[index][2]

        if itm then
            -- dont assume player has enough resources here
            if GetCurrency(pid, GOLD) >= gold and GetCurrency(pid, PLATINUM) >= plat then
                itm.charges = itm.charges + 1

                -- update charge count in both inventories
                SetItemCharges(itm.abilities[ITEM_ABILITY].obj, itm.charges)
                INVENTORY.refresh(itm.pid)

                AddCurrency(pid, GOLD, -gold)
                AddCurrency(pid, PLATINUM, -plat)

                local message = ""

                if plat > 0 then
                    message = message .. "\nRecharged " .. GetItemName(itm.obj) .. " for " .. RealToString(plat) .. " Platinum and " .. RealToString(gold) .. " Gold."
                else
                    message = message .. "\nRecharged " .. GetItemName(itm.obj) .. " for " .. RealToString(gold) .. " Gold."
                end
                DisplayTextToPlayer(Player(pid - 1), 0, 0, message)

                -- start recharge cooldown
                RECHARGE_COOLDOWN[pid] = 180.
                TimerQueue:callDelayed(1., recharge_cd, pid)
            end
        end

        dw:destroy()
    end

    return false
end

---@type fun(pid: integer, itm: Item)
function RechargeDialog(pid, itm)
    local percentage = (Profile[pid].hero.hardcore > 0 and 0.03) or 0.01
    local message      = GetObjectName(itm.id) ---@type string 
    local playerGold   = GetCurrency(pid, GOLD) ---@type integer 
    local goldCost     = ItemData[itm.id][ITEM_COST] * 100 * percentage + playerGold * percentage ---@type number 
    local platCost     = GetCurrency(pid, PLATINUM) * percentage ---@type number 
    local dw           = DialogWindow.create(pid, "", RechargeItem) ---@type DialogWindow 

    -- must be integers
    goldCost = R2I(goldCost + (platCost - R2I(platCost)) * 1000000)
    platCost = R2I(platCost)

    if platCost > 0 then
        message = message .. "\nRecharge cost:|n|cffffffff" .. RealToString(platCost) .. "|r |cffe3e2e2Platinum|r, |cffffffff" .. RealToString(goldCost) .. "|r |cffffcc00Gold|r|n"
    else
        message = message .. "\nRecharge cost:|n|cffffffff" .. RealToString(goldCost) .. " |cffffcc00Gold|r|n"
    end

    dw.title = message

    if GetCurrency(pid, GOLD) >= goldCost and GetCurrency(pid, PLATINUM) >= platCost then
        dw:addButton("Recharge", {goldCost, platCost})
    end

    dw:display()
end

---@param pid integer
---@param itemid integer
function KillQuestHandler(pid, itemid)
    local index         = KillQuest[itemid][0] ---@type integer 
    local min           = KillQuest[index].min ---@type integer 
    local max           = KillQuest[index].max ---@type integer 
    local avg           = (min + max) // 2
    local goal          = KillQuest[index].goal ---@type integer 
    local playercount   = 0 ---@type integer 
    local U             = User.first ---@type User 
    local p             = Player(pid - 1)
    local x             = 0.
    local y             = 0.
    local myregion      = nil ---@type rect 

    if GetUnitLevel(Hero[pid]) < min then
        DisplayTimedTextToPlayer(p, 0,0, 10, "You must be level |cffffcc00" .. (min) .. "|r to begin this quest.")
    elseif GetUnitLevel(Hero[pid]) > max then
        DisplayTimedTextToPlayer(p, 0,0, 10, "You are too high level to do this quest.")
    -- progress
    elseif KillQuest[index].status == 1 then
        DisplayTimedTextToPlayer(p, 0,0, 10, "Killed " .. (KillQuest[index].count) .. "/" .. (goal) .. " " .. KillQuest[index].name)
        PingMinimap(GetRectCenterX(KillQuest[index].region), GetRectCenterY(KillQuest[index].region), 3)
    -- start quest
    elseif KillQuest[index].status == 0 then
        KillQuest[index].status = 1
        DisplayTimedTextToPlayer(p, 0, 0, 10, "|cffffcc00QUEST:|r Kill " .. (goal) .. " " .. KillQuest[index].name .. " for a reward.")
        PingMinimap(GetRectCenterX(KillQuest[index].region), GetRectCenterY(KillQuest[index].region), 5)
    -- completion
    elseif KillQuest[index].status == 2 then
        while U do
            if Profile[U.id].playing and GetUnitLevel(Hero[U.id]) >= min and GetUnitLevel(Hero[U.id]) <= max then
                playercount = playercount + 1
            end

            U = U.next
        end

        U = User.first

        while U do
            if GetHeroLevel(Hero[U.id]) >= min and GetHeroLevel(Hero[U.id]) <= max then
                DisplayTimedTextToPlayer(U.player, 0, 0, 10, "|c00c0c0c0" .. KillQuest[index].name .. " quest completed!|r")
                local GOLD = GOLD_TABLE[avg] * goal * 0.5 / (0.5 + playercount * 0.5)
                AwardGold(U.id, GOLD, true)
                local XP = floor(EXPERIENCE_TABLE[max] * XP_Rate[U.id] * goal * 0.0008) / (0.5 + playercount * 0.5)
                AwardXP(U.id, XP)
            end

            U = U.next
        end

        -- reset
        KillQuest[index].status = 1
        KillQuest[index].count = 0
        KillQuest[index].goal = IMinBJ(goal + 3, 100)

        -- increase max spawns based on last unit killed (until max goal of 100 is reached)
        if (KillQuest[index].goal) < 100 and ModuloInteger(KillQuest[index].goal, 2) == 0 then
            myregion = SelectGroupedRegion(UnitData[KillQuest[index].last].spawn)
            repeat
                x = GetRandomReal(GetRectMinX(myregion), GetRectMaxX(myregion))
                y = GetRandomReal(GetRectMinY(myregion), GetRectMaxY(myregion))
            until IsTerrainWalkable(x, y)
            CreateUnit(PLAYER_CREEP, KillQuest[index].last, x, y, GetRandomInt(0, 359))
            DisplayTimedTextToForce(FORCE_PLAYING, 20., "An additional " .. GetObjectName(KillQuest[index].last) .. " has spawned in the area.")
        end
    end
end

---@return boolean
function BackpackUpgrades()
    local dw    = DialogWindow[GetPlayerId(GetTriggerPlayer()) + 1] ---@type DialogWindow 
    local id    = dw.data[0] ---@type integer 
    local price = dw.data[1] ---@type integer 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 
    local ablev = 0 ---@type integer 

    if index ~= -1 then
        AddCurrency(dw.pid, GOLD, - ModuloInteger(price, 1000000))
        AddCurrency(dw.pid, PLATINUM, - (price // 1000000))

        if id == FourCC('I101') then
            ablev = GetUnitAbilityLevel(Backpack[dw.pid], TELEPORT_HOME.id)
            SetUnitAbilityLevel(Backpack[dw.pid], TELEPORT_HOME.id, ablev + 1)
            SetUnitAbilityLevel(Backpack[dw.pid], TELEPORT.id, ablev + 1)
            DisplayTimedTextToPlayer(Player(dw.pid - 1), 0, 0, 20, "You successfully upgraded to: Teleport [|cffffcc00Level " .. (ablev + 1) .. "|r]")
        elseif id == FourCC('I102') then
            ablev = GetUnitAbilityLevel(Backpack[dw.pid], FourCC('A0FK'))
            SetUnitAbilityLevel(Backpack[dw.pid], FourCC('A0FK'), ablev + 1)
            DisplayTimedTextToPlayer(Player(dw.pid - 1), 0, 0, 20, "You successfully upgraded to: Reveal [|cffffcc00Level " .. (ablev + 1) .. "|r]")
        end

        dw:destroy()
    end

    return false
end

---@return boolean
local function UpgradeItemConfirm()
    local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
    local dw    = DialogWindow[pid] ---@type DialogWindow 
    local itm   = dw.data[0] ---@type Item 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

    if index ~= -1 then
        AddCurrency(pid, GOLD, -dw.data[1])
        AddCurrency(pid, PLATINUM, -dw.data[2])
        AddCurrency(pid, CRYSTAL, -dw.data[3])

        itm:lvl(itm.level + 1)
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20, "You successfully upgraded to: " .. itm:name())

        dw:destroy()
    end

    return false
end

---@return boolean
function UpgradeItem()
    local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
    local dw    = DialogWindow[pid] ---@type DialogWindow 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

    if index ~= -1 then
        local itm = dw.data[index]

        dw:destroy()

        if itm then
            local goldCost = ModuloInteger(itm:getValue(ITEM_COST, 0), 1000000)
            local platCost = itm:getValue(ITEM_COST, 0) // 1000000
            local crystalCost = CRYSTAL_PRICE[itm.level]
            local s = "Upgrade cost: |n" ---@type string 

            if platCost > 0 then
                s = s .. "|cffffffff" .. (platCost) .. "|r |cffe3e2e2Platinum|r|n"
            end

            if goldCost > 0 then
                s = s .. "|cffffffff" .. (goldCost) .. "|r |cffffcc00Gold|r|n"
            end

            if crystalCost > 0 then
                s = s .. "|cffffffff" .. (crystalCost) .. "|r |cff6969FFCrystals|r|n"
            end

            dw = DialogWindow.create(pid, s, UpgradeItemConfirm)
            dw.data[0] = itm
            dw.data[1] = goldCost
            dw.data[2] = platCost
            dw.data[3] = crystalCost

            if GetCurrency(pid, GOLD) >= goldCost and GetCurrency(pid, PLATINUM) >= platCost and GetCurrency(pid, CRYSTAL) >= crystalCost then
                dw:addButton("Upgrade")
            end

            dw:display()
        end
    end

    return false
end

local stat_enum = {
    "|cff990000Strength|r",
    "|cff006600Agility|r",
    "|cff3333ffIntelligence|r",
    "All Stats",
}

---@type fun(pid: integer, bonus: number, type: integer)
local function StatTome(pid, bonus, type)
    if type == 1 then
        Unit[Hero[pid]].str = Unit[Hero[pid]].str + bonus
    elseif type == 2 then
        Unit[Hero[pid]].agi = Unit[Hero[pid]].agi + bonus
    elseif type == 3 then
        Unit[Hero[pid]].int = Unit[Hero[pid]].int + bonus
    elseif type == 4 then
        Unit[Hero[pid]].str = Unit[Hero[pid]].str + bonus
        Unit[Hero[pid]].agi = Unit[Hero[pid]].agi + bonus
        Unit[Hero[pid]].int = Unit[Hero[pid]].int + bonus
    end

    DisplayTextToPlayer(Player(pid - 1), 0, 0, "You have gained |cffffcc00" .. bonus .. "|r " .. stat_enum[type])

    DestroyEffect(AddSpecialEffectTarget("Objects\\InventoryItems\\tomeRed\\tomeRed.mdl", Hero[pid], "origin"))
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", Hero[pid], "origin"))
end

local function stat_purchase()
    local p   = GetTriggerPlayer()
    local pid = GetPlayerId(p) + 1 ---@type integer 
    local dw    = DialogWindow[pid] ---@type DialogWindow 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

    if index ~= -1 then
        local count = dw.data[index]
        local currency = (count <= 20 and GOLD) or PLATINUM
        local cost = (currency == GOLD and count * 10000) or (count // 100)

        if GetCurrency(pid, currency) >= cost then
            AddCurrency(pid, currency, -cost)
            StatTome(pid, dw.data[10], dw.data[100])
        else
            DisplayTextToPlayer(p, 0., 0., "You do not have enough money!")
        end

        dw:destroy()
    end

    return false
end

local function stat_confirm()
    local p   = GetTriggerPlayer()
    local pid = GetPlayerId(p) + 1 ---@type integer 
    local dw    = DialogWindow[pid] ---@type DialogWindow 
    local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

    if index ~= -1 then
        local count = dw.data[index]
        local type = dw.data[100]
        local final_bonus = 0
        local total_stats = Unit[Hero[pid]].str + Unit[Hero[pid]].agi + Unit[Hero[pid]].int
        local tome_cap = TomeCap(GetHeroLevel(Hero[pid]))
        local name = stat_enum[type]

        dw:destroy()

        for _ = 1, count do
            final_bonus = final_bonus + 100 // ((total_stats + final_bonus) ^ 0.25) * (log(tome_cap / (total_stats + final_bonus) + 0.75, 2.71828) / 3.)
            if total_stats + final_bonus >= tome_cap then
                final_bonus = tome_cap - total_stats
                break
            end
        end

        final_bonus = floor(final_bonus)
        if final_bonus > 0 then
            dw = DialogWindow.create(pid, "Purchase " .. final_bonus .. " " .. name .. "?", stat_purchase)

            dw.data[10] = final_bonus
            dw.data[100] = type
            dw:addButton("Confirm", count)

            dw:display()
        else
            DisplayTextToPlayer(p, 0, 0, "You cannot gain any more stats.")
        end
    end

    return false
end

local function stat_dialog(pid, type)
    local name = stat_enum[type]
    local dw = DialogWindow.create(pid, "Purchase " .. name, stat_confirm)
    local prefix = (type == 4 and "2") or "1"
    local mult = (type == 4 and 2) or 1

    dw:addButton(prefix .. "0,000 Gold", 1 * mult)
    dw:addButton(prefix .. "00,000 Gold", 10 * mult)
    dw:addButton(prefix .. " Platinum", 100 * mult)
    dw:addButton(prefix .. "0 Platinum", 1000 * mult)
    dw:addButton(prefix .. "00 Platinum", 10000 * mult)
    dw.data[100] = type

    dw:display()
end

    -- tomes
    ITEM_LOOKUP[FourCC('I0TS')] = function(p, pid) -- str
        stat_dialog(pid, 1)
    end
    ITEM_LOOKUP[FourCC('I0TA')] = function(p, pid) -- agi
        stat_dialog(pid, 2)
    end
    ITEM_LOOKUP[FourCC('I0TI')] = function(p, pid) -- int
        stat_dialog(pid, 3)
    end
    ITEM_LOOKUP[FourCC('I0TT')] = function(p, pid) -- all
        stat_dialog(pid, 4)
    end

    ITEM_LOOKUP[FourCC('I0N0')] = function(p, pid) -- focus grimoire
        local refund = 0
        if Unit[Hero[pid]].str - 50 > 20 then
            Unit[Hero[pid]].str = Unit[Hero[pid]].str - 50
            refund = refund + 5000
        elseif Unit[Hero[pid]].str >= 20 then
            Unit[Hero[pid]].str = 20
        end
        if Unit[Hero[pid]].agi - 50 > 20 then
            Unit[Hero[pid]].agi = Unit[Hero[pid]].agi - 50
            refund = refund + 5000
        elseif Unit[Hero[pid]].agi >= 20 then
            Unit[Hero[pid]].agi = 20
        end
        if Unit[Hero[pid]].int - 50 > 20 then
            Unit[Hero[pid]].int = Unit[Hero[pid]].int - 50
            refund = refund + 5000
        elseif Unit[Hero[pid]].int >= 20 then
            Unit[Hero[pid]].int = 20
        end
        if refund > 0 then
            AddCurrency(pid, GOLD, refund)
            DisplayTextToPlayer(p, 0, 0, "You have been refunded |cffffcc00" .. RealToString(refund) .. "|r gold.")
        end
    end

    ITEM_LOOKUP[FourCC('I0JN')] = function(p, pid) -- retraining
        UnitAddItemById(Hero[pid], FourCC('Iret'))
    end

    ITEM_LOOKUP[FourCC('I0JS')] = function(p, pid) -- recharge reincarnation
        local it = GetResurrectionItem(pid, true)

        if it and it.charges >= MAX_REINCARNATION_CHARGES then
            it = nil
        end

        if it == nil then
            DisplayTimedTextToPlayer(p, 0, 0, 15, "You have no item to recharge!")
        elseif RECHARGE_COOLDOWN[pid] >= 1 then
            DisplayTimedTextToPlayer(p, 0, 0,15, (RECHARGE_COOLDOWN[pid]) .. " seconds until you can recharge your " .. GetItemName(it.obj))
        else
            RechargeDialog(pid, it)
        end
    end
end, Debug and Debug.getLine())
