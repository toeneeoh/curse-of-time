OnInit.final("BardSpells", function(Require)
    Require('Spells')
    Require('SpellTools')

    local valid_damage_target = VALID_DAMAGE_TARGET
    local valid_pull_target = VALID_PULL_TARGET
    local BARD_SONG = __jarray(0)

    local song_color = {
        [SONG_FATIGUE] = 3,
        [SONG_HARMONY] = 6,
        [SONG_PEACE] = 4,
        [SONG_WAR] = 0
    }

    local function song_periodic(pt)
        local ug = CreateGroup()
        local pt2 = TimerList[pt.pid]:get(IMPROV.id, nil, pt.caster)
        MakeGroupInRange(pt.pid, ug, GetUnitX(pt.caster), GetUnitY(pt.caster), 900. * LBOOST[pt.pid], Condition(isalive))

        if pt2 then
            GroupEnumUnitsInRangeEx(pt.pid, ug, pt2.x, pt2.y, pt2.aoe, Condition(isalive))
        end

        for target in each(ug) do
            if IsUnitAlly(target, Player(pt.pid - 1)) then
                if (BARD_SONG[pt.pid] == SONG_WAR and IsUnitInRange(target, pt.caster, 900.)) or (pt2 and pt2.song == SONG_WAR and IsUnitInRangeXY(target, pt2.x, pt2.y, pt2.aoe)) then
                    SongOfWarBuff:add(pt.caster, target):duration(2.)
                end
                if (BARD_SONG[pt.pid] == SONG_PEACE and IsUnitInRange(target, pt.caster, 900.)) or (pt2 and pt2.song == SONG_PEACE and IsUnitInRangeXY(target, pt2.x, pt2.y, pt2.aoe)) then
                    SongOfPeaceBuff:add(pt.caster, target):duration(2.)
                end
                if (BARD_SONG[pt.pid] == SONG_HARMONY and IsUnitInRange(target, pt.caster, 900.)) or (pt2 and pt2.song == SONG_HARMONY and IsUnitInRangeXY(target, pt2.x, pt2.y, pt2.aoe)) then
                    SongOfHarmonyBuff:add(pt.caster, target):duration(2.)
                end
            elseif not IsUnitAlly(target, Player(pt.pid - 1)) then
                if (BARD_SONG[pt.pid] == SONG_FATIGUE and IsUnitInRange(target, pt.caster, 900.)) or (pt2 and pt2.song == SONG_FATIGUE and IsUnitInRangeXY(target, pt2.x, pt2.y, pt2.aoe)) then
                    SongOfFatigueSlow:add(pt.caster, target):duration(2.)
                end
            end
        end

        pt.timer:callDelayed(1., song_periodic, pt)
    end

    local songeffect = {} ---@type effect[] 

    local function change_song(self, song)
        local p = Player(self.pid - 1)
        local pt = TimerList[self.pid]:get('song')

        if pt then
            pt.song = song
        else
            pt = TimerList[self.pid]:add()
            pt.caster = self.caster
            pt.song = song
            pt.tag = 'song'
            pt.onRemove = function(this)
                BARD_SONG[this.pid] = 0
                SetPlayerAbilityAvailable(Player(this.pid - 1), SONG_FATIGUE, false)
                SetPlayerAbilityAvailable(Player(this.pid - 1), SONG_HARMONY, false)
                SetPlayerAbilityAvailable(Player(this.pid - 1), SONG_PEACE, false)
                SetPlayerAbilityAvailable(Player(this.pid - 1), SONG_WAR, false)
                DestroyEffect(songeffect[this.pid])
            end

            song_periodic(pt)
        end

        BARD_SONG[self.pid] = song
        SetPlayerAbilityAvailable(p, SONG_FATIGUE, false)
        SetPlayerAbilityAvailable(p, SONG_HARMONY, false)
        SetPlayerAbilityAvailable(p, SONG_PEACE, false)
        SetPlayerAbilityAvailable(p, SONG_WAR, false)

        SetPlayerAbilityAvailable(p, song, true)
        if songeffect[self.pid] == nil then
            songeffect[self.pid] = AddSpecialEffectTarget("war3mapImported\\Music effect01.mdx", self.caster, "overhead")
        end
        BlzSetSpecialEffectColorByPlayer(songeffect[self.pid], Player(song_color[song]))
    end

    local SONGSOFTHETRAVELLER = Spell.define("A02F")

    ---@class SONGOFFATIGUE : Spell
    local SONGOFFATIGUE = Spell.define("A025")
    do
        local thistype = SONGOFFATIGUE

        function thistype:onCast()
            change_song(self, SONG_FATIGUE)
        end
    end

    ---@class SONGOFHARMONY : Spell
    local SONGOFHARMONY = Spell.define("A026")
    do
        local thistype = SONGOFHARMONY

        function thistype:onCast()
            change_song(self, SONG_HARMONY)
        end
    end

    ---@class SONGOFPEACE : Spell
    local SONGOFPEACE = Spell.define("A027")
    do
        local thistype = SONGOFPEACE

        function thistype:onCast()
            change_song(self, SONG_PEACE)
        end
    end

    ---@class SONGOFWAR : Spell
    local SONGOFWAR = Spell.define("A02C")
    do
        local thistype = SONGOFWAR

        function thistype:onCast()
            change_song(self, SONG_WAR)
        end
    end

    ---@class ENCORE : Spell
    ---@field aoe number
    ---@field wardur number
    ---@field heal function
    ---@field peacedur number
    ---@field fatiguedur number
    ---@field on_hit function
    ENCORE = Spell.define("A0AZ")
    do
        local thistype = ENCORE

        thistype.values = {
            aoe = 900.,
            wardur = 5.,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return GetHeroInt(Hero[pid], true) * (.75 + .25 * ablev) end,
            peacedur = 5.,
            fatiguedur = 3.,
        }

        function thistype:onCast()
            local ug = CreateGroup()
            local p = Player(self.pid - 1)

            MakeGroupInRange(self.pid, ug, self.x, self.y, self.aoe * LBOOST[self.pid], Condition(isalive))

            -- harmony all allied units
            -- war all allied heroes
            -- fatigue all enemies
            -- peace all heroes

            -- improv
            local pt = TimerList[self.pid]:get(IMPROV.id, nil, self.caster)
            local x2, y2, aoe, song = 0, 0, 0, 0

            if pt then
                GroupEnumUnitsInRangeEx(self.pid, ug, pt.x, pt.y, pt.aoe, Condition(isalive))
                x2 = pt.x
                y2 = pt.y
                aoe = pt.aoe
                song = pt.song ---@type integer 
            end

            for target in each(ug) do
                self.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

                -- allied units
                if IsUnitAlly(target, p) == true then
                    -- song of harmony
                    if (BARD_SONG[self.pid] == SONG_HARMONY and IsUnitInRangeXY(target, self.x, self.y, aoe)) or (song == SONG_HARMONY and IsUnitInRangeXY(target, x2, y2, aoe)) then
                        HP(self.caster, target, self.heal * BOOST[self.pid], thistype.tag)
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", target, "origin"))
                    end
                    -- heroes
                    if target == Hero[self.tpid] then
                        -- song of war
                        if (BARD_SONG[self.pid] == SONG_WAR and IsUnitInRangeXY(target, self.x, self.y, aoe)) or (song == SONG_WAR and IsUnitInRangeXY(target, x2, y2, aoe)) then
                            SongOfWarEncoreBuff:add(self.caster, target):duration(thistype.wardur * LBOOST[self.pid])
                        end
                        -- song of peace
                        if (BARD_SONG[self.pid] == SONG_PEACE and IsUnitInRangeXY(target, self.x, self.y, aoe)) or (song == SONG_PEACE and IsUnitInRangeXY(target, x2, y2, aoe)) then
                            SongOfPeaceEncoreBuff:add(self.caster, target):duration(thistype.peacedur * LBOOST[self.pid])
                        end
                    end
                else
                -- enemies
                    -- song of fatigue
                    if (BARD_SONG[self.pid] == SONG_FATIGUE and IsUnitInRangeXY(target, self.x, self.y, aoe)) or (song == SONG_FATIGUE and IsUnitInRangeXY(target, x2, y2, aoe)) then
                        StunUnit(self.pid, target, thistype.fatiguedur * LBOOST[self.pid])
                    end
                end
            end
        end
    end

    ---@class MELODYOFLIFE : Spell
    ---@field cost function
    ---@field heal function
    MELODYOFLIFE = Spell.define("A02H")
    do
        local thistype = MELODYOFLIFE

        thistype.values = {
            cost = function(pid) return GetUnitState(Hero[pid], UNIT_STATE_MANA) * .1 end,
            heal = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return thistype.cost(pid) * (.25 + .25 * ablev) end,
        }

        function thistype:onCast()
            local p = Player(self.pid - 1)
            local heal = self.heal * BOOST[self.pid] ---@type number 

            if GetUnitTypeId(self.target) == BACKPACK then
                HP(self.caster, Hero[self.tpid], heal, thistype.tag)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", GetUnitX(Hero[self.tpid]), GetUnitY(Hero[self.tpid])))
            elseif IsUnitAlly(self.target, p) then
                HP(self.caster, self.target, heal, thistype.tag)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", self.targetX, self.targetY))
            end
        end

        local manacost = function(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(thistype.values.cost(pid)))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_ON_CAST:register_unit_action(source, manacost)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
            manacost(source)
        end
    end

    ---@class IMPROV : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field dur number
    IMPROV = Spell.define("A06Y")
    do
        local thistype = IMPROV

        thistype.values = {
            aoe = 750.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.25 + 0.25 * ablev) * GetHeroInt(Hero[pid], true) end,
            dur = 20.,
        }

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.time = pt.time + 1.

            if pt.time >= pt.dur then
                BlzSetSpecialEffectScale(pt.sfx, 1.)
                SetUnitScale(pt.source, 1., 1., 1.)
                pt:destroy()
            else
                local ug = CreateGroup()

                MakeGroupInRange(pt.pid, ug, pt.x, pt.y, pt.aoe, Condition(FilterEnemy))

                for target in each(ug) do
                    if ModuloInteger(R2I(pt.time), 2) == 0 then
                        DamageTarget(Hero[pt.pid], target, pt.dmg * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(1., periodic, pt)
            end
        end

        function thistype:onCast()
            if BARD_SONG[self.pid] ~= 0 then
                local pt = TimerList[self.pid]:add()

                pt.x = self.targetX
                pt.y = self.targetY
                pt.song = BARD_SONG[self.pid]
                pt.tag = thistype.id -- important for aura check
                pt.aoe = self.aoe * LBOOST[self.pid]
                pt.dmg = self.dmg
                pt.dur = self.dur * LBOOST[self.pid]
                pt.target = self.caster
                pt.source = Dummy.create(pt.x, pt.y, 0, 0, pt.dur).unit

                SetUnitScale(pt.source, 3., 3., 3.)
                SetUnitOwner(pt.source, Player(PLAYER_TOWN), true)

                --the order matters here
                UnitAddAbility(pt.source, BARD_SONG[self.pid])

                --auras for allies
                if BARD_SONG[self.pid] ~= SONG_FATIGUE then
                    BlzSetAbilityRealLevelField(BlzGetUnitAbility(pt.source, BARD_SONG[self.pid]), ABILITY_RLF_AREA_OF_EFFECT, 0, pt.aoe)
                    IncUnitAbilityLevel(pt.source, BARD_SONG[self.pid])
                    DecUnitAbilityLevel(pt.source, BARD_SONG[self.pid])
                end

                if BARD_SONG[self.pid] == SONG_WAR then
                    pt.sfx = AddSpecialEffectTarget("war3mapImported\\QuestMarkingRed.mdx", pt.source, "origin")
                elseif BARD_SONG[self.pid] == SONG_HARMONY then
                    pt.sfx = AddSpecialEffectTarget("war3mapImported\\QuestMarkingGreen.mdx", pt.source, "origin")
                elseif BARD_SONG[self.pid] == SONG_PEACE then
                    pt.sfx = AddSpecialEffectTarget("war3mapImported\\QuestMarkingYellow.mdx", pt.source, "origin")
                elseif BARD_SONG[self.pid] == SONG_FATIGUE then
                    pt.sfx = AddSpecialEffectTarget("war3mapImported\\QuestMarkingPurple.mdx", pt.source, "origin")
                end

                BlzSetSpecialEffectScale(pt.sfx, 4.5)

                pt.timer:callDelayed(1., periodic, pt)
            end
        end
    end

    ---@class INSPIRE : Spell
    INSPIRE = Spell.define("A09Y")
    do
        local thistype = INSPIRE

        function thistype:onCast()
            InspireBuff:add(self.caster, self.caster)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.02))
        end

        local function on_order(source, target, id)
            if id == ORDER_ID_UNIMMOLATION then
                if IsUnitPaused(source) == false and IsUnitLoaded(source) == false then
                    InspireBuff:dispel(source, source)
                end
            end
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
            EVENT_ON_ORDER:register_unit_action(source, on_order)
        end
    end

    ---@class TONEOFDEATH : Spell
    ---@field aoe number
    ---@field dmg function
    ---@field dur number
    TONEOFDEATH = Spell.define("A02K")
    do
        local thistype = TONEOFDEATH

        thistype.values = {
            aoe = 350.,
            dmg = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) return (0.5 + 0.5 * ablev) * GetHeroInt(Hero[pid], true) end,
            dur = 5.,
        }

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight,
                CAT_Orient2D,
                CAT_Decay,
            },
            identifier = "missile",
            speed = 125.,
            visualZ = 75.,
        }
        missile_template.__index = missile_template

        local SWIRL_RADIUS  = 130    -- distance at which swirling starts
        local MAX_SWIRL_FORCE = 20   -- max tangential speed when right on top

        local function pull_force(target, missile)
            local x, y = GetUnitX(target), GetUnitY(target)
            local dx, dy = missile.x - x, missile.y - y
            local dist  = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan(dy, dx)

            -- radial pull strength
            local pull
            if dist > 80 then
                pull = 5000.0 / dist
            else
                pull = 2.0
            end

            -- compute pull vector
            local fx = pull * math.cos(angle)
            local fy = pull * math.sin(angle)

            if dist < SWIRL_RADIUS then
                local swirl_strength = MAX_SWIRL_FORCE * (1 - dist / SWIRL_RADIUS)
                local perp = angle + (math.pi * 0.5)
                fx = fx + swirl_strength * math.cos(perp)
                fy = fy + swirl_strength * math.sin(perp)
            end

            -- apply movement if walkable
            local nx, ny = x + fx, y + fy
            if IsTerrainWalkable(nx, ny) then
                SetUnitXBounded(target, nx)
                SetUnitYBounded(target, ny)
            end
        end

        local function pull(missile)
            if missile.lifetime > 0 then
                ALICE_ForAllObjectsInRangeDo(pull_force, missile.x, missile.y, 800., "nonhero", valid_pull_target, missile)
                TimerQueue:callDelayed(FPS_32, pull, missile)
            end
        end

        local function do_damage(object, missile)
            DamageTarget(missile.source, object, missile.dmg * BOOST[missile.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end

        local function damage(missile)
            if missile.lifetime > 0 then
                ALICE_ForAllObjectsInRangeDo(do_damage, missile.x, missile.y, missile.aoe, "unit", valid_damage_target, missile)
                TimerQueue:callDelayed(1., damage, missile)
            end
        end

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.z = GetUnitZ(self.caster)
            missile.visual = AddSpecialEffect("war3mapImported\\BlackHoleSpell.mdx", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 0.5)
            missile.launchOffset = 250.
            missile.vx = missile.speed * math.cos(self.angle)
            missile.vy = missile.speed * math.sin(self.angle)
            missile.owner = Player(self.pid - 1)
            missile.source = self.caster
            missile.aoe = self.aoe * LBOOST[self.pid]
            missile.dmg = self.dmg
            missile.pid = self.pid
            missile.lifetime = self.dur * LBOOST[self.pid]

            ALICE_Create(missile)

            TimerQueue:callDelayed(0.25, damage, missile)
            TimerQueue:callDelayed(FPS_32, pull, missile)
        end

        local manacost = function(u)
            BlzSetUnitAbilityManaCost(u, thistype.id, GetUnitAbilityLevel(u, thistype.id) - 1, R2I(BlzGetUnitMaxMana(u) * 0.2))
        end

        function thistype.onLearn(source, ablev, pid)
            EVENT_STAT_CHANGE:register_unit_action(source, manacost)
        end
    end
end, Debug and Debug.getLine())
