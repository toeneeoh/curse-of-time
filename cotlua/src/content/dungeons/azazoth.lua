-- Dungeon-specific content; the shared queue/lifecycle lives in gameplay/dungeons/dungeon.lua.
OnInit.final('AzazothDungeon', function(Require)
    Require('Dungeons')
    Require('BossSchema')
    Require('Boss')
    Require('WorldTransitions')

    DUNGEON_AZAZOTH = Dungeon.define('I08T')
    do
        local thistype = DUNGEON_AZAZOTH

        thistype.level = 360
        thistype.name = "Azazoth's Lair"
        thistype.queue_x = -1408.
        thistype.queue_y = -15246.
        thistype.entrance_x = -2036.
        thistype.entrance_y = -28236.
        thistype.exit_x = -250.
        thistype.exit_y = 60.

        thistype.playerDeath = function(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            TableRemove(thistype.players, pid)

            if UnitAlive(thistype.boss) then
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20.00, "|c00ff3333Azazoth: Mortal weakling, begone! Your flesh is not even worth annihilation.")
            end

            if #thistype.players <= 0 then
                thistype:destroy()
                Buff.dispelAll(thistype.boss)
                SetUnitLifePercentBJ(thistype.boss, 100)
                SetUnitManaPercentBJ(thistype.boss, 100)
                SetUnitPosition(thistype.boss, GetRectCenterX(gg_rct_Azazoth_Boss_Spawn), GetRectCenterY(gg_rct_Azazoth_Boss_Spawn))
                BlzSetUnitFacingEx(thistype.boss, 90.00)
            end

            EVENT_GRAVE_DEATH:unregister_unit_action(u, thistype.playerDeath)
        end

        local function onComplete()
            StartSound(bj_questCompletedSound)

            -- wait for azazoth to respawn before able to enter again
            RemoveItemFromStock(god_portal, FourCC('I08T'))

            thistype:endDungeon()
        end

        local function unpause_boss(go)
            if not thistype.started or #thistype.players == 0 then return end
            if not go then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl", thistype.boss, "origin"))
                TimerQueue:callDelayed(2., unpause_boss, true)
            else
                PauseUnit(thistype.boss, false)
                SetUnitTimeScale(thistype.boss, 1.)
                UnitRemoveAbility(thistype.boss, ABIL_AVUL)
            end
        end

        function thistype:onStart()
            thistype.boss = Boss[BOSS_AZAZOTH].unit
            UnitAddAbility(thistype.boss, ABIL_AVUL)
            PauseUnit(thistype.boss, true)
            SetUnitTimeScale(thistype.boss, 0.)
            TimerQueue:callDelayed(5., unpause_boss, false)

            EVENT_ON_UNIT_DEATH:register_unit_action(Boss[BOSS_AZAZOTH].unit, onComplete)
        end
    end

end, Debug and Debug.getLine())
