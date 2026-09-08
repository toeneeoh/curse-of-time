OnInit.final("BuffsWorldColosseum", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local valid_damage_target = VALID_DAMAGE_TARGET

    ---@class EarthquakeDebuff : Buff
    EarthquakeDebuff = Buff.new()
    do
        local thistype = EarthquakeDebuff
        thistype.NAME            = "Earthquake"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$regen% regeneration"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEarthquake.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.regen
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\EarthQuake\\EarthQuakeTarget.mdl", "origin")
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))
            self.regen = 0.5

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].regen_percent = Unit[self.target].regen_percent - self.regen
        end
    end

    ---@class DefensiveBubbleBuff : Buff
    DefensiveBubbleBuff = Buff.new()
    do
        local thistype = DefensiveBubbleBuff
        thistype.NAME            = "Defensive Bubble"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNLightningShield.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.7
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class AttributeExpertBuff : Buff
    AttributeExpertBuff = Buff.new()
    do
        local thistype = AttributeExpertBuff
        thistype.NAME            = "Attribute Expert"
        thistype.DESC            = "This unit has +$bonus bonus $stat"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNStatUp.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]["bonus_"..self.main] = Unit[self.target]["bonus_"..self.main] - self.bonus
        end

        function thistype:onApply()
            self.main = HighestStatName(self.target)
            self.bonus = 0.75 * Unit[self.target][self.main]
            self.stat = HighestStatName(self.target, true)

            Unit[self.target]["bonus_"..self.main] = Unit[self.target]["bonus_"..self.main] + self.bonus
        end
    end

    ---@class SpeedDemonBuff : Buff
    SpeedDemonBuff = Buff.new()
    do
        local thistype = SpeedDemonBuff
        thistype.NAME            = "Speed Demon"
        thistype.DESC            = "This unit always has $ms movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            Unit[self.target].overmovespeed = self.ms
            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onRemove()
            Unit[self.target].overmovespeed = nil
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.ms = 600
            periodic(self)
        end
    end

    ---@class RadianceBuff : Buff
    RadianceBuff = Buff.new()
    do
        local thistype = RadianceBuff
        thistype.NAME            = "Radiance"
        thistype.DESC            = "This unit deals $dmg magic damage every second in a 900 AoE"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTransmute.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function damage_target(target, source, dmg)
            DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, "Radiance")
        end

        local function periodic(self)
            if not self.active then
                return
            end

            self.callback = nil
            local x, y = GetUnitX(self.target), GetUnitY(self.target)
            self.dmg = GetHeroStat(HighestStat(self.target, true), self.target, true)
            ALICE_ForAllObjectsInRangeDo(damage_target, x, y, 900., "unit", valid_damage_target, self.target, self.dmg)

            -- Damage callbacks can synchronously end the Colosseum and remove this
            -- buff. Do not let the currently executing tick revive its timer chain.
            if self.active then
                self.callback = TQ:callDelayed(1., periodic, self)
            end
        end

        function thistype:onRemove()
            self.active = false
            Unit[self.target]:removeEffect(self.sfx)
            if self.callback then
                TQ:disableCallback(self.callback)
                self.callback = nil
            end
        end

        function thistype:onApply()
            self.active = true
            self.sfx = Unit[self.target]:addEffect("spinning fire.mdl", "origin")
            periodic(self)
        end
    end

    ---@class BattleTranceBuff : Buff
    BattleTranceBuff = Buff.new()
    do
        local thistype = BattleTranceBuff
        thistype.NAME            = "Battle Trance"
        thistype.DESC            = "This unit has +^$attack% attack damage and +^$spellboost% Spellboost"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodLust.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            local unit = Unit[self.target]
            unit.damage_percent = unit.damage_percent - self.attack
            unit.spellboost = unit.spellboost - self.spellboost
        end

        function thistype:onApply()
            local unit = Unit[self.target]
            self.attack = 0.25
            self.spellboost = 0.25
            unit.damage_percent = unit.damage_percent + self.attack
            unit.spellboost = unit.spellboost + self.spellboost
        end
    end

    ---@class BloodsportBuff : Buff
    BloodsportBuff = Buff.new()
    do
        local thistype = BloodsportBuff
        thistype.NAME            = "Bloodsport"
        thistype.DESC            = "Killing an enemy restores ^$restore% Max Health and Max Mana"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNVampiricAura.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_kill(source)
            local self = thistype:get(nil, source)
            if self then
                HP(source, source, BlzGetUnitMaxHP(source) * self.restore, thistype.NAME)
                MP(source, BlzGetUnitMaxMana(source) * self.restore)
            end
        end

        function thistype:onRemove()
            EVENT_ON_KILL:unregister_unit_action(self.target, on_kill)
        end

        function thistype:onApply()
            self.restore = 0.03
            EVENT_ON_KILL:register_unit_action(self.target, on_kill)
        end
    end

    ---@class ColossusSlayerBuff : Buff
    ColossusSlayerBuff = Buff.new()
    do
        local thistype = ColossusSlayerBuff
        local COLOSSEUM_BOSS_ID = FourCC('N003')
        thistype.NAME            = "Colossus Slayer"
        thistype.DESC            = "This unit deals +^$damage% damage to Colosseum bosses"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCriticalStrike.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(source, target, amount)
            local self = thistype:get(nil, source)
            if self and GetUnitTypeId(target) == COLOSSEUM_BOSS_ID then
                amount.value = amount.value * (1. + self.damage)
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT_MULTIPLIER:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            self.damage = 0.35
            EVENT_ON_HIT_MULTIPLIER:register_unit_action(self.target, on_hit)
        end
    end

    ---@class FleetFootedBuff : Buff
    FleetFootedBuff = Buff.new()
    do
        local thistype = FleetFootedBuff
        thistype.NAME            = "Fleet-Footed"
        thistype.DESC            = "This unit has +^$ms% movespeed and +$evasion% evasion"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            local unit = Unit[self.target]
            unit.ms_percent = unit.ms_percent - self.ms
            unit.evasion = unit.evasion - self.evasion
        end

        function thistype:onApply()
            local unit = Unit[self.target]
            self.ms = 0.2
            self.evasion = 15
            unit.ms_percent = unit.ms_percent + self.ms
            unit.evasion = unit.evasion + self.evasion
        end
    end

end, Debug and Debug.getLine())
