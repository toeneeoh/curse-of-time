OnInit.final("DevMetricSnapshots", function(Require)
    Require('DevRuntimeLog')
    Require('TimerQueue')

    if not DevLog.enabled then return end

    local function snapshot()
        DevLog.snapshot("periodic")
        TimerQueue:callDelayed(30., snapshot)
    end

    TimerQueue:callDelayed(30., snapshot)
end, Debug and Debug.getLine())
