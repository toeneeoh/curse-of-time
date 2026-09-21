--[[
    balance_harness.lua

    Development-only item-data export and applied-damage recording. The
    resulting FileIO files are inputs for repeatable breakpoint/build analysis;
    the harness deliberately records real combat rather than reimplementing
    spell formulas outside the damage pipeline.
]]

OnInit.final("BalanceHarness", function(Require)
    Require("DevRuntimeLog")
    Require("DropTable")
    Require("Events")
    Require("HeroDefinitions")
    Require("ItemHelpers")
    Require("Items")
    Require("Profile")
    Require("ShopCatalog")
    Require("TimerQueue")

    local ITEM_SCAN_LIMIT = 9000
    local ITEM_EXPORT_BATCH = 50
    local DEFAULT_DURATION = 60.
    local RIGHT_CLICK_UPTIME = 0.90

    local EXPORT_STATS = {
        { ITEM_HEALTH, "health" },
        { ITEM_MANA, "mana" },
        { ITEM_DAMAGE, "damage" },
        { ITEM_ARMOR, "armor" },
        { ITEM_STRENGTH, "strength" },
        { ITEM_AGILITY, "agility" },
        { ITEM_INTELLIGENCE, "intelligence" },
        { ITEM_REGENERATION, "regeneration" },
        { ITEM_MANA_REGENERATION, "mana_regeneration" },
        { ITEM_DAMAGE_RESIST, "damage_resist" },
        { ITEM_MAGIC_RESIST, "magic_resist" },
        { ITEM_DAMAGE_MULT, "physical_dealt" },
        { ITEM_MAGIC_MULT, "magic_dealt" },
        { ITEM_MOVESPEED, "movespeed" },
        { ITEM_EVASION, "evasion" },
        { ITEM_SPELLBOOST, "spellboost" },
        { ITEM_CRIT_CHANCE, "crit_chance" },
        { ITEM_CRIT_DAMAGE, "crit_damage" },
        { ITEM_BASE_ATTACK_SPEED, "base_attack_speed" },
        { ITEM_GOLD_GAIN, "gold_find" },
    }

    BalanceHarness = {
        sessions = {},
        exporting_items = false,
    }

    local function clean(value)
        local cleaned = tostring(value or "")
            :gsub("|c%x%x%x%x%x%x%x%x", "")
            :gsub("|r", "")
            :gsub("[\t\r\n]", " ")
        return cleaned
    end

    local function rawcode(id)
        return string.pack(">I4", id)
    end

    local function number(value)
        if math.abs(value or 0.) < 0.0000005 then
            return "0"
        end
        local formatted = string.format("%.6f", value):gsub("0+$", ""):gsub("%.$", "")
        return formatted
    end

    local function damage_type_name(damage_type)
        if damage_type == PHYSICAL then
            return "physical"
        elseif damage_type == MAGIC then
            return "magical"
        elseif damage_type == PURE then
            return "pure"
        end
        return "other"
    end

    local function save_for_player(pid, filename, contents)
        if GetLocalPlayer() == Player(pid - 1) then
            FileIO.Save(MAP_NAME .. "\\dev\\" .. filename, contents)
        end
    end

    local function set_quality(item, quality)
        for index = 1, ITEM_ABILITY2 do
            item.quality[index] = quality
        end
        item:cache_stats()
    end

    local function copy_export_stats(item)
        local values = {}
        for index, definition in ipairs(EXPORT_STATS) do
            values[index] = item.cached_stats[definition[1]] or 0.
        end
        return values
    end

    local function average_export_stats(item)
        local values = {}
        for index = 1, #EXPORT_STATS do values[index] = 0. end

        for quality = 0, 63 do
            for index = 1, ITEM_ABILITY2 do
                item.quality[index] = quality
            end
            for index, definition in ipairs(EXPORT_STATS) do
                values[index] = values[index] + item:calculateValue(definition[1])
            end
        end

        for index = 1, #values do values[index] = values[index] / 64. end
        return values
    end

    local function append_item_row(lines, availability, id)
        local name = GetObjectName(id)
        if name == "" or name == "Default string" then
            return
        end

        local item = ItemRuntime.create(id, 30000., 30000.)
        if not item or item.id ~= id then
            if item then item:destroy() end
            return
        end

        local data = ItemData[id]
        local max_level = data[ITEM_UPGRADE_MAX]
        item.level = max_level

        local average = average_export_stats(item)
        set_quality(item, 63.)
        local perfect = copy_export_stats(item)

        local row = {
            rawcode(id), clean(data.name ~= 0 and data.name or name),
            tostring(data[ITEM_TYPE]), tostring(data[ITEM_LEVEL_REQUIREMENT]),
            tostring(max_level), tostring(data[ITEM_TIER]),
            tostring(data[ITEM_RARITY]), tostring(data[ITEM_LIMIT]),
            availability[id] and availability[id].drop and "1" or "0",
            availability[id] and availability[id].shop and "1" or "0",
            ItemRuntime.definitions[id] and "1" or "0",
        }

        for index = 1, #EXPORT_STATS do
            row[#row + 1] = number(average[index])
            row[#row + 1] = number(perfect[index])
        end

        row[#row + 1] = data[ITEM_ABILITY .. "id"] ~= 0
            and rawcode(data[ITEM_ABILITY .. "id"]) or ""
        row[#row + 1] = tostring(data[ITEM_ABILITY .. "unlock"])
        row[#row + 1] = clean(data[ITEM_ABILITY .. "data"])
        row[#row + 1] = data[ITEM_ABILITY2 .. "id"] ~= 0
            and rawcode(data[ITEM_ABILITY2 .. "id"]) or ""
        row[#row + 1] = tostring(data[ITEM_ABILITY2 .. "unlock"])
        row[#row + 1] = clean(data[ITEM_ABILITY2 .. "data"])

        lines[#lines + 1] = table.concat(row, "\t")
        item:destroy()
    end

    local function build_availability()
        local availability = {}
        local function mark(id, source)
            if not id or id == 0 then return end
            availability[id] = availability[id] or {}
            availability[id][source] = true
        end

        for _, pool in pairs(ItemDrops) do
            if type(pool) == "table" then
                for index = 1, pool[100] do
                    mark(pool[index], "drop")
                end
            end
        end

        for _, shop_item in pairs(ShopItem.itempool) do
            if type(shop_item) == "table" and shop_item.id then
                local _, id = GetItem(shop_item.id)
                mark(id, "shop")
            end
        end

        return availability
    end

    local function export_heroes(pid)
        local lines = {
            "rawcode\tname\tproficiency_mask\tmain_attribute\trange\tbase_strength\tbase_agility\tbase_intelligence\tstrength_gain\tagility_gain\tintelligence_gain\tphysical_dealt\tphysical_taken\tmagical_taken\tbase_armor\tbase_crit_chance\tbase_crit_damage\tskills",
        }

        for id, definition in pairs(HERO_STATS) do
            local skills = {}
            for index, skill in ipairs(definition.skills or {}) do
                skills[index] = skill
            end
            lines[#lines + 1] = table.concat({
                rawcode(id), clean(GetObjectName(id)), definition.prof,
                definition.main, definition.range,
                number(definition.str), number(definition.agi), number(definition.int),
                number(definition.str_gain), number(definition.agi_gain), number(definition.int_gain),
                number(definition.phys_damage), number(definition.phys_resist),
                number(definition.magic_resist), number(definition.armor),
                number(definition.crit_chance), number(definition.crit_damage),
                table.concat(skills, ","),
            }, "\t")
        end

        table.sort(lines, function(a, b) return a < b end)
        -- Keep the schema header above the sorted hero rows.
        for index = 1, #lines do
            if lines[index]:sub(1, 7) == "rawcode" then
                lines[1], lines[index] = lines[index], lines[1]
                break
            end
        end
        save_for_player(pid, "balance-heroes-player-" .. pid .. ".pld",
            table.concat(lines, "\n") .. "\n")
    end

    ---Exports every custom item using the same parser and value calculation as
    ---the runtime item system. Values use maximum upgrade level; each stat has
    ---an expected-roll and perfect-roll column.
    ---@param pid integer
    function BalanceHarness.exportItems(pid)
        if BalanceHarness.exporting_items then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "A balance item export is already running.")
            return
        end

        BalanceHarness.exporting_items = true
        local availability = build_availability()
        local lines = {}
        local header = {
            "rawcode", "name", "type", "requirement", "max_upgrade", "tier", "rarity", "limit",
            "drop_pool", "shop_catalog", "runtime_definition",
        }
        for _, definition in ipairs(EXPORT_STATS) do
            header[#header + 1] = definition[2] .. "_average"
            header[#header + 1] = definition[2] .. "_perfect"
        end
        header[#header + 1] = "ability_1"
        header[#header + 1] = "ability_1_unlock"
        header[#header + 1] = "ability_1_data"
        header[#header + 1] = "ability_2"
        header[#header + 1] = "ability_2_unlock"
        header[#header + 1] = "ability_2_data"
        lines[1] = table.concat(header, "\t")

        local offset = 0
        local function process_batch()
            local last = math.min(ITEM_SCAN_LIMIT, offset + ITEM_EXPORT_BATCH - 1)
            for index = offset, last do
                append_item_row(lines, availability, CUSTOM_ITEM_OFFSET + index)
            end
            offset = last + 1

            if offset <= ITEM_SCAN_LIMIT then
                TimerQueue:callDelayed(0.01, process_batch)
                return
            end

            local filename = "balance-items-player-" .. pid .. ".pld"
            save_for_player(pid, filename, table.concat(lines, "\n") .. "\n")
            export_heroes(pid)
            BalanceHarness.exporting_items = false
            DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                "Exported " .. (#lines - 1) .. " item definitions to " .. filename .. ".")
        end

        DisplayTextToPlayer(Player(pid - 1), 0., 0., "Balance item export started.")
        process_batch()
    end

    local function append_snapshot(lines, pid, prefix)
        local hero = Hero[pid]
        if not hero then return end

        local unit = Unit[hero]
        local agi = GetHeroAgi(hero, true)
        local crit_multiplier = 1. + math.min(100., unit.cc) * 0.01 * unit.cd * 0.01
        local attacks_per_second = (1. / unit.bat) * (1. + math.min(agi, 400) * 0.01)
        local raw_attack_dps = (unit.damage + 1.) * crit_multiplier * attacks_per_second
            * unit.dm * unit.pm * RIGHT_CLICK_UPTIME

        lines[#lines + 1] = table.concat({
            prefix, "hero", rawcode(GetUnitTypeId(hero)), clean(GetUnitName(hero)),
            "level", GetHeroLevel(hero),
        }, "\t")
        lines[#lines + 1] = table.concat({
            prefix, "stats",
            "strength", number(GetHeroStr(hero, true)),
            "agility", number(agi),
            "intelligence", number(GetHeroInt(hero, true)),
            "damage", number(unit.damage + 1.),
            "armor", number(BlzGetUnitArmor(hero)),
            "health", number(BlzGetUnitMaxHP(hero)),
            "mana", number(BlzGetUnitMaxMana(hero)),
            "physical_dealt", number(unit.dm * unit.pm),
            "magical_dealt", number(unit.dm * unit.mm),
            "spellboost", number(unit.spellboost),
            "crit_chance", number(unit.cc),
            "crit_damage", number(unit.cd),
            "bat", number(unit.bat),
            "attacks_per_second", number(attacks_per_second),
            "attack_dps_90pct", number(raw_attack_dps),
        }, "\t")

        local profile = Profile[pid]
        local inventory = profile and profile.hero and profile.hero.items
        if inventory then
            for slot = 1, 6 do
                local item = inventory[slot]
                if item then
                    local row = {
                        prefix, "item", slot, rawcode(item.id), clean(item:name()),
                        "upgrade", item.level,
                    }
                    for _, definition in ipairs(EXPORT_STATS) do
                        local value = item.cached_stats[definition[1]] or 0.
                        if value ~= 0. then
                            row[#row + 1] = definition[2]
                            row[#row + 1] = number(value)
                        end
                    end
                    for socket_index, socket in ipairs(item.sockets or {}) do
                        row[#row + 1] = "socket_" .. socket_index
                        row[#row + 1] = rawcode(socket.id) .. ":" .. socket.level
                    end
                    lines[#lines + 1] = table.concat(row, "\t")
                end
            end
        end
    end

    local function append_target_snapshot(lines, pid)
        local target = PLAYER_SELECTED_UNIT[pid]
        if not target or target == Hero[pid] then return end

        local unit = Unit[target]
        lines[#lines + 1] = table.concat({
            "start", "target", rawcode(GetUnitTypeId(target)), clean(GetUnitName(target)),
            "level", GetUnitLevel(target),
            "health", number(BlzGetUnitMaxHP(target)),
            "armor", number(BlzGetUnitArmor(target)),
            "defense_type", BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE),
            "physical_taken", number(unit.dr * unit.pr),
            "magical_taken", number(unit.dr * unit.mr),
        }, "\t")
    end

    local function damage_recorder(pid, source, target, applied_amount, displayed_amount,
            damage_type, tag, is_basic_attack)
        local session = BalanceHarness.sessions[pid]
        if not session or displayed_amount <= 0. or not IsUnitEnemy(target, Player(pid - 1)) then
            return
        end

        local label = tag
        if not label or label == "" then
            label = is_basic_attack and "Basic Attack" or "Untagged"
        end

        local key = table.concat({
            rawcode(GetUnitTypeId(source)), clean(GetUnitName(source)),
            damage_type_name(damage_type), clean(label),
        }, "\t")
        local entry = session.damage[key]
        if not entry then
            entry = { total = 0., applied = 0., count = 0, maximum = 0. }
            session.damage[key] = entry
        end

        entry.total = entry.total + displayed_amount
        entry.applied = entry.applied + applied_amount
        entry.count = entry.count + 1
        entry.maximum = math.max(entry.maximum, displayed_amount)
        session.total = session.total + displayed_amount
        session.applied_total = session.applied_total + applied_amount
        if not session.targets[target] then
            session.targets[target] = true
            session.target_count = session.target_count + 1
        end
    end

    ---@param pid integer
    ---@param reason string?
    function BalanceHarness.stop(pid, reason)
        local session = BalanceHarness.sessions[pid]
        if not session then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "No balance recording is active.")
            return
        end

        BalanceHarness.sessions[pid] = nil
        EVENT_PLAYER_DAMAGE_APPLIED:unregister_action(pid, damage_recorder)
        local elapsed = math.max(0.001, session.stopwatch:getElapsed())
        session.stopwatch:destroy()

        local lines = {
            session.start_snapshot,
            table.concat({ "session", clean(session.label), "elapsed", number(elapsed),
                "reason", clean(reason or "manual") }, "\t"),
        }
        append_snapshot(lines, pid, "end")

        local entries = {}
        for key, entry in pairs(session.damage) do
            entries[#entries + 1] = { key = key, data = entry }
        end
        table.sort(entries, function(a, b) return a.data.total > b.data.total end)

        lines[#lines + 1] = table.concat({
            "total", number(session.total), "dps", number(session.total / elapsed),
            "applied_total", number(session.applied_total),
            "targets_hit", session.target_count,
        }, "\t")
        for _, result in ipairs(entries) do
            local entry = result.data
            lines[#lines + 1] = table.concat({
                "damage", result.key, "count", entry.count,
                "total", number(entry.total), "dps", number(entry.total / elapsed),
                "applied", number(entry.applied),
                "average", number(entry.total / entry.count), "maximum", number(entry.maximum),
            }, "\t")
        end

        local filename = "balance-combat-player-" .. pid .. "-" .. session.filename .. ".pld"
        save_for_player(pid, filename, table.concat(lines, "\n") .. "\n")
        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            string.format("Balance recording complete: %.1f seconds, %.1f DPS. Saved to %s.",
                elapsed, session.total / elapsed, filename))
    end

    ---@param pid integer
    ---@param duration number?
    ---@param label string?
    function BalanceHarness.start(pid, duration, label)
        if BalanceHarness.sessions[pid] then
            BalanceHarness.stop(pid, "restarted")
        end

        local hero = Hero[pid]
        if not hero then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Select a hero before recording.")
            return
        end

        duration = math.max(1., duration or DEFAULT_DURATION)
        label = label and label ~= "" and label or (clean(GetUnitName(hero)) .. "-level-" .. GetHeroLevel(hero))
        local filename = label:lower():gsub("[^%w%-]+", "-"):gsub("%-+", "-")
        local session = {
            hero = hero,
            label = label,
            filename = filename,
            damage = {},
            total = 0.,
            applied_total = 0.,
            targets = setmetatable({}, { __mode = "k" }),
            target_count = 0,
            stopwatch = Stopwatch.create(true),
        }
        BalanceHarness.sessions[pid] = session
        EVENT_PLAYER_DAMAGE_APPLIED:register_action(pid, damage_recorder)

        local start_lines = {}
        append_snapshot(start_lines, pid, "start")
        append_target_snapshot(start_lines, pid)
        session.start_snapshot = table.concat(start_lines, "\n")

        TimerQueue:callDelayed(duration, function()
            if BalanceHarness.sessions[pid] == session then
                BalanceHarness.stop(pid, "duration")
            end
        end)

        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            string.format("Recording %.0f seconds for %s. Begin the test rotation now.", duration, label))
    end

    ---Writes a build/stat snapshot without starting a combat recording.
    ---@param pid integer
    ---@param label string?
    function BalanceHarness.snapshot(pid, label)
        local lines = {}
        append_snapshot(lines, pid, "snapshot")
        local filename = "balance-snapshot-player-" .. pid .. "-"
            .. (label or "current"):lower():gsub("[^%w%-]+", "-") .. ".pld"
        save_for_player(pid, filename, table.concat(lines, "\n") .. "\n")
        DisplayTextToPlayer(Player(pid - 1), 0., 0., "Balance snapshot saved to " .. filename .. ".")
    end

    ---Replaces the six equipped items with a generated benchmark loadout.
    ---`average` uses the nearest representable midpoint roll (quality 32),
    ---while `perfect` uses quality 63. This is development-only and destructive
    ---to the currently equipped items.
    ---@param pid integer
    ---@param roll string
    ---@param rawcodes string[]
    function BalanceHarness.equip(pid, roll, rawcodes)
        if not Hero[pid] then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Select a hero before equipping a balance build.")
            return
        elseif roll ~= "average" and roll ~= "perfect" then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Roll must be 'average' or 'perfect'.")
            return
        elseif #rawcodes ~= 6 then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "A balance build requires exactly six item rawcodes.")
            return
        end

        local ids = {}
        for index, code in ipairs(rawcodes) do
            if code:len() ~= 4 then
                DisplayTextToPlayer(Player(pid - 1), 0., 0., "Invalid item rawcode: " .. code)
                return
            end
            ids[index] = FourCC(code)
            if ItemData[ids[index]].name == 0 then
                DisplayTextToPlayer(Player(pid - 1), 0., 0., "Unknown item rawcode: " .. code)
                return
            end
        end

        local inventory = Profile[pid].hero.items
        for slot = 1, 6 do
            local item = inventory[slot]
            if item then item:destroy() end
        end

        local quality = roll == "perfect" and 63 or 32
        for _, id in ipairs(ids) do
            local item = ItemRuntime.create(id, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
            item.level = ItemData[id][ITEM_UPGRADE_MAX]
            for index = 1, ITEM_ABILITY2 do
                item.quality[index] = quality
            end
            item:update()
            PlayerAddItem(pid, item)
        end

        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            "Equipped " .. roll .. " benchmark build. Existing equipped items were removed.")
    end
end, Debug and Debug.getLine())
