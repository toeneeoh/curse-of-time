OnInit.final("ItemEquipmentMobility", function(Require)
    Require("Spells")

    local THANATOS_WINGS = Spell.define('A01F')
    do
        local thistype = THANATOS_WINGS

        function thistype:onCast()
            local wings = GetItemFromPlayer(self.pid, 'I04E:-1')

            if wings then
                local max = wings.cached_stats[ITEM_ABILITY]

                if wings.sfx_index then
                    wings.sfx_index = ((wings.sfx_index + 1) > max and 1) or wings.sfx_index + 1
                else
                    wings.sfx_index = 1
                end

                local tbl = ItemData[wings.id].sfx[wings.sfx_index]

                Unit[self.caster]:removeEffect(wings.sfx)
                wings.sfx = Unit[self.caster]:addEffect(tbl.path, tbl.attach)
            end
        end

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[orig_holder]:removeEffect(itm.sfx)
            itm.sfx = nil
        end

        function thistype.onEquip(itm, id, index)
            local sfx = ItemData[itm.id].sfx[itm.sfx_index or itm.cached_stats[index]]

            if not itm.sfx then
                itm.sfx = Unit[itm.holder]:addEffect(sfx.path, sfx.attach)
            end
        end
    end

    local SHORT_BLINK = Spell.define('A03D', 'A061', 'AIbk')
    do
        local thistype = SHORT_BLINK

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You can't blink there.")
            end
        end
    end

    local GOD_BLINK = Spell.define('A018')
    do
        local thistype = GOD_BLINK

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if CHAOS_MODE then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20.00, "With the Gods dead, these items no longer have the ability to move around the map with free will. Their powers are dead, however their innate fighting powers are left unscathed.")
            elseif r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't blink there.")
            end
        end

        function thistype.onEquip(itm, id, index)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_MAXIMUM_RANGE, 0, itm.cached_stats[index])
        end
    end

    local THANATOS_BOOTS = Spell.define('A01S')
    do
        local thistype = THANATOS_BOOTS

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You can't blink there.")
            end
        end

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[orig_holder]:removeEffect(itm.sfx)
            Unit[orig_holder]:removeEffect(itm.sfx2)
            itm.sfx = nil
        end

        function thistype.onEquip(itm, id, index)
            local tbl = ItemData[itm.id].sfx

            if not itm.sfx then
                itm.sfx = Unit[itm.holder]:addEffect(tbl[1].path, tbl[1].attach)
                itm.sfx2 = Unit[itm.holder]:addEffect(tbl[2].path, tbl[2].attach)
            end

            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_MAXIMUM_RANGE, 0, itm.cached_stats[index])
        end
    end
end, Debug and Debug.getLine())
