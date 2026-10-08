OnInit.final("ItemAuraAbilities", function(Require)
    Require("Spells")

    local TQ = TimerQueue

    local EMPYREAN_SONG = Spell.define('A04I')
    EMPYREAN_SONG.ACTIVE = false
    EMPYREAN_SONG.ITEM_NATIVE_ABILITY = true
    do
        local thistype = EMPYREAN_SONG

        local function periodic(itm, holder)
            if itm and itm.holder then
                local ug = CreateGroup()
                MakeGroupInRange(itm.pid, ug, GetUnitX(holder), GetUnitY(holder), 900. * LBOOST[itm.pid], Condition(FilterAlly))

                for ally in each(ug) do
                    EmpyreanSongBuff:add(holder, ally):duration(2.)
                end

                DestroyGroup(ug)
                TQ:callDelayed(1., periodic, itm, holder)
            end
        end

        function thistype.onEquip(itm, id, index)
            periodic(itm, itm.holder)
        end
    end

    local UNHOLY_AURA = Spell.define('A03G')
    UNHOLY_AURA.ACTIVE = false
    UNHOLY_AURA.ITEM_NATIVE_ABILITY = true
    do
        local thistype = UNHOLY_AURA

        local function periodic(itm, holder)
            if itm and itm.holder then
                local ug = CreateGroup()
                MakeGroupInRange(itm.pid, ug, GetUnitX(holder), GetUnitY(holder), 900. * LBOOST[itm.pid], Condition(FilterAlly))

                for ally in each(ug) do
                    BloodHornBuff:add(holder, ally):duration(2.)
                end

                DestroyGroup(ug)
                TQ:callDelayed(1., periodic, itm, holder)
            end
        end

        function thistype.onEquip(itm, id, index)
            periodic(itm, itm.holder)
        end
    end

    local REINCARNATION_NORECHARGE = Spell.define('Anrv')
    do
        local thistype = REINCARNATION_NORECHARGE
        thistype.ACTIVE = false

        function thistype:onCast(itm)
            local heal = itm.cached_stats[ITEM_ABILITY] * 0.01

            itm:consumeCharge()

            local dummy = itm.abilities[ITEM_ABILITY].obj

            RevivePlayer(itm.pid, GetUnitX(HeroGrave[itm.pid]), GetUnitY(HeroGrave[itm.pid]), heal, heal)
            SetItemCharges(dummy, itm.charges)
            INVENTORY.refresh(itm.pid)
        end

        function thistype.onEquip(itm, id, index)
            SetItemCharges(itm.abilities[index].obj, itm.charges)
        end
    end

    local REINCARNATION_RECHARGE = Spell.define('Arrv')
    do
        local thistype = REINCARNATION_RECHARGE
        thistype.ACTIVE = false

        function thistype:onCast(itm)
            local heal = itm.cached_stats[ITEM_ABILITY] * 0.01

            itm.charges = itm.charges - 1
            local dummy = itm.abilities[ITEM_ABILITY].obj

            RevivePlayer(itm.pid, GetUnitX(HeroGrave[itm.pid]), GetUnitY(HeroGrave[itm.pid]), heal, heal)
            SetItemCharges(dummy, itm.charges)
            INVENTORY.refresh(itm.pid)
        end

        function thistype.onEquip(itm, id, index)
            SetItemCharges(itm.abilities[index].obj, itm.charges)
        end
    end
    local DETECTION = Spell.define('Adt1')
    DETECTION.ACTIVE = false
    DETECTION.ITEM_NATIVE_ABILITY = true
    local ENDURANCE_AURA = Spell.define('A03F')
    ENDURANCE_AURA.ACTIVE = false
    ENDURANCE_AURA.ITEM_NATIVE_ABILITY = true
    local VAMPIRIC_AURA = Spell.define('A03H')
    VAMPIRIC_AURA.ACTIVE = false
    VAMPIRIC_AURA.ITEM_NATIVE_ABILITY = true
    local WAR_DRUM_AURA = Spell.define('AIcd')
    WAR_DRUM_AURA.ACTIVE = false
    WAR_DRUM_AURA.ITEM_NATIVE_ABILITY = true
    local CRYSTAL_BALL = Spell.define('AIta')
    CRYSTAL_BALL.ACTIVE = true
    local SEA_WARDS = Spell.define('A0E2')
    SEA_WARDS.ACTIVE = true
    local JEWEL_OF_THE_HORDE = Spell.define('A0D3')
    JEWEL_OF_THE_HORDE.ACTIVE = true
end, Debug and Debug.getLine())
