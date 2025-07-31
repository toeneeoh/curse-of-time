--[[
    https://www.hiveworkshop.com/threads/perfect-async-mouse-screen-xy.354135/
 
    - by ModdieMads, with special thanks to:
        - #modding channel on the HiveWorkshop Discord. The best part of modding WC3!
        - @Tasyen, for the herculean job of writing The Big UI-Frame Tutorial (https://www.hiveworkshop.com/pastebin/e23909d8468ff4942ccea268fbbcafd1.20598).
        - @Water, for the support while we're trying to push WC3 to its limits.
        - @Eikonium, for providing the DebugUtils and the IngameConsole. Big W.
        - @Vinz, for the crosshair texture!
 
    --GetMouseFrameX(), GetMouseFrameY(),
    --GetMouseSaneX(), GetMouseSaneY()
    --GetMouseFrameXStable(), GetMouseFrameYStable(),
    --GetMouseSaneXStable(), GetMouseSaneYStable()
--]]

OnInit.final("MouseTracker", function()

mouseFrameX = 0.0;
mouseFrameY = 0.0;
mouseSaneX = 0.0;
mouseSaneY = 0.0;

do
    local globalFrame = 0;
 
    local TRACKER_ERROR_BOUND = .15;
 
    local baseSize = .002;
    local TRACKER_LEVELS = 6;
    local trackerTilesGaps = {3, 3, 3, 1, 1, 1};
    local trackerTilesClms = {9, 9, 7, 3, 3, 3};
    local trackerTilesSizes = {baseSize, 3.0*baseSize, 3.0*3.0*baseSize, 7.0*3.0*3.0*baseSize, 3.0*7.0*3.0*3.0*baseSize, 3.0*3.0*7.0*3.0*3.0*baseSize};
 
    -- These are the arrays for the frames used in the lattice. It uses SIMPLEFRAMES, in fact.
    local trackerTilesButtons = {};
    local trackerTilesTooltips = {};
    local trackerTilesN = 0;
 
    -- These two are for internal use of the Tracker only.
    local trackerRawX = 0.0;
    local trackerRawY = 0.0;
 
    -- These two should always be integer powers of 2.
    -- Changing them will make the stabilization stronger/weaker, and the coords update lag bigger/smaller.
    local TRACKER_BUFFER_N = 8;
    local TRACKER_BUFFER_PERIOD_FRAMES = 16;
 
 
    local curTrackerBufferInd = -1;
    local trackerXBuffer = {};
    local trackerYBuffer = {};
 
    local trackerFlickerFrame = 0;

    local screenWid;
    local screenHei;
    local screenAspectRatio;
 
    local timTick;
 
    local function Fill(arr, arrLen, val)
        for i=1,arrLen do
            arr[i] = val;
        end
 
        return arr;
    end
 
    local function Mean(arr)
        local sum = 0;
        local arrLen = #arr;
        for i=1,arrLen do
            sum = sum + arr[i];
        end
 
        return sum/arrLen;
    end
 
    -- The Getters this system provides. 8 of them!
    function GetMouseFrameX(index)
        return mouseFrameX;
    end
 
    function GetMouseFrameY(index)
        return mouseFrameY;
    end
 
    function GetMouseSaneX()
        return mouseSaneX;
    end
 
    function GetMouseSaneY()
        return mouseSaneY;
    end
 
    function GetMouseFrameXStable()
        return Mean(trackerXBuffer) + .4;
    end
 
    function GetMouseFrameYStable()
        return Mean(trackerYBuffer) + .3;
    end
 
    function GetMouseSaneXStable()
        return 1.666667*(Mean(trackerXBuffer) + .3*screenAspectRatio)/screenAspectRatio;
    end
 
    function GetMouseSaneYStable()
        return (1.0 - 1.666667*(Mean(trackerYBuffer) + .3));
    end
 
    local function MoveTracker(x, y)
        -- MoveTracker moves the entire lattice to the x,y pair provided. (in raw coordinates, meaning center of the screen is 0,0)
 
        -- First calculate the sane coordinates, as sanity is a treasured resource.
        mouseSaneX = 1.666667*(x+.3*screenAspectRatio)/screenAspectRatio;
        mouseSaneY = (1.0 - 1.666667*(y+.3));
 
        -- Check if the tracker was catastrophically shaken.
        -- If it left the screen, reposition it on the center and try again.
        if mouseSaneX > (1.0+TRACKER_ERROR_BOUND) or mouseSaneY > (1.0+TRACKER_ERROR_BOUND) or mouseSaneX < -TRACKER_ERROR_BOUND or mouseSaneY < -TRACKER_ERROR_BOUND then
            do return MoveTracker(0.0,0.0) end;
        end
 
 
        trackerRawX = x;
        trackerRawY = y;
 
        mouseFrameX = x + .4;
        mouseFrameY = y + .3;
    
        local curSize, curGap, gapInd0, gapInd1, clms, clmCenter, ind;
 
        -- Here is the centering loops.
        -- They may look a little scary, but they are big pushovers.
        ind = 0;
        for lvl=1,TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            clms = trackerTilesClms[lvl];
    
            clmCenter = clms >> 1;
            gapInd0 = (clms - curGap) >> 1;
            gapInd1 = clms - gapInd0;
    
            for i=0, clms-1 do
                for i2=0,clms-1 do            
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then                
                        ind = ind + 1;
                
                        -- Re-center the Tracker tiles. It really is doing just that.
                        BlzFrameSetAbsPoint(
                            trackerTilesButtons[ind], FRAMEPOINT_CENTER,
                            mouseFrameX + curSize*(i2 - clmCenter),
                            mouseFrameY - curSize*(i - clmCenter)
                        );
                
                    end
                end
            end
        end
    end
 
    -- Also very simple. Just sets visibility for all tiles in the tracker.
    local function SetTrackerVisible(val)
        for i=1,trackerTilesN do
            BlzFrameSetVisible(trackerTilesButtons[i], val);
        end
    end
 
    -- Now here we have more meat.
    -- What this does is check if the mouse is on top of a tile.
    -- It does so by using the tooltip trick, explained by Tasyen in his tutorial.
    -- Basically, if the mouse is over a tooltipped SIMPLEBUTTON, the tooltip will say it's visible (even if it isn't drawing anything on the screen)
 
    local function UpdateTracker()
        local curSize, curGap, gapInd0, gapInd1, clms, clmCenter, ind;
 
        ind = 0;
        for lvl=1,TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            clms = trackerTilesClms[lvl];
    
            clmCenter = clms >> 1;
            gapInd0 = (clms - curGap) >> 1;
            gapInd1 = clms - gapInd0;
    
            for i=0, clms-1 do
                for i2=0,clms-1 do
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then
                        ind = ind + 1;
                
                        -- If mouse on top of the tile at ind...
                        if BlzFrameIsVisible(trackerTilesTooltips[ind]) then
                
                            -- Immediately hide the tooltip, important to prevent double-procs of the hit detection.
                            BlzFrameSetVisible(trackerTilesTooltips[ind], false);
                    
                            -- You know what, better be safe and hide the whole tracker.
                            SetTrackerVisible(false);
                    
                            -- I think this could be called FlickerDelay, but since this really turned out to be a Magic Number..
                            -- Why not make it true to its nature?
                            trackerFlickerFrame = globalFrame + 25;
                    
                            -- After the hit is detected, re-center the tracker on the position of the hit tile to
                            -- initiate the cybernetic process.
                            MoveTracker(
                                trackerRawX + curSize*(i2 - clmCenter),
                                trackerRawY - curSize*(i - clmCenter)
                            );
                    
                            do return true end;
                        end
                    end
                end
            end
        end
 
        -- Nothing was hit, so return false.
        return false;
    end
 
    -- Creates a tile for the tracker.
    local function CreateTrackerButton(size)
        local button = BlzCreateSimpleFrame('Tile', BlzGetOriginFrame(ORIGIN_FRAME_SIMPLE_UI_PARENT, 0), 0);
 
        -- Important for the tracker to stay above buttons and the top UI bar.
        BlzFrameSetLevel(button, 5);
        BlzFrameSetSize(button, size, size);
 
        return button;
    end
 
    -- Tooltip for the hit detection.
    local function CreateTrackerTooltip(button)
        local tooltip = BlzCreateFrameByType('SIMPLEFRAME', '', button, '', 0);
 
        BlzFrameSetTooltip(button, tooltip);
        BlzFrameSetEnable(tooltip, false);
        BlzFrameSetVisible(tooltip, false);
 
        return tooltip;
    end
 
    -- This only runs once. Here we create all the tiles. Very basic stuff.
    local function CreateTracker()
        local button, curSize, curGap, gapInd0, gapInd1, clms, ind;
 
        ind = 0;
        for lvl=1,TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            clms = trackerTilesClms[lvl];
    
            gapInd0 = (clms - curGap) >> 1;
            gapInd1 = clms - gapInd0;
    
            for i=0, clms-1 do
                for i2=0,clms-1 do
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then
            
                        button = CreateTrackerButton(curSize);
                
                        ind = ind + 1;
                        trackerTilesButtons[ind] = button;
                        trackerTilesTooltips[ind] = CreateTrackerTooltip(button);
                
                    end
                end
            end
        end
 
        trackerTilesN = ind;
        MoveTracker(0.0, 0.0);
    end

    local enabled = __jarray(false)
    local id = GetPlayerId(GetLocalPlayer()) + 1
 
    -- Now here is the beating heart of the system.
    -- And what a beat it has! This Tick is proc-ing every 0.001 seconds.
    local function TimerTick()
        globalFrame = globalFrame+1;

        -- If it's time to flicker...
        if globalFrame == trackerFlickerFrame then
            -- Turn on the tracker!
            SetTrackerVisible(enabled[id]);
        end
 
        -- This block only runs once every 512 ticks.
        if (globalFrame&511)==1 then
            if BlzGetLocalClientWidth() ~= screenWid then
                MoveTracker(0,0);
            end
    
            screenWid = BlzGetLocalClientWidth();
            screenHei = BlzGetLocalClientHeight();
    
            screenAspectRatio = screenWid/screenHei;
        end
 
        if (globalFrame&(TRACKER_BUFFER_PERIOD_FRAMES-1))==1 then
            curTrackerBufferInd = (curTrackerBufferInd + 1)&(TRACKER_BUFFER_N-1);
    
            trackerXBuffer[curTrackerBufferInd + 1] = trackerRawX;
            trackerYBuffer[curTrackerBufferInd + 1] = trackerRawY;
        end
 
        -- Here the tracker is updating itself after it has been flickered on.
        -- Once the player hovers a tile with the mouse, the tracker instantly goes dark, and re-sets the flicker frame,
        --         freeing up the screen for any inputs!
        if trackerFlickerFrame <= globalFrame then
            UpdateTracker();
        end
    end

    function StartMouseTracker(pid, x, y)
        if GetLocalPlayer() == Player(pid - 1) then
            Fill(trackerXBuffer, TRACKER_BUFFER_N, x);
            Fill(trackerYBuffer, TRACKER_BUFFER_N, y);
            SetTrackerVisible(true);
        end
        enabled[pid] = true
    end
    function PauseMouseTracker(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            SetTrackerVisible(false);
        end
        enabled[pid] = false
    end

    -- Init
    screenWid = BlzGetLocalClientWidth();
    screenHei = BlzGetLocalClientHeight();

    screenAspectRatio = screenWid/screenHei;

    BlzSetMousePos(screenWid>>1, screenHei>>1);
    CreateTracker();

    Fill(trackerXBuffer, TRACKER_BUFFER_N, 0.0);
    Fill(trackerYBuffer, TRACKER_BUFFER_N, 0.0);

    timTick = CreateTimer();
    TimerStart(timTick, .001, true, TimerTick);
end

end, Debug and Debug.getLine())
