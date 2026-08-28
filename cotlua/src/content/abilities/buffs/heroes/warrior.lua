OnInit.final("BuffsHeroesWarrior", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class SpinDashBuff : Buff
    SpinDashBuff = Buff.new()
    do
        local thistype = SpinDashBuff
        thistype.NAME            = "Spin Dash"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNComed Fall.blp"
        thistype.DESC            = "This unit may recast Spin Dash"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            BlzStartUnitAbilityCooldown(self.source, SPINDASH.id, 3. + self:remaining())
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(self.source, SPINDASH.id), ABILITY_ILF_TARGET_TYPE, GetUnitAbilityLevel(self.source, SPINDASH.id) - 1, 2)
        end

        function thistype:onApply()
            self.x = GetUnitX(self.target)
            self.y = GetUnitY(self.target)
        end
    end

    ---@class SpinDashDebuff : Buff
    SpinDashDebuff = Buff.new()
    do
        local thistype = SpinDashDebuff
        thistype.NAME            = "Spin Dash"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNComed Fall.blp"
        thistype.DESC            = "This unit has -^#as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            local u = Unit[self.target]
            u:removeEffect(self.sfx)
            u.bonus_bat = u.bonus_bat / self.as
        end

        function thistype:onApply()
            local u = Unit[self.target]

            self.as = 1.25
            u.bonus_bat = u.bonus_bat * self.as

            self.sfx = u:addEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", "overhead")
        end
    end

    ---@class ParryBuff : Buff
    ParryBuff = Buff.new()
    do
        local thistype = ParryBuff
        thistype.NAME            = "Parry"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNReflex.blp"
        thistype.DESC            = "This unit is immune to damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(target, source, amount_ref)
            local self = ParryBuff:get(target, target)

            if self then
                local pid = GetPlayerId(GetOwningPlayer(target)) + 1
                amount_ref.value = 0.00
                self:playSound()

                DamageTarget(target, source, PARRY.dmg(pid) * (((LIMITBREAK.flag[pid] & 0x1) > 0 and 2.) or 1.) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, PARRY.tag)
            end
        end

        function thistype:playSound()
            if not self.soundPlayed then
                self.soundPlayed = true

                SoundHandler("war3mapImported\\parry" .. GetRandomInt(1, 2) .. ".mp3", true, GetOwningPlayer(self.target), self.target)
            end
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, on_hit)
            AddUnitAnimationProperties(self.target, "ready", false)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, on_hit)
            AddUnitAnimationProperties(self.target, "ready", true)

            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Buff_Shield_Non.mdx", "chest")

            if LIMITBREAK.flag[self.tpid] & 0x1 > 0 then
                self.sfx.color = {255, 255, 0}
            end
        end
    end

    ---@class IntimidatingShoutBuff : Buff
    IntimidatingShoutBuff = Buff.new()
    do
        local thistype = IntimidatingShoutBuff
        thistype.NAME            = "Intimidating Shout"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBattleShout.blp"
        thistype.DESC            = "This unit has +^$dmg% attack damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.dmg
        end

        function thistype:onApply()
            self.dmg = 0.2
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\BattleCryTarget.mdx", "overhead")

            Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.dmg
        end
    end

    ---@class IntimidatingShoutDebuff : Buff
    IntimidatingShoutDebuff = Buff.new()
    do
        local thistype = IntimidatingShoutDebuff
        thistype.NAME            = "Intimidating Shout"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBattleShout.blp"
        thistype.DESC            = "This unit has -^#dmg% attack damage"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            local u = Unit[self.target]
            u.mr = Unit[self.target].mr / self.mr
            u:removeEffect(self.sfx)

            u.damage_percent = u.damage_percent + self.dmg
        end

        function thistype:onApply()
            local u = Unit[self.target]
            self.mr = (LIMITBREAK.flag[self.pid] & 0x4 > 0 and 1.4) or 1

            u.mr = u.mr * self.mr
            self.dmg = 0.4

            self.sfx = u:addEffect("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", "overhead")

            u.damage_percent = Unit[self.target].damage_percent - self.dmg
        end
    end

    ---@class AdaptiveStrikeBuff : Buff
    AdaptiveStrikeBuff = Buff.new()
    do
        local thistype = AdaptiveStrikeBuff
        thistype.NAME            = "Adaptive Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGhostOrb.blp"
        thistype.DESC            = "This spell is on cooldown"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
        end

        function thistype:onApply()
        end
    end

end, Debug and Debug.getLine())
