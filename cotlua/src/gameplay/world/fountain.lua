OnInit.final("Fountain", function(Require)
    Require('ALICE')
    Require('MapSetup')
    Require('TimerQueue')
    Require('Units')
    Require('UnitTable')

    local function restore_unit(unit)
        local max_health = BlzGetUnitMaxHP(unit)
        local max_mana = BlzGetUnitMaxMana(unit)
        local health = GetWidgetLife(unit)
        local mana = GetUnitState(unit, UNIT_STATE_MANA)

        if health < max_health * 0.99 then
            DestroyEffect(AddSpecialEffectTarget(
                "Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl",
                unit,
                "origin"
            ))
            SetWidgetLife(unit, health + max_health)
        end

        if mana < max_mana * 0.99 and not Unit[unit].nomanaregen then
            DestroyEffect(AddSpecialEffectTarget(
                "Abilities\\Spells\\Items\\AIma\\AImaTarget.mdl",
                unit,
                "origin"
            ))
            SetUnitState(unit, UNIT_STATE_MANA, mana + max_mana)
        end
    end

    TimerQueue:callPeriodically(1., nil, function()
        ALICE_ForAllObjectsInRangeDo(restore_unit, -260., 350., 600., "unit")
    end)
end, Debug and Debug.getLine())
