-- Read-only NPC classification for presentation. Building status is authored
-- in object data; changing UNIT_BF_IS_A_BUILDING at runtime did not enable hover.
OnInit.final("NpcPresentation", function(Require)
    Require('ShopRegistry')
    Require('Variables')

    NpcPresentation = {}
    local bundle = FourCC('nLTP')

    -- Read-only classification; callers may use this for local presentation.
    function NpcPresentation.isNPC(unit)
        if not unit or GetUnitTypeId(unit) == 0 then return false end
        local id = GetUnitTypeId(unit)
        if id == bundle or ShopRegistry.get(id) then return true end
        local owner = GetOwningPlayer(unit)
        return (owner == Player(PLAYER_NEUTRAL_PASSIVE) or owner == Player(PLAYER_TOWN)) and
            not IsUnitType(unit, UNIT_TYPE_HERO) and BlzIsUnitInvulnerable(unit)
    end
end, Debug and Debug.getLine())
