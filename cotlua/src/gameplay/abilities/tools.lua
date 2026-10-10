OnInit.final("SpellTools", function(Require)
    Require('TimerQueue')

    -- Alit visual settings copied from war3map.w3a (Lit2) and
    -- war3mapSkin.w3a (alig/atat/ata0). No object changes or attack orders.
    local lightning_attacks = {
        A01Y = {kind = "CLSB", duration = 1., art = "Abilities\\Weapons\\Bolt\\BoltImpact.mdl", attach = "chest"},
        A09D = {kind = "DRAL", duration = 1.},
        A09Q = {kind = "YENL", duration = 1., art = "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", attach = "origin"},
        A09R = {kind = "MBUR", duration = 1., art = "Abilities\\Weapons\\FarseerMissile\\FarseerMissile.mdl", attach = "chest"},
        A09W = {kind = "CLPB", duration = 1., art = "Abilities\\Weapons\\Bolt\\BoltImpact.mdl", attach = "origin"},
        A0A1 = {kind = "AFOD", duration = 1.},
        A010 = {kind = "RAIL", duration = 1.5}, -- Scripted Railgun lifetime, intentionally shorter than Lit2.
    }

    ---Play an instant, fixed-endpoint beam. Gameplay damage stays at the call site.
    ---@param ability string Original Alit fourcc, used only to select visual settings.
    ---@param x1 number
    ---@param y1 number
    ---@param z1 number
    ---@param x2 number
    ---@param y2 number
    ---@param z2 number
    ---@return lightning?
    function LightningAttackBeam(ability, x1, y1, z1, x2, y2, z2)
        local visual = assert(lightning_attacks[ability], "Unknown lightning attack: " .. ability)
        local beam = AddLightningEx(visual.kind, true, x1, y1, z1, x2, y2, z2)
        if beam then TimerQueue:callDelayed(visual.duration, DestroyLightning, beam) end
        return beam
    end

    ---Coordinates may override the source unit (Medean Lightning's seal ring).
    ---Dead source units are allowed: Blood Siphon also drains corpses visually.
    ---@param ability string
    ---@param source unit
    ---@param target unit
    ---@param x number?
    ---@param y number?
    ---@return lightning?
    function LightningAttackVisual(ability, source, target, x, y)
        local visual = assert(lightning_attacks[ability], "Unknown lightning attack: " .. ability)
        local source_z = x and GetTerrainZ(x, y) or GetUnitZ(source)
        local beam = LightningAttackBeam(ability, x or GetUnitX(source), y or GetUnitY(source),
            source_z + 75., GetUnitX(target), GetUnitY(target), GetUnitZ(target) + 75.)
        if visual.art then
            DestroyEffect(AddSpecialEffectTarget(visual.art, target, visual.attach))
        end
        return beam
    end

    function MISSILE_DISTANCE(self, _)
        self.dist = self.dist - self.speed * ALICE_Config.MIN_INTERVAL
        if self.dist < 0 then
            ALICE_Kill(self)
        end
    end

    function VALID_DAMAGE_TARGET(object, self)
        if type(self) == "table" then
            self = self.owner
        else
            self = GetOwningPlayer(self)
        end
        return UnitAlive(object) and IsUnitEnemy(object, self)
    end

    function VALID_PULL_TARGET(object, self)
        if type(self) == "table" then
            self = self.owner
        else
            self = GetOwningPlayer(self)
        end
        return UnitAlive(object) and IsUnitEnemy(object, self) and GetUnitMoveSpeed(object) > 0
    end

    function DASH_PRECAST(pid, tpid, caster, target, x, y, targetX, targetY)
        local r = GetRectFromCoords(x, y)
        local r2 = GetRectFromCoords(targetX, targetY)

        if not IsTerrainWalkable(targetX, targetY) or r2 ~= r then
            IssueImmediateOrderById(caster, ORDER_ID_STOP)
            DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            return false
        end

        return true
    end

    function TERRAIN_PRECAST(pid, tpid, caster, target, x, y, targetX, targetY)
        if not IsTerrainWalkable(targetX, targetY) then
            IssueImmediateOrderById(caster, ORDER_ID_STOP)
            DisplayTextToPlayer(Player(pid - 1), 0, 0, INVALID_TARGET_MESSAGE)
            return false
        end

        return true
    end

end, Debug and Debug.getLine())
