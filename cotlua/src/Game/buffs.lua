--[[
    buffs.lua

    A module that contains most of the triggered buffs and debuffs in the game.
]]

OnInit.global("Buffs", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32
    local atan = math.atan
    local valid_damage_target = VALID_DAMAGE_TARGET
    local valid_pull_target = VALID_PULL_TARGET
    local PHASED_MOVEMENT = FourCC('I0OE')

    ---@class Disarm : Buff
    Disarm = Buff.new()
    do
        local thistype = Disarm
        thistype.NAME            = "Disarmed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEmptyHand.BLP"
        thistype.DESC            = "This unit cannot attack"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].attack = true
        end

        function thistype:onApply()
            Unit[self.target].attack = false
        end
    end

    ---@class Silence : Buff
    Silence = Buff.new()
    do
        local thistype = Silence
        thistype.NAME            = "Silenced"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSilence.blp"
        thistype.DESC            = "This unit cannot cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            DestroyEffect(self.sfx)
            ToggleCommandCard(self.target, true)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\Silence\\SilenceTarget.mdl", self.target, "overhead")
            ToggleCommandCard(self.target, false)
        end
    end

    ---@class Fear : Buff
    Fear = Buff.new()
    do
        local thistype = Fear
        thistype.NAME            = "Feared"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGuldanSkull.blp"
        thistype.DESC            = "This unit is moving uncontrollably"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_order(source, target, id)
            local b = Fear:get(nil, source)

            -- reissue movement order to feared units
            if b then
                IssuePointOrder(source, "move", b.x, b.y)
            end
        end

        function thistype:onRemove()
            UnitRemoveAbility(self.target, FourCC('ARal'))
            ToggleCommandCard(self.target, true)
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(self.target, FourCC("AInv")), ConvertAbilityIntegerLevelField(FourCC('inv5')), 0, 1)

            Unit[self.target].attack = true
            EVENT_ON_ORDER:unregister_unit_action(self.target, on_order)
        end

        function thistype:onApply()
            local angle = atan(GetUnitY(self.target) - GetUnitY(self.source), GetUnitX(self.target) - GetUnitX(self.source)) ---@type number 
            self.x = GetUnitX(self.target) + 2000. * math.cos(angle)
            self.y = GetUnitY(self.target) + 2000. * math.sin(angle)

            IssuePointOrder(self.target, "move", self.x, self.y)
            ToggleCommandCard(self.target, false)
            UnitAddAbility(self.target, FourCC('ARal'))
            BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(self.target, FourCC("AInv")), ConvertAbilityIntegerLevelField(FourCC('inv5')), 0, 0)
            EVENT_ON_ORDER:register_unit_action(self.target, on_order)
        end
    end

    ---@class Lava : Buff
    Lava = Buff.new()
    do
        local thistype = Lava
        thistype.NAME            = "Lava"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNLavaSpawn.blp"
        thistype.DESC            = "This unit is burning"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            if not IsUnitInRegion(LAVA_REGION, self.target) then
                self:remove()
            else
                local dmg = BlzGetUnitMaxHP(self.target) / 40. + 1000.

                if BlzGetUnitZ(self.target) < 60. then
                    DamageTarget(DUMMY_UNIT, self.target, dmg, ATTACK_TYPE_NORMAL, PURE, "Lava")
                end

                self.timer = TQ:callDelayed(0.5, periodic, self)
            end
        end

        function thistype:onRemove()
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.timer = TQ:callDelayed(0.5, periodic, self)
        end
    end

    ---@class BurningDebuff : Buff
    BurningDebuff = Buff.new()
    do
        local thistype = BurningDebuff
        thistype.NAME            = "Burning"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSearingArrows.blp"
        thistype.DESC            = "This unit is afflicted by Searing Arrows"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
    end

    ---@class IgniteDebuff : Buff
    IgniteDebuff = Buff.new()
    do
        local thistype = IgniteDebuff
        thistype.NAME            = "Ignited"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWallOfFire.blp"
        thistype.DESC            = "This unit is taking $dmg every second"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function periodic(self)
            DamageTarget(self.source, self.target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, SEARINGARROWS.tag)

            self.callback = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onRemove()
            TQ:disableCallback(self.callback)

            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Real Fire2.mdx", self.target, "origin")
            self.dmg = SEARINGARROWS.dot(self.pid)

            self.callback = TQ:callDelayed(0.5, periodic, self)
        end
    end

    ---@class InfusedWaterBuff : Buff
    InfusedWaterBuff = Buff.new()
    do
        local thistype = InfusedWaterBuff
        thistype.NAME            = "Infused Water"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInfusedWater2.blp"
        thistype.DESC            = "This unit has +$ms movespeed and next spell cast is empowered"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 150
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

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

    ---@class ArcaneBarrageBuff : Buff
    ArcaneBarrageBuff = Buff.new()
    do
        local thistype = ArcaneBarrageBuff
        thistype.NAME            = "Arcane Barrage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneStorm2.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 150
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class OmnislashBuff : Buff
    OmnislashBuff = Buff.new()
    do
        local thistype = OmnislashBuff
        thistype.NAME            = "Omnislash"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNOmnislash5.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function periodic(self, override)
            if self.charges > 0 then
                self.charges = self.charges - 1
                local x, y = GetUnitX(self.target), GetUnitY(self.target)
                MakeGroupInRange(self.pid, self.ug, x, y, 600., Condition(FilterEnemy))

                local target
                if override then
                    target = override
                else
                    target = FirstOfGroup(self.ug)
                end

                if target then
                    local facing = GetUnitFacing(target)
                    SetUnitAnimation(self.target, "Attack Slam")
                    SetUnitXBounded(self.target, GetUnitX(target) + 60. * math.cos(bj_DEGTORAD * (facing - 180.)))
                    SetUnitYBounded(self.target, GetUnitY(target) + 60. * math.sin(bj_DEGTORAD * (facing - 180.)))
                    BlzSetUnitFacingEx(self.target, facing)
                    DamageTarget(self.target, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, OMNISLASH.tag)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", self.target, "chest"))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\Bolt\\BoltImpact.mdl", target, "chest"))
                else
                    self.charges = 0
                end

                UnitRefreshBuff(self.target, self)

                if self.charges <= 0 then
                    self:remove()
                else
                    self.callback = TQ:callDelayed(0.4, periodic, self)
                end
            end
        end

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr

            TQ:disableCallback(self.callback)
            DestroyGroup(self.ug)
            reselect(self.target)
            SetUnitVertexColor(self.target, 255, 255, 255, 255)
            SetUnitTimeScale(self.target, 1.)
        end

        function thistype:onApply()
            self.dr = 0.2
            self.ug = CreateGroup()
            Unit[self.target].dr = Unit[self.target].dr * self.dr

            periodic(self, self.override)
        end
    end

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
            DestroyEffect(self.sfx)

            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", self.target, "origin")
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
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
            self.dmg = (.25 + .25 * GetUnitAbilityLevel(self.source, ENCORE.id)) * GetHeroStat(MainStat(self.target), self.target, true)
            self.count = 10

            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Items\\VampiricPotion\\VampPotionCaster.mdl", self.target, "origin")
        end
    end

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

    ---@class FlamingBowBuff : Buff
    FlamingBowBuff = Buff.new()
    do
        local thistype = FlamingBowBuff
        thistype.NAME            = "Flaming Bow"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInnerFire.blp"
        thistype.DESC            = "This unit has +^$attack% attack damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target)
            local self = FlamingBowBuff:get(nil, source)
            local increase = 0.01

            if self.attack < self.max then
                if MULTISHOT.enabled[source] then
                    increase = increase / (1. + GetUnitAbilityLevel(self.target, MULTISHOT.id))
                end

                Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.attack
                self.attack = math.min(self.attack + increase, self.max)
                Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.attack
                UnitRefreshBuff(source, self)
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT:unregister_unit_action(self.target, on_hit)
            DestroyEffect(self.sfx)
            UnitRemoveAbility(self.target, FourCC('A08B'))
            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.attack
        end

        function thistype:onApply()
            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
            self.attack = 0.5
            self.max = 0.8 + 0.02 * GetUnitAbilityLevel(self.target, FLAMINGBOW.id)

            Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.attack
            self.sfx = AddSpecialEffectTarget("Environment\\SmallBuildingspeffect\\SmallBuildingspeffect2.mdl", self.target, "weapon")
            UnitAddAbility(self.target, FourCC('A08B'))
        end
    end

    ---@class StasisFieldDebuff : Buff
    StasisFieldDebuff = Buff.new()
    do
        local thistype = StasisFieldDebuff
        thistype.NAME            = "Stasis Field"
        thistype.DESC            = "This unit cannot move"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneBarrier2.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            SetUnitPropWindow(self.target, bj_DEGTORAD * 60.)
            SetUnitPathing(self.target, true)
        end

        function thistype:onApply()
            SetUnitPropWindow(self.target, 0)
        end
    end

    ---@class ArcanosphereDebuff : Buff
    ArcanosphereDebuff = Buff.new()
    do
        local thistype = ArcanosphereDebuff
        thistype.NAME            = "Arcanosphere"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpaceTimeWarp.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.75 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

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
            DestroyEffect(self.sfx)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.regen
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\EarthQuake\\EarthQuakeTarget.mdl", self.target, "origin")
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
            local x, y = GetUnitX(self.target), GetUnitY(self.target)
            self.dmg = GetHeroStat(HighestStat(self.target, true), self.target, true)
            ALICE_ForAllObjectsInRangeDo(damage_target, x, y, 900., "unit", valid_damage_target, self.target, self.dmg)
            self.callback = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onRemove()
            DestroyEffect(self.sfx)
            TQ:disableCallback(self.callback)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("spinning fire.mdl", self.target, "origin")
            periodic(self)
        end
    end

    ---@class ArcanosphereBuff : Buff
    ArcanosphereBuff = Buff.new()
    do
        local thistype = ArcanosphereBuff
        thistype.NAME            = "Arcanosphere"
        thistype.DESC            = "This unit always has $ms movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpaceTimeWarp.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].overmovespeed = nil
        end

        function thistype:onApply()
            self.ms = 1000
            Unit[self.target].overmovespeed = self.ms
        end
    end

    ---@class MarkedForDeathDebuff : Buff
    MarkedForDeathDebuff = Buff.new()
    do
        local thistype = MarkedForDeathDebuff
        thistype.NAME            = "Marked for Death"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSacrificialSkull.blp"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            SetUnitPathing(self.target, true)

            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms

            BlzSetSpecialEffectScale(self.sfx, 0)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            SetUnitPathing(self.target, false)

            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Human\\Banish\\BanishTarget.mdl", self.target, "chest")

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class FightMeBuff : Buff
    FightMeBuff = Buff.new()
    do
        local thistype = FightMeBuff
        thistype.NAME            = "Fight Me"
        thistype.DESC            = "This unit is immune to damage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWarCry.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(target, source, amount_ref)
            local pid = GetPlayerId(GetOwningPlayer(target)) + 1

            if target == Hero[pid] then
                amount_ref.value = 0.
            end
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, on_hit)
        end
    end

    ---@class FightMeCasterBuff : Buff
    FightMeCasterBuff = Buff.new()
    do
        local thistype = FightMeCasterBuff
        thistype.NAME            = "Fight Me"
        thistype.DESC            = "This unit gives nearby allies damage immunity"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWarCry.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            TQ:disableCallback(self.timer)
            DestroyEffect(self.sfx)
            DestroyGroup(self.ug)
        end

        local function periodic(self)
            MakeGroupInRange(self.pid, self.ug, GetUnitX(self.source), GetUnitY(self.source), 900. * LBOOST[self.pid], Condition(FilterAlly))

            for target in each(self.ug) do
                if target ~= self.source then
                    FightMeBuff:add(self.source, target):duration(2.)
                end
            end

            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Voodoo\\VoodooAura.mdl", self.target, "origin")
            self.ug = CreateGroup()

            periodic(self)
        end
    end

    ---@class RoyalPlateBuff : Buff
    RoyalPlateBuff = Buff.new()
    do
        local thistype = RoyalPlateBuff
        thistype.NAME            = "Royal Plate"
        thistype.DESC            = "This unit has +$armor armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArmor Gold.blp"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor - self.armor
        end

        function thistype:onApply()
            self.armor = ROYALPLATE.armor(self.tpid) * BOOST[self.tpid]

            if Unit[self.target].shield_count > 0 then
                self.armor = self.armor * 1.3
            end

            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor + self.armor
        end
    end

    ---@class ProvokeDebuff : Buff
    ProvokeDebuff = Buff.new()
    do
        local thistype = ProvokeDebuff
        thistype.NAME            = "Provoked"
        thistype.DESC            = "This unit deals -^#dm% total damage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInnerFire.blp"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.dm
        end

        function thistype:onApply()
            self.dm = 0.75
            Unit[self.target].dm = Unit[self.target].dm * self.dm
        end
    end

    ---@class DemonicSacrificeBuff : Buff
    DemonicSacrificeBuff = Buff.new()
    do
        local thistype = DemonicSacrificeBuff
        thistype.NAME            = "Demonic Sacrifice"
        thistype.DESC            = "This unit has +^$spellboost% spellboost"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTurnUndead.blp"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        end

        function thistype:onApply()
            self.spellboost = 0.15
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        end
    end

    ---@class JusticeAuraBuff : Buff
    JusticeAuraBuff = Buff.new()
    do
        local thistype = JusticeAuraBuff
        thistype.NAME            = "Aura of Justice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDevotionAura2.blp"
        thistype.DESC            = "This unit has +^#pr% physical resistance"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].pr = Unit[self.target].pr / self.pr
        end

        function thistype:onApply()
            self.pr = math.max(0.91 - 0.01 * self.ablev, 0.85)

            Unit[self.target].pr = Unit[self.target].pr * self.pr
        end
    end

    ---@class SoulLinkBuff : Buff
    SoulLinkBuff = Buff.new()
    do
        local thistype = SoulLinkBuff
        thistype.NAME            = "Soul Link"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpiritLink.blp"
        thistype.DESC            = "This unit's health and mana will be restored"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(self.target, SOULLINK.onHit)
            FadeSFX(self.sfx, true)
            TQ:callDelayed(2., HideEffect, self.sfx)
            DestroyLightning(self.lfx)

            HP(self.source, self.target, math.max(0., self.hp - GetWidgetLife(self.target)), SOULLINK.tag)
            if not Unit[self.target].nomanaregen then
                MP(self.target, math.max(0., self.mana - GetUnitState(self.target, UNIT_STATE_MANA)))
            end

            TQ:disableCallback(self.timer)
        end

        local function periodic(self, x, y)
            MoveLightningEx(self.lfx, false, x, y, BlzGetUnitZ(self.target) + 75., GetUnitX(self.target), GetUnitY(self.target), BlzGetUnitZ(self.target) + 75.)

            self.timer = TQ:callDelayed(FPS_32, periodic, self, x, y)
        end

        function thistype:onApply()
            local angle  = math.rad(GetUnitFacing(self.target) - 180) ---@type number 
            local x      = GetUnitX(self.target) + 75. * math.cos(angle) ---@type number 
            local y      = GetUnitY(self.target) + 75. * math.sin(angle) ---@type number 

            EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, SOULLINK.onHit)
            self.hp = GetWidgetLife(self.target)
            self.mana = GetUnitState(self.target, UNIT_STATE_MANA)

            BlzSetItemSkin(PATH_ITEM, BlzGetUnitSkin(self.target))
            self.sfx = AddSpecialEffect(BlzGetItemStringField(PATH_ITEM, ITEM_SF_MODEL_USED), x, y)
            self.lfx = AddLightningEx("HCHA", false, x, y, BlzGetUnitZ(self.target) + 75., GetUnitX(self.target), GetUnitY(self.target), BlzGetUnitZ(self.target) + 75.)
            BlzSetItemSkin(PATH_ITEM, BlzGetUnitSkin(DUMMY_UNIT))

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Items\\AIil\\AIilTarget.mdl", x, y))

            BlzSetSpecialEffectYaw(self.sfx, angle + bj_PI)
            BlzSetSpecialEffectColorByPlayer(self.sfx, GetOwningPlayer(self.target))
            BlzSetSpecialEffectColor(self.sfx, 255, 255, 0)
            BlzSetSpecialEffectAlpha(self.sfx, 100)

            self.timer = TQ:callDelayed(FPS_32, periodic, self, x, y)
        end
    end

    ---@class LawOfMightBuff : Buff
    LawOfMightBuff = Buff.new()
    do
        local thistype = LawOfMightBuff
        thistype.NAME            = "Law of Might"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneMight2.blp"
        thistype.DESC            = "This unit has +$bonus $attr"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            DestroyEffect(self.sfx)

            UnitAddBonus(self.target, self.main + 2, -self.bonus)
        end

        function thistype:onApply()
            self.main = HighestStat(self.target, true)
            self.attr = HighestStatName(self.target, true, true)

            self.bonus = R2I(GetHeroStat(self.main, self.target, true) * LAWOFMIGHT.pbonus(self.pid) * 0.01 * LBOOST[self.pid] + LAWOFMIGHT.fbonus(self.pid) * BOOST[self.pid])
            UnitAddBonus(self.target, self.main + 2, self.bonus)

            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Human\\InnerFire\\InnerFireTarget.mdl", self.target, "overhead")
        end
    end

    ---@class LawOfValorBuff : Buff
    LawOfValorBuff = Buff.new()
    do
        local thistype = LawOfValorBuff
        thistype.NAME            = "Law of Valor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTN_CR_Favor.blp"
        thistype.DESC            = "This unit has +$regen regeneration and +$percent% healing"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            DestroyEffect(self.sfx)

            Unit[self.target].regen_flat = Unit[self.target].regen_flat - self.regen
            Unit[self.target].regen_percent = Unit[self.target].regen_percent - self.percent * 0.01
        end

        function thistype:onApply()
            self.regen = LAWOFVALOR.regen(self.pid) * BOOST[self.pid]
            self.percent = R2I(LAWOFVALOR.amp(self.pid))

            Unit[self.target].regen_flat = Unit[self.target].regen_flat + self.regen
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.percent * 0.01

            self.sfx = AddSpecialEffectTarget("war3mapImported\\RunicShield.mdx", self.target, "chest")
        end
    end

    ---@class LawOfResonanceBuff : Buff
    LawOfResonanceBuff = Buff.new()
    do
        local thistype = LawOfResonanceBuff
        thistype.NAME            = "Law of Resonance"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDuality.blp"
        thistype.DESC            = "This unit's attacks are echoed for ^$multiplier% damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target, amount, amount_after_red, damage_type)
            local self = thistype:get(nil, source)

            if damage_type == PHYSICAL then
                DamageTarget(source, target, amount_after_red * self.multiplier, ATTACK_TYPE_NORMAL, PURE, LAWOFRESONANCE.tag)
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
            self.multiplier = LAWOFRESONANCE.echo(self.pid) * 0.01

            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\Parasite\\ParasiteTarget.mdl", self.target, "overhead")
            BlzSetSpecialEffectColor(self.sfx, 60, 60, 255)
            BlzSetSpecialEffectTimeScale(self.sfx, 2.)
        end
    end

    ---@class OverloadBuff : Buff
    OverloadBuff = Buff.new()
    do
        local thistype = OverloadBuff
        thistype.NAME            = "Overload"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNOverloadOn1.blp"
        thistype.DESC            = "This unit has +^#mm% magic damage while draining mana"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local mana = GetUnitState(self.target, UNIT_STATE_MANA) ---@type number 
            local maxmana = BlzGetUnitMaxMana(self.target) * 0.02 ---@type number 

            if UnitAlive(self.target) and mana >= maxmana then
                SetUnitState(self.target, UNIT_STATE_MANA, mana - maxmana)
                self.timer = TQ:callDelayed(1., periodic, self)
            else
                self.timer = nil
                self:remove()
            end
        end

        function thistype:onRemove()
            Unit[self.target].mm = Unit[self.target].mm / self.mm
            IssueImmediateOrder(self.target, "unimmolation")
            DestroyEffect(self.sfx)

            if self.timer then
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Windwalk Blue Soul.mdx", self.target, "origin")
            self.mm = OVERLOAD.mult(self.pid)
            Unit[self.target].mm = Unit[self.target].mm * self.mm

            self.timer = TQ:callDelayed(1., periodic, self)
        end
    end

    ---@class BloodMistBuff : Buff
    BloodMistBuff = Buff.new()
    do
        local thistype = BloodMistBuff
        thistype.NAME            = "Blood Mist"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodOffering.blp"
        thistype.DESC            = "This unit has +$ms movespeed and is rapidly healing"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local blood = BLOODBANK.get(self.tpid)

            if blood >= BLOODMIST.cost(self.tpid) then
                BLOODBANK.add(self.tpid, -BLOODMIST.cost(self.tpid))
                HP(self.target, self.target, BLOODMIST.heal(self.tpid) * BOOST[self.tpid], BLOODMIST.tag)
                if self.ms == 0 then
                    self.ms = 50 + 50 * GetUnitAbilityLevel(self.source, BLOODMIST.id)
                    Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
                    PlayerAddItemById(self.tpid, PHASED_MOVEMENT)
                    BlzSetSpecialEffectColor(self.sfx, 255, 255, 255)
                end
            else
                Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
                self.ms = 0
                UnitRemoveAbility(self.target, FourCC('B02Q'))
                BlzSetSpecialEffectColor(self.sfx, 0, 0, 0)
            end

            self.timer = TQ:callDelayed(0.5, periodic, self)
        end

        function thistype:onRemove()
            DestroyEffect(self.sfx)

            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
            UnitRemoveAbility(self.target, FourCC('B02Q'))

            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            local ablev = GetUnitAbilityLevel(self.target, BLOODMIST.id)
            self.ms = 0

            if BLOODBANK.get(self.tpid) >= BLOODMIST.cost(self.tpid, ablev) then
                self.ms = 50 + 50 * GetUnitAbilityLevel(self.target, BLOODMIST.id)
                Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
            end

            self.sfx = AddSpecialEffectTarget("war3mapImported\\Chumpool.mdx", self.target, "origin")

            self.timer = TQ:callDelayed(0.5, periodic, self)
        end
    end

    ---@class BloodLordBuff : Buff
    BloodLordBuff = Buff.new()
    do
        local thistype = BloodLordBuff
        thistype.NAME            = "Blood Lord"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDarkHarvest.blp"
        thistype.DESC            = "This unit has +^#bat% base attack speed, +$bonus $stat, and deals extra magic damage on attacks"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            DamageTarget(source, target, BLOODLORD.dmg(pid) * BOOST[pid], ATTACK_TYPE_NORMAL, MAGIC, BLOODLORD.tag)
            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Coup de Grace.mdx", target, "chest"))
        end

        local function periodic(self)
            MakeGroupInRange(self.tpid, self.ug, GetUnitX(self.source), GetUnitY(self.source), 500. * LBOOST[self.tpid], Condition(FilterEnemy))

            if BlzGroupGetSize(self.ug) > 0 then
                DestroyEffect(AddSpecialEffectTarget("war3mapImported\\DarknessLeechTarget_Portrait.mdx", self.source, "origin"))
            end

            for target in each(self.ug) do
                BLOODBANK.add(self.tpid, BLOODLEECH.gain(self.tpid) / 3.)
                DamageTarget(self.source, target, BLOODLEECH.dmg(self.tpid) / 3. * BOOST[self.tpid], ATTACK_TYPE_NORMAL, MAGIC, BLOODLORD.tag)

                local dummy = Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A0A1'), 1)
                dummy:attack(self.source)
            end

            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onRemove()
            DestroyGroup(self.ug)
            EVENT_ON_HIT:unregister_unit_action(self.source, on_hit)

            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
            Unit[self.source].bonus_agi = Unit[self.source].bonus_agi - self.agi
            Unit[self.source].bonus_str = Unit[self.source].bonus_str - self.str

            if self.timer then
                UnitDisableAbility(self.source, BLOODLEECH.id, false)
                UnitDisableAbility(self.source, BLOODDOMAIN.id, false)
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            self.agi = 0
            self.str = 0
            EVENT_ON_HIT:register_unit_action(self.source, on_hit)

            if GetHeroAgi(self.source, true) > GetHeroStr(self.source, true) then
                self.stat = "Agility"
                UnitDisableAbility(self.source, BLOODLEECH.id, true)
                BlzUnitHideAbility(self.source, BLOODLEECH.id, false)
                UnitDisableAbility(self.source, BLOODDOMAIN.id, true)
                BlzUnitHideAbility(self.source, BLOODDOMAIN.id, false)

                -- blood leech aoe
                self.ug = CreateGroup()
                self.timer = TQ:callDelayed(1., periodic, self)
                self.agi = BLOODLORD.bonus(self.pid)
                Unit[self.source].bonus_agi = Unit[self.source].bonus_agi + self.agi
                self.bonus = self.agi
            else
                self.stat = "Strength"
                self.str = BLOODLORD.bonus(self.pid)
                Unit[self.source].bonus_str = Unit[self.source].bonus_str + self.str
                self.bonus = self.str
            end

            self.bat = 0.7
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat
            TQ:callDelayed(BLOODLORD.dur(self.pid) * LBOOST[self.pid], DestroyEffect, AddSpecialEffectTarget("war3mapImported\\Burning Rage Red.mdx", self.source, "overhead"))
            SetUnitAnimationByIndex(self.source, 3)

            BLOODBANK.set(self.tpid, 0)
        end
    end

    ---@class ManaDrainDebuff : Buff
    ManaDrainDebuff = Buff.new()
    do
        local thistype = ManaDrainDebuff
        thistype.NAME            = "Mana Drain"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNManaDrain.blp"
        thistype.DESC            = "This unit is having their mana drained"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            MoveLightningEx(self.lfx, false, GetUnitX(self.source), GetUnitY(self.source), BlzGetUnitZ(self.source) + 50., GetUnitX(self.target), GetUnitY(self.target), BlzGetUnitZ(self.target) + 50.)
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end

        local function drain(self, x, y)
            local mana = GetUnitState(self.target, UNIT_STATE_MANA) ---@type number 

            if mana > 0. then
                mana = math.max(0., mana - 1000.)
                SetUnitState(self.target, UNIT_STATE_MANA, mana)
                SetUnitState(self.source, UNIT_STATE_MANA, GetUnitState(self.source, UNIT_STATE_MANA) + math.min(1000., mana))

                DamageTarget(self.source, self.target, math.min(1000., mana) * 2., ATTACK_TYPE_NORMAL, MAGIC, "Mana Drain")
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\ManaBurn\\ManaBurnTarget.mdl", self.target, "chest"))
            end

            if DistanceCoords(x, y, GetUnitX(self.target), GetUnitY(self.target)) > 800. or not UnitAlive(self.source) then
                self:remove()
            else
                TQ:callDelayed(1., drain, self, x, y)
            end
        end

        function thistype:onRemove()
            DestroyLightning(self.lfx)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.lfx = AddLightningEx("DRAM", false, GetUnitX(self.source), GetUnitY(self.source), BlzGetUnitZ(self.source) + 50., GetUnitX(self.target), GetUnitY(self.target), BlzGetUnitZ(self.target) + 50.)

            MoveLightningEx(self.lfx, false, GetUnitX(self.source), GetUnitY(self.source), BlzGetUnitZ(self.source) + 50., GetUnitX(self.target), GetUnitY(self.target), BlzGetUnitZ(self.target) + 50.)

            TQ:callDelayed(1., drain, self, GetUnitX(self.source), GetUnitY(self.source))
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

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
            DestroyEffect(self.sfx)
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as
        end

        function thistype:onApply()
            self.as = 1.25
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as

            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", self.target, "overhead")
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
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, on_hit)
            AddUnitAnimationProperties(self.target, "ready", true)

            self.sfx = AddSpecialEffectTarget("war3mapImported\\Buff_Shield_Non.mdx", self.target, "chest")

            if LIMITBREAK.flag[self.tpid] & 0x1 > 0 then
                BlzSetSpecialEffectColor(self.sfx, 255, 255, 0)
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
            DestroyEffect(self.sfx)

            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.dmg
        end

        function thistype:onApply()
            self.dmg = 0.2
            self.sfx = AddSpecialEffectTarget("war3mapImported\\BattleCryTarget.mdx", self.target, "overhead")

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
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            DestroyEffect(self.sfx)

            Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.dmg
        end

        function thistype:onApply()
            self.mr = (LIMITBREAK.flag[self.pid] & 0x4 > 0 and 1.4) or 1

            Unit[self.target].mr = Unit[self.target].mr * self.mr
            self.dmg = 0.4

            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", self.target, "overhead")

            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.dmg
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

    ---@class UndyingRageBuff : Buff
    UndyingRageBuff = Buff.new()
    do
        local thistype = UndyingRageBuff
        thistype.NAME            = "Undying Rage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNtaur.blp"
        thistype.DESC            = "This unit cannot die"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        ---@param dmg number
        function thistype:addRegen(dmg)
            self.totalRegen = MathClamp(self.totalRegen + dmg / BlzGetUnitMaxHP(self.target) * 100., -100., 100)
        end

        function thistype:onRemove()
            DestroyEffect(self.sfx)
            DestroyTextTag(self.text)

            if self.totalRegen >= 0 then
                HP(self.target, self.target, BlzGetUnitMaxHP(self.target) * 0.01 * self.totalRegen, UNDYINGRAGE.tag)
            else
                DamageTarget(self.target, self.target, BlzGetUnitMaxHP(self.target) * 0.01 * -self.totalRegen, ATTACK_TYPE_NORMAL, PURE, UNDYINGRAGE.tag)
            end

            Unit[self.target].hidehp = false
            TQ:disableCallback(self.timer)
        end

        local function periodic(self)
            SetTextTagText(self.text, (R2I(self.totalRegen)) .. "%", 0.025)
            local red, green, blue = HealthGradient(self.totalRegen, false)
            SetTextTagColor(self.text, red, green, blue, 255)
            SetTextTagPosUnit(self.text, self.target, -200.)

            --percent
            self:addRegen(Unit[self.target].regen * FPS_32)

            SetWidgetLife(self.target, math.max(10., BlzGetUnitMaxHP(self.target) * 0.0001))
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end

        function thistype:onApply()
            self.text = CreateTextTag()
            self.totalRegen = 0.
            SetTextTagText(self.text, (R2I(self.totalRegen)) .. "%", 0.025)
            SetTextTagColor(self.text, R2I(Pow(100 - self.totalRegen, 1.1)), R2I(SquareRoot(math.max(0, self.totalRegen) * 500)), 0, 255)

            Unit[self.target].hidehp = true

            self.sfx = AddSpecialEffectTarget("war3mapImported\\DemonicAdornment.mdx", self.target, "head")

            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

    ---@class RampageBuff : Buff
    RampageBuff = Buff.new()
    do
        local thistype = RampageBuff
        thistype.NAME            = "Rampage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodRampage5.blp"
        thistype.DESC            = "This unit has +$ms movespeed, +$pen% armor penetration, and is draining health"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent - self.pen

            TQ:disableCallback(self.timer)
            DestroyEffect(self.sfx)
        end

        local function periodic(self)
            DamageTarget(self.source, self.source, 0.08 * GetWidgetLife(self.source), ATTACK_TYPE_NORMAL, PURE, "Rampage")
            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onApply()
            self.pen = RAMPAGE.pen(self.tpid)
            self.ms = 100
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent + self.pen
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms

            self.sfx = AddSpecialEffectTarget("war3mapImported\\Windwalk Blood.mdx", self.source, "origin")
            periodic(self)
        end
    end

    ---@class FrostArmorDebuff : Buff
    FrostArmorDebuff = Buff.new()
    do
        local thistype = FrostArmorDebuff
        thistype.NAME            = "Frost Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFrostArmor.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^#bat% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
        end

        function thistype:onApply()
            self.ms = 0.25 * (math.min(1, Unit[self.target].ms_percent))
            self.bat = 1.25

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat
        end
    end

    ---@class FrostArmorBuff : Buff
    FrostArmorBuff = Buff.new()
    do
        local thistype = FrostArmorBuff
        thistype.NAME            = "Frost Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFrostArmor.blp"
        thistype.DESC            = "This unit has +$armor armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(target, source)
            FrostArmorDebuff:add(target, source):duration(3.)
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK:unregister_unit_action(self.target, on_hit)
            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor - self.armor

            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.armor = 100
            EVENT_ON_STRUCK:register_unit_action(self.target, on_hit)
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl", self.source, "chest")

            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor + self.armor
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

    ---@class PiercingStrikeBuff : Buff
    PiercingStrikeBuff = Buff.new()
    do
        local thistype = PiercingStrikeBuff
        thistype.NAME            = "Piercing Strike"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASShieldBreakGreen.tga"
        thistype.DESC            = "This unit has +$pen% armor penetration"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent - self.pen
        end

        function thistype:onApply()
            self.pen = PIERCINGSTRIKE.pen(self.tpid)
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent + self.pen
        end
    end

    ---@class RighteousMightBuff : Buff
    RighteousMightBuff = Buff.new()
    do
        local thistype = RighteousMightBuff
        thistype.NAME            = "Righteous Might"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolyAngel.blp"
        thistype.DESC            = "This unit has +^$dmg% attack damage, +^#mr% magic resist, and +^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function grow(self, size, dur)
            size = size + 0.008
            SetUnitScale(self.source, size, size, size)
            dur = dur - 1

            if dur > 0 then
                self.timer = TQ:callDelayed(FPS_32, grow, self, size, dur)
            else
                self.timer = nil
            end
        end

        function thistype:onRemove()
            SetUnitScale(self.target, BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE))
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            Unit[self.target].damage_percent = Unit[self.target].damage_percent - self.dmg
            Unit[self.target].armor_percent = Unit[self.target].armor_percent - self.armor

            if self.timer then
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            local size = BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE)

            self.timer = TQ:callDelayed(FPS_32, grow, self, size, 60)
            self.mr = 0.2

            Unit[self.target].mr = Unit[self.target].mr * self.mr
            Unit[self.target].damage_percent = Unit[self.target].damage_percent + self.dmg
            Unit[self.target].armor_percent = Unit[self.target].armor_percent + self.armor
        end
    end

    ---@class BloodFrenzyBuff : Buff
    BloodFrenzyBuff = Buff.new()
    do
        local thistype = BloodFrenzyBuff
        thistype.NAME            = "Blood Frenzy"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodFrenzy3.blp"
        thistype.DESC            = "This unit has +^#bat% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl", self.target, "chest")
            self.bat = 1.5

            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
            DamageTarget(self.source, self.source, 0.15 * BlzGetUnitMaxHP(self.source), ATTACK_TYPE_NORMAL, PURE, BLOODFRENZY.tag)
        end
    end

    ---@class EarthDebuff : Buff
    EarthDebuff = Buff.new()
    do
        local thistype = EarthDebuff
        thistype.NAME            = "Earth"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEarthSphere.blp"
        thistype.DESC            = "This unit has -^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.level = self.level or 1
            self.charges = self.level
            self.dr = (1. + 0.04 * self.level)
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class HardHatBuff : Buff
    HardHatBuff = Buff.new()
    do
        local thistype = HardHatBuff
        thistype.NAME            = "Hard Hat"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHelmOfValor.blp"
        thistype.DESC            = "This unit has +^#mult% damage resist"
        thistype.DESC_FACTION    = "After standing still for 3 seconds gain |cffffcc0015%|r damage reduction."
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.CANNOT_PURGE    = true

       local function periodic(self)
            if UnitAlive(self.target) and
                Unit[self.target].x == GetUnitX(self.target) and
                Unit[self.target].y == GetUnitY(self.target)
            then
                self.count = self.count + 1
                if self.count >= 3 then
                    Unit[self.target].dr = Unit[self.target].dr / self.mult
                    self.mult = 0.85
                    Unit[self.target].dr = Unit[self.target].dr * self.mult
                end
            else
                Unit[self.target].dr = Unit[self.target].dr / self.mult
                self.mult = 1.
                self.count = 0
            end
            self.timer = TQ:callDelayed(1, periodic, self)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.mult
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.mult = 1.
            self.count = 0
            self.timer = TQ:callDelayed(1, periodic, self)
        end
    end

    ---@class SteedChargeBuff : Buff
    SteedChargeBuff = Buff.new()
    do
        local thistype = SteedChargeBuff
        thistype.NAME            = "Steed Charge"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSteedCharge.dds"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 100
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class SingleShotDebuff : Buff
    SingleShotDebuff = Buff.new()
    do
        local thistype = SingleShotDebuff
        thistype.NAME            = "Crippled"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGunHD.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Cripple\\CrippleTarget.mdl", self.target, "chest")
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class FreezingBlastDebuff : Buff
    FreezingBlastDebuff = Buff.new()
    do
        local thistype = FreezingBlastDebuff
        thistype.NAME            = "Freezing Blast"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFreezingBlast2.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class ProtectedBuff : Buff
    ProtectedBuff = Buff.new()
    do
        local thistype = ProtectedBuff
        thistype.NAME            = "Protected"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASShield.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = (0.93 - 0.02 * self.ablev)

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class AstralShieldBuff : Buff
    AstralShieldBuff = Buff.new()
    do
        local thistype = AstralShieldBuff
        thistype.NAME            = "Astral Shield"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSnakeShield.blp"
        thistype.DESC            = "This unit has +^#mr% magic resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.mr = 0.333
            Unit[self.target].mr = Unit[self.target].mr * self.mr
            self.sfx = AddSpecialEffectTarget("war3mapImported\\DemonShieldTarget3A.mdx", self.target, "origin")
        end
    end

    ---@class ProtectedExistenceBuff : Buff
    ProtectedExistenceBuff = Buff.new()
    do
        local thistype = ProtectedExistenceBuff
        thistype.NAME            = "Protected Existence"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSnakeShield.blp"
        thistype.DESC            = "This unit has +^#mr% magic resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.mr = 0.666
            Unit[self.target].mr = Unit[self.target].mr * self.mr
            self.sfx = AddSpecialEffectTarget("war3mapImported\\DemonShieldTarget3A.mdx", self.target, "origin")
        end
    end

    ---@class ProtectionBuff : Buff
    ProtectionBuff = Buff.new()
    do
        local thistype = ProtectionBuff
        thistype.NAME            = "Protection"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolybird.blp"
        thistype.DESC            = "This unit has +^#as% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_expire(source)
            thistype:dispel(nil, source)
        end

        local function on_extend(source, amount, dur)
            local buff = thistype:get(nil, source)

            buff:duration(math.max(buff:remaining(), dur))
        end

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as

            EVENT_ON_SHIELD_APPLY:unregister_unit_action(self.target, on_extend)
            EVENT_ON_SHIELD_EXPIRE:unregister_unit_action(self.target, on_expire)
        end

        function thistype:onApply()
            self.as = 1.1
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as

            EVENT_ON_SHIELD_APPLY:register_unit_action(self.target, on_extend)
            EVENT_ON_SHIELD_EXPIRE:register_unit_action(self.target, on_expire)
        end
    end

    ---@class SanctifiedGroundDebuff : Buff
    SanctifiedGroundDebuff = Buff.new()
    do
        local thistype = SanctifiedGroundDebuff
        thistype.NAME            = "Sanctified Ground"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolyShock3.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$regen% healing"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.regen
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = SANCTIFIEDGROUND.ms * 0.01 * (math.min(1, Unit[self.target].ms_percent))
            self.regen = (IsBoss(self.target) and 0.5) or 1

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].regen_percent = Unit[self.target].regen_percent - self.regen
        end
    end

    ---@class DivineLightBuff : Buff
    DivineLightBuff = Buff.new()
    do
        local thistype = DivineLightBuff
        thistype.NAME            = "Divine Light"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDivineLight5.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 25 + 25 * GetUnitAbilityLevel(self.source, DIVINELIGHT.id)

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

    ---@class SmokebombBuff : Buff
    SmokebombBuff = Buff.new()
    do
        local thistype = SmokebombBuff
        thistype.NAME            = "Smoke Bomb"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSmokeBomb1.blp"
        thistype.DESC            = "This unit has +$evasion% evasion"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].evasion = Unit[self.target].evasion - self.evasion
        end

        function thistype:onApply()
            if self.source == self.target then
                self.evasion = self.evasion + (9 + GetUnitAbilityLevel(self.source, SMOKEBOMB.id)) * 2
            else
                self.evasion = self.evasion + 9 + GetUnitAbilityLevel(self.source, SMOKEBOMB.id)
            end

            Unit[self.target].evasion = Unit[self.target].evasion + self.evasion
        end
    end

    ---@class SmokebombDebuff : Buff
    SmokebombDebuff = Buff.new()
    do
        local thistype = SmokebombDebuff
        thistype.NAME            = "Smoke Bomb"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSmokeBomb1.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = (0.28 + 0.02 * GetUnitAbilityLevel(self.source, SMOKEBOMB.id)) * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
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
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.35
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", self.target, "overhead")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

    ---@class BloodCurdlingScreamDebuff : Buff
    BloodCurdlingScreamDebuff = Buff.new()
    do
        local thistype = BloodCurdlingScreamDebuff
        thistype.NAME            = "Blood Curdling Scream"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBlood-CurdlingScream2.blp"
        thistype.DESC            = "This unit has -^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.armor         = 0

        function thistype:onRemove()
            Unit[self.target].armor_percent = Unit[self.target].armor_percent + self.armor
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.armor = 0.12 + 0.02 * GetUnitAbilityLevel(self.source, FourCC('A06H'))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", self.target, "chest")

            Unit[self.target].armor_percent = Unit[self.target].armor_percent - self.armor
        end
    end

    ---@class NerveGasDebuff : Buff
    NerveGasDebuff = Buff.new()
    do
        local thistype = NerveGasDebuff
        thistype.NAME            = "Nerve Gas"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNAcidBomb.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed, -^$as% attack speed, and -^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local dmg = NERVEGAS.dmg(self.pid) * BOOST[self.pid] / (NERVEGAS.dur * LBOOST[self.pid] * 2.)

            DamageTarget(self.source, self.target, dmg, ATTACK_TYPE_NORMAL, MAGIC, "Nerve Gas")

            self.timer = TQ:callDelayed(0.5, periodic, self)
        end

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target].armor_percent = Unit[self.target].armor_percent + self.armor
            DestroyEffect(self.sfx)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.as = 0.3
            self.armor = 0.2

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].armor_percent = Unit[self.target].armor_percent - self.armor
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\AcidBomb\\BottleImpact.mdl", self.target, "chest")

            self.timer = TQ:callDelayed(0.25, periodic, self)
        end
    end

    ---@class DemonPrinceBloodlust : Buff
    DemonPrinceBloodlust = Buff.new()
    do
        local thistype = DemonPrinceBloodlust
        thistype.NAME            = "Bloodlust"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodLust.blp"
        thistype.DESC            = "This unit has +^$ms% movespeed and +^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end

        function thistype:onApply()
            self.as = 0.75
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end
    end

    ---@class FireElementBuff : Buff
    FireElementBuff = Buff.new()
    do
        local thistype = FireElementBuff
        thistype.NAME            = "Fire"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFireSwirl.blp"
        thistype.DESC            = "This unit has +^$spellboost% spellboost"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            DestroyEffect(self.sfx)
            DestroyEffect(self.sfx2)
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        end

        function thistype:onApply()
            self.spellboost = 0.15
            masterElement[self.tpid] = ELEMENTFIRE.value
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Fire Uber.mdx", self.target, "right hand")
            self.sfx2 = AddSpecialEffectTarget("war3mapImported\\Fire Uber.mdx", self.target, "left hand")
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        end
    end

    ---@class IceElementBuff : Buff
    IceElementBuff = Buff.new()
    do
        local thistype = IceElementBuff
        thistype.NAME            = "Ice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNIceBlast.blp"
        thistype.DESC            = "This unit has +!$regen% max mana regeneration and slows nearby enemies"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max - self.regen
            DestroyEffect(self.sfx)
            DestroyEffect(self.sfx2)
        end

        function thistype:onApply()
            self.regen = 1.5
            masterElement[self.tpid] = ELEMENTICE.value
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max + self.regen
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Water High.mdx", self.target, "right hand")
            self.sfx2 = AddSpecialEffectTarget("war3mapImported\\Water High.mdx", self.target, "left hand")
        end
    end

    ---@class LightningElementBuff : Buff
    LightningElementBuff = Buff.new()
    do
        local thistype = LightningElementBuff
        thistype.NAME            = "Lightning"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNLightningOrb.blp"
        thistype.DESC            = "This unit has +^$ms% movespeed and shocks nearby enemies"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(source, target)
            DamageTarget(source, target, GetWidgetLife(target) * 0.005, ATTACK_TYPE_NORMAL, PURE, ELEMENTLIGHTNING.tag)
        end

        local function periodic(self)
            if UnitAlive(self.target) then
                local ug = CreateGroup()
                local x = GetUnitX(self.target)
                local y = GetUnitY(self.target)

                MakeGroupInRange(self.tpid, ug, x, y, 900., Condition(FilterEnemy))

                local target = FirstOfGroup(ug)
                if target then
                    local dummy = Dummy.create(x, y, FourCC('A09W'), 1, 1.)
                    dummy:attack(target, self.target, on_hit)
                end

                DestroyGroup(ug)
            end

            self.timer = TQ:callDelayed(5., periodic, self)
        end

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            DestroyEffect(self.sfx)
            DestroyEffect(self.sfx2)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms

            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            masterElement[self.tpid] = ELEMENTLIGHTNING.value
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Storm Cast.mdx", self.target, "right hand")
            self.sfx2 = AddSpecialEffectTarget("war3mapImported\\Storm Cast.mdx", self.target, "left hand")
            self.ms = 0.4 * (math.min(1, Unit[self.target].ms_percent))
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms

            self.timer = TQ:callDelayed(5., periodic, self)
        end
    end

    ---@class EarthElementBuff : Buff
    EarthElementBuff = Buff.new()
    do
        local thistype = EarthElementBuff
        thistype.NAME            = "Earth"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEarthSphere.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            DestroyEffect(self.sfx)
            DestroyEffect(self.sfx2)
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.75
            masterElement[self.tpid] = ELEMENTEARTH.value
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Earth High.mdx", self.target, "right hand")
            self.sfx2 = AddSpecialEffectTarget("war3mapImported\\Earth High.mdx", self.target, "left hand")
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class GaiaArmorBuff : Buff
    GaiaArmorBuff = Buff.new()
    do
        local thistype = GaiaArmorBuff
        thistype.NAME            = "Gaia Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNMantleOfForestDefender.blp"
        thistype.DESC            = "This unit is protected from a fatal blow"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
        thistype.callback        = {}

        local on_hit

        local function on_cleanup(pid)
            TQ:disableCallback(thistype.callback[pid])
        end

        local function fatal_cooldown(self)
            if GetUnitAbilityLevel(self.target, GAIAARMOR.id) >= 1 then
                thistype:add(self.target, self.target)
                EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, on_hit)
            end

            EVENT_ON_CLEANUP:unregister_action(self.pid, on_cleanup)
        end

        on_hit = function(target, source, amount, damage_type)
            local buff = thistype:get(nil, target) ---@type Buff

            if buff then
                buff:remove()
                amount.value = 0
                HP(target, target, BlzGetUnitMaxHP(target) * 0.2 * GetUnitAbilityLevel(target, GAIAARMOR.id), GAIAARMOR.tag)
                MP(target, BlzGetUnitMaxMana(target) * 0.2 * GetUnitAbilityLevel(target, GAIAARMOR.id))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl", target, "origin"))

                local x = GetUnitX(target)
                local y = GetUnitY(target)
                local ug = CreateGroup()
                MakeGroupInRange(buff.pid, ug, x, y, 400., Condition(FilterEnemy))

                for u in each(ug) do
                    Stun:add(target, u):duration(4.)

                    local x2 = GetUnitX(u)
                    local y2 = GetUnitY(u)
                    local angle = atan(y2 - y, x2 - x)

                    CAT_Knockback(u, 1200. * math.cos(angle), 1200. * math.sin(angle), 0.)
                    CAT_UnitEnableFriction(u, true)
                    TQ:callDelayed(1., CAT_UnitEnableFriction, u, false)
                end

                DestroyGroup(ug)

                thistype.callback[buff.pid] = TQ:callDelayed(120., fatal_cooldown, buff)
                EVENT_ON_CLEANUP:register_action(buff.pid, on_cleanup)
            end

            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(target, on_hit)
        end

        function thistype:onRemove()
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, on_hit)
        end
    end

    ---@class IceElementDebuff : Buff
    IceElementDebuff = Buff.new()
    do
        local thistype = IceElementDebuff
        thistype.NAME            = "Ice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNIceBlast.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.25
            self.ms = 0.35 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\FrostDamage\\FrostDamage.mdl", self.target, "chest")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

    ---@class TidalWaveDebuff : Buff
    TidalWaveDebuff = Buff.new()
    do
        local thistype = TidalWaveDebuff
        thistype.NAME            = "Tidal Wave"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTidalWave4.blp"
        thistype.DESC            = "This unit has -^$percent% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / (1 + self.percent)
        end
        function thistype:onApply()
            self.percent = self.percent or .15
            Unit[self.target].dr = Unit[self.target].dr * (1 + self.percent)
        end

    end

    ---@class SoakedDebuff : Buff
    SoakedDebuff = Buff.new()
    do
        local thistype = SoakedDebuff
        thistype.NAME            = "Soaked"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCrushingWave.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.3
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Other\\FrostDamage\\FrostDamage.mdl", self.target, "chest")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
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
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.3
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Human\\slow\\slowtarget.mdl", self.target, "origin")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class MeatGolemThunderClap : Buff
    MeatGolemThunderClap = Buff.new()
    do
        local thistype = MeatGolemThunderClap
        thistype.NAME            = "Thunder Clap"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNThunderclap.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.3
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", self.target, "overhead")

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

    ---@class SaviorThunderClap : Buff
    SaviorThunderClap = Buff.new()
    do
        local thistype = SaviorThunderClap
        thistype.NAME            = "Thunder Clap"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHoly Might.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self. as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.35
            self.ms = 0.35 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", self.target, "overhead")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class BlinkStrikeBuff : Buff
    BlinkStrikeBuff = Buff.new()
    do
        local thistype = BlinkStrikeBuff
        thistype.NAME            = "Blink Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBlinkStrike1.blp"
        thistype.DESC            = "This unit has +$evasion% evasion"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            DestroyEffect(self.sfx)
            Unit[self.target].evasion = Unit[self.target].evasion - self.evasion
        end

        function thistype:onApply()
            self.evasion = 30
            self.sfx = AddSpecialEffectTarget("war3mapImported\\Windwalk.mdx", self.target, "origin")
            Unit[self.target].evasion = Unit[self.target].evasion + self.evasion
        end
    end

    ---@class NagaThorns : Buff
    NagaThorns = Buff.new()
    do
        local thistype = NagaThorns
        thistype.NAME            = "Thorns"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASBTNThorns.blp"
        thistype.DESC            = "This unit returns massive damage when attacked"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function onStruck(target, source, damage_type)
            if damage_type == PHYSICAL then
                DamageTarget(target, source, BlzGetUnitMaxHP(source) * 0.4, ATTACK_TYPE_NORMAL, MAGIC)
            end
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK:unregister_unit_action(self.target, onStruck)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Undead\\ThornyShield\\ThornyShieldTargetChestLeft.mdl", self.target, "chest")
            EVENT_ON_STRUCK:register_unit_action(self.target, onStruck)

            TQ:callDelayed(2.5, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\ThornsAura\\ThornsAura.mdl", self.target, "origin"))
        end
    end

    ---@class NagaBerserkBuff : Buff
    NagaBerserkBuff = Buff.new()
    do
        local thistype = NagaBerserkBuff
        thistype.NAME            = "Berserk"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBerserkForTrolls.blp"
        thistype.DESC            = "This unit has +^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end

        function thistype:onApply()
            self.as = 8
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\BattleRoar\\RoarCaster.mdl", self.target, "chest"))
        end
    end

    ---@class SpiritCallSlow : Buff
    SpiritCallSlow = Buff.new()
    do
        local thistype = SpiritCallSlow
        thistype.NAME            = "Spirit Call"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWisp.blp"
        thistype.DESC            = "This unit has -^%ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class LightSealBuff : Buff
    LightSealBuff = Buff.new()
    do
        local thistype = LightSealBuff
        thistype.NAME            = "Perserverance"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower2.blp"
        thistype.DESC            = "This unit has +$strength strength and +^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function stack_expire(self)
            if self.charges > 0 then
                -- remove current contribution
                Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
                Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor

                self.charges = math.max(0, self.charges - 1)

                -- recompute bonuses
                self.strength = R2I(GetHeroStr(self.source, true) * 0.01 * self.charges)
                self.armor    = 0.01 * self.charges

                -- reapply new contribution (if any)
                Unit[self.source].bonus_str     = Unit[self.source].bonus_str + self.strength
                Unit[self.source].armor_percent = Unit[self.source].armor_percent + self.armor
                UnitRefreshBuff(self.source, self)

                if self.charges > 0 then
                    self.timer = TQ:callDelayed(5., stack_expire, self)
                    self:duration(5.05)
                else
                    self.timer = false
                    self:duration()
                end
            end
        end

        function thistype:addStack(u)
            local i = IsBoss(u) and 5 or 1

            local hp = GetWidgetLife(self.source)

            -- remove old contribution
            Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor

            self.charges  = math.min(self.charges + i, GetUnitAbilityLevel(self.source, LIGHTSEAL.id) * 10)

            -- recompute bonuses
            self.strength = R2I(GetHeroStr(self.source, true) * 0.01 * self.charges)
            self.armor    = 0.01 * self.charges -- +1% per charge

            -- apply new contribution
            Unit[self.source].bonus_str     = Unit[self.source].bonus_str + self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent + self.armor

            SetWidgetLife(self.source, hp)
            UnitRefreshBuff(self.source, self)

            if not self.timer then
                self.timer = TQ:callDelayed(5., stack_expire, self)
                self:duration(5.05)
            end
        end

        function thistype:onRemove()
            TQ:disableCallback(self.timer)

            Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor
        end

        function thistype:onApply()
            self.charges = 0
            self.strength = 0
            self.armor = 0
        end
    end

    ---@class DarkSealDebuff : Buff
    DarkSealDebuff = Buff.new()
    do
        local thistype = DarkSealDebuff
        thistype.NAME            = "Dark Seal"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower.BLP"
        thistype.DESC            = "This unit is under a Dark Seal"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
    end

    ---@class DarkSealBuff : Buff
    ---@field x number
    ---@field y number
    ---@field count number
    ---@field sfx unit
    DarkSealBuff = Buff.new()
    do
        local thistype = DarkSealBuff
        thistype.NAME            = "Dark Seal"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower.BLP"
        thistype.DESC            = "This unit has +$charges% spellboost and base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function count(object, target, self)
            self.charges = self.charges + ((IsUnitType(object, UNIT_TYPE_HERO) and 10) or 1)
            DarkSealDebuff:add(target, object):duration(1.)
        end

        local function periodic(self)
            self.charges = 0

            -- count units in seal
            ALICE_ForAllObjectsInRangeDo(count, self.x, self.y, 450. * LBOOST[self.pid], "unit", valid_damage_target, self.target, self)

            self.charges = math.min(5 + (GetHeroLevel(self.source) // 100) * 10, self.charges)

            self:refresh()
            self.callback = TQ:callDelayed(0.5, periodic, self)
        end

        -- reapplies spellboost and bat bonus
        function thistype:refresh()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat

            self.spellboost = self.charges * 0.01
            self.bat = (1. + self.charges * 0.01)
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat

            HideEffect(self.sfx)

            TQ:disableCallback(self.callback)
        end

        function thistype:onApply()
            self.spellboost = 0
            self.bat = 1
            self.charges = 0

            self.sfx = AddSpecialEffect("war3mapImported\\newrunetest.mdl", self.x, self.y)
            BlzSetSpecialEffectZ(self.sfx, GetLocZ(self.x, self.y))
            BlzSetSpecialEffectScale(self.sfx, 6.1)
            BlzSetSpecialEffectYaw(self.sfx, 270. * bj_DEGTORAD)
            BlzSetSpecialEffectTimeScale(self.sfx, 0.8)

            periodic(self)
        end
    end

    ---@class MetamorphosisBuff : Buff
    MetamorphosisBuff = Buff.new()
    do
        local thistype = MetamorphosisBuff
        thistype.NAME            = "Metamorphosis"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNMetamorphasis3.blp"
        thistype.DESC            = "This unit has $range attack range, splash attacks, !$bat base attack time, and +^#dm% total damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.dm
            Unit[self.target].base_bat = 2.222
        end

        function thistype:onApply()
            self.range = 900
            self.bat = 0.8
            local hp = GetWidgetLife(self.target) * 0.5 ---@type number 

            SetWidgetLife(self.target, hp)
            self.dm = 1 + math.max(0.01, hp / (BlzGetUnitMaxHP(self.target) * 1.))
            Unit[self.target].dm = Unit[self.target].dm * self.dm
            Unit[self.target].base_bat = self.bat
        end
    end

    ---@class KnockUp : Buff
    KnockUp = Buff.new()
    do
        local thistype = KnockUp
        thistype.NAME            = "Mid-air"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNStun.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local SPEED = 1500.
        local DEBUFF_TIME = 1.

        ---@param deltaTime number
        ---@return number
        local function calcHeight(deltaTime)
            local g = 9.81 ---@type number 
            local h = 0. ---@type number 

            deltaTime = deltaTime * 1.2

            if deltaTime <= DEBUFF_TIME * 0.5 then
                h = SPEED * deltaTime - 0.5 * g * deltaTime * deltaTime
            else
                deltaTime = deltaTime * 1.2
                h = SPEED * (DEBUFF_TIME - deltaTime) - 0.5 * g * (DEBUFF_TIME - deltaTime) * (DEBUFF_TIME - deltaTime)
            end

            return math.max(0, h)
        end

        local function periodic(self)
            self.time = self.time + FPS_32
            SetUnitFlyHeight(self.target, calcHeight(self.time), 0.)

            if self.time > DEBUFF_TIME then
                self:remove()
            else
                self.timer = TQ:callDelayed(FPS_32, periodic, self)
            end
        end

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            SetUnitFlyHeight(self.target, 0., 0.)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)

            if UnitAddAbility(self.target, FourCC('Amrf')) then
                UnitRemoveAbility(self.target, FourCC('Amrf'))
            end

            self.time = 0
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

    ---@class Freeze : Buff
    Freeze = Buff.new()
    do
        local thistype = Freeze
        thistype.NAME            = "Frozen"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGlacier.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Undead\\FreezingBreath\\FreezingBreathTargetArt.mdl", self.target, "chest")
        end
    end

    ---@class Stun : Buff
    Stun = Buff.new()
    do
        local thistype = Stun
        thistype.NAME            = "Stunned"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNStun.blp"
        thistype.DESC            = "This unit cannot move, attack, or cast spells"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            BlzPauseUnitEx(self.target, false)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            BlzPauseUnitEx(self.target, true)
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", self.target, "overhead")
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
            DestroyEffect(self.sfx)

            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, onStruck)
        end

        function thistype:onApply()
            self.dm = 0.15
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\shadowstrike\\shadowstrike.mdl", self.target, "overhead")

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
            DestroyEffect(self.sfx)

            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.7
            self.sfx = AddSpecialEffectTarget("war3mapImported\\SoulArmor.mdx", self.target, "chest")

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class HolyBlessing : Buff
    HolyBlessing = Buff.new()
    do
        local thistype = HolyBlessing
        thistype.NAME            = "Holy Blessing"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBerserkForTrolls.blp"
        thistype.DESC            = "This unit has +^$as% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as
        end

        function thistype:onApply()
            self.as = 2.
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as
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
            HP(source, source, amount_after_red * 0.05, "Vampiric Potion")
            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\VampiricAuraTarget.mdx", source, "chest"))
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
            DestroyEffect(self.sfx)
        end

        function thistype:onApply()
            self.leech = 0.05
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
            self.sfx = AddSpecialEffectTarget("Abilities\\Spells\\Items\\VampiricPotion\\VampPotionCaster.mdl", self.target, "origin")
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

    ---@class WeatherBuff : Buff
    WeatherBuff = Buff.new()
    do
        local thistype = WeatherBuff
        thistype.DISPEL_TYPE     = BUFF_NONE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
    end
end, Debug and Debug.getLine())
