--[[
    death.lua

    This library handles death events (i.e. EVENT_PLAYER_UNIT_DEATH or EVENT_UNIT_DEATH)
    and provides related functions and globals
]]

OnInit.final("Death", function(Require)
    Require('DropTable')
    Require('Units')
    Require('Spells')
    Require('Events')

    REVIVE_INDICATOR  = {} ---@type effect[] 
    REVIVE_BAR        = {} ---@type effect[] 

    -- Grave Revive
    local GRAVE_REVIVE = Spell.define('A042', 'A044', 'A045')
    do
        local thistype = GRAVE_REVIVE

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            if not IsTerrainWalkable(targetX, targetY) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            end
        end

        function thistype:onCast()
            HideEffect(REVIVE_INDICATOR[self.pid])
            HideEffect(REVIVE_BAR[self.pid])
            TimerList[self.pid]:stopAllTimers('dead')

            -- item revival
            if self.sid == FourCC('A042') then
                local itm = GetResurrectionItem(self.pid, false)

                if itm then
                    Spells[itm.abil]:onCast(itm)
                end
            -- pr reincarnation
            elseif self.sid == FourCC('A044') then
                RevivePlayer(self.pid, self.targetX, self.targetY, 1, 1)

                BlzStartUnitAbilityCooldown(Hero[self.pid], REINCARNATION.id, 300.)
            -- high priestess revival
            elseif self.sid == RESURRECTION.spell then
                local heal = 0.4 + 0.2 * GetUnitAbilityLevel(Hero[ResurrectionRevival[self.pid]], RESURRECTION.id)
                RevivePlayer(self.pid, self.targetX, self.targetY, heal, heal)
            end

            -- refund HP cooldown and mana
            if self.sid ~= RESURRECTION.spell and ResurrectionRevival[self.pid] > 0 then
                BlzEndUnitAbilityCooldown(Hero[ResurrectionRevival[self.pid]], RESURRECTION.id)
                SetUnitState(Hero[ResurrectionRevival[self.pid]], UNIT_STATE_MANA, BlzGetUnitMaxMana(Hero[ResurrectionRevival[self.pid]]) * 0.5)
            end

            REINCARNATION.enabled[self.pid] = false
            ResurrectionRevival[self.pid] = 0
            UnitRemoveAbility(self.caster, FourCC('A042'))
            UnitRemoveAbility(self.caster, FourCC('A044'))
            UnitRemoveAbility(self.caster, RESURRECTION.spell)
            SetUnitPosition(self.caster, 30000, 30000)
            ShowUnit(self.caster, false)
        end
    end

    ---@param pid integer
    function DeathHandler(pid)
        CleanupSummons(pid)
        EVENT_GRAVE_DEATH:trigger(Hero[pid])

        -- gods area
        if TableHas(GODS_GROUP, pid) then
            TableRemove(GODS_GROUP, pid)
        -- death exception
        elseif InColosseum(pid) then
        -- hardcore death
        elseif Profile[pid].hero.hardcore > 0 then
            DisplayTextToPlayer(Player(pid - 1), 0, 0, "You have died on Hardcore mode, you cannot revive. However, you may -repick to begin a new character in a new character save slot.")

            PlayerCleanup(pid)
        -- softcore death
        else
            ChargeNetworth(Player(pid - 1), 0, 0.02, 50 * GetHeroLevel(Hero[pid]), "Dying has cost you")

            RevivePlayer(pid, GetLocationX(TOWN_CENTER), GetLocationY(TOWN_CENTER), 1, 1)
            SetCamera(pid, MAIN_MAP.rect)
        end
    end

    ---@type fun(pt: PlayerTimer)
    local function grave_expire(pt)
        local pid  = pt.pid
        local itm  = GetResurrectionItem(pid, false) ---@type Item?
        local heal = 0. ---@type number 

        HideEffect(REVIVE_INDICATOR[pid])
        HideEffect(REVIVE_BAR[pid])

        if IsUnitHidden(HeroGrave[pid]) == false then
            -- high priestess resurrection
            if ResurrectionRevival[pid] > 0 then
                heal = RESURRECTION.restore(ResurrectionRevival[pid])
                RevivePlayer(pid, GetUnitX(HeroGrave[pid]), GetUnitY(HeroGrave[pid]), heal, heal)
            elseif REINCARNATION.enabled[pid] then
                RevivePlayer(pid, GetUnitX(HeroGrave[pid]), GetUnitY(HeroGrave[pid]), 1, 1)
                BlzStartUnitAbilityCooldown(Hero[pid], REINCARNATION.id, 300.)
            -- reincarnation item
            elseif itm then
                Spells[itm.abil]:onCast(itm)
            -- actually died
            else
                DeathHandler(pid)
            end

            -- cleanup
            REINCARNATION.enabled[pid] = false
            ResurrectionRevival[pid] = 0
            UnitRemoveAbility(HeroGrave[pid], FourCC('A042'))
            UnitRemoveAbility(HeroGrave[pid], FourCC('A044'))
            UnitRemoveAbility(HeroGrave[pid], RESURRECTION.spell)

            SetUnitPosition(HeroGrave[pid], 30000, 30000)
            ShowUnit(HeroGrave[pid], false)
        end
    end

    ---@type fun(pid: integer)
    function SpawnGrave(pid)
        local itm = GetResurrectionItem(pid, false)
        local scale = 0 ---@type number 

        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\RaiseSkeletonWarrior\\RaiseSkeleton.mdl", GetUnitX(HeroGrave[pid]), GetUnitY(HeroGrave[pid])))
        SetUnitVertexColor(HeroGrave[pid], 175, 175, 175, 255)
        if GetHeroLevel(Hero[pid]) > 1 then
            SuspendHeroXP(HeroGrave[pid], false)
            SetHeroLevel(HeroGrave[pid], GetHeroLevel(Hero[pid]), false)
            SuspendHeroXP(HeroGrave[pid], true)
        end
        BlzSetHeroProperName(HeroGrave[pid], GetHeroProperName(Hero[pid]))
        Fade(HeroGrave[pid], 1., false)
        if GetLocalPlayer() == Player(pid - 1) then
            ClearSelection()
            SelectUnit(HeroGrave[pid], true)
        end

        if itm then
            UnitAddAbility(HeroGrave[pid], FourCC('A042'))
        end

        if itm or REINCARNATION.enabled[pid] or ResurrectionRevival[pid] > 0 then
            REVIVE_INDICATOR[pid] = AddSpecialEffect("UI\\Feedback\\Target\\Target.mdx", GetUnitX(HeroGrave[pid]), GetUnitY(HeroGrave[pid]))

            if GetLocalPlayer() == Player(pid - 1) then
                scale = 15
            end

            BlzSetSpecialEffectTimeScale(REVIVE_INDICATOR[pid], 0)
            BlzSetSpecialEffectScale(REVIVE_INDICATOR[pid], scale)
            BlzSetSpecialEffectZ(REVIVE_INDICATOR[pid], BlzGetLocalSpecialEffectZ(REVIVE_INDICATOR[pid]) - 100)
        end

        REVIVE_BAR[pid] = AddSpecialEffect("war3mapImported\\Progressbar.mdl", GetUnitX(HeroGrave[pid]), GetUnitY(HeroGrave[pid]))
        BlzSetSpecialEffectZ(REVIVE_BAR[pid], BlzGetUnitZ(HeroGrave[pid]) + 200.)
        BlzSetSpecialEffectColorByPlayer(REVIVE_BAR[pid], Player(pid - 1))
        BlzPlaySpecialEffectWithTimeScale(REVIVE_BAR[pid], ANIM_TYPE_BIRTH, 0.099)
        BlzSetSpecialEffectScale(REVIVE_BAR[pid], 1.25)

        local pt = TimerList[pid]:add()
        pt.tag = 'dead'
        pt.timer:callDelayed(12.5, grave_expire, pt)
    end

    -- main death event
    local function on_death()
        local killed = GetTriggerUnit()
        local killer = GetKillingUnit()
        local pid    = GetPlayerId(GetOwningPlayer(killed)) + 1

        -- on kill trigger
        if killer then
            EVENT_ON_KILL:trigger(killer, killed)
        end

        -- on death trigger
        EVENT_ON_UNIT_DEATH:trigger(killed, killer)
        EVENT_ON_DEATH:trigger(pid, killed, killer)

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DEATH, on_death)
end, Debug and Debug.getLine())
