OnInit.final("BuffsBossesForgottenMystic", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local TQ = TimerQueue
    local FPS_32 = FPS_32

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

end, Debug and Debug.getLine())
