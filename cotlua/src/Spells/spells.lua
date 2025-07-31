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

    SONG_WAR     = FourCC('A024') ---@type integer 
    SONG_HARMONY = FourCC('A01A') ---@type integer 
    SONG_PEACE   = FourCC('A09X') ---@type integer 
    SONG_FATIGUE = FourCC('A00N') ---@type integer 
    LAST_CAST    = __jarray(0) ---@type integer[] 

    --storage for spell definitions
    Spells = {} ---@type Spell[]
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
    ---@field destroy function
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

        -- TODO: use get key status function in hotkeys?
        local alt_down = {} ---@type boolean[]

        ---@param pid integer
        local function UpdateItemTooltips(pid)
            -- update 6 visible item slot tooltips
            local modifier = alt_down[pid]
            local profile = Profile[pid]

            if profile and profile.hero then
                for i = 1, 6 do
                    local itm = profile.hero.items[i]

                    if itm then
                        if modifier and itm.alt_tooltip then
                            if GetLocalPlayer() == Player(pid - 1) then
                                BlzSetItemExtendedTooltip(itm.obj, itm.alt_tooltip)
                            end
                        elseif itm.tooltip then
                            if GetLocalPlayer() == Player(pid - 1) then
                                BlzSetItemExtendedTooltip(itm.obj, itm.tooltip)
                            end
                        end
                    end
                end
            end
        end

        local function extended_spell_tooltip(pid, is_down)
            if alt_down[pid] ~= is_down then
                alt_down[pid] = is_down
                UpdateSpellTooltips(Hero[pid])
                UpdateItemTooltips(pid)
            end
        end

        RegisterHotkeyToFunc('ALT', nil, extended_spell_tooltip, nil, true)
        RegisterHotkeyToFunc('ALT+ALT', nil, extended_spell_tooltip, nil, true)

        ---@type fun(self: Spell, u: unit?, ablev: integer?): string
        function thistype:getTooltip(u, ablev)
            local orig = thistype.TOOLTIPS[self.id][self.ablev or ablev or 1]

            -- create temporary spell object to calculate values
            if not self.pid and u then
                self = self:create(u)
            end

            -- return original tooltip if no values to parse
            if not self.values then
                return orig
            end

            --[[
                >: no color
                ~: only shows calculated value
                [: normal boost
                {: low boost
                \: no boost
                =: tag identifier
            ]]
            local pattern = "(~?)(>?)([\\{\x25[])(\x25w-)=(.-)]"
            orig = string.gsub(orig, pattern, function(defaultflag, colorflag, prefix, tag, content)
                local color = (colorflag ~= ">")
                local alt   = alt_down[self.pid] or defaultflag == "~"
                if not alt or not u then
                    return content
                end

                -- calculate value based on bracket type
                local val  = self[tag]
                local calc = (type(val) == "table") and val[self.pid] or val

                if prefix == "[" then
                    local sb = Unit[u].spellboost
                    return HL(RealToString(calc * (1 + sb - 0.2)) .. " - " .. RealToString(calc * (1 + sb + 0.2)), color)

                elseif prefix == "{" then
                    local out
                    if calc < 1000 then
                        out = string.format("\x25.2f", calc * LBOOST[self.pid])
                    else
                        out = RealToString(calc * LBOOST[self.pid])
                    end
                    return HL(out, color)

                elseif prefix == "\\" then
                    return HL(RealToString(calc), color)
                end
            end)

            return orig
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
        function thistype.onUnequip(itm, id, index) end
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

        if Spells[sid] then
            Spells[sid].preCast(pid, tpid, caster, target, x, y, targetX, targetY)
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

        -- find ability
        while abil and BlzGetAbilityId(abil) ~= sid do
            i = i + 1
            abil = BlzGetUnitAbilityByIndex(source, i)
        end

        UpdateSpellTooltips(source)

        -- execute onlearn function
        if Spells[sid] and Spells[sid].onLearn then
            Spells[sid].onLearn(source, ablev, pid)
        end

        return false
    end

    local function SpellEffect()
        local caster = GetTriggerUnit() ---@type unit 
        local target = GetSpellTargetUnit() ---@type unit 
        local p      = GetOwningPlayer(caster)
        --local itm  = GetSpellTargetItem() ---@type item?
        local sid    = GetSpellAbilityId() ---@type integer 
        local pid    = GetPlayerId(p) + 1 ---@type integer 
        local tpid   = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer 
        local ablev  = GetUnitAbilityLevel(caster, sid) ---@type integer 
        local x      = GetUnitX(caster) ---@type number 
        local y      = GetUnitY(caster) ---@type number 
        local targetX = GetSpellTargetX() ---@type number 
        local targetY = GetSpellTargetY() ---@type number 

        EVENT_ON_CAST:trigger(caster, sid, ablev)

        -- remember last cast spell id
        if sid ~= ADAPTIVESTRIKE.id and sid ~= LIMITBREAK.id then
            LAST_CAST[pid] = sid
        end

        -- check existing spell definition
        if Spells[sid] then
            local spell = Spells[sid]:create(caster)
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
            -- pr setup
            SetPlayerAbilityAvailable(p, prMulti[0], false)
            SetPlayerAbilityAvailable(p, prMulti[1], false)
            SetPlayerAbilityAvailable(p, prMulti[2], false)
            SetPlayerAbilityAvailable(p, prMulti[3], false)
            SetPlayerAbilityAvailable(p, prMulti[4], false)
            SetPlayerAbilityAvailable(p, prMulti[5], false)
            SetPlayerAbilityAvailable(p, FourCC('A0AP'), false)
            -- bard setup
            SetPlayerAbilityAvailable(p, SONG_HARMONY, false)
            SetPlayerAbilityAvailable(p, SONG_PEACE, false)
            SetPlayerAbilityAvailable(p, SONG_WAR, false)
            SetPlayerAbilityAvailable(p, SONG_FATIGUE, false)
        end
    end

    -- Hook UnitAddAbility
    function Hook:UnitAddAbility(whichUnit, id)
        local returnValue = self.old(whichUnit, id)

        -- force mana cost update
        EVENT_STAT_CHANGE:trigger(whichUnit)

        return returnValue
    end

    ---@param u unit
    function UpdateSpellTooltips(u)
        local i = 0
        local abil = BlzGetUnitAbilityByIndex(u, i)

        while abil do
            local sid = BlzGetAbilityId(abil)

            if Spells[sid] then
                Spells[sid]:setTooltip(u, sid)
            end

            i = i + 1
            abil = BlzGetUnitAbilityByIndex(u, i)
        end

        SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), true)
        SetPlayerAbilityAvailable(PLAYER_CREEP, FourCC('Agyv'), false)
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_CAST, SpellCast)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_EFFECT, SpellEffect)
    RegisterPlayerUnitEvent(EVENT_PLAYER_HERO_SKILL, SpellLearn)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SPELL_CHANNEL, SpellChannel)
end, Debug and Debug.getLine())
