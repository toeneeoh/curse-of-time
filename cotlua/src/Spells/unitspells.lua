--[[
    unitspells.lua

    Defines any spells used by units and summons that don't have dynamic tooltips
]]

OnInit.final("UnitSpells", function(Require)
    Require("Spells")

    local random = math.random
    local FPS_32 = FPS_32

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

    ---@type fun(boss: unit, baseDamage: integer, effectability: integer, AOE: number, tag: string)
    local function BossBlastTaper(boss, baseDamage, effectability, AOE, tag)
        local castx = GetUnitX(boss) ---@type number 
        local casty = GetUnitY(boss) ---@type number 
        local dx    = 0. ---@type number 
        local dy    = 0. ---@type number 
        local ug    = CreateGroup()

        for i = 1, 18 do
            local angle = bj_PI * i /9.
            local dummy = Dummy.create(castx, casty, effectability, 1).unit
            SetUnitFlyHeight(dummy, 150., 0)
            IssuePointOrder(dummy, "breathoffire", castx + 40 * math.cos(angle), casty + 40 * math.sin(angle))
        end
        GroupEnumUnitsInRange(ug, castx, casty, AOE, Condition(ishostileEnemy))
        for target in each(ug) do
            --call DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\LordofFlameMissile\\LordofFlameMissile.mdl", GetUnitX(target), GetUnitY(target)))
            dx= GetUnitX(target) - castx
            dy= GetUnitY(target) - casty
            local dist = SquareRoot(dx * dx +dy * dy)
            if dist < 150 then
                DamageTarget(boss,target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
            else
                DamageTarget(boss,target, baseDamage / (dist / 200.), ATTACK_TYPE_NORMAL, MAGIC, tag)
            end
        end

        DestroyGroup(ug)
        PauseUnit(boss, false)
    end

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, speffect: string, tag: string)
    local function BossPlusSpell(boss, baseDamage, hgroup, speffect, tag)
        local castx = GetUnitX(boss) ---@type number 
        local casty = GetUnitY(boss) ---@type number 
        local dx ---@type number 
        local dy ---@type number 

        if UnitAlive(boss) then
            for i = -8, 8 do
                DestroyEffect(AddSpecialEffect(speffect, castx + 80 * i, casty - 75))
                DestroyEffect(AddSpecialEffect(speffect, castx + 80 * i, casty + 75))
                DestroyEffect(AddSpecialEffect(speffect, castx - 75, casty + 80 * i))
                DestroyEffect(AddSpecialEffect(speffect, castx + 75, casty + 80 * i))
            end

            local ug = CreateGroup()

            GroupEnumUnitsInRange(ug, castx, casty, 750, Condition(ishostileEnemy))

            for target in each(ug) do
                --call DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\LordofFlameMissile\\LordofFlameMissile.mdl", GetUnitX(target), GetUnitY(target)))
                dx = RAbsBJ(GetUnitX(target) - castx)
                dy = RAbsBJ(GetUnitY(target) - casty)
                if dx < 150 and dy < 700 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                elseif dx < 700 and dy < 150 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                end
            end

            DestroyGroup(ug)
        end
    end

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, speffect: string, tag: string)
    local function BossXSpell(boss, baseDamage, hgroup, speffect, tag)
        local castx      = GetUnitX(boss) ---@type number 
        local casty      = GetUnitY(boss) ---@type number 
        local dx ---@type number 
        local dy ---@type number 

        if UnitAlive(boss) then
            for i = -8, 8 do
                DestroyEffect(AddSpecialEffect(speffect, castx + 75 * i, casty + 75 * i))
                DestroyEffect(AddSpecialEffect(speffect, castx + 75 * i, casty - 75 * i))
            end

            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, castx, casty, 750, Condition(ishostileEnemy))

            for target in each(ug) do
                dx = RAbsBJ(GetUnitX(target) - castx)
                dy = RAbsBJ(GetUnitY(target) - casty)
                if RAbsBJ(dx - dy) < 200 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                end
            end

            DestroyGroup(ug)
        end
    end

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, AOE: number, speffect: string, tag: string)
    local function BossInnerRing(boss, baseDamage, hgroup, AOE, speffect, tag)
        local castx = GetUnitX(boss) ---@type number 
        local casty = GetUnitY(boss) ---@type number 
        local angle ---@type number 

        for i = 0, 6 do
            angle= bj_PI *i /3.
            DestroyEffect(AddSpecialEffect(speffect, castx +AOE*.4 * math.cos(angle), casty +AOE*.4 * math.sin(angle)))
            DestroyEffect(AddSpecialEffect(speffect, castx +AOE*.8 * math.cos(angle), casty +AOE*.8 * math.sin(angle)))
        end

        local ug = CreateGroup()
        GroupEnumUnitsInRange(ug, castx, casty, AOE, Condition(ishostileEnemy))

        for target in each(ug) do
            --call DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\LordofFlameMissile\\LordofFlameMissile.mdl", GetUnitX(target), GetUnitY(target)))
            DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
        end

        DestroyGroup(ug)
    end

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, innerRadius: number, outerRadius: number, speffect: string, tag: string)
    local function BossOuterRing(boss, baseDamage, hgroup, innerRadius, outerRadius, speffect, tag)
        local castx = GetUnitX(boss) ---@type number 
        local casty = GetUnitY(boss) ---@type number 
        local dx    = 0. ---@type number 
        local dy    = 0. ---@type number 
        local angle = 0. ---@type number 
        local distance = outerRadius - innerRadius ---@type number 

        for i = 0, 10 do
            angle = bj_PI * i / 5.
            DestroyEffect(AddSpecialEffect(speffect, castx + (innerRadius + distance / 6.) * math.cos(angle), casty + (innerRadius + distance / 6.) * math.sin(angle)))
            DestroyEffect(AddSpecialEffect(speffect, castx + (outerRadius - distance / 6.) * math.cos(angle), casty + (outerRadius - distance / 6.) * math.sin(angle)))
        end

        local ug = CreateGroup()
        GroupEnumUnitsInRange(ug, castx, casty, outerRadius, Condition(ishostileEnemy))

        for target in each(ug) do
            dx = GetUnitX(target) - castx
            dy = GetUnitY(target) - casty
            distance = SquareRoot(dx * dx + dy * dy)
            if distance > innerRadius then
                DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
            end
        end

        DestroyGroup(ug)
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
                    UnitAddBonus(self.source, BONUS_ARMOR, R2I(BlzGetUnitArmor(self.source) * 0.25 + 0.5))
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

                TimerQueue:callDelayed(0.05, pull, pid, dur)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            TimerQueue:callDelayed(0.05, pull, self.pid, self.caster, 10)
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

        ---@type fun(pid: integer, u: unit, dur: number)
        local function teleport(pid, u, dur)
            local pt = TimerList[pid]:add()
            local x, y = GetUnitX(u), GetUnitY(u)

            Unit[Hero[pid]].busy = true
            BlzPauseUnitEx(Backpack[pid], true)
            TimerQueue:callDelayed(dur, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl", x, y))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl", Backpack[pid], "origin"))
            pt.onRemove = function()
                Unit[Hero[pid]].busy = false
                BlzPauseUnitEx(Backpack[pid], false)

                if UnitAlive(Hero[pid]) and GetRectFromCoords(GetUnitX(Hero[pid]), GetUnitY(Hero[pid])) == GetRectFromCoords(x, y) then
                    SetUnitPosition(Hero[pid], x, y)
                    SetUnitPosition(Backpack[pid], x, y)
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", GetUnitX(Hero[pid]), GetUnitY(Hero[pid])))
                end
            end

            pt.timer:callDelayed(dur, PlayerTimer.destroy, pt)
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

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.dur = pt.dur - FPS_32

            BlzSetSpecialEffectTime(pt.sfx, math.max(0, 1. - pt.dur / pt.time))

            if pt.dur < 0 then
                pt:destroy()
            else
                pt.timer:callDelayed(FPS_32, periodic, pt)
            end
        end

        ---@param pid integer
        ---@param dur integer
        local function teleport(pid, caster, dur)
            local pt = TimerList[pid]:add()

            Unit[caster].busy = true
            PauseUnit(Backpack[pid], true)
            PauseUnit(caster, true)
            UnitAddAbility(caster, FourCC('A050'))
            BlzUnitHideAbility(caster, FourCC('A050'), true)

            pt.dur = dur
            pt.time = dur
            pt.sfx = AddSpecialEffect("war3mapImported\\Progressbar.mdl", GetUnitX(caster), GetUnitY(caster))
            pt.onRemove = function()
                Unit[caster].busy = false
                UnitRemoveAbility(caster, FourCC('A050'))
                PauseUnit(caster, false)
                PauseUnit(Backpack[pid], false)

                MoveHeroLoc(pid, TOWN_CENTER)

                BlzSetSpecialEffectTimeScale(pt.sfx, 5.)
                BlzPlaySpecialEffect(pt.sfx, ANIM_TYPE_DEATH)
            end

            BlzSetSpecialEffectZ(pt.sfx, BlzGetUnitZ(caster) + 200.0)
            BlzSetSpecialEffectTimeScale(pt.sfx, 0.001)
            BlzSetSpecialEffectColorByPlayer(pt.sfx, Player(4))
            pt.timer:callDelayed(FPS_32, periodic, pt)
        end

        function thistype:onCast()
            if self.ablev > 1 then
                teleport(self.pid, self.caster, 11 - self.ablev)
            else
                teleport(self.pid, self.caster, 12)
            end
        end
    end

    local MAGIC_RESIST = Spell.define('A04A')
    do
        local thistype = MAGIC_RESIST

        function thistype.setup(u)
            Unit[u].mr = Unit[u].mr * 0.7
        end
    end

    local URSA_FROST_NOVA = Spell.define('ACfn')
    do
        local thistype = URSA_FROST_NOVA

        local function onStruck(target, source)
            IssueTargetOrder(target, "frostnova", source)
        end

        function thistype.setup(u)
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

    local REALITY_RIP = Spell.define('A06M')
    do
        local thistype = REALITY_RIP

        local function onHit(source, target)
            local dmg = (IsUnitIllusion(source) and BlzGetUnitMaxHP(target) * 0.0025) or BlzGetUnitMaxHP(target) * 0.005
            DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local DECAY = Spell.define('A08N')
    do
        local thistype = DECAY

        local function onHit(source, target)
            if random(0, 99) < 20 then
                DamageTarget(source, target, 2500., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", target, "origin"))
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local SPELL_REFLECT = Spell.define('A00S')
    do
        local thistype = SPELL_REFLECT

        local function onStruck(target, source, amount)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and amount.value > 10000. then
                local angle = math.atan(GetUnitY(source) - GetUnitY(target), GetUnitX(source) - GetUnitX(target))
                local sfx = AddSpecialEffect("war3mapImported\\BoneArmorCasterTC.mdx", GetUnitX(target) + 75. * math.cos(angle), GetUnitY(target) + 75. * math.sin(angle))

                BlzSetSpecialEffectZ(sfx, BlzGetUnitZ(target) + 80.)
                BlzSetSpecialEffectColorByPlayer(sfx, Player(0))
                BlzSetSpecialEffectYaw(sfx, angle)
                BlzSetSpecialEffectScale(sfx, 0.9)
                BlzSetSpecialEffectTimeScale(sfx, 3.)

                DestroyEffect(sfx)

                BlzStartUnitAbilityCooldown(target, thistype.id, 5.)
                --call DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ManaShield\\ManaShieldCaster.mdl", target, "origin"))
                DamageTarget(target, source, math.min(amount.value, 2500), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)

                amount.value = math.max(0, amount.value - 20000)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(u, onStruck)
        end
    end

    local MANA_SHIELD = Spell.define('A062')
    do
        local thistype = MANA_SHIELD

        local function onStruck(target, source, amount, amount_after_red)
            local taken = amount_after_red / 3.
            local dmg = GetUnitState(target, UNIT_STATE_MANA) - taken

            if dmg >= 0. then
                ArcingTextTag.create(taken, target, 1, 1, 170, 50, 220, 0)
                UnitAddAbility(target, FourCC('A058'))
            else
                UnitRemoveAbility(target, FourCC('A058'))
            end

            SetUnitState(target, UNIT_STATE_MANA, math.max(0., dmg))

            amount.value = math.max(0., 0. - dmg * 3.)
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK_AFTER_REDUCTIONS:register_unit_action(u, onStruck)
        end
    end

    local BERSERK = Spell.define('A04V')
    do
        local thistype = BERSERK

        local function apply_attack_speed(source)
            if UnitAlive(source) then
                NagaBerserkBuff:add(source, source):duration(4.)
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Enrage", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TimerQueue:callDelayed(2., apply_attack_speed, self.caster)
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) == 0 and GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local MIASMA = Spell.define('A04W')
    do
        local thistype = MIASMA

        local function periodic(caster, time)
            time = time - 1

            if time > 0 then
                local ug = CreateGroup()

                GroupEnumUnitsInRect(ug, gg_rct_Naga_Dungeon, Condition(isplayerunit))

                for target in each(ug) do
                    if ModuloInteger(time, 2) == 0 then
                        TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget("Units\\Undead\\PlagueCloud\\PlagueCloudtarget.mdl", target, "overhead"))
                    end
                    DamageTarget(caster, target, 25000 + BlzGetUnitMaxHP(target) * 0.03, ATTACK_TYPE_NORMAL, MAGIC, "Miasma")
                end
                TimerQueue:callDelayed(0.5, periodic, caster, time)

                DestroyGroup(ug)
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Miasma", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            SetUnitAnimation(self.caster, "channel")
            TimerQueue:callDelayed(2., periodic, self.caster, 41)
            for i = 0, 3 do
                local sfx = AddSpecialEffect("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", self.x + 175 * math.cos(bj_PI * i / 2 + (bj_PI / 4.)), self.y + 175 * math.sin(bj_PI * i / 2 + (bj_PI / 4.)))
                BlzSetSpecialEffectScale(sfx, 2.)
                TimerQueue:callDelayed(21., DestroyEffect, sfx)
            end
        end

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) == 0 and GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local THORNS = Spell.define('A04K')
    do
        local thistype = THORNS

        local function apply(caster)
            NagaThorns:add(caster, caster):duration(6.5)
        end

        function thistype:onCast()
            FloatingTextUnit(thistype.tag, self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TimerQueue:callDelayed(2., apply, self.caster)
            TimerQueue:callDelayed(8.5, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Orc\\SpikeBarrier\\SpikeBarrier.mdl", self.caster, "origin"))
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SWARM = Spell.define('A04R')
    do
        local thistype = SWARM

        local function beetle_on_hit(source, target)
            Stun:add(source, target):duration(8.)
            KillUnit(source)
        end

        local function beetle_on_struck(target, source, amount, damage_type)
            if damage_type == MAGIC then
                amount.value = 0.00
            end
        end

        local function beetle_ai(source, target)
            PauseUnit(source, false)
            UnitRemoveAbility(source, FourCC('Avul'))
            IssueTargetOrder(source, "attack", target)
            UnitApplyTimedLife(source, FourCC('BTLF'), 6.5)
            EVENT_ON_HIT_EVADE:register_unit_action(source, beetle_on_hit)
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(source, beetle_on_struck)
            TimerQueue:callDelayed(5., DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Other\\Parasite\\ParasiteTarget.mdl", source, "overhead"))
        end

        function thistype:onCast()
            FloatingTextUnit(thistype.tag, self.caster, 2, 50, 0, 13.5, 155, 255, 255, 0, true)
            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, self.x, self.y, 1250., Condition(isplayerunit))

            local target = FirstOfGroup(ug)
            while target do
                if random() < 0.75 then
                    GroupRemoveUnit(ug, target)
                end
                local rand = random(0, 359)
                local x, y = self.x + random(150, 250) * math.cos(bj_DEGTORAD * rand), self.y + random(125, 250) * math.sin(bj_DEGTORAD * rand)
                local beetle = CreateUnit(Player(self.pid - 1), FourCC('u002'), x, y, 0)
                BlzSetUnitFacingEx(beetle, bj_RADTODEG * math.atan(GetUnitY(target) - y, GetUnitX(target) - x))
                PauseUnit(beetle, true)
                UnitAddAbility(beetle, FourCC('Avul'))
                SetUnitAnimation(beetle, "birth")
                TimerQueue:callDelayed(GetRandomReal(0.75, 1.), beetle_ai, beetle, target)
                target = FirstOfGroup(ug)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TRIDENT_STRIKE = Spell.define('A00O')
    do
        local thistype = TRIDENT_STRIKE

        local function proc(source, dmg, x, y, aoe, filter)
            local ug = CreateGroup()

            GroupEnumUnitsInRange(ug, x, y, aoe, filter)

            for target in each(ug) do
                DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function onHit(source, target, amount)
            source = Unit[source]
            amount.value = 0.00

            source.hits = source.hits + 1
            FloatingTextUnit(tostring(source.hits), target, 1.5, 50, 150., 14.5, 255, 255, 255, 0, true)

            if source.tri_target ~= target then
                source.hits = 1
            elseif source.hits > 2 then
                proc(source.unit, BlzGetUnitMaxHP(target) * 0.7, GetUnitX(target), GetUnitY(target), 120., Condition(isplayerunit))
                DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", target, "origin"))
                source.hits = 0
            end

            source.tri_target = target
        end

        function thistype.onSetup(u)
            Unit[u].hits = 0
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local SPIRIT_CALL = Spell.define('A05C')
    do
        local thistype = SPIRIT_CALL

        local function spirit_call_on_hit(source, target)
            DamageTarget(source, target, BlzGetUnitMaxHP(target) * 0.1, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            SpiritCallSlow:add(source, target):duration(5.)
        end

        ---@return boolean
        local function is_spirit(object)
            local id = GetUnitTypeId(object)
            return id == FourCC('n00P')
        end

        local function valid_target(object)
            return UnitAlive(object) and GetUnitAbilityLevel(object, FourCC('Avul')) == 0 and GetPlayerId(GetOwningPlayer(object)) < PLAYER_CAP
        end

        local function dummy_attack(object, source)
            local dummy = Dummy.create(GetUnitX(source), GetUnitY(source), FourCC('A09R'), 1)
            dummy:attack(object, source, spirit_call_on_hit)
        end

        local minX, minY, maxX, maxY = GetRectMinX(gg_rct_Naga_Dungeon_Boss), GetRectMinY(gg_rct_Naga_Dungeon_Boss), GetRectMaxX(gg_rct_Naga_Dungeon_Boss), GetRectMaxY(gg_rct_Naga_Dungeon_Boss)
        local spirits = ALICE_EnumObjectsInRect(minX, minY, maxX, maxY, "unit", is_spirit)

        local function periodic(time)
            time = time - 1

            if time >= 0 then
                local player_units = ALICE_EnumObjectsInRect(minX, minY, maxX, maxY, "unit", valid_target)
                if #player_units > 0 then
                    for _, source in ipairs(spirits) do
                        if random() < 0.25 then
                            local u = player_units[random(1, #player_units)]
                            IssuePointOrder(source, "move", GetUnitX(u) + random(-150, 150), GetUnitY(u) + random(-150, 150))
                        end
                        ALICE_ForAllObjectsInRangeDo(dummy_attack, GetUnitX(source), GetUnitY(source), 300., "unit", valid_target, source)
                    end
                end
                TimerQueue:callDelayed(1., periodic, time)
            else
                for _, source in ipairs(spirits) do
                    SetUnitVertexColor(source, 100, 255, 100, 255)
                    SetUnitScale(source, 1, 1, 1)
                    IssuePointOrder(source, "move", GetRandomReal(minX, maxX), GetRandomReal(minY, maxY))
                end
            end
        end

        function thistype:onCast()
            FloatingTextUnit("Spirit Call", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)

            for _, target in ipairs(spirits) do
                SetUnitVertexColor(target, 255, 25, 25, 255)
                SetUnitScale(target, 1.25, 1.25, 1.25)
            end

            TimerQueue:callDelayed(1., periodic, 15)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 90. then
                IssueImmediateOrder(target, "berserk")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local COLLAPSE = Spell.define('A05K')
    do
        local thistype = COLLAPSE

        local function expire(dummies, caster)
            local ug = CreateGroup()

            for _, v in ipairs(dummies) do
                local x, y = GetUnitX(v), GetUnitY(v)

                GroupEnumUnitsInRange(ug, x, y, 500., Condition(isplayerunit))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x + 150, y + 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x - 150, y - 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x + 150, y - 150))
                DestroyEffect(AddSpecialEffect("Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl", x - 150, y + 150))

                for target in each(ug) do
                    DamageTarget(caster, target, BlzGetUnitMaxHP(target) * GetRandomReal(0.75, 1), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end
            end

            DestroyGroup(ug)
        end

        function thistype:onCast()
            local dummies = {}

            for _ = 0, 9 do
                local dummy = Dummy.create(GetRandomReal(GetRectMinX(gg_rct_Naga_Dungeon_Boss), GetRectMaxX(gg_rct_Naga_Dungeon_Boss)), GetRandomReal(GetRectMinY(gg_rct_Naga_Dungeon_Boss), GetRectMaxY(gg_rct_Naga_Dungeon_Boss)), 0, 0, 4.).unit
                dummies[#dummies + 1] = dummy
                BlzSetUnitFacingEx(dummy, 270.)
                BlzSetUnitSkin(dummy, FourCC('e01F'))
                SetUnitScale(dummy, 10., 10., 10.)
                SetUnitVertexColor(dummy, 0, 255, 255, 255)
            end

            FloatingTextUnit("Collapse", self.caster, 2, 50, 0, 13.5, 255, 255, 125, 0, true)
            TimerQueue:callDelayed(3., expire, dummies, self.caster)
        end

        local function onStruck(target)
            if GetUnitLifePercent(target) < 80. then
                IssueImmediateOrder(target, "battleroar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local WATER_STRIKE = Spell.define("A006")
    do
        local thistype = WATER_STRIKE

        local missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 5.,
            onlyTarget = true,
            visualZ = 75.,
            speed = 900.,
            arc = 0.6,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                DamageTarget(self.source, enemy, BlzGetUnitMaxHP(enemy) * 0.075, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end,
        }
        missile_template.__index = missile_template

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. then
                CastSpell(target, thistype.id, 0., 0, 0.)

                local ug = CreateGroup()

                MakeGroupInRect(BOSS_ID, ug, gg_rct_Naga_Dungeon_Boss, Condition(FilterEnemy))

                for enemy in each(ug) do
                    local x = GetUnitX(target)
                    local y = GetUnitY(target)
                    local missile = setmetatable({}, missile_template)
                    missile.x = x
                    missile.y = y
                    missile.visual = AddSpecialEffect("Abilities\\Weapons\\WaterElementalMissile\\WaterElementalMissile.mdx", x, y)
                    BlzSetSpecialEffectScale(missile.visual, 1.3)
                    missile.source = target
                    missile.target = enemy

                    ALICE_Create(missile)
                end

                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local ASTRAL_ANNIHILATION = Spell.define("A00K")
    do
        local thistype = ASTRAL_ANNIHILATION

        ---@type fun(pt: PlayerTimer)
        local function periodic(pt)
            pt.time = pt.time + 1

            if UnitAlive(pt.source) then
                if pt.time < 4 then -- azazoth cast
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", pt.source, "origin"))
                    pt.timer:callDelayed(pt.dur, periodic, pt)
                else
                    local x = GetUnitX(pt.source)
                    local y = GetUnitY(pt.source)

                    for i = 1, 11 do
                        for j = 0, 9 do
                            local angle = 2 * bj_PI * i / 11.
                            DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x + 100 * j * math.cos(angle), y + 100 * j * math.sin(angle)))
                        end
                    end

                    local ug = CreateGroup()
                    MakeGroupInRange(pt.pid, ug, x, y, 900., Filter(FilterEnemy))

                    for target in each(ug) do
                        DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end

                    DestroyGroup(ug)

                    pt:destroy()
                end
            else
                pt:destroy()
            end
        end

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitAlive(target) then
                -- adjust cooldown based on HP
                local cd = 25. + R2I(GetWidgetLife(target) / BlzGetUnitMaxHP(target) * 25.)
                local animation_time = MathClamp(GetWidgetLife(target) / BlzGetUnitMaxHP(target), 0.35, 0.75)
                BlzSetUnitAbilityCooldown(target, thistype.id, 0, cd)
                CastSpell(target, thistype.id, animation_time * 4., 4, 1.)
                local pt = TimerList[BOSS_ID]:add()
                pt.dur = animation_time
                pt.dmg = 2000000.
                pt.source = target
                FloatingTextUnit(thistype.tag, pt.source, 3, 70, 0, 12, 255, 255, 255, 0, true)
                pt.timer:callDelayed(pt.dur, periodic, pt)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    ASTRAL_FREEZE = Spell.define('A01B')
    do
        local thistype = ASTRAL_FREEZE

        ---@type fun(pt: PlayerTimer)
        function thistype.periodic(pt)
            pt.time = pt.time + 1

            if UnitAlive(pt.source) then
                if pt.time < 4 then --azazoth cast
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", pt.source, "origin"))
                    pt.timer:callDelayed(pt.dur, thistype.periodic, pt)
                else
                    local ug = CreateGroup()
                    local playerBonus = 0 ---@type integer 
                    local x = 0. ---@type number 
                    local y = 0. ---@type number 

                    if pt.pid ~= BOSS_ID then
                        playerBonus = 20
                    else
                        PauseUnit(pt.source, false)
                    end

                    for i = 1, 8 do
                        for i2 = -1, 1 do
                            x = GetUnitX(pt.source) + (150 * i) * math.cos(bj_DEGTORAD * (pt.angle + 40 * i2))
                            y = GetUnitY(pt.source) + (150 * i) * math.sin(bj_DEGTORAD * (pt.angle + 40 * i2))
                            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", x, y))
                            if i2 == 0 and playerBonus > 0 then
                                GroupEnumUnitsInRangeEx(pt.pid, ug, x, y, 130. + playerBonus, Condition(FilterEnemy))
                                playerBonus = playerBonus + 40
                            else
                                GroupEnumUnitsInRangeEx(pt.pid, ug, x, y, 130., Condition(FilterEnemy))
                            end
                        end
                    end

                    for target in each(ug) do
                        DamageTarget(pt.source, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end

                    pt:destroy()

                    DestroyGroup(ug)
                end
            else
                pt:destroy()
            end
        end

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitAlive(target) then
                -- adjust cooldown based on HP
                local cd = 15. + R2I(GetWidgetLife(target) / BlzGetUnitMaxHP(target) * 15.)
                local animation_time = MathClamp(GetWidgetLife(target) // BlzGetUnitMaxHP(target), 0.35, 0.75)
                BlzSetUnitAbilityCooldown(target, thistype.id, 0, cd)
                CastSpell(target, thistype.id, animation_time * 4, 4, 1.)
                local pt = TimerList[BOSS_ID]:add()
                pt.dmg = 4000000.
                pt.dur = animation_time
                pt.angle = GetUnitFacing(target)
                pt.source = target
                FloatingTextUnit(thistype.tag, pt.source, 3, 70, 0, 12, 255, 255, 255, 0, true)
                pt.timer:callDelayed(pt.dur, thistype.periodic, pt)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local ASTRAL_SHIELD = Spell.define("A01C")
    do
        local thistype = ASTRAL_SHIELD

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitAlive(target) then
                CastSpell(target, thistype.id, 1., 6, 1.)
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 255, 255, 255, 0, true)
                AstralShieldBuff:add(target, target):duration(13.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local FROST_ARMOR = Spell.define("A02M")
    do
        local thistype = FROST_ARMOR

        local function onStruck(target)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitAlive(target) then
                CastSpell(target, thistype.id, 1., 4, 1.)
                FrostArmorBuff:add(target, target):duration(10.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local CHAIN_LIGHTNING = Spell.define("A00G")
    do
        local thistype = CHAIN_LIGHTNING

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                Unit[target].cast_time = 1.
                IssueTargetOrder(target, "chainlightning", source)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FLAME_STRIKE = Spell.define("A01T")
    do
        local thistype = FLAME_STRIKE

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                Unit[target].cast_time = 2.
                IssuePointOrder(target, "flamestrike", GetUnitX(source), GetUnitY(source))
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TORNADO_STORM = Spell.define("A085")
    do
        local thistype = TORNADO_STORM

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and IsUnitInRange(target, source, 500.) then
                CastSpell(target, thistype.id, 1.5, 5, 1.)
                local dummy = CreateUnit(PLAYER_BOSS, FourCC('n001'), GetUnitX(target), GetUnitY(target), 0.)
                IssuePointOrder(dummy, "move", GetRandomReal(GetUnitX(target) - 250, GetUnitX(target) + 250), GetRandomReal(GetUnitY(target) - 250, GetUnitY(target) + 250))
                TimerQueue:callDelayed(40., RemoveUnit, dummy)
                dummy = CreateUnit(PLAYER_BOSS, FourCC('n001'), GetUnitX(target), GetUnitY(target), 0.)
                IssuePointOrder(dummy, "move", GetRandomReal(GetUnitX(target) - 250, GetUnitX(target) + 250), GetRandomReal(GetUnitY(target) - 250, GetUnitY(target) + 250))
                TimerQueue:callDelayed(40., RemoveUnit, dummy)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SHOCKWAVE = Spell.define("A02L")
    do
        local thistype = SHOCKWAVE

        local function distance(missile, _)
            missile.dist = missile.dist - missile.speed * ALICE_Config.MIN_INTERVAL
            if missile.dist < 0 then
                ALICE_Kill(missile)
            end
        end

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
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) < 600. then
                CastSpell(target, thistype.id, 1., 15, 1)
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

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local WAR_STOMP = Spell.define("A09J")
    do
        local thistype = WAR_STOMP

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) < 300. then
                CastSpell(target, thistype.id, 1., 10, 1.)
                local pt = TimerList[BOSS_ID]:add()
                pt.dmg = 2000.
                pt.source = target
                pt.dur = 8.
                pt.tag = "War Stomp"
                pt.timer:callDelayed(1., StompPeriodic, pt)
                FloatingTextUnit(pt.tag, target, 2., 60., 0, 12, 255, 255, 255, 0, true)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local MANA_DRAIN = Spell.define("A01Z")
    do
        local thistype = MANA_DRAIN

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(target, source) < 800. then
                CastSpell(target, thistype.id, 1.5, 4, 1.)

                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 800., Condition(FilterEnemy))
                for enemy in each(ug) do
                    if not ManaDrainDebuff:has(target, enemy) and not Unit[enemy].nomanaregen then
                        ManaDrainDebuff:add(target, enemy):duration(9999.)
                    end
                end
                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local DWARF_AVATAR = Spell.define("A0DV")
    do
        local thistype = DWARF_AVATAR

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(target, source) < 300. then
                IssueImmediateOrder(target, "avatar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local THUNDER_CLAP = Spell.define("A0A2")
    do
        local thistype = THUNDER_CLAP

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(target, source) < 300. then
                CastSpell(target, thistype.id, 1., 10, 1.)
                local pt = TimerList[BOSS_ID]:add()
                pt.dmg = 4000.
                pt.source = target
                pt.dur = 8.
                pt.tag = "Thunder Clap"
                pt.timer:callDelayed(1., StompPeriodic, pt)
                FloatingTextUnit(pt.tag, target, 2., 60., 0, 12, 0, 255, 255, 0, true)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DEATH_MARCH = Spell.define("A0AO")
    do
        local thistype = DEATH_MARCH

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) > 250. then
                BlzStartUnitAbilityCooldown(target, thistype.id, 20.)
                BossTeleport(source, 1.5)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local DEATH_STRIKES = Spell.define("A088")
    do
        local thistype = DEATH_STRIKES

        local function expire(pt)
            SetUnitAnimation(pt.source, "death")
            DestroyEffect(AddSpecialEffect("NecroticBlast.mdx", pt.x, pt.y))

            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, pt.x, pt.y, 180., Condition(FilterEnemy))

            for target in each(ug) do
                DamageTarget(Boss[BOSS_DEATH_KNIGHT].unit, target, 15000., ATTACK_TYPE_NORMAL, MAGIC, DEATHSTRIKE.tag)
            end

            DestroyGroup(ug)

            pt:destroy()
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitAlive(target) then
                local ug = CreateGroup()
                CastSpell(target, thistype.id, 0.7, 3, 1.)
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 1250., Condition(FilterEnemy))
                FloatingTextUnit(thistype.tag, target, 2., 60., 0, 12, 255, 255, 255, 0, true)
                local count = 0
                for u in each(ug) do
                    if count >= 3 then break end
                    local pt = TimerList[BOSS_ID]:add()
                    pt.x = GetUnitX(u)
                    pt.y = GetUnitY(u)
                    pt.source = Dummy.create(pt.x, pt.y, 0, 0).unit
                    SetUnitScale(pt.source, 4., 4., 4.)
                    BlzSetUnitSkin(pt.source, FourCC('e01F'))
                    pt.timer:callDelayed(3., expire, pt)
                    count = count + 1
                end
                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local HOLY_LIGHT = Spell.define("A0FI")
    do
        local thistype = HOLY_LIGHT

        local function onStruck(target, source)
            if UnitAlive(target) then
                IssueTargetOrder(target, "holybolt", target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local RAISE_SKELETON = Spell.define("A01H")
    do
        local thistype = RAISE_SKELETON

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. then
                CastSpell(target, thistype.id, 1.5, 8, 1.)

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

    local METAMORPHOSIS = Spell.define("A065")
    do
        local thistype = METAMORPHOSIS

        local function onStruck(target, source)
            if GetWidgetLife(target) < BlzGetUnitMaxHP(target) * 0.5 then
                IssueImmediateOrder(target, "metamorphosis")
                RAISE_SKELETON.onSetup(target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FROST_NOVA = Spell.define("A066")
    do
        local thistype = FROST_NOVA

        local function nova(target)
            if UnitAlive(target) then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 700., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffect("war3mapImported\\FrostNova.mdx", GetUnitX(target), GetUnitY(target)))

                for enemy in each(ug) do
                    Freeze:add(target, enemy):duration(3.)
                    DamageTarget(target, enemy, 15000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. and IsUnitInRange(target, source, 700.) then
                if GetUnitTypeId(target) == FourCC('E007') then
                    CastSpell(target, thistype.id, 1., 8, 1.)
                else
                    CastSpell(target, thistype.id, 1., 2, 1.)
                end

                FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 255, 255, 0, true)

                TimerQueue:callDelayed(1., nova, target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local HOLY_WARD = Spell.define("A06T")
    do
        local thistype = HOLY_WARD

        local function holy_ward(holyward)
            if UnitAlive(holyward) then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(holyward), GetUnitY(holyward), 2000., Condition(FilterAlly))

                for target in each(ug) do
                    HP(holyward, target, 100000)
                    HolyBlessing:add(target, target):duration(30.)
                    TimerQueue:callDelayed(2, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl", target, "origin"))
                end

                KillUnit(holyward)
                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 then
                CastSpell(target, thistype.id, 0.5, 9, 1.5)
                local holyward = CreateUnit(PLAYER_BOSS, FourCC('o009'), GetRandomReal(GetRectMinX(gg_rct_Crystal_Spawn) - 500, GetRectMaxX(gg_rct_Crystal_Spawn) + 500), GetRandomReal(GetRectMinY(gg_rct_Crystal_Spawn) - 600, GetRectMaxY(gg_rct_Crystal_Spawn) + 600), 0)
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(holyward), GetUnitY(holyward), 1250., Condition(FilterEnemy))
                BlzSetUnitMaxHP(holyward, 10 * BlzGroupGetSize(ug))

                Unit[holyward].attackCount = BlzGetUnitMaxHP(holyward)

                TimerQueue:callDelayed(10., holy_ward, holyward)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local GHOST_SHROUD = Spell.define("A0A8")
    do
        local thistype = GHOST_SHROUD

        local function ghost_shroud(target)
            if IsUnitType(target, UNIT_TYPE_ETHEREAL) then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 500., Condition(FilterEnemy))

                for enemy in each(ug) do
                    local dmg = math.max(0, GetHeroInt(target, true) - GetHeroInt(enemy, true))

                    DamageTarget(target, enemy, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)

                TimerQueue:callDelayed(1., ghost_shroud, target)
            end
        end

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 0.25, 8, 1.5)
                Dummy.create(GetUnitX(target), GetUnitY(target), thistype.id, 1):cast(PLAYER_BOSS, "banish", target)
                TimerQueue:callDelayed(1., ghost_shroud, target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SILENCE = Spell.define("A05B")
    do
        local thistype = SILENCE

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                local ug = CreateGroup()
                CastSpell(target, thistype.id, 1., 8, 1.5)

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(source), GetUnitY(source), 1000., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Silence\\SilenceAreaBirth.mdl", GetUnitX(source), GetUnitY(source)))

                for enemy in each(ug) do
                    Silence:add(target, enemy):duration(10.)
                end

                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DISARM = Spell.define("A05W")
    do
        local thistype = DISARM

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 1., 8, 1.5)
                Disarm:add(target, source):duration(6.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SUN_STRIKE = Spell.define("A08M")
    do
        local thistype = SUN_STRIKE

        local function sun_strike(source, x, y)
            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, x, y, 150., Condition(FilterEnemy))

            DestroyEffect(AddSpecialEffect("war3mapImported\\OrbitalRay.mdx", x, y))

            for target in each(ug) do
                DamageTarget(source, target, 25000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                local ug = CreateGroup()
                BlzStartUnitAbilityCooldown(target, thistype.id, 20.)

                GroupEnumUnitsInRange(ug, GetUnitX(target), GetUnitY(target), 1250., Condition(isplayerAlly))

                local count = 0

                for u in each(ug) do
                    if count >= 3 then break end
                    local dummy = Dummy.create(GetUnitX(u), GetUnitY(u), 0, 0, 3.).unit
                    SetUnitScale(dummy, 4., 4., 4.)
                    BlzSetUnitFacingEx(dummy, 270)
                    BlzSetUnitSkin(dummy, FourCC('e01F'))
                    SetUnitVertexColor(dummy, 200, 200, 0, 255)

                    TimerQueue:callDelayed(3., sun_strike, target, GetUnitX(u), GetUnitY(u))

                    count = count + 1
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local BLOODLUST = Spell.define("A0AX")
    do
        local thistype = BLOODLUST

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.5 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                BlzStartUnitAbilityCooldown(target, thistype.id, 60.)
                DemonPrinceBloodlust:add(target, target):duration(60.)
                Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A041'), 1):cast(PLAYER_BOSS, "bloodlust", target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local TRUE_STEALTH = Spell.define("A0AC")
    do
        local thistype = TRUE_STEALTH

        local function expire(pt)
            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, pt.x, pt.y, 400., Condition(FilterEnemy))

            UnitRemoveAbility(pt.source, FourCC('Amrf'))
            UnitRemoveAbility(pt.source, FourCC('A043'))
            UnitRemoveAbility(pt.source, FourCC('BOwk'))
            UnitRemoveAbility(pt.source, FourCC('Avul'))
            SetUnitXBounded(pt.source, pt.x)
            SetUnitYBounded(pt.source, pt.y)
            SetUnitAnimation(pt.source, "Attack Slam")

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y))

            local count = BlzGroupGetSize(ug)

            if count > 0 then
                local target = BlzGroupUnitAt(ug, GetRandomInt(0, count - 1))
                local heal = GetWidgetLife(target)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", target, "origin"))
                DamageTarget(pt.source, target, 80000. + BlzGetUnitMaxHP(target) * 0.3, ATTACK_TYPE_NORMAL, MAGIC, "True Stealth")
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", pt.source, "chest"))
                heal = math.max(0, heal - GetWidgetLife(target))
                SetUnitState(pt.source, UNIT_STATE_LIFE, GetWidgetLife(pt.source) + heal)
            end

            pt:destroy()

            DestroyGroup(ug)
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.8 then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 1500., Condition(FilterEnemy))

                local u = FirstOfGroup(ug)
                if u then
                    BlzStartUnitAbilityCooldown(target, thistype.id, 10.)

                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 90, 30, 150, 0, true)
                    Buff.dispelAll(target)
                    UnitAddAbility(target, FourCC('Avul'))
                    UnitAddAbility(target, FourCC('A043'))
                    IssueImmediateOrder(target, "windwalk")

                    local angle = math.atan(GetUnitY(u) - GetUnitY(target), GetUnitX(u) - GetUnitX(target))
                    UnitAddAbility(target, FourCC('Amrf'))
                    IssuePointOrder(target, "move", GetUnitX(u) + 300 * math.cos(angle), GetUnitY(u) + 300 * math.sin(angle))
                    local pt = TimerList[BOSS_ID]:add()
                    pt.x = GetUnitX(u) + 150 * math.cos(angle)
                    pt.y = GetUnitY(u) + 150 * math.sin(angle)
                    pt.source = target
                    pt.timer:callDelayed(2., expire, pt)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local CLOUD_OF_DESPAIR = Spell.define("A03W")
    do
        local thistype = CLOUD_OF_DESPAIR

        local function periodic(pt)
            pt.time = pt.time + 1.

            if pt.time < pt.dur then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, pt.x, pt.y, 300., Condition(FilterEnemy))

                for target in each(ug) do
                    DamageTarget(pt.source, target, BlzGetUnitMaxHP(target) * 0.05, ATTACK_TYPE_NORMAL, PURE, "Cloud of Despair")
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(1., periodic, pt)
            else
                pt:destroy()
            end
        end

        local function onStruck(target, source)
            if UnitAlive(target) and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. then
                local pt = TimerList[BOSS_ID]:add()
                pt.x = GetRandomReal(GetRectMinX(gg_rct_Crypt) + 200., GetRectMaxX(gg_rct_Crypt) - 200.)
                pt.y = GetRandomReal(GetRectMinY(gg_rct_Crypt) + 200., GetRectMaxY(gg_rct_Crypt) - 200.)
                pt.sfx = AddSpecialEffect("war3mapImported\\SporeCloud025_Priority005.mdx", pt.x, pt.y)
                pt.dur = 8.
                pt.source = target

                BlzSetUnitFacingEx(target, math.atan(pt.y - GetUnitY(target), pt.x - GetUnitX(target)) * bj_RADTODEG)
                CastSpell(target, thistype.id, 1.5, 3, 1.2)

                pt.timer:callDelayed(1., periodic, pt)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SCREAM_OF_DESPAIR = Spell.define("A04Q")
    do
        local thistype = SCREAM_OF_DESPAIR

        local function expire(target)
            if UnitAlive(target) then
                local ug = CreateGroup()

                CastSpell(target, 0, 1.8, 5, 1.2)
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 500., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlCaster.mdl", target, "origin"))

                for enemy in each(ug) do
                    Fear:add(target, enemy):duration(6.)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. and UnitDistance(source, target) <= 300. then
                CastSpell(target, thistype.id, 2., 1, 1.)

                FloatingTextUnit(thistype.tag, target, 3, 100, 0, 13, 255, 255, 255, 0, true)

                TimerQueue:callDelayed(2, expire)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SLAUGHTER_AVATAR = Spell.define("A040")
    do
        local thistype = SLAUGHTER_AVATAR

        local function reset(target)
            SetUnitMoveSpeed(target, 300)
        end

        local function avatar(target)
            IssueImmediateOrder(target, "avatar")
            SetUnitMoveSpeed(target, 270)
            TimerQueue:callDelayed(10., reset, target)
        end

        local function onStruck(target, source)
            if math.random(0, 99) < 13 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 0., -1, 1.)
                FloatingTextUnit("Avatar", target, 3, 100, 0, 13, 255, 255, 255, 0, true)
                TimerQueue:callDelayed(2., avatar, target)
            end
        end

        function thistype.onSetup(u)
            local boss = IsBoss(u)
            SetUnitAbilityLevel(u, FourCC('A064'), boss.difficulty)
            SetUnitAbilityLevel(u, thistype.id, boss.difficulty)

            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local MORTIFY_TERRIFY = Spell.define("A03M")
    do
        local thistype = MORTIFY_TERRIFY

        local function expire(pt)
            if UnitAlive(pt.source) then
                if pt.spell == 1 then
                    BossPlusSpell(pt.source, 1000000, 1, "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", "Mortify")
                elseif pt.spell == 2 then
                    BossXSpell(pt.source, 1000000,1, "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", "Terrify")
                end
            end

            pt:destroy()
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 2., 0, 1)
                BlzStartUnitAbilityCooldown(target, FourCC('A05U'), 5.)
                local pt = TimerList[BOSS_ID]:add()
                pt.source = target
                if random(1, 2) == 1 then
                    FloatingTextUnit("+ MORTIFY +", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                    pt.spell = 1
                else
                    FloatingTextUnit("x TERRIFY x", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                    pt.spell = 2
                end

                pt.timer:callDelayed(4., expire, pt)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FREEZE = Spell.define("A02Q")
    do
        local thistype = FREEZE

        local function expire(target)
            if UnitAlive(target) then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 300., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(target), GetUnitY(target)))

                for enemy in each(ug) do
                    Stun:add(target, enemy):duration(5.)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 2., 5, 1.)
                FloatingTextUnit("||||| FREEZE |||||", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                TimerQueue:callDelayed(4., expire, target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FLAME_ONSLAUGHT = Spell.define("A03R")
    do
        local thistype = FLAME_ONSLAUGHT

        local function on_hit(source, target)
            if IsUnitEnemy(target, PLAYER_BOSS) then
                DamageTarget(source, target, 10000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 then
                local dummy = Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A0DN'), 1)
                dummy.source = target
                SetUnitOwner(dummy.unit, PLAYER_BOSS, false)
                IssuePointOrder(dummy.unit, "flamestrike", GetUnitX(source), GetUnitY(source))
                EVENT_DUMMY_ON_HIT:register_unit_action(target, on_hit)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local SHADOW_STEP = Spell.define("A05I")
    do
        local thistype = SHADOW_STEP

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) > 250. then
                CastSpell(target, thistype.id, 0., 1, 1.)
                BossTeleport(source, 1.5)
            end
        end

        function thistype.onSetup(u)
            if not IsUnitIllusion(u) then
                EVENT_ENEMY_AI:register_unit_action(u, onStruck)
            end
        end
    end

    local LEGION = Spell.define("A08C")
    do
        local thistype = LEGION

        local function spawn(target)
            if UnitAlive(target) then
                for _ = 0, 6 do
                    UnitAddItemById(target, FourCC('I06V'))
                end
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and TimerList[BOSS_ID]:has(FourCC('tpin')) == false and IsUnitInRange(target, source, 800.) then
                CastSpell(target, thistype.id, 0.5, 12, 1.)
                TimerQueue:callDelayed(2, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Orc\\MirrorImage\\MirrorImageCaster.mdl", GetUnitX(target), GetUnitY(target)))
                RemoveLocation(Boss[BOSS_LEGION].loc)
                Boss[BOSS_LEGION].loc = Location(GetUnitX(source), GetUnitY(source))
                TimerQueue:callDelayed(0.5, spawn, target)
            end
        end

        function thistype.onSetup(u)
            if not IsUnitIllusion(u) then
                EVENT_ENEMY_AI:register_unit_action(u, onStruck)
            end
        end
    end

    local SWIFT_HUNT = Spell.define("A023")
    do
        local thistype = SWIFT_HUNT

        local function expire(pt)
            if UnitAlive(pt.source) then
                local ug = CreateGroup()
                GroupEnumUnitsInRange(ug, pt.x, pt.y, 200., Condition(ishostileEnemy))

                SetUnitXBounded(pt.source, pt.x)
                SetUnitYBounded(pt.source, pt.y)
                SetUnitAnimation(pt.source, "attack")

                for target in each(ug) do
                    DestroyEffect(AddSpecialEffectTarget("war3mapImported\\Coup de Grace.mdx", target, "chest"))
                    DamageTarget(pt.source, target, 1500000, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)
            end

            pt:destroy()
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) > 250. then
                CastSpell(target, thistype.id, 0, -1, 1)
                local pt = TimerList[BOSS_ID]:add()
                pt.x = GetUnitX(source)
                pt.y = GetUnitY(source)
                pt.source = target
                pt.spell = 1
                pt.timer:callDelayed(1.5, expire, pt)
                FloatingTextUnit(thistype.tag, target, 1, 70, 0, 10, 255, 255, 255, 0, true)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DEATH_BECKONS = Spell.define("A02P")
    do
        local thistype = DEATH_BECKONS

        local function expire(target)
            if UnitAlive(target) then
                BossBlastTaper(target, 1000000, FourCC('A0A4'), 750, thistype.tag)
            end
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                CastSpell(target, thistype.id, 2., 12, 1.)
                TimerQueue:callDelayed(2.5, expire, target)
                FloatingTextUnit(thistype.tag, target, 2, 70, 0, 10, 255, 255, 255, 0, true)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local EXISTENCE = Spell.define("A07F")
    do
        local thistype = EXISTENCE

        local function expire(pt)
            pt.dur = pt.dur - 1

            if pt.dur == 3 then
                if pt.spell == 2 then
                    BossInnerRing(pt.source, 1000000, 2, 400, "Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl", "Implosion")
                elseif pt.spell == 3 then
                    BossOuterRing(pt.source, 500000, 2, 400, 900, "war3mapImported\\NeutralExplosion.mdx", "Explosion")
                end
            elseif pt.dur == 1 then
                if pt.spell == 1 then
                    BossBlastTaper(pt.source, 1500000, FourCC('A0AB'), 800, "Extermination")
                end
            end

            if pt.dur < 0 or not UnitAlive(pt.source) then
                pt:destroy()
            else
                pt.timer:callDelayed(0.5, expire, pt)
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, FourCC('A07F')) <= 0. then
                local rand = 0
                repeat
                    rand = random(1, 3)
                    if rand == 1 then
                        FloatingTextUnit("Extermination", target, 3, 70, 0, 12, 255, 255, 255, 0, true)
                    elseif rand == 2 and UnitDistance(source, target) <= 400 then
                        FloatingTextUnit("Implosion", target, 3, 70, 0, 12, 68, 68, 255, 0, true)
                    elseif rand == 3 and UnitDistance(source, target) >= 400 then
                        FloatingTextUnit("Explosion", target, 3, 70, 0, 12, 255, 100, 50, 0, true)
                    else
                        rand = 0
                    end
                until rand ~= 0

                local pt = TimerList[BOSS_ID]:add()
                pt.source = target
                pt.dur = 6
                pt.spell = rand
                CastSpell(target, FourCC('A07F'), 0., -1, 1.)
                CastSpell(target, FourCC('A07Q'), 0., -1, 1.)
                CastSpell(target, FourCC('A073'), 0., -1, 1.)
                CastSpell(target, FourCC('A072'), 1.5, 4, 1.5)
                pt.timer:callDelayed(0.5, expire, pt)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local PROTECTED_EXISTENCE = Spell.define("A07X")
    do
        local thistype = PROTECTED_EXISTENCE
        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. and not Unit[target].casting then
                CastSpell(target, thistype.id, 1.5, 4, 1.5)
                FloatingTextUnit(thistype.tag, target, 3, 70, 0, 12, 100, 255, 100, 0, true)
                ProtectedExistenceBuff:add(target, target):duration(10.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end

    local REINFORCEMENTS = Spell.define("A01I")
    do
        local thistype = REINFORCEMENTS

        local function summon(angle, x, y)
            UnitApplyTimedLife(CreateUnit(PLAYER_BOSS, FourCC('o034'), x + 400 * math.cos((angle + 90) * bj_DEGTORAD), y + 400 * math.sin((angle + 90) * bj_DEGTORAD), angle), FourCC('BTLF'), 120.)
            UnitApplyTimedLife(CreateUnit(PLAYER_BOSS, FourCC('o034'), x + 400 * math.cos((angle - 90) * bj_DEGTORAD), y + 400 * math.sin((angle - 90) * bj_DEGTORAD), angle), FourCC('BTLF'), 120.)
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and GetWidgetLife(target) <= BlzGetUnitMaxHP(target) * 0.5 then
                CastSpell(target, thistype.id, 0., 3, 1.)
                FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 0, 0, 0, true)
                local angle, x, y = GetUnitFacing(target), GetUnitX(target), GetUnitY(target)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", x + 400. * math.cos((angle + 90) * bj_DEGTORAD), y + 400. * math.sin((angle + 90) * bj_DEGTORAD)))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl", x + 400. * math.cos((angle - 90) * bj_DEGTORAD), y + 400. * math.sin((angle - 90) * bj_DEGTORAD)))
                TimerQueue:callDelayed(2., summon, angle, x, y)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local UNSTOPPABLE_FORCE = Spell.define("A01J")
    do
        local thistype = UNSTOPPABLE_FORCE

        local function periodic(pt)
            if UnitAlive(pt.source) then
                local ug = CreateGroup()

                GroupEnumUnitsInRange(ug, GetUnitX(pt.source), GetUnitY(pt.source), 400., Condition(isplayerunit))

                for target in each(ug) do
                    if IsUnitInGroup(target, pt.ug) == false then
                        GroupAddUnit(pt.ug, target)
                        DamageTarget(pt.source, target, 50000000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                    end
                end

                pt.angle = math.atan(pt.y - GetUnitY(pt.source), pt.x - GetUnitX(pt.source))

                if IsUnitInRangeXY(pt.source, pt.x, pt.y, 125.) or DistanceCoords(pt.x, pt.y, GetUnitX(pt.source), GetUnitY(pt.source)) > 2500. then
                    SetUnitPathing(pt.source, true)
                    PauseUnit(pt.source, false)
                    IssueImmediateOrder(pt.source, "stand")
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x + 200, pt.y))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x - 200, pt.y))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y + 200))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y - 200))

                    pt:destroy()
                else
                    SetUnitPathing(pt.source, false)
                    SetUnitXBounded(pt.source, GetUnitX(pt.source) + 55 * math.cos(pt.angle))
                    SetUnitYBounded(pt.source, GetUnitY(pt.source) + 55 * math.sin(pt.angle))

                    pt.timer:callDelayed(FPS_32, periodic, pt)
                end

                DestroyGroup(ug)
            else
                SetUnitPathing(pt.source, true)
                PauseUnit(pt.source, false)
                IssueImmediateOrder(pt.source, "stand")
                pt:destroy()
            end
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                local ug = CreateGroup()
                GroupEnumUnitsInRange(ug, GetUnitX(target), GetUnitY(target), 1500., Condition(isplayerAlly))

                if BlzGroupGetSize(ug) > 0 then
                    PauseUnit(target, true)
                    CastSpell(target, thistype.id, 2.5, 1, 1.)
                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 0, 0, 0, true)
                    local u = BlzGroupUnitAt(ug, GetRandomInt(0, BlzGroupGetSize(ug) - 1))
                    local dummy = Dummy.create(GetUnitX(u), GetUnitY(u), 0, 0, 4.).unit
                    SetUnitScale(dummy, 10., 10., 10.)
                    BlzSetUnitFacingEx(dummy, 270.)
                    BlzSetUnitSkin(dummy, FourCC('e01F'))
                    SetUnitVertexColor(dummy, 200, 200, 0, 255)
                    local pt = TimerList[BOSS_ID]:add()
                    pt.x = GetUnitX(u)
                    pt.y = GetUnitY(u)
                    pt.ug = CreateGroup()
                    pt.angle = math.atan(GetUnitY(u) - GetUnitY(target), GetUnitX(u) - GetUnitX(target))
                    pt.source = target
                    BlzSetUnitFacingEx(target, pt.angle * bj_RADTODEG)
                    pt.timer:callDelayed(2.5, periodic, pt)
                end

                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local AMBUSH = Spell.define("A02B")
    do
        local thistype = AMBUSH

        local function fireball_projectile(pt)
            local x = GetUnitX(pt.source) ---@type number 
            local y = GetUnitY(pt.source) ---@type number 

            pt.dur = pt.dur - pt.speed

            if pt.dur > 0. then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, x, y, pt.aoe, Condition(FilterEnemy))

                --movement
                SetUnitXBounded(pt.source, x + pt.speed * math.cos(pt.angle))
                SetUnitYBounded(pt.source, y + pt.speed * math.sin(pt.angle))

                local target = FirstOfGroup(ug)

                if target then
                    DamageTarget(Boss[BOSS_XALLARATH].unit, target, pt.dmg, ATTACK_TYPE_NORMAL, MAGIC, "Fireball")

                    pt.dur = 0.
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(FPS_32, fireball_projectile, pt)
            else
                SetUnitAnimation(pt.source, "death")
                pt:destroy()
            end
        end

        ---@type fun(pt: PlayerTimer)
        local function fireball(pt)
            if UnitAlive(pt.source) then
                local ug = CreateGroup()
                local x = GetUnitX(pt.source) ---@type number 
                local y = GetUnitY(pt.source) ---@type number 

                MakeGroupInRange(BOSS_ID, ug, x, y, 4000., Condition(FilterEnemy))

                local size = BlzGroupGetSize(ug)

                if size > 0 and BlzGetUnitAbilityCooldownRemaining(pt.source, FourCC('A02V')) <= 0 then
                    CastSpell(pt.source, FourCC('A02V'), 0.75, 5, 1.)
                    local pt2 = TimerList[BOSS_ID]:add()
                    pt2.target = BlzGroupUnitAt(ug, GetRandomInt(0, size - 1))
                    pt2.angle = math.atan(GetUnitY(pt2.target) - y, GetUnitX(pt2.target) - x)
                    pt2.source = Dummy.create(x, y, 0, 0, 21.).unit
                    pt2.x = GetUnitX(pt2.target)
                    pt2.y = GetUnitY(pt2.target)
                    pt2.speed = 7.
                    pt2.aoe = 90.
                    pt2.dur = DistanceCoords(pt2.x, pt2.y, x, y) + 500.
                    pt2.dmg = 3000000.
                    BlzSetUnitSkin(pt2.source, FourCC('h02U'))
                    SetUnitFlyHeight(pt2.source, 80., 0.)
                    SetUnitScale(pt2.source, 1.8, 1.8, 1.8)
                    UnitDisableAbility(pt2.source, FourCC('Amov'), true)
                    BlzSetUnitFacingEx(pt.source, pt2.angle * bj_RADTODEG)
                    BlzSetUnitFacingEx(pt2.source, pt2.angle * bj_RADTODEG)

                    pt2.timer:callDelayed(FPS_32, fireball_projectile, pt2)
                end

                DestroyGroup(ug)

                pt.timer:callDelayed(1., fireball, pt)
            else
                pt:destroy()
            end
        end

        ---@type fun(pt: PlayerTimer)
        local function focus_fire(pt)
            local x = GetUnitX(pt.source) ---@type number 
            local y = GetUnitY(pt.source) ---@type number 

            if UnitAlive(pt.source) then
                if pt.target == nil then
                    local ug = CreateGroup()
                    MakeGroupInRange(BOSS_ID, ug, x, y, 4000., Condition(FilterEnemy))

                    local size = BlzGroupGetSize(ug)

                    if size > 0 then
                        pt.target = BlzGroupUnitAt(ug, GetRandomInt(0, size - 1))
                        IssueTargetOrder(pt.source, "attack", pt.target)

                        if not pt.lfx then
                            pt.lfx = AddLightning("RLAS", false, x, y, GetUnitX(pt.target), GetUnitY(pt.target))
                        else
                            MoveLightningEx(pt.lfx, false, x, y, BlzGetUnitZ(pt.source) + GetUnitFlyHeight(pt.source) + 50., GetUnitX(pt.target), GetUnitY(pt.target), BlzGetUnitZ(pt.target) + 50.)
                        end
                    end

                    DestroyGroup(ug)
                else
                    if not IsUnitVisible(pt.target, PLAYER_BOSS) or UnitDistance(pt.source, pt.target) > 4000. then
                        pt.target = nil
                        pt.time = 0.
                        pt.agi = 0
                        MoveLightningEx(pt.lfx, false, 30000., 30000., 0., 30000., 30000., 0.)
                        IssueImmediateOrderById(pt.source, ORDER_ID_STOP)
                        UnitSetBonus(pt.source, BONUS_ATTACK_SPEED, -8.)
                        BlzStartUnitAbilityCooldown(pt.source, FourCC('A02G'), 0.001)
                    else
                        pt.time = pt.time + FPS_32
                        MoveLightningEx(pt.lfx, false, x, y, BlzGetUnitZ(pt.source) + GetUnitFlyHeight(pt.source) + 50., GetUnitX(pt.target), GetUnitY(pt.target), BlzGetUnitZ(pt.target) + 50.)

                        if BlzGetUnitAbilityCooldownRemaining(pt.source, FourCC('A02G')) <= 0. then
                            CastSpell(pt.source, FourCC('A02G'), 5., 0, 1.)
                        end

                        if pt.time >= 5 then
                            DamageTarget(pt.source, pt.target, 0.001, ATTACK_TYPE_NORMAL, PHYSICAL, "Focus Fire")
                            IssueTargetOrder(pt.source, "attack", pt.target)
                            UnitSetBonus(pt.source, BONUS_ATTACK_SPEED, 8.)
                            BlzSetUnitFacingEx(pt.source, bj_RADTODEG * math.atan(GetUnitY(pt.target) - y, GetUnitX(pt.target) - x))
                        end
                    end
                end
            else
                DestroyLightning(pt.lfx)
                pt:destroy()
            end
        end

        local function spawn_archer(x, y, height)
            local pt = TimerList[BOSS_ID]:add()
            pt.source = CreateUnit(PLAYER_BOSS, FourCC('o001'), x, y, 0.)
            if UnitAddAbility(pt.source, FourCC('Amrf')) then
                UnitRemoveAbility(pt.source, FourCC('Amrf'))
            end
            SetUnitFlyHeight(pt.source, height, 0.)
            ShowUnit(pt.source, false)
            ShowUnit(pt.source, true)
            UnitApplyTimedLife(pt.source, FourCC('BTLF'), 300.)
            pt.timer:callPeriodically(FPS_32, nil, focus_fire, pt)
        end

        local function spawn_mage(x, y, height)
            local pt = TimerList[BOSS_ID]:add()
            pt.source = CreateUnit(PLAYER_BOSS, FourCC('o000'), x, y, 0.)
            if UnitAddAbility(pt.source, FourCC('Amrf')) then
                UnitRemoveAbility(pt.source, FourCC('Amrf'))
            end
            SetUnitFlyHeight(pt.source, height, 0.)
            ShowUnit(pt.source, false)
            ShowUnit(pt.source, true)
            UnitApplyTimedLife(pt.source, FourCC('BTLF'), 300.)
            pt.timer:callDelayed(1., fireball, pt)
        end

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0. and GetWidgetLife(target) <= BlzGetUnitMaxHP(target) * 0.9 then
                CastSpell(target, thistype.id, 0., 3, 1.)
                spawn_archer(12349., -15307., 770.)
                spawn_archer(13500., -12300., 575.)
                spawn_archer(14079., -11550., 575.)
                spawn_mage(14315., -12863., 770.)
                spawn_mage(11788., -14279., 575.)
                spawn_mage(11214., -15133., 575.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local MINK_LUCK = Spell.define("A0BH")
    do
        local thistype = MINK_LUCK

        function thistype.onSetup(u)
            Unit[u].evasion = Unit[u].evasion + 50
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
