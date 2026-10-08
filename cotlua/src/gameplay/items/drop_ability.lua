OnInit.final("ItemDropAbility", function(Require)
    Require("Spells")

    local DROP_ITEM = Spell.define("A015")
    do
        local thistype = DROP_ITEM

        function thistype.preCast(pid, _, _, _, _, _, targetX, targetY)
            local hero = Profile[pid].hero
            local item = hero.item_to_drop

            if item then
                local itm = hero.items[item.index]
                if itm then
                    itm:drop(targetX, targetY)
                end
            end
        end
    end
end, Debug and Debug.getLine())



