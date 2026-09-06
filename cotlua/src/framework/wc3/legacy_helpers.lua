--[[
    helper.lua

    A general purpose module with useful helper functions for use across files.
]]

OnInit.global("Helper", function(Require)
    Require('Variables')
    Require('TimerQueue')
    Require('TableHelpers')
    Require('Geometry')
    Require('Effects')
    Require('Groups')
    Require('TextHelpers')
    Require('FrameHelpers')

    local TQ = TimerQueue
    local floor, sin, cos, min, max, random = math.floor, math.sin, math.cos, math.min, math.max, math.random
    local type, pack = type, string.pack
    local Player, FourCC, GetFilterUnit, GetOwningPlayer, GetUnitTypeId, UnitAlive = Player, FourCC, GetFilterUnit, GetOwningPlayer, GetUnitTypeId, UnitAlive
    local GetUnitX, GetUnitY, BlzGetUnitMaxHP, IsUnitAlly, GetUnitAbilityLevel, GetLocalPlayer = GetUnitX, GetUnitY, BlzGetUnitMaxHP, IsUnitAlly, GetUnitAbilityLevel, GetLocalPlayer
    local CreateTextTag, SetTextTagPermanent, SetTextTagColor, SetTextTagLifespan, SetTextTagFadepoint, SetTextTagText, SetTextTagPos = CreateTextTag, SetTextTagPermanent, SetTextTagColor, SetTextTagLifespan, SetTextTagFadepoint, SetTextTagText, SetTextTagPos

local RealToString = RealToString

--misc helper functions

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

    if IsUnitHidden(u) == false then --important
        if uid == SUMMON_DESTROYER or uid == SUMMON_REAVER or uid == SUMMON_BRUTE then
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
        if GetOwningPlayer(target) == p and (GetUnitTypeId(target) == SUMMON_REAVER or GetUnitTypeId(target) == SUMMON_BRUTE or GetUnitTypeId(target) == SUMMON_DESTROYER) and IsUnitHidden(target) == false then
            SetUnitPosition(target, x, y)
            SetUnitPathing(target, false)
            SetUnitPathing(target, true)
            BlzSetUnitFacingEx(target, GetUnitFacing(Hero[pid]))
        end
    end
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
