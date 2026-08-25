--[[
    helper.lua

    A general purpose module with useful helper functions for use across files.
]]

OnInit.global("Helper", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local floor, fmod, sin, cos, min, max, random = math.floor, math.fmod, math.sin, math.cos, math.min, math.max, math.random
    local tostring, type, sub, concat, pack = tostring, type, string.sub, table.concat, string.pack
    local Player, FourCC, GetFilterUnit, GetOwningPlayer, GetUnitTypeId, UnitAlive = Player, FourCC, GetFilterUnit, GetOwningPlayer, GetUnitTypeId, UnitAlive
    local GetUnitX, GetUnitY, BlzGetUnitMaxHP, IsUnitAlly, GetUnitAbilityLevel, GetLocalPlayer = GetUnitX, GetUnitY, BlzGetUnitMaxHP, IsUnitAlly, GetUnitAbilityLevel, GetLocalPlayer
    local CreateTextTag, SetTextTagPermanent, SetTextTagColor, SetTextTagLifespan, SetTextTagFadepoint, SetTextTagText, SetTextTagPos = CreateTextTag, SetTextTagPermanent, SetTextTagColor, SetTextTagLifespan, SetTextTagFadepoint, SetTextTagText, SetTextTagPos
    local ABIL_AVUL = ABIL_AVUL
    local ABIL_ALOC = ABIL_ALOC

---@type fun(val: number, a: number, b: number): number
function MathClamp(val, a, b)
    if val < a then
        return a
    elseif val > b then
        return a
    end

    return val
end

--[[Tasyen/Bribes's GetMainSelectedUnit]]
function GetMainSelectedUnit(...)
    --initialize on the first call...        group frame:      bottom UI:               console:
    local containerFrame = BlzFrameGetChild(BlzFrameGetChild(BlzFrameGetParent(BlzGetFrameByName("SimpleInfoPanelUnitDetail", 0)), 5), 0)

    local function getUnitSortValue(unit)
                --heroes use handleId                                    units use type ID
        return IsUnitType(unit, UNIT_TYPE_HERO) and GetHandleId(unit) or GetUnitTypeId(unit)
    end
    local units
    local function getUnitAt(index)
        return units[index + 1]
    end
    local filter        = Filter(function()
        local unit      = GetFilterUnit()
        local prio      = BlzGetUnitRealField(unit, UNIT_RF_PRIORITY)
        local pos       = #units + 1
        -- compare the current unit with already found, to place it in the right slot
        for i = 1, pos - 1 do
            local value = units[i]
            -- higher prio than this; take it's slot                    equal prio and better colisions Value
            if BlzGetUnitRealField(value, UNIT_RF_PRIORITY) < prio or (BlzGetUnitRealField(value, UNIT_RF_PRIORITY) == prio and getUnitSortValue(value) > getUnitSortValue(unit)) then
                pos = i
                break
            end
        end
        table.insert(units, pos, unit)
    end)
    -- give each frame a unique ID
    local frames = {}
    for int = 0, BlzFrameGetChildrenCount(containerFrame) - 1 do
        local buttonContainer = BlzFrameGetChild(containerFrame, int)
        frames[int + 1] = BlzFrameGetChild(buttonContainer, 0)
    end
    ---@param atIndex? integer
    ---@param async? boolean --if no atIndex is specified but this is true, returns the local current main selected unit's index. Beware: using it in a sync gamestate relevant manner breaks the game.
    function GetMainSelectedUnit(atIndex, async) --re-declare itself once it was called the first time.
        if async and not atIndex then
            -- local player is in group selection?
            if BlzFrameIsVisible(containerFrame) then
                -- find the first visible yellow Background Frame
                for i = 1, #frames do
                    local frame = frames[i]

                    if BlzFrameIsVisible(frame) then
                        atIndex = i - 1
                        break
                    end
                end
            end
        end
        local whichFilter
        local getUnit   = FirstOfGroup
        if atIndex then
            units       = {}
            whichFilter = filter
            getUnit     = getUnitAt
        end
        GroupEnumUnitsSelected(bj_lastCreatedGroup, GetLocalPlayer(), whichFilter)
        return getUnit(atIndex or bj_lastCreatedGroup)
    end
    return GetMainSelectedUnit(...) --return the product of the newly-declared function.
end

-- formats a number to a string with commas (no decimals)
---@param value number
---@return string
function RealToString(value)
    -- let Lua handle giant values directly
    if value >= INT_32_LIMIT then
        return tostring(value)
    end

    -- handle sign
    local negative = false
    if value < 0 then
        negative = true
        value = -value
    end

    -- round to nearest int
    local s = tostring(floor(value + 0.5))
    local len = #s

    -- fast path: no commas needed
    if len <= 3 then
        return negative and ("-" .. s) or s
    end

    -- split "head" group and remaining 3-digit groups
    local first = len % 3
    if first == 0 then first = 3 end

    local parts = {}
    local idx = 1

    -- first group (1–3 digits, no leading comma)
    parts[idx] = sub(s, 1, first)
    idx = idx + 1

    -- remaining groups in chunks of 3 with commas
    for i = first + 1, len, 3 do
        parts[idx] = ","
        parts[idx + 1] = sub(s, i, i + 2)
        idx = idx + 2
    end

    local out = concat(parts)
    if negative then
        out = "-" .. out
    end

    return out
end

local RealToString = RealToString

--misc helper functions

---@type fun(n: integer, t: table): table
function pickN(n, t)
    local seen = {}
    local out = {}
    while #out < n do
        local r = random(1, #t)
        if not seen[r] then
            seen[r] = true
            out[#out + 1] = t[r]
        end
    end
    return out
end

---@type fun(sfx: effect)
function HideEffect(sfx)
    BlzSetSpecialEffectScale(sfx, 0.)
    BlzSetSpecialEffectPosition(sfx, 30000., 30000., 0.)
    DestroyEffect(sfx)
end

---@param u unit
---@return boolean
function IsUnitStunned(u)
    return (Stun:has(nil, u) or Freeze:has(nil, u) or KnockUp:has(nil, u) or GetUnitAbilityLevel(u, FourCC('BPSE')) > 0 or GetUnitAbilityLevel(u, FourCC('BSTN')) > 0)
end

---@type fun(u: unit, id: integer, disable: boolean)
function UnitDisableAbility(u, id, disable)
    local ablev = GetUnitAbilityLevel(u, id) ---@type integer 

    if ablev == 0 then
        return
    end

    UnitRemoveAbility(u, id)
    UnitAddAbility(u, id)
    SetUnitAbilityLevel(u, id, ablev)
    BlzUnitDisableAbility(u, id, disable, false)
    BlzUnitHideAbility(u, id, true)
end

---@param position integer
---@param returnHex boolean
---@return integer|string, integer|nil, integer|nil
function HealthGradient(position, returnHex)
    -- Ensure the position is within the valid range [1, 100]
    position = min(100, max(1, position))

    -- Define color stops and their corresponding positions
    local colorStops = {
        {1,   {255, 0, 0}},
        {10,  {255, 0, 0}},
        {70,  {242, 255, 64}},
        {100, {8, 200, 2}}
    }

    -- Find the two color stops between which the position falls
    local startStop, endStop
    for i = 1, #colorStops - 1 do
        if position <= colorStops[i + 1][1] then
            startStop = colorStops[i]
            endStop = colorStops[i + 1]
            break
        end
    end

    -- Interpolate between the two color stops based on position
    local t = (position - startStop[1]) / (endStop[1] - startStop[1])
    local interpolatedColor = {
        math.floor(startStop[2][1] + t * (endStop[2][1] - startStop[2][1])),
        math.floor(startStop[2][2] + t * (endStop[2][2] - startStop[2][2])),
        math.floor(startStop[2][3] + t * (endStop[2][3] - startStop[2][3]))
    }

    if returnHex then
        -- Convert RGB values to hexadecimal string
        local hexString = string.format("|cff%02X%02X%02X", interpolatedColor[1], interpolatedColor[2], interpolatedColor[3])
        return hexString
    else
        return interpolatedColor[1], interpolatedColor[2], interpolatedColor[3]
    end
end

--Returns index if found otherwise false
---@type fun(tbl:table, val: any): integer | boolean
function TableHas(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            return i
        end
    end

    return false
end

---@type fun(tbl: table, val: any)
function TableRemove(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            tbl[i] = tbl[#tbl]
            tbl[#tbl] = nil
            break
        end
    end
end

---@type fun(tbl: table, text: string)
function DisplayTextToTable(tbl, text)
    for i = 1, #tbl do
        local p = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
        DisplayTextToPlayer(p, 0, 0, text)
    end
end

---@type fun(tbl: table, dur: number, text: string)
function DisplayTimedTextToTable(tbl, dur, text)
    for i = 1, #tbl do
        local p = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
        DisplayTimedTextToPlayer(p, 0, 0, dur, text)
    end
end

local passedValue = {}

---@type fun(pid: integer, g: group, r: rect, b: boolexpr)
function MakeGroupInRect(pid, g, r, b)
    passedValue[#passedValue + 1] = pid
    GroupEnumUnitsInRect(g, r, b)
    passedValue[#passedValue] = nil
end

---@type fun(pid: integer, g: group, x: number, y: number, radius: number, b: boolexpr)
function MakeGroupInRange(pid, g, x, y, radius, b)
    passedValue[#passedValue + 1] = pid
    GroupEnumUnitsInRange(g, x, y, radius, b)
    passedValue[#passedValue] = nil
end

---@type fun(pid: integer, g: group, x: number, y: number, radius: number, b: boolexpr)
function GroupEnumUnitsInRangeEx(pid, g, x, y, radius, b)
    local ug = CreateGroup()

    MakeGroupInRange(pid, ug, x, y, radius, b)
    BlzGroupAddGroupFast(ug, g)

    DestroyGroup(ug)
end

---@param u unit
---@param show boolean
function ToggleCommandCard(u, show)
    local classification = BlzGetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION) ---@type integer 
    local ward = GetHandleId(UNIT_CATEGORY_WARD) ---@type integer 

    if (BlzBitAnd(classification, ward) > 0 and show) or (BlzBitAnd(classification, ward) == 0 and not show) then
        BlzSetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION, BlzBitXor(classification, ward))
    end
end

---@type fun(path: string, is3D: boolean, p: player|nil, u: unit|nil)
function SoundHandler(path, is3D, p, u)
    local ss = ((p and GetLocalPlayer() ~= p) and "") or path ---@type string 
    local s = CreateSound(ss, false, is3D, is3D, 12700, 12700, "")

    if u ~= nil then
        AttachSoundToUnit(s, u)
    end

    StartSound(s)
    KillSoundWhenDone(s)
end

---@param time number
---@return string
function RemainingTimeString(time)
    local minutes = time // 60
    local seconds = fmod(R2I(time), 60)

    return (minutes > 0 and (minutes) .. " minutes") or (seconds) .. " seconds"
end

---@type fun(u: unit): boolean
function IsDummy(u)
    local id = GetUnitTypeId(u)

    return (id == DUMMY_CASTER or id == DUMMY_VISION)
end

---@return boolean
function ischar()
    local pid = GetPlayerId(GetOwningPlayer(GetFilterUnit())) + 1 ---@type integer 

    return (GetFilterUnit() == Hero[pid] and UnitAlive(Hero[pid]))
end

---@return boolean
function ishostile()
    local i =GetPlayerId(GetOwningPlayer(GetFilterUnit())) ---@type integer 

    return (UnitAlive(GetFilterUnit()) and GetUnitAbilityLevel(GetFilterUnit(),ABIL_AVUL) == 0 and (i ==10 or i ==11 or i ==PLAYER_NEUTRAL_AGGRESSIVE))
end

---@return boolean
function isplayerAlly()
    return (UnitAlive(GetFilterUnit()) and GetPlayerId(GetOwningPlayer(GetFilterUnit())) <= PLAYER_CAP and IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) == true and GetUnitTypeId(GetFilterUnit()) ~= BACKPACK)
end

---@return boolean
function isplayerunitRegion()
    local u = GetFilterUnit()

    return (UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and not IsDummy(u))
end

---@return boolean
function isplayerunit()
    local u = GetFilterUnit()

    return (UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and not IsDummy(u))
end

---@return boolean
function ishostileEnemy()
    local u = GetFilterUnit()
    local i = GetPlayerId(GetOwningPlayer(u)) ---@type integer 

    return
    (UnitAlive(u) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    i <= PLAYER_CAP and
    not IsDummy(u))
end

---@return boolean
function isalive()
    local u = GetFilterUnit()

    return
    (UnitAlive(u) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0
    and not IsDummy(u))
end

local similar_units = {
    [FourCC('nitt')] = FourCC('n0tb'), --troll
    [FourCC('n0tw')] = FourCC('n0ts'), --tuskarr
    [FourCC('n0tc')] = FourCC('n0ts'),
    [FourCC('n0sl')] = FourCC('n0ss'), --spider
    [FourCC('n0us')] = FourCC('n0uw'), --ursae
    [FourCC('n0po')] = FourCC('n0dm'), --polar bear / mammoth
    [FourCC('o01G')] = FourCC('n01G'), --ogre / tauren
    [FourCC('n0ut')] = FourCC('n0ud'), --unbroken
    [FourCC('n0ub')] = FourCC('n0ud'),
    [FourCC('n0hh')] = FourCC('n0hs'), --hellfire / hellhound
    [FourCC('n027')] = FourCC('n024'), --centaur
    [FourCC('n028')] = FourCC('n024'),
    [FourCC('n08M')] = FourCC('n01M'), --magnataur
    [FourCC('n01R')] = FourCC('n02P'), --frost dragon / drake
    [FourCC('n00C')] = FourCC('n02L'), --devourers
    [FourCC('E007')] = FourCC('H00O'), --arkaden
    [FourCC('n033')] = FourCC('n034'), --demons
    [FourCC('n03B')] = FourCC('n03A'), --horror
    [FourCC('n03C')] = FourCC('n03A'),
    [FourCC('n01W')] = FourCC('n03F'), --despair
    [FourCC('n00W')] = FourCC('n08N'), --abyssal
    [FourCC('n00X')] = FourCC('n08N'),
    [FourCC('n030')] = FourCC('n031'), --void
    [FourCC('n02Z')] = FourCC('n031'),
    [FourCC('n02J')] = FourCC('n020'), --nightmare
    [FourCC('n03E')] = FourCC('n03D'), --hell
    [FourCC('n03G')] = FourCC('n03D'),
    [FourCC('n01X')] = FourCC('n03J'), --existence
    [FourCC('n01V')] = FourCC('n03M'), --astral
    [FourCC('n03T')] = FourCC('n026'), --dimensional
}

---unifies different unit types together
---@type fun(id: any): integer
function GetType(id)
    if type(id) == "userdata" then
        id = GetUnitTypeId(id)
    end

    if similar_units[id] then
        return similar_units[id]
    end

    return id
end

---@type fun(u: any): Boss|nil
function IsBoss(u)
    local uid = (type(u) == "number" and u) or GetType(GetUnitTypeId(u))

    for i = BOSS_OFFSET, #Boss do
        if Boss[i].id == uid then
            return Boss[i]
        end
    end

    return nil
end

---@param enemy integer|unit
---@return boolean
function IsEnemy(enemy)
    if type(enemy) == "userdata" then
        enemy = GetPlayerId(GetOwningPlayer(enemy)) + 1
    end

    return (enemy >= 12)
end

---@param pid integer
function RemovePlayerUnits(pid)
    local ug = CreateGroup()

    GroupEnumUnitsOfPlayer(ug, Player(pid - 1), nil)

    for target in each(ug) do
        if not IsDummy(target) then
            EVENT:unregister_unit_action(target)
            Buff.dispelAll(target, true)
            RemoveUnit(target)
        end
    end

    DestroyGroup(ug)
end

local stat_map = {
    "str",
    "int",
    "agi",
}

local literal_stat_map = {
    "Strength",
    "Intelligence",
    "Agility",
}

---@param hero unit
---@param include_bonus boolean
---@return integer
function HighestStat(hero, include_bonus)
    local str = GetHeroStr(hero, include_bonus) ---@type integer 
    local int = GetHeroInt(hero, include_bonus) ---@type integer 
    local agi = GetHeroAgi(hero, include_bonus) ---@type integer 

    if str >= agi and str >= int then
        return 1
    elseif int >= str and int >= agi then
        return 2
    else
        return 3
    end
end

function HighestStatName(hero, literal, include_bonus)
    if literal then
        return literal_stat_map[HighestStat(hero, include_bonus)]
    else
        return stat_map[HighestStat(hero, include_bonus)]
    end
end

---@param hero unit
---@return integer
function MainStat(hero) -- returns integer signifying primary attribute
    return BlzGetUnitIntegerField(hero, UNIT_IF_PRIMARY_ATTRIBUTE)
end

---@type fun(pt: PlayerTimer)
function DelayAnimationExpire(pt)
    if pt.pause then
        BlzPauseUnitEx(pt.target, false)
    end

    if pt.dur > 0. then
        SetUnitTimeScale(pt.target, pt.dur)
    end

    if UnitAlive(pt.target) then
        SetUnitAnimationByIndex(pt.target, pt.index)
    end
end

---@type fun(pid: integer, u: unit, delay: number, index: integer, timescale: number, pause: boolean)
function DelayAnimation(pid, u, delay, index, timescale, pause)
    local pt = TimerList[pid]:add() ---@type PlayerTimer

    pt.target = u
    pt.index = index
    pt.pause = false
    pt.dur = timescale

    if pause then
        BlzPauseUnitEx(u, true)
        pt.pause = true
    end

    pt:after(delay, DelayAnimationExpire)
end

--#region TODO: move lighting stuff somewhere?

local CustomLighting = __jarray(0)

---@param i integer
---@param x number
---@param y number
local function CustomLightingPlayerCheck(i, x, y)
    local daynightmodel = DEFAULT_LIGHTING ---@type string 

    CustomLighting[i] = 1

    if RectContainsCoords(gg_rct_Naga_Dungeon, x, y) and not RectContainsCoords(gg_rct_Naga_Dungeon_Reward, x, y) then
        CustomLighting[i] = 2
    elseif RectContainsCoords(gg_rct_Naga_Dungeon_Boss, x, y) then
        CustomLighting[i] = 2
    elseif RectContainsCoords(gg_rct_Cave, x, y) then
        CustomLighting[i] = 3
    elseif RectContainsCoords(gg_rct_Crypt, x, y) then
        CustomLighting[i] = 4
    elseif RectContainsCoords(gg_rct_Church, x, y) then
        CustomLighting[i] = 4
    end

    if CustomLighting[i] ~= 1 then
        daynightmodel = "blacklight.mdx"
    end

    if CustomLighting[i] == 1 then
        UnitRemoveAbility(Hero[i], FourCC('A059'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
    elseif CustomLighting[i] == 2 and GetUnitAbilityLevel(Hero[i], FourCC('A0AN')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
        UnitRemoveAbility(Hero[i], FourCC('A059'))
    elseif CustomLighting[i] == 3 and GetUnitAbilityLevel(Hero[i], FourCC('A0B8')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A0B8'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A059'))
    elseif CustomLighting[i] == 4 and GetUnitAbilityLevel(Hero[i], FourCC('A059')) == 0 then
        UnitAddAbility(Hero[i], FourCC('A059'))
        UnitRemoveAbility(Hero[i], FourCC('A0AN'))
        UnitRemoveAbility(Hero[i], FourCC('A0B8'))
    end

    if GetLocalPlayer() == Player(i - 1) then
        SetDayNightModels(daynightmodel, daynightmodel)
    end
end


---@param p player
---@param r rect
local function SetCameraBoundsRectForPlayerEx(p, r)
    local minX = GetRectMinX(r) ---@type number 
    local minY = GetRectMinY(r) ---@type number 
    local maxX = GetRectMaxX(r) ---@type number 
    local maxY = GetRectMaxY(r) ---@type number 
    local pid  = GetPlayerId(p) + 1 ---@type integer 

    --lighting
    CustomLightingPlayerCheck(pid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))

    if GetLocalPlayer() == p then
        SetCameraField(CAMERA_FIELD_ROTATION, 90., 0)
        SetCameraBounds(minX, minY, minX, maxY, maxX, maxY, maxX, minY)
    end
end

function SetCamera(pid, r)
    local data = REGION_DATA[r]

    if data.vision then
        SetCameraBoundsRectForPlayerEx(Player(pid - 1), data.vision)
    end

    if Hero[pid] then
        PanCameraToTimedForPlayer(Player(pid - 1), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), 0.)
    end

    if data.minimap then
        SetMinimapTexture(pid, data.minimap)
    end
end
--#endregion

---@param line integer
---@param contents string?
---@return string
function GetLine(line, contents)
    if contents == nil then
        return ""
    end

    local count = 0

    for match in contents:gmatch("[^\n]*\n?") do
        if count == line then
            return match
        end
        count = count + 1
    end

    return ""
end

---@type fun(pid: integer, slot: integer): string
function GetCharacterPath(pid, slot)
     return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\slot" .. (slot) .. ".pld"
end

---@type fun(pid: integer): string
function GetProfilePath(pid)
    return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\profile.pld"
end

local function CleanupBoundItems(object, p)
    local itm = Item[object]

    if itm.owner == p then
        itm:destroy()
    end
end

local function valid_item(object)
    return Item[object] and object ~= PATH_ITEM
end

-- use for any instance of player removal (leave, repick, permanent death)
---@type fun(pid: integer)
function PlayerCleanup(pid)
    local p = Player(pid - 1)

    -- close actions spellbook
    UnitRemoveAbility(Hero[pid], FourCC('A03C'))

    -- clear cosmetics
    for _, v in ipairs(CosmeticTable.cosmetics) do
        local sfx = v[pid .. v.name] ---@type effect

        if sfx then
            DestroyEffect(sfx)
        end
    end

    PLAYER_SELECTED_UNIT[pid] = nil

    -- cleanup bound items
    ALICE_ForAllObjectsDo(CleanupBoundItems, "item", valid_item, p)

    -- TODO: Use this more
    EVENT_ON_CLEANUP:trigger(pid)

    TimerList[pid]:stopAllTimers()

    RemovePlayerUnits(pid)
    SetCameraLocked(pid, false)
    IS_AUTO_ATTACK_OFF[pid] = false
    SetCurrency(pid, GOLD, 0)
    SetCurrency(pid, PLATINUM, 0)
    SetCurrency(pid, CRYSTAL, 0)
    CustomLighting[pid] = 1

    if GetLocalPlayer() == p then
        BlzFrameSetVisible(DPS_FRAME, false)
        DisplayCineFilter(false)

        -- clear damage log
        BlzFrameSetText(MULTIBOARD.DAMAGE:get(2, 1).frame, " ")
    end
end

---@param u1 unit
---@param u2 unit
---@return number
function UnitDistance(u1, u2)
    local dx = GetUnitX(u2) - GetUnitX(u1) ---@type number 
    local dy = GetUnitY(u2) - GetUnitY(u1) ---@type number 

    return SquareRoot(dx * dx + dy * dy)
end

---@type fun(x: number, y: number, x2: number, y2: number):number
function DistanceCoords(x, y, x2, y2)
    return SquareRoot((x - x2) * (x - x2) + (y - y2) * (y - y2))
end

---@type fun(p: player, p2: player, show: boolean)
function ShowHeroPanel(p, p2, show)
    if show == true then
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, true, p)
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_CONTROL, false, p)
    else
        SetPlayerAllianceBJ(p2, ALLIANCE_SHARED_ADVANCED_CONTROL, false, p)
    end
end

---@type fun(pid: integer, id: integer): boolean
function PlayerHasItemType(pid, id)
    for i = 1, MAX_INVENTORY_SLOTS do
        local itm = Profile[pid].hero.items[i]
        if itm and itm.id == id then
            return true
        end
    end

    return false
end

local dummies = {
    FourCC('I00D'),
    FourCC('I00M'),
    FourCC('I028'),
    FourCC('I02K'),
    FourCC('I01B'),
    FourCC('I027'),
}

function IsDummyCastItem(id)
    return TableHas(dummies, id)
end

function MakeDummyCastItem(u)
    local index = 0

    for i = 0, 5 do
        if not UnitItemInSlot(u, i) then
            index = i + 1
            break
        end
    end

    if dummies[index] then
        local itm = CreateItem(dummies[index], 30000, 30000)
        UnitAddItem(u, itm)

        return itm
    end

    return nil
end

---@param pid integer
---@param charge boolean
---@return Item?
function GetResurrectionItem(pid, charge)
    local items = Profile[pid].hero.items

    for i = 1, 6 do
        local itm = items[i]
        if itm then
            if itm.abil == FourCC('Arrv') or itm.abil == FourCC('Anrv') then
                if charge and itm.abil == FourCC('Arrv') then
                    return itm
                elseif not charge and itm.charges > 0 then
                    return itm
                end
            end
        end
    end

    if charge then
        for i = 1, 6 do
            local itm = items[i]
            if itm then
                if itm.abil == FourCC('Arrv') or itm.abil == FourCC('Anrv') then
                    if charge and itm.abil == FourCC('Arrv') then
                        return itm
                    elseif not charge and itm.charges > 0 then
                        return itm
                    end
                end
            end
        end
    end

    return nil
end

---@param groupnumber integer
---@return rect
function SelectGroupedRegion(groupnumber)
    local REGION_GAP = 25 ---@type integer 
    local lowBound  = groupnumber * REGION_GAP ---@type integer 
    local highBound = lowBound ---@type integer 

    while not (RegionCount[highBound] == nil) do
        highBound = highBound + 1
    end

    return RegionCount[GetRandomInt(lowBound, highBound - 1)]
end

---@type fun(pid: integer, prof: integer): boolean
function HasProficiency(pid, prof)
    local id = Profile[pid].hero.unit_id

    if not HERO_STATS[id] then
        return false
    end

    return BlzBitAnd(HERO_STATS[id].prof, prof) ~= 0 or prof == 0 or prof == PROF_SHIELD or prof == PROF_POTION
end

---@type fun(id: integer, pid: integer):number
function ItemProfMod(id, pid)
    local prof = ItemData[id][ITEM_TYPE] ---@type integer 

    return (HasProficiency(pid, PROF[prof]) and 1) or 0.75
end

---@type fun(itemid: integer): integer|nil
function ItemToIndex(itemid)
    return SAVE_TABLE.KEY_ITEMS[itemid]
end

-- overrides default UnitAddItemById function
---@type fun(u: unit, id: integer): Item
function UnitAddItemById(u, id)
    local itm = ItemRuntime.create(id, GetUnitX(u), GetUnitY(u)) ---@type Item

    UnitAddItem(u, itm.obj)

    return itm
end

---@type fun(pid: integer, itm: Item)
function PlayerAddItem(pid, itm)
    itm.owner = Player(pid - 1)
    itm.pid = pid

    -- power ups are given to hero regardless
    if GetItemType(itm.obj) == ITEM_TYPE_POWERUP then
        UnitAddItem(Hero[pid], itm.obj)
    else
        if not itm:equip() then
            SetItemPosition(itm.obj, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        end
    end
end

---@type fun(itm: Item): boolean
function ItemIsUpgradeable(itm)
    return ItemData[itm.id][ITEM_UPGRADE_MAX] > itm.level
end

---@type fun(pid: integer, id: string|integer): Item
function PlayerAddItemById(pid, id)
    local _, origid, level = GetItem(id)
    local itm = ItemRuntime.create(origid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid])) ---@type Item
    itm.owner = Player(pid - 1)
    itm.pid = pid

    -- power ups are given to hero regardless
    if GetItemType(itm.obj) == ITEM_TYPE_POWERUP then
        UnitAddItem(Hero[pid], itm.obj)
    else
        if level > 0 then
            itm:lvl(level)
        end

        itm:equip()
    end

    return itm
end

---@type fun(killed: unit, killer: unit)
function RewardXPGold(killed, killer)
    local kpid = GetPlayerId(GetOwningPlayer(killer)) + 1 ---@type integer 
    local xpgroup = {}
    local lvl = GetUnitLevel(killed)

    -- nearby allies
    local U = User.first

    while U do
        if U.id ~= kpid and IsUnitInRange(Hero[U.id], killed, 1800.00) and UnitAlive(Hero[U.id]) then
            if (GetHeroLevel(Hero[U.id]) >= (lvl - 20)) and (GetHeroLevel(Hero[U.id])) >= GetUnitLevel(Hero[kpid]) - LEECH_CONSTANT then
                xpgroup[#xpgroup + 1] = U.id
            end
        end
        U = U.next
    end

    -- killer
    if GetHeroLevel(Hero[kpid]) >= (lvl - 20) then
        xpgroup[#xpgroup + 1] = kpid
    end

    -- allocate rewards
    local maingold = GOLD_TABLE[lvl]
    local teamgold = 0
    local expbase = EXPERIENCE_TABLE[lvl] * 0.007 ---@type number 

    -- boss bounty
    local boss = IsBoss(killed)

    if boss then
        expbase = expbase * 10. * boss.difficulty
        maingold = expbase * 90 * boss.difficulty
    end

    if #xpgroup > 0 then
        expbase = expbase * (1.2 / #xpgroup)
        teamgold = maingold * (1. / #xpgroup)
    end

    for i = 1, #xpgroup do
        local pid = xpgroup[i]
        local XP = math.floor(expbase * Unit[Hero[pid]].xp_rate)

        AwardGold(pid, teamgold, false)
        AwardXP(pid, XP)
    end
end

function DisableBackpackTeleports(pid, disable)
    UnitDisableAbility(Backpack[pid], TELEPORT.id, disable)
    UnitDisableAbility(Backpack[pid], TELEPORT_HOME.id, disable)
    if disable then
        BlzUnitHideAbility(Backpack[pid], TELEPORT.id, false)
        BlzUnitHideAbility(Backpack[pid], TELEPORT_HOME.id, false)
    end
end

local StatTable = {
    GetHeroStr,
    GetHeroInt,
    GetHeroAgi,
    function() return 0 end,
}

---@type fun(stat: integer, u: unit, bonuses: boolean): integer
function GetHeroStat(stat, u, bonuses)
    return StatTable[stat](u, bonuses)
end

---@type fun(p0_x: number, p0_y: number, p1_x: number, p1_y: number, p2_x: number, p2_y: number, p3_x: number, p3_y: number): location | nil
function GetLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x = p1_x - p0_x ---@type number 
    local s1_y = p1_y - p0_y ---@type number 
    local s2_x = p3_x - p2_x ---@type number 
    local s2_y = p3_y - p2_y ---@type number 
    local s    = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y) ---@type number 
    local t    = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) // (-s2_x * s1_y + s1_x * s2_y) ---@type number 
    local i_x  = 0. ---@type number 
    local i_y  = 0. ---@type number 

    if (s >= 0.0 and s <= 1.0 and t >= 0.0 and t <= 1.0) then
        -- collision
        i_x = p0_x + (t * s1_x)
        i_y = p0_y + (t * s1_y)

        return {i_x, i_y}
    end

    --no collision
    return nil
end

---@type fun(x: number, y: number, x2: number, y2: number, minX: number, minY: number, maxX: number, maxY: number): boolean
function LineContainsRect(x, y, x2, y2, minX, minY, maxX, maxY)
    local leftSide   = GetLineIntersection(x, y, x2, y2, minX, minY, minX, maxY) ---@type table 
    local rightSide  = GetLineIntersection(x, y, x2, y2, maxX, minY, maxX, maxY) ---@type table 
    local bottomSide = GetLineIntersection(x, y, x2, y2, minX, minY, maxX, minY) ---@type table 
    local topSide    = GetLineIntersection(x, y, x2, y2, minX, maxY, maxX, maxY) ---@type table 

    return (leftSide ~= nil or rightSide ~= nil or bottomSide ~= nil or topSide ~= nil)
end

---@param pid integer
function ToggleAutoAttack(pid)
    if IS_AUTO_ATTACK_OFF[pid] then
        IS_AUTO_ATTACK_OFF[pid] = false
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Auto Attacking on.")
        if Unit[Hero[pid]].can_attack then
            BlzSetUnitWeaponBooleanField(Hero[pid], UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, true)
        end
    else
        IS_AUTO_ATTACK_OFF[pid] = true
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Auto Attacking off.")
        BlzSetUnitWeaponBooleanField(Hero[pid], UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
    end
end

function ToggleTaunting(pid)
    if IS_TAUNT_DISABLED[pid] then
        DisplayTimedTextToForce(FORCE_PLAYING, 10, User[pid - 1].nameColored .. " toggled their taunts on.")
    else
        DisplayTimedTextToForce(FORCE_PLAYING, 10, User[pid - 1].nameColored .. " toggled their taunts off.")
    end
    IS_TAUNT_DISABLED[pid] = not IS_TAUNT_DISABLED[pid]
end

local MAX_SPELLBOOST_VARIANCE = MAX_SPELLBOOST_VARIANCE
local MIN_SPELLBOOST_VARIANCE = MIN_SPELLBOOST_VARIANCE

function SpellboostVariance()
    return random() * (MAX_SPELLBOOST_VARIANCE * 2) + MIN_SPELLBOOST_VARIANCE
end

local VALID_TREES = {
    ['ITtw'] = 1,
    ['JTtw'] = 1,
    ['FTtw'] = 1,
    ['NTtw'] = 1,
    ['B00B'] = 1,
    ['B00H'] = 1,
    ['ITtc'] = 1,
    ['NTtc'] = 1,
    ['WTst'] = 1,
    ['WTtw'] = 1,
    x = 0.,
    y = 0.,
    range = 0.
}

function EnumDestroyTreesInRange()
    local d   = GetEnumDestructable() ---@type destructable 
    local did = pack(">I4", GetDestructableTypeId(d))

    if VALID_TREES[did] and DistanceCoords(VALID_TREES.x, VALID_TREES.y, GetDestructableX(d), GetDestructableY(d)) <= VALID_TREES.range then
        KillDestructable(d)
    end
end

---@type fun(x: number, y: number, range: number)
function DestroyTreesInRange(x, y, range)
    local r = Rect(x - range, y - range, x + range, y + range) ---@type rect 

    VALID_TREES.x = x
    VALID_TREES.y = y
    VALID_TREES.range = range
    EnumDestructablesInRect(r, nil, EnumDestroyTreesInRange)

    RemoveRect(r)
end

---@type fun(pid: integer, target: unit, duration: number)
function StunUnit(pid, target, duration)
    local stun = Stun:add(Hero[pid], target)

    if IsUnitType(target, UNIT_TYPE_HERO) then
        stun:duration(duration * 0.5)
    else
        stun:duration(duration)
    end
end

--highlights a string with |cffffcc00
---@type fun(s: string, y: boolean): string
function HL(s, y)
    return (y and ("|cffffcc00" .. s .. "|r")) or s
end

---@type fun(itm: item, s: string)
function ParseItemTooltip(itm, s)
    local orig = s ~= "" and s or BlzGetItemExtendedTooltip(itm)
    local itemid = GetItemTypeId(itm)
    local gmatch, gsub = string.gmatch, string.gsub

    -- store original tooltip
    ItemData[itemid].tooltip = orig

    -- store original icon path
    ItemData[itemid].path = BlzGetItemIconPath(itm)

    -- store original name
    ItemData[itemid].name = GetItemName(itm)

    -- match balanced brackets
    orig = orig:gsub("(%b[])", function(contents)
        contents = contents:sub(2, -2) ---@type string

        local tag, suffix, value = contents:match("(%a+)([ %*])(%-?%d+%.?%d*)")
        local index
        for i = 1, #STAT_TAG do
            local v = STAT_TAG[i]

            if v.syntax == tag then
                index = i
                break
            end
        end

        if index then

            -- assign value
            ItemData[itemid][index] = tonumber(value)
            -- fixed toggle
            ItemData[itemid][index .. "fixed"] = (suffix == "*") and 1 or 0

            -- process ability data if available
            contents = contents:gsub("(#.*)", function(capture)
                local data = capture:sub(7, #capture)

                ItemData[itemid][index .. "id"] = FourCC(capture:sub(2, 5))
                ItemData[itemid][index .. "data"] = data

                -- read sfx data
                for entry in gmatch(data, "(%S+)") do
                    local args = {}

                    -- parse [sfx,level,attach,path] entries
                    for arg in gmatch(entry, "([^,]+)") do
                        args[#args + 1] = arg
                    end

                    if #args == 4 then
                        -- replace underscores with spaces in attachment point
                        args[3] = gsub(args[3], "_", " ")

                        local tbl = ItemData[itemid].sfx

                        if type(tbl) ~= "table" then
                            tbl = {}
                            ItemData[itemid].sfx = tbl
                        end

                        tbl[#tbl + 1] = {
                            level = args[2],
                            attach = args[3],
                            path = args[4],
                        }
                    end
                end

                return ""
            end)

            -- process affixes
            local affix = "([|=>%@])(%-?%d+%.?%d*)"
            local start = contents:find(affix)

            if start then
                contents = contents:sub(start)
                contents = gsub(contents, affix, function(prefix, capture)

                    -- value range
                    if prefix == "|" then
                        ItemData[itemid][index .. "range"] = tonumber(capture)
                    -- flat per level
                    elseif prefix == "=" then
                        ItemData[itemid][index .. "fpl"] = tonumber(capture)
                    -- flat per rarity
                    elseif prefix == ">" then
                        ItemData[itemid][index .. "fpr"] = tonumber(capture)
                    -- percent effectiveness
                    elseif prefix == "%" then
                        ItemData[itemid][index .. "percent"] = tonumber(capture)
                    -- unlock at
                    elseif prefix == "@" then
                        ItemData[itemid][index .. "unlock"] = tonumber(capture)
                    end
                end)
            end
        end
    end)
end

local function finish_cast(u)
    Unit[u]._casting = false
end

local function finish_pause(u, pause_override)
    if not pause_override then
        PauseUnit(u, false)
    end
    TQ:callDelayed(3., finish_cast, u) -- internal spacing between boss spell casts
end

---@param whichRect rect
---@return number x
---@return number y
function GetRandomXYInRect(whichRect)
	return GetRandomReal(GetRectMinX(whichRect), GetRectMaxX(whichRect)), GetRandomReal(GetRectMinY(whichRect), GetRectMaxY(whichRect))
end

--- Helper for boss casting
---@type fun(u: unit, id: integer, dur: number, anim: integer, timescale: number, pause_override: boolean?): boolean
function CastSpell(u, id, dur, anim, timescale, pause_override)
    if Unit[u]._casting or BlzGetUnitAbilityCooldownRemaining(u, id) > 0. or not UnitAlive(u) then
        return false
    end

    Unit[u]._casting = true
    BlzStartUnitAbilityCooldown(u, id, BlzGetUnitAbilityCooldown(u, id, GetUnitAbilityLevel(u, id) - 1))
    DelayAnimation(BOSS_ID, u, dur, 0, 1., true)
    if anim ~= -1 then
        SetUnitTimeScale(u, timescale)
        SetUnitAnimationByIndex(u, anim)
    end

    if not pause_override then
        PauseUnit(u, true)
    end
    TQ:callDelayed(dur, finish_pause, u, pause_override)

    return true
end

---@type fun(pid: integer, x: number, y: number)
function MoveHero(pid, x, y)
    SetUnitXBounded(Hero[pid], x)
    SetUnitYBounded(Hero[pid], y)
    SetUnitXBounded(HeroGrave[pid], x)
    SetUnitYBounded(HeroGrave[pid], y)
    BlzUnitClearOrders(Hero[pid], false)

    local r = GetRectFromCoords(x, y)

    if r then
        SetCamera(pid, r)
    end
end

---@param pid integer
function ExperienceControl(pid)
    local level = GetHeroLevel(Hero[pid]) ---@type integer 

    Unit[Hero[pid]].xp_rate = max(0, BASE_XP_RATE[level])
end

---@type fun(pid: integer, texture: string)
function SetMinimapTexture(pid, texture)
    if GetLocalPlayer() == Player(pid - 1) then
        BlzChangeMinimapTerrainTex(texture)
    end
end

local conversion_cd = {}
local conversion_reset_cd = function(pid) conversion_cd[pid] = nil end

---@type fun(pid: integer)
function ConversionEffect(pid)
    if not conversion_cd[pid] then
        conversion_cd[pid] = true
        TQ:callDelayed(1., conversion_reset_cd, pid)
        local x = GetUnitX(Hero[pid])
        local y = GetUnitY(Hero[pid])

        for i = 1, 3 do
            for j = 1, i * 4 do
                local dist = i * 40
                local angle = 2. * bj_PI / (i * 4) * j
                local sfx = AddSpecialEffect("Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl", x + dist * cos(angle), y + dist * sin(angle))
                BlzSetSpecialEffectColor(sfx, 50, 50, 255)
                DestroyEffect(sfx)
            end
        end
    end
end

---@type fun(pid: integer, xp: number)
function AwardXP(pid, xp)
    xp = math.floor(xp)
    SetHeroXP(Hero[pid], GetHeroXP(Hero[pid]) + xp, true)
    ExperienceControl(pid)
    FloatingTextUnit("+" .. (xp) .. " XP", Hero[pid], 2, 80, 0, 10, 204, 0, 204, 0, false)
end

---@type fun(s: string, u: unit, dur: number, speed: number, z: number, size: number, r: integer, g: integer, b: integer, alpha: integer, shared: boolean)
function FloatingTextUnit(s, u, dur, speed, z, size, r, g, b, alpha, shared)
    local tt = nil

    if shared then
        tt = CreateTextTag()
    elseif GetLocalPlayer() == GetOwningPlayer(u) then
        tt = CreateTextTag()
    end

    if tt then
        SetTextTagText(tt, s, size * 0.0023)
        SetTextTagPos(tt, GetUnitX(u), GetUnitY(u), z)
        SetTextTagColor(tt, r, g, b, 255 - alpha)
        SetTextTagPermanent(tt, false)
        SetTextTagVelocity(tt, 0, speed / 1803.)
        SetTextTagLifespan(tt, dur)
        SetTextTagFadepoint(tt, dur - .4)
    end
end

---@type fun(source: unit, target: unit, hp: number, tag: string|nil)
function HP(source, target, hp, tag)
    -- hit count based units cannot be healed
    if not Unit[target].hit_based_health then
        hp = hp * Unit[target].regen_percent

        local text = RealToString(hp)

        --undying rage heal delay
        if UndyingRageBuff:has(target, target) then
            UndyingRageBuff:get(target, target):addRegen(hp)
        else
            SetUnitState(target, UNIT_STATE_LIFE, GetUnitState(target, UNIT_STATE_LIFE) + hp)
            if R2I(hp) ~= 0 then
                FloatingTextUnit(text, target, 2, 50, 0, 10, 125, 255, 125, 0, true)
            end
        end

        LogDamage(source, target, "|cff7dff7d" .. text .. "|r", true, tag)
    end
end

---@type fun(source: unit, mp: number)
function MP(source, mp)
    if not Unit[source].nomanaregen then
        SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MANA) + mp)
        FloatingTextUnit(RealToString(mp), source, 2, 50, -70, 10, 0, 255, 255, 0, true)
    end
end

local function apply_fade(u, dur, fade, amount)
    local r = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_RED) ---@type integer 
    local g = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_BLUE) ---@type integer 
    local b = BlzGetUnitIntegerField(u, UNIT_IF_TINTING_COLOR_GREEN) ---@type integer 

    if GetUnitAbilityLevel(u, FourCC('Bmag')) > 0 then --magnetic stance
        r = 255 g = 25 b = 25
    end

    amount = amount + (255 / (dur * 32))

    if fade then
        SetUnitVertexColor(u, r, g, b, math.floor(max(255 - amount, 0)))
    else
        SetUnitVertexColor(u, r, g, b, math.floor(min(255, amount)))
    end

    if amount < 255 and UnitAlive(u) then
        TQ:callDelayed(FPS_32, apply_fade, u, dur, fade, amount)
    end
end

---@type fun(u: unit, dur: number, fade: boolean)
function Fade(u, dur, fade)
    TQ:callDelayed(0, apply_fade, u, dur, fade, 0)
end

local function apply_sfx_fade(sfx, fade, count)
    count = count - 1

    if count > 0 then
        if fade == true then
            BlzSetSpecialEffectAlpha(sfx, count * 7)
        else
            BlzSetSpecialEffectAlpha(sfx, 255 - count * 7)
        end

        TQ:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
    end
end

---@type fun(sfx: effect, fade: boolean)
function FadeSFX(sfx, fade)
    local count = 40 ---@type number

    if fade == false then
        BlzSetSpecialEffectAlpha(sfx, 0)
    end

    TQ:callDelayed(FPS_32, apply_sfx_fade, sfx, fade, count)
end

local shop_id = FourCC('n01F')

function MoveShopkeeper()
    local shop = evilshopkeeper

    if UnitAlive(shop) then
        local x = 0.
        local y = 0.

        repeat
            x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
            y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)

            if random(0, 99) < 5 then
                x = GetRandomReal(GetRectMinX(gg_rct_Tavern), GetRectMaxX(gg_rct_Tavern))
                y = GetRandomReal(GetRectMinY(gg_rct_Tavern), GetRectMaxY(gg_rct_Tavern))
            end

        until IsTerrainWalkable(x, y)

        evilshop:visible(false)
        ShowUnit(shop, false)
        ShowUnit(shop, true)
        SetUnitPosition(shop, x, y)
        BlzStartUnitAbilityCooldown(shop, FourCC('A017'), 300.)

        ShopSetStock(shop_id, 'I02B:0', 1)
        ShopSetStock(shop_id, 'I02C:0', 1)
        ShopSetStock(shop_id, 'I0EY:0', 1)
        ShopSetStock(shop_id, 'I074:0', 1)
        ShopSetStock(shop_id, 'I03U:0', 1)
        ShopSetStock(shop_id, 'I07F:0', 1)
        ShopSetStock(shop_id, 'I03P:0', 1)
        ShopSetStock(shop_id, 'I0F9:0', 1)
        ShopSetStock(shop_id, 'I079:0', 1)
        ShopSetStock(shop_id, 'I0FC:0', 1)
        ShopSetStock(shop_id, 'I00A:0', 1)

        local ghost = FourCC('Agho')
        UnitRemoveAbility(shop, ghost)
        TQ:callDelayed(5., UnitAddAbility, shop, ghost)
        SHOPKEEPER_CALLBACK = TQ:callDelayed(300., MoveShopkeeper)
    end
end

---@type fun(pt: PlayerTimer)
function HideSummonDelay(pt)
    ShowUnit(pt.target, false)

    pt:destroy()
end

---@type fun(pt: PlayerTimer)
function HideSummon(pt)
    SetUnitXBounded(pt.target, 30000)
    SetUnitYBounded(pt.target, 30000)

    pt:after(1., HideSummonDelay)
end

---@param u unit
function SummonExpire(u)
    local pid = GetPlayerId(GetOwningPlayer(u)) + 1
    local uid = GetUnitTypeId(u)

    TimerList[pid]:stopAllTimers(u)

    Unit[u].borrowed_life = 0

    if IsUnitHidden(u) == false then --important
        if uid == SUMMON_DESTROYER or uid == SUMMON_HOUND or uid == SUMMON_GOLEM then
            UnitRemoveAbility(u, FourCC('BNpa'))
            UnitRemoveAbility(u, FourCC('BNpm'))
            local pt = TimerList[pid]:add(u)
            pt.target = u
            pt.autoDestroy = false
            TQ:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", u, "origin"))

            pt:after(2., HideSummon)
        end

        if UnitAlive(u) then
            KillUnit(u)
        end
    end
end

---@param level integer
---@return integer
function RequiredXP(level)
    local base        = 150 ---@type integer 
    local levelFactor = 100 ---@type integer 

    for i = 2, level do
        base = base + i * levelFactor
    end

    return base
end

---@param p player
function CleanupSummons(p)
    for i = 1, #PLAYER_SUMMONS do
        local target = PLAYER_SUMMONS[i]
        if GetOwningPlayer(target) == p then
            SummonExpire(target)
        end
    end
end

---@param pid integer
function RecallSummons(pid)
    local p = Player(pid - 1) 
    local x = GetUnitX(Hero[pid]) + 200 * cos(bj_DEGTORAD * GetUnitFacing(Hero[pid])) ---@type number 
    local y = GetUnitY(Hero[pid]) + 200 * sin(bj_DEGTORAD * GetUnitFacing(Hero[pid])) ---@type number 

    for i = 1, #PLAYER_SUMMONS do
        local target = PLAYER_SUMMONS[i]
        if GetOwningPlayer(target) == p and (GetUnitTypeId(target) == SUMMON_HOUND or GetUnitTypeId(target) == SUMMON_GOLEM or GetUnitTypeId(target) == SUMMON_DESTROYER) and IsUnitHidden(target) == false then
            SetUnitPosition(target, x, y)
            SetUnitPathing(target, false)
            SetUnitPathing(target, true)
            BlzSetUnitFacingEx(target, GetUnitFacing(Hero[pid]))
        end
    end
end

---@param u unit
function reselect(u)
    if (GetLocalPlayer() == GetOwningPlayer(u)) then
        ClearSelection()
        SelectUnit(u, true)
    end
end

---@return boolean
function FilterEnemyDead()
    local u = GetFilterUnit()

    return GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == false
end

---@type fun():boolean
function FilterEnemy()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    IsUnitEnemy(u, Player(passedValue[#passedValue] - 1)) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u)
end

---@return boolean
function FilterAllyHero()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == true and
    IsUnitType(u, UNIT_TYPE_HERO) == true and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u)
end

---@return boolean
function FilterAlly()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == true
end

---@return boolean
function FilterEnemyAwake()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u) and
    IsUnitAlly(u, Player(passedValue[#passedValue] - 1)) == false and
    UnitIsSleeping(u) == false
end

---@return boolean
function FilterAlive()
    local u = GetFilterUnit()

    return UnitAlive(u) and
    GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and
    GetUnitAbilityLevel(u, ABIL_ALOC) == 0 and
    not IsDummy(u)
end

---@type fun(frame: framehandle, title: string, text: string, simple: boolean, point1: framepointtype|nil, point2: framepointtype|nil, x: number|nil, y: number|nil, margin: number|nil): table
function FrameAddSimpleTooltip(frame, title, text, simple, point1, point2, x, y, margin)
    local self = {}
    point1 = point1 or FRAMEPOINT_TOP
    point2 = point2 or FRAMEPOINT_BOTTOM
    x = x or 0.
    y = y or -0.008
    margin = margin or 0.008

    if simple then
        self.frame = BlzCreateFrame("Leaderboard", frame, 0, 0)
        self.tooltip = BlzCreateFrameByType("TEXT", "", self.frame, "", 0)
        BlzFrameSetPoint(self.tooltip, point1, frame, point2, x, y)
        BlzFrameSetPoint(self.frame, FRAMEPOINT_TOPLEFT, self.tooltip, FRAMEPOINT_TOPLEFT, -(margin), margin)
        BlzFrameSetPoint(self.frame, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, margin, -(margin))
    else
        self.frame = BlzCreateFrame("TooltipBoxFrame", frame, 0, 0)
        self.box = BlzGetFrameByName("TooltipBox", 0)
        self.line = BlzGetFrameByName("TooltipSeperator", 0)
        self.tooltip = BlzGetFrameByName("TooltipText", 0)
        self.iconFrame = BlzGetFrameByName("TooltipIcon", 0)
        self.nameFrame = BlzGetFrameByName("TooltipName", 0)

        BlzFrameSetPoint(self.tooltip, FRAMEPOINT_CENTER, BlzGetFrameByName("CommandButton_3", 0), FRAMEPOINT_TOPLEFT, -0.09, 0.045)
        BlzFrameSetSize(self.iconFrame, 0.009, 0.009)
        BlzFrameSetTexture(self.iconFrame, "trans32.blp", 0, true)
        BlzFrameSetText(self.nameFrame, title)
        BlzFrameSetPoint(self.box, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, -0.005, 0.005)
        BlzFrameSetPoint(self.box, FRAMEPOINT_BOTTOMRIGHT, self.tooltip, FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
        BlzFrameSetSize(self.tooltip, 0.275, 0)
        BlzFrameClearAllPoints(self.nameFrame)
        BlzFrameSetPoint(self.nameFrame, FRAMEPOINT_TOPLEFT, self.iconFrame, FRAMEPOINT_TOPLEFT, 0, 0)
        BlzFrameSetScale(self.nameFrame, 0.77)
    end

    BlzFrameSetText(self.tooltip, text)
    BlzFrameSetTooltip(frame, self.frame)

    return self
end

---@type fun(tbl: table, fadedur: number, fade: boolean)
local applyblackmask = function(tbl, fadedur, fade)
    for _, pid in ipairs(tbl) do
        pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid

        if GetLocalPlayer() == Player(pid - 1) then
            SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
            if fade then
                SetCineFilterStartColor(0,0,0,0)
                SetCineFilterEndColor(0,0,0,255)
            else
                SetCineFilterStartColor(0,0,0,255)
                SetCineFilterEndColor(0,0,0,0)
            end
            SetCineFilterDuration(fadedur)
            DisplayCineFilter(true)
        end
    end
end

---@type fun(tbl: table, fadein: number, fadeout: number)
function BlackMask(tbl, fadein, fadeout)
    applyblackmask(tbl, fadein, true)
    TQ:callDelayed(fadein, applyblackmask, tbl, fadeout, false)
end

---@type fun(tbl: table, x: number, y: number)
function MovePlayers(tbl, x, y)
    for _, pid in ipairs(tbl) do
        pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
        MoveHero(pid, x, y)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", Hero[pid], "origin"))
    end
end

-- Handles "I000:0" format item ids (includes level/variation)
-- Has backwards compatibility for integer item ids
---@type fun(id: string|integer)
---@return string index, integer origid, integer var
function GetItem(id)
    local var = 0
    local origid = id

    if type(id) == "string" then
        var = tonumber(id:sub(6)) or 0 ---@type integer
        origid = FourCC(id:sub(1, 4))
    end

    local index = pack(">I4", origid) .. ":" .. var

    return index, origid, var
end

--optional third argument for the nth item found
---@type fun(pid: integer, id: string|integer, count: integer?): Item | nil
function GetItemFromPlayer(pid, id, count)
    _, id, lvl = GetItem(id)
    count = count or 1

    for i = 1, MAX_INVENTORY_SLOTS do
        local slot = Profile[pid].hero.items[i]

        if slot and slot.id == id and (slot.level == lvl or lvl == -1) then
            if count <= 1 then
                return Profile[pid].hero.items[i]
            else
                count = count - 1
            end
        end
    end

    return nil
end

-- TODO: Remove / replace with perks
function UpdateBackpackTooltips(pid)
    local s = ""
    local u = User[pid - 1]
    local unlocked = 0

    for j = PUBLIC_SKINS + 2, TOTAL_SKINS do
        if CosmeticTable[u.name][j] > 0 then
            unlocked = unlocked + 1
        end
    end

    if unlocked >= 17 then
        s = "Change your backpack's appearance.\n\nUnlocked skins: |c0000ff4017/17"
    else
        s = "Change your backpack's appearance.\n\nUnlocked skins: " .. (unlocked) .. "/17"
    end

    if GetLocalPlayer() == u.player then
        BlzSetAbilityExtendedTooltip(FourCC('A0KX'), s, 0)
    end
end

---@type fun(hero: unit, aoe: number)
function Taunt(hero, aoe)
    local pid = GetPlayerId(GetOwningPlayer(hero)) + 1

    if IS_TAUNT_DISABLED[pid] then
        return
    end

    local ug = CreateGroup()

    MakeGroupInRange(pid, ug, GetUnitX(hero), GetUnitY(hero), aoe, Condition(FilterEnemy))

    for enemy in each(ug) do
        Unit[hero]:taunt(Unit[enemy])
    end

    DestroyGroup(ug)
end

---@type fun(pid: integer, x: number, y: number, percenthp: number, percentmana: number)
function RevivePlayer(pid, x, y, percenthp, percentmana)
    local p = Player(pid - 1)

    -- reenable backpack teleports
    DisableBackpackTeleports(pid, false)

    -- reenable inventory
    DisableItems(pid, false)

    ReviveHero(Hero[pid], x, y, true)
    SetWidgetLife(Hero[pid], BlzGetUnitMaxHP(Hero[pid]) * percenthp)
    SetUnitState(Hero[pid], UNIT_STATE_MANA, GetUnitState(Hero[pid], UNIT_STATE_MAX_MANA) * percentmana)
    PanCameraToTimedForPlayer(p, x, y, 0)
    SetUnitFlyHeight(Hero[pid], 0, 0)
    reselect(Hero[pid])
    SetUnitTimeScale(Hero[pid], 1.)
    SetUnitPropWindow(Hero[pid], bj_DEGTORAD * 60.)
    SetUnitPathing(Hero[pid], true)

    EVENT_ON_REVIVE:trigger(Hero[pid])
end

function SyncCallback(prefix, func)
    local t = CreateTrigger()
    local U = User.first
    while U do
        BlzTriggerRegisterPlayerSyncEvent(t, U.player, prefix, false)
        U = U.next
    end
    TriggerAddCondition(t, Condition(func))
end

end, Debug and Debug.getLine())
