if Debug and Debug.beginFile then Debug.beginFile("TimerQueue") end
--[[------------------------------------------------------------------------------------------------------------------------------------------------------------
*
*    --------------------------------
*    | TimerQueue and Stopwatch 1.4 |
*    --------------------------------
*
*    - by Eikonium
*
*    -> https://www.hiveworkshop.com/threads/timerqueue-stopwatch.353718/
*    - Credits to AGD, who's "ExecuteDelayed 1.0.4" code was used as the basis for TimerQueue. See https://www.hiveworkshop.com/threads/lua-delayedaction.321072/
*
* --------------------
* | TimerQueue class |
* --------------------
*        - A TimerQueue is an object used to execute delayed function calls. It can queue any number of function calls at the same time, while being based on a single timer. This offers much better performance than starting many separate timers.
*        - The class also provides methods to pause, resume, reset and destroy a TimerQueue - and even includes error handling.
*        - As such, you can create as many independent TimerQueues as you like, which you can individually use, pause, reset, etc.
*        - All methods can also be called on the class directly, which frees you from needing to create a TimerQueue object in the first place. You still need colon-notation!
*    TimerQueue.create() --> TimerQueue
*        - Creates a new TimerQueue with its own independent timer and function queue.
*    <TimerQueue>:callDelayed(number delay, function callback, ...) --> integer (callbackId)
*        - Calls the specified function (or callable table) after the specified delay (in seconds) with the specified arguments (...). Does not delay the following lines of codes.
*        - The returned integer can usually be discarded. Saving it to a local var allows you to TimerQueue:disableCallback(callbackId) or TimerQueue:enableCallback(callbackId) later. The callbackId is unique per callback and never reused.
*    <TimerQueue>:callPeriodically(number delay, function|nil stopCondition, function callback, ...)
*        - Periodically calls the specified function (or callable table) after the specified delay (in seconds) with the specified arguments (...). Stops, when the specified condition resolves to true.
*        - The stop-condition must be a function returning a boolean. It is checked after each callback execution and is passed the same arguments as the callback (...) (which you can still ignore).
*        - You can pass nil instead of a function to let the periodic execution repeat forever.
*        - Resetting the TimerQueue will stop all periodic executions, even if the reset happened within the periodic callback.
*        - Doesn't return a callbackId, so disabling a periodic callback is only possible via either meeting the stop-condition or resetting the queue.
*    <TimerQueue>:reset()
*        - Discards all queued function calls from the Timer Queue. Discarded function calls are not executed.
*        - You can continue to use <TimerQueue>:callDelayed after resetting it.
*    <TimerQueue>:pause()
*        - Pauses the TimerQueue at its current point in time, effectively freezing all delayed function calls that it currently holds, until the queue is resumed.
*        - Using <TimerQueue>:callDelayed on a paused queue will correctly add the new callback to the queue, but time will start ticking only after resuming the queue.
*    <TimerQueue>:isPaused() --> boolean
*        - Returns true, if the TimerQueue is paused, and false otherwise.
*    <TimerQueue>:resume()
*        - Resumes a TimerQueue that was previously paused. Has no effect on TimerQueues that are not paused.
*    <TimerQueue>:destroy()
*        - Destroys the Timer Queue. Remaining function calls are discarded and not being executed.
*    <TimerQueue>:tostring() --> string
*        - Represents a TimerQueue as a list of its tasks. For debugging purposes.
*    <TimerQueue>:disableCallback(callbackId)
*        - Disables the specified callback (as per Id returned by TimerQueue:callDelayed), making it not execute upon timeout.
*        - The disabled callback will stay in the queue until timeout, allowing you to TimerQueue:enableCallback it, if you changed your mind.
*        - Use this to cancel a future callback, when resetting the whole queue is not a suitable solution.
*        - CallbackId's are unique and never reused. Using one within TimerQueue:disableCallback after original timeout will not have any effect, but you don't need to worry about accidently disabling another callback.
*    <TimerQueue>:enableCallback(callbackId)
*        - Enables the specified callback (as per Id returned by TimerQueue:callDelayed) after you have previously disabled it, making it again execute upon timeout.
*        - Enabling a callback after its timeout has already passed while disabled will not have any effect.
*    <TimerQueue>:getTimeout(callbackId) --> number | nil
*        - Returns the original timeout of the specified callback (as per Id returned by TimerQueue:callDelayed).
*        - Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
*    <TimerQueue>:getElapsed(callbackId) --> number | nil
*        - Returns the number of seconds that have passed since the specified callback (as per Id returned by TimerQueue:callDelayed) was queued, not counting time passed while the TimerQueue was paused.
*        - Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
*    <TimerQueue>:getRemaining(callbackId) --> number | nil
*        - Returns the number of seconds that are left until the specified callback (as per Id returned by TimerQueue:callDelayed) will execute.
*        - Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
*    <TimerQueue>:hasExpired(callbackId) --> boolean
*        - Returns true, if the specified callback (as per Id returned by TimerQueue:callDelayed) has already expired (and thus removed from the queue) or never existed in the first place. Returns false otherwise.
*    <TimerQueue>.debugMode : boolean
*        - TimerQueues come with their own error handling in case you are not using DebugUtils (https://www.hiveworkshop.com/threads/debug-utils-ingame-console-etc.330758/).
*        - Set to true to let erroneous function calls through <TimerQueue>:callDelayed print error messages on screen (only takes effect, if Debug Utils is not present. Otherwise you get Debug Utils error handling, which is even better).
*        - Set to false to not trigger error messages after erroneous callbacks. Do this before map release.
*        - Default: false (because I assume you also use DebugUtils, which provides its own error handling).
*    local MAX_STACK_SIZE : integer
*        - TimerQueue uses table recycling to unburden the garbage collector.
*        - This constant defines the maximum number of tables that can wait for reusage at the same time. Tables freed while this limit is reached will be garbage collected as normal.
*        - Can be set to 0 to disable table recycling.
*        - Default: 128. Should be fine in most scenarios. Increase, if you expect to have a lot of callbacks in the queue.
* -------------------
* | Stopwatch class |
* -------------------
*        - Stopwatches count upwards, i.e. they measure the time passed since you've started them. Thus, they can't trigger any callbacks (use normal timers or TimerQueues for that).
*    Stopwatch.create(boolean startImmediately_yn) --> Stopwatch
*        - Creates a Stopwatch. Set boolean param to true to start it immediately.
*    <Stopwatch>:start()
*        - Starts or restarts a Stopwatch, i.e. resets the elapsed time of the Stopwatch to zero and starts counting upwards.
*    <Stopwatch>:getElapsed() --> number
*        - Returns the time in seconds that a Stopwatch is currently running, i.e. the elapsed time since start.
*    <Stopwatch>:pause()
*        - Pauses a Stopwatch, so it will retain its current elapsed time, until resumed.
*    <Stopwatch>:resume()
*        - Resumes a Stopwatch after having been paused.
*    <Stopwatch>:destroy()
*        - Destroys a Stopwatch. Maybe necessary to prevent memory leaks. Not sure, if lua garbage collection also collects warcraft objects...
---------------------------------------------------------------------------------------------------------------------------------------------------------]]

do

    --Help data structures for recycling tables for tasks (TimerQueueElements) in TimerQueues.
    local recycleStack = {} --Used tables are stored here to prevent garbage collection, up to MAX_STACK_SIZE
    local stackSize = 0 --Current number of tables stored in recycleStack
    local MAX_STACK_SIZE = 128 --Max number of tables that can be stored in recycleStack. Set this to a value > 0 to activate table recycling.

    ---@class TimerQueueElement
    ---@field [integer] any arguments to be passed to callback
    TimerQueueElement = {
        next = nil                      ---@type TimerQueueElement next TimerQueueElement to expire after this one
        ,   timeout = 0.                ---@type number time between previous callback and this one
        ,   timeoutTotal = 0.           ---@type number timeout this element has originally been queued with
        ,   timerQueueRuntime = 0.      ---@type number runtime of the TimerQueue hosting this element at the moment of insertion. Used to retreive the remaining runtime of this element.
        ,   callback = function() end   ---@type function callback to be executed
        ,   n = 0                       ---@type integer number of arguments passed
        ,   enabled = true              ---@type boolean defines whether the callback shall be executed on timeout or not.
        ,   id = 0                      ---@type integer unique id of this TimerQueueElement
        --static
        ,   nextId = 0                  ---@type integer ever increasing counter that shows the unique id of the next TimerQueueElement being created.
        ,   storage = setmetatable({}, {__mode = 'v'})                ---@type table<integer, TimerQueueElement> saves all TimerQueueElements by their unique id. Weak values to not interfere with garbage collection.
    }
    TimerQueueElement.__index = TimerQueueElement
    TimerQueueElement.__name = 'TimerQueueElement'

    local fillTable
    ---Recursive help function that fills a table with the specified arguments from index to maxIndex.
    ---@param whichTable table table to be filled
    ---@param index integer current index to be filled with firstParam
    ---@param maxIndex integer maximum index up to which to continue recursively
    ---@param firstParam any first param is mentioned explicitly to simplify the recursive call below
    ---@param ... any second and subsequent params
    fillTable = function(whichTable, index, maxIndex, firstParam, ...)
        whichTable[index] = firstParam
        if index < maxIndex then
            fillTable(whichTable, index + 1, maxIndex, ...)
        end
    end

    ---Creates a new TimerQueueElement, which points to itself.
    ---@param timeout? number
    ---@param timeoutTotal? number
    ---@param timerQueueRuntime? number
    ---@param callback? function
    ---@param ... any arguments for callback
    ---@return TimerQueueElement
    function TimerQueueElement.create(timeout, timeoutTotal, timerQueueRuntime, callback, ...)
        local new
        if stackSize == 0 then
            new = setmetatable({timeout = timeout, timeoutTotal = timeoutTotal, timerQueueRuntime = timerQueueRuntime, callback = callback, id = TimerQueueElement.nextId, n = select('#', ...), ...}, TimerQueueElement)
        else
            new = setmetatable(recycleStack[stackSize], TimerQueueElement)
            recycleStack[stackSize] = nil
            stackSize = stackSize - 1
            new.timeout, new.timeoutTotal, new.timerQueueRuntime, new.callback, new.id, new.n = timeout, timeoutTotal, timerQueueRuntime, callback, TimerQueueElement.nextId, select('#', ...)
            fillTable(new, 1, new.n, ...) --recursive fillTable is around 20 percent faster than a for-loop based on new[i] = select(i, ...)
        end
        new.next = new
        TimerQueueElement.nextId = TimerQueueElement.nextId + 1
        TimerQueueElement.storage[new.id] = new
        return new
    end

    ---Empties a TimerQueueElement and puts it to the recycleStack.
    ---@param timerQueueElement TimerQueueElement
    local function recycleTimerQueueElement(timerQueueElement)
        --remove TimerQueueElement from storage and remove metatable
        TimerQueueElement.storage[timerQueueElement.id] = nil
        setmetatable(timerQueueElement, nil)
        --If table recycling is activated and there is space on the recycleStack, push the TimerQueueElement back onto it.
        if stackSize < MAX_STACK_SIZE then
            --empty table before putting it back
            for i = 1, timerQueueElement.n do
                timerQueueElement[i] = nil
            end
            timerQueueElement.next, timerQueueElement.callback, timerQueueElement.n, timerQueueElement.timeout, timerQueueElement.timeoutTotal, timerQueueElement.timerQueueRuntime, timerQueueElement.enabled, timerQueueElement.id = nil, nil, nil, nil, nil, nil, nil, nil
            --push on stack
            stackSize = stackSize + 1
            recycleStack[stackSize] = timerQueueElement
        end
        --Else: Do nothing. TimerQueueElement will automatically be garbage collected.
    end

    ---@class TimerQueue
    TimerQueue = {
        timer = nil                     ---@type timer the single timer this system is based on (one per instance of course)
        ,   queue = TimerQueueElement.create() ---@type TimerQueueElement queue of waiting callbacks to be executed in the future
        ,   n = 0                       ---@type integer number of elements in the queue
        ,   on_expire = function() end  ---@type function callback to be executed upon timer expiration.
        ,   paused = false              ---@type boolean whether the queue is paused or not
        ,   runtime = 0.                ---@type number time the queue has been running with callbacks queued. Only updated upon callback execution, so need to add TimerGetElapsed(self.timer) to get the proper amount.
        ,   debugMode = false           ---@type boolean If set to true, TimerQueues will print error messages upon failing callback execution. Not necessary if you are using DebugUtils. Set this to false before releasing your map.
    }

    TimerQueue.__index = TimerQueue
    TimerQueue.__name = 'TimerQueue'

    --Creates a timer on first access of the static TimerQueue:callDelayed method. Avoids timer creation inside the Lua root.
    setmetatable(TimerQueue, {__index = function(t,k) if k == 'timer' then t[k] = CreateTimer() end; return rawget(t,k) end})

    local unpack, max, timerStart, timerGetElapsed, pauseTimer, try = table.unpack, math.max, TimerStart, TimerGetElapsed, PauseTimer, Debug and Debug.try

    ---Executes the topmost queued callback and removes it from the queue.
    ---@param timerQueue TimerQueue
    local function on_expire(timerQueue)
        local queue, timer = timerQueue.queue, timerQueue.timer
        local topOfQueue = queue.next
        queue.next = topOfQueue.next
        timerQueue.runtime = timerQueue.runtime + topOfQueue.timeout --add the time that has passed since the last on_expire
        timerQueue.n = timerQueue.n - 1
        if timerQueue.n > 0 then
            timerStart(timer, queue.next.timeout, false, timerQueue.on_expire)
        else
            -- These two functions below may not be necessary
            timerStart(timer, 0, false, nil) --don't put in on_expire as handlerFunc, because it can still expire and reduce n to a value < 0.
            pauseTimer(timer)
        end
        if topOfQueue.enabled then
            if try then
                try(topOfQueue.callback, unpack(topOfQueue, 1, topOfQueue.n))
            else
                local errorStatus, errorMessage = pcall(topOfQueue.callback, unpack(topOfQueue, 1, topOfQueue.n))
                if timerQueue.debugMode and not errorStatus then
                    print("|cffff5555ERROR during TimerQueue callback: " .. errorMessage .. "|r")
                end
            end
        end
        recycleTimerQueueElement(topOfQueue)
    end

    TimerQueue.on_expire = function() on_expire(TimerQueue) end

    ---@return TimerQueue
    function TimerQueue.create()
        local new = {}
        setmetatable(new, TimerQueue)
        new.n = 0
        new.paused = false
        new.runtime = 0.
        new.timer = CreateTimer()
        new.queue = TimerQueueElement.create()
        new.on_expire = function() on_expire(new) end
        return new
    end

    ---Calls a function (or callable table) after the specified timeout (in seconds) with all specified arguments (...). Does not delay the following lines of codes.
    ---@param timeout number
    ---@param callback function|table if table, must be callable
    ---@param ... any arguments of the callback function
    ---@return integer callbackId usually discarded. Can be saved to local var to use in :disableCallback() or :enableCallback() later.
    function TimerQueue:callDelayed(timeout, callback, ...)
        timeout = math.max(timeout, 0.)
        local timeoutTotal = timeout --remember original timeout, before queue insertion changes it to the diff to the next element
        local queue = self.queue
        self.n = self.n + 1
        -- Sort timeouts in descending order
        local current = queue
        local timeElapsed = max(timerGetElapsed(self.timer), 0.)
        local current_timeout = current.next.timeout - timeElapsed -- don't use TimerGetRemaining to prevent bugs for expired and previously paused timers.
        while current.next ~= queue and timeout >= current_timeout do --there is another element in the queue and the new element shall be executed later than the current
            timeout = timeout - current_timeout
            current = current.next
            current_timeout = current.next.timeout
        end
        -- after loop, current is the element that executes right before the new callback. If the new is the front of the queue, current is the root element (queue).
        local new = TimerQueueElement.create(timeout, timeoutTotal, self.runtime, callback, ...)
        new.next = current.next
        current.next = new
        -- if the new callback is the next to expire, restart timer with new timeout
        if current == queue then --New callback is the next to expire
            self.runtime = self.runtime + timeElapsed
            new.next.timeout = max(current_timeout - timeout, 0.) --adapt element that was previously on top. Subtract new timeout and subtract timer elapsed time to get new timeout.
            timerStart(self.timer, timeout, false, self.on_expire)
            if self.paused then
                self:pause()
            end
        else
            new.next.timeout = max(new.next.timeout - timeout, 0.) --current.next might be the root element (queue), so prevent that from dropping below 0. (although it doesn't really matter)
        end
        return new.id
    end

    ---Calls the specified callback with the specified argumets (...) every <timeout> seconds, until the specified stop-condition holds.
    ---The stop-condition must be a function returning a boolean. It is checked after every callback execution. All arguments (...) are also passed to the stop-conditon (you can still ignore them).
    ---Resetting the TimerQueue will stop all periodic executions, even if the reset happened within the periodic callback.
    ---Doesn't return a TimerQueue-Element, so disabling is only possible by either meeting the stop-condition or resetting the queue.
    ---@param timeout number time between calls
    ---@param stopCondition? fun(...):boolean callback will stop to repeat, when this condition holds. You can pass nil to skip the condition (i.e. the periodic execution will run forever).
    ---@param callback fun(...) the callback to be executed
    ---@param ... any arguments for the callback
    function TimerQueue:callPeriodically(timeout, stopCondition, callback, ...)
        local func
        func = function(...)
            local queue = self.queue --memorize queue element to check later, whether TimerQueue:reset has been called in the meantime.
            callback(...) --execute callback first
            --re-queue, if stopCondition doesn't hold and the TimerQueue has not been reset during the callback (checked via queue == self.queue)
            if queue == self.queue and not (stopCondition and stopCondition(...)) then
                self:callDelayed(timeout, func, ...)
            end
        end
        self:callDelayed(timeout, func, ...)
    end

    ---Recycles all elements of a given TimerQueue (including the root element), up to the limit given by MAX_STACK_SIZE
    ---@param timerQueue TimerQueue
    local function recycleQueueElements(timerQueue)
        --Recycle all TimerQueueElements in the queue except the root element (which is used for call-by-reference checks in :callPeriodically)
        local current, next = timerQueue.queue.next, nil
        while current ~= timerQueue.queue and stackSize < MAX_STACK_SIZE do --stop recycling early, if MAX_STACK_SIZE is reached. Remaining TimerQueueElements will be garbage collected. Weak values in TimerQueueElement.storage makes sure no reference is left.
            next = current.next --need to save current.next here, as it gets nilled during recycleTimerQueueElement
            recycleTimerQueueElement(current)
            current = next
        end
        --Recycle root element
        TimerQueueElement.storage[timerQueue.queue.id] = nil
    end

    ---Removes all queued calls from the Timer Queue, so any remaining actions will not be executed.
    ---Using <TimerQueue>:callDelayed afterwards will still work.
    ---Resetting a paused queue will leave it paused.
    function TimerQueue:reset()
        recycleQueueElements(self)
        --Reset timer and create new queue to replace the old
        timerStart(self.timer, 0., false, nil) --don't put in on_expire as handlerFunc. callback can still expire after pausing and resuming the empty queue, which would set n to a value < 0.
        pauseTimer(self.timer)
        self.n = 0
        self.runtime = 0.
        self.queue = TimerQueueElement.create()
    end

    ---Pauses the TimerQueue at its current point in time, preventing all queued callbacks from being executed, until the queue is resumed.
    ---Using <TimerQueue>:callDelayed on a paused queue will correctly add the new callback to the queue, but time will start ticking only after the queue is being resumed.
    function TimerQueue:pause()
        self.paused = true
        pauseTimer(self.timer)
    end

    ---Returns true, if the timer queue is paused, and false otherwise.
    ---@return boolean
    function TimerQueue:isPaused()
        return self.paused
    end

    ---Resumes a TimerQueue that was paused previously. Has no effect on running TimerQueues.
    function TimerQueue:resume()
        if self.paused then
            self.paused = false
            self.runtime = self.runtime + timerGetElapsed(self.timer)
            self.queue.next.timeout = self.queue.next.timeout - timerGetElapsed(self.timer) --need to restart from 0, because TimerGetElapsed(resumedTimer) is doing so as well after a timer is resumed.
            ResumeTimer(self.timer)
        end
    end

    ---Destroys the timer object behind the TimerQueue. The Lua object will be automatically garbage collected once you ensure that there is no more reference to it.
    function TimerQueue:destroy()
        pauseTimer(self.timer) --https://www.hiveworkshop.com/threads/issues-with-timer-functions.309433/ suggests that non-paused destroyed timers can still execute their callback
        DestroyTimer(self.timer)
        recycleQueueElements(self)
        self.queue = nil
        setmetatable(self, nil) --prevents consequences on the TimerQueue class, if further methods (like :destroy again) are used on the destroyed TimerQueue.
    end

    ---Returns a list of queued callbacks within the TimerQueue. For debugging purposes.
    ---@return string
    function TimerQueue:tostring()
        local current, result, i = self.queue.next, {}, 0
        local args = {}
        while current ~= self.queue do
            i = i + 1
            for j = 1, current.n do
                args[j] = tostring(current[j])
            end
            result[i] = '(i=' .. i .. ',timeout=' .. current.timeout .. ',enabled=' .. tostring(current.enabled) .. ',f=' .. tostring(current.callback) .. ',args={' .. table.concat(args, ',',1,current.n) .. '})'
            current = current.next
        end
        return '{n = ' .. self.n .. ',queue=(' .. table.concat(result, ',', 1, i) .. ')}'
    end

    ---Disables a callback that is currently queued in the TimerQueue.
    ---The callback will still sit in the queue until timeout, but resolve without any effect.
    ---This method is similiar to resetting the whole TimerQueue, just limited to a single callback.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    function TimerQueue:disableCallback(callbackId)
        if TimerQueueElement.storage[callbackId] then
            TimerQueueElement.storage[callbackId].enabled = false
        end
    end

    ---Re-enables a callback that was previously disabled by TimerQueue:disableCallback.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    function TimerQueue:enableCallback(callbackId)
        if TimerQueueElement.storage[callbackId] then
            TimerQueueElement.storage[callbackId].enabled = true
        end
    end

    ---Returns the original timeout of a callback that is currently queued in the TimerQueue.
    ---
    ---Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    ---@return number | nil
    function TimerQueue:getTimeout(callbackId)
        if TimerQueueElement.storage[callbackId] then
            return TimerQueueElement.storage[callbackId].timeoutTotal
        end
        return nil
    end

    ---Returns the number of seconds that have passed since the callback was queued in the TimerQueue, not counting time passed while the timer queue was paused.
    ---
    ---Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    ---@return number | nil
    function TimerQueue:getElapsed(callbackId)
        if TimerQueueElement.storage[callbackId] then
            --The runtime of the timer queue right now minus the runtime it had when the callback was queued.
            return self.runtime + timerGetElapsed(self.timer) - TimerQueueElement.storage[callbackId].timerQueueRuntime
        end
        return nil
    end

    ---Returns the number of seconds still to go until callback timeout.
    ---
    ---Returns nil, if the specified callbackId does not exist or if the callback has already been executed and thus removed from the queue.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    ---@return number | nil
    function TimerQueue:getRemaining(callbackId)
        if TimerQueueElement.storage[callbackId] then
            return max(self:getTimeout(callbackId) - self:getElapsed(callbackId),0.) --max prevents "-0.0" return value sometimes resulting from floating point arithmetic, e.g. after using getRemaining on a 0-callback.
        end
        return nil
    end

    ---Returns true, if the specified callback has already expired or the callbackId does not exist. Returns false otherwise.
    ---@param callbackId integer the callbackId returned by TimerQueue:callDelayed
    ---@return boolean
    function TimerQueue:hasExpired(callbackId)
        --if the callbackId is stored in storage, the callback is still running.
        if TimerQueueElement.storage[callbackId] then
            return false
        end
        return true
    end


    ---@class Stopwatch
    Stopwatch = {
        timer = {}                                  ---@type timer the countdown-timer permanently cycling
        ,   elapsed = 0.                            ---@type number the number of times the timer reached 0 and restarted
        ,   increaseElapsed = function() end        ---@type function timer callback function to increase numCycles by 1 for a specific Stopwatch.
    }
    Stopwatch.__index = Stopwatch

    local CYCLE_LENGTH = 3600. --time in seconds that a timer needs for one cycle. doesn't really matter.

    ---Creates a Stopwatch.
    ---@param startImmediately_yn boolean Set to true to start immediately. If not specified or set to false, the Stopwatch will not start to count upwards.
    function Stopwatch.create(startImmediately_yn)
        local new = {}
        setmetatable(new, Stopwatch)
        new.timer = CreateTimer()
        new.elapsed = 0.
        new.increaseElapsed = function() new.elapsed = new.elapsed + CYCLE_LENGTH end
        if startImmediately_yn then
            new:start()
        end
        return new
    end

    ---Starts or restarts a Stopwatch, i.e. resets the elapsed time of the Stopwatch to zero and starts counting upwards.
    function Stopwatch:start()
        self.elapsed = 0.
        TimerStart(self.timer, CYCLE_LENGTH, true, self.increaseElapsed)
    end

    ---Returns the time in seconds that a Stopwatch is currently running, i.e. the elapsed time since start.
    ---@return number
    function Stopwatch:getElapsed()
        return self.elapsed + TimerGetElapsed(self.timer)
    end

    ---Pauses a Stopwatch, so it will retain its current elapsed time, until resumed.
    function Stopwatch:pause()
        PauseTimer(self.timer)
    end

    ---Resumes a Stopwatch after having been paused.
    function Stopwatch:resume()
        self.elapsed = self.elapsed + TimerGetElapsed(self.timer)
        TimerStart(self.timer, CYCLE_LENGTH, true, self.increaseElapsed) --not using ResumeTimer here, as it actually starts timer from new with the remaining time and thus screws up TimerGetElapsed().
    end

    ---Destroys the timer object behind the Stopwatch. The Lua object will be automatically garbage collected once you ensure that there is no more reference to it.
    function Stopwatch:destroy()
        DestroyTimer(self.timer)
    end
end
if Debug and Debug.endFile then Debug.endFile() end
