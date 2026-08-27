-- Naga dungeon boss abilities and their damage-driven casting behavior.

OnInit.final("NagaAbilities", function(Require)
    Require("Spells")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local random = math.random

    local BERSERK = Spell.define('A04V')
    do
        local thistype = BERSERK

        local function apply_attack_speed(source)
            if UnitAlive(source) then
                NagaBerserkBuff:add(source, source):duration(4.)
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Enrage", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TQ:callDelayed(2., apply_attack_speed, self.caster)
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) == 0 and GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local MIASMA = Spell.define('A04W')
    do
        local thistype = MIASMA

        local function periodic(caster, time)
            time = time - 1

            if time > 0 then
                local ug = CreateGroup()

                GroupEnumUnitsInRect(ug, gg_rct_Naga_Dungeon, Condition(isplayerunit))

                for target in each(ug) do
                    if ModuloInteger(time, 2) == 0 then
                        TQ:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Units\\Undead\\PlagueCloud\\PlagueCloudtarget.mdl", target, "overhead"))
                    end
                    DamageTarget(caster, target, 25000 + BlzGetUnitMaxHP(target) * 0.03, ATTACK_TYPE_NORMAL, MAGIC, "Miasma")
                end
                TQ:callDelayed(0.5, periodic, caster, time)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Miasma", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            SetUnitAnimation(self.caster, "channel")
            TQ:callDelayed(2., periodic, self.caster, 41)
            for i = 0, 3 do
                local sfx = AddSpecialEffect("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", self.x + 175 * math.cos(bj_PI * i / 2 + (bj_PI / 4.)), self.y + 175 * math.sin(bj_PI * i / 2 + (bj_PI / 4.)))
                BlzSetSpecialEffectScale(sfx, 2.)
                TQ:callDelayed(21., DestroyEffect, sfx)
            end
        end

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) == 0 and GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local THORNS = Spell.define('A04K')
    do
        local thistype = THORNS

        local function apply(caster)
            NagaThorns:add(caster, caster):duration(6.5)
        end

        function thistype:onCast()
            FloatingTextUnit(thistype.tag, self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TQ:callDelayed(2., apply, self.caster)
            TQ:callDelayed(8.5, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Orc\\SpikeBarrier\\SpikeBarrier.mdl", self.caster, "origin"))
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SWARM = Spell.define('A04R')
    do
        local thistype = SWARM

        local function beetle_on_hit(source, target)
            Stun:add(source, target):duration(8.)
            KillUnit(source)
        end

        local function beetle_on_struck(target, source, amount, damage_type)
            if damage_type == MAGIC then
                amount.value = 0.00
            end
        end

        local function beetle_ai(source, target)
            PauseUnit(source, false)
            UnitRemoveAbility(source, ABIL_AVUL)
            IssueTargetOrder(source, "attack", target)
            UnitApplyTimedLife(source, FourCC('BTLF'), 6.5)
            EVENT_ON_HIT_EVADE:register_unit_action(source, beetle_on_hit)
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(source, beetle_on_struck)
            TQ:callDelayed(5., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Other\\Parasite\\ParasiteTarget.mdl", source, "overhead"))
        end

        function thistype:onCast()
            FloatingTextUnit(thistype.tag, self.caster, 2, 50, 0, 13.5, 155, 255, 255, 0, true)
            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, self.x, self.y, 1250., Condition(isplayerunit))

            local target = FirstOfGroup(ug)
            while target do
                if random() < 0.75 then
                    GroupRemoveUnit(ug, target)
                end
                local rand = random(0, 359)
                local x, y = self.x + random(150, 250) * math.cos(bj_DEGTORAD * rand), self.y + random(125, 250) * math.sin(bj_DEGTORAD * rand)
                local beetle = CreateUnit(Player(self.pid - 1), FourCC('u002'), x, y, 0)
                BlzSetUnitFacingEx(beetle, bj_RADTODEG * math.atan(GetUnitY(target) - y, GetUnitX(target) - x))
                PauseUnit(beetle, true)
                UnitAddAbility(beetle, ABIL_AVUL)
                SetUnitAnimation(beetle, "birth")
                TQ:callDelayed(GetRandomReal(0.75, 1.), beetle_ai, beetle, target)
                target = FirstOfGroup(ug)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TRIDENT_STRIKE = Spell.define('A00O')
    do
        local thistype = TRIDENT_STRIKE

        local function proc(source, dmg, x, y, aoe, filter)
            local ug = CreateGroup()

            GroupEnumUnitsInRange(ug, x, y, aoe, filter)

            for target in each(ug) do
                DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function onHit(source, target, amount)
            source = Unit[source]
            amount.value = 0.00

            source.hits = source.hits + 1
            FloatingTextUnit(tostring(source.hits), target, 1.5, 50, 150., 14.5, 255, 255, 255, 0, true)

            if source.tri_target ~= target then
                source.hits = 1
            elseif source.hits > 2 then
                proc(source.unit, BlzGetUnitMaxHP(target) * 0.7, GetUnitX(target), GetUnitY(target), 120., Condition(isplayerunit))
                DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", target, "origin"))
                source.hits = 0
            end

            source.tri_target = target
        end

        function thistype.onSetup(u)
            Unit[u].hits = 0
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local SPIRIT_CALL = Spell.define('A05C')
    do
        local thistype = SPIRIT_CALL

        local function spirit_call_on_hit(source, target)
            DamageTarget(source, target, BlzGetUnitMaxHP(target) * 0.1, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            SpiritCallSlow:add(source, target):duration(5.)
        end

        ---@return boolean
        local function is_spirit(object)
            local id = GetUnitTypeId(object)
            return id == FourCC('n00P')
        end

        local function valid_target(object)
            return UnitAlive(object) and GetUnitAbilityLevel(object, ABIL_AVUL) == 0 and GetPlayerId(GetOwningPlayer(object)) < PLAYER_CAP
        end

        local function dummy_attack(object, source)
            local dummy = Dummy.create(GetUnitX(source), GetUnitY(source), FourCC('A09R'), 1)
            dummy:attack(object, source, spirit_call_on_hit)
        end

        local minX, minY, maxX, maxY = GetRectMinX(gg_rct_Naga_Dungeon_Boss), GetRectMinY(gg_rct_Naga_Dungeon_Boss), GetRectMaxX(gg_rct_Naga_Dungeon_Boss), GetRectMaxY(gg_rct_Naga_Dungeon_Boss)
        local spirits = ALICE_EnumObjectsInRect(minX, minY, maxX, maxY, "unit", is_spirit)

        local function periodic(time)
            time = time - 1

            if time >= 0 then
                local player_units = ALICE_EnumObjectsInRect(minX, minY, maxX, maxY, "unit", valid_target)
                if #player_units > 0 then
                    for _, source in ipairs(spirits) do
                        if random() < 0.25 then
                            local u = player_units[random(1, #player_units)]
                            IssuePointOrder(source, "move", GetUnitX(u) + random(-150, 150), GetUnitY(u) + random(-150, 150))
                        end
                        ALICE_ForAllObjectsInRangeDo(dummy_attack, GetUnitX(source), GetUnitY(source), 300., "unit", valid_target, source)
                    end
                end
                TQ:callDelayed(1., periodic, time)
            else
                for _, source in ipairs(spirits) do
                    SetUnitVertexColor(source, 100, 255, 100, 255)
                    SetUnitScale(source, 1, 1, 1)
                    IssuePointOrder(source, "move", GetRandomReal(minX, maxX), GetRandomReal(minY, maxY))
                end
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Spirit Call", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)

            for _, target in ipairs(spirits) do
                SetUnitVertexColor(target, 255, 25, 25, 255)
                SetUnitScale(target, 1.25, 1.25, 1.25)
            end

            TQ:callDelayed(1., periodic, 15)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local COLLAPSE = Spell.define('A05K')
    do
        local thistype = COLLAPSE

        local function expire(dummies, caster)
            local ug = CreateGroup()

            for _, v in ipairs(dummies) do
                local x, y = GetUnitX(v), GetUnitY(v)

                GroupEnumUnitsInRange(ug, x, y, 500., Condition(isplayerunit))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x + 150, y + 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x - 150, y - 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x + 150, y - 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x - 150, y + 150))

                for target in each(ug) do
                    DamageTarget(caster, target, BlzGetUnitMaxHP(target) * GetRandomReal(0.75, 1), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            end

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local dummies = {}

            for _ = 0, 9 do
                local dummy = Dummy.create(GetRandomReal(GetRectMinX(gg_rct_Naga_Dungeon_Boss), GetRectMaxX(gg_rct_Naga_Dungeon_Boss)), GetRandomReal(GetRectMinY(gg_rct_Naga_Dungeon_Boss), GetRectMaxY(gg_rct_Naga_Dungeon_Boss)), 0, 0, 4.).unit
                dummies[#dummies + 1] = dummy
                BlzSetUnitFacingEx(dummy, 270.)
                BlzSetUnitSkin(dummy, FourCC('e01F'))
                SetUnitScale(dummy, 10., 10., 10.)
                SetUnitVertexColor(dummy, 0, 255, 255, 255)
            end

            FloatingTextUnit("Collapse", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TQ:callDelayed(3., expire, dummies, self.caster)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

end, Debug and Debug.getLine())
