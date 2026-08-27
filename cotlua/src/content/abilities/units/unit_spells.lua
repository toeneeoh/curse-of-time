--[[
    unitspells.lua

    Defines any spells used by units and summons that don't have dynamic tooltips
]]

OnInit.final("UnitSpells", function(Require)
    Require("Spells")

    local TQ = TimerQueue
    local random = math.random
    local FPS_32 = FPS_32
    local distance = MISSILE_DISTANCE

    IS_HERO_PANEL_ON = {} ---@type boolean[] 

    ---@return boolean
    local function HeroPanelClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            local id = pid * PLAYER_CAP + dw.data[index] ---@type integer 

            IS_HERO_PANEL_ON[id] = (not IS_HERO_PANEL_ON[id])
            ShowHeroPanel(GetTriggerPlayer(), Player(dw.data[index] - 1), IS_HERO_PANEL_ON[id])

            dw:destroy()
        end

        return false
    end

    ---@param pid integer
    local function DisplayHeroPanel(pid)
        local dw = DialogWindow.create(pid, "", HeroPanelClick) ---@type DialogWindow 
        local U  = User.first ---@type User 

        while U do
            if pid ~= U.id and Profile[U.id].playing then
                dw:addButton(U.nameColored, U.id)
            end

            U = U.next
        end

        dw:display()
    end

    -- Runs upon selecting a backpack
    ---@return boolean
    function BackpackSkinClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 
        
        if index ~= -1 then
            index = dw.data[index]
            if CosmeticTable[User[pid - 1].name][index] == 0 and not CosmeticTable.skins[index].public then
                DisplayTextToPlayer(GetTriggerPlayer(), 0, 0, CosmeticTable.skins[index].error)
            else
                Profile[pid]:skin(index)
            end

            dw:destroy()
        end

        return false
    end

    -- Displays backpack selection dialog
    ---@param pid integer
    function BackpackSkin(pid)
        local name = User[pid - 1].name
        local dw   = DialogWindow.create(pid, "Select Appearance", BackpackSkinClick) ---@type DialogWindow 

        for i, v in ipairs(CosmeticTable.skins) do
            local text = ((v.req and CosmeticTable[name][i] > 0) and "|cff00ff00" .. v.name .. "|r") or v.name

            if CosmeticTable[name][i] > 0 or v.public == true then
                dw:addButton(text, i)
            end
        end

        dw:display()
    end

    -- Runs upon selecting a cosmetic
    ---@return boolean
    function CosmeticButtonClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            CosmeticTable.cosmetics[dw.data[index]]:effect(pid)

            dw:destroy()
        end

        return false
    end

    -- Displays cosmetic selection dialog
    ---@param pid integer
    function DisplaySpecialEffects(pid)
        local name = User[pid - 1].name
        local dw   = DialogWindow.create(pid, "", CosmeticButtonClick) ---@type DialogWindow 

        for i, v in ipairs(CosmeticTable.cosmetics) do
            if CosmeticTable[name][i + DONATOR_AURA_OFFSET] > 0 then
                dw:addButton(v.name, i)
            end
        end

        dw:display()
    end

    local mouse_move = function(pid, x, y, x2, y2)
        if IS_M2_DOWN[pid] and IsUnitSelected(Hero[pid], Player(pid - 1)) then
            local dist = DistanceCoords(x, y, x2, y2)

            if dist >= 3 then
                local ug = CreateGroup()
                GroupEnumUnitsInRange(ug, x, y, 15.0, Condition(ishostile))

                local target = FirstOfGroup(ug)
                if not target then
                    IssuePointOrder(Hero[pid], "smart", x, y)
                elseif GetUnitCurrentOrder(Hero[pid]) ~= OrderId("attack") then
                    IssueTargetOrder(Hero[pid], "attack", target)
                end

                DestroyGroup(ug)
            end
        end
    end

    local function unselect_bp(pid)
        local p = Player(pid - 1)

        if IsUnitSelected(Hero[pid], p) and IsUnitSelected(Backpack[pid], p) then
            if GetLocalPlayer() == p then
                SelectUnit(Backpack[pid], false)
            end
        end
    end

    DMG_NUMBERS = __jarray(0) ---@type integer[] 

    -- fairly simple spells
    UNIT_SPELLS = {
        [FourCC('A00I')] = function(_, pid) -- change hotkeys
            ChangeHotkeys(pid)
        end,

        [FourCC('A0KI')] = function(caster, pid) -- meat golem taunt
            Taunt(caster, 800.)
        end,

        [FourCC('A00Y')] = function(_, pid) -- Item drop toggle
            if IS_ITEM_DROP[pid] then
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Item Drops off.")
            else
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Item Drops on")
            end

            IS_ITEM_DROP[pid] = not IS_ITEM_DROP[pid]
        end,

        [FourCC('A00B')] = function(_, pid) -- Movement Toggle
            if EVENT_ON_MOUSE_MOVE:register_action(pid, mouse_move) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Movement Toggle enabled.")
            else
                EVENT_ON_MOUSE_MOVE:unregister_action(pid, mouse_move)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Movement Toggle disabled.")
            end
        end,

        [FourCC('A02T')] = function(_, pid) -- Hero Panels
            DisplayHeroPanel(pid)
        end,

        [FourCC('A031')] = function(_, pid) -- Damage Numbers
            if DMG_NUMBERS[pid] == 0 then
                DMG_NUMBERS[pid] = 1
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers for allied damage received disabled.")
            elseif DMG_NUMBERS[pid] == 1 then
                DMG_NUMBERS[pid] = 2
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers for all damage disabled.")
            else
                DMG_NUMBERS[pid] = 0
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers enabled.")
            end
        end,

        [FourCC('A067')] = function(_, pid) -- Deselect Backpack
            if EVENT_ON_SELECT:register_action(pid, unselect_bp) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Deselect Backpack enabled.")
            else
                EVENT_ON_SELECT:unregister_action(pid, unselect_bp)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Deselect Backpack disabled.")
            end
        end,
        [FourCC('A0KX')] = function(_, pid) -- Change Skin
            BackpackSkin(pid)
        end,

        [FourCC('A04N')] = function(_, pid) -- Special Effects
            DisplaySpecialEffects(pid)
        end,
    }

    BORROWED_LIFE = Spell.define('A071')
    do
        local thistype = BORROWED_LIFE

        function thistype:onCast()
            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local time = 120

                if self.ablev > 1 then
                    time = time / ((self.ablev - 1) * 2) --60, 30, 20, 15
                end

                Unit[self.target].borrowed_life = time
            end
        end
    end

    DEVOUR_GOLEM = Spell.define('A06C')
    do
        local thistype = DEVOUR_GOLEM

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            visualZ = 50.,
            speed = 900.,
            arc = 0.5,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                local golem = Unit[self.source]

                golem.borrowed_life = 0
                golem.bonus_str = golem.bonus_str - R2I(golem.str * 0.1 * golem.devour_stacks)
                if golem.devour_stacks > 0 then
                    golem.mr = golem.mr / (0.75 - golem.devour_stacks * 0.1)
                end
                golem.devour_stacks = golem.devour_stacks + 1
                BlzSetHeroProperName(self.source, "Meat Golem (" .. (golem.devour_stacks) .. ")")
                FloatingTextUnit(tostring(golem.devour_stacks), self.source, 1, 60, 50, 13.5, 255, 255, 255, 0, true)
                golem.bonus_str = golem.bonus_str + R2I(golem.str * 0.1 * golem.devour_stacks)
                SetUnitScale(self.source, 1 + golem.devour_stacks * 0.07, 1 + golem.devour_stacks * 0.07, 1 + golem.devour_stacks * 0.07)
                --magnetic
                if golem.devour_stacks == 1 then
                    UnitAddAbility(self.source, BORROWED_LIFE.id)
                elseif golem.devour_stacks == 2 then
                    UnitAddAbility(self.source, MAGNETIC_FORCE.id)
                --thunder clap
                elseif golem.devour_stacks == 3 then
                    UnitAddAbility(self.source, THUNDER_CLAP_GOLEM.id)
                elseif golem.devour_stacks == 5 then
                    golem.bonus_armor = golem.bonus_armor + R2I(BlzGetUnitArmor(self.source) * 0.25 + 0.5)
                end
                if golem.devour_stacks >= GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                    UnitDisableAbility(self.source, thistype.id, true)
                end
                SetUnitAbilityLevel(self.source, BORROWED_LIFE.id, golem.devour_stacks)

                --magic resist -(25-30) percent
                golem.mr = golem.mr * (0.75 - golem.devour_stacks * 0.1)
            end,
        }

        function thistype:onCast()
            local golem = Unit[self.source]

            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) and golem.devour_stacks < GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local missile = setmetatable({}, missile_template)
                missile.x = GetUnitX(self.target)
                missile.y = GetUnitY(self.target)
                missile.z = GetUnitZ(self.target)
                missile.visual = AddSpecialEffect("war3mapImported\\Haunt_v2_Portrait.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.1)
                missile.source = self.caster
                missile.target = self.caster
                missile.collideZ = true
                missile.owner = Player(self.pid - 1)
                missile.pid = self.pid

                ALICE_Create(missile)
            end
        end
    end

    DEVOUR_DESTROYER = Spell.define('A04Z')
    do
        local thistype = DEVOUR_DESTROYER

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            visualZ = 50.,
            speed = 900.,
            arc = 0.5,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                local destroyer = Unit[self.source]

                destroyer.borrowed_life = 0
                destroyer.bonus_int = destroyer.bonus_int - R2I(Unit[self.source].int * 0.15 * destroyer.devour_stacks)
                destroyer.devour_stacks = destroyer.devour_stacks + 1
                destroyer.bonus_int = destroyer.bonus_int + R2I(Unit[self.source].int * 0.15 * destroyer.devour_stacks)
                BlzSetHeroProperName(self.source, "Destroyer (" .. (destroyer.devour_stacks) .. ")")
                FloatingTextUnit(tostring(destroyer.devour_stacks), self.source, 1, 60, 50, 13.5, 255, 255, 255, 0, true)
                if destroyer.devour_stacks == 1 then
                    UnitAddAbility(self.source, BORROWED_LIFE.id)
                    UnitAddAbility(self.source, FourCC('A061')) --blink
                elseif destroyer.devour_stacks == 2 then
                    UnitAddAbility(self.source, FourCC('A03B')) --crit
                    destroyer.cc_flat = destroyer.cc_flat + 25
                    destroyer.cd_flat = destroyer.cd_flat + 200
                elseif destroyer.devour_stacks == 3 then
                    destroyer.agi = 200
                elseif destroyer.devour_stacks == 4 then
                    SetUnitAbilityLevel(self.source, FourCC('A02D'), 2)
                elseif destroyer.devour_stacks == 5 then
                    destroyer.agi = 400
                    destroyer.bonus_int = destroyer.bonus_int + R2I(Unit[self.source].int * 0.25)
                end
                if destroyer.devour_stacks >= GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                    UnitDisableAbility(self.source, thistype.id, true)
                end
                SetUnitAbilityLevel(self.source, BORROWED_LIFE.id, destroyer.devour_stacks)
            end,
        }

        function thistype:onCast()
            local destroyer = Unit[self.caster]
            if GetUnitTypeId(self.target) == SUMMON_HOUND and GetOwningPlayer(self.target) == Player(self.pid - 1) and destroyer.devour_stacks < GetUnitAbilityLevel(Hero[self.pid], DEVOUR.id) + 1 then
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", self.target, "chest"))
                SummonExpire(self.target)

                local missile = setmetatable({}, missile_template)
                missile.x = GetUnitX(self.target)
                missile.y = GetUnitY(self.target)
                missile.z = GetUnitZ(self.target)
                missile.visual = AddSpecialEffect("war3mapImported\\Haunt_v2_Portrait.mdl", self.x, self.y)
                BlzSetSpecialEffectScale(missile.visual, 1.1)
                missile.source = self.caster
                missile.target = self.caster
                missile.collideZ = true
                missile.owner = Player(self.pid - 1)
                missile.pid = self.pid

                ALICE_Create(missile)
            end
        end
    end

    MAGNETIC_FORCE = Spell.define('A06O')
    do
        local thistype = MAGNETIC_FORCE

        ---@type fun(pid: integer, caster: unit, dur: number)
        local function pull(pid, caster, dur)
            dur = dur - 0.05

            if dur > 0 then
                local ug = CreateGroup()

                MakeGroupInRange(pid, ug, GetUnitX(caster), GetUnitY(caster), 600. * LBOOST[pid], Condition(FilterEnemy))

                for target in each(ug) do
                    local angle = math.atan(GetUnitY(caster) - GetUnitY(target), GetUnitX(caster) - GetUnitX(target))
                    if GetUnitMoveSpeed(target) > 0 and IsTerrainWalkable(GetUnitX(target) + (7. * math.cos(angle)), GetUnitY(target) + (7. * math.sin(angle))) then
                        SetUnitXBounded(target, GetUnitX(target) + (7. * math.cos(angle)))
                        SetUnitYBounded(target, GetUnitY(target) + (7. * math.sin(angle)))
                    end
                end

                TQ:callDelayed(0.05, pull, pid, dur)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            TQ:callDelayed(0.05, pull, self.pid, self.caster, 10)
        end
    end

    THUNDER_CLAP_GOLEM = Spell.define('A0B0')
    do
        local thistype = THUNDER_CLAP_GOLEM

        function thistype:onCast()
            local ug = CreateGroup()
            MakeGroupInRange(self.pid, ug, self.x, self.y, 300., Condition(FilterEnemy))

            for target in each(ug) do
                MeatGolemThunderClap:add(self.caster, target):duration(3.)
            end

            DestroyGroup(ug)
        end
    end

    TELEPORT = Spell.define('A02J')
    do
        local thistype = TELEPORT

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= MAIN_MAP.rect or r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't teleport there.")
            end
        end

        local function on_expire(pt)
            local x, y = GetUnitX(pt.source), GetUnitY(pt.source)
            Unit[pt.source].busy = false
            BlzPauseUnitEx(Backpack[pt.pid], false)

            if UnitAlive(pt.source) then
                SetUnitPosition(pt.source, pt.x, pt.y)
                SetUnitPosition(Backpack[pt.pid], pt.x, pt.y)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", pt.x, pt.y))
            end
        end

        ---@type fun(pid: integer, u: unit, dur: number)
        local function teleport(pid, u, dur)
            local pt = TimerList[pid]:add()
            local x, y = GetUnitX(u), GetUnitY(u)
            pt.source = Hero[pid]
            pt.x = x
            pt.y = y

            Unit[Hero[pid]].busy = true
            BlzPauseUnitEx(Backpack[pid], true)
            TQ:callDelayed(dur, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl", x, y))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", Backpack[pid], "origin"))

            pt:after(dur, on_expire)
        end

        function thistype:onCast()
            if self.ablev > 1 then
                teleport(self.pid, self.target, 3 - self.ablev * .25)
            else
                teleport(self.pid, self.target, 3)
            end
        end
    end

    TELEPORT_HOME = Spell.define('A0FV')
    do
        local thistype = TELEPORT_HOME

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)

            if not (r == MAIN_MAP.rect or r == gg_rct_Cave or r == gg_rct_Gods_Arena or r == gg_rct_Tavern) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't teleport here.")
            end
        end

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - FPS_32

            BlzSetSpecialEffectTime(pt.sfx, math.max(0, 1. - pt.dur / pt.time))

            if pt.dur >= 0 then
                return true
            end

            Unit[pt.source].busy = false
            PauseUnit(pt.source, false)
            PauseUnit(Backpack[pt.pid], false)
            MoveHero(pt.pid, TOWN_CENTER_X, TOWN_CENTER_Y)
            BlzSetSpecialEffectTimeScale(pt.sfx, 5.)
            BlzPlaySpecialEffect(pt.sfx, ANIM_TYPE_DEATH)

            return false
        end

        ---@param pid integer
        ---@param dur integer
        local function teleport(pid, caster, dur)
            local pt = TimerList[pid]:add()

            Unit[caster].busy = true
            PauseUnit(Backpack[pid], true)
            PauseUnit(caster, true)

            pt.source = caster
            pt.dur = dur
            pt.time = dur
            pt.sfx = AddSpecialEffect("war3mapImported\\Progressbar.mdl", GetUnitX(caster), GetUnitY(caster))

            BlzSetSpecialEffectZ(pt.sfx, BlzGetUnitZ(caster) + 200.0)
            BlzSetSpecialEffectTimeScale(pt.sfx, 0.001)
            BlzSetSpecialEffectColorByPlayer(pt.sfx, Player(4))
            pt:startLoop(FPS_32, periodic)
        end

        function thistype:onCast()
            if self.ablev > 1 then
                teleport(self.pid, self.caster, 11 - self.ablev)
            else
                teleport(self.pid, self.caster, 12)
            end
        end
    end

    local URSA_FROST_NOVA = Spell.define('ACfn')
    do
        local thistype = URSA_FROST_NOVA

        local function onStruck(target, source)
            IssueTargetOrder(target, "frostnova", source)
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TENTACLE = Spell.define('A0AJ')
    do
        local thistype = TENTACLE

        local function onStruck(target, source)
            if random(1, 5) == 1 then
                IssueImmediateOrder(target, "waterelemental")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SHOCKWAVE = Spell.define("A02L")
    do
        local thistype = SHOCKWAVE

        local missile_template = {
            selfInteractions = {
                CAT_MoveAutoHeight,
                CAT_Orient2D,
                distance,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
            },
            identifier = "missile",
            collisionRadius = 100.,
            friendlyFire = false,
            visualZ = 75.,
            speed = 1000.,
            onUnitCollision = CAT_UnitPassThrough2D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, 6000., ATTACK_TYPE_NORMAL, MAGIC, "Shockwave")
            end,
        }

        local function onStruck(target, source)
            if UnitDistance(source, target) < 600. then
                if CastSpell(target, thistype.id, 1., 15, 1) then
                    local x, y = GetUnitX(target), GetUnitY(target)
                    local angle = math.atan(GetUnitX(source) - y, GetUnitY(source) - x)
                    local missile = setmetatable({}, missile_template)
                    missile.x = x
                    missile.y = y
                    missile.vx = missile.speed * math.cos(angle)
                    missile.vy = missile.speed * math.sin(angle)
                    missile.visual = AddSpecialEffect("Abilities\\Spells\\Orc\\Shockwave\\ShockwaveMissile.mdl", x, y)
                    BlzSetSpecialEffectScale(missile.visual, 1.1)
                    missile.source = target
                    missile.owner = GetOwningPlayer(target)

                    ALICE_Create(missile)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local RAISE_SKELETON = Spell.define("A01H")
    do
        local thistype = RAISE_SKELETON

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 1.5, 8, 1.) then
                for i = 0, 4 do
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\RaiseSkeletonWarrior\\RaiseSkeleton.mdl", GetUnitX(target) + 80. * math.cos(bj_PI * i * 0.4), GetUnitY(target) + 80. * math.sin(bj_PI * i * 0.4)))
                    local dummy = CreateUnit(PLAYER_BOSS, FourCC('n00E'), GetUnitX(target) + 80. * math.cos(bj_PI * i * 0.4), GetUnitY(target) + 80. * math.sin(bj_PI * i * 0.4), GetUnitFacing(target))
                    CastSpell(dummy, 0, 1.5, 9, 1.)
                    UnitApplyTimedLife(dummy, FourCC('BTLF'), 30.)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DROP_ITEM = Spell.define("A015")
    do
        local thistype = DROP_ITEM

        function thistype.preCast(pid, _, _, _, _, _, targetX, targetY)
            local hero = Profile[pid].hero
            local item = hero.item_to_drop

            if item then
                local itm = hero.items[item.index]
                if itm then
                    itm:drop(targetX, targetY)
                end
            end
        end
    end
end, Debug and Debug.getLine())
