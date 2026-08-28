OnInit.final("BuffsHeroesBard", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class InspireBuff : Buff
    InspireBuff = Buff.new()
    do
        local thistype = InspireBuff
        thistype.NAME            = "Inspired"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBearBlink.blp"
        thistype.DESC            = "This unit has +^$spellboost% spellboost"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        end

        function thistype:onApply()
            self.spellboost = (0.08 + 0.02 * self.ablev)
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        end
    end

    ---@class SongOfWarBuff : Buff
    SongOfWarBuff = Buff.new()
    do
        local thistype = SongOfWarBuff
        thistype.NAME            = "Song of War"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfWar.blp"
        thistype.DESC            = "This unit has +^$attack% attack damage"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.attack
        end

        function thistype:onApply()
            self.attack = 0.2
            Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.attack
        end
    end

    ---@class SongOfHarmonyBuff : Buff
    SongOfHarmonyBuff = Buff.new()
    do
        local thistype = SongOfHarmonyBuff
        thistype.NAME            = "Song of Harmony"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfHarmony.blp"
        thistype.DESC            = "This unit has +$regen% max health regeneration"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].regen_max = Unit[self.target].regen_max - self.regen
        end

        function thistype:onApply()
            self.regen = 1
            Unit[self.target].regen_max = Unit[self.target].regen_max + self.regen
        end
    end

    ---@class SongOfPeaceBuff : Buff
    SongOfPeaceBuff = Buff.new()
    do
        local thistype = SongOfPeaceBuff
        thistype.NAME            = "Song of Peace"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfPeace.blp"
        thistype.DESC            = "This unit has +$regen% max mana regeneration"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max - self.regen
        end

        function thistype:onApply()
            self.regen = 1
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max + self.regen
        end
    end

    ---@class SongOfPeaceEncoreBuff : Buff
    SongOfPeaceEncoreBuff = Buff.new()
    do
        local thistype = SongOfPeaceEncoreBuff
        thistype.NAME            = "Encore (Song of Peace)"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfPeace.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", "origin")
            self.dr = 0.8

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class SongOfWarEncoreBuff : Buff
    SongOfWarEncoreBuff = Buff.new()
    do
        local thistype = SongOfWarEncoreBuff
        thistype.NAME            = "Encore (Song of War)"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfWar.blp"
        thistype.DESC            = "This unit deals $dmg extra magic damage on attacks"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(source, target)
            local self = SongOfWarEncoreBuff:get(nil, source)

            if self then
                self.count = self.count - 1
                DamageTarget(self.source, target, self.dmg * BOOST[GetPlayerId(GetOwningPlayer(self.source)) + 1], ATTACK_TYPE_NORMAL, MAGIC, ENCORE.tag)

                if self.count <= 0 then
                    self:remove()
                end
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT:unregister_unit_action(self.target, on_hit)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
            self.dmg = (.25 + .25 * GetUnitAbilityLevel(self.source, ENCORE.id)) * GetHeroStat(MainStat(self.target), self.target, true)
            self.count = 10

            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Items\\VampiricPotion\\VampPotionCaster.mdl", "origin")
        end
    end

    ---@class SongOfFatigueSlow : Buff
    SongOfFatigueSlow = Buff.new()
    do
        local thistype = SongOfFatigueSlow
        thistype.NAME            = "Song of Fatigue"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBardMusicSongOfSleep.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.3
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Human\\slow\\slowtarget.mdl", "origin")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

end, Debug and Debug.getLine())
