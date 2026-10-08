OnInit.global("WorldUnitQueries", function(Require)
    Require('BossSchema')
    Require('Variables')

    local similar_units = {
        [FourCC('nitt')] = FourCC('n0tb'),
        [FourCC('n0tw')] = FourCC('n0ts'),
        [FourCC('n0tc')] = FourCC('n0ts'),
        [FourCC('n0sl')] = FourCC('n0ss'),
        [FourCC('n0us')] = FourCC('n0uw'),
        [FourCC('n0po')] = FourCC('n0dm'),
        [FourCC('o01G')] = FourCC('n01G'),
        [FourCC('n0ut')] = FourCC('n0ud'),
        [FourCC('n0ub')] = FourCC('n0ud'),
        [FourCC('n0hh')] = FourCC('n0hs'),
        [FourCC('n027')] = FourCC('n024'),
        [FourCC('n028')] = FourCC('n024'),
        [FourCC('n08M')] = FourCC('n01M'),
        [FourCC('n01R')] = FourCC('n02P'),
        [FourCC('n00C')] = FourCC('n02L'),
        [FourCC('E007')] = FourCC('H00O'),
        [FourCC('n033')] = FourCC('n034'),
        [FourCC('n03B')] = FourCC('n03A'),
        [FourCC('n03C')] = FourCC('n03A'),
        [FourCC('n01W')] = FourCC('n03F'),
        [FourCC('n00W')] = FourCC('n08N'),
        [FourCC('n00X')] = FourCC('n08N'),
        [FourCC('n030')] = FourCC('n031'),
        [FourCC('n02Z')] = FourCC('n031'),
        [FourCC('n02J')] = FourCC('n020'),
        [FourCC('n03E')] = FourCC('n03D'),
        [FourCC('n03G')] = FourCC('n03D'),
        [FourCC('n01X')] = FourCC('n03J'),
        [FourCC('n01V')] = FourCC('n03M'),
        [FourCC('n03T')] = FourCC('n026'),
    }

    ---@type fun(id: any): integer
    function GetType(id)
        if type(id) == "userdata" then id = GetUnitTypeId(id) end
        return similar_units[id] or id
    end

    ---@type fun(u: any): Boss|nil
    function IsBoss(u)
        local uid = (type(u) == "number" and u) or GetType(GetUnitTypeId(u))
        for i = BOSS_OFFSET, #Boss do
            if Boss[i].id == uid then return Boss[i] end
        end
        return nil
    end

    ---@param enemy integer|unit
    ---@return boolean
    function IsEnemy(enemy)
        if type(enemy) == "userdata" then
            enemy = GetPlayerId(GetOwningPlayer(enemy)) + 1
        end
        return enemy >= 12
    end
end)
