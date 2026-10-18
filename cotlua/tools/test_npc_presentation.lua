-- Actual read-only NPC classification and local armor wrapper on native mocks.
local function client(selected)
    local env = setmetatable({}, {__index = _G})
    local frames, callbacks, mutations, creates = {}, {}, {}, 0
    env.OnInit = {final = function(_, callback) callback(function() end) end}
    env.FourCC, env.Player = function(id) return id end, function(id) return id end
    env.UNIT_BF_IS_A_BUILDING, env.UNIT_TYPE_HERO = 'building', 'hero'
    env.PLAYER_NEUTRAL_PASSIVE, env.PLAYER_TOWN = 27, 8
    env.Unit = {onIndex = function(callback) callbacks[#callbacks + 1] = callback end}
    env.ShopRegistry = {get = function(id) return id == 'n01A' or id == 'n01B' or id == 'other_shop' end}
    env.GetUnitTypeId, env.GetOwningPlayer = function(u) return u.id end, function(u) return u.owner end
    env.IsUnitType = function(u) return u.hero or false end
    env.BlzIsUnitInvulnerable = function(u) return u.invulnerable or false end
    env.BlzSetUnitBooleanField = function(u, field, value)
        u[field] = value; mutations[#mutations + 1] = u.id .. ':' .. field .. ':' .. tostring(value); return true
    end
    local root = {visible = true}
    env.BlzGetFrameByName = function(name, context)
        local key = name .. context
        if not frames[key] then frames[key] = {parent = root, visible = true} end
        return frames[key]
    end
    env.BlzFrameGetParent = function(f) return f.parent end
    env.BlzCreateFrameByType = function(_, _, parent)
        creates = creates + 1; return {parent = parent, visible = true}
    end
    env.BlzFrameSetParent = function(f, p) f.parent = p end
    env.BlzFrameSetAllPoints = function() end
    env.BlzFrameSetVisible = function(f, visible) f.visible = visible end
    env.BlzFrameIsVisible = function(f) return f.visible end
    env.GetMainSelectedUnit = function() return selected end
    assert(loadfile('cotlua/src/gameplay/world/npc_presentation.lua', 't', env))()
    assert(#callbacks == 0 and #mutations == 0, 'NPC presentation must not toggle building state in game')
    assert(loadfile('cotlua/src/ui/hud/npc_info_panel.lua', 't', env))()
    local armor = frames.SimpleInfoPanelIconArmor2
    local gate = armor.parent
    local count = #mutations
    for _, case in ipairs({
        {unit = selected, hidden = selected and selected.id == 'n01A'},
        {unit = {id = 'nLTP', owner = 27}, hidden = true},
        {unit = {id = 'quest_npc', owner = 8, invulnerable = true}, hidden = true},
        {unit = {id = 'other_shop', owner = 27}, hidden = true},
        {unit = {id = 'hero', owner = 0, hero = true, invulnerable = true}, hidden = false},
        {unit = {id = 'enemy', owner = 11, invulnerable = true}, hidden = false},
        {unit = {id = 'enemy', owner = 27}, hidden = false},
        {hidden = false},
    }) do
        selected = case.unit
        env.NpcInfoPanel.refresh()
        -- Simulate the engine re-showing its armor frame on a selection change.
        armor.visible = true
        assert(gate.visible == not case.hidden)
    end
    selected = {id = 'n01A', owner = 8}; env.NpcInfoPanel.refresh(); assert(not gate.visible)
    frames.SimpleInfoPanelUnitDetail0.visible = false -- deselection / items / group panel
    env.NpcInfoPanel.refresh(); assert(gate.visible)
    assert(#mutations == count and creates == 1, 'Local selection mutated units or created frames')
    return table.concat(mutations, '|')
end
assert(client({id = 'n01A', owner = 8}) == client({id = 'hero', owner = 0, hero = true}))
print('PASS: NPC-only armor/Invulnerable hiding, combat/deselection restoration, fixed frame allocation, and local selection has no shared unit mutations.')
