--[[
    spells.lua

    A library that handles spell related events:
        (EVENT_PLAYER_UNIT_SPELL_EFFECT,
        EVENT_PLAYER_UNIT_SPELL_CAST,
        EVENT_PLAYER_UNIT_SPELL_FINISH,
        EVENT_PLAYER_HERO_SKILL,
        EVENT_PLAYER_UNIT_SPELL_CHANNEL)

    Provides a spell object factory for defining abilities by their ID
]] OnInit.final("Spells", function(Require)
    Require("Users")
    Require("UnitEvent")
    Require("UnitTable")
    Require("Mouse")

    -- Refresh dynamic spell data only when a registered spell is actually
    -- added. The native return value is part of UnitAddAbility's contract and
    -- is used by callers to decide whether one-time setup is necessary.
    local OldUnitAddAbility = UnitAddAbility
    UnitAddAbility = function(u, id)
        local added = OldUnitAddAbility(u, id)

        if added and Spells and Spells[id] then
            EVENT_STAT_CHANGE:trigger(u, "int")
        end

        return added
    end

    -- storage for spell definitions
    Spells = {} ---@type Spell[]

    local Spells = Spells
    local real_to_string = RealToString
    local HL = HL
    local format = string.format
    local pattern = "(~?)(>?)([\\{%[])(%w-)=(.-)]"
    local gsub = string.gsub
    -- Existing native {tag=...] placeholders used one half-Spellboost
    -- multiplier. Route each known tag to its actual mechanic instead.
    local area_tags = {aoe = true, aoe2 = true, iceaoe = true, orbaoe = true,
        range = true, spinaoe = true, knockaoe = true, shoutaoe = true}
    local duration_tags = {dur = true, freeze = true, wardur = true,
        peacedur = true, fatiguedur = true, knockdur = true,
        shoutdur = true, tornadodur = true}
    local times_duration = {[FourCC('A098')] = true, [FourCC('A0MN')] = true}
    local function tooltip_scaling_kind(spell, tag)
        local kind = spell.tooltip_scaling and spell.tooltip_scaling[tag]
        if kind == "none" then return "none" end
        if kind == "area" or (not kind and area_tags[tag]) then
            return "area"
        end
        if kind == "duration" or (not kind and (duration_tags[tag] or
            (tag == "times" and times_duration[spell.id]))) then
            return "duration"
        end
        return "half_power"
    end
    function SpellTooltipMultiplier(spell, u, tag)
        local unit = Unit[u]
        local kind = tooltip_scaling_kind(spell, tag)
        if kind == "none" then return 1. end
        if kind == "area" then return math.max(0., 1. + unit.spell_area) end
        if kind == "duration" then return math.max(0., 1. + unit.spell_duration) end
        return 1. + 0.5 * unit.spellboost
    end

    -- Rewrite only text outside native color codes. A regex over the whole
    -- tooltip can consume the last hex digit: |c000080c03 contains "03".
    function TagSpellDurationTooltip(text)
        local parts, cursor = {}, 1
        while cursor <= #text do
            local first, last = text:find("|c%x%x%x%x%x%x%x%x", cursor)
            local boundary = first or (#text + 1)
            local plain, count = text:sub(cursor, boundary - 1):gsub("(%d+) second duration", ">{dur=%1] second duration", 1)
            parts[#parts + 1] = plain
            if count > 0 then
                parts[#parts + 1] = text:sub(boundary)
                return table.concat(parts)
            end
            if not first then return table.concat(parts) end
            parts[#parts + 1] = text:sub(first, last)
            cursor = last + 1
        end
        return table.concat(parts)
    end

    -- Derive the note from the same tags that calculate displayed values.
    -- Explicit notes cover mechanics delegated to buffs/other spell definitions;
    -- an empty override deliberately suppresses the note.
    function SpellScalingTooltip(spell, orig, result)
        local note = spell.scaling_note
        if note == nil then
            local kinds = {}
            if spell.values then
                for _, _, prefix, tag in orig:gmatch(pattern) do
                    if spell.values[tag] ~= nil then
                        if prefix == "[" then kinds.power = true
                        elseif prefix == "{" then kinds[tooltip_scaling_kind(spell, tag)] = true end
                    end
                end
            end
            local stats = {}
            if kinds.power or kinds.half_power then
                stats[#stats + 1] = "Spell Power"
            end
            if kinds.duration then stats[#stats + 1] = "Spell Duration" end
            if kinds.area then stats[#stats + 1] = "Spell Area" end
            if #stats == 0 then return result end
            note = "Improved by: " .. table.concat(stats, ", ") .. "."
        end
        if note == "" then return result end
        note = "|cff40e0d0* " .. note .. "|r"
        -- Explain markers after every value, including duration and costs.
        -- Preserve native text and colors without guessing footer boundaries.
        return result:gsub("%s+$", "") .. "\n" .. note
    end

    -- ASCII-only markers. Restore the native surrounding color so units such
    -- as %, seconds, and AoE retain their existing formatting after the star.
    local function tooltip_color_before(text, position)
        local color, cursor = "|r", 1
        while true do
            local start = text:find("|[cr]", cursor)
            if not start or start >= position then return color end
            if text:sub(start, start + 1) == "|r" then
                color, cursor = "|r", start + 2
            else
                local code = text:sub(start, start + 9)
                if code:match("^|c%x%x%x%x%x%x%x%x$") then color = code end
                cursor = start + 10
            end
        end
    end
    local function mark_scaling_value(spell, prefix, tag, value, alt)
        local kind = prefix == "[" and "power" or
            (prefix == "{" and tooltip_scaling_kind(spell, tag) or "none")
        if kind == "none" then return value end
        if alt then return value .. (kind == "half_power" and "\1" or "") end
        return value .. "\2"
    end

    -- Move annotations past native color resets and a percentage unit. Private
    -- sentinels never reach a frame/native tooltip. No arbitrary prose is moved.
    local function place_scaling_annotations(text)
        local parts, start = {}, 1
        local function skip_colors(cursor)
            while true do
                if text:sub(cursor, cursor + 1) == "|r" then cursor = cursor + 2
                elseif text:sub(cursor, cursor + 9):match("^|c%x%x%x%x%x%x%x%x$") then cursor = cursor + 10
                else return cursor end
            end
        end
        while true do
            local position = text:find("[\1\2]", start)
            if not position then parts[#parts + 1] = text:sub(start); break end
            local half = text:sub(position, position) == "\1"
            local cursor = skip_colors(position + 1)
            if text:sub(cursor, cursor) == "%" then
                cursor = skip_colors(cursor + 1)
            end
            parts[#parts + 1] = text:sub(start, position - 1) .. text:sub(position + 1, cursor - 1)
            parts[#parts + 1] = "|cff40e0d0" .. (half and " (50% scaling)" or "*") .. tooltip_color_before(text, cursor)
            start = cursor
        end
        return table.concat(parts)
    end

    -- set by getTooltip before calling gsub
    local current_spell ---@type Spell
    local current_unit ---@type unit
    local current_pid ---@type integer
    local current_alt ---@type boolean

    SONG_WAR = FourCC('A024') ---@type integer
    SONG_HARMONY = FourCC('A01A') ---@type integer
    SONG_PEACE = FourCC('A09X') ---@type integer
    SONG_FATIGUE = FourCC('A00N') ---@type integer
    LAST_CAST = __jarray(0) ---@type integer[]

    INVALID_TARGET_MESSAGE = "|cffff0000Cannot target there!|r" ---@type string

    ---@class Spell
    ---@field id integer
    ---@field sid integer
    ---@field caster unit
    ---@field target unit
    ---@field pid integer
    ---@field tpid integer
    ---@field ablev integer
    ---@field x number
    ---@field y number
    ---@field targetX number
    ---@field targetY number
    ---@field angle number
    ---@field values table
    ---@field tooltip_scaling? table<string, string> Explicit area/duration/power/none overrides.
    ---@field scaling_note? string Override automatic scaling prose for delegated mechanics; empty hides it.
    ---@field tooltip_rewrite? fun(text: string): string Correct native formula tags without editing object data.
    ---@field create function
    ---@field onEquip function
    ---@field onUnequip function
    ---@field onSetup function
    ---@field tag string
    ---@field define function
    ---@field getTooltip function
    ---@field setTooltip function
    ---@field preCast function
    ---@field onCast function
    ---@field onLearn function
    ---@field TOOLTIPS string[][]
    ---@field ACTIVE boolean
    ---@field ITEM_NATIVE_ABILITY? boolean Attach a native item ability even when passive.
    ---@field cooldown number
    Spell = {}
    do
        local thistype = Spell
        thistype.TOOLTIPS = array2d("")

        -- memoize metatables for inheritance
        local mts = {}

        ---@type fun(self: Spell, u: unit): Spell
        function thistype:create(u)
            local spell = {
                caster = u,
                pid = GetPlayerId(GetOwningPlayer(u)) + 1,
                ablev = GetUnitAbilityLevel(u, self.id)
            }

            mts[self] = mts[self] or {__index = self}

            setmetatable(spell, mts[self])

            -- precalculate function values
            if self.values then
                for k, v in pairs(self.values) do -- sync safe
                    if type(v) == "function" then
                        spell[k] = v(spell.pid, u)
                    else
                        spell[k] = v
                    end
                end
            end

            return spell
        end

        local mt = {
            __index = function(tbl, key)
                local v = rawget(tbl, "values")
                return Spell[key] or (v and v[key])
            end
        }

        local function store_tooltip(id)
            UnitAddAbility(DUMMY_UNIT, id)
            local abil = BlzGetUnitAbility(DUMMY_UNIT, id)
            for ablev = 1, BlzGetAbilityIntegerField(abil, ABILITY_IF_LEVELS) do
                Spell.TOOLTIPS[id][ablev] =
                    BlzGetAbilityStringLevelField(abil,
                                                  ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED,
                                                  ablev - 1)
            end
            UnitRemoveAbility(DUMMY_UNIT, id)
        end

        -- defines a new spell type by ID
        ---@param id integer
        ---@param ... any
        ---@return table
        function thistype.define(id, ...)
            local self = {}

            self.id = FourCC(id)
            self.tag = GetObjectName(self.id) -- lazy tag generation
            self.ACTIVE = true -- player-activated; item modules classify explicitly

            setmetatable(self, mt)

            Spells[self.id] = self

            -- store original tooltips
            store_tooltip(self.id)

            -- if multiple ids share a definition, store them
            if ... then
                self.shared = {self.id}
                for i = 1, select('#', ...) do
                    id = FourCC(select(i, ...))
                    Spells[id] = self
                    self.shared[#self.shared + 1] = id
                end
            end

            return self
        end

        local alt_down = {} ---@type boolean[]
        local function update_player_tooltips(pid)
            local hero = Hero[pid]
            local selected = PLAYER_SELECTED_UNIT[pid]

            if hero then UpdateSpellTooltips(hero) end
            if selected and selected ~= hero then
                UpdateSpellTooltips(selected)
            end
        end

        local function update_selected_tooltips(_, selected)
            if selected then UpdateSpellTooltips(selected) end
        end

        local function extended_spell_tooltip(pid, is_down)
            if alt_down[pid] ~= is_down then
                alt_down[pid] = is_down
                update_player_tooltips(pid)
            end
        end

        RegisterHotkeyToFunc('ALT', nil, extended_spell_tooltip, nil, true)
        RegisterHotkeyToFunc('ALT+ALT', nil, extended_spell_tooltip, nil, true)

        local user = User.first
        while user do
            EVENT_ON_SELECT:register_action(user.id, update_selected_tooltips)
            user = user.next
        end

        local function tooltip_replacer(defaultflag, colorflag, prefix, tag,
                                        content)
            local self = current_spell
            local u = current_unit

            -- ~ values are always calculated, but half-power details remain
            -- Alt-only even for these always-dynamic values.
            local alt = current_alt or (defaultflag == "~")

            local color = (colorflag ~= ">")

            -- lookup value
            local val = self[tag]
            if val == nil then return content end

            local function marked(value)
                return mark_scaling_value(self, prefix, tag, value, current_alt)
            end
            if not u or not alt then return marked(content) end

            local calc = (type(val) == "table") and val[current_pid] or val

            if prefix == "[" then
                local sb = Unit[u].spellboost
                return marked(HL(real_to_string(calc *
                                             (1 + sb + MIN_SPELLBOOST_VARIANCE)) ..
                              " - " ..
                              real_to_string(
                                  calc * (1 + sb + MAX_SPELLBOOST_VARIANCE)),
                          color))

            elseif prefix == "{" then
                local mult = SpellTooltipMultiplier(self, u, tag)
                local v = calc * mult
                local out
                if v < 1000 then
                    out = format("%.2f", v)
                else
                    out = real_to_string(v)
                end
                return marked(HL(out, color))

            elseif prefix == "\\" then
                return HL(real_to_string(calc), color)
            end

            return content
        end

        ---@type fun(self: Spell, u: unit?, ablev: integer?): string
        function thistype:getTooltip(u, ablev)
            local level = ablev or self.ablev or 1
            -- Native object tooltips still use the old player-facing stat name.
            local orig = gsub(thistype.TOOLTIPS[self.id][level], "Spellboost", "Spell Power")
            if self.tooltip_rewrite then orig = self.tooltip_rewrite(orig) end

            -- just return raw tooltip if no dynamic values
            if not self.values or (not string.find(orig, "=", 1, true)) then
                return SpellScalingTooltip(self, orig, orig)
            end

            -- set context for the replacer
            current_spell = self
            current_unit = u
            current_pid = self.pid
            current_alt = alt_down[self.pid] or false

            local result = gsub(orig, pattern, tooltip_replacer)
            result = place_scaling_annotations(result)

            return SpellScalingTooltip(self, orig, result)
        end

        ---@type fun(self: Spell, u: unit, sid: integer?)
        function thistype:setTooltip(u, sid)
            local ablev = GetUnitAbilityLevel(u, sid)
            local skill = self:create(u)
            local tooltip = skill:getTooltip(u, ablev)
            -- Resolve the native ability handle in synchronized execution;
            -- only the tooltip string writes belong in local presentation.
            local ability = BlzGetUnitAbility(u, sid)

            if GetLocalPlayer() == GetOwningPlayer(u) then
                if ability then
                    BlzSetAbilityStringLevelField(ability,
                                                  ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED,
                                                  ablev - 1, tooltip)
                end
                BlzSetAbilityExtendedTooltip(sid, tooltip, ablev - 1)
                BlzSetAbilityActivatedExtendedTooltip(sid, tooltip, ablev - 1)
            end
        end

        -- Stub methods
        function thistype.preCast(pid, tpid, caster, target, x, y, targetX,
                                  targetY) end
        function thistype.onCast() end
        function thistype.onUnequip(itm, id, index, orig_holder) end
        function thistype.onEquip(itm, id, index) end
        -- function thistype.onLearn(source, ablev, pid) end
        -- function thistype.onSetup(source) end
    end

    local function SpellCast()
        local caster = GetTriggerUnit() ---@type unit
        local target = GetSpellTargetUnit() ---@type unit
        local sid = GetSpellAbilityId() ---@type integer
        local p = GetOwningPlayer(caster)
        local pid = GetPlayerId(p) + 1 ---@type integer
        local tpid = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer
        local x = GetUnitX(caster) ---@type number
        local y = GetUnitY(caster) ---@type number
        local targetX = GetSpellTargetX() ---@type number
        local targetY = GetSpellTargetY() ---@type number
        local spell = Spells[sid]

        if spell then
            spell.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
        end

        return false
    end

    ---@return boolean
    local function SpellChannel()
        if GetSpellAbilityId() == FourCC('IATK') then
            UnitRemoveAbility(GetTriggerUnit(), FourCC('IATK'))
        end

        return false
    end

    ---@return boolean
    local function SpellLearn()
        local source = GetTriggerUnit() ---@type unit
        local sid = GetLearnedSkill() ---@type integer
        local pid = GetPlayerId(GetOwningPlayer(source)) + 1 ---@type integer
        local ablev = GetUnitAbilityLevel(source, sid) ---@type integer
        local i = 0 ---@type integer
        local abil = BlzGetUnitAbilityByIndex(source, i) ---@type ability
        local spell = Spells[sid]

        -- find ability
        while abil and BlzGetAbilityId(abil) ~= sid do
            i = i + 1
            abil = BlzGetUnitAbilityByIndex(source, i)
        end

        -- execute onlearn function
        if spell and spell.onLearn then spell.onLearn(source, ablev, pid) end

        -- Learning registers percentage-mana cost listeners, but does not
        -- change a stat. Initialize them after the learn hook, just as adding
        -- an ability does, then render the completed cost and spell state.
        EVENT_STAT_CHANGE:trigger(source, "int")
        UpdateSpellTooltips(source)

        return false
    end

    local function SpellEffect()
        local caster = GetTriggerUnit() ---@type unit
        local target = GetSpellTargetUnit() ---@type unit
        local p = GetOwningPlayer(caster)
        local sid = GetSpellAbilityId() ---@type integer
        local pid = GetPlayerId(p) + 1 ---@type integer
        local tpid = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer
        local ablev = GetUnitAbilityLevel(caster, sid) ---@type integer
        local x = GetUnitX(caster) ---@type number
        local y = GetUnitY(caster) ---@type number
        local targetX = GetSpellTargetX() ---@type number
        local targetY = GetSpellTargetY() ---@type number
        local spell = Spells[sid]

        EVENT_ON_CAST:trigger(caster, sid, ablev)

        -- remember last cast spell id
        if sid ~= ADAPTIVESTRIKE.id and sid ~= LIMITBREAK.id then
            LAST_CAST[pid] = sid
        end

        -- check existing spell definition
        if spell then
            spell = spell:create(caster)
            spell.owner = p
            spell.sid = sid
            spell.tpid = tpid
            spell.caster = caster
            spell.target = target
            spell.ablev = ablev
            spell.x = x
            spell.y = y
            spell.targetX = targetX
            spell.targetY = targetY
            spell.angle = math.atan(spell.targetY - y, spell.targetX - x)

            spell:onCast()
        elseif UNIT_SPELLS[sid] then
            UNIT_SPELLS[sid](caster, pid)
        end

        return false
    end

    for k = 0, bj_MAX_PLAYER_SLOTS do
        local p = Player(k)

        if GetPlayerController(p) ~= MAP_CONTROL_NONE then
            -- bard setup
            SetPlayerAbilityAvailable(p, SONG_HARMONY, false)
            SetPlayerAbilityAvailable(p, SONG_PEACE, false)
            SetPlayerAbilityAvailable(p, SONG_WAR, false)
            SetPlayerAbilityAvailable(p, SONG_FATIGUE, false)
        end
    end

    local blzgetunitabilitybyindex = BlzGetUnitAbilityByIndex
    local blzgetabilityid = BlzGetAbilityId

    ---@param u unit
    function UpdateSpellTooltips(u)
        local i = 0
        local abil = blzgetunitabilitybyindex(u, i)

        while abil do
            local sid = blzgetabilityid(abil)
            local spell = Spells[sid]

            if spell then spell:setTooltip(u, sid) end

            i = i + 1
            abil = blzgetunitabilitybyindex(u, i)
        end

        -- SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), true)
        -- SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), false)
    end

    ---Runs first-time setup for registered abilities on a newly indexed unit.
    ---@param u unit
    local function setup_unit_spells(u)
        local index = 0
        local ability = blzgetunitabilitybyindex(u, index)

        while ability do
            local id = blzgetabilityid(ability)
            local spell = Spells[id]

            if spell then
                spell:setTooltip(u, id)
                if spell.onSetup then spell.onSetup(u) end
            end

            index = index + 1
            ability = blzgetunitabilitybyindex(u, index)
        end
    end

    Unit.onIndex(setup_unit_spells)

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_CAST, SpellCast)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_EFFECT, SpellEffect)
    RegisterPlayerUnitEvent(EVENT_PLAYER_HERO_SKILL, SpellLearn)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_CHANNEL, SpellChannel)
end, Debug and Debug.getLine())
