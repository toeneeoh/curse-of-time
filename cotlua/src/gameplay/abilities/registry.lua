--[[
    spell.lua

    A library that handles spell related events:
        (EVENT_PLAYER_UNIT_SPELL_EFFECT,
        EVENT_PLAYER_UNIT_SPELL_CAST,
        EVENT_PLAYER_UNIT_SPELL_FINISH,
        EVENT_PLAYER_HERO_SKILL,
        EVENT_PLAYER_UNIT_SPELL_CHANNEL)
    
    Provides a spell object factory for defining abilities by their ID
]]

OnInit.final("Spells", function(Require)
    Require("Users")
    Require("UnitEvent")
    Require("UnitTable")

    -- this only exists to update mana costs if a spell is readded for any reason
    local OldUnitAddAbility = UnitAddAbility
    UnitAddAbility = function(u, id)
        OldUnitAddAbility(u, id)

        EVENT_STAT_CHANGE:trigger(u, "int")
    end

    -- storage for spell definitions
    Spells = {} ---@type Spell[]

    local Spells = Spells
    local real_to_string = RealToString
    local HL = HL
    local format = string.format
    local pattern = "(~?)(>?)([\\{%[])(%w-)=(.-)]"
    local gsub = string.gsub

    -- set by getTooltip before calling gsub
    local current_spell      ---@type Spell
    local current_unit       ---@type unit
    local current_pid        ---@type integer
    local current_alt        ---@type boolean

    SONG_WAR     = FourCC('A024') ---@type integer 
    SONG_HARMONY = FourCC('A01A') ---@type integer 
    SONG_PEACE   = FourCC('A09X') ---@type integer 
    SONG_FATIGUE = FourCC('A00N') ---@type integer 
    LAST_CAST    = __jarray(0) ---@type integer[] 

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

            mts[self] = mts[self] or { __index = self }

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

        local mt = { __index = function(tbl, key) local v = rawget(tbl, "values") return Spell[key] or (v and v[key]) end }

        local function store_tooltip(id)
            UnitAddAbility(DUMMY_UNIT, id)
            local abil = BlzGetUnitAbility(DUMMY_UNIT, id)
            for ablev = 1, BlzGetAbilityIntegerField(abil, ABILITY_IF_LEVELS) do
                Spell.TOOLTIPS[id][ablev] = BlzGetAbilityStringLevelField(abil, ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED, ablev - 1)
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
            self.ACTIVE = true -- determines if ability is given to dummy item

            setmetatable(self, mt)

            Spells[self.id] = self

            -- store original tooltips
            store_tooltip(self.id)

            -- if multiple ids share a definition, store them
            if ... then
                self.shared = { self.id }
                for i = 1, select('#', ...) do
                    id = FourCC(select(i, ...))
                    Spells[id] = self
                    self.shared[#self.shared + 1] = id
                end
            end

            return self
        end

        local alt_down = {} ---@type boolean[]
        local function extended_spell_tooltip(pid, is_down)
            if alt_down[pid] ~= is_down then
                alt_down[pid] = is_down
                UpdateSpellTooltips(Hero[pid])
            end
        end

        RegisterHotkeyToFunc('ALT', nil, extended_spell_tooltip, nil, true)
        RegisterHotkeyToFunc('ALT+ALT', nil, extended_spell_tooltip, nil, true)

        local function tooltip_replacer(defaultflag, colorflag, prefix, tag, content)
            local self = current_spell
            local u    = current_unit

            -- if we don't have a unit, just show raw content
            if not u then
                return content
            end

            -- only calculate if alt mode is active for this player
            local alt = current_alt or (defaultflag == "~")
            if not alt then
                return content
            end

            local color = (colorflag ~= ">")

            -- lookup value
            local val = self[tag]
            if val == nil then
                return content
            end

            local calc = (type(val) == "table") and val[current_pid] or val

            if prefix == "[" then
                local sb = Unit[u].spellboost
                return HL(
                    real_to_string(calc * (1 + sb - MIN_SPELLBOOST_VARIANCE)) .. " - " .. real_to_string(calc * (1 + sb + MAX_SPELLBOOST_VARIANCE)), color
                )

            elseif prefix == "{" then
                local mult = LBOOST[current_pid]
                local v = calc * mult
                local out
                if v < 1000 then
                    out = format("%.2f", v)
                else
                    out = real_to_string(v)
                end
                return HL(out, color)

            elseif prefix == "\\" then
                return HL(real_to_string(calc), color)
            end

            return content
        end

        ---@type fun(self: Spell, u: unit?, ablev: integer?): string
        function thistype:getTooltip(u, ablev)
            local level = self.ablev or ablev or 1
            local orig  = thistype.TOOLTIPS[self.id][level]

            -- just return raw tooltip if no dynamic values
            if not self.values or (not string.find(orig, "=", 1, true)) then
                return orig
            end

            -- set context for the replacer
            current_spell = self
            current_unit  = u
            current_pid   = self.pid
            current_alt   = alt_down[self.pid] or false

            local result = gsub(orig, pattern, tooltip_replacer)

            return result
        end

        ---@type fun(self: Spell, u: unit, sid: integer?)
        function thistype:setTooltip(u, sid)
            local ablev = GetUnitAbilityLevel(u, sid)
            local skill = self:create(u)
            local tooltip = skill:getTooltip(u, ablev)

            if GetLocalPlayer() == GetOwningPlayer(u) then
                BlzSetAbilityExtendedTooltip(sid, tooltip, ablev - 1)
                BlzSetAbilityActivatedExtendedTooltip(sid, tooltip, ablev - 1)
            end
        end

        -- Stub methods
        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY) end
        function thistype.onCast() end
        function thistype.onUnequip(itm, id, index, orig_holder) end
        function thistype.onEquip(itm, id, index) end
        --function thistype.onLearn(source, ablev, pid) end
        --function thistype.onSetup(source) end
    end

    local function SpellCast()
        local caster  = GetTriggerUnit() ---@type unit 
        local target  = GetSpellTargetUnit() ---@type unit 
        local sid     = GetSpellAbilityId() ---@type integer 
        local p       = GetOwningPlayer(caster)
        local pid     = GetPlayerId(p) + 1 ---@type integer 
        local tpid    = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer 
        local x       = GetUnitX(caster) ---@type number 
        local y       = GetUnitY(caster) ---@type number 
        local targetX = GetSpellTargetX() ---@type number 
        local targetY = GetSpellTargetY() ---@type number 
        local spell   = Spells[sid]

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
        local sid    = GetLearnedSkill() ---@type integer 
        local pid    = GetPlayerId(GetOwningPlayer(source)) + 1 ---@type integer 
        local ablev  = GetUnitAbilityLevel(source, sid) ---@type integer 
        local i      = 0 ---@type integer 
        local abil   = BlzGetUnitAbilityByIndex(source, i) ---@type ability 
        local spell  = Spells[sid]

        -- find ability
        while abil and BlzGetAbilityId(abil) ~= sid do
            i = i + 1
            abil = BlzGetUnitAbilityByIndex(source, i)
        end

        UpdateSpellTooltips(source)

        -- execute onlearn function
        if spell and spell.onLearn then
            spell.onLearn(source, ablev, pid)
        end

        return false
    end

    local function SpellEffect()
        local caster = GetTriggerUnit() ---@type unit 
        local target = GetSpellTargetUnit() ---@type unit 
        local p      = GetOwningPlayer(caster)
        local sid    = GetSpellAbilityId() ---@type integer 
        local pid    = GetPlayerId(p) + 1 ---@type integer 
        local tpid   = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer 
        local ablev  = GetUnitAbilityLevel(caster, sid) ---@type integer 
        local x      = GetUnitX(caster) ---@type number 
        local y      = GetUnitY(caster) ---@type number 
        local targetX = GetSpellTargetX() ---@type number 
        local targetY = GetSpellTargetY() ---@type number 
        local spell   = Spells[sid]

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

            if spell then
                spell:setTooltip(u, sid)
            end

            i = i + 1
            abil = blzgetunitabilitybyindex(u, i)
        end

        --SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), true)
        --SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), false)
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
                if spell.onSetup then
                    spell.onSetup(u)
                end
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
