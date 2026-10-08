-- Run from the repository root. Exercises the real grave expiry callback
-- with mocked Warcraft natives; this does not replace an in-game death test.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local native_load = load
local function load(chunk, name, mode) return native_load(chunk, name, mode or "t", sandbox) end

local file = assert(io.open("cotlua/src/gameplay/combat/death.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(source:find("    local function grave_expire(pt)", 1, true))
local last = assert(source:find("    -- handles visuals", first, true))
local expire = assert(load(source:sub(first, last - 1) .. "\nreturn grave_expire"))()

Hero, HeroGrave = {[1] = {}}, {[1] = {}}
REVIVE_INDICATOR, REVIVE_BAR = {}, {}
ResurrectionRevival = {[1] = 0}
REINCARNATION = {enabled = {[1] = false}}
RESURRECTION = {spell = 0}
Profile = {[1] = {hero = {hardcore = 0}}}
Unit = {[Hero[1]] = {death_exception = false}}
MAIN_MAP = {rect = {}}
TOWN_CENTER_X, TOWN_CENTER_Y = 10, 20
GetResurrectionItem = function() return nil end
HideEffect, CleanupSummons, SetCamera = function() end, function() end, function() end
EVENT_GRAVE_DEATH = {trigger = function() end}
IsUnitHidden = function() return false end
UnitRemoveAbility, SetUnitPosition, ShowUnit = function() end, function() end, function() end
FourCC = function() return 0 end
Player = function(index) return index end
DisplayTextToPlayer = function() end

local charges, revived, cleanups = {}, 0, 0
ChargeNetworth = function(...) charges[#charges + 1] = {...} end
RevivePlayer = function(pid, x, y, health, mana)
    assert(pid == 1 and x == 10 and y == 20 and health == 1 and mana == 1)
    revived = revived + 1
end
PlayerCleanup = function() cleanups = cleanups + 1 end

for _, level in ipairs({1, 2, 3, 4, 100, 400}) do
    GetHeroLevel = function() return level end
    local before = #charges
    local revivals_before = revived
    expire({pid = 1})
    assert(revived == revivals_before + 1, "Softcore revival changed")
    if level <= 3 then
        assert(#charges == before, "Starter death charged gold at level " .. level)
    else
        assert(#charges == before + 1, "Missing death charge at level " .. level)
        local charge = charges[#charges]
        assert(charge[1] == 0 and charge[2] == 0 and charge[3] == 0.02 and
            charge[4] == 50 * level and charge[5] == "Dying has cost you",
            "Higher-level death formula changed")
    end
end

-- The exemption must not allow Hardcore heroes to revive.
Profile[1].hero.hardcore = 1
GetHeroLevel = function() return 1 end
local before, revivals_before = #charges, revived
local timer = {pid = 1, autoDestroy = true}
expire(timer)
assert(cleanups == 1 and not timer.autoDestroy and revived == revivals_before and #charges == before)
print("PASS: levels 1–3 incur no death charge; level 4+ formula, revival, and Hardcore behavior are unchanged.")
