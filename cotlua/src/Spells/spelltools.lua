OnInit.final("SpellTools", function()

    function MISSILE_DISTANCE(self, _)
        self.dist = self.dist - self.speed * ALICE_Config.MIN_INTERVAL
        if self.dist < 0 then
            ALICE_Kill(self)
        end
    end

    function VALID_DAMAGE_TARGET(object, self)
        return UnitAlive(object) and IsUnitEnemy(object, self.owner)
    end

    function VALID_PULL_TARGET(object, self)
        return UnitAlive(object) and IsUnitEnemy(object, self.owner) and GetUnitMoveSpeed(object) > 0
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
