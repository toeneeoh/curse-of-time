OnInit.global("Progression", function(Require)
    Require('Variables')
    Require('Users')
    Require('WorldUnitQueries')
    Require('RewardNotifications')

    EXPERIENCE_TABLE = {}
    GOLD_TABLE = {}
    BASE_XP_RATE = __jarray(0) ---@type number[]
    Progression = {}

    local XP_PER_LEVEL = 10000
    local SOLO_PARTY_BONUS = 1.2
    local STARTING_KILLS_PER_LEVEL = 10.
    local LINEAR_KILL_GROWTH = 20.
    local LATE_KILL_GROWTH = 20.
    local shared_xp_bonus = function() return 0. end

    -- XP uses a flat 10,000-point level band. The reward curve supplies the
    -- progression slowdown instead: an equal-level solo hero moves gradually
    -- from roughly 10 normal kills per level at level 1 to 50 at level 500.
    -- The quadratic term keeps early progression brisk while making the chaos
    -- levels increasingly deliberate without an exponential wall.
    -- Gold deliberately retains the old economy curve and is not derived from
    -- the new XP values.
    for level = 1, MAX_LEVEL do
        local progress = (level - 1.) / math.max(1., MAX_LEVEL - 1.)
        local kills = STARTING_KILLS_PER_LEVEL + LINEAR_KILL_GROWTH * progress
            + LATE_KILL_GROWTH * progress * progress
        local economy_value = math.floor(20 + 13. * level * 1.4 ^ (level / 20))

        EXPERIENCE_TABLE[level] = math.floor(XP_PER_LEVEL / (kills * SOLO_PARTY_BONUS) + 0.5)
        GOLD_TABLE[level] = economy_value ^ 0.94
    end

    -- Character level no longer applies a second exponential penalty. The
    -- desired slowdown is already represented by EXPERIENCE_TABLE.
    for level = 0, MAX_LEVEL do
        BASE_XP_RATE[level] = 100.
    end

    ---Returns the amount required to advance one level.
    ---@param _ integer
    ---@return integer
    function RequiredXP(_)
        return XP_PER_LEVEL
    end

    ---@param hero unit
    ---@return integer
    function Progression.getXPIntoLevel(hero)
        local level = math.min(MAX_LEVEL, GetHeroLevel(hero))
        local level_start = math.max(0, level - 1) * XP_PER_LEVEL
        return math.max(0, math.min(XP_PER_LEVEL, GetHeroXP(hero) - level_start))
    end

    ---@param level integer
    ---@param progress integer
    ---@return integer
    function Progression.getCumulativeXP(level, progress)
        level = math.max(1, math.min(MAX_LEVEL, level))
        progress = math.max(0, math.min(XP_PER_LEVEL - 1, progress))
        return (level - 1) * XP_PER_LEVEL + progress
    end

    ---Smoothly reduces rewards from enemies below the recipient's level and
    ---gives a modest bonus for enemies above it. Reward eligibility separately
    ---limits the latter case to enemies at most 20 levels higher.
    ---@param hero_level number
    ---@param enemy_level number
    ---@return number
    function Progression.getLevelDifferenceMultiplier(hero_level, enemy_level)
        local difference = hero_level - enemy_level

        if difference <= 0. then
            return math.min(1.5, 1. - difference * 0.025)
        end

        local ratio = difference / LEVEL_REWARD_FALLOFF
        return 1. / (1. + ratio * ratio)
    end

    ---Registers the profile/lobby layer that supplies the shared XP bonus.
    ---The returned value is a decimal multiplier bonus, such as 0.05 for 5%.
    ---@param provider fun(): number
    function Progression.setSharedXPBonusProvider(provider)
        shared_xp_bonus = provider
    end

    ---@param pid integer
    function ExperienceControl(pid)
        local level = GetHeroLevel(Hero[pid])
        Unit[Hero[pid]].xp_rate = math.max(0, BASE_XP_RATE[level]) * (1. + shared_xp_bonus())
    end

    ---@type fun(pid: integer, xp: number)
    function AwardXP(pid, xp)
        xp = math.floor(xp)
        local hero = Hero[pid]
        local previous_level = GetHeroLevel(hero)

        if xp <= 0 or previous_level >= MAX_LEVEL then
            return
        end

        local previous_xp = GetHeroXP(hero)
        local new_xp = math.min(previous_xp + xp, MAX_LEVEL * XP_PER_LEVEL - 1)
        local awarded_xp = new_xp - previous_xp

        if awarded_xp <= 0 then
            return
        end

        local started_at = os.clock()
        SetHeroXP(hero, new_xp, true)
        local elapsed = os.clock() - started_at
        local metrics = RuntimeMetrics.leveling
        metrics.xp_awards = metrics.xp_awards + 1
        metrics.xp_award_time = metrics.xp_award_time + elapsed
        if GetHeroLevel(Hero[pid]) > previous_level then
            metrics.leveling_awards = metrics.leveling_awards + 1
            metrics.leveling_award_time = metrics.leveling_award_time + elapsed
            metrics.max_leveling_award_time = math.max(metrics.max_leveling_award_time, elapsed)
        end
        -- EVENT_PLAYER_HERO_LEVEL recalculates the rate whenever this award
        -- actually changes the hero's level. Otherwise the rate is unchanged.
        RuntimeMetrics.rewards.xp_rate_refreshes_saved = RuntimeMetrics.rewards.xp_rate_refreshes_saved + 1
        RewardNotifications.xp(pid, awarded_xp)
    end

    ---@type fun(killed: unit, killer: unit)
    function RewardXPGold(killed, killer)
        local killer_pid = GetPlayerId(GetOwningPlayer(killer)) + 1
        local recipients = {}
        local level = GetUnitLevel(killed)
        local user = User.first

        -- Eligibility is measured against the defeated unit rather than the
        -- killer. A low-level hero still cannot receive high-level rewards,
        -- while a legitimate party member cannot fall out of XP range merely
        -- because another member advanced more quickly.
        while user do
            if user.id ~= killer_pid and IsUnitInRange(Hero[user.id], killed, 1800.)
                and UnitAlive(Hero[user.id])
                and GetHeroLevel(Hero[user.id]) >= level - 20 then
                recipients[#recipients + 1] = user.id
            end
            user = user.next
        end

        if GetHeroLevel(Hero[killer_pid]) >= level - 20 then
            recipients[#recipients + 1] = killer_pid
        end

        level = math.max(1, math.min(MAX_LEVEL, level))
        local main_gold = GOLD_TABLE[level]
        local team_gold = 0
        local experience = EXPERIENCE_TABLE[level]
        local boss = IsBoss(killed)

        if boss then
            experience = experience * 10. * boss.difficulty
            -- Preserve the established boss-gold economy independently from
            -- the new XP curve.
            local economy_value = math.floor(20 + 13. * level * 1.4 ^ (level / 20))
            main_gold = economy_value * 0.007 * 10. * boss.difficulty
                * 90. * boss.difficulty
        end

        if #recipients > 0 then
            experience = experience * (1.2 / #recipients)
            team_gold = main_gold * (1. / #recipients)
        end

        for i = 1, #recipients do
            local pid = recipients[i]
            local hero = Hero[pid]
            local level_multiplier = Progression.getLevelDifferenceMultiplier(
                GetHeroLevel(hero), level)
            local xp = math.floor(experience * Unit[hero].xp_rate * 0.01
                * level_multiplier)
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
