-- Ashen Vanguard faction definition, rare hunts, and Grand Hunt event.

OnInit.final("AshenVanguard", function(Require)
    Require('Faction')
    Require('FactionEvents')
    Require('BuffsWorldFactions')
    Require('Currency')
    Require('Damage')
    Require('Events')
    Require('Groups')
    Require('MainMap')
    Require('Progression')
    Require('ShopActions')
    Require('TimerQueue')
    Require('UnitTable')
    Require('Units')
    Require('Users')
    Require('Variables')

    local ASHEN_VANGUARD_ID = 3
    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3
    local RARE_SEARCH_RADIUS = 6000.
    local RARE_CREDIT_RADIUS = 2500.
    local RARE_RETRY_DELAY = 5.
    local EVENT_RADIUS = 3500.
    local EVENT_TIMEOUT = 600.
    local EVENT_REWARD = 30
    local EVENT_PRESENCE_REQUIRED = 30
    local SHARED_BLESSING_DURATION = 300.
    local HUNT_RENOWN_REQUIRED = 12
    local BOUNTY_MAX_STACKS = 3
    local BOUNTY_REQUIRED_RANK = 4
    local BOUNTY_SERVICE_COOLDOWN = 900.
    local BOUNTY_DROP_MULTIPLIER = 1.25

    local ashen_vanguard = Faction.create(
        ASHEN_VANGUARD_ID,
        "Ashen Vanguard",
        -8800.,
        -13124.,
        AshenVanguardBuff,
        "The Ashen Vanguard hunt the most dangerous creatures unleashed by Chaos and reward those who seek varied, formidable quarry.|n|n|cffffcc00Membership, rank progress, and unspent Faction Points are saved with this character.|r",
        "ReplaceableTextures\\CommandButtons\\BTNHarbingerHelm.blp"
    )

    local rare_by_unit = setmetatable({}, { __mode = 'k' })
    local rare_by_player = {}
    local rare_retry = {}

    local function is_member(pid)
        local faction = Faction.getFaction(pid)
        return faction and faction.id == ASHEN_VANGUARD_ID
    end

    local function announce(message, sound)
        local user = User.first
        while user do
            if is_member(user.id) then
                DisplayTextToPlayer(user.player, 0., 0., message)
                if sound then
                    StartSoundForPlayerBJ(user.player, sound)
                end
            end
            user = user.next
        end
    end

    local function format_time(time)
        local total = math.max(0, math.ceil(time or 0.))
        return string.format("%d:%02d", total // 60, total % 60)
    end

    local function save_visuals(unit)
        return {
            name = GetUnitName(unit),
            scale = BlzGetUnitRealField(unit, UNIT_RF_SCALING_VALUE),
            red = BlzGetUnitIntegerField(unit, UNIT_IF_TINTING_COLOR_RED),
            green = BlzGetUnitIntegerField(unit, UNIT_IF_TINTING_COLOR_GREEN),
            blue = BlzGetUnitIntegerField(unit, UNIT_IF_TINTING_COLOR_BLUE),
        }
    end

    local function restore_visuals(state)
        if not UnitAlive(state.unit) then return end
        local visual = state.visual
        BlzSetUnitName(state.unit, visual.name)
        SetUnitScale(state.unit, visual.scale, visual.scale, visual.scale)
        SetUnitVertexColor(state.unit, visual.red, visual.green, visual.blue, 255)
    end

    local function release_rare(state)
        if not state or not state.active then return end
        state.active = false
        if state.pulse_callback then
            TimerQueue:disableCallback(state.pulse_callback)
            state.pulse_callback = nil
        end
        if state.effect then
            DestroyEffect(state.effect)
            state.effect = nil
        end
        rare_by_unit[state.unit] = nil
        if state.pid and rare_by_player[state.pid] then
            rare_by_player[state.pid][state.unit] = nil
        end
        OverworldCreeps.restore(state.unit)
        restore_visuals(state)
    end

    local function resolve_pulse(state, warning, x, y)
        DestroyEffect(warning)
        if not state.active or not UnitAlive(state.unit) then return end
        local user = User.first
        while user do
            local hero = Hero[user.id]
            if hero and UnitAlive(hero)
                and IsUnitInRangeXY(hero, x, y, state.pulse_radius) then
                DamageTarget(state.unit, hero,
                    BlzGetUnitMaxHP(hero) * state.pulse_damage,
                    ATTACK_TYPE_NORMAL, PURE, "Rare Eruption")
            end
            user = user.next
        end
        DestroyEffect(AddSpecialEffect(
            "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl", x, y))
    end

    local function rare_pulse(state)
        state.pulse_callback = nil
        if not state.active or not UnitAlive(state.unit) then return end
        local x, y = GetUnitX(state.unit), GetUnitY(state.unit)
        local warning = AddSpecialEffect("Indicators\\circle.mdl", x, y)
        BlzSetSpecialEffectScale(warning, state.pulse_radius / 500.)
        TimerQueue:callDelayed(1.5, resolve_pulse, state, warning, x, y)
        state.pulse_callback = TimerQueue:callDelayed(state.pulse_interval,
            rare_pulse, state)
    end

    local variants = {
        {
            prefix = "Brutal",
            color = { 255, 185, 70 },
            health = 5.,
            damage = 2.,
            radius = 325.,
            pulse_damage = 0.10,
            interval = 8.,
        },
        {
            prefix = "Eldritch",
            color = { 100, 175, 255 },
            health = 4.,
            damage = 1.75,
            radius = 425.,
            pulse_damage = 0.08,
            interval = 7.,
        },
    }

    local function promote(unit, pid, kind, config)
        if not OverworldCreeps.promoteRare(unit, config.health, config.damage) then
            return nil
        end
        local visual = save_visuals(unit)
        local state = {
            active = true,
            unit = unit,
            pid = pid,
            kind = kind,
            visual = visual,
            pulse_radius = config.radius,
            pulse_damage = config.pulse_damage,
            pulse_interval = config.interval,
        }
        rare_by_unit[unit] = state
        if pid then
            rare_by_player[pid] = rare_by_player[pid] or setmetatable({}, { __mode = 'k' })
            rare_by_player[pid][unit] = state
        end
        BlzSetUnitName(unit, config.prefix .. " " .. visual.name)
        local scale = visual.scale * (config.scale or 1.25)
        SetUnitScale(unit, scale, scale, scale)
        SetUnitVertexColor(unit, config.color[1], config.color[2], config.color[3], 255)
        state.effect = AddSpecialEffectTarget(
            "Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", unit, "overhead")
        state.pulse_callback = TimerQueue:callDelayed(
            GetRandomReal(4., config.interval), rare_pulse, state)
        return state
    end

    local function collect_candidates(pid, desired_level)
        local nearby, available = {}, {}
        local hero = pid and Hero[pid] or nil
        local hero_x = hero and GetUnitX(hero) or 0.
        local hero_y = hero and GetUnitY(hero) or 0.
        local group = CreateGroup()
        GroupEnumUnitsInRect(group, MAIN_MAP.rect, nil)
        local unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if OverworldCreeps.isRegular(unit) and not rare_by_unit[unit]
                and not Unit[unit].target then
                local valid = true
                if pid then
                    valid = Progression.getLevelDifferenceMultiplier(
                        GetHeroLevel(hero), GetUnitLevel(unit)) >= 0.5
                end
                if valid then
                    local entry = {
                        unit = unit,
                        difference = math.abs(GetUnitLevel(unit)
                            - (desired_level or GetUnitLevel(unit))),
                    }
                    available[#available + 1] = entry
                    if hero and DistanceCoords(hero_x, hero_y,
                        GetUnitX(unit), GetUnitY(unit)) <= RARE_SEARCH_RADIUS then
                        nearby[#nearby + 1] = entry
                    end
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        if pid and #nearby > 0 then return nearby end
        table.sort(available, function(a, b) return a.difference < b.difference end)
        return available
    end

    local ensure_rare_targets

    local function retry_rare_targets(pid)
        rare_retry[pid] = nil
        ensure_rare_targets(pid)
    end

    local function active_rare_count(pid)
        local count = 0
        for _, state in pairs(rare_by_player[pid] or {}) do
            if state.active and UnitAlive(state.unit) then count = count + 1 end
        end
        return count
    end

    ensure_rare_targets = function(pid)
        local quest, progress = Quest.getActive(pid)
        if not quest or quest.kind ~= "rare_hunt" or not Hero[pid] then return end
        local desired = math.max(0, quest.goal - math.floor(progress))
        local needed = math.max(0, desired - active_rare_count(pid))
        if needed <= 0 then return end
        local candidates = collect_candidates(pid)
        for _ = 1, needed do
            if #candidates == 0 then break end
            local upper = math.min(#candidates, 8)
            local choice = math.random(1, upper)
            local entry = table.remove(candidates, choice)
            local variant = variants[math.random(1, #variants)]
            local state = promote(entry.unit, pid, "quest", variant)
            if state and GetLocalPlayer() == Player(pid - 1) then
                PingMinimap(GetUnitX(entry.unit), GetUnitY(entry.unit), 3.)
            end
        end
        if active_rare_count(pid) < desired and not rare_retry[pid] then
            rare_retry[pid] = TimerQueue:callDelayed(
                RARE_RETRY_DELAY, retry_rare_targets, pid)
        end
    end

    local function end_rare_hunt(pid)
        if rare_retry[pid] then
            TimerQueue:disableCallback(rare_retry[pid])
            rare_retry[pid] = nil
        end
        local states = {}
        for _, state in pairs(rare_by_player[pid] or {}) do
            states[#states + 1] = state
        end
        for index = 1, #states do
            release_rare(states[index])
        end
        rare_by_player[pid] = nil
    end

    local function rare_death(killed)
        local state = rare_by_unit[killed]
        if not state or state.kind ~= "quest" then return end
        local pid = state.pid
        local hero = Hero[pid]
        local credited = hero and UnitAlive(hero)
            and IsUnitInRange(hero, killed, RARE_CREDIT_RADIUS)
        release_rare(state)
        if credited then
            Quest.progress(pid, "rare_hunt")
        end
        ensure_rare_targets(pid)
    end

    local function begin_rare_hunt(pid)
        ensure_rare_targets(pid)
        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            "|cffffcc00Ashen Vanguard:|r Rare quarry has been marked on your minimap.")
    end

    Unit.onIndex(function(unit)
        if UnitData[GetUnitTypeId(unit)] then
            EVENT_ON_UNIT_DEATH:register_unit_action(unit, rare_death)
        end
    end)

    ashen_vanguard:addQuest(Quest.create(
        "Varied Quarry",
        "Defeat 4 different enemy types that grant at least 50% rewards.\n\n|cffffcc00Reward:|r 5 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNSpy.blp",
        QUEST_DIFF_EASY,
        "distinct_enemy_types", 4, 5, 5
    ))

    local rare_specimens = Quest.create(
        "Rare Specimens",
        "Hunt 2 empowered rare variants marked when this quest is accepted. Remain within 2500 range when each target dies.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNEnsnare.blp",
        QUEST_DIFF_MEDIUM,
        "rare_hunt", 2, 10, 10
    )
    rare_specimens.accept_action = begin_rare_hunt
    rare_specimens.end_action = end_rare_hunt
    ashen_vanguard:addQuest(rare_specimens)

    ashen_vanguard:addQuest(Quest.create(
        "Dangerous Game",
        "Help defeat 2 different bosses within 20 levels of your hero. Endgame bosses always count.\n\n|cffffcc00Reward:|r 10 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNMarkOfFire.blp",
        QUEST_DIFF_MEDIUM,
        "distinct_bosses", 2, 10, 10
    ))

    local legendary_quarry = Quest.create(
        "Legendary Quarry",
        "Hunt 4 empowered rare variants marked when this quest is accepted. Remain within 2500 range when each target dies.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNCriticalStrike.blp",
        QUEST_DIFF_HARD,
        "rare_hunt", 4, 20, 20, 3
    )
    legendary_quarry.accept_action = begin_rare_hunt
    legendary_quarry.end_action = end_rare_hunt
    ashen_vanguard:addQuest(legendary_quarry)

    ashen_vanguard:addQuest(Quest.create(
        "Vanguard's Ledger",
        "Help defeat 4 different bosses within 20 levels of your hero. Endgame bosses always count.\n\n|cffffcc00Reward:|r 20 Faction Points",
        "ReplaceableTextures\\CommandButtons\\BTNManual3.blp",
        QUEST_DIFF_HARD,
        "distinct_bosses", 4, 20, 20, 3
    ))
    ashen_vanguard:addGenericQuests()

    local function rank_damage(rank)
        if rank >= 7 then return 0.12 end
        if rank >= 4 then return 0.08 end
        return 0.05
    end

    local grand_active = false
    AshenVanguardBuff.getFactionDamage = function(target)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        return rank_damage(Faction.getRank(
                               Faction.getReputation(pid,
                                                     ASHEN_VANGUARD_ID)))
    end
    SharedAshenVanguardBuff.getRankDamage = rank_damage

    AshenVanguardServices = {}
    local hunt_renown = 0
    local bounty_stacks = 0
    local bounty_cooldown ---@type integer?

    local function notify_bounty_changed()
        local user = User.first
        while user do
            NotifyShopActionChanged(user.id)
            user = user.next
        end
    end

    local function clear_bounty_cooldown()
        bounty_cooldown = nil
        notify_bounty_changed()
    end

    function AshenVanguardServices.shareBlessing(pid)
        local success, shared = Faction.shareBlessing(
                                    pid, ASHEN_VANGUARD_ID,
                                    SharedAshenVanguardBuff,
                                    SHARED_BLESSING_DURATION)
        if not success then return false end
        DisplayTimedTextToForce(FORCE_PLAYING, 15.,
            User[pid - 1].nameColored ..
                " shared their Ashen Vanguard blessing with " .. shared ..
                " allied hero" .. (shared == 1 and "." or "es."))
        return true
    end

    function AshenVanguardServices.getBountyState()
        local remaining = bounty_cooldown and
                              (TimerQueue:getRemaining(bounty_cooldown) or 0.) or
                              0.
        return hunt_renown, HUNT_RENOWN_REQUIRED, bounty_stacks,
               BOUNTY_MAX_STACKS, remaining, BOUNTY_SERVICE_COOLDOWN
    end

    function AshenVanguardServices.canPurchaseBounty(pid)
        if not is_member(pid) then return false, "WRONG FACTION" end
        local rank = Faction.getRank(
                         Faction.getReputation(pid, ASHEN_VANGUARD_ID))
        if rank < BOUNTY_REQUIRED_RANK then
            return false, "REQUIRES RANK " .. BOUNTY_REQUIRED_RANK
        end
        if bounty_stacks >= BOUNTY_MAX_STACKS then
            return false, "BOUNTIES FULL"
        end
        if hunt_renown < HUNT_RENOWN_REQUIRED then
            return false, "REQUIRES " .. HUNT_RENOWN_REQUIRED ..
                       " HUNT RENOWN"
        end
        if bounty_cooldown and
            (TimerQueue:getRemaining(bounty_cooldown) or 0.) > 0. then
            return false, "COOLDOWN"
        end
        return true
    end

    function AshenVanguardServices.purchaseBounty(pid)
        if not AshenVanguardServices.canPurchaseBounty(pid) then return false end
        hunt_renown = hunt_renown - HUNT_RENOWN_REQUIRED
        bounty_stacks = bounty_stacks + 1
        bounty_cooldown = TimerQueue:callDelayed(
                              BOUNTY_SERVICE_COOLDOWN,
                              clear_bounty_cooldown)
        announce(User[pid - 1].nameColored ..
            " commissioned a |cffffcc00Vanguard Bounty|r. " ..
            bounty_stacks .. " / " .. BOUNTY_MAX_STACKS .. " stored.",
            bj_questCompletedSound)
        notify_bounty_changed()
        return true
    end

    function AshenVanguardServices.addHuntRenown(amount, contributor)
        amount = math.max(0, math.floor(amount or 0))
        if amount == 0 then return false end
        hunt_renown = hunt_renown + amount
        local progress = math.min(hunt_renown, HUNT_RENOWN_REQUIRED)
        announce("|cffffcc00Hunt Renown:|r " .. progress .. " / " ..
            HUNT_RENOWN_REQUIRED .. (contributor and
            (" |cff808080(" .. contributor .. ")|r") or ""))
        notify_bounty_changed()
        return true
    end

    ---Consumes one lobby bounty when an eligible Ashen member is present for
    ---a Chaos boss kill, returning the multiplier for that boss's drop rolls.
    function AshenVanguardServices.consumeBountyForBoss(boss, x, y)
        if not CHAOS_MODE or bounty_stacks <= 0 then return 1. end
        local user = User.first
        local eligible = false
        while user do
            local hero = Hero[user.id]
            if is_member(user.id) and hero and UnitAlive(hero) and
                IsUnitInRangeXY(hero, x, y, 2500.) and
                GetHeroLevel(hero) >= boss.level then
                eligible = true
                break
            end
            user = user.next
        end
        if not eligible then return 1. end

        bounty_stacks = bounty_stacks - 1
        DisplayTimedTextToForce(FORCE_PLAYING, 15.,
            "|cffffcc00Vanguard Bounty claimed:|r " .. boss.name ..
                " has improved drop rates. " .. bounty_stacks .. " / " ..
                BOUNTY_MAX_STACKS .. " remain.")
        notify_bounty_changed()
        return BOUNTY_DROP_MULTIPLIER
    end

    Faction.registerQuestCompletionAction(function(pid, faction)
        if faction and faction.id == ASHEN_VANGUARD_ID then
            AshenVanguardServices.addHuntRenown(
                1, User[pid - 1].nameColored .. " completed a quest")
        end
    end)

    local grand_state
    local grand_timeout ---@type integer?
    local grand_presence ---@type integer?
    local grand_contribution = {}
    local finish_grand_hunt

    local function event_members()
        local result = {}
        local user = User.first
        while user do
            if is_member(user.id) and Hero[user.id] and UnitAlive(Hero[user.id]) then
                result[#result + 1] = user.id
            end
            user = user.next
        end
        return result
    end

    local function ping_members(x, y)
        local user = User.first
        while user do
            if is_member(user.id) and GetLocalPlayer() == user.player then
                PingMinimap(x, y, 5.)
            end
            user = user.next
        end
    end

    local function track_grand_damage(target, source, _amount, amount_after_red)
        if not grand_active or not grand_state or target ~= grand_state.unit
            or not source or amount_after_red <= 0. then return end
        local pid = GetPlayerId(GetOwningPlayer(source)) + 1
        if pid <= PLAYER_CAP and is_member(pid) then
            local contribution = grand_contribution[pid]
                or { presence = 0, damage = 0. }
            grand_contribution[pid] = contribution
            contribution.damage = contribution.damage
                + math.min(amount_after_red, GetWidgetLife(target))
        end
    end

    local function grand_presence_tick()
        grand_presence = nil
        if not grand_active or not grand_state or not UnitAlive(grand_state.unit) then return end
        local x, y = GetUnitX(grand_state.unit), GetUnitY(grand_state.unit)
        local members = event_members()
        for index = 1, #members do
            local pid = members[index]
            local hero = Hero[pid]
            if DistanceCoords(x, y, GetUnitX(hero), GetUnitY(hero)) <= EVENT_RADIUS then
                local contribution = grand_contribution[pid]
                    or { presence = 0, damage = 0. }
                grand_contribution[pid] = contribution
                contribution.presence = contribution.presence + 1
            end
        end
        grand_presence = TimerQueue:callDelayed(1., grand_presence_tick)
    end

    local function grand_death(killed)
        if grand_active and grand_state and killed == grand_state.unit then
            finish_grand_hunt(true)
        end
    end

    local function stop_grand_callbacks()
        if grand_timeout then TimerQueue:disableCallback(grand_timeout) end
        if grand_presence then TimerQueue:disableCallback(grand_presence) end
        grand_timeout = nil
        grand_presence = nil
    end

    finish_grand_hunt = function(success)
        if not grand_active or not grand_state then return false end
        grand_active = false
        stop_grand_callbacks()
        local target = grand_state.unit
        EVENT_ON_STRUCK_FINAL:unregister_unit_action(target, track_grand_damage)
        local maximum = math.max(1., BlzGetUnitMaxHP(target))
        local fraction = success and 1. or math.max(0., math.min(1.,
            (maximum - math.max(0., GetWidgetLife(target))) / maximum))
        local reward = math.floor(EVENT_REWARD * fraction + 0.5)
        local rewarded = 0
        if reward > 0 then
            for pid, contribution in pairs(grand_contribution) do
                if is_member(pid) and (contribution.presence >= EVENT_PRESENCE_REQUIRED
                    or contribution.damage > 0.) then
                    AddCurrency(pid, FACTION, reward)
                    Faction.addReputation(pid, reward)
                    if success then
                        Quest.progress(pid, "faction_event")
                        StartSoundForPlayerBJ(Player(pid - 1), bj_questCompletedSound)
                    else
                        StartSoundForPlayerBJ(Player(pid - 1), bj_questUpdatedSound)
                    end
                    rewarded = rewarded + 1
                end
            end
        end
        if success then
            if rewarded > 0 then
                AshenVanguardServices.addHuntRenown(3,
                                                    "Grand Hunt completed")
            end
            announce("|cff80ff80Grand Hunt complete!|r " .. rewarded
                .. " hunter" .. (rewarded == 1 and " was" or "s were") .. " rewarded.")
        else
            announce("|cffffcc00Grand Hunt ended at "
                .. math.floor(fraction * 100. + 0.5) .. "% damage.|r "
                .. rewarded .. " hunter" .. (rewarded == 1 and " receives " or "s receive ")
                .. reward .. " Faction Points.", bj_questFailedSound)
        end
        release_rare(grand_state)
        grand_state = nil
        grand_contribution = {}
        return true
    end

    local function start_grand_hunt()
        if grand_active or not CHAOS_MODE then return false end
        local members = event_members()
        local total_level = 0
        for index = 1, #members do
            total_level = total_level + GetHeroLevel(Hero[members[index]])
        end
        local level = #members > 0 and math.floor(total_level / #members) or 200
        local candidates = collect_candidates(nil, level)
        if #candidates == 0 then return false end
        local entry = candidates[math.random(1, math.min(8, #candidates))]
        local config = {
            prefix = "Grand Quarry:",
            color = { 255, 80, 40 },
            health = 20.,
            damage = 2.75,
            radius = 475.,
            pulse_damage = 0.15,
            interval = 6.,
            scale = 1.5,
        }
        grand_state = promote(entry.unit, nil, "event", config)
        if not grand_state then return false end
        grand_active = true
        grand_contribution = {}
        EVENT_ON_STRUCK_FINAL:register_unit_action(grand_state.unit, track_grand_damage)
        EVENT_ON_UNIT_DEATH:register_unit_action(grand_state.unit, grand_death)
        local x, y = GetUnitX(grand_state.unit), GetUnitY(grand_state.unit)
        ping_members(x, y)
        announce("|cffffcc00Faction Event: Grand Hunt|r\nA legendary quarry has been marked. Track it down and deal as much damage as possible within 10 minutes.",
            bj_questDiscoveredSound)
        grand_presence = TimerQueue:callDelayed(1., grand_presence_tick)
        grand_timeout = TimerQueue:callDelayed(EVENT_TIMEOUT, finish_grand_hunt, false)
        return true
    end

    local function grand_status(_pid, _remaining)
        if grand_active and grand_state then
            return "|cffff6040Grand Hunt|r\n\nTrack and defeat "
                .. GetUnitName(grand_state.unit) .. " before time expires."
        end
        return "|cffff6040Grand Hunt|r\n\nTrack a legendary rare creature and defeat it before the hunt ends."
    end

    local function grand_hud(pid)
        if not grand_active or not grand_state or not is_member(pid) then return nil end
        local unit = grand_state.unit
        local health = UnitAlive(unit) and math.max(0., GetWidgetLife(unit)) or 0.
        local maximum = math.max(1., BlzGetUnitMaxHP(unit))
        return "|cffff6040Grand Hunt|r  |  " .. GetUnitName(unit) .. ": "
            .. math.floor(health / maximum * 100.) .. "%\nTime: "
            .. format_time(grand_timeout and TimerQueue:getRemaining(grand_timeout) or 0.)
    end

    local function warn_grand_hunt()
        announce("|cffffcc00Faction Event:|r Grand Hunt begins in 5 minutes.",
            bj_questWarningSound)
    end

    local start_now
    if DEV_ENABLED then
        start_now = function()
            if grand_active then finish_grand_hunt(false) end
            return start_grand_hunt()
        end
    end

    FactionEvents.register(ASHEN_VANGUARD_ID, {
        name = "Grand Hunt",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMarkOfFire.blp",
        description = "Track an empowered rare creature somewhere in the Chaos world and defeat it within 10 minutes. Its location is marked when the event begins, and it periodically unleashes a telegraphed eruption. Remain near the quarry for at least 30 seconds or damage it to qualify.\n\nAll eligible hunters receive up to |cffffcc0030 Faction Points|r based on the percentage of its health removed.",
        activate = function() return true end,
        start = start_grand_hunt,
        warning = warn_grand_hunt,
        isActive = function() return grand_active end,
        getStatus = grand_status,
        getHudStatus = grand_hud,
        startNow = start_now,
    })
end, Debug and Debug.getLine())
