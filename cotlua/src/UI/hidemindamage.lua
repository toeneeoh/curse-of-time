--[[
    hidemindamage.lua

    Credits: Tasyen
    A tool that hides the minimum damage from game UI
]]

OnInit.final("HideMin", function()
    local text, index
    local find, sub, get_text, set_text, is_visible = string.find, string.sub, BlzFrameGetText, BlzFrameSetText, BlzFrameIsVisible
    BlzLoadTOCFile("war3mapImported\\HideMinDamage.toc")
    local damageA = BlzGetFrameByName("InfoPanelIconValue", 0)
    local parentA = BlzGetFrameByName("SimpleInfoPanelIconDamage",0)
    BlzCreateSimpleFrame("CustomDamageString", parentA, 0)
    local damageA2 = BlzGetFrameByName("CustomDamageStringValue", 0)
    BlzFrameSetFont(damageA, "", 0, 0)

    local function update(sourceFrame, targetFrame)
        text = get_text(sourceFrame)
        index = find(text, " - ", 1, true)
        set_text(targetFrame, sub(text, index + 3))
    end

    local function check()
        if is_visible(parentA) then
            update(damageA, damageA2)
        end
    end

    local t = CreateTimer()
    TimerStart(t, 0.05, true, check)
end, Debug and Debug.getLine())
