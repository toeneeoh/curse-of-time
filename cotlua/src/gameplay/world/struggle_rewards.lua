--[[
    struggle_rewards.lua

    Defines the 100-rank Struggle reward independently of the ordinary
    20-level item rarity curve. The ring is its pre-Chaos carrier; at level 200
    it can be crystallized into an equivalent socketable gem.
]]

OnInit.final("StruggleRewards", function(Require)
    Require('Items')
    Require('ItemHelpers')
    Require('Profile')
    Require('Struggle')

    StruggleRewards = {}

    local RING_ID = FourCC('I0D0')
    local GEM_ID = FourCC('I00T')
    local MAX_RANK = 100
    local GEM_LEVEL_REQUIREMENT = 200

    local function clamp_rank(rank)
        return math.max(1, math.min(MAX_RANK, math.floor(rank or 1)))
    end

    local function rank_from_wave(wave)
        return clamp_rank(math.floor(math.max(5, wave) / 5))
    end

    local function attribute_bonus(rank)
        return math.floor(10. * rank ^ 1.65 + 0.5)
    end

    local function percentage_bonus(rank)
        return math.floor(rank / 10)
    end

    ---@param base_name string
    ---@param level_requirement integer
    ---@param item_type integer
    ---@return RuntimeItemDefinition
    local function reward_definition(base_name, level_requirement, item_type)
        return {
            custom_level = true,
            flavor = base_name == "Struggle Gem"
                and "|cff808080A crystallized record of the deepest Struggle overcome by this hero.|r"
                or "|cff808080A record of the deepest Struggle overcome by this hero.|r",
            prepare = function(_, data)
                data[ITEM_TIER] = 3
                data[ITEM_TYPE] = item_type
                data[ITEM_UPGRADE_MAX] = 0
                data[ITEM_LEVEL_REQUIREMENT] = level_requirement
                data[ITEM_LIMIT] = 1
                data[ITEM_NOCRAFT] = 1
            end,
            calculateValue = function(item, stat)
                local rank = clamp_rank(item.level)
                if stat == ITEM_STRENGTH or stat == ITEM_AGILITY or stat == ITEM_INTELLIGENCE then
                    return attribute_bonus(rank)
                elseif stat == ITEM_SPELLBOOST or stat == ITEM_GOLD_GAIN then
                    return percentage_bonus(rank)
                elseif stat <= TOTAL_STATS then
                    -- Custom ranks extend far beyond the ordinary 20-level item
                    -- multiplier table, so every other cached field must be
                    -- resolved here instead of falling through to normal scaling.
                    return 0
                end
                return nil
            end,
            name = function(item)
                return base_name .. " |cffffcc00[Rank " .. clamp_rank(item.level) .. "]|r"
            end,
            appendHeader = function(item, text, alt_text)
                local rank = clamp_rank(item.level)
                local header = "|cffffcc00Struggle Rank:|r " .. rank .. "/" .. MAX_RANK
                    .. "|n|cff808080Secured at wave " .. rank * 5 .. "|r|n"
                text[#text + 1] = header
                alt_text[#alt_text + 1] = header
            end,
        }
    end

    ItemRuntime.define(RING_ID, reward_definition("Ring of Struggle", 0, 0))
    ItemRuntime.define(GEM_ID, reward_definition("Struggle Gem", GEM_LEVEL_REQUIREMENT, 12))

    ---@param pid integer
    ---@return Item?, Item?
    local function find_reward(pid)
        local profile = Profile[pid]
        local items = profile and profile.hero and profile.hero.items
        if not items then return nil, nil end

        for slot = 1, MAX_INVENTORY_SLOTS do
            local item = items[slot]
            if item then
                if item.id == RING_ID or item.id == GEM_ID then
                    return item, nil
                end
                for _, socket in ipairs(item.sockets or {}) do
                    if socket.id == GEM_ID then
                        return socket, item
                    end
                end
            end
        end
        return nil, nil
    end

    ---@param pid integer
    ---@param rawcode integer
    ---@param rank integer
    ---@return Item
    local function grant(pid, rawcode, rank)
        local item_id = rawcode == GEM_ID and "I00T:" or "I0D0:"
        return PlayerAddItemById(pid, item_id .. clamp_rank(rank))
    end

    ---@param pid integer
    ---@param gem boolean
    ---@return boolean, string?
    function StruggleRewards.canRedeem(pid, gem)
        local hero = Hero[pid]
        local level = hero and GetUnitLevel(hero) or 0
        if gem and level < GEM_LEVEL_REQUIREMENT then
            return false, "LEVEL 200"
        elseif not gem and level >= GEM_LEVEL_REQUIREMENT then
            return false, "USE GEM"
        end

        local wave = Struggle.getClaimWave(pid)
        if wave < 5 then
            return false, "NO CLAIM"
        end

        local rank = rank_from_wave(wave)
        local existing = find_reward(pid)
        if existing and existing.level >= rank
            and existing.id == (gem and GEM_ID or RING_ID) then
            return false, "NO UPGRADE"
        end
        return true
    end

    ---@param pid integer
    ---@param gem boolean
    ---@return boolean
    function StruggleRewards.redeem(pid, gem)
        if not StruggleRewards.canRedeem(pid, gem) then
            return false
        end

        local wave = Struggle.getClaimWave(pid)
        local rank = rank_from_wave(wave)
        local rawcode = gem and GEM_ID or RING_ID
        local existing = find_reward(pid)

        if existing and existing.id == rawcode then
            existing:lvl(math.max(existing.level, rank))
        else
            if existing then
                existing:destroy()
            end
            grant(pid, rawcode, rank)
        end

        return Struggle.consumeClaim(pid, wave)
    end

    ---@param pid integer
    ---@return boolean, string?
    function StruggleRewards.canConvert(pid)
        local hero = Hero[pid]
        if not hero or GetUnitLevel(hero) < GEM_LEVEL_REQUIREMENT then
            return false, "LEVEL 200"
        end

        local existing, parent = find_reward(pid)
        if parent then
            return false, "ALREADY SOCKETED"
        elseif not existing or existing.id ~= RING_ID then
            return false, "NO RING"
        elseif #(existing.sockets or {}) > 0 then
            return false, "REMOVE SOCKETS"
        end
        return true
    end

    ---@param pid integer
    ---@return boolean
    function StruggleRewards.convert(pid)
        if not StruggleRewards.canConvert(pid) then
            return false
        end

        local ring = find_reward(pid)
        local rank = clamp_rank(ring.level)
        ring:destroy()
        grant(pid, GEM_ID, rank)
        return true
    end

    function StruggleRewards.getClaimRank(pid)
        local wave = Struggle.getClaimWave(pid)
        return wave >= 5 and rank_from_wave(wave) or 0
    end

    function StruggleRewards.getAttributeBonus(rank)
        return attribute_bonus(clamp_rank(rank))
    end

    function StruggleRewards.getPercentageBonus(rank)
        return percentage_bonus(clamp_rank(rank))
    end
end, Debug and Debug.getLine())
