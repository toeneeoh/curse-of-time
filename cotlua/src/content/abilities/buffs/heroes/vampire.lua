OnInit.final("BuffsHeroesVampire", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local PHASED_MOVEMENT = FourCC('I0OE')

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
                    self.sfx.color = {255, 255, 255}
                end
            else
                Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
                self.ms = 0
                UnitRemoveAbility(self.target, FourCC('B02Q'))
                self.sfx.color = {0, 0, 0}
            end

            self.timer = TQ:callDelayed(0.5, periodic, self)
        end

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

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

            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Chumpool.mdx", "origin")

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
            local u = Unit[self.target]
            DestroyGroup(self.ug)
            EVENT_ON_HIT:unregister_unit_action(self.source, on_hit)

            u.bonus_bat = u.bonus_bat / self.bat
            u.bonus_agi = u.bonus_agi - self.agi
            u.bonus_str = u.bonus_str - self.str
            u:removeEffect(self.sfx)

            if self.timer then
                UnitDisableAbility(self.source, BLOODLEECH.id, false)
                UnitDisableAbility(self.source, BLOODDOMAIN.id, false)
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            local u = Unit[self.target]

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
                u.bonus_agi = u.bonus_agi + self.agi
                self.bonus = self.agi
            else
                self.stat = "Strength"
                self.str = BLOODLORD.bonus(self.pid)
                u.bonus_str = u.bonus_str + self.str
                self.bonus = self.str
            end

            self.bat = 0.7
            u.bonus_bat = u.bonus_bat * self.bat
            self.sfx = u:addEffect("war3mapImported\\Burning Rage Red.mdx", "overhead")
            SetUnitAnimationByIndex(self.source, 3)

            BLOODBANK.set(self.tpid, 0)
        end
    end

end, Debug and Debug.getLine())
