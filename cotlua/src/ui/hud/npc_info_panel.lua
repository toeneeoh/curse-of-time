-- Hide only the NPC armor row, including its native Invulnerable text.
OnInit.final("NpcInfoPanel", function(Require)
    Require('Frames')
    Require('FrameHelpersSelection')
    Require('NpcPresentation')

    NpcInfoPanel = {}
    local armor = BlzGetFrameByName("SimpleInfoPanelIconArmor", 2)
    local parent = BlzFrameGetParent(armor)
    local gate = BlzCreateFrameByType("SIMPLEFRAME", "NpcArmorVisibility", parent, "", 0)
    BlzFrameSetAllPoints(gate, parent)
    BlzFrameSetParent(armor, gate)
    local detail = BlzGetFrameByName("SimpleInfoPanelUnitDetail", 0)
    local hidden = false

    -- Called by the existing native-stat-panel timer. Local selection is used
    -- solely for frame visibility; it never drives unit mutations or timers.
    function NpcInfoPanel.refresh()
        local hide = false
        if BlzFrameIsVisible(detail) then
            hide = NpcPresentation.isNPC(GetMainSelectedUnit())
        end
        if hide ~= hidden then
            hidden = hide
            -- The engine can show/hide the armor frame on selection; it does
            -- not control this wrapper, so the whole row stays hidden for NPCs.
            BlzFrameSetVisible(gate, not hide)
        end
    end
end, Debug and Debug.getLine())
