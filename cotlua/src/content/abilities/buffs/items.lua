OnInit.final("BuffsItems", function(Require)
    Require('BuffSystem')
    Require('CooldownAcceleration')
    Require('Groups')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class EmpyreanSongBuff : Buff
    EmpyreanSongBuff = Buff.new()
    do
        local thistype = EmpyreanSongBuff
        thistype.NAME            = "Empyrean Song"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTribal Drum of War.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 150
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class BloodHornBuff : Buff
    BloodHornBuff = Buff.new()
    do
        local thistype = BloodHornBuff
        thistype.NAME            = "Blood Horn"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNUnholyAura.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 75
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class ResurgenceBuff : Buff
    ResurgenceBuff = Buff.new()
    do
        local thistype = ResurgenceBuff
        thistype.NAME            = "Resurgence"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDarkShield.blp"
        thistype.DESC            = "This unit has +!$regen% max health regeneration"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local max_hp = Unit[self.target].hp
            local hp = math.min(5, (((max_hp - GetWidgetLife(self.target)) / max_hp) * 100.) // 15.)

            Unit[self.target].regen_max = Unit[self.target].regen_max - self.regen
            self.regen = self.item.cached_stats[ITEM_ABILITY] * hp
            self.charges = R2I(hp)
            Unit[self.target].regen_max = Unit[self.target].regen_max + self.regen
            self.timer = TQ:callDelayed(0.5, periodic, self)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].regen_max = Unit[self.target].regen_max - (self.regen or 0)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.regen = 0
            self.hp = 0
            periodic(self)
        end
    end

    ---@class AzazothHammerStomp : Buff
    AzazothHammerStomp = Buff.new()
    do
        local thistype = AzazothHammerStomp
        thistype.NAME            = "Stomp"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNThunderclap.blp"
        thistype.DESC            = "This unit has -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.35
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", "overhead")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

    ---@class InstillFearDebuff : Buff
    InstillFearDebuff = Buff.new()
    do
        local thistype = InstillFearDebuff
        thistype.NAME            = "Instill Fear"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDagger.blp"
        thistype.DESC            = "This unit takes +^$dm% total damage from the afflicter"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_FULL

        local function onStruck(target, source, amount, amount_after_red, damage_type)
            if thistype:has(source, target) then
                amount.value = amount.value * 1.15
            end
        end

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, onStruck)
        end

        function thistype:onApply()
            self.dm = 0.15
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\NightElf\\shadowstrike\\shadowstrike.mdl", "overhead")

            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, onStruck)
        end
    end

    ---@class DarkestOfDarknessBuff : Buff
    DarkestOfDarknessBuff = Buff.new()
    do
        local thistype = DarkestOfDarknessBuff
        thistype.NAME            = "Darkest of Darkness"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEradication.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.7
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\SoulArmor.mdx", "chest")

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class VampiricPotion : Buff
    VampiricPotion = Buff.new()
    do
        local thistype = VampiricPotion
        thistype.NAME            = "Vampiric Potion"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNPotionOfVampirism.blp"
        thistype.DESC            = "This unit restores +^$leech% of damage dealt as health"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target, amount, amount_after_red)
            local buff = thistype:get(nil, source)
            if buff then
                HP(source, source, amount_after_red * buff.leech, "Vampiric Potion")
                DestroyEffect(AddSpecialEffectTarget(
                    "war3mapImported\\VampiricAuraTarget.mdx", source, "chest"))
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.leech = self.leech or 0.05
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Items\\VampiricPotion\\VampPotionCaster.mdl", "origin")
        end
    end

    ---@class StonebloodFlaskBuff : Buff
    StonebloodFlaskBuff = Buff.new()
    do
        local thistype = StonebloodFlaskBuff
        thistype.NAME            = "Stoneblood"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNgreenEApotionGS.blp"
        thistype.DESC            = "This unit has +^#dr% damage resistance"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.85
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class TempestFlaskBuff : Buff
    TempestFlaskBuff = Buff.new()
    do
        local thistype = TempestFlaskBuff
        thistype.NAME            = "Tempest"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNManaPotion.blp"
        thistype.DESC            = "Ability cooldowns recover +^$rate% faster"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            CooldownAcceleration.remove(self.target)
        end

        function thistype:onApply()
            self.rate = 1.
        end
    end

    ---@class FuryFlaskBuff : Buff
    FuryFlaskBuff = Buff.new()
    do
        local thistype = FuryFlaskBuff
        thistype.NAME = "Fury Infusion"
        thistype.ICON = "ReplaceableTextures\\CommandButtons\\BTNredEApotionGS.blp"
        thistype.DESC = "This unit has +^$damage% total damage"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / (1. + self.damage)
        end

        function thistype:onApply() self.damage = 0. end
    end

    ---@class ArcaneFlaskBuff : Buff
    ArcaneFlaskBuff = Buff.new()
    do
        local thistype = ArcaneFlaskBuff
        thistype.NAME = "Arcane Infusion"
        thistype.ICON = "ReplaceableTextures\\CommandButtons\\BTNpurpleEApotionGS.blp"
        thistype.DESC = "This unit has +^$spellboost% Spell Power"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost -
                                               self.spellboost
        end

        function thistype:onApply() self.spellboost = 0. end
    end

    ---@class SwiftnessFlaskBuff : Buff
    SwiftnessFlaskBuff = Buff.new()
    do
        local thistype = SwiftnessFlaskBuff
        thistype.NAME = "Swiftness Infusion"
        thistype.ICON = "ReplaceableTextures\\CommandButtons\\BTNblueEApotionGS.blp"
        thistype.DESC = "This unit has +^$movespeed% movement speed"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent -
                                               self.movespeed
        end

        function thistype:onApply() self.movespeed = 0. end
    end

    ---@class PurityFlaskBuff : Buff
    PurityFlaskBuff = Buff.new()
    do
        local thistype = PurityFlaskBuff
        thistype.NAME = "Purity Infusion"
        thistype.ICON = "ReplaceableTextures\\CommandButtons\\BTNnoEApotionGS.blp"
        thistype.DESC = "This unit has +$status_resist% Status Resistance"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].status_resist_flat =
                Unit[self.target].status_resist_flat - self.status_resist
        end

        function thistype:onApply() self.status_resist = 0. end
    end

    ---@class OmniscienceFlaskBuff : Buff
    OmniscienceFlaskBuff = Buff.new()
    do
        local thistype = OmniscienceFlaskBuff
        thistype.NAME = "Omniscience Infusion"
        thistype.ICON =
            "ReplaceableTextures\\CommandButtons\\BTNPotionOfOmniscience.blp"
        thistype.DESC = "This unit has +$crit% Critical Chance and +$crit_damage% Critical Damage"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            local unit = Unit[self.target]
            unit.cc_flat = unit.cc_flat - self.crit
            unit.cd_flat = unit.cd_flat - self.crit_damage
        end

        function thistype:onApply()
            self.crit = 0.
            self.crit_damage = 0.
        end
    end

    ---@class FrenzyFlaskBuff : Buff
    FrenzyFlaskBuff = Buff.new()
    do
        local thistype = FrenzyFlaskBuff
        thistype.NAME = "Frenzy Infusion"
        thistype.ICON = "ReplaceableTextures\\CommandButtons\\BTNStrongDrink.blp"
        thistype.DESC = "This unit attacks +^$attack_speed% faster"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat *
                                               (1. + self.attack_speed)
        end

        function thistype:onApply() self.attack_speed = 0. end
    end

    ---@class PhasingFlaskBuff : Buff
    PhasingFlaskBuff = Buff.new()
    do
        local thistype = PhasingFlaskBuff
        thistype.NAME = "Phasing Infusion"
        thistype.ICON =
            "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp"
        thistype.DESC = "This unit has +$evasion% Evasion"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].evasion = Unit[self.target].evasion - self.evasion
        end

        function thistype:onApply() self.evasion = 0. end
    end

    ---@class CorrosiveFlaskDebuff : Buff
    CorrosiveFlaskDebuff = Buff.new()
    do
        local thistype = CorrosiveFlaskDebuff
        thistype.NAME = "Corroded"
        thistype.ICON =
            "ReplaceableTextures\\CommandButtons\\BTNAcidFlask3.blp"
        thistype.DESC = "This unit has -^$armor% armor"
        thistype.DISPEL_TYPE = BUFF_NEGATIVE
        thistype.STACK_TYPE = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].armor_percent =
                Unit[self.target].armor_percent + self.armor
        end

        function thistype:onApply() self.armor = 0. end
    end

    ---@class CorrosiveFlaskBuff : Buff
    CorrosiveFlaskBuff = Buff.new()
    do
        local thistype = CorrosiveFlaskBuff
        thistype.NAME = "Corrosive Infusion"
        thistype.ICON =
            "ReplaceableTextures\\CommandButtons\\BTNAcidFlask3.blp"
        thistype.DESC = "Attacks reduce enemy armor by +^$armor%"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        local function on_hit(source, target, is_basic_attack)
            local buff = thistype:get(nil, source)
            if not buff or not is_basic_attack then return end

            local debuff = CorrosiveFlaskDebuff:add(source, target)
            local previous = debuff.armor or 0.
            local armor = math.max(previous, buff.armor)
            Unit[target].armor_percent = Unit[target].armor_percent +
                                             previous - armor
            debuff.armor = armor
            debuff:duration(4.)
            UnitRefreshBuff(target, debuff)
        end

        function thistype:onRemove()
            EVENT_ON_HIT:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            self.armor = 0.15
            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
        end
    end

    ---@class VoltaicFlaskBuff : Buff
    VoltaicFlaskBuff = Buff.new()
    do
        local thistype = VoltaicFlaskBuff
        thistype.NAME = "Voltaic Infusion"
        thistype.ICON =
            "ReplaceableTextures\\CommandButtons\\BTNLightningSpeedBottle.blp"
        thistype.DESC = "Attacks arc +^$damage% damage to nearby enemies"
        thistype.DISPEL_TYPE = BUFF_POSITIVE
        thistype.STACK_TYPE = BUFF_STACK_NONE

        local function on_hit(source, primary, _amount, amount_after_reduction,
                              _damage_type, attack_amount, is_basic_attack)
            local buff = thistype:get(nil, source)
            if not buff or not is_basic_attack or
                amount_after_reduction <= 0. or not attack_amount or
                attack_amount <= 0. then return end

            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local group = CreateGroup()
            MakeGroupInRange(pid, group, GetUnitX(primary), GetUnitY(primary),
                             350., Condition(FilterEnemy))
            local struck = 0
            for target in each(group) do
                if target ~= primary and struck < 4 then
                    struck = struck + 1
                    DamageTarget(source, target, attack_amount * buff.damage,
                                 ATTACK_TYPE_NORMAL, MAGIC, "Voltaic Flask", {
                            attack = false,
                            pre_scaled_source = true,
                            suppress_source_events = true,
                        })
                    DestroyEffect(AddSpecialEffectTarget(
                        "Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl",
                        target, "origin"))
                end
            end
            DestroyGroup(group)
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target,
                                                                 on_hit)
        end

        function thistype:onApply()
            self.damage = 0.40
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target,
                                                               on_hit)
        end
    end

    ---@class IntenseFocusBuff : Buff
    IntenseFocusBuff = Buff.new()
    do
        local thistype = IntenseFocusBuff
        thistype.NAME            = "Intense Focus"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTrueShot.blp"
        thistype.DESC            = "This unit has +^#mult% total damage"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

       local function periodic(self)
            if UnitAlive(self.target) and
                Unit[self.target].x == GetUnitX(self.target) and
                Unit[self.target].y == GetUnitY(self.target)
            then
                self.charges = math.min(10, self.charges + 1)
                Unit[self.target].dm = Unit[self.target].dm / self.mult
                self.mult = 1. + self.charges * 0.01
                Unit[self.target].dm = Unit[self.target].dm * self.mult
            else
                Unit[self.target].dm = Unit[self.target].dm / self.mult
                self.mult = 1.
                self.charges = 0
            end
            UnitRefreshBuff(self.target, self)
            self.timer = TQ:callDelayed(1, periodic, self)
        end

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.mult
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.charges = 0
            self.mult = 1.
            self.timer = TQ:callDelayed(1, periodic, self)
        end
    end

end, Debug and Debug.getLine())
