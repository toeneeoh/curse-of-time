OnInit.global("Progression", function(Require)
    Require('Variables')
    Require('Users')
    Require('WorldUnitQueries')
    Require('FloatingText')

    PrestigeTable = array2d(0) ---@type table
    EXPERIENCE_TABLE = {}
    GOLD_TABLE = {}
    BASE_XP_RATE = __jarray(0) ---@type number[]

    for level = 1, MAX_LEVEL do
        EXPERIENCE_TABLE[level] = math.floor(20 + 13. * level * 1.4 ^ (level / 20))
        GOLD_TABLE[level] = EXPERIENCE_TABLE[level] ^ 0.94
    end

    for level = 0, 400 do
        BASE_XP_RATE[level] = (level <= 1 and 100) or (BASE_XP_RATE[level - 1] * 0.988)
    end

    ---@param level integer
    ---@return integer
    function RequiredXP(level)
        local base = 150
        local level_factor = 100
        for i = 2, level do
            base = base + i * level_factor
        end
        return base
    end

    ---@param pid integer
    function ExperienceControl(pid)
        local level = GetHeroLevel(Hero[pid])
        Unit[Hero[pid]].xp_rate = math.max(0, BASE_XP_RATE[level])
    end

    ---@type fun(pid: integer, xp: number)
    function AwardXP(pid, xp)
        xp = math.floor(xp)
        SetHeroXP(Hero[pid], GetHeroXP(Hero[pid]) + xp, true)
        ExperienceControl(pid)
        FloatingTextUnit("+" .. xp .. " XP", Hero[pid], 2, 80, 0, 10, 204, 0, 204, 0, false)
    end

    ---@type fun(killed: unit, killer: unit)
    function RewardXPGold(killed, killer)
        local killer_pid = GetPlayerId(GetOwningPlayer(killer)) + 1
        local recipients = {}
        local level = GetUnitLevel(killed)
        local user = User.first

        while user do
            if user.id ~= killer_pid and IsUnitInRange(Hero[user.id], killed, 1800.)
                and UnitAlive(Hero[user.id])
                and GetHeroLevel(Hero[user.id]) >= level - 20
                and GetHeroLevel(Hero[user.id]) >= GetUnitLevel(Hero[killer_pid]) - LEECH_CONSTANT then
                recipients[#recipients + 1] = user.id
            end
            user = user.next
        end

        if GetHeroLevel(Hero[killer_pid]) >= level - 20 then
            recipients[#recipients + 1] = killer_pid
        end

        local main_gold = GOLD_TABLE[level]
        local team_gold = 0
        local experience = EXPERIENCE_TABLE[level] * 0.007
        local boss = IsBoss(killed)

        if boss then
            experience = experience * 10. * boss.difficulty
            main_gold = experience * 90 * boss.difficulty
        end

        if #recipients > 0 then
            experience = experience * (1.2 / #recipients)
            team_gold = main_gold * (1. / #recipients)
        end

        for i = 1, #recipients do
            local pid = recipients[i]
            local xp = math.floor(experience * Unit[Hero[pid]].xp_rate)
            AwardGold(pid, team_gold, false)
            AwardXP(pid, xp)
        end
    end
end)

OnInit.final("ProgressionRuntime", function(Require)
    Require('Progression')
    Require('Profile')
    Require('TimerQueue')

    TimerQueue:callPeriodically(60., nil, function()
        local user = User.first

        while user do
            local profile = Profile[user.id]
            if profile and profile.playing then
                profile.hero.time = profile.hero.time + 1
                profile.total_time = profile.total_time + 1
                ExperienceControl(user.id)
            end
            user = user.next
        end
    end)
end, Debug and Debug.getLine())
