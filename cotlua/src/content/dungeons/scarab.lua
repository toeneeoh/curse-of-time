-- Public crawl entrance. Boss access and rewards are not yet connected.
OnInit.final('ScarabDungeon', function(Require)
    Require('Dungeons')
    Require('ScarabCrawl')
    Require('PlayerLifecycle')
    Require('TimerQueue')
    Require('UnitTable')

    DUNGEON_SCARAB = Dungeon.define('scarab_crawl')
    local dungeon = DUNGEON_SCARAB
    dungeon.name = 'Scarab Tunnels'
    dungeon.level = 500 -- Provisional: intended for max-upgrade Azazoth gear.
    dungeon.queue_x, dungeon.queue_y = 16000., 6311.
    dungeon.managed_entry = true -- Crawl owns camera, positioning and teardown.
    function dungeon:canStart() return ScarabCrawl.canStart() end

    -- The allocated corner has already been cleared/flattened in the editor.
    -- This flag authorizes generation; it does not edit terrain at startup.
    ScarabCrawl.setPrepared(true)
    function dungeon:onStart()
        local seed = GetRandomInt(1, 2147483646)
        local party = {}
        for i, pid in ipairs(self.players) do party[i] = pid end
        for _, pid in ipairs(party) do
            local ok, reason = ScarabCrawl.enter(pid, seed)
            if not ok then
                DisplayTextToTable(party, reason or 'Unable to enter the Scarab crawl.')
                ScarabCrawl.stop()
                self.players = {}
                self:destroy()
                return
            end
            Unit[Hero[pid]].busy = true
            DisableBackpackTeleports(pid, true)
        end
    end
    ScarabCrawl.subscribeLeave(function(pid)
        if not TableHas(dungeon.players, pid) then return end
        TableRemove(dungeon.players, pid)
        if Hero[pid] then Unit[Hero[pid]].busy = false end
        DisableBackpackTeleports(pid, false)
        if #dungeon.players == 0 then
            dungeon:destroy()
            -- Avoid recursive teardown when stop() itself releases members.
            TimerQueue:callDelayed(0., function()
                if ScarabCrawl.participantCount() == 0 then ScarabCrawl.stop() end
            end)
        end
    end)

end, Debug and Debug.getLine())
