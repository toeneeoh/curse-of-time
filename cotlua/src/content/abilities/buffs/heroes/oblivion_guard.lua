OnInit.final("BuffsHeroesOblivionGuard", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan
    local valid_pull_target = VALID_PULL_TARGET

    ---@class MagneticStanceBuff : Buff
    MagneticStanceBuff = Buff.new()
    do
        local thistype = MagneticStanceBuff
        thistype.NAME            = "Magnetic Stance"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNChaosWave1.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist and deals -^#dm% total damage while pulling nearby enemies"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function taunt(self, aoe)
            Taunt(self.target, aoe)

            self.callback = TQ:callDelayed(3., taunt, self, aoe)
        end

        local function pull_force(target, _, x, y)
            local x2, y2 = GetUnitX(target), GetUnitY(target)
            local dist = DistanceCoords(x, y, x2, y2)
            if dist > 200 then
                local angle = atan(y - y2, x - x2)
                local strength = 500000. / (dist ^ 2)
                SetUnitXBounded(target, x2 + strength * math.cos(angle))
                SetUnitYBounded(target, y2 + strength * math.sin(angle))
            end
        end

        local function pull(self)
            local x, y = GetUnitX(self.target), GetUnitY(self.target)
            ALICE_ForAllObjectsInRangeDo(pull_force, x, y, 800., "nonhero", valid_pull_target, self.target, x, y)

            self.pull = TQ:callDelayed(FPS_32, pull, self)
        end

        function thistype:onRemove()
            TQ:disableCallback(self.callback)
            TQ:disableCallback(self.pull)
            SetUnitVertexColor(self.target, 255, 255, 255, 255)
            Unit[self.target].dm = Unit[self.target].dm / self.dm
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            SetUnitVertexColor(self.target, 255, 25, 25, 255)
            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Call of Dread Red.mdx", self.target, "chest"))

            self.callback = TQ:callDelayed(3., taunt, self, 800.)
            pull(self)

            local ablev = GetUnitAbilityLevel(self.source, MAGNETICSTANCE.id)
            self.dr = (0.95 - 0.05 * ablev)
            self.dm = (0.45 + 0.05 * ablev)

            Unit[self.target].dm = Unit[self.target].dm * self.dm
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class MagneticStrikeDebuff : Buff
    MagneticStrikeDebuff = Buff.new()
    do
        local thistype = MagneticStrikeDebuff
        thistype.NAME            = "Magnetic Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInfernalImpact.blp"
        thistype.DESC            = "This unit has -^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 1.15
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class MagneticStrikeBuff : Buff
    MagneticStrikeBuff = Buff.new()
    do
        local thistype = MagneticStrikeBuff
        thistype.NAME            = "Magnetic Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInfernalImpact.blp"
        thistype.DESC            = "This unit's next attack will trigger Magnetic Strike"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            BODYOFFIRE.charges[pid] = BODYOFFIRE.charges[pid] - 1

            if GetLocalPlayer() == Player(pid - 1) then
                BlzSetAbilityIcon(BODYOFFIRE.id, "ReplaceableTextures\\CommandButtons\\BTNBodyOfFire" .. (BODYOFFIRE.charges[pid]) .. ".blp")
            end

            -- disable casting at 0 charges
            if BODYOFFIRE.charges[pid] <= 0 then
                UnitDisableAbility(source, INFERNALSTRIKE.id, true)
                BlzUnitHideAbility(source, INFERNALSTRIKE.id, false)
                UnitDisableAbility(source, MAGNETICSTRIKE.id, true)
                BlzUnitHideAbility(source, MAGNETICSTRIKE.id, false)
            end

            -- refresh charge timer
            if not BODYOFFIRE.callback[pid] then
                BODYOFFIRE.callback[pid] = TQ:callDelayed(5., BODYOFFIRE.cooldown, pid, source)
                BlzStartUnitAbilityCooldown(source, BODYOFFIRE.id, 5.)
            end
            MagneticStrikeBuff:dispel(source, source)

            local ug = CreateGroup()
            MakeGroupInRange(pid, ug, GetUnitX(target), GetUnitY(target), MAGNETICSTRIKE.aoe(pid) * LBOOST[pid], Condition(FilterEnemy))

            for u in each(ug) do
                MagneticStrikeDebuff:add(source, u):duration(MAGNETICSTRIKE.dur(pid) * LBOOST[pid])
            end

            DestroyGroup(ug)

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", GetUnitX(target), GetUnitY(target)))
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(target), GetUnitY(target)))
        end

        function thistype:onRemove()
            EVENT_ON_HIT_MULTIPLIER:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_HIT_MULTIPLIER:register_unit_action(self.target, on_hit)
        end
    end

    ---@class InfernalStrikeBuff : Buff
    InfernalStrikeBuff = Buff.new()
    do
        local thistype = InfernalStrikeBuff
        thistype.NAME            = "Infernal Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFireImpact.blp"
        thistype.DESC            = "This unit's next attack will trigger Infernal Strike"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target, amount_ref)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            BODYOFFIRE.charges[pid] = BODYOFFIRE.charges[pid] - 1

            if GetLocalPlayer() == Player(pid - 1) then
                BlzSetAbilityIcon(BODYOFFIRE.id, "ReplaceableTextures\\CommandButtons\\BTNBodyOfFire" .. (BODYOFFIRE.charges[pid]) .. ".blp")
            end

            -- disable casting at 0 charges
            if BODYOFFIRE.charges[pid] <= 0 then
                UnitDisableAbility(source, INFERNALSTRIKE.id, true)
                BlzUnitHideAbility(source, INFERNALSTRIKE.id, false)
                UnitDisableAbility(source, MAGNETICSTRIKE.id, true)
                BlzUnitHideAbility(source, MAGNETICSTRIKE.id, false)
            end

            -- refresh charge timer
            if not BODYOFFIRE.callback[pid] then
                BODYOFFIRE.callback[pid] = TQ:callDelayed(5., BODYOFFIRE.cooldown, pid, source)
                BlzStartUnitAbilityCooldown(source, BODYOFFIRE.id, 5.)
            end

            InfernalStrikeBuff:dispel(source, source)
            amount_ref.value = 0.00

            local ablev = GetUnitAbilityLevel(source, INFERNALSTRIKE.id)

            local ug = CreateGroup()
            MakeGroupInRange(pid, ug, GetUnitX(target), GetUnitY(target), 250. * LBOOST[pid], Condition(FilterEnemy))
            local count = BlzGroupGetSize(ug)

            for u in each(ug) do
                if IsUnitType(u, UNIT_TYPE_HERO) then
                    count = count + 4
                end
                local dtype = BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE)

                if dtype == 1 or dtype == 7 then -- boss
                    DamageTarget(source, u, ((GetHeroStr(source, true) * ablev) + GetWidgetLife(u) * (0.25 + 0.05 * ablev)) * 0.5 * LBOOST[pid], ATTACK_TYPE_NORMAL, PHYSICAL, INFERNALSTRIKE.tag)
                else
                    DamageTarget(source, u, ((GetHeroStr(source, true) * ablev) + GetWidgetLife(u) * (0.25 + 0.05 * ablev)) * LBOOST[pid], ATTACK_TYPE_NORMAL, PHYSICAL, INFERNALSTRIKE.tag)
                end
            end

            DestroyGroup(ug)

            DestroyEffect(AddSpecialEffect("war3mapImported\\Lava_Slam.mdx", GetUnitX(target), GetUnitY(target)))
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(target), GetUnitY(target)))

            --6 percent max heal
            HP(source, source, BlzGetUnitMaxHP(source) * 0.01 * IMinBJ(6, count), INFERNALSTRIKE.tag)
        end

        function thistype:onRemove()
            EVENT_ON_HIT_MULTIPLIER:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_HIT_MULTIPLIER:register_unit_action(self.target, on_hit)
        end
    end

end, Debug and Debug.getLine())
