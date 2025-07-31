if Debug then Debug.beginFile "ALICE" end
---@diagnostic disable: need-check-nil
do
    --[[
    =============================================================================================================================================================
                                                            A Limitless Interaction Caller Engine
                                                                         by Antares
                                                                            v2.9

                                A Lua system to easily create highly performant checks and interactions, between any type of objects.
                        
                                Requires:
                                TotalInitialization             https://www.hiveworkshop.com/threads/total-initialization.317099/
                                Hook                            https://www.hiveworkshop.com/threads/hook.339153/
                                HandleType                      https://www.hiveworkshop.com/threads/get-handle-type.354436/
                                PrecomputedHeightMap (optional) https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/


                                                            For tutorials & documentation, see here:
                                                          https://www.hiveworkshop.com/threads/.353126/

    =============================================================================================================================================================
                                                                        C O N F I G
    =============================================================================================================================================================
    ]]

    ALICE_Config = {

        --Minimum interval between interactions in seconds. Sets the time step of the timer. All interaction intervals are an integer multiple of this value.
        MIN_INTERVAL                        = 0.02      ---@constant number

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Debugging

        --Print out warnings, errors, and enable the "downtherabbithole" cheat code for the players with these names. #XXXX not required.
        ,MAP_CREATORS                       = {         ---@constant string[]
            "lcm#1458",
            "WorldEdit"
        }

        --Calls all interaction functions in protected mode, so that the main cycle is not interrupted on an error. Each unique error will be printed only once to the
        --map creator. This is recommended for playtest versions which are not fully stable yet.
        ,PROCTECTED_MODE                    = false     ---@constant boolean

        --These constants control which hotkeys are used for the various commands in debug mode. The key combo is Ctrl + the specified hotkey.
        ,CYCLE_SELECTION_HOTKEY             = "Q"
        ,LOCK_SELECTION_HOTKEY              = "W"
        ,NEXT_STEP_HOTKEY                   = "R"
        ,HALT_CYCLE_HOTKEY                  = "T"
        ,PRINT_FUNCTION_NAMES_HOTKEY        = "G"

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Optimization

        --Maximum interval between interactions in seconds.
        ,MAX_INTERVAL                       = 10.0      ---@constant number

        --This interval is used by a second, faster timer that can be used to update visual effects at a faster rate than the MIN_INTERVAL with ALICE_PairInterpolate.
        --Set to nil to disable.
        ,INTERPOLATION_INTERVAL             = nil      ---@constant number

        --The playable map area is divided into cells of this size. Objects only interact with other objects that share a cell with them. Smaller cells increase the
        --efficiency of interactions at the cost of increased memory usage and overhead.
        ,CELL_SIZE                          = 256       ---@constant number

        --How often the system checks if objects left their current cell. Should be overwritten with the cellCheckInterval flag for fast-moving objects.
        ,DEFAULT_CELL_CHECK_INTERVAL        = 0.1       ---@constant number

        --How large an actor is when it comes to determining in which cells it is in and its maximum interaction range. Should be overwritten with the radius flag for
        --objects with a larger interaction range.
        ,DEFAULT_OBJECT_RADIUS              = 75        ---@constant number

        --You can integrate ALICE's internal table recycling system into your own by setting the GetTable and ReturnTable functions here.
        ,TABLE_RECYCLER_GET                 = nil       ---@constant function
        ,TABLE_RECYCLER_RETURN              = nil       ---@constant function

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Automatic actor creation for widgets

        --Actor creation for user-defined objects is up to you. For widgets, ALICE offers automatic actor creation and destruction.

        --Determine which widget types will automatically receive actors and be registered with ALICE. The created actors are passive and only receive pairs. You can
        --add exceptions with ALICE_IncludeType and ALICE_ExcludeType.
        ,NO_UNIT_ACTOR                      = false     ---@constant boolean
        ,NO_DESTRUCTABLE_ACTOR              = false     ---@constant boolean
        ,NO_ITEM_ACTOR                      = false     ---@constant boolean

        --Add widget names (converted to camelCase) as identifiers to widget actors. Note that the names of widgets are localized and you risk a desync if you reference
        --a widget by name unless it's a custom name.
        ,ADD_WIDGET_NAMES                   = false     ---@constant boolean

        --Disable to destroy unit actors on death. Units will not regain an actor when revived.
        ,UNITS_LEAVE_BEHIND_CORPSES         = true      ---@constant boolean

        --Disable if corpses are relevant and you're moving them around.
        ,UNIT_CORPSES_ARE_STATIONARY        = true      ---@constant boolean

        --Add identifiers such as "hero" or "mechanical" to units if they have the corresponding classification and "nonhero", "nonmechanical" etc. if they do not.
        --The identifiers will not get updated automatically when a unit gains or loses classifications and you must update them manually with ALICE_SwapIdentifier.
        ,UNIT_ADDED_CLASSIFICATIONS         = {         ---@constant unittype[]
            UNIT_TYPE_HERO,
            UNIT_TYPE_STRUCTURE
        }

        --The radius of the unit actors. Set to nil to use DEFAULT_OBJECT_RADIUS.
        ,DEFAULT_UNIT_RADIUS                = nil       ---@constant number

        --The radius of the destructable actors. Set to nil to use DEFAULT_OBJECT_RADIUS.
        ,DEFAULT_DESTRUCTABLE_RADIUS        = nil       ---@constant number

        --Disable if items are relevant and you're moving them around.
        ,ITEMS_ARE_STATIONARY               = true      ---@constant boolean

        --The radius of the item actors. Set to nil to use DEFAULT_OBJECT_RADIUS.
        ,DEFAULT_ITEM_RADIUS                = nil       ---@constant number

    }

    -------------------------------------------------------------------------------------------------------------------------------------------------------------

    --For EmmyLua annotations. If you're passing any types into object functions other than these types, add them here to disable warnings.
    ---@alias Object unit | destructable | item | table

    --[[
    =============================================================================================================================================================
                                                                    E N D   O F   C O N F I G
    =============================================================================================================================================================
    ]]

    --#region Variables
    ALICE_TimeElapsed = 0.0                     ---@readonly number
    ALICE_CPULoad = 0                           ---@readonly number
    ALICE_Where = "outsideofcycle"              ---@readonly "outsideofcycle" | "precleanup" | "postcleanup" | "callbacks" | "everystep" | "cellcheck" | "variablestep"
    MATCHING_TYPE_ANY = {}                      ---@constant table
    MATCHING_TYPE_ALL = {}                      ---@constant table

    local max = math.max
    local min = math.min
    local sqrt = math.sqrt
    local atan = math.atan
    local insert = table.insert
    local concat = table.concat
    local sort = table.sort
    local pack = table.pack
    local unpack = table.unpack
    local config = ALICE_Config

    local timers = {}                           ---@type timer[]
    local MAX_STEPS = 0                         ---@type integer
    local CYCLE_LENGTH = 0                      ---@type integer
    local DO_NOT_EVALUATE = 0                   ---@type integer

    local MAP_MIN_X                             ---@type number
    local MAP_MAX_X                             ---@type number
    local MAP_MIN_Y                             ---@type number
    local MAP_MAX_Y                             ---@type number
    local MAP_SIZE_X                            ---@type number
    local MAP_SIZE_Y                            ---@type number

    local NUM_CELLS_X                           ---@type integer
    local NUM_CELLS_Y                           ---@type integer
    local CELL_MIN_X = {}                       ---@type number[]
    local CELL_MIN_Y = {}                       ---@type number[]
    local CELL_MAX_X = {}                       ---@type number[]
    local CELL_MAX_Y = {}                       ---@type number[]
    local CELL_LIST = {}                        ---@type Cell[][]

    --[[Array indices for pair fields. Storing as a sequence up to 8 reduces memory usage. Constants have been inlined because of local variable limit. Hexadecimals to be able to revert with find&replace.
    ACTOR A                         = 0x1
    ACTOR_B                         = 0x2
    HOST_A                          = 0x3
    HOST_B                          = 0x4
    CURRENT_POSITION / NEXT         = 0x5
    POSITION_IN_STEP / PREVIOUS     = 0x6
    EVERY_STEP                      = 0x7
    INTERACTION_FUNC                = 0x8
    ]]

    local EMPTY_TABLE = {}                      ---@constant table
    local SELF_INTERACTION_ACTOR                ---@type Actor
    local DUMMY_PAIR                            ---@constant Pair
        = {destructionQueued = true}
    local OUTSIDE_OF_CYCLE =                    ---@constant Pair
        setmetatable({}, {__index = function()
            error("Attempted to call Pair API function from outside of allowed functions.")
        end})

    local cycle = {
        counter = 0,                            ---@type integer
        unboundCounter = 0,                     ---@type integer
        isHalted = false,                       ---@type boolean
        isCrash = false,                        ---@type boolean
        freezeCounter = 0,                      ---@type number
    }

    local currentPair = OUTSIDE_OF_CYCLE        ---@type Pair | nil
    local totalActors = 0                       ---@type integer
    local moveableLoc                           ---@type location
    local numPairs = {}                         ---@type integer[]
    local whichPairs = {}                       ---@type table[]
    local firstEveryStepPair = DUMMY_PAIR       ---@type Pair
    local lastEveryStepPair = DUMMY_PAIR        ---@type Pair
    local numEveryStepPairs = 0                 ---@type integer
    local actorList = {}                        ---@type Actor[]
    local celllessActorList = {}                ---@type Actor[]
    local pairList = {}                         ---@type Pair[]
    local pairingExcluded = {}                  ---@type table[]
    local numCellChecks = {}                    ---@type integer[]
    local cellCheckedActors = {}                ---@type Actor[]
    local actorAlreadyChecked = {}              ---@type boolean[]
    local unusedPairs = {}                      ---@type Pair[]
    local unusedActors = {}                     ---@type Actor[]
    local unusedTables = {}                     ---@type table[]
    local additionalFlags = {}                  ---@type table
    local destroyedActors = {}                  ---@type Actor[]
    local actorOf = {}                          ---@type Actor[]
    local alreadyEnumerated = {}                ---@type any[]
    local interpolatedPairs = {}                ---@type Pair[]
    local actorsOfActorClass =                  ---@type Actor[]
        setmetatable({}, {__index = function(self, key) self[key] = {} return self[key] end})
    local isInterpolated                        ---@type boolean
    local interpolationCounter = 10             ---@type integer
    local regions = {}                          ---@type table[]

    local functionIsEveryStep = {}              ---@type table<function,boolean>
    local functionIsUnbreakable = {}            ---@type table<function,boolean>
    local functionIsUnsuspendable = {}          ---@type table<function,boolean>
    local functionInitializer = {}              ---@type table<function,function>
    local functionDelay = {}                    ---@type table<function,number>
    local functionDelayIsDistributed = {}       ---@type table<function,boolean>
    local functionDelayCurrent = {}             ---@type table<function,number>
    local functionOnDestroy = {}                ---@type table<function,function>
    local functionOnBreak = {}                  ---@type table<function,function>
    local functionOnReset = {}                  ---@type table<function,function>
    local functionPauseOnStationary = {}        ---@type table<function,boolean>
    local functionRequiredFields = {}           ---@type table<function,table>
    local functionKey = {}                      ---@type table<function,integer>
    local highestFunctionKey = 0                ---@type integer

    local delayedCallbackFunctions = {}         ---@type function[]
    local delayedCallbackArgs = {}              ---@type table[]
    local unitOwnerFunc = {}                    ---@type function[]
    local userCallbacks = {}                    ---@type table[]
    local pairingFunctions = {}                 ---@type table[]
    local objectIsStationary                    ---@type table<any,boolean>
        = setmetatable({}, {__mode = "k"})

    local widgets = {
        bindChecks = {},                        ---@type Actor[]
        deathTriggers                           ---@type table<destructable|item,trigger>
            = setmetatable({}, {__mode = "k"}),
        reviveTriggers = {},                    ---@type table<unit,trigger>
        idExclusions = {},                      ---@type table<integer,boolean>
        idInclusions = {},                      ---@type table<integer,boolean>
        hash = nil                              ---@type hashtable
    }

    local onCreation = {                        ---@type table
        flags = {},                             ---@type table<string,table>
        funcs = {},                             ---@type table<string,table>
        identifiers = {},                       ---@type table<string,table>
        interactions = {},                      ---@type table<string,table>
        selfInteractions = {}                   ---@type table<string,table>
    }

    local INV_MIN_INTERVAL                      ---@constant number
        = 1/config.MIN_INTERVAL - 0.001

    local OVERWRITEABLE_FLAGS = {               ---@constant table<string,boolean>
        priority = true,
        zOffset = true,
        cellCheckInterval = true,
        isStationary = true,
        radius = true,
        persistOnDeath = true,
        onActorDestroy = true,
        hasInfiniteRange = true,
        isUnselectable = true,
    }

    local RECOGNIZED_FLAGS = {                  ---@constant table<string,boolean>
        anchor = true,
        zOffset = true,
        cellCheckInterval = true,
        isStationary = true,
        radius = true,
        persistOnDeath = true,
        width = true,
        height = true,
        bindToBuff = true,
        bindToOrder = true,
        onActorDestroy = true,
        hasInfiniteRange = true,
        isGlobal = true,
        isAnonymous = true,
        isUnselectable = true,
        actorClass = true,
        selfInteractions = true
    }

    ---@class ALICE_Flags
    ---@field anchor Object
    ---@field zOffset number
    ---@field cellCheckInterval number
    ---@field isStationary boolean
    ---@field radius number
    ---@field persistOnDeath boolean
    ---@field width number
    ---@field height number
    ---@field bindToBuff string | integer
    ---@field bindToOrder string | integer
    ---@field onActorDestroy function
    ---@field hasInfiniteRange boolean
    ---@field isGlobal boolean
    ---@field isAnonymous boolean
    ---@field isUnselectable boolean
    ---@field actorClass string
    ---@field selfInteractions string | string[]

    local UNIT_CLASSIFICATION_NAMES = {         ---@constant table<unittype,string>
        [UNIT_TYPE_HERO] = "hero",
        [UNIT_TYPE_STRUCTURE] = "structure",
        [UNIT_TYPE_MECHANICAL] = "mechanical",
        [UNIT_TYPE_UNDEAD] = "undead",
        [UNIT_TYPE_TAUREN] = "tauren",
        [UNIT_TYPE_ANCIENT] = "ancient",
        [UNIT_TYPE_SAPPER] = "sapper",
        [UNIT_TYPE_PEON] = "worker",
        [UNIT_TYPE_FLYING] = "flying",
        [UNIT_TYPE_GIANT] = "giant",
        [UNIT_TYPE_SUMMONED] = "summoned",
        [UNIT_TYPE_TOWNHALL] = "townhall",
    }

    local GetTable                              ---@type function
    local ReturnTable                           ---@type function

    local Create                                ---@type function
    local Destroy                               ---@type function
    local Release                               ---@type function
    local CreateReference                       ---@type function
    local RemoveReference                       ---@type function
    local SetCoordinateFuncs                    ---@type function
    local SetOwnerFunc                          ---@type function
    local InitCells                             ---@type function
    local InitCellChecks                        ---@type function
    local AssignActorClass                      ---@type function
    local Flicker                               ---@type function
    local SharesCellWith                        ---@type function
    local CreateBinds                           ---@type function
    local DestroyObsoletePairs                  ---@type function
    local Unpause                               ---@type function
    local SetStationary                         ---@type function
    local VisualizeCells                        ---@type function
    local RedrawCellVisualizers                 ---@type function
    local Suspend                               ---@type function
    local Deselect                              ---@type function
    local Select                                ---@type function
    local GetMissingRequiredFieldsString        ---@type function
    local GetDescription                        ---@type function
    local CreateVisualizer                      ---@type function

    local EnterCell                             ---@type function
    local RemoveCell                            ---@type function
    local LeaveCell                             ---@type function

    local VisualizationLightning                ---@type function
    local GetTerrainZ                           ---@type function
    local GetActor                              ---@type function
    local EnableDebugMode                       ---@type function
    local UpdateSelectedActor                   ---@type function
    local OnDestructableDeath                   ---@type function
    local OnItemDeath                           ---@type function

    local debug = {}                            ---@type table
    debug.enabled = false                       ---@type boolean
    debug.mouseClickTrigger = nil               ---@type trigger
    debug.cycleSelectTrigger = nil              ---@type trigger
    debug.nextStepTrigger = nil                 ---@type trigger
    debug.lockSelectionTrigger = nil            ---@type trigger
    debug.haltTrigger = nil                     ---@type trigger
    debug.printFunctionsTrigger = nil           ---@type trigger
    debug.selectedActor = nil                   ---@type Actor | nil
    debug.tooltip = nil                         ---@type framehandle
    debug.tooltipText = nil                     ---@type framehandle
    debug.tooltipTitle = nil                    ---@type framehandle
    debug.visualizationLightnings = {}          ---@type lightning[]
    debug.selectionLocked = false               ---@type boolean
    debug.benchmark = false                     ---@type boolean
    debug.visualizeAllActors = false            ---@type boolean
    debug.visualizeAllCells = false             ---@type boolean
    debug.printFunctionNames = false            ---@type boolean
    debug.evaluationTime = {}                   ---@type table
    debug.gameIsPaused = nil                    ---@type boolean
    debug.functionName = {}                     ---@type table<function,string>
    debug.controlIsPressed = false              ---@type boolean
    debug.errors = {}                           ---@type table<string, boolean>

    local eventHooks = {                        ---@type table[]
        onUnitEnter = {},
        onUnitDeath = {},
        onUnitRevive = {},
        onUnitRemove = {},
        onUnitChangeOwner = {},
        onDestructableEnter = {},
        onDestructableDestroy = {},
        onItemEnter = {},
        onItemDestroy = {}
    }
    --#endregion

    --===========================================================================================================================================================
    --Filter Functions
    --===========================================================================================================================================================

    --#region Filter Functions

    ---For debug functions.
    ---@param whichIdentifier string | string[] | nil
    local function Identifier2String(whichIdentifier)
        local toString = "("
        local i = 1
        for key, __ in pairs(whichIdentifier) do
            if i > 1 then
                toString = toString .. ", "
            end
            toString = toString .. key
            i = i + 1
        end
        toString = toString .. ")"
        return toString
    end

    local function HasIdentifierFromTable(actor, whichIdentifier)
        if whichIdentifier[#whichIdentifier] == MATCHING_TYPE_ANY then
            for i = 1, #whichIdentifier - 1 do
                if actor.identifier[whichIdentifier[i]] then
                    return true
                end
            end
            return false
        elseif whichIdentifier[#whichIdentifier] == MATCHING_TYPE_ALL then
            for i = 1, #whichIdentifier - 1 do
                if not actor.identifier[whichIdentifier[i]] then
                    return false
                end
            end
            return true
        elseif type(whichIdentifier[#whichIdentifier]) == "string" then
            error("Matching type missing in identifier table.")
        else
            error("Invalid matching type specified in identifier table.")
        end
    end
    --#endregion

    --===========================================================================================================================================================
    --Utility
    --===========================================================================================================================================================

    --#region Utility
    local function Warning(whichWarning)
        for __, name in ipairs(config.MAP_CREATORS) do
            if string.find(GetPlayerName(GetLocalPlayer()), name) then
                print(whichWarning)
            end
        end
    end

    local function AddDelayedCallback(func, arg1, arg2, arg3)
        local index = #delayedCallbackFunctions + 1
        delayedCallbackFunctions[index] = func
        local args = delayedCallbackArgs[index] or {}
        args[1], args[2], args[3] = arg1, arg2, arg3
        delayedCallbackArgs[index] = args
    end

    local function RemoveUserCallbackFromList(self)
        if self == userCallbacks.first then
            if self.next then
                self.next.previous = nil
            else
                userCallbacks.last = nil
            end
            userCallbacks.first = self.next
        elseif self == userCallbacks.last then
            userCallbacks.last = self.previous
            self.previous.next = nil
        else
            self.previous.next = self.next
            self.next.previous = self.previous
        end
    end

    local function ExecuteUserCallback(self)
        if self.pair then
            if self.pair[0x3] == self.hostA and self.pair[0x4] == self.hostB then
                currentPair = self.pair
                self.callback(self.hostA, self.hostB, true)
                if functionOnDestroy[self.callback] then
                    functionOnDestroy[self.callback](self.hostA, self.hostB, true)
                end
                currentPair = OUTSIDE_OF_CYCLE
            else
                self.callback(self.hostA, self.hostB, false)
                if functionOnDestroy[self.callback] then
                    functionOnDestroy[self.callback](self.hostA, self.hostB, false)
                end
            end
        elseif self.args then
            if self.unpack then
                self.callback(unpack(self.args))
                if functionOnDestroy[self.callback] then
                    functionOnDestroy[self.callback](unpack(self.args))
                end
                ReturnTable(self.args)
            else
                self.callback(self.args)
                if functionOnDestroy[self.callback] then
                    functionOnDestroy[self.callback](self.args)
                end
            end
        else
            self.callback()
            if functionOnDestroy[self.callback] then
                functionOnDestroy[self.callback]()
            end
        end

        RemoveUserCallbackFromList(self)
        for key, __ in pairs(self) do
            self[key] = nil
        end
    end

    local function AddUserCallback(self)
        if userCallbacks.first == nil then
            userCallbacks.first = self
            userCallbacks.last = self
        else
            local node = userCallbacks.last
            local callCounter = self.callCounter
            while node and node.callCounter > callCounter do
                node = node.previous
            end
            if node == nil then
                --Insert at the beginning
                userCallbacks.first.previous = self
                self.next = userCallbacks.first
                userCallbacks.first = self
            else
                if node == userCallbacks.last then
                    --Insert at the end
                    userCallbacks.last = self
                else
                    --Insert in the middle
                    self.next = node.next
                    self.next.previous = self
                end
                self.previous = node
                node.next = self
            end
        end
    end

    local function PeriodicWrapper(caller)
        if caller.excess > 0 then
            local returnValue = caller.excess
            caller.excess = caller.excess - config.MAX_INTERVAL
            return returnValue
        end
        local returnValue = caller.callback(unpack(caller))
        if returnValue and returnValue > config.MAX_INTERVAL then
            caller.excess = returnValue - config.MAX_INTERVAL
        end
        return returnValue
    end

    local function RepeatedWrapper(caller)
        if caller.excess > 0 then
            local returnValue = caller.excess
            caller.excess = caller.excess - config.MAX_INTERVAL
            return returnValue
        end
        caller.currentExecution = caller.currentExecution + 1
        local returnValue = caller.callback(caller.currentExecution, unpack(caller))
        if caller.currentExecution == caller.howOften then
            ALICE_DisableCallback()
        end
        if returnValue and returnValue > config.MAX_INTERVAL then
            caller.excess = returnValue - config.MAX_INTERVAL
        end
        return returnValue
    end

    local function ToUpperCase(__, letter)
        return letter:upper()
    end

    local toCamelCase = setmetatable({}, {
        __index = function(self, whichString)
            whichString = whichString:gsub("|[cC]\x25x\x25x\x25x\x25x\x25x\x25x\x25x\x25x", "") --remove color codes
            whichString = whichString:gsub("|[rR]", "")                                         --remove closing color codes
            whichString = whichString:gsub("(\x25s)(\x25a)", ToUpperCase)                       --remove spaces and convert to upper case after space
            whichString = whichString:gsub("[^\x25w]", "")                                      --remove special characters
            self[whichString] = string.lower(whichString:sub(1,1)) .. string.sub(whichString,2) --converts first character to lower case
            return self[whichString]
        end
    })

    --For debug mode
    local function Function2String(func)
        if debug.functionName[func] then
            return debug.functionName[func]
        end
        local string = string.gsub(tostring(func), "function: ", "")
        if string.sub(string,1,1) == "0" then
            return string.sub(string, string.len(string) - 3, string.len(string))
        else
            return string
        end
    end

    --For debug mode
    local function Object2String(object)
        if IsHandle[object] then
            if IsWidget[object] then
                if HandleType[object] == "unit" then
                    local str = string.gsub(tostring(object), "unit: ", "")
                    if str:sub(1,1) == "0" then
                        return GetUnitName(object) .. ": " .. str:sub(str:len() - 3, str:len())
                    else
                        return str
                    end
                elseif HandleType[object] == "destructable" then
                    local str = string.gsub(tostring(object), "destructable: ", "")
                    if str:sub(1,1) == "0" then
                        return GetDestructableName(object) .. ": " .. str:sub(str:len() - 3, str:len())
                    else
                        return str
                    end
                else
                    local str = string.gsub(tostring(object), "item: ", "")
                    if str:sub(1,1) == "0" then
                        return GetItemName(object) .. ": " .. str:sub(str:len() - 3, str:len())
                    else
                        return str
                    end
                end
            else
                local str = tostring(object)
                local address = str:sub((str:find(":", nil, true) or 0) + 2, str:len())
                return HandleType[object] .. " " .. (address:sub(1,1) == "0" and address:sub(address:len() - 3, address:len()))
            end
        elseif object.__name then
            local str = string.gsub(tostring(object), object.__name .. ": ", "")
            str = string.sub(str, string.len(str) - 3, string.len(str))
            return object.__name .. " " .. str
        else
            local str = tostring(object)
            if string.sub(str,8,8) == "0" then
                return "table: " .. string.sub(str, string.len(str) - 3, string.len(str))
            else
                return str
            end
        end
    end

    local function OnUnitChangeOwner()
        local u = GetTriggerUnit()
        local newOwner = GetOwningPlayer(u)
        unitOwnerFunc[newOwner] = unitOwnerFunc[newOwner] or function() return newOwner end
        if actorOf[u] then
            if actorOf[u].isActor then
                actorOf[u].getOwner = unitOwnerFunc[newOwner]
            else
                for __, actor in ipairs(actorOf[u]) do
                    actor.getOwner = unitOwnerFunc[newOwner]
                end
            end
        end
        for __, func in ipairs(eventHooks.onUnitChangeOwner) do
            func(u)
        end
    end
    --#endregion

    --===========================================================================================================================================================
    --Getter functions
    --===========================================================================================================================================================

    --#region Getter Functions

    --x and y are stored with an anchor key because GetUnitX etc. cannot take an actor as an argument and they are identical for all actors anchored to the same
    --object. z is stored with an actor key because it requires zOffset, which is stored on the actor, and the z-values are not guaranteed to be identical for all
    --actors anchored to the same object.

    local coord = {
        classX          = setmetatable({}, {__index = function(self, key) self[key] = key.x                                                                                            return self[key] end}),
        classY          = setmetatable({}, {__index = function(self, key) self[key] = key.y                                                                                            return self[key] end}),
        classZ          = setmetatable({}, {__index = function(self, key) self[key] = key.anchor.z + key.zOffset                                                                       return self[key] end}),
        unitX           = setmetatable({}, {__index = function(self, key) self[key] = GetUnitX(key)                                                                                    return self[key] end}),
        unitY           = setmetatable({}, {__index = function(self, key) self[key] = GetUnitY(key)                                                                                    return self[key] end}),
        unitZ           = setmetatable({}, {__index = function(self, key) self[key] = GetTerrainZ(key.x[key.anchor], key.y[key.anchor]) + GetUnitFlyHeight(key.anchor) + key.zOffset   return self[key] end}),
        destructableX   = setmetatable({}, {__index = function(self, key) self[key] = GetDestructableX(key)                                                                            return self[key] end}),
        destructableY   = setmetatable({}, {__index = function(self, key) self[key] = GetDestructableY(key)                                                                            return self[key] end}),
        destructableZ   = setmetatable({}, {__index = function(self, key) self[key] = GetTerrainZ(key.x[key.anchor], key.y[key.anchor]) + key.zOffset                                  return self[key] end}),
        itemX           = setmetatable({}, {__index = function(self, key) self[key] = GetItemX(key)                                                                                    return self[key] end}),
        itemY           = setmetatable({}, {__index = function(self, key) self[key] = GetItemY(key)                                                                                    return self[key] end}),
        itemZ           = setmetatable({}, {__index = function(self, key) self[key] = GetTerrainZ(key.x[key.anchor], key.y[key.anchor]) + key.zOffset                                  return self[key] end}),
        terrainZ        = setmetatable({}, {__index = function(self, key) self[key] = GetTerrainZ(key.x[key.anchor], key.y[key.anchor]) + key.zOffset                                  return self[key] end}),
        globalXYZ       = setmetatable({}, {__index = function(self, key) self[key] = 0                                                                                                return 0         end})
    }

    local function GetClassOwner(source)
        return source.owner
    end

    local function GetClassOwnerById(source)
        return Player(source.owner - 1)
    end
    --#endregion

    --===========================================================================================================================================================
    --Pair Class
    --===========================================================================================================================================================

    --#region Pair
    ---@class Pair
    local Pair = {
        destructionQueued = nil,       ---@type boolean
        userData = nil,                ---@type table
        hadContact = nil,              ---@type boolean
        cooldown = nil,                 ---@type number
        paused = nil,                   ---@type boolean
    }

    local function GetInteractionFunc(male, female)
        local func = pairingFunctions[female.identifierClass][male.interactionsClass]
        if func ~= nil then
            return func
        end

        local identifier = female.identifier
        local level = 0
        local conflict = false
        for key, value in pairs(male.interactions) do
            if type(key) == "string" then
                if identifier[key] then
                    if level < 1 then
                        func = value
                        level = 1
                    elseif level == 1 then
                        conflict = true
                    end
                end
            else
                local match = true
                for __, tableKey in ipairs(key) do
                    if not identifier[tableKey] then
                        match = false
                        break
                    end
                end
                if match then
                    if #key > level then
                        func = value
                        level = #key
                        conflict = false
                    elseif #key == level then
                        conflict = true
                    end
                end
            end
        end

        if conflict then
            error("InteractionFunc ambiguous for actors with identifiers " .. Identifier2String(male.identifier) .. " and " .. Identifier2String(female.identifier) .. ".")
        end
        if func then
            pairingFunctions[female.identifierClass][male.interactionsClass] = func
            return func
        else
            pairingFunctions[female.identifierClass][male.interactionsClass] = false
            return false
        end
    end

    ---@param whichPair Pair
    local function AddPairToEveryStepList(whichPair)
        whichPair[0x6] = lastEveryStepPair
        whichPair[0x5] = nil
        lastEveryStepPair[0x5] = whichPair
        lastEveryStepPair = whichPair
        numEveryStepPairs = numEveryStepPairs + 1
    end

    ---@param whichPair Pair
    local function RemovePairFromEveryStepList(whichPair)
        if whichPair[0x6] == nil then
            return
        end
        if whichPair[0x5] then
            whichPair[0x5][0x6] = whichPair[0x6]
        else
            lastEveryStepPair = whichPair[0x6]
        end

        whichPair[0x6][0x5] = whichPair[0x5]
        whichPair[0x6] = nil
        numEveryStepPairs = numEveryStepPairs - 1
    end

    ---@param actorA Actor
    ---@param actorB Actor
    ---@param interactionFunc function
    ---@return Pair | nil
    local function CreatePair(actorA, actorB, interactionFunc)
        if pairingExcluded[actorA][actorB] or interactionFunc == nil or actorA.host == actorB.host or actorA.originalAnchor == actorB.originalAnchor then
            pairingExcluded[actorA][actorB] = true
            pairingExcluded[actorB][actorA] = true
            return nil
        end

        if (actorA.isSuspended or actorB.isSuspended) and not functionIsUnsuspendable[interactionFunc] then
            return nil
        end

        local self ---@type Pair
        if #unusedPairs == 0 then
---@diagnostic disable-next-line: missing-fields
            self = {}
        else
            self = unusedPairs[#unusedPairs]
            unusedPairs[#unusedPairs] = nil
        end

        self[0x1] = actorA
        self[0x2] = actorB
        self[0x3] = actorA.host
        if actorB == SELF_INTERACTION_ACTOR then
            self[0x4] = actorA.host
        else
            self[0x4] = actorB.host
        end

        self[0x8] = interactionFunc

        local lastPair = actorA.lastPair
        actorA.previousPair[self] = lastPair
        actorA.nextPair[lastPair] = self
        actorA.lastPair = self

        lastPair = actorB.lastPair
        actorB.previousPair[self] = lastPair
        actorB.nextPair[lastPair] = self
        actorB.lastPair = self

        self.destructionQueued = nil
        pairList[actorA][actorB] = self

        if functionInitializer[interactionFunc] then
            local tempPair = currentPair
            currentPair = self
            functionInitializer[interactionFunc](self[0x3], self[0x4])
            currentPair = tempPair
        end

        if (functionPauseOnStationary[interactionFunc] and actorA.isStationary) then
            if functionIsEveryStep[interactionFunc] then
                self[0x7] = true
            else
                self[0x5] = DO_NOT_EVALUATE
            end
            self.paused = true
        elseif functionIsEveryStep[interactionFunc] then
            AddPairToEveryStepList(self)
            self[0x7] = true
        else
            local firstStep
            if functionDelay[interactionFunc] then
                if functionDelayIsDistributed[interactionFunc] then
                    functionDelayCurrent[interactionFunc] = functionDelayCurrent[interactionFunc] + config.MIN_INTERVAL
                    if functionDelayCurrent[interactionFunc] > functionDelay[interactionFunc] then
                        functionDelayCurrent[interactionFunc] = functionDelayCurrent[interactionFunc] - functionDelay[interactionFunc]
                    end
                    firstStep = cycle.counter + (functionDelayCurrent[interactionFunc]*INV_MIN_INTERVAL + 1) // 1
                else
                    firstStep = cycle.counter + (functionDelay[interactionFunc]*INV_MIN_INTERVAL + 1) // 1
                end
            else
                firstStep = cycle.counter + 1
            end
            if firstStep > CYCLE_LENGTH then
                firstStep = firstStep - CYCLE_LENGTH
            end
            numPairs[firstStep] = numPairs[firstStep] + 1
            whichPairs[firstStep][numPairs[firstStep]] = self
            self[0x5] = firstStep
            self[0x6] = numPairs[firstStep]
        end

        return self
    end

    local function DestroyPair(self)
        if self[0x7] then
            RemovePairFromEveryStepList(self)
        else
            whichPairs[self[0x5]][self[0x6]] = DUMMY_PAIR
        end
        self[0x5] = nil
        self[0x6] = nil
        self.destructionQueued = true

        local tempPair = currentPair
        currentPair = self
        if self.hadContact then
            if functionOnReset[self[0x8]] and not cycle.isCrash then
                functionOnReset[self[0x8]](self[0x3], self[0x4], self.userData, true)
            end
            self.hadContact = nil
        end
        if functionOnBreak[self[0x8]] and not cycle.isCrash then
            functionOnBreak[self[0x8]](self[0x3], self[0x4], self.userData, true)
        end
        if functionOnDestroy[self[0x8]] and not cycle.isCrash then
            functionOnDestroy[self[0x8]](self[0x3], self[0x4], self.userData)
        end
        if self.userData then
            ReturnTable(self.userData)
        end
        currentPair = tempPair

        --Reset ALICE_PairIsUnoccupied()
        if self[0x2][self[0x8]] == self then
            self[0x2][self[0x8]] = nil
        end

        if self[0x2] == SELF_INTERACTION_ACTOR then
            self[0x1].selfInteractions[self[0x8]] = nil
        end

        local actorA = self[0x1]
        local previous = actorA.previousPair
        local next = actorA.nextPair
        if next[self] then
            previous[next[self]] = previous[self]
        else
            actorA.lastPair = previous[self]
        end
        next[previous[self]] = next[self]
        previous[self] = nil
        next[self] = nil

        local actorB = self[0x2]
        previous = actorB.previousPair
        next = actorB.nextPair
        if next[self] then
            previous[next[self]] = previous[self]
        else
            actorB.lastPair = previous[self]
        end
        next[previous[self]] = next[self]
        previous[self] = nil
        next[self] = nil

        unusedPairs[#unusedPairs + 1] = self
        pairList[actorA][actorB] = nil
        pairList[actorB][actorA] = nil

        self.userData = nil
        self.hadContact = nil
        self[0x7] = nil
        self.paused = nil
        if self.cooldown then
            ReturnTable(self.cooldown)
            self.cooldown = nil
        end
    end

    local function PausePair(self)
        if self.destructionQueued then
            return
        end
        if self[0x7] then
            RemovePairFromEveryStepList(self)
        else
            if self[0x5] ~= DO_NOT_EVALUATE then
                whichPairs[self[0x5]][self[0x6]] = DUMMY_PAIR
                local nextStep = DO_NOT_EVALUATE
                numPairs[nextStep] = numPairs[nextStep] + 1
                whichPairs[nextStep][numPairs[nextStep]] = self
                self[0x5] = nextStep
                self[0x6] = numPairs[nextStep]
            end
        end
        self.paused = true
    end

    local function UnpausePair(self)
        if self.destructionQueued then
            return
        end
        local actorA = self[0x1]
        local actorB = self[0x2]
        if self[0x7] then
            if self[0x6] == nil and (not actorA.usesCells or not actorB.usesCells or SharesCellWith(actorA, actorB)) then
                AddPairToEveryStepList(self)
            end
        else
            if self[0x5] == DO_NOT_EVALUATE and (not actorA.usesCells or not actorB.usesCells or SharesCellWith(actorA, actorB)) then
                local nextStep = cycle.counter + 1
                if nextStep > CYCLE_LENGTH then
                    nextStep = nextStep - CYCLE_LENGTH
                end

                numPairs[nextStep] = numPairs[nextStep] + 1
                whichPairs[nextStep][numPairs[nextStep]] = self
                self[0x5] = nextStep
                self[0x6] = numPairs[nextStep]
            end
        end
        self.paused = nil
    end
    --#endregion

    --===========================================================================================================================================================
    --Actor Class
    --===========================================================================================================================================================

    local function GetUnusedActor()
        local self
        if #unusedActors == 0 then
            --Actors have their own table recycling system. These fields do not get nilled on destroy.
---@diagnostic disable-next-line: missing-fields
            self = {} ---@type Actor
            self.isActor = true
            self.identifier = {}
            self.firstPair = {}
            self.lastPair = self.firstPair
            self.nextPair = {}
            self.previousPair = {}
            self.isInCell = {}
            self.nextInCell = {}
            self.previousInCell = {}
            self.interactions = {}
            self.selfInteractions = {}
            self.references = {}
---@diagnostic disable-next-line: missing-fields
            pairList[self] = {}
            pairingExcluded[self] = {}
        else
            self = unusedActors[#unusedActors]
            unusedActors[#unusedActors] = nil
        end
        return self
    end

    GetActor = function(object, keyword)
        if object == nil then
            if debug.selectedActor then
                return debug.selectedActor
            end
            return nil
        end

        local actorOf = actorOf[object]
        if actorOf then
            if actorOf.isActor then
                if keyword == nil or actorOf.identifier[keyword] then
                    return actorOf
                else
                    return nil
                end
            elseif keyword == nil then
                --If called within interactionFunc and keyword is not specified, prioritize returning actor that's in the current pair, then an actor for which the object is the
                --host, not the anchor.
                if currentPair ~= OUTSIDE_OF_CYCLE then
                    if object == currentPair[0x3] then
                        return currentPair[0x1]
                    elseif object == currentPair[0x4] then
                        return currentPair[0x2]
                    end
                end
                for __, actor in ipairs(actorOf) do
                    if actor.host == object then
                        return actor
                    end
                end
                return actorOf[1]
            else
                for __, actor in ipairs(actorOf) do
                    if actor.identifier[keyword] then
                        return actor
                    end
                end
                return nil
            end
        elseif type(object) == "table" and object.isActor then
            return object
        end
        return nil
    end

    --#region Actor

    ---@class Actor
    local Actor = {
        --Main:
        isActor = nil,                  ---@type boolean
        host = nil,                     ---@type any
        anchor = nil,                   ---@type any
        originalAnchor = nil,           ---@type any
        getOwner = nil,                 ---@type function
        interactions = nil,             ---@type function | table | nil
        selfInteractions = nil,         ---@type table
        identifier = nil,               ---@type table
        visualizer = nil,               ---@type effect
        alreadyDestroyed = nil,         ---@type boolean
        causedCrash = nil,              ---@type boolean
        isSuspended = nil,              ---@type boolean
        identifierClass = nil,          ---@type string
        interactionsClass = nil,        ---@type string
        references = nil,               ---@type table
        periodicPair = nil,             ---@type Pair

        --Pairs:
        firstPair = nil,                ---@type table
        lastPair = nil,                 ---@type table
        nextPair = nil,                 ---@type table
        previousPair = nil,             ---@type table

        --Coordinates:
        x = nil,                        ---@type table
        y = nil,                        ---@type table
        z = nil,                        ---@type table
        lastX = nil,                    ---@type number
        lastY = nil,                    ---@type number
        zOffset = nil,                  ---@type number

        --Flags:
        priority = nil,                 ---@type integer
        index = nil,                    ---@type integer
        isStationary = nil,             ---@type boolean
        unique = nil,                   ---@type integer
        bindToBuff = nil,               ---@type string | nil
        persistOnDeath = nil,           ---@type boolean
        unit = nil,                     ---@type unit | nil
        waitingForBuff = nil,           ---@type boolean
        bindToOrder = nil,              ---@type integer | nil
        onDestroy = nil,                ---@type function | nil
        isUnselectable = nil,           ---@type boolean
        isAnonymous = nil,              ---@type boolean

        --Cell interaction:
        isGlobal = nil,                 ---@type boolean
        usesCells = nil,                ---@type boolean
        halfWidth = nil,                ---@type number
        halfHeight = nil,               ---@type number
        minX = nil,                     ---@type integer
        minY = nil,                     ---@type integer
        maxX = nil,                     ---@type integer
        maxY = nil,                     ---@type integer
        cellCheckInterval = nil,        ---@type integer
        nextCellCheck = nil,            ---@type integer
        positionInCellCheck = nil,      ---@type integer
        isInCell = nil,                 ---@type boolean[]
        nextInCell = nil,               ---@type Actor[]
        previousInCell = nil,           ---@type Actor[]
        cellsVisualized = nil,          ---@type boolean
        cellVisualizers = nil,          ---@type lightning[]
    }

    ---@param host any
    ---@param identifier string | string[]
    ---@param interactions table | nil
    ---@param flags table
    ---@return Actor | nil
    Create = function(host, identifier, interactions, flags)

        local recycle, self, actorsOfClass
        if flags.actorClass then
            actorsOfClass = actorsOfActorClass[flags.actorClass]
            if #actorsOfClass > 0 then
                recycle = true
            end
        end

        if not recycle then
            local identifierType = type(identifier)
            local tempIdentifier = GetTable()
            if identifierType == "string" then
                tempIdentifier[1] = identifier
            elseif identifierType == "table" then
                for i = 1, #identifier do
                    tempIdentifier[i] = identifier[i]
                end
            else
                if identifier == nil then
                    error("Object identifier is nil.")
                else
                    error("Object identifier must be string or table, but was " .. identifierType)
                end
            end

            self = GetUnusedActor()

            totalActors = totalActors + 1
            self.unique = totalActors
            self.causedCrash = nil
            self.actorClass = flags.actorClass

            self.host = host or EMPTY_TABLE
            if flags.anchor then
                local anchor = flags.anchor
                while type(anchor) == "table" and anchor.anchor do
                    CreateReference(self, anchor)
                    anchor = anchor.anchor --Sup dawg, I heard you like anchors.
                end
                self.anchor = anchor
                CreateReference(self, anchor)
                if host then
                    CreateReference(self, host)
                end
            elseif host then
                self.anchor = host
                CreateReference(self, host)
            end
            self.originalAnchor = self.anchor

            --Execute onCreation functions before flags are initialized.
            for __, keyword in ipairs(tempIdentifier) do
                if onCreation.funcs[keyword] then
                    for __, func in ipairs(onCreation.funcs[keyword]) do
                        func(self.host)
                    end
                end
            end

            --Add additional flags from onCreation hooks.
            for __, keyword in ipairs(tempIdentifier) do
                if onCreation.flags[keyword] then
                    local onCreationFlags = onCreation.flags[keyword]
                    for key, __ in pairs(OVERWRITEABLE_FLAGS) do
                        if onCreationFlags[key] then
                            if type(onCreationFlags[key]) == "function" then
                                additionalFlags[key] = onCreationFlags[key](host)
                            else
                                additionalFlags[key] = onCreationFlags[key]
                            end
                        end
                    end
                end
            end

            --Transform identifier sequence into hashmap.
            local onCreationIdentifiers
            for __, keyword in ipairs(tempIdentifier) do
                self.identifier[keyword] = true
                if onCreation.identifiers[keyword] then
                    onCreationIdentifiers = onCreationIdentifiers or GetTable()
                    for __, newIdentifier in ipairs(onCreation.identifiers[keyword]) do
                        if type(newIdentifier) == "function" then
                            onCreationIdentifiers[#onCreationIdentifiers + 1] = newIdentifier(self.host)
                        else
                            onCreationIdentifiers[#onCreationIdentifiers + 1] = newIdentifier
                        end
                    end
                end
            end

            if onCreationIdentifiers then
                for __, keyword in ipairs(onCreationIdentifiers) do
                    self.identifier[keyword] = true
                end
            end

            --Copy interactions.
            if interactions then
                for keyword, func in pairs(interactions) do
                    if keyword ~= "self" then
                        self.interactions[keyword] = func
                    end
                end
            end

            --Add additional interactions from onCreation hooks.
            for keyword, __ in pairs(self.identifier) do
                if onCreation.interactions[keyword] then
                    for target, func in pairs(onCreation.interactions[keyword]) do
                        self.interactions[target] = func
                    end
                end
            end

            AssignActorClass(self, true, true)

            self.zOffset = additionalFlags.zOffset or flags.zOffset or 0

            SetOwnerFunc(self, host)

            --Set or inherit stationary.
            if objectIsStationary[self.anchor] then
                self.isStationary = true
            elseif additionalFlags.isStationary or flags.isStationary then
                if not objectIsStationary[self.anchor] then
                    objectIsStationary[self.anchor] = true
                    if not actorOf[self.anchor].isActor then
                        for __, actor in ipairs(actorOf[self.anchor]) do
                            if actor ~= self then
                                SetStationary(actor, true)
                            end
                        end
                    end
                end
                self.isStationary = true
            else
                self.isStationary = nil
            end

            --Set coordinate getter functions.
            SetCoordinateFuncs(self)
            if flags.isAnonymous then
                if interactions then
                    error("An anonymous actor cannot carry an interactions table. To add self-interactions, use the selfInteractions flag.")
                end
                self.isAnonymous = true
            else
                self.isAnonymous = nil
            end
            self.isGlobal = flags.isGlobal or (self.x == coord.globalXYZ or self.x == nil) or self.isAnonymous or nil
            self.usesCells = not self.isGlobal and not additionalFlags.hasInfiniteRange and not flags.hasInfiniteRange
            if not self.isGlobal then
                self.lastX = self.x[self.anchor]
                self.lastY = self.y[self.anchor]
            end

            self.priority = additionalFlags.priority or flags.priority or 0

            --Pair with global actors or all actors if self is global.
            local selfFunc, actorFunc
            for __, actor in ipairs(self.usesCells and celllessActorList or actorList) do
                selfFunc = GetInteractionFunc(self, actor)
                actorFunc = GetInteractionFunc(actor, self)
                if selfFunc and actorFunc then
                    if self.priority < actor.priority then
                        CreatePair(actor, self, actorFunc)
                    else
                        CreatePair(self, actor, selfFunc)
                    end
                elseif selfFunc then
                    CreatePair(self, actor, selfFunc)
                elseif actorFunc then
                    CreatePair(actor, self, actorFunc)
                end
            end

            --Create self-interactions.
            local selfInteractions = interactions and interactions.self or flags.selfInteractions
            if selfInteractions then
                if type(selfInteractions) == "table" then
                    for __, func in ipairs(selfInteractions) do
                        self.selfInteractions[func] = CreatePair(self, SELF_INTERACTION_ACTOR, func)
                    end
                    if self.actorClass then
                        self.orderedSelfInteractions = {}
                        for i = 1, #selfInteractions do
                            self.orderedSelfInteractions[i] = selfInteractions[i]
                        end
                    end
                else
                    self.selfInteractions[selfInteractions] = CreatePair(self, SELF_INTERACTION_ACTOR, selfInteractions)
                    if self.actorClass then
                        self.orderedSelfInteractions = {selfInteractions}
                    end
                end
                self.interactions.self = nil
            end

            --Add additional self-interactions from onCreation hooks.
            for __, keyword in ipairs(tempIdentifier) do
                if onCreation.selfInteractions[keyword] then
                    for __, func in ipairs(onCreation.selfInteractions[keyword]) do
                        self.selfInteractions[func] = CreatePair(self, SELF_INTERACTION_ACTOR, func)
                    end
                    if self.actorClass then
                        for i = 1, #onCreation.selfInteractions[keyword] do
                            self.orderedSelfInteractions[#self.orderedSelfInteractions + 1] = onCreation.selfInteractions[keyword][i]
                        end
                    end
                end
            end

            --Add additional self-interactions from onCreation hooks to onCreation identifiers.
            if onCreationIdentifiers then
                for __, keyword in ipairs(onCreationIdentifiers) do
                    if onCreation.selfInteractions[keyword] then
                        for __, func in ipairs(onCreation.selfInteractions[keyword]) do
                            self.selfInteractions[func] = CreatePair(self, SELF_INTERACTION_ACTOR, func)
                        end
                        if self.actorClass then
                            for i = 1, #onCreation.selfInteractions[keyword] do
                                self.orderedSelfInteractions[#self.orderedSelfInteractions + 1] = onCreation.selfInteractions[keyword][i]
                            end
                        end
                    end
                end
                ReturnTable(onCreationIdentifiers)
            end

            --Set actor size and initialize cells and cell checks.
            if not self.isGlobal then
                if flags.width then
                    self.halfWidth = flags.width/2
                    if flags.height then
                        self.halfHeight = flags.height/2
                    else
                        Warning("|cffff0000Warning:|r width flag set for actor, but not height flag.")
                        self.halfHeight = flags.width/2
                    end
                else
                    local radius = additionalFlags.radius or flags.radius
                    if radius then
                        self.halfWidth = radius
                        self.halfHeight = radius
                    else
                        self.halfWidth = config.DEFAULT_OBJECT_RADIUS
                        self.halfHeight = config.DEFAULT_OBJECT_RADIUS
                    end
                end

                InitCells(self)

                if self.isStationary then
                    self.nextCellCheck = DO_NOT_EVALUATE
                    local interval = additionalFlags.cellCheckInterval or flags.cellCheckInterval or config.DEFAULT_CELL_CHECK_INTERVAL
                    self.cellCheckInterval = min(MAX_STEPS, max(1, (interval*INV_MIN_INTERVAL) // 1 + 1))
                else
                    InitCellChecks(self, additionalFlags.cellCheckInterval or flags.cellCheckInterval or config.DEFAULT_CELL_CHECK_INTERVAL)
                end
            end

            --Create onDeath trigger.
            self.persistOnDeath = flags.persistOnDeath
            if (HandleType[self.anchor] == "destructable" or HandleType[self.anchor] == "item") and widgets.deathTriggers[self.anchor] == nil then
                widgets.deathTriggers[self.anchor] = CreateTrigger()
                TriggerRegisterDeathEvent(widgets.deathTriggers[self.anchor], self.anchor)
                if HandleType[self.anchor] == "destructable" then
                    TriggerAddAction(widgets.deathTriggers[self.anchor], OnDestructableDeath)
                else
                    TriggerAddAction(widgets.deathTriggers[self.anchor], OnItemDeath)
                end
            end

            --Create binds.
            if flags.bindToBuff then
                CreateBinds(self, flags.bindToBuff, nil)
            elseif flags.bindToOrder then
                CreateBinds(self, nil, flags.bindToOrder)
            end

            --Misc.
            self.onDestroy = additionalFlags.onActorDestroy or flags.onActorDestroy

            if debug.visualizeAllActors and not self.isGlobal then
                CreateVisualizer(self)
            end

            self.alreadyDestroyed = nil

            actorList[#actorList + 1] = self
            if not self.usesCells and not self.isAnonymous then
                celllessActorList[#celllessActorList + 1] = self
            end
            self.index = #actorList

            self.isUnselectable = additionalFlags.isUnselectable or flags.isUnselectable

            for key, __ in pairs(additionalFlags) do
                additionalFlags[key] = nil
            end
            ReturnTable(tempIdentifier)

        else

            self = actorsOfClass[#actorsOfClass]
            actorsOfClass[#actorsOfClass] = nil

            totalActors = totalActors + 1
            self.unique = totalActors
            self.causedCrash = nil

            self.host = host or EMPTY_TABLE
            if flags.anchor then
                local anchor = flags.anchor
                while type(anchor) == "table" and anchor.anchor do
                    CreateReference(self, anchor)
                    anchor = anchor.anchor --Sup dawg, I heard you like anchors.
                end
                self.anchor = anchor
                CreateReference(self, anchor)
                if host then
                    CreateReference(self, host)
                end
            elseif host then
                self.anchor = host
                CreateReference(self, host)
            end
            self.originalAnchor = self.anchor

            SetOwnerFunc(self, host)

            if not self.isGlobal then
                self.lastX = self.x[self.anchor]
                self.lastY = self.y[self.anchor]
            end

            --Pair with global actors or all actors if self is global.
            local selfFunc, actorFunc
            for __, actor in ipairs(self.usesCells and celllessActorList or actorList) do
                selfFunc = GetInteractionFunc(self, actor)
                actorFunc = GetInteractionFunc(actor, self)
                if selfFunc and actorFunc then
                    if self.priority < actor.priority then
                        CreatePair(actor, self, actorFunc)
                    else
                        CreatePair(self, actor, selfFunc)
                    end
                elseif selfFunc then
                    CreatePair(self, actor, selfFunc)
                elseif actorFunc then
                    CreatePair(actor, self, actorFunc)
                end
            end

            --Create self-interactions.
            if self.orderedSelfInteractions then
                for __, func in ipairs(self.orderedSelfInteractions) do
                    self.selfInteractions[func] = CreatePair(self, SELF_INTERACTION_ACTOR, func)
                end
            end

            --Set actor size and initialize cells and cell checks.
            if not self.isGlobal then
                if flags.width then
                    self.halfWidth = flags.width/2
                    if flags.height then
                        self.halfHeight = flags.height/2
                    else
                        Warning("|cffff0000Warning:|r width flag set for actor, but not height flag.")
                        self.halfHeight = flags.width/2
                    end
                else
                    local radius = additionalFlags.radius or flags.radius
                    if radius then
                        self.halfWidth = radius
                        self.halfHeight = radius
                    else
                        self.halfWidth = config.DEFAULT_OBJECT_RADIUS
                        self.halfHeight = config.DEFAULT_OBJECT_RADIUS
                    end
                end

                InitCells(self)

                if self.isStationary then
                    self.nextCellCheck = DO_NOT_EVALUATE
                    local interval = additionalFlags.cellCheckInterval or flags.cellCheckInterval or config.DEFAULT_CELL_CHECK_INTERVAL
                    self.cellCheckInterval = min(MAX_STEPS, max(1, (interval*INV_MIN_INTERVAL) // 1 + 1))
                else
                    InitCellChecks(self, additionalFlags.cellCheckInterval or flags.cellCheckInterval or config.DEFAULT_CELL_CHECK_INTERVAL)
                end
            end

            --Create onDeath trigger.
            if (HandleType[self.anchor] == "destructable" or HandleType[self.anchor] == "item") and widgets.deathTriggers[self.anchor] == nil then
                widgets.deathTriggers[self.anchor] = CreateTrigger()
                TriggerRegisterDeathEvent(widgets.deathTriggers[self.anchor], self.anchor)
                if HandleType[self.anchor] == "destructable" then
                    TriggerAddAction(widgets.deathTriggers[self.anchor], OnDestructableDeath)
                else
                    TriggerAddAction(widgets.deathTriggers[self.anchor], OnItemDeath)
                end
            end

            --Create binds.
            if self.bindToBuff then
                CreateBinds(self, flags.bindToBuff, nil)
            elseif self.bindToOrder then
                CreateBinds(self, nil, flags.bindToOrder)
            end

            --Misc.

            if debug.visualizeAllActors and not self.isGlobal then
                CreateVisualizer(self)
            end

            self.alreadyDestroyed = nil

            actorList[#actorList + 1] = self
            if not self.usesCells and not self.isAnonymous then
                celllessActorList[#celllessActorList + 1] = self
            end
            self.index = #actorList
        end

        return self
    end

    Destroy = function(self)
        if self == nil or self.alreadyDestroyed then
            return
        end

        self.alreadyDestroyed = true
        destroyedActors[#destroyedActors + 1] = self

        if self.onDestroy then
            self.onDestroy(self.host)
            if not self.actorClass then
                self.onDestroy = nil
            end
        end

        local next = self.nextPair
        local pair = next[self.firstPair]
        while pair do
            pair.destructionQueued = true
            pair = next[pair]
        end

        if self.index then
            actorList[#actorList].index = self.index
            actorList[self.index] = actorList[#actorList]
            actorList[#actorList] = nil
        end
        if not self.usesCells and not self.isAnonymous then
            for i, actor in ipairs(celllessActorList) do
                if self == actor then
                    celllessActorList[i] = celllessActorList[#celllessActorList]
                    celllessActorList[#celllessActorList] = nil
                    break
                end
            end
        end

        if not self.isGlobal then
            local nextCheck = self.nextCellCheck
            if nextCheck ~= DO_NOT_EVALUATE then
                local actorAtHighestPosition = cellCheckedActors[nextCheck][numCellChecks[nextCheck]]
                actorAtHighestPosition.positionInCellCheck = self.positionInCellCheck
                cellCheckedActors[nextCheck][self.positionInCellCheck] = actorAtHighestPosition
                numCellChecks[nextCheck] = numCellChecks[nextCheck] - 1
            end
            for X = self.minX, self.maxX do
                for Y = self.minY, self.maxY do
                    RemoveCell(CELL_LIST[X][Y], self)
                end
            end
        end

        if debug.visualizeAllActors and not self.isGlobal then
            DestroyEffect(self.visualizer)
        end

        for object, __ in pairs(self.references) do
            RemoveReference(self, object)
        end

        if self == debug.selectedActor then
            DestroyEffect(self.visualizer)
            debug.selectedActor = nil
        end
    end

    Release = function(self)
        for key, __ in pairs(pairingExcluded[self]) do
            pairingExcluded[self][key] = nil
            pairingExcluded[key][self] = nil
        end

        self.bindToBuff = nil
        self.bindToOrder = nil

        if self.cellsVisualized then
            for __, bolt in ipairs(self.cellVisualizers) do
                DestroyLightning(bolt)
            end
            self.cellsVisualized = nil
        end

        if self.host ~= EMPTY_TABLE then
            self.host = nil
            self.x[self.anchor] = nil
            self.y[self.anchor] = nil
            self.z[self] = nil
            self.anchor = nil
        end

        if self.actorClass then
            local actorsOfClass = actorsOfActorClass[self.actorClass]
            actorsOfClass[#actorsOfClass + 1] = self
        else
            for key, __ in pairs(self.interactions) do
                self.interactions[key] = nil
            end
            for key, __ in pairs(self.identifier) do
                self.identifier[key] = nil
            end
            for key, __ in pairs(self.selfInteractions) do
                self.selfInteractions[key] = nil
            end

            self.x = nil
            self.y = nil
            self.z = nil

            unusedActors[#unusedActors + 1] = self
        end

        self.lastX = nil
        self.lastY = nil
        self.isSuspended = nil
    end

    ---Create a reference to the actor. If more than one actor, transform into a table and store actors in a sequence.
    CreateReference = function(self, object)
        if actorOf[object] == nil then
            actorOf[object] = self
        elseif actorOf[object].isActor then
---@diagnostic disable-next-line: missing-fields
            actorOf[object] = {actorOf[object], self}
        else
            actorOf[object][#actorOf[object] + 1] = self
        end
        self.references[object] = true
    end

    RemoveReference = function(self, object)
        if actorOf[object].isActor then
            actorOf[object] = nil
        else
            for j, v in ipairs(actorOf[object]) do
                if self == v then
                    table.remove(actorOf[object], j)
                end
            end
            if #actorOf[object] == 1 then
                actorOf[object] = actorOf[object][1]
            end
        end
        self.references[object] = nil
    end

    SetCoordinateFuncs = function(self)
        if self.anchor ~= nil then
            if IsHandle[self.anchor] then
                local type = HandleType[self.anchor]
                if type == "unit" then
                    self.x = coord.unitX
                    self.y = coord.unitY
                    self.z = coord.unitZ
                elseif type == "destructable" then
                    self.x = coord.destructableX
                    self.y = coord.destructableY
                    self.z = coord.destructableZ
                elseif type == "item" then
                    self.x = coord.itemX
                    self.y = coord.itemY
                    self.z = coord.itemZ
                else
                    self.x = coord.globalXYZ
                    self.y = coord.globalXYZ
                    self.z = coord.globalXYZ
                end
            elseif self.anchor.x then
                self.x = coord.classX
                self.y = coord.classY
                if self.anchor.z then
                    self.z = coord.classZ
                else
                    self.z  = coord.terrainZ
                end
            else
                self.x = coord.globalXYZ
                self.y = coord.globalXYZ
                self.z = coord.globalXYZ
            end
            self.x[self.anchor] = nil
            self.y[self.anchor] = nil
            self.z[self] = nil
        end
    end

    SetOwnerFunc = function(self, source)
        if source then
            if IsHandle[source] then
                if HandleType[source] == "unit" then
                    local owner = GetOwningPlayer(source)
                    unitOwnerFunc[owner] = unitOwnerFunc[owner] or function() return owner end
                    self.getOwner = unitOwnerFunc[owner]
                else
                    self.getOwner = DoNothing
                end
            elseif type(source) == "table" then
                if type(source.owner) == "number" then
                    self.getOwner = GetClassOwnerById
                elseif source.owner then
                    self.getOwner = GetClassOwner
                else
                    self.getOwner = DoNothing
                end
            end
        end
    end

    InitCells = function(self)
        local x = self.x[self.anchor]
        local y = self.y[self.anchor]
        self.minX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x - self.halfWidth - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        self.minY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y - self.halfHeight - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))
        self.maxX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x + self.halfWidth - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        self.maxY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y + self.halfHeight - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))

        for key, __ in pairs(actorAlreadyChecked) do
            actorAlreadyChecked[key] = nil
        end
        actorAlreadyChecked[self] = true
        for X = self.minX, self.maxX do
            for Y = self.minY, self.maxY do
                EnterCell(CELL_LIST[X][Y], self)
            end
        end
    end

    InitCellChecks = function(self, interval)
        self.cellCheckInterval = min(MAX_STEPS, max(1, (interval*INV_MIN_INTERVAL) // 1 + 1))
        local nextStep = cycle.counter + self.cellCheckInterval
        if nextStep > CYCLE_LENGTH then
            nextStep = nextStep - CYCLE_LENGTH
        end
        numCellChecks[nextStep] = numCellChecks[nextStep] + 1
        cellCheckedActors[nextStep][numCellChecks[nextStep]] = self
        self.nextCellCheck = nextStep
        self.positionInCellCheck = numCellChecks[nextStep]
    end

    AssignActorClass = function(self, doIdentifier, doInteractions)
        --Concatenates all identifiers and interaction table keys to generate a unique string for an interactionFunc lookup table.
        if doIdentifier then
            local i = 1
            local identifierClass = GetTable()
            for id, __ in pairs(self.identifier) do
                identifierClass[i] = id
                i = i + 1
            end
            sort(identifierClass)
            self.identifierClass = concat(identifierClass)
            pairingFunctions[self.identifierClass] = pairingFunctions[self.identifierClass] or {}
            ReturnTable(identifierClass)
        end

        if doInteractions then
            local j = 1
            local first, entry
            local interactionsClass = GetTable()
            for target, func in pairs(self.interactions) do
                if type(target) == "string" then
                    if not functionKey[func] then
                        highestFunctionKey = highestFunctionKey + 1
                        functionKey[func] = highestFunctionKey
                    end
                    interactionsClass[j] = target .. functionKey[func]
                elseif type(target) == "table" then
                    first = true
                    entry = ""
                    for __, subtarget in ipairs(target) do
                        if not first then
                            entry = entry .. "+"
                        else
                            first = false
                        end
                        if not functionKey[func] then
                            highestFunctionKey = highestFunctionKey + 1
                            functionKey[func] = highestFunctionKey
                        end
                        entry = entry .. subtarget
                    end
                    interactionsClass[j] = entry .. functionKey[func]
                else
                    error("Interactions table key must be string or table, but was " .. type(target) .. ".")
                end
                j = j + 1
            end
            sort(interactionsClass)
            self.interactionsClass = concat(interactionsClass)
            ReturnTable(interactionsClass)
        end
    end

    --Repair with all actors currently in interaction range.
    Flicker = function(self)
        if self.alreadyDestroyed then
            return
        end

        if not self.isGlobal then
            for key, __ in pairs(actorAlreadyChecked) do
                actorAlreadyChecked[key] = nil
            end
            actorAlreadyChecked[self] = true
            for X = self.minX, self.maxX do
                for Y = self.minY, self.maxY do
                    LeaveCell(CELL_LIST[X][Y], self)
                end
            end

            InitCells(self)

            if self.cellsVisualized then
                RedrawCellVisualizers(self)
            end
        end

        local selfFunc, actorFunc
        for __, actor in ipairs(self.usesCells and celllessActorList or actorList) do
            if not pairList[actor][self] and not pairList[self][actor] then
                selfFunc = GetInteractionFunc(self, actor)
                actorFunc = GetInteractionFunc(actor, self)
                if selfFunc and actorFunc then
                    if self.priority < actor.priority then
                        CreatePair(actor, self, actorFunc)
                    else
                        CreatePair(self, actor, selfFunc)
                    end
                elseif selfFunc then
                    CreatePair(self, actor, selfFunc)
                elseif actorFunc then
                    CreatePair(actor, self, actorFunc)
                end
            end
        end
    end

    SharesCellWith = function(self, actor)
        if self.halfWidth < actor.halfWidth then
            for cellA in pairs(self.isInCell) do
                if actor.isInCell[cellA] then
                    return true
                end
            end
            return false
        else
            for cellB in pairs(actor.isInCell) do
                if self.isInCell[cellB] then
                    return true
                end
            end
            return false
        end
    end

    CreateBinds = function(self, bindToBuff, bindToOrder)
        if bindToBuff then
            self.bindToBuff = type(bindToBuff) == "number" and bindToBuff or FourCC(bindToBuff)
            self.waitingForBuff = true
            insert(widgets.bindChecks, self)
        elseif bindToOrder then
            self.bindToOrder = type(bindToOrder) == "number" and bindToOrder or OrderId(bindToOrder)
            insert(widgets.bindChecks, self)
        end
        if HandleType[self.host] == "unit" then
            self.unit = self.host
        elseif HandleType[self.anchor] == "unit" then
            self.unit = self.anchor
        else
            Warning("|cffff0000Warning:|r Attempted to bind actor with identifier " .. Identifier2String(self.identifier) .. " to a buff or order, but that actor doesn't have a unit host or anchor.")
        end
    end

    DestroyObsoletePairs = function(self)
        if self.alreadyDestroyed then
            return
        end
        local actor
        local next = self.nextPair
        local pair = next[self.firstPair]
        local thisPair
        while pair do
            if pair[0x2] ~= SELF_INTERACTION_ACTOR then
                if self == pair[0x1] then
                    actor = pair[0x2]
                else
                    actor = pair[0x1]
                end
                if not actor.alreadyDestroyed and not GetInteractionFunc(self, actor) and not GetInteractionFunc(actor, self) then
                    thisPair = pair
                    pair = next[pair]
                    if not thisPair.destructionQueued then
                        thisPair.destructionQueued = true
                        AddDelayedCallback(DestroyPair, thisPair)
                    end
                else
                    pair = next[pair]
                end
            else
                pair = next[pair]
            end
        end
    end

    Unpause = function(self, whichFunctions)
        local actorA, actorB, nextStep
        local DO_NOT_EVALUATE = DO_NOT_EVALUATE
        local CYCLE_LENGTH = CYCLE_LENGTH

        local next = self.nextPair
        local pair = next[self.firstPair]
        while pair do
            if whichFunctions == nil or whichFunctions[pair[0x8]] then
                actorA = pair[0x1]
                actorB = pair[0x2]
                if pair[0x7] then
                    if pair[0x6] == nil and (not actorA.usesCells or not actorB.usesCells or SharesCellWith(actorA, actorB)) then
                        AddPairToEveryStepList(pair)
                    end
                else
                    if pair[0x5] == DO_NOT_EVALUATE and (not actorA.usesCells or not actorB.usesCells or SharesCellWith(actorA, actorB)) then
                        nextStep = cycle.counter + 1
                        if nextStep > CYCLE_LENGTH then
                            nextStep = nextStep - CYCLE_LENGTH
                        end

                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = pair
                        pair[0x5] = nextStep
                        pair[0x6] = numPairs[nextStep]
                    end
                end
                pair.paused = nil
            end
            pair = next[pair]
        end
    end

    SetStationary = function(self, enable)
        if (self.isStationary == true) == enable then
            return
        end
        self.isStationary = enable

        if enable then
            local nextCheck = self.nextCellCheck
            local actorAtHighestPosition = cellCheckedActors[nextCheck][numCellChecks[nextCheck]]
            actorAtHighestPosition.positionInCellCheck = self.positionInCellCheck
            cellCheckedActors[nextCheck][self.positionInCellCheck] = actorAtHighestPosition
            numCellChecks[nextCheck] = numCellChecks[nextCheck] - 1
            self.nextCellCheck = DO_NOT_EVALUATE
            local next = self.nextPair
            local thisPair = next[self.firstPair]
            while thisPair do
                if functionPauseOnStationary[thisPair[0x8]] and self == thisPair[0x1] then
                    AddDelayedCallback(PausePair, thisPair)
                end
                thisPair = next[thisPair]
            end
        else
            local nextStep = cycle.counter + 1
            if nextStep > CYCLE_LENGTH then
                nextStep = nextStep - CYCLE_LENGTH
            end
            numCellChecks[nextStep] = numCellChecks[nextStep] + 1
            cellCheckedActors[nextStep][numCellChecks[nextStep]] = self
            self.nextCellCheck = nextStep
            self.positionInCellCheck = numCellChecks[nextStep]
            AddDelayedCallback(Unpause, self, functionPauseOnStationary)
        end
        SetCoordinateFuncs(self)
    end

    ---For debug mode.
    VisualizeCells = function(self, enable)
        if enable == self.cellsVisualized then
            return
        end
        if self.cellsVisualized then
            self.cellsVisualized = false
            DestroyLightning(self.cellVisualizers[1])
            DestroyLightning(self.cellVisualizers[2])
            DestroyLightning(self.cellVisualizers[3])
            DestroyLightning(self.cellVisualizers[4])
        elseif not self.isGlobal then
            self.cellVisualizers = {}
            self.cellsVisualized = true
            local minx = CELL_MIN_X[self.minX]
            local miny = CELL_MIN_Y[self.minY]
            local maxx = CELL_MAX_X[self.maxX]
            local maxy = CELL_MAX_Y[self.maxY]
            self.cellVisualizers[1] = AddLightning("LEAS", false, maxx, miny, maxx, maxy)
            self.cellVisualizers[2] = AddLightning("LEAS", false, maxx, maxy, minx, maxy)
            self.cellVisualizers[3] = AddLightning("LEAS", false, minx, maxy, minx, miny)
            self.cellVisualizers[4] = AddLightning("LEAS", false, minx, miny, maxx, miny)
        end
    end

    ---For debug mode.
    RedrawCellVisualizers = function(self)
        local minx = CELL_MIN_X[self.minX]
        local miny = CELL_MIN_Y[self.minY]
        local maxx = CELL_MAX_X[self.maxX]
        local maxy = CELL_MAX_Y[self.maxY]
        MoveLightning(self.cellVisualizers[1], false, maxx, miny, maxx, maxy)
        MoveLightning(self.cellVisualizers[2], false, maxx, maxy, minx, maxy)
        MoveLightning(self.cellVisualizers[3], false, minx, maxy, minx, miny)
        MoveLightning(self.cellVisualizers[4], false, minx, miny, maxx, miny)
    end

    ---Called when an object is loaded into a transport actor crashes a thread.
    Suspend = function(self, enable)
        if enable then
            local pair
            for __, actor in ipairs(actorList) do
                pair = pairList[actor][self] or pairList[self][actor]
                if pair and not functionIsUnsuspendable[pair[0x8]] then
                    DestroyPair(pair)
                end
            end
            self.isSuspended = true
        else
            self.isSuspended = false
            AddDelayedCallback(Flicker, self)
        end
    end

    ---For debug mode.
    Deselect = function(self)
        debug.selectedActor = nil
        if not debug.visualizeAllActors then
            DestroyEffect(self.visualizer)
        end
        VisualizeCells(self, false)
        BlzFrameSetVisible(debug.tooltip, false)
    end

    GetMissingRequiredFieldsString = function(self, func, isMaleInFunc, isFemaleInFunc)
        local description = ""
        if functionRequiredFields[func] then
            local first = true
            if functionRequiredFields[func] then
                if isMaleInFunc and functionRequiredFields[func].male then
                    for field, value in pairs(functionRequiredFields[func].male) do
                        if not self.host[field] and (value == true or self.host[value]) then
                            if first then
                                first = false
                            else
                                description = description .. ", "
                            end
                            description = description .. field
                        end
                    end
                end
                if isFemaleInFunc and functionRequiredFields[func].female then
                    for field, value in pairs(functionRequiredFields[func].female) do
                        if not self.host[field] and (value == true or self.host[value]) then
                            if first then
                                first = false
                            else
                                description = description .. ", "
                            end
                            description = description .. field
                        end
                    end
                end
            end
        end
        return description
    end

    ---For debug mode.
    GetDescription = function(self)

        local description = setmetatable({}, {__add = function(old, new) old[#old + 1] = new return old end})

        description = description + "|cffffcc00Identifiers:|r "
        local first = true
        for key, __ in pairs(self.identifier) do
            if not first then
                description = description + ", "
            else
                first = false
            end
            description = description + key
        end

        if self.host ~= EMPTY_TABLE then
            description = description + "\n\n|cffffcc00Host:|r " + Object2String(self.host)
        end
        if self.originalAnchor ~= self.host then
            description = description + "\n|cffffcc00Anchor:|r " + Object2String(self.originalAnchor)
        end

        description = description + "\n|cffffcc00Interactions:|r "
        first = true
        for key, func in pairs(self.interactions) do
            if not first then
                description = description + ", "
            end
            if type(key) == "string" then
                description = description + key + " - " + Function2String(func)
            else
                local subFirst = true
                for __, word in ipairs(key) do
                    if not subFirst then
                        description = description + " + "
                    end
                    description = description + word
                    subFirst = false
                end
                description = description + " - " + Function2String(func)
            end
            first = false
        end

        if next(self.selfInteractions) then
            description = description + "\n|cffffcc00Self-Interactions:|r "
            first = true
            for key, __ in pairs(self.selfInteractions) do
                if not first then
                    description = description + ", "
                end
                first = false
                description = description + Function2String(key)
            end
        end

        if self.priority ~= 0 then
            description = description + "\n|cffffcc00Priority:|r " + self.priority
        end
        if self.zOffset ~= 0 then
            description = description + "\n|cffffcc00Z-Offset:|r " + self.zOffset
        end

        if self.cellCheckInterval and math.abs(self.cellCheckInterval*config.MIN_INTERVAL - config.DEFAULT_CELL_CHECK_INTERVAL) > 0.001 then
            description = description + "\n|cffffcc00Cell Check Interval:|r " + self.cellCheckInterval*config.MIN_INTERVAL
        end
        if self.isStationary then
            description = description + "\n|cffffcc00Stationary:|r true"
        end
        if not self.isGlobal and not self.usesCells then
            description = description + "\n|cffffcc00Has infinite range:|r true"
        end

        if self.halfWidth and self.halfWidth ~= config.DEFAULT_OBJECT_RADIUS then
            if self.halfWidth ~= self.halfHeight then
                description = description + "\n|cffffcc00Width:|r " + 2*self.halfWidth
                description = description + "\n|cffffcc00Height:|r " + 2*self.halfHeight
            else
                description = description + "\n|cffffcc00Radius:|r " + self.halfWidth
            end
        end

        if self.getOwner(self.host) then
            description = description + "\n|cffffcc00Owner:|r Player " + (GetPlayerId(self.getOwner(self.host)) + 1)
        end

        if self.bindToBuff then
            description = description + "\n|cffffcc00Bound to buff:|r " + string.pack(">I4", self.bindToBuff)
            if self.waitingForBuff then
                description = description + " |cffaaaaaa(waiting for buff to be applied)|r"
            end
        end

        if self.bindToOrder then
            description = description + "\n|cffffcc00Bound to order:|r " + OrderId2String(self.bindToOrder) + " |cffaaaaaa(current order = " + OrderId2String(GetUnitCurrentOrder(self.anchor)) + ")|r"
        end

        if self.onDestroy then
            description = description + "\n|cffffcc00On Destroy:|r " + Function2String(self.onDestroy)
        end

        description = description + "\n\n|cffffcc00Unique Number:|r " + self.unique
        local numOutgoing = 0
        local numIncoming = 0
        local hasError = false
        local outgoingFuncs = {}
        local incomingFuncs = {}
        local funcs = {}
        local isMaleInFunc = {}
        local isFemaleInFunc = {}

        local nextPair = self.nextPair
        local pair = nextPair[self.firstPair]
        while pair do
            if pair[0x2] ~= SELF_INTERACTION_ACTOR then
                if pair[0x1] == self then
                    numOutgoing = numOutgoing + 1
                    outgoingFuncs[pair[0x8]] = (outgoingFuncs[pair[0x8]] or 0) + 1
                elseif pair[0x2] == self then
                    numIncoming = numIncoming + 1
                    incomingFuncs[pair[0x8]] = (incomingFuncs[pair[0x8]] or 0) + 1
                else
                    hasError = true
                end
            end
            funcs[pair[0x8]] = true
            if pair[0x1] == self then
                isMaleInFunc[pair[0x8]] = true
            else
                isFemaleInFunc[pair[0x8]] = true
            end
            pair = nextPair[pair]
        end

        description = description + "\n|cffffcc00Outgoing pairs:|r " + numOutgoing
        if numOutgoing > 0 then
            first = true
            description = description + "|cffaaaaaa ("
            for key, number in pairs(outgoingFuncs) do
                if not first then
                    description = description + ", |r"
                end
                description = description + "|cffffcc00" + number + "|r |cffaaaaaa" + Function2String(key)
                first = false
            end
            description = description + ")|r"
        end
        description = description + "\n|cffffcc00Incoming pairs:|r " + numIncoming
        if numIncoming > 0 then
            first = true
            description = description + "|cffaaaaaa ("
            for key, number in pairs(incomingFuncs) do
                if not first then
                    description = description + ", |r"
                end
                description = description + "|cffffcc00" + number + "|r |cffaaaaaa" + Function2String(key)
                first = false
            end
            description = description + ")|r"
        end

        if not self.isGlobal then
            local x, y = self.x[self.anchor], self.y[self.anchor]
            description = description + "\n\n|cffffcc00x:|r " + x
            description = description + "\n|cffffcc00y:|r " + y
            description = description + "\n|cffffcc00z:|r " + self.z[self]
        end

        if hasError then
            description = description + "\n\n|cffff0000DESYNCED PAIR DETECTED!|r"
        end

        if self.causedCrash then
            description = description + "\n\n|cffff0000CAUSED CRASH!|r"
        end

        if type(self.host) == "table" then
            first = true
            local requiredFieldString
            for func, __ in pairs(funcs) do
                requiredFieldString = GetMissingRequiredFieldsString(self, func, isMaleInFunc[func], isFemaleInFunc[func])
                if requiredFieldString ~= "" then
                    if first then
                        description = description + "\n\n|cffff0000Missing required fields:|r"
                        first = false
                    end
                    description = description + "\n" + requiredFieldString +  " |cffaaaaaa(" + Function2String(func) + ")|r"
                end
            end
        end

        local str = concat(description)
        if self.isGlobal then
            return str, "|cff00bb00Global Actor|r"
        else
            if numOutgoing == 0 and numIncoming == 0 then
                return str, "|cffaaaaaaUnpaired Actor|r"
            elseif numOutgoing == 0 then
                return str, "|cffffc0cbFemale Actor|r"
            elseif numIncoming == 0 then
                return str, "|cff90b5ffMale Actor|r"
            else
                return str, "|cffffff00Hybrid Actor|r"
            end
        end
    end

    ---For debug mode.
    Select = function(self)
        debug.selectedActor = self
        local description, title = GetDescription(self)

        BlzFrameSetText(debug.tooltipText, description)
        BlzFrameSetText(debug.tooltipTitle, title )
        BlzFrameSetSize(debug.tooltipText, 0.28, 0.0)
        BlzFrameSetSize(debug.tooltip, 0.29, BlzFrameGetHeight(debug.tooltipText) + 0.0315)
        BlzFrameSetVisible(debug.tooltip, true)

        if not self.isGlobal then
            VisualizeCells(self, true)
            if not self.isGlobal and not debug.visualizeAllActors then
                CreateVisualizer(self)
            end
        end
    end

    ---For debug mode.
    CreateVisualizer = function(self)
        local x, y = self.x[self.anchor], self.y[self.anchor]
        self.visualizer = AddSpecialEffect("Abilities\\Spells\\Other\\Aneu\\AneuTarget.mdl", x, y)
        BlzSetSpecialEffectColorByPlayer(self.visualizer, self.getOwner(self.host) or Player(21))
        BlzSetSpecialEffectZ(self.visualizer, self.z[self] + 75)
    end
    --#endregion

    --Stub actors are used by periodic callers.
    CreateStub = function(host)
        local actor = GetUnusedActor()
        actor.host = host
        actor.anchor = host
        actor.isGlobal = true
        actor.x = coord.globalXYZ
        actor.y = coord.globalXYZ
        actor.z = coord.globalXYZ
        actor.unique = 0
        actor.alreadyDestroyed = nil
        actorOf[host] = actor
        return actor
    end

    DestroyStub = function(self)
        if self == nil or self.alreadyDestroyed then
            return
        end
        self.periodicPair = nil
        actorOf[self.host] = nil
        self.host = nil
        self.anchor = nil
        self.isGlobal = nil
        self.x = nil
        self.y = nil
        self.z = nil
        self.alreadyDestroyed = true
        unusedActors[#unusedActors + 1] = self
    end

    local SetFlag = {
        radius = function(self, radius)
            self.halfWidth = radius
            self.halfHeight = radius
            AddDelayedCallback(Flicker, self)
        end,
        anchor = function(self, anchor)
            if anchor == self.originalAnchor then
                return
            end
            for object, __ in pairs(self.references) do
                if object ~= self.host then
                    RemoveReference(self, object)
                end
            end

            if anchor then
                while type(anchor) == "table" and anchor.anchor do
                    CreateReference(self, anchor)
                    anchor = anchor.anchor
                end
                self.anchor = anchor
                self.originalAnchor = self.anchor
                CreateReference(self, anchor)
                SetCoordinateFuncs(self)
            else
                local oldAnchor = self.anchor
                self.anchor = self.host
                self.originalAnchor = self.anchor
                if type(self.host) == "table" then
                    self.host.x, self.host.y, self.host.z = ALICE_GetCoordinates3D(oldAnchor)
                end
                SetCoordinateFuncs(self)
            end
            AddDelayedCallback(Flicker, self)
        end,
        width = function(self, width)
            self.halfWidth = width/2
            AddDelayedCallback(Flicker, self)
        end,
        height = function(self, height)
            self.halfHeight = height/2
            AddDelayedCallback(Flicker, self)
        end,
        cellCheckInterval = function(self, cellCheckInterval)
            self.cellCheckInterval = min(MAX_STEPS, max(1, (cellCheckInterval*INV_MIN_INTERVAL) // 1 + 1))
        end,
        onActorDestroy = function(self, onActorDestroy)
            self.onActorDestroy = onActorDestroy
        end,
        isUnselectable = function(self, isUnselectable)
            self.isUnselectable = isUnselectable
        end,
        persistOnDeath = function(self, persistOnDeath)
            self.persistOnDeath = persistOnDeath
        end,
        priority = function(self, priority)
            self.priority = priority
        end,
        zOffset = function(self, zOffset)
            self.zOffset = zOffset
            self.z[self] = nil
        end,
        bindToBuff = function(self, buff)
            if self.bindToBuff then
                self.bindToBuff = type(buff) == "number" and buff or FourCC(buff)
            else
                CreateBinds(self, buff, nil)
            end
        end,
        bindToOrder = function(self, order)
            if self.bindToOrder then
                self.bindToorder = type(order) == "number" and order or OrderId(order)
            else
                CreateBinds(self, nil, order)
            end
        end
    }

    --===========================================================================================================================================================
    --Cell Class
    --===========================================================================================================================================================

    --#region Cell
    ---@class Cell
    local Cell = {
        horizontalLightning = nil,  ---@type lightning
        verticalLightning = nil,    ---@type lightning
        first = nil,                ---@type Actor
        last = nil,                 ---@type Actor
        numActors = nil             ---@type integer
    }

    EnterCell = function(self, actorA)
        local aFunc, bFunc

        actorA.isInCell[self] = true
        actorA.nextInCell[self] = nil
        actorA.previousInCell[self] = self.last

        if self.first == nil then
            self.first = actorA
        else
            self.last.nextInCell[self] = actorA
        end
        self.last = actorA

        if actorA.hasInfiniteRange then
            return
        end

        local DO_NOT_EVALUATE = DO_NOT_EVALUATE
        local CYCLE_LENGTH = CYCLE_LENGTH

        local actorB = self.first
        for __ = 1, self.numActors do
            if not actorAlreadyChecked[actorB] then
                actorAlreadyChecked[actorB] = true
                local thisPair = pairList[actorA][actorB] or pairList[actorB][actorA]
                if thisPair then
                    if not thisPair.paused then
                        if thisPair[0x7] then
                            if thisPair[0x6] == nil then
                                AddPairToEveryStepList(thisPair)
                            end
                        elseif thisPair[0x5] == DO_NOT_EVALUATE then
                            local nextStep
                            if functionDelay[0x8] then
                                local interactionFunc = thisPair[0x8]
                                if functionDelayIsDistributed[interactionFunc] then
                                    functionDelayCurrent[interactionFunc] = functionDelay[interactionFunc] + config.MIN_INTERVAL
                                    if functionDelayCurrent[interactionFunc] > functionDelay[interactionFunc] then
                                        functionDelayCurrent[interactionFunc] = functionDelayCurrent[interactionFunc] - functionDelay[interactionFunc]
                                    end
                                    nextStep = cycle.counter + (functionDelayCurrent[interactionFunc]*INV_MIN_INTERVAL + 1) // 1
                                else
                                    nextStep = cycle.counter + (functionDelay[interactionFunc]*INV_MIN_INTERVAL + 1) // 1
                                end
                            else
                                nextStep = cycle.counter + 1
                            end
                            if nextStep > CYCLE_LENGTH then
                                nextStep = nextStep - CYCLE_LENGTH
                            end

                            numPairs[nextStep] = numPairs[nextStep] + 1
                            whichPairs[nextStep][numPairs[nextStep]] = thisPair
                            thisPair[0x5] = nextStep
                            thisPair[0x6] = numPairs[nextStep]
                        end
                    end
                elseif not pairingExcluded[actorA][actorB] then
                    aFunc = GetInteractionFunc(actorA, actorB)
                    if aFunc then
                        if actorA.priority < actorB.priority then
                            bFunc = GetInteractionFunc(actorB, actorA)
                            if bFunc then
                                CreatePair(actorB, actorA, bFunc)
                            else
                                CreatePair(actorA, actorB, aFunc)
                            end
                        else
                            CreatePair(actorA, actorB, aFunc)
                        end
                    else
                        bFunc = GetInteractionFunc(actorB, actorA)
                        if bFunc then
                            CreatePair(actorB, actorA, bFunc)
                        end
                    end
                end
            end
            actorB = actorB.nextInCell[self]
        end

        self.numActors = self.numActors + 1
    end

    RemoveCell = function(self, actorA)
        if self.first == actorA then
            self.first = actorA.nextInCell[self]
        else
            actorA.previousInCell[self].nextInCell[self] = actorA.nextInCell[self]
        end
        if self.last == actorA then
            self.last = actorA.previousInCell[self]
        else
            actorA.nextInCell[self].previousInCell[self] = actorA.previousInCell[self]
        end

        actorA.isInCell[self] = nil
        self.numActors = self.numActors - 1
    end

    LeaveCell = function(self, actorA, wasLoaded)
        RemoveCell(self, actorA)

        if actorA.hasInfiniteRange then
            return
        end

        local DO_NOT_EVALUATE = DO_NOT_EVALUATE

        local actorB = self.first
        for __ = 1, self.numActors do
            if not actorAlreadyChecked[actorB] then
                actorAlreadyChecked[actorB] = true
                local thisPair = pairList[actorA][actorB] or pairList[actorB][actorA]
                if thisPair then
                    if thisPair[0x7] then
                        if thisPair[0x6] and (((actorA.maxX < actorB.minX or actorA.minX > actorB.maxX or actorA.maxY < actorB.minY or actorA.minY > actorB.maxY) and not functionIsUnbreakable[thisPair[0x8]]) or wasLoaded) and actorB.usesCells then
                            RemovePairFromEveryStepList(thisPair)

                            if thisPair.hadContact then
                                if functionOnReset[thisPair[0x8]] and not cycle.isCrash then
                                    local tempPair = currentPair
                                    currentPair = thisPair
                                    functionOnReset[thisPair[0x8]](thisPair[0x3], thisPair[0x4], thisPair.userData, false)
                                    currentPair = tempPair
                                end
                                thisPair.hadContact = nil
                            end
                            if functionOnBreak[thisPair[0x8]] then
                                local tempPair = currentPair
                                currentPair = thisPair
                                functionOnBreak[thisPair[0x8]](thisPair[0x3], thisPair[0x4], thisPair.userData, false)
                                currentPair = tempPair
                            end
                        end
                    elseif thisPair[0x5] ~= DO_NOT_EVALUATE and (actorA.maxX < actorB.minX or actorA.minX > actorB.maxX or actorA.maxY < actorB.minY or actorA.minY > actorB.maxY) and not functionIsUnbreakable[thisPair[0x8]] and actorB.usesCells then
                        whichPairs[thisPair[0x5]][thisPair[0x6]] = DUMMY_PAIR
                        local nextStep = DO_NOT_EVALUATE
                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = thisPair
                        thisPair[0x5] = nextStep
                        thisPair[0x6] = numPairs[nextStep]

                        if thisPair.hadContact then
                            if functionOnReset[thisPair[0x8]] and not cycle.isCrash then
                                local tempPair = currentPair
                                currentPair = thisPair
                                functionOnReset[thisPair[0x8]](thisPair[0x3], thisPair[0x4], thisPair.userData, false)
                                currentPair = tempPair
                            end
                            thisPair.hadContact = nil
                        end
                        if functionOnBreak[thisPair[0x8]] then
                            local tempPair = currentPair
                            currentPair = thisPair
                            functionOnBreak[thisPair[0x8]](thisPair[0x3], thisPair[0x4], thisPair.userData, false)
                            currentPair = tempPair
                        end
                    end
                end
            end
            actorB = actorB.nextInCell[self]
        end
    end
    --#endregion

    --===========================================================================================================================================================
    --Repair
    --===========================================================================================================================================================

    --#region Repair

    local function PrintCrashMessage(crashingPairOrCallback, A, B)
        local warning
        if A then
            if B == SELF_INTERACTION_ACTOR then
                if A.periodicPair then
                    warning = "\n|cffff0000Error:|r ALICE Cycle crashed during last execution. The crash occured during a periodic callback with function |cffaaaaff" .. Function2String(crashingPairOrCallback[0x8]) .. "|r. The interaction has been disabled."
                else
                    warning = "\n|cffff0000Error:|r ALICE Cycle crashed during last execution. The identifier of the actor responsible is "
                    .. "|cffffcc00" .. Identifier2String(A.identifier) .. "|r. Unique number: " .. A.unique .. ". The crash occured during self-interaction with function |cffaaaaff" .. Function2String(crashingPairOrCallback[0x8]) .. "|r. The interaction has been disabled."
                end
            else
                warning = "\n|cffff0000Error:|r ALICE Cycle crashed during last execution. The identifiers of the actors responsible are "
                .. "|cffffcc00" .. Identifier2String(A.identifier) .. "|r and |cffaaaaff" .. Identifier2String(B.identifier) .. "|r. Unique numbers: " .. A.unique .. ", " .. B.unique .. ". The pair has been removed from the cycle."
            end

            if type(A.host) == "table" then
                local requiredFieldString = GetMissingRequiredFieldsString(A, crashingPairOrCallback[0x8], true, false)
                if requiredFieldString ~= "" then
                    warning = warning .. "\n\nThere are one or more |cffff0000required fields missing|r for the interaction function in the host table of actor " .. A.unique .. ":\n|cffaaaaff" .. requiredFieldString .. "|r"
                end
            end
            if type(B.host) == "table" then
                local requiredFieldString = GetMissingRequiredFieldsString(B, crashingPairOrCallback[0x8], false, true)
                if requiredFieldString ~= "" then
                    warning = warning .. "\n\nThere are one or more |cffff0000required fields missing|r for the interaction function in the host table of actor " .. B.unique .. ":\n|cffaaaaff" .. requiredFieldString .. "|r"
                end
            end
        else
            warning = "\n|cffff0000Error:|r ALICE Cycle crashed during last execution. The crash occured during a delayed callback with function |cffaaaaff" .. Function2String(crashingPairOrCallback.callback) .. "|r."
        end

        Warning(warning)
    end
    --#endregion

    --===========================================================================================================================================================
    --Main Functions
    --===========================================================================================================================================================

    --#region Main Functions
    local function ResetCoordinateLookupTables()
        local classX, classY = coord.classX, coord.classY
        for key, __ in pairs(classX) do
            classX[key], classY[key] = nil, nil
        end
        local classZ = coord.classZ
        for key, __ in pairs(classZ) do
            classZ[key] = nil
        end
        local unitX, unitY = coord.unitX, coord.unitY
        for key, __ in pairs(unitX) do
            unitX[key], unitY[key] = nil, nil
        end
        local unitZ = coord.unitZ
        for key, __ in pairs(unitZ) do
            unitZ[key] = nil
        end
        if not config.ITEMS_ARE_STATIONARY then
            local itemX, itemY = coord.itemX, coord.itemY
            for key, __ in pairs(itemX) do
                itemX[key], itemY[key] = nil, nil
            end
            local itemZ = coord.itemZ
            for key, __ in pairs(itemZ) do
                itemZ[key] = nil
            end
        end
        local terrainZ = coord.terrainZ
        for key, __ in pairs(terrainZ) do
            terrainZ[key] = nil
        end
    end

    local function BindChecks()
        for i = #widgets.bindChecks, 1, -1 do
            local actor = widgets.bindChecks[i]

            if actor.bindToBuff then
                if actor.waitingForBuff then
                    if GetUnitAbilityLevel(actor.unit, FourCC(actor.bindToBuff)) > 0 then
                        actor.waitingForBuff = nil
                    end
                elseif GetUnitAbilityLevel(actor.unit, FourCC(actor.bindToBuff)) == 0 then
                    Destroy(actor)
                    widgets.bindChecks[i] = widgets.bindChecks[#widgets.bindChecks]
                    widgets.bindChecks[#widgets.bindChecks] = nil
                end
            elseif actor.bindToOrder then
                if GetUnitCurrentOrder(actor.unit) ~= actor.bindToOrder then
                    Destroy(actor)
                    widgets.bindChecks[i] = widgets.bindChecks[#widgets.bindChecks]
                    widgets.bindChecks[#widgets.bindChecks] = nil
                end
            end
        end
    end

    ---All destroyed pairs are only flagged and not destroyed until main cycle completes. This function destroys all pairs in one go.
    local function RemovePairsFromCycle()
        for i = #destroyedActors, 1, -1 do
            local actor = destroyedActors[i]
            if actor then
                local firstPair = actor.firstPair
                local thisPair = actor.lastPair
                while thisPair ~= firstPair do
                    DestroyPair(thisPair)
                    thisPair = actor.lastPair
                end
                Release(actor)
            end
            destroyedActors[i] = nil
        end
    end

    local function CellCheck()
        local x, y
        local minx, miny, maxx, maxy
        local changedCells
        local newMinX, newMinY, newMaxX, newMaxY
        local oldMinX, oldMinY, oldMaxX, oldMaxY
        local halfWidth, halfHeight
        local actor
        local currentCounter = cycle.counter
        local actorsThisStep = cellCheckedActors[currentCounter]
        local nextStep
        local CYCLE_LENGTH = CYCLE_LENGTH

        for i = 1, numCellChecks[currentCounter] do
            actor = actorsThisStep[i]

            x = actor.x[actor.anchor]
            y = actor.y[actor.anchor]
            halfWidth = actor.halfWidth
            halfHeight = actor.halfHeight
            minx = x - halfWidth
            miny = y - halfHeight
            maxx = x + halfWidth
            maxy = y + halfHeight

            newMinX = actor.minX
            newMinY = actor.minY
            newMaxX = actor.maxX
            newMaxY = actor.maxY

            if x > actor.lastX then
                while minx > CELL_MAX_X[newMinX] and newMinX < NUM_CELLS_X do
                    changedCells = true
                    newMinX = newMinX + 1
                end
                while maxx > CELL_MAX_X[newMaxX] and newMaxX < NUM_CELLS_X do
                    changedCells = true
                    newMaxX = newMaxX + 1
                end
            else
                while minx < CELL_MIN_X[newMinX] and newMinX > 1 do
                    changedCells = true
                    newMinX = newMinX - 1
                end
                while maxx < CELL_MIN_X[newMaxX] and newMaxX > 1 do
                    changedCells = true
                    newMaxX = newMaxX - 1
                end
            end
            if y > actor.lastY then
                while miny > CELL_MAX_Y[newMinY] and newMinY < NUM_CELLS_Y do
                    changedCells = true
                    newMinY = newMinY + 1
                end
                while maxy > CELL_MAX_Y[newMaxY] and newMaxY < NUM_CELLS_Y do
                    changedCells = true
                    newMaxY = newMaxY + 1
                end
            else
                while miny < CELL_MIN_Y[newMinY] and newMinY > 1 do
                    changedCells = true
                    newMinY = newMinY - 1
                end
                while maxy < CELL_MIN_Y[newMaxY] and newMaxY > 1 do
                    changedCells = true
                    newMaxY = newMaxY - 1
                end
            end

            if changedCells then
                oldMinX = actor.minX
                oldMinY = actor.minY
                oldMaxX = actor.maxX
                oldMaxY = actor.maxY
                actor.minY = newMinY
                actor.maxX = newMaxX
                actor.maxY = newMaxY

                for key, __ in pairs(actorAlreadyChecked) do
                    actorAlreadyChecked[key] = nil
                end
                actorAlreadyChecked[actor] = true

                if newMinX > oldMinX then
                    actor.minX = newMinX
                    for X = oldMinX, newMinX - 1 < oldMaxX and newMinX - 1 or oldMaxX do
                        for Y = oldMinY, oldMaxY do
                            LeaveCell(CELL_LIST[X][Y], actor)
                        end
                    end
                elseif newMinX < oldMinX then
                    actor.minX = newMinX
                    for X = newMinX, newMaxX < oldMinX - 1 and newMaxX or oldMinX  - 1 do
                        for Y = newMinY, newMaxY do
                            EnterCell(CELL_LIST[X][Y], actor)
                        end
                    end
                end

                if newMaxX > oldMaxX then
                    for X = oldMaxX + 1 > newMinX and oldMaxX + 1 or newMinX, newMaxX do
                        for Y = newMinY, newMaxY do
                            EnterCell(CELL_LIST[X][Y], actor)
                        end
                    end
                elseif newMaxX < oldMaxX then
                    for X = newMaxX + 1 > oldMinX and newMaxX + 1 or oldMinX , oldMaxX do
                        for Y = oldMinY, oldMaxY do
                            LeaveCell(CELL_LIST[X][Y], actor)
                        end
                    end
                end

                if newMinY > oldMinY then
                    for Y = oldMinY, newMinY - 1 < oldMaxY and newMinY - 1 or oldMaxY do
                        for X = oldMinX > newMinX and oldMinX or newMinX, oldMaxX < newMaxX and oldMaxX or newMaxX do
                            LeaveCell(CELL_LIST[X][Y], actor)
                        end
                    end
                elseif newMinY < oldMinY then
                    for Y = newMinY, newMaxY < oldMinY - 1 and newMaxY or oldMinY  - 1 do
                        for X = oldMinX > newMinX and oldMinX or newMinX, oldMaxX < newMaxX and oldMaxX or newMaxX do
                            EnterCell(CELL_LIST[X][Y], actor)
                        end
                    end
                end

                if newMaxY > oldMaxY then
                    for Y = oldMaxY + 1 > newMinY and oldMaxY + 1 or newMinY, newMaxY do
                        for X = oldMinX > newMinX and oldMinX or newMinX, oldMaxX < newMaxX and oldMaxX or newMaxX do
                            EnterCell(CELL_LIST[X][Y], actor)
                        end
                    end
                elseif newMaxY < oldMaxY then
                    for Y = newMaxY + 1 > oldMinY and newMaxY + 1 or oldMinY , oldMaxY do
                        for X = oldMinX > newMinX and oldMinX or newMinX, oldMaxX < newMaxX and oldMaxX or newMaxX do
                            LeaveCell(CELL_LIST[X][Y], actor)
                        end
                    end
                end

                if actor.cellsVisualized then
                    RedrawCellVisualizers(actor)
                end

                changedCells = false
            end

            actor.lastX, actor.lastY = x, y

            nextStep = currentCounter + actor.cellCheckInterval
            if nextStep > CYCLE_LENGTH then
                nextStep = nextStep - CYCLE_LENGTH
            end

            numCellChecks[nextStep] = numCellChecks[nextStep] + 1
            cellCheckedActors[nextStep][numCellChecks[nextStep]] = actor
            actor.nextCellCheck = nextStep
            actor.positionInCellCheck = numCellChecks[nextStep]
        end

        if debug.visualizeAllActors then
            for i = 1, numCellChecks[currentCounter] do
                actor = actorsThisStep[i]
                BlzSetSpecialEffectPosition(actor.visualizer, actor.x[actor.anchor], actor.y[actor.anchor], actor.z[actor] + 75)
            end
        end

        numCellChecks[currentCounter] = 0
    end

    local function Interpolate()
        interpolationCounter = interpolationCounter + 1
        if interpolationCounter == 1 then
            return
        end

        local actor, anchor
        isInterpolated = true

        RemovePairsFromCycle()

        if currentPair ~= OUTSIDE_OF_CYCLE then
            return
        end

        for i = 1, #interpolatedPairs do
            currentPair = interpolatedPairs[i]

            if not currentPair.destructionQueued then
                actor = currentPair[0x1]
                if actor.x then
                    anchor = actor.anchor
                    actor.x[anchor] = nil
                    actor.y[anchor] = nil
                    actor.z[actor] = nil
                end

                actor = currentPair[0x2]
                if actor.x then
                    anchor = actor.anchor
                    actor.x[anchor] = nil
                    actor.y[anchor] = nil
                    actor.z[actor] = nil
                end

                currentPair[0x8](currentPair[0x3], currentPair[0x4], true)
            end
        end
        isInterpolated = false
        currentPair = OUTSIDE_OF_CYCLE
    end
    --#endregion

    --===========================================================================================================================================================
    --Main
    --===========================================================================================================================================================

    --#region Main
    local function Main(nextStep)
        local INV_MIN_INTERVAL = INV_MIN_INTERVAL
        local CYCLE_LENGTH = CYCLE_LENGTH
        local MAX_STEPS = MAX_STEPS
        local evalCounter = cycle.unboundCounter - (cycle.unboundCounter // 10)*10 + 1
        local startTime = os.clock()
        local crashingPairOrCallback, crashingActorA, crashingActorB, success, err

        interpolationCounter = 0
        for i = 1, #interpolatedPairs do
            interpolatedPairs[i] = nil
        end

        if ALICE_Where ~= "outsideofcycle" then
            if debug.lastCoroutine and coroutine.status(debug.lastCoroutine) == "suspended" then
                local tries = 0
                while ALICE_Where ~= "outsideofcycle" and coroutine.status(debug.lastCoroutine) ~= "dead" do
                    coroutine.resume(debug.lastCoroutine)
                    if tries > 100 then
                        error("Cannot resume ALICE as the previous step's thread was halted and is unable to be resumed.")
                    end
                end
            else
                if currentPair ~= OUTSIDE_OF_CYCLE then
                    local A = currentPair[0x1]
                    local B = currentPair[0x2]
                    PrintCrashMessage(currentPair, A, B)
                elseif ALICE_Where == "callbacks" then
                    PrintCrashMessage(userCallbacks.first)
                else
                    Warning("\n|cffff0000Error:|r ALICE Cycle crashed during last execution. The crash occured during " .. ALICE_Where .. ".")
                end

                ALICE_Halt()
                if not debug.enabled then
                    EnableDebugMode()
                end
                if ALICE_Where == "callbacks" then
                    RemoveUserCallbackFromList(userCallbacks.first)
                end
                ALICE_Where = "outsideofcycle"
                return
            end
        end
        debug.lastCoroutine = coroutine.running()

        ALICE_Where = "precleanup"

        --First-in first-out.
        local k = 1
        while delayedCallbackFunctions[k] do
            delayedCallbackFunctions[k](unpack(delayedCallbackArgs[k]))
            k = k + 1
        end
        for i = 1, #delayedCallbackFunctions do
            delayedCallbackFunctions[i] = nil
        end

        BindChecks()
        RemovePairsFromCycle()

        cycle.unboundCounter = cycle.unboundCounter + 1
        ALICE_TimeElapsed = cycle.unboundCounter*config.MIN_INTERVAL

        ALICE_Where = "callbacks"

        if ALICE_Config.PROCTECTED_MODE then
            while userCallbacks.first and userCallbacks.first.callCounter == cycle.unboundCounter do
                success, err = pcall(ExecuteUserCallback, userCallbacks.first)
                if not success then
                    if Debug then
                        Debug.throwError(err)
                    end
                    if not crashingPairOrCallback then
                        crashingPairOrCallback = userCallbacks.first
                    end
                    RemoveUserCallbackFromList(userCallbacks.first)
                end
            end
        else
            while userCallbacks.first and userCallbacks.first.callCounter == cycle.unboundCounter do
                ExecuteUserCallback(userCallbacks.first)
            end
        end

        if cycle.isHalted and not nextStep then
            ALICE_Where = "outsideofcycle"
            return
        end

        --Must be after callbacks.
        cycle.counter = cycle.counter + 1
        if cycle.counter > CYCLE_LENGTH then
            cycle.counter = 1
        end
        local currentCounter = cycle.counter

        for i = 1, #debug.visualizationLightnings do
            local lightning = debug.visualizationLightnings[i]
            TimerStart(CreateTimer(), 0.02, false, function()
                DestroyTimer(GetExpiredTimer())
                DestroyLightning(lightning)
            end)
            debug.visualizationLightnings[i] = nil
        end

        if debug.benchmark then
            local averageEvalTime = 0
            for i = 1, 10 do
                averageEvalTime = averageEvalTime + (debug.evaluationTime[i] or 0)/10
            end
            Warning("eval time: |cffffcc00" .. string.format("\x25.2f", 1000*averageEvalTime) .. "ms|r, actors: " .. #actorList .. ", pairs: " .. numPairs[currentCounter] + numEveryStepPairs .. ", cell checks: " .. numCellChecks[currentCounter])
        end

        if debug.enabled then
            UpdateSelectedActor()
        end

        local numSteps, nextStep

        ALICE_Where = "everystep"

        --Every Step Cycle
        currentPair = firstEveryStepPair
        if ALICE_Config.PROCTECTED_MODE then
            local pairsToRemove
            for __ = 1, numEveryStepPairs do
                currentPair = currentPair[0x5]
                if not currentPair.destructionQueued then
                    success, err = pcall(currentPair[0x8], currentPair[0x3], currentPair[0x4])
                    if not success then
                        if not crashingPairOrCallback then
                            crashingPairOrCallback = currentPair
                            crashingActorA = currentPair[0x1]
                            crashingActorB = currentPair[0x2]
                        end
                        pairsToRemove = pairsToRemove or {}
                        pairsToRemove[#pairsToRemove + 1] = currentPair
                    end
                end
            end
            if pairsToRemove then
                for i = 1, #pairsToRemove do
                    RemovePairFromEveryStepList(pairsToRemove[i])
                    if pairsToRemove[i][0x2] ~= SELF_INTERACTION_ACTOR then
                        pairingExcluded[pairsToRemove[i]][0x1][0x2] = true
                        pairingExcluded[pairsToRemove[i]][0x2][0x1] = true
                    end
                end
            end
        else
            for __ = 1, numEveryStepPairs do
                currentPair = currentPair[0x5]
                if not currentPair.destructionQueued then
                    currentPair[0x8](currentPair[0x3], currentPair[0x4])
                end
            end
        end

        ALICE_Where = "cellcheck"

        ResetCoordinateLookupTables()
        CellCheck()

        ALICE_Where = "variablestep"

        --Variable Step Cycle
        local returnValue
        local pairsThisStep = whichPairs[currentCounter]
        if ALICE_Config.PROCTECTED_MODE then
            for i = 1, numPairs[currentCounter] do
                currentPair = pairsThisStep[i]
                if currentPair.destructionQueued then
                    if currentPair ~= DUMMY_PAIR then
                        nextStep = currentCounter + MAX_STEPS
                        if nextStep > CYCLE_LENGTH then
                            nextStep = nextStep - CYCLE_LENGTH
                        end

                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = currentPair
                        currentPair[0x5] = nextStep
                        currentPair[0x6] = numPairs[nextStep]
                    end
                else
                    success, returnValue = pcall(currentPair[0x8], currentPair[0x3], currentPair[0x4])
                    if not success then
                        err = returnValue
                        if not crashingPairOrCallback then
                            crashingPairOrCallback = currentPair
                            crashingActorA = currentPair[0x1]
                            crashingActorB = currentPair[0x2]
                        end
                        currentPair[0x5] = DO_NOT_EVALUATE
                    elseif returnValue then
                        numSteps = (returnValue*INV_MIN_INTERVAL + 1) // 1 --convert seconds to steps, then ceil.
                        if numSteps < 1 then
                            numSteps = 1
                        elseif numSteps > MAX_STEPS then
                            numSteps = MAX_STEPS
                        end

                        nextStep = currentCounter + numSteps
                        if nextStep > CYCLE_LENGTH then
                            nextStep = nextStep - CYCLE_LENGTH
                        end

                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = currentPair
                        currentPair[0x5] = nextStep
                        currentPair[0x6] = numPairs[nextStep]
                    else
                        AddPairToEveryStepList(currentPair)
                        if currentPair[0x8] ~= PeriodicWrapper and currentPair[0x8] ~= RepeatedWrapper then
                            functionIsEveryStep[currentPair[0x8]] = true
                        end
                        currentPair[0x7] = true
                    end
                end
            end
        else
            for i = 1, numPairs[currentCounter] do
                currentPair = pairsThisStep[i]
                if currentPair.destructionQueued then
                    if currentPair ~= DUMMY_PAIR then
                        nextStep = currentCounter + MAX_STEPS
                        if nextStep > CYCLE_LENGTH then
                            nextStep = nextStep - CYCLE_LENGTH
                        end

                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = currentPair
                        currentPair[0x5] = nextStep
                        currentPair[0x6] = numPairs[nextStep]
                    end
                else
                    returnValue = currentPair[0x8](currentPair[0x3], currentPair[0x4])
                    if returnValue then
                        numSteps = (returnValue*INV_MIN_INTERVAL + 1) // 1 --convert seconds to steps, then ceil.
                        if numSteps < 1 then
                            numSteps = 1
                        elseif numSteps > MAX_STEPS then
                            numSteps = MAX_STEPS
                        end

                        nextStep = currentCounter + numSteps
                        if nextStep > CYCLE_LENGTH then
                            nextStep = nextStep - CYCLE_LENGTH
                        end

                        numPairs[nextStep] = numPairs[nextStep] + 1
                        whichPairs[nextStep][numPairs[nextStep]] = currentPair
                        currentPair[0x5] = nextStep
                        currentPair[0x6] = numPairs[nextStep]
                    else
                        AddPairToEveryStepList(currentPair)
                        if currentPair[0x8] ~= PeriodicWrapper and currentPair[0x8] ~= RepeatedWrapper then
                            functionIsEveryStep[currentPair[0x8]] = true
                        end
                        currentPair[0x7] = true
                    end
                end
            end
        end

        numPairs[currentCounter] = 0

        currentPair = OUTSIDE_OF_CYCLE

        ALICE_Where = "postcleanup"

        k = 1
        while delayedCallbackFunctions[k] do
            delayedCallbackFunctions[k](unpack(delayedCallbackArgs[k]))
            k = k + 1
        end
        for i = 1, #delayedCallbackFunctions do
            delayedCallbackFunctions[i] = nil
        end

        local endTime = os.clock()
        debug.evaluationTime[evalCounter] = endTime - startTime
        ALICE_CPULoad = (endTime - startTime)/config.MIN_INTERVAL

        ALICE_Where = "outsideofcycle"

        if crashingPairOrCallback then
            if not debug.errors[err] then
                PrintCrashMessage(crashingPairOrCallback, crashingActorA, crashingActorB)
                error(err, 0)
                debug.errors[err] = true
            end
        end
    end
    --#endregion

       --===========================================================================================================================================================
    --Debug Mode
    --===========================================================================================================================================================

    ---@param whichPair Pair
    ---@param lightningType string
    VisualizationLightning = function(whichPair, lightningType)
        local A = whichPair[0x1]
        local B = whichPair[0x2]

        if A.alreadyDestroyed or B.alreadyDestroyed or A.isGlobal or B.isGlobal then
            return
        end

        local xa = A.x[A.anchor]
        local ya = A.y[A.anchor]
        local za = A.z[A]
        local xb = B.x[B.anchor]
        local yb = B.y[B.anchor]
        local zb = B.z[B]

        if za and zb then
            insert(debug.visualizationLightnings, AddLightningEx(lightningType, true, xa, ya, za, xb, yb, zb))
        else
            insert(debug.visualizationLightnings, AddLightning(lightningType, true, xa, ya, xb, yb))
        end
    end

    UpdateSelectedActor = function()
        if debug.selectedActor then
            if not debug.selectedActor.isGlobal then
                local x = debug.selectedActor.x[debug.selectedActor.anchor]
                local y = debug.selectedActor.y[debug.selectedActor.anchor]
                BlzSetSpecialEffectPosition(debug.selectedActor.visualizer, x, y, debug.selectedActor.z[debug.selectedActor] + 75)

                SetCameraQuickPosition(x, y)
            end

            local description, title = GetDescription(debug.selectedActor)
            BlzFrameSetText(debug.tooltipText, description)
            BlzFrameSetText(debug.tooltipTitle, title )
            BlzFrameSetSize(debug.tooltipText, 0.28, 0.0)
            BlzFrameSetSize(debug.tooltip, 0.29, BlzFrameGetHeight(debug.tooltipText) + 0.0315)

            local funcs = {}
            local next = debug.selectedActor.nextPair
            local pair = next[debug.selectedActor.firstPair]
            while pair do
                if (pair[0x7] and pair[0x6] ~= nil) or (not pair[0x7] and pair[0x5] == cycle.counter) then
                    VisualizationLightning(pair, "DRAL")
                    if debug.printFunctionNames then
                        funcs[pair[0x8]] = (funcs[pair[0x8]] or 0) + 1
                    end
                end
                pair = next[pair]
            end

            if debug.printFunctionNames then
                local first = true
                local message
                for func, amount in pairs(funcs) do
                    if first then
                        message = "\n|cffffcc00Step " .. cycle.unboundCounter .. ":|r"
                        first = false
                    end
                    if amount > 1 then
                        message = message .. "\n" .. Function2String(func) .. " |cffaaaaffx" .. amount .. "|r"
                    else
                        message = message .. "\n" .. Function2String(func)
                    end
                end
                if message then
                    Warning(message)
                end
            end
        end
    end

    ---@param x number
    ---@param y number
    ---@param z number
    ---@return number, number
    local function World2Screen(eyeX, eyeY, eyeZ, angleOfAttack, x, y, z)
        local cosAngle = math.cos(angleOfAttack)
        local sinAngle = math.sin(angleOfAttack)

        local dx = x - eyeX
        local dy = y - eyeY
        local dz = (z or 0) - eyeZ

        local yPrime = cosAngle*dy - sinAngle*dz
        local zPrime = sinAngle*dy + cosAngle*dz

        return 0.4 + 0.7425*dx/yPrime, 0.355 + 0.7425*zPrime/yPrime
    end

    --#region Debug Mode
    local function OnMouseClick()
        if debug.selectionLocked or BlzGetTriggerPlayerMouseButton() ~= MOUSE_BUTTON_TYPE_LEFT or not debug.controlIsPressed then
            return
        end

        local previousSelectedActor = debug.selectedActor
        if debug.selectedActor then
            Deselect(debug.selectedActor)
        end

        local mouseX = BlzGetTriggerPlayerMouseX()
        local mouseY = BlzGetTriggerPlayerMouseY()
        local objects = ALICE_EnumObjectsInRange(mouseX, mouseY, 500, {MATCHING_TYPE_ALL}, nil)
        local closestDist = 0.04
        local closestObject = nil

        local eyeX = GetCameraEyePositionX()
        local eyeY = GetCameraEyePositionY()
        local eyeZ = GetCameraEyePositionZ()
        local angleOfAttack = -GetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK)

        local mouseScreenX, mouseScreenY = World2Screen(eyeX, eyeY, eyeZ, angleOfAttack, mouseX, mouseY, GetTerrainZ(mouseX, mouseY))

        local x, y, dx, dy
        for __, object in ipairs(objects) do
            local actor = GetActor(object)
            --Find the actor that is closest to the mouse-cursor.
            if not actor.isUnselectable and (previousSelectedActor == nil or ALICE_GetAnchor(object) ~= previousSelectedActor.anchor) then
                x, y = World2Screen(eyeX, eyeY, eyeZ, angleOfAttack, ALICE_GetCoordinates3D(actor))
                dx, dy = x - mouseScreenX, y - mouseScreenY
                local dist = sqrt(dx*dx + dy*dy)
                if dist < closestDist then
                    closestDist = dist
                    closestObject = actor.anchor
                end
            end
        end

        if closestObject then
            if actorOf[closestObject].isActor then
                Select(actorOf[closestObject])
            else
                Warning("Multiple actors are anchored to this object. Press |cffffcc00Ctrl + " .. ALICE_Config.CYCLE_SELECTION_HOTKEY .. "|r to cycle through.")
                Select(actorOf[closestObject][1])
            end
        end
    end

    local function OnCtrlR()
        Warning("Going to step " .. cycle.unboundCounter + 1 .. " |cffaaaaaa(" .. string.format("\x25.2f", config.MIN_INTERVAL*(cycle.unboundCounter + 1)) .. "s)|r.")
        Main(true)
        if debug.gameIsPaused then
            ALICE_ForAllObjectsDo(function(unit) PauseUnit(unit, true) end, "unit")
        end
    end

    local function OnCtrlG()
        if debug.printFunctionNames then
            Warning("\nPrinting function names disabled.")
        else
            Warning("\nPrinting function names enabled.")
        end
        debug.printFunctionNames = not debug.printFunctionNames
    end

    local function OnCtrlW()
        if debug.selectionLocked then
            Warning("\nSelection unlocked.")
        else
            Warning("\nSelection locked. To unlock, press |cffffcc00Ctrl + " .. ALICE_Config.LOCK_SELECTION_HOTKEY .. "|r.")
        end
        debug.selectionLocked = not debug.selectionLocked
    end

    ---Cycle through actors anchored to the same object.
    local function OnCtrlQ()
        if debug.selectedActor == nil then
            return
        end
        local selectedObject = debug.selectedActor.anchor
        if actorOf[selectedObject].isActor then
            return
        end
        for index, actor in ipairs(actorOf[selectedObject]) do
            if debug.selectedActor == actor then
                Deselect(debug.selectedActor)
                if actorOf[selectedObject][index + 1] then
                    Select(actorOf[selectedObject][index + 1])
                    return
                else
                    Select(actorOf[selectedObject][1])
                    return
                end
            end
        end
    end

    local function OnCtrlT()
        if cycle.isHalted then
            ALICE_Resume()
            Warning("\nALICE Cycle resumed.")
        else
            ALICE_Halt(BlzGetTriggerPlayerMetaKey() == 3)
            Warning("\nALICE Cycle halted. To go to the next step, press |cffffcc00Ctrl + " .. ALICE_Config.HALT_CYCLE_HOTKEY .. "|r. To resume, press |cffffcc00Ctrl + T|r.")
        end
    end

    local function DownTheRabbitHole()
        EnableDebugMode()
        if debug.enabled then
            Warning("\nDebug mode enabled. Left-click near an actor to display attributes and enable visualization.")
        else
            Warning("\nDebug mode has been disabled.")
        end
    end

    EnableDebugMode = function()
        local playerName = GetPlayerName(GetTriggerPlayer())
        local nameFound = false
        for __, name in ipairs(config.MAP_CREATORS) do
            if string.find(playerName, name) then
                nameFound = true
                break
            end
        end

        if not nameFound then
            if GetLocalPlayer() == GetTriggerPlayer() then
                print("|cffff0000Warning:|r You need to set yourself as a map creator in the ALICE config to use debug mode.")
            end
            return
        end

        if not debug.enabled then
            debug.enabled = true
            BlzLoadTOCFile("CustomTooltip.toc")
            debug.tooltip = BlzCreateFrame("CustomTooltip", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), 0, 0)
            BlzFrameSetAbsPoint(debug.tooltip, FRAMEPOINT_BOTTOMRIGHT, 0.8, 0.165)
            BlzFrameSetSize(debug.tooltip, 0.32, 0.0)
            debug.tooltipTitle = BlzGetFrameByName("CustomTooltipTitle", 0)
            debug.tooltipText = BlzGetFrameByName("CustomTooltipValue", 0)

            debug.nextStepTrigger = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(debug.nextStepTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.NEXT_STEP_HOTKEY], 2, true)
            TriggerAddAction(debug.nextStepTrigger, OnCtrlR)

            debug.mouseClickTrigger = CreateTrigger()
            TriggerRegisterPlayerEvent(debug.mouseClickTrigger, GetTriggerPlayer() or Player(0), EVENT_PLAYER_MOUSE_DOWN)
            TriggerAddAction(debug.mouseClickTrigger, OnMouseClick)

            debug.lockSelectionTrigger = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(debug.lockSelectionTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.LOCK_SELECTION_HOTKEY], 2, true)
            TriggerAddAction(debug.lockSelectionTrigger, OnCtrlW)

            debug.cycleSelectTrigger = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(debug.cycleSelectTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.CYCLE_SELECTION_HOTKEY], 2, true)
            TriggerAddAction(debug.cycleSelectTrigger, OnCtrlQ)

            debug.haltTrigger = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(debug.haltTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.HALT_CYCLE_HOTKEY], 2, true)
            BlzTriggerRegisterPlayerKeyEvent(debug.haltTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.HALT_CYCLE_HOTKEY], 3, true)
            TriggerAddAction(debug.haltTrigger, OnCtrlT)

            debug.printFunctionsTrigger = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(debug.printFunctionsTrigger, GetTriggerPlayer() or Player(0), _G["OSKEY_" .. ALICE_Config.PRINT_FUNCTION_NAMES_HOTKEY], 2, true)
            TriggerAddAction(debug.printFunctionsTrigger, OnCtrlG)

            debug.pressControlTrigger = CreateTrigger()
            for i = 0, 3 do
                BlzTriggerRegisterPlayerKeyEvent(debug.pressControlTrigger, GetTriggerPlayer() or Player(0), OSKEY_LCONTROL, i, true)
            end
            TriggerAddAction(debug.pressControlTrigger, function() debug.controlIsPressed = true end)

            debug.releaseControlTrigger = CreateTrigger()
            for i = 0, 3 do
                BlzTriggerRegisterPlayerKeyEvent(debug.releaseControlTrigger, GetTriggerPlayer() or Player(0), OSKEY_LCONTROL, i, false)
            end
            TriggerAddAction(debug.releaseControlTrigger, function() debug.controlIsPressed = false end)
        else
            if debug.selectedActor then
                Deselect(debug.selectedActor)
            end

            debug.enabled = false
            DestroyTrigger(debug.nextStepTrigger)
            DestroyTrigger(debug.lockSelectionTrigger)
            DestroyTrigger(debug.mouseClickTrigger)
            DestroyTrigger(debug.cycleSelectTrigger)
            DestroyTrigger(debug.haltTrigger)
            DestroyTrigger(debug.printFunctionsTrigger)
            DestroyTrigger(debug.pressControlTrigger)
            DestroyTrigger(debug.releaseControlTrigger)
            BlzDestroyFrame(debug.tooltip)
        end
    end
    --#endregion

       --===========================================================================================================================================================
    --Widget Actors
    --===========================================================================================================================================================

    --#region WidgetActors    
    local actorFlags = {}
    local identifiers = {}

    local function Kill(object, remove)
        if type(object) == "table" then
            if object.destroy then
                object:destroy()
            elseif object.visual then
                if HandleType[object.visual] == "effect" then
                    DestroyEffect(object.visual)
                elseif HandleType[object.visual] == "unit" then
                    KillUnit(object.visual)
                elseif HandleType[object.visual] == "image" then
                    DestroyImage(object.visual)
                elseif HandleType[object.visual] == "lightning" then
                    DestroyLightning(object.visual)
                end
            end
        elseif IsHandle[object] then
            if HandleType[object] == "unit" then
                (remove and RemoveUnit or KillUnit)(object)
            elseif HandleType[object] == "destructable" then
                (remove and RemoveDestructable or KillDestructable)(object)
            elseif HandleType[object] == "item" then
                RemoveItem(object)
            end
        end
    end

    local function Clear(object, wasUnitDeath)
        local actor = actorOf[object]
        if actor then
            if not actor.isActor then
                for i = #actor, 1, -1 do
                    if not wasUnitDeath or not actor[i].persistOnDeath then
                        if actor[i].host ~= object then
                            Kill(actor[i].host)
                        end
                        Destroy(actor[i])
                    end
                end
            elseif not wasUnitDeath or not actor.persistOnDeath then
                Destroy(actor)
            end
        end
    end

    local function OnLoad(widget, transport)
        if actorOf[widget] == nil then
            return
        end
        if actorOf[widget].isActor then
            actorOf[widget].anchor = transport
            SetCoordinateFuncs(actorOf[widget])
            Suspend(actorOf[widget], true)
        else
            for __, actor in ipairs(actorOf[widget]) do
                actor.anchor = transport
                SetCoordinateFuncs(actor)
                Suspend(actor, true)
            end
        end
    end

    local function OnUnload(widget)
        if actorOf[widget].isActor then
            local actor = actorOf[widget]
            actor.anchor = actor.originalAnchor
            actor.x[actor.anchor] = nil
            actor.y[actor.anchor] = nil
            actor.z[actor] = nil
            SetCoordinateFuncs(actor)
            Suspend(actorOf[widget], false)
        else
            for __, actor in ipairs(actorOf[widget]) do
                actor.anchor = actor.originalAnchor
                actor.x[actor.anchor] = nil
                actor.y[actor.anchor] = nil
                actor.z[actor] = nil
                SetCoordinateFuncs(actor)
                Suspend(actor, false)
            end
        end
    end

       --===========================================================================================================================================================
    --Unit Actors
    --===========================================================================================================================================================

    local function CorpseCleanUp(u)
        if GetUnitTypeId(u) == 0 then
            DestroyTrigger(widgets.reviveTriggers[u])
            widgets.reviveTriggers[u] = nil
            for __, func in ipairs(eventHooks.onUnitRemove) do
                func(u)
            end
            Clear(u)
        end
        return 1.0
    end

    ---@param u unit
    ---@return boolean
    local function CreateUnitActor(u)
        local id = GetUnitTypeId(u)

        if GetUnitAbilityLevel(u, 1097625443) > 0 and not widgets.idInclusions[id] then --FourCC "Aloc" (Locust)
            return false
        end

        if not widgets.idInclusions[id] and (config.NO_UNIT_ACTOR or widgets.idExclusions[id]) then
            return false
        end

        if id == 0 then
            return false
        end

        for key, __ in pairs(identifiers) do
            identifiers[key] = nil
        end

        local interactions
        if GetUnitState(u, UNIT_STATE_LIFE) > 0.405 then
            identifiers[#identifiers + 1] = "unit"
            actorFlags.isStationary = IsUnitType(u, UNIT_TYPE_STRUCTURE)
        elseif config.UNITS_LEAVE_BEHIND_CORPSES then
            identifiers[#identifiers + 1] = "corpse"
            interactions = {self = CorpseCleanUp}
            actorFlags.isStationary = config.UNIT_CORPSES_ARE_STATIONARY
        else
            return false
        end
        if config.ADD_WIDGET_NAMES then
            identifiers[#identifiers + 1] = toCamelCase[GetUnitName(u)]
            if IsUnitType(u, UNIT_TYPE_HERO) then
                identifiers[#identifiers + 1] = toCamelCase[GetHeroProperName(u)]
            end
        end

        for __, unittype in ipairs(config.UNIT_ADDED_CLASSIFICATIONS) do
            if IsUnitType(u, unittype) then
                identifiers[#identifiers + 1] = UNIT_CLASSIFICATION_NAMES[unittype]
            else
                identifiers[#identifiers + 1] = "non" .. UNIT_CLASSIFICATION_NAMES[unittype]
            end
        end

        identifiers[#identifiers + 1] = string.pack(">I4", id)

        actorFlags.radius = config.DEFAULT_UNIT_RADIUS
        actorFlags.persistOnDeath = config.UNITS_LEAVE_BEHIND_CORPSES

        Create(u, identifiers, interactions, actorFlags)
        return true
    end

    local function OnRevive()
        local u = GetTriggerUnit()
        ALICE_RemoveSelfInteraction(u, CorpseCleanUp, "corpse")
        ALICE_SwapIdentifier(u, "corpse", "unit", "corpse")
        if config.UNIT_CORPSES_ARE_STATIONARY and not IsUnitType(u, UNIT_TYPE_STRUCTURE) then
            ALICE_SetStationary(u, false)
        end
        DestroyTrigger(widgets.reviveTriggers[u])
        widgets.reviveTriggers[u] = nil

        for __, func in ipairs(eventHooks.onUnitRevive) do
            func(u)
        end
    end

    local function OnUnitDeath()
        local u = GetTriggerUnit()
        local actor = actorOf[u]
        if actor == nil then
            return
        end
        if config.UNITS_LEAVE_BEHIND_CORPSES then
            ALICE_AddSelfInteraction(u, CorpseCleanUp, "unit")
            ALICE_SwapIdentifier(u, "unit", "corpse", "unit")
            if config.UNIT_CORPSES_ARE_STATIONARY then
                ALICE_SetStationary(u, true)
            end
            widgets.reviveTriggers[u] = CreateTrigger()
            TriggerAddAction(widgets.reviveTriggers[u], OnRevive)
            TriggerRegisterUnitStateEvent(widgets.reviveTriggers[u], u, UNIT_STATE_LIFE, GREATER_THAN_OR_EQUAL, 0.405)
            for __, func in ipairs(eventHooks.onUnitDeath) do
                func(u)
            end
            Clear(u, true)
        else
            for __, func in ipairs(eventHooks.onUnitRemove) do
                func(u)
            end
            Clear(u)
        end
    end

    local function OnUnitEnter()
        local u = GetTrainedUnit() or GetTriggerUnit()
        if GetActor(u, "unit") then
            return
        end
        if CreateUnitActor(u) then
            for __, func in ipairs(eventHooks.onUnitEnter) do
                func(u)
            end
        end
    end

    local function OnUnitLoaded()
        local u = GetLoadedUnit()
        OnLoad(u, GetTransportUnit())
        ALICE_CallPeriodic(function(unit)
            if not IsUnitLoaded(unit) then
                ALICE_DisableCallback()
                if actorOf[unit] then
                    OnUnload(unit)
                end
            end
        end, 0, u)
    end

       --===========================================================================================================================================================
    --Destructable Actors
    --===========================================================================================================================================================

    ---@param d destructable
    local function CreateDestructableActor(d)
        local id = GetDestructableTypeId(d)

        if not widgets.idInclusions[id] and (config.NO_DESTRUCTABLE_ACTOR or widgets.idExclusions[id]) then
            return
        end

        if id == 0 then
            return
        end

        for key, __ in pairs(identifiers) do
            identifiers[key] = nil
        end
        identifiers[#identifiers + 1] = "destructable"
        local name = GetDestructableName(d)
        if config.ADD_WIDGET_NAMES then
            identifiers[#identifiers + 1] = toCamelCase[name]
        end
        identifiers[#identifiers + 1] = string.pack(">I4", id)

        actorFlags.radius = config.DEFAULT_DESTRUCTABLE_RADIUS
        actorFlags.isStationary = true
        actorFlags.persistOnDeath = nil

        Create(d, identifiers, nil, actorFlags)
    end

    OnDestructableDeath = function()
        local whichObject = GetTriggerDestructable()
        DestroyTrigger(widgets.deathTriggers[whichObject])
        widgets.deathTriggers[whichObject] = nil
        for __, func in ipairs(eventHooks.onDestructableDestroy) do
            func(whichObject)
        end
        Clear(whichObject)
    end

       --===========================================================================================================================================================
    --Item Actors
    --===========================================================================================================================================================

    ---@param i item
    local function CreateItemActor(i)
        local id = GetItemTypeId(i)

        if not widgets.idInclusions[id] and (config.NO_ITEM_ACTOR or widgets.idExclusions[id]) then
            return
        end

        if id == 0 then
            return
        end

        for key, __ in pairs(identifiers) do
            identifiers[key] = nil
        end
        identifiers[#identifiers + 1] = "item"
        if config.ADD_WIDGET_NAMES then
            identifiers[#identifiers + 1] = toCamelCase[GetItemName(i)]
        end
        identifiers[#identifiers + 1] = string.pack(">I4", id)

        actorFlags.radius = config.DEFAULT_ITEM_RADIUS
        actorFlags.isStationary = config.ITEMS_ARE_STATIONARY
        actorFlags.persistOnDeath = nil

        Create(i, identifiers, nil, actorFlags)
    end

    local function OnItemPickup()
        local item = GetManipulatedItem()
        OnLoad(item, GetTriggerUnit())
        if config.ITEMS_ARE_STATIONARY then
            ALICE_SetStationary(item, false)
        end
    end

    local function OnItemDrop()
        local item = GetManipulatedItem()
        if actorOf[item] then
            OnUnload(item)
            if config.ITEMS_ARE_STATIONARY then
                ALICE_SetStationary(item, true)
            end
        else
            AddDelayedCallback(function(whichItem)
                if GetItemTypeId(whichItem) == 0 then
                    return
                end
                CreateItemActor(whichItem)
                for __, func in ipairs(eventHooks.onItemEnter) do
                    func(whichItem)
                end
            end, item)
        end
    end

    local function OnItemSold()
        Clear(GetManipulatedItem())
    end

    OnItemDeath = function()
        SaveWidgetHandle(widgets.hash, 0, 0, GetTriggerWidget())
        local whichObject = LoadItemHandle(widgets.hash, 0, 0)
        DestroyTrigger(widgets.deathTriggers[whichObject])
        widgets.deathTriggers[whichObject] = nil
        for __, func in ipairs(eventHooks.onItemDestroy) do
            func(whichObject)
        end
        Clear(whichObject)
    end
    --#endregion

       --===========================================================================================================================================================
    --Init
    --===========================================================================================================================================================

    --#region Init
    local function Init()
        Require "HandleType"
        Require "Hook"

        timers.MASTER = CreateTimer()
        timers.INTERPOLATION = CreateTimer()
        MAX_STEPS = (config.MAX_INTERVAL/config.MIN_INTERVAL) // 1
        CYCLE_LENGTH = MAX_STEPS + 1
        DO_NOT_EVALUATE = CYCLE_LENGTH + 1

        for i = 1, DO_NOT_EVALUATE do
            numPairs[i] = 0
            whichPairs[i] = {}
        end

        for i = 1, CYCLE_LENGTH do
            numCellChecks[i] = 0
---@diagnostic disable-next-line: missing-fields
            cellCheckedActors[i] = {}
        end

        local worldBounds = GetWorldBounds()
        MAP_MIN_X = GetRectMinX(worldBounds)
        MAP_MAX_X = GetRectMaxX(worldBounds)
        MAP_MIN_Y = GetRectMinY(worldBounds)
        MAP_MAX_Y = GetRectMaxY(worldBounds)
        MAP_SIZE_X = MAP_MAX_X - MAP_MIN_X
        MAP_SIZE_Y = MAP_MAX_Y - MAP_MIN_Y

        NUM_CELLS_X = MAP_SIZE_X // config.CELL_SIZE
        NUM_CELLS_Y = MAP_SIZE_Y // config.CELL_SIZE

        for X = 1, NUM_CELLS_X do
            CELL_LIST[X] = {}
            for Y = 1, NUM_CELLS_Y do
---@diagnostic disable-next-line: missing-fields
                CELL_LIST[X][Y] = {numActors = 0}
            end
        end

        for x = 1, NUM_CELLS_X do
            CELL_MIN_X[x] = MAP_MIN_X + (x-1)/NUM_CELLS_X*MAP_SIZE_X
            CELL_MAX_X[x] = MAP_MIN_X + x/NUM_CELLS_X*MAP_SIZE_X
        end
        for y = 1, NUM_CELLS_Y do
            CELL_MIN_Y[y] = MAP_MIN_Y + (y-1)/NUM_CELLS_Y*MAP_SIZE_Y
            CELL_MAX_Y[y] = MAP_MIN_Y + y/NUM_CELLS_Y*MAP_SIZE_Y
        end

        GetTable = config.TABLE_RECYCLER_GET or function()
            local numUnusedTables = #unusedTables
            if numUnusedTables == 0 then
                return {}
            else
                local returnTable = unusedTables[numUnusedTables]
                unusedTables[numUnusedTables] = nil
                return returnTable
            end
        end

        ReturnTable = config.TABLE_RECYCLER_RETURN or function(whichTable)
            for key, __ in pairs(whichTable) do
                whichTable[key] = nil
            end
            unusedTables[#unusedTables + 1] = whichTable
            setmetatable(whichTable, nil)
        end

        local trig = CreateTrigger()
        for i = 0, 23 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "downtherabbithole", true)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-downtherabbithole", true)
        end
        TriggerAddAction(trig, DownTheRabbitHole)

        SELF_INTERACTION_ACTOR = Create({}, "selfInteraction", nil, EMPTY_TABLE)
        actorList[#actorList] = nil
        celllessActorList[#celllessActorList] = nil
        totalActors = totalActors - 1
        SELF_INTERACTION_ACTOR.unique = 0

        debug.functionName[CorpseCleanUp] = "CorpseCleanUp"

        TimerStart(timers.MASTER, config.MIN_INTERVAL, true, Main)
        if config.INTERPOLATION_INTERVAL then
            TimerStart(timers.INTERPOLATION, config.INTERPOLATION_INTERVAL, true, Interpolate)
        end

        local precomputedHeightMap = Require.optionally "PrecomputedHeightMap"

        if precomputedHeightMap then
            GetTerrainZ = _G.GetTerrainZ
        else
            moveableLoc = Location(0, 0)
            GetTerrainZ = function(x, y)
                MoveLocation(moveableLoc, x, y)
                return GetLocationZ(moveableLoc)
            end
        end

        widgets.hash = InitHashtable()

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_HERO_REVIVE_FINISH)
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_SUMMON)
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_TRAIN_FINISH)
        TriggerAddAction(trig, OnUnitEnter)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddAction(trig, OnUnitDeath)

        local G = CreateGroup()
        GroupEnumUnitsInRect(G, GetPlayableMapRect(), nil)
        ForGroup(G, function()
            local u = GetEnumUnit()
            if CreateUnitActor(u) then
                for __, func in ipairs(eventHooks.onUnitEnter) do
                    func(u)
                end
            end
        end)
        DestroyGroup(G)

        EnumDestructablesInRect(worldBounds, nil, function() CreateDestructableActor(GetEnumDestructable()) end)

        EnumItemsInRect(worldBounds, nil, function() CreateItemActor(GetEnumItem()) end)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_DROP_ITEM)
        TriggerAddAction(trig, OnItemDrop)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_PICKUP_ITEM)
        TriggerAddAction(trig, OnItemPickup)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_PAWN_ITEM)
        TriggerAddAction(trig, OnItemSold)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_CHANGE_OWNER)
        TriggerAddAction(trig, OnUnitChangeOwner)

        trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_LOADED)
        TriggerAddAction(trig, OnUnitLoaded)

        local function CreateUnitHookFunc(self, ...)
            local newUnit = self.old(...)
            if CreateUnitActor(newUnit) then
                for __, func in ipairs(eventHooks.onUnitEnter) do
                    func(newUnit)
                end
            end
            return newUnit
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateUnit = CreateUnitHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateUnitByName = CreateUnitHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateUnitAtLoc = CreateUnitHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateUnitAtLocByName = CreateUnitHookFunc
        if config.UNITS_LEAVE_BEHIND_CORPSES then
            ---@diagnostic disable-next-line: duplicate-set-field
            Hook.CreateCorpse = CreateUnitHookFunc
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:RemoveUnit(whichUnit)
            local item
            for i = 0, UnitInventorySize(whichUnit) - 1 do
                item = UnitItemInSlot(whichUnit, i)
                for __, func in ipairs(eventHooks.onItemDestroy) do
                    func(item)
                end
                Clear(item)
            end
            for __, func in ipairs(eventHooks.onUnitRemove) do
                func(whichUnit)
            end
            Clear(whichUnit)
            self.old(whichUnit)
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:ShowUnit(whichUnit, enable)
            self.old(whichUnit, enable)
            if actorOf[whichUnit] == nil then
                return
            end
            if actorOf[whichUnit].isActor then
                Suspend(actorOf[whichUnit], not enable)
            else
                for __, actor in ipairs(actorOf[whichUnit]) do
                    Suspend(actor, not enable)
                end
            end
        end

        local function CreateDestructableHookFunc(self, ...)
            local newDestructable = self.old(...)
            CreateDestructableActor(newDestructable)
            for __, func in ipairs(eventHooks.onDestructableEnter) do
                func(newDestructable)
            end
            return newDestructable
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateDestructable = CreateDestructableHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.CreateDestructableZ = CreateDestructableHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.BlzCreateDestructableWithSkin = CreateDestructableHookFunc
        ---@diagnostic disable-next-line: duplicate-set-field
        Hook.BlzCreateDestructableZWithSkin = CreateDestructableHookFunc

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:RemoveDestructable(whichDestructable)
            for __, func in ipairs(eventHooks.onDestructableDestroy) do
                func(whichDestructable)
            end
            Clear(whichDestructable)
            if widgets.deathTriggers[whichDestructable] then
                DestroyTrigger(widgets.deathTriggers[whichDestructable])
                widgets.deathTriggers[whichDestructable] = nil
            end
            self.old(whichDestructable)
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:DestructableRestoreLife(whichDestructable, life, birth)
            self.old(whichDestructable, life, birth)
            if GetDestructableLife(whichDestructable) > 0 and GetActor(whichDestructable, "destructable") == nil then
                CreateDestructableActor(whichDestructable)
                for __, func in ipairs(eventHooks.onDestructableEnter) do
                    func(whichDestructable)
                end
            end
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:CreateItem(...)
            local newItem
            newItem = self.old(...)
            CreateItemActor(newItem)
            for __, func in ipairs(eventHooks.onItemEnter) do
                func(newItem)
            end
            return newItem
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:RemoveItem(whichItem)
            for __, func in ipairs(eventHooks.onItemDestroy) do
                func(whichItem)
            end
            Clear(whichItem)
            if widgets.deathTriggers[whichItem] then
                DestroyTrigger(widgets.deathTriggers[whichItem])
                widgets.deathTriggers[whichItem] = nil
            end
            self.old(whichItem)
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        function Hook:SetItemVisible(whichItem, enable)
            self.old(whichItem, enable)
            if actorOf[whichItem] == nil then
                return
            end
            if actorOf[whichItem].isActor then
                Suspend(actorOf[whichItem], not enable)
            else
                for __, actor in ipairs(actorOf[whichItem]) do
                    Suspend(actor, not enable)
                end
            end
        end
    end

    OnInit.final("ALICE", Init)
    --#endregion

    --===========================================================================================================================================================
    --API
    --===========================================================================================================================================================

    --#region API

    --Core API
    --===========================================================================================================================================================

    ---Create an actor for the object host and add it to the cycle. If the host is a table and is provided as the only input argument, all other arguments will be retrieved directly from that table.
    ---Recognized flags:
    -- - anchor
    -- - radius
    -- - selfInteractions
    -- - bindToBuff
    -- - bindToOrder
    -- - isStationary
    -- - onActorDestroy
    -- - zOffset
    -- - cellCheckInterval
    -- - persistOnDeath
    -- - priority
    -- - width
    -- - height
    -- - hasInfiniteRange
    -- - isGlobal
    -- - isAnonymous
    -- - isUnselectable
    -- - actorClass
    ---@param host any
    ---@param identifier? string | string[]
    ---@param interactions? table
    ---@param flags? ALICE_Flags
    ---@return any
    function ALICE_Create(host, identifier, interactions, flags)
        if host == nil then
            error("Host is nil.")
        end
        if identifier then
            Create(host, identifier, interactions, flags or EMPTY_TABLE)
        else
            Create(host, host.identifier, host.interactions, host)
        end
        return host
    end

    ---Destroy the actor of the specified object. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param keyword? string
    function ALICE_Destroy(object, keyword)
        local actor = GetActor(object, keyword)
        if actor then
            Destroy(actor)
        end
    end

    ---Calls the appropriate function to destroy the object, then destroys all actors attached to it. If the object is a table, the object:destroy() method will be called. If no destroy function exists, it will try to destroy the table's visual, which can be an effect, a unit, or an image.
    ---@param object Object
    ---@param remove? boolean
    function ALICE_Kill(object, remove)
        if object == nil then
            return
        end

        Kill(object, remove)
        Clear(object)
    end

    --Math API
    --===========================================================================================================================================================

    ---Returns the distance between the objects of the pair currently being evaluated in two dimensions. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number
    function ALICE_PairGetDistance2D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]

        if actorA and actorB == SELF_INTERACTION_ACTOR then
            return 0
        end

        local anchorA = actorA.anchor
        local anchorB = actorB.anchor
        local dx = actorA.x[anchorA] - actorB.x[anchorB]
        local dy = actorA.y[anchorA] - actorB.y[anchorB]

        return sqrt(dx*dx + dy*dy)
    end

    ---Returns the distance between the objects of the pair currently being evaluated in three dimensions. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number
    function ALICE_PairGetDistance3D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]

        if actorA and actorB == SELF_INTERACTION_ACTOR then
            return 0
        end

        local anchorA = actorA.anchor
        local anchorB = actorB.anchor
        local dx = actorA.x[anchorA] - actorB.x[anchorB]
        local dy = actorA.y[anchorA] - actorB.y[anchorB]
        local dz = actorA.z[actorA] - actorB.z[actorB]

        return sqrt(dx*dx + dy*dy + dz*dz)
    end

    ---Returns the angle from object A to object B of the pair currently being evaluated. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number
    function ALICE_PairGetAngle2D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]

        if actorA and actorB == SELF_INTERACTION_ACTOR then
            return 0
        end

        local anchorA = actorA.anchor
        local anchorB = actorB.anchor
        local dx = actorB.x[anchorB] - actorA.x[anchorA]
        local dy = actorB.y[anchorB] - actorA.y[anchorA]

        return atan(dy, dx)
    end

    ---Returns the horizontal and vertical angles from object A to object B of the pair currently being evaluated. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number, number
    function ALICE_PairGetAngle3D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]

        if actorA and actorB == SELF_INTERACTION_ACTOR then
            return 0, 0
        end

        local anchorA = actorA.anchor
        local anchorB = actorB.anchor
        local dx = actorB.x[anchorB] - actorA.x[anchorA]
        local dy = actorB.y[anchorB] - actorA.y[anchorA]
        local dz = actorB.z[actorB] - actorA.z[actorA]

        return atan(dy, dx), atan(dz, sqrt(dx*dx + dy*dy))
    end

    ---Returns the coordinates of the objects in the pair currently being evaluated in the order x1, y1, x2, y2. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number, number, number, number
    function ALICE_PairGetCoordinates2D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]
        local anchorA = actorA.anchor
        local anchorB = actorB.anchor

        return actorA.x[anchorA], actorA.y[anchorA], actorB.x[anchorB], actorB.y[anchorB]
    end

    ---Returns the coordinates of the objects in the pair currently being evaluated in the order x1, y1, z1, x2, y2, z2. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@return number, number, number, number, number, number
    function ALICE_PairGetCoordinates3D()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]
        local anchorA = actorA.anchor
        local anchorB = actorB.anchor

        return actorA.x[anchorA], actorA.y[anchorA], actorA.z[actorA], actorB.x[anchorB], actorB.y[anchorB], actorB.z[actorB]
    end

    ---Returns the coordinates x, y of an object. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@param object Object
    ---@param keyword? string
    ---@return number, number
    function ALICE_GetCoordinates2D(object, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return 0, 0
        end

        local anchor = actor.anchor
        return actor.x[anchor], actor.y[anchor]
    end

    ---Returns the coordinates x, y, z of an object. This function uses cached values and may not be accurate if immediately called after changing an object's location.
    ---@param object Object
    ---@param keyword? string
    ---@return number, number, number
    function ALICE_GetCoordinates3D(object, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return 0, 0, 0
        end

        local anchor = actor.anchor
        return actor.x[anchor], actor.y[anchor], actor.z[actor]
    end

    --Callback API
    --===========================================================================================================================================================

    ---Invokes the callback function after the specified delay, passing additional arguments into the callback function.
    ---@param callback function
    ---@param delay? number
    ---@vararg any
    ---@return table
    function ALICE_CallDelayed(callback, delay, ...)
        local new = GetTable()
        new.callCounter = cycle.unboundCounter + ((delay or 0)*INV_MIN_INTERVAL + 1) // 1
        new.callback = callback
        local numArgs = select("#", ...)
        if numArgs == 1 then
            new.args = select(1, ...)
        elseif numArgs > 1 then
            new.args = pack(...)
            new.unpack = true
        end

        AddUserCallback(new)

        return new
    end

    ---Invokes the callback function after the specified delay, passing the hosts of the current pair as arguments. A third parameter is passed into the callback, specifying whether you have access to the ALICE_Pair functions. You will not if the current pair has been destroyed after the callback was queued up.
    ---@param callback function
    ---@param delay? number
    ---@return table
    function ALICE_PairCallDelayed(callback, delay)
        local new = GetTable()
        new.callCounter = cycle.unboundCounter + ((delay or 0)*INV_MIN_INTERVAL + 1) // 1
        new.callback = callback
        new.hostA = currentPair[0x3]
        new.hostB = currentPair[0x4]
        new.pair = currentPair

        AddUserCallback(new)

        return new
    end

    ---Periodically invokes the callback function. Optional delay parameter to delay the first execution. Additional arguments are passed into the callback function. The return value of the callback function specifies the interval until next execution.
    ---@param callback function
    ---@param delay? number
    ---@vararg any
    ---@return table
    function ALICE_CallPeriodic(callback, delay, ...)
        local host = pack(...)
        host.callback = callback
        host.excess = delay or 0
        host.isPeriodic = true
        local actor = CreateStub(host)
        actor.periodicPair = CreatePair(actor, SELF_INTERACTION_ACTOR, PeriodicWrapper)

        return host
    end

    ---Periodically invokes the callback function up to howOften times. Optional delay parameter to delay the first execution. The arguments passed into the callback function are the current iteration, followed by any additional arguments. The return value of the callback function specifies the interval until next execution.
    ---@param callback function
    ---@param howOften integer
    ---@param delay? number
    ---@vararg any
    ---@return table
    function ALICE_CallRepeated(callback, howOften, delay, ...)
        local host = pack(...)
        host.callback = callback
        host.howOften = howOften
        host.currentExecution = 0
        host.excess = delay or 0
        host.isPeriodic = true
        local actor = CreateStub(host)
        if howOften > 0 then
            actor.periodicPair = CreatePair(actor, SELF_INTERACTION_ACTOR, RepeatedWrapper)
        end

        return host
    end

    ---Disables a callback returned by ALICE_CallDelayed, ALICE_CallPeriodic, or ALICE_CallRepeated. If called from within a periodic callback function itself, the parameter can be omitted. Returns whether the callback was interrupted.
    ---@param callback? table
    ---@return boolean
    function ALICE_DisableCallback(callback)
        local actor
        if callback then
            if callback.isPeriodic then
                actor = GetActor(callback)
                if actor == nil or actor.alreadyDestroyed then
                    return false
                end

                actor.periodicPair.destructionQueued = true
                AddDelayedCallback(DestroyPair, actor.periodicPair)
                if functionOnDestroy[callback.callback] then
                    functionOnDestroy[callback.callback](unpack(callback))
                end
                DestroyStub(actor)
                for key, __ in pairs(callback) do
                    callback[key] = nil
                end
                return true
            else
                if callback.callCounter == nil or callback.callCounter <= cycle.unboundCounter then
                    return false
                end

                if functionOnDestroy[callback.callback] then
                    if callback.pair then
                        if callback.pair[0x3] == callback.hostA and callback.pair[0x4] == callback.hostB then
                            currentPair = callback.pair
                            functionOnDestroy[callback.callback](callback.hostA, callback.hostB, true)
                            currentPair = OUTSIDE_OF_CYCLE
                        else
                            functionOnDestroy[callback.callback](callback.hostA, callback.hostB, false)
                        end
                    elseif callback.args then
                        if callback.unpack then
                            functionOnDestroy[callback.callback](unpack(callback.args))
                        else
                            functionOnDestroy[callback.callback](callback.args)
                        end
                    else
                        functionOnDestroy[callback.callback]()
                    end
                end

                if not callback.isPaused then
                    RemoveUserCallbackFromList(callback)
                end
                for key, __ in pairs(callback) do
                    callback[key] = nil
                end
                return true
            end
        elseif currentPair ~= OUTSIDE_OF_CYCLE then
            actor = currentPair[0x1]

            if actor == nil or actor.alreadyDestroyed or actor.periodicPair ~= currentPair then
                return false
            end

            actor.periodicPair.destructionQueued = true
            AddDelayedCallback(DestroyPair, actor.periodicPair)
            callback = actor.host

            if functionOnDestroy[callback.callback] then
                functionOnDestroy[callback.callback](unpack(callback))
            end
            DestroyStub(actor)
            for key, __ in pairs(callback) do
                callback[key] = nil
            end
            return true
        end
        return false
    end

    ---Pauses or unpauses a callback returned by ALICE_CallDelayed, ALICE_CallPeriodic, or ALICE_CallRepeated. If a periodic callback is unpaused this way, the next iteration will be executed immediately. Otherwise, the remaining time will be waited. If called from within a periodic callback function itself, the callback parameter can be omitted.
    ---@param callback? table
    ---@param enable? boolean
    function ALICE_PauseCallback(callback, enable)
        enable = enable ~= false

        local actor
        if callback then
            if callback.isPeriodic then
                if callback.isPaused == enable then
                    return
                end
                callback.isPaused = enable

                actor = GetActor(callback)
                if enable then
                    PausePair(actor.periodicPair)
                else
                    UnpausePair(actor.periodicPair)
                end
            else
                if callback.callCounter == nil then
                    return
                end

                if callback.isPaused == enable then
                    return
                end
                callback.isPaused = enable

                if enable then
                    if callback.callCounter <= cycle.unboundCounter then
                        return
                    end
                    callback.stepsRemaining = callback.callCounter - cycle.unboundCounter
                    RemoveUserCallbackFromList(callback)
                else
                    callback.callCounter = cycle.unboundCounter + callback.stepsRemaining
                    AddUserCallback(callback)
                end
                return
            end
        elseif currentPair ~= OUTSIDE_OF_CYCLE then
            if callback.isPaused == enable then
                return
            end
            callback.isPaused = enable

            actor = currentPair[0x1]
            if enable then
                PausePair(actor.periodicPair)
            else
                UnpausePair(actor.periodicPair)
            end
        else

        end
    end

    --Enum API
    --===========================================================================================================================================================

    ---Enum functions return a table with all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    ---@return Object[]
    function ALICE_EnumObjects(identifier, condition, ...)
        local returnTable = GetTable()

        if type(identifier) == "string" then
            for __, actor in ipairs(actorList) do
                if actor.identifier[identifier] and (condition == nil or condition(actor.host, ...)) then
                    if not actor.isSuspended then
                        returnTable[#returnTable + 1] = actor.host
                    end
                end
            end
        else
            for __, actor in ipairs(actorList) do
                if HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) then
                    if not actor.isSuspended then
                        returnTable[#returnTable + 1] = actor.host
                    end
                end
            end
        end

        return returnTable
    end

    ---Performs the action on all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean.  Additional arguments are passed into both the filter and the action function.
    ---@param action function
    ---@param identifier string | table
    ---@param condition function | nil
    ---@vararg any
    function ALICE_ForAllObjectsDo(action, identifier, condition, ...)
        local list = ALICE_EnumObjects(identifier, condition, ...)
        for __, object in ipairs(list) do
            action(object, ...)
        end
        ReturnTable(list)
    end

    ---Enum functions return a table with all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param x number
    ---@param y number
    ---@param range number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    ---@return Object[]
    function ALICE_EnumObjectsInRange(x, y, range, identifier, condition, ...)
        local returnTable = GetTable()

        ResetCoordinateLookupTables()

        local minX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x - range - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local minY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y - range - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))
        local maxX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x + range - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local maxY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y + range - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))

        local dx
        local dy
        local rangeSquared = range*range
        local identifierIsString = type(identifier) == "string"

        local actor, cell
        for X = minX, maxX do
            for Y = minY, maxY do
                cell = CELL_LIST[X][Y]
                actor = cell.first
                if actor then
                    if identifierIsString then
                        for __ = 1, cell.numActors do
                            if actor.identifier[identifier] and not alreadyEnumerated[actor] and (condition == nil or condition(actor.host, ...)) then
                                alreadyEnumerated[actor] = true
                                dx = actor.x[actor.anchor] - x
                                dy = actor.y[actor.anchor] - y
                                if dx*dx + dy*dy < rangeSquared then
                                    returnTable[#returnTable + 1] = actor.host
                                end
                            end
                            actor = actor.nextInCell[cell]
                        end
                    else
                        for __ = 1, cell.numActors do
                            if not alreadyEnumerated[actor] and HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) then
                                alreadyEnumerated[actor] = true
                                dx = actor.x[actor.anchor] - x
                                dy = actor.y[actor.anchor] - y
                                if dx*dx + dy*dy < rangeSquared then
                                    returnTable[#returnTable + 1] = actor.host
                                end
                            end
                            actor = actor.nextInCell[cell]
                        end
                    end
                end
            end
        end

        for key, __ in pairs(alreadyEnumerated) do
            alreadyEnumerated[key] = nil
        end

        return returnTable
    end

    ---Performs the action on all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into both the filter and the action function.
    ---@param action function
    ---@param x number
    ---@param y number
    ---@param range number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    function ALICE_ForAllObjectsInRangeDo(action, x, y, range, identifier, condition, ...)
        local list = ALICE_EnumObjectsInRange(x, y, range, identifier, condition, ...)
        for __, object in ipairs(list) do
            action(object, ...)
        end
        ReturnTable(list)
    end

    ---Enum functions return a table with all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param minx number
    ---@param miny number
    ---@param maxx number
    ---@param maxy number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    ---@return Object[]
    function ALICE_EnumObjectsInRect(minx, miny, maxx, maxy, identifier, condition, ...)
        local returnTable = GetTable()

        ResetCoordinateLookupTables()

        local minX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(minx - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local minY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(miny - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))
        local maxX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(maxx - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local maxY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(maxy - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))

        local x
        local y
        local identifierIsString = type(identifier) == "string"

        local actor, cell
        for X = minX, maxX do
            for Y = minY, maxY do
                cell = CELL_LIST[X][Y]
                actor = cell.first
                if actor then
                    if identifierIsString then
                        for __ = 1, cell.numActors do
                            if actor.identifier[identifier] and not alreadyEnumerated[actor] and (condition == nil or condition(actor.host, ...)) then
                                alreadyEnumerated[actor] = true
                                x = actor.x[actor.anchor]
                                y = actor.y[actor.anchor]
                                if x > minx and x < maxx and y > miny and y < maxy then
                                    returnTable[#returnTable + 1] = actor.host
                                end
                            end
                            actor = actor.nextInCell[cell]
                        end
                    else
                        for __ = 1, cell.numActors do
                            if not alreadyEnumerated[actor] and HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) then
                                alreadyEnumerated[actor] = true
                                x = actor.x[actor.anchor]
                                y = actor.y[actor.anchor]
                                if x > minx and x < maxx and y > miny and y < maxy then
                                    returnTable[#returnTable + 1] = actor.host
                                end
                            end
                            actor = actor.nextInCell[cell]
                        end
                    end
                end
            end
        end

        for key, __ in pairs(alreadyEnumerated) do
            alreadyEnumerated[key] = nil
        end

        return returnTable
    end

    ---Performs the action on all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into both the filter and the action function.
    ---@param action function
    ---@param minx number
    ---@param miny number
    ---@param maxx number
    ---@param maxy number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    function ALICE_ForAllObjectsInRectDo(action, minx, miny, maxx, maxy, identifier, condition, ...)
        local list = ALICE_EnumObjectsInRect(minx, miny, maxx, maxy, identifier, condition, ...)
        for __, object in ipairs(list) do
            action(object, ...)
        end
        ReturnTable(list)
    end

   ---Enum functions return a table with all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@param halfWidth number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    ---@return Object[]
    function ALICE_EnumObjectsInLineSegment(x1, y1, x2, y2, halfWidth, identifier, condition, ...)
        if x2 == x1 then
            return ALICE_EnumObjectsInRect(x1 - halfWidth, min(y1, y2), x1 + halfWidth, max(y1, y2), identifier, condition, ...)
        end

        ResetCoordinateLookupTables()

        local returnTable = GetTable()
        local cells = GetTable()

        local angle = atan(y2 - y1, x2 - x1)
        local cosAngle = math.cos(angle)
        local sinAngle = math.sin(angle)

        local Xmin, Xmax, Ymin, Ymax, cRight, cLeft, slope
        local XminRight = (NUM_CELLS_X*(x1 + halfWidth*sinAngle - MAP_MIN_X)/MAP_SIZE_X)
        local XmaxRight = (NUM_CELLS_X*(x2 + halfWidth*sinAngle - MAP_MIN_X)/MAP_SIZE_X)
        local YminRight = (NUM_CELLS_Y*(y1 - halfWidth*cosAngle - MAP_MIN_Y)/MAP_SIZE_Y)
        local YmaxRight = (NUM_CELLS_Y*(y2 - halfWidth*cosAngle - MAP_MIN_Y)/MAP_SIZE_Y)
        local XminLeft = (NUM_CELLS_X*(x1 - halfWidth*sinAngle - MAP_MIN_X)/MAP_SIZE_X)
        local XmaxLeft = (NUM_CELLS_X*(x2 - halfWidth*sinAngle - MAP_MIN_X)/MAP_SIZE_X)
        local YminLeft = (NUM_CELLS_Y*(y1 + halfWidth*cosAngle - MAP_MIN_Y)/MAP_SIZE_Y)
        local YmaxLeft = (NUM_CELLS_Y*(y2 + halfWidth*cosAngle - MAP_MIN_Y)/MAP_SIZE_Y)

        slope = (y2 - y1)/(x2 - x1)
        cRight = YminRight - XminRight*slope
        cLeft = YminLeft - XminLeft*slope

        if x2 > x1 then
            if y2 > y1 then
                Ymin = min(NUM_CELLS_Y, max(1, YminRight // 1)) + 1
                Ymax = min(NUM_CELLS_Y, max(1, YmaxLeft // 1)) + 1

                for j = Ymin, Ymax do
                    Xmin = min(NUM_CELLS_X, max(1, max((j - 1 - cLeft)/slope, XminLeft) // 1 + 1))
                    Xmax = min(NUM_CELLS_X, max(1, min((j - cRight)/slope, XmaxRight) // 1 + 1))

                    for i = Xmin, Xmax do
                        cells[#cells + 1] = CELL_LIST[i][j]
                    end
                end
            else
                Ymin = min(NUM_CELLS_Y, max(1, YmaxRight // 1)) + 1
                Ymax = min(NUM_CELLS_Y, max(1, YminLeft // 1)) + 1

                for j = Ymin, Ymax do
                    Xmin = min(NUM_CELLS_X, max(1, max((j - cRight)/slope, XminRight) // 1 + 1))
                    Xmax = min(NUM_CELLS_X, max(1, min((j - 1 - cLeft)/slope, XmaxLeft) // 1 + 1))

                    for i = Xmin, Xmax do
                        cells[#cells + 1] = CELL_LIST[i][j]
                    end
                end
            end
        else
            if y2 > y1 then
                Ymin = min(NUM_CELLS_Y, max(1, YminLeft // 1)) + 1
                Ymax = min(NUM_CELLS_Y, max(1, YmaxRight // 1)) + 1

                for j = Ymin, Ymax do
                    Xmin = min(NUM_CELLS_X, max(1, max((j - cLeft)/slope, XmaxLeft) // 1 + 1))
                    Xmax = min(NUM_CELLS_X, max(1, min((j - 1 - cRight)/slope, XminRight) // 1 + 1))

                    for i = Xmin, Xmax do
                        cells[#cells + 1] = CELL_LIST[i][j]
                    end
                end
            else
                Ymin = min(NUM_CELLS_Y, max(1, YmaxLeft // 1)) + 1
                Ymax = min(NUM_CELLS_Y, max(1, YminRight // 1)) + 1

                for j = Ymin, Ymax do
                    Xmin = min(NUM_CELLS_X, max(1, max((j - 1 - cRight)/slope, XmaxRight) // 1 + 1))
                    Xmax = min(NUM_CELLS_X, max(1, min((j - cLeft)/slope, XminLeft) // 1 + 1))

                    for i = Xmin, Xmax do
                        cells[#cells + 1] = CELL_LIST[i][j]
                    end
                end
            end
        end

        local identifierIsString = type(identifier) == "string"

        local actor
        local maxDist = sqrt((x2 - x1)^2 + (y2 - y1)^2)
        local dx, dy, xPrime, yPrime
        for __, cell in ipairs(cells) do
            actor = cell.first
            if actor then
                if identifierIsString then
                    for __ = 1, cell.numActors do
                        if actor.identifier[identifier] and not alreadyEnumerated[actor] and (condition == nil or condition(actor.host, ...)) then
                            alreadyEnumerated[actor] = true
                            dx = actor.x[actor.anchor] - x1
                            dy = actor.y[actor.anchor] - y1
                            xPrime = cosAngle*dx + sinAngle*dy
                            yPrime = -sinAngle*dx + cosAngle*dy
                            if yPrime < halfWidth and yPrime > -halfWidth and xPrime > 0 and xPrime < maxDist then
                                returnTable[#returnTable + 1] = actor.host
                            end
                        end
                        actor = actor.nextInCell[cell]
                    end
                else
                    for __ = 1, cell.numActors do
                        if not alreadyEnumerated[actor] and HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) then
                            alreadyEnumerated[actor] = true
                            dx = actor.x[actor.anchor] - x1
                            dy = actor.y[actor.anchor] - y1
                            xPrime = cosAngle*dx + sinAngle*dy
                            yPrime = -sinAngle*dx + cosAngle*dy
                            if yPrime < halfWidth and yPrime > -halfWidth and xPrime > 0 and xPrime < maxDist then
                                returnTable[#returnTable + 1] = actor.host
                            end
                        end
                        actor = actor.nextInCell[cell]
                    end
                end
            end
        end

        ReturnTable(cells)

        for key, __ in pairs(alreadyEnumerated) do
            alreadyEnumerated[key] = nil
        end

        return returnTable
    end

    ---Performs the action on all objects that have the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into both the filter and the action function.
    ---@param action function
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@param halfWidth number
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    function ALICE_ForAllObjectsInLineSegmentDo(action, x1, y1, x2, y2, halfWidth, identifier, condition, ...)
        local list = ALICE_EnumObjectsInLineSegment(x1, y1, x2, y2, halfWidth, identifier, condition, ...)
        for __, object in ipairs(list) do
            action(object, ...)
        end
        ReturnTable(list)
    end

    ---Function for performant enumeration of objects within a region. The region does not use the native region type, but is represented by a rect array or a table array, where each table must hold the minX, minY, maxX, and maxY fields. Region data is cached on the first call and the region object must not change afterwards. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param whichRegion rect[] | table[]
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    ---@return Object[]
    function ALICE_EnumObjectsInRegion(whichRegion, identifier, condition, ...)
        local returnTable = GetTable()

        ResetCoordinateLookupTables()

        local identifierIsString = type(identifier) == "string"

        if not regions[whichRegion] then
            regions[whichRegion] = {
                cells = {}
            }

            if type(whichRegion[1]) == "table" then
                regions[whichRegion].rects = whichRegion
            else
                regions[whichRegion].rects = {}
                for __, rect in ipairs(whichRegion) do
                    regions[whichRegion].rects[#regions[whichRegion].rects + 1] = {
                        minX = GetRectMinX(rect),
                        minY = GetRectMinY(rect),
                        maxX = GetRectMaxX(rect),
                        maxY = GetRectMaxY(rect)
                    }
                end
            end

            local minx, miny, maxx, maxy, minI, minJ, maxI, maxJ
            local cellIsInRegion = {}

            for __, rect in ipairs(regions[whichRegion].rects) do
                minx = rect.minX
                miny = rect.minY
                maxx = rect.maxX
                maxy = rect.maxY
                minI = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(minx - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
                minJ = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(miny - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))
                maxI = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(maxx - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
                maxJ = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(maxy - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))

                for i = minI, maxI do
                    for j = minJ, maxJ do
                        if not cellIsInRegion[CELL_LIST[i][j]] then
                            cellIsInRegion[CELL_LIST[i][j]] = true
                            regions[whichRegion].cells[#regions[whichRegion].cells + 1] = CELL_LIST[i][j]
                        end
                    end
                end
            end
        end

        local cell, actor
        local cells = regions[whichRegion].cells
        local rects = regions[whichRegion].rects

        local x, y
        for i = 1, #cells do
            cell = cells[i]
            actor = cell.first
            if actor then
                if identifierIsString then
                    for __ = 1, cell.numActors do
                        if actor.identifier[identifier] and not alreadyEnumerated[actor] and (condition == nil or condition(actor.host, ...)) then
                            alreadyEnumerated[actor] = true
                            x = actor.x[actor.anchor]
                            y = actor.y[actor.anchor]
                            for __, rect in ipairs(rects) do
                                if x > rect.minX and x < rect.maxX and y > rect.minY and y < rect.maxY then
                                    if rect.missingVertex then
                                        local xr = (x - rect.minX)/(rect.maxX - rect.minX)
                                        local yr = (y - rect.minY)/(rect.maxY - rect.minY)
                                        if rect.missingVertex == "topright" then
                                            if xr + yr < 1 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif rect.missingVertex == "topleft" then
                                            if  xr - yr > 0 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif rect.missingVertex == "bottomleft" then
                                            if xr + yr > 1 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif xr - yr < 0 then
                                            returnTable[#returnTable + 1] = actor.host
                                        end
                                    else
                                        returnTable[#returnTable + 1] = actor.host
                                    end
                                    break
                                end
                            end
                        end
                        actor = actor.nextInCell[cell]
                    end
                else
                    for __ = 1, cell.numActors do
                        if not alreadyEnumerated[actor] and HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) then
                            alreadyEnumerated[actor] = true
                            x = actor.x[actor.anchor]
                            y = actor.y[actor.anchor]
                            for __, rect in ipairs(rects) do
                                if x > rect.minX and x < rect.maxX and y > rect.minY and y < rect.maxY then
                                    if rect.missingVertex then
                                        local xr = (x - rect.minX)/(rect.maxX - rect.minX)
                                        local yr = (y - rect.minY)/(rect.maxY - rect.minY)
                                        if rect.missingVertex == "topright" then
                                            if xr + yr < 1 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif rect.missingVertex == "topleft" then
                                            if  xr - yr > 0 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif rect.missingVertex == "bottomleft" then
                                            if xr + yr > 1 then
                                                returnTable[#returnTable + 1] = actor.host
                                            end
                                        elseif xr - yr < 0 then
                                            returnTable[#returnTable + 1] = actor.host
                                        end
                                    else
                                        returnTable[#returnTable + 1] = actor.host
                                    end
                                end
                            end
                        end
                        actor = actor.nextInCell[cell]
                    end
                end
            end
        end

        for key, __ in pairs(alreadyEnumerated) do
            alreadyEnumerated[key] = nil
        end

        return returnTable
    end

    ---Performs the action on all objects within a region that have the specified identifier. The region does not use the native region type, but is represented by a rect array or a table array, where each table must hold the minX, minY, maxX, and maxY fields. Region data is cached on the first call and the region object must not change afterwards. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into both the filter and the action function.
    ---@param action function
    ---@param whichRegion rect[] | table[]
    ---@param identifier string | table
    ---@param condition? function
    ---@vararg any
    function ALICE_ForAllObjectsInRegionDo(action, whichRegion, identifier, condition, ...)
        local list = ALICE_EnumObjectsInRegion(whichRegion, identifier, condition, ...)
        for __, object in ipairs(list) do
            action(object, ...)
        end
        ReturnTable(list)
    end

    ---Returns the closest object to a point from among objects with the specified identifier. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional condition to specify an additional filter function, which takes the enumerated objects as an argument and returns a boolean. Additional arguments are passed into the filter function.
    ---@param x number
    ---@param y number
    ---@param identifier string | table
    ---@param cutOffDistance? number
    ---@param condition? function
    ---@vararg any
    ---@return Object | nil
    function ALICE_GetClosestObject(x, y, identifier, cutOffDistance, condition, ...)
        ResetCoordinateLookupTables()

        cutOffDistance = cutOffDistance or 99999

        local minX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x - cutOffDistance - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local minY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y - cutOffDistance - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))
        local maxX = min(NUM_CELLS_X, max(1, (NUM_CELLS_X*(x + cutOffDistance - MAP_MIN_X)/MAP_SIZE_X) // 1 + 1))
        local maxY = min(NUM_CELLS_Y, max(1, (NUM_CELLS_Y*(y + cutOffDistance - MAP_MIN_Y)/MAP_SIZE_Y) // 1 + 1))

        local dx, dy
        local closestDistSquared = cutOffDistance*cutOffDistance
        local closestObject, thisDistSquared
        local identifierIsString = type(identifier) == "string"

        local actor, cell
        for X = minX, maxX do
            for Y = minY, maxY do
                cell = CELL_LIST[X][Y]
                actor = cell.first
                if actor then
                    if identifierIsString then
                        for __ = 1, cell.numActors do
                            dx = actor.x[actor.anchor] - x
                            dy = actor.y[actor.anchor] - y
                            thisDistSquared = dx*dx + dy*dy
                            if thisDistSquared < closestDistSquared and actor.identifier[identifier] and (condition == nil or condition(actor.host, ...)) and not actor.isSuspended then
                                closestDistSquared = thisDistSquared
                                closestObject = actor.host
                            end
                            actor = actor.nextInCell[cell]
                        end
                    else
                        for __ = 1, cell.numActors do
                            dx = actor.x[actor.anchor] - x
                            dy = actor.y[actor.anchor] - y
                            thisDistSquared = dx*dx + dy*dy
                            if thisDistSquared < closestDistSquared and HasIdentifierFromTable(actor, identifier) and (condition == nil or condition(actor.host, ...)) and not actor.isSuspended then
                                closestDistSquared = thisDistSquared
                                closestObject = actor.host
                            end
                            actor = actor.nextInCell[cell]
                        end
                    end
                end
            end
        end

        return closestObject
    end

    --Debug API
    --===========================================================================================================================================================

    ---Display warnings in the actor tooltips and crash messages of actors interacting with the specified function or list of functions if the listed fields are not present in the host table. requiredOnMale and requiredOnFemale control whether the field is expected to exist in the host table of the initiating (male) or receiving (female) actor of the interaction. Strings or string sequences specify fields that always need to be present. A table entry {optionalField = requiredField} denotes that requiredField must be present only if optionalField is also present in the table. requiredField can be a string or string sequence.
    ---@param whichFunc function | function[]
    ---@param requiredOnMale boolean
    ---@param requiredOnFemale boolean
    ---@vararg string | string[] | table<string,string|table>
    function ALICE_FuncRequireFields(whichFunc, requiredOnMale, requiredOnFemale, ...)
        local entry
        whichFunc = type(whichFunc) == "function" and {whichFunc} or whichFunc

        local actors = {
            male = requiredOnMale or nil,
            female = requiredOnFemale or nil
        }

        for actorType, __ in pairs(actors) do
            for __, func in pairs(whichFunc) do
                functionRequiredFields[func] = functionRequiredFields[func] or {}
                if requiredOnMale then
                    functionRequiredFields[func][actorType] = functionRequiredFields[func][actorType] or {}
                    for i = 1, select("#", ...) do
                        entry = select(i, ...)
                        entry = type(entry) == "string" and {entry} or entry
                        for key, value in pairs(entry) do
                            if type(key) == "string" then
                                if type(value) == "table" then
                                    for __, subvalue in ipairs(value) do
                                        functionRequiredFields[func][actorType][subvalue] = key
                                    end
                                else
                                    functionRequiredFields[func][actorType][value] = key
                                end
                            else
                                functionRequiredFields[func][actorType][value] = true
                            end
                        end
                    end
                end
            end
        end
    end

    ---Sets the name of a function when displayed in debug mode.
    ---@param whichFunc function
    ---@param name string
    function ALICE_FuncSetName(whichFunc, name)
        debug.functionName[whichFunc] = name
    end

    ---Enable or disable debug mode.
    ---@param enable? boolean
    function ALICE_Debug(enable)
        if enable == nil or (not debug.enabled and enable == true) or (debug.enabled and enable == false) then
            EnableDebugMode()
        end
    end

    ---List all global actors.
    function ALICE_ListGlobals()
        local message = "List of all global actors:"
        for __, actor in ipairs(celllessActorList) do
            if actor.isGlobal then
                message = message .. "\n" .. Identifier2String(actor.identifier) .. ", Unique: " .. actor.unique
            end
        end
        Warning(message)
    end

    ---Select the actor of the specified object if qualifier is an object, the first actor encountered with the specified identifier if qualifier is a string, or the actor with the specified unique number if qualifier is an integer. Requires debug mode.
    ---@param qualifier Object | integer | string
    function ALICE_Select(qualifier)
        if not debug.enabled then
            Warning("|cffff0000Error:|r ALICE_Select is only available in debug mode.")
            return
        end
        if type(qualifier) == "number" then
            for __, actor in ipairs(actorList) do
                if actor.unique == qualifier then
                    Select(actor)
                    SetCameraPosition(ALICE_GetCoordinates2D(actor))
                    return
                end
            end
            Warning("\nNo actor exists with the specified unique number.")
        elseif type(qualifier) == "string" then
            for __, actor in ipairs(actorList) do
                if actor.identifier[qualifier] then
                    Select(actor)
                    SetCameraPosition(ALICE_GetCoordinates2D(actor))
                    return
                end
            end
            Warning("\nNo actor exists with the specified identifier.")
        else
            local actor = GetActor(qualifier)
            if actor then
                Select(qualifier)
                SetCameraPosition(ALICE_GetCoordinates2D(actor))
            else
                Warning("\nNo actor exists for the specified object.")
            end
        end
    end

    ---Returns the host of the actor currently selected in debug mode.
    ---@return Object | nil
    function ALICE_GetSelectedObject()
        if debug.selectedActor then
            return debug.selectedActor.host
        end
        return nil
    end

    ---Returns whether an actor attached to the specified object is selected.
    function ALICE_IsSelected(whichObject)
        local actor = actorOf[whichObject]
        if actor.isActor then
            return actor == debug.selectedActor
        else
            for i = 1, #actor do
                if actor[i] == debug.selectedActor then
                    return true
                end
            end
            return false
        end
    end

    ---Returns true if one of the actors in the current pair is selected.
    ---@return boolean
    function ALICE_PairIsSelected()
        return debug.selectedActor == currentPair[0x1] or debug.selectedActor == currentPair[0x2]
    end

    ---Pause the entire cycle. Optional pauseGame parameter to pause all units on the map.
    ---@param pauseGame? boolean
    function ALICE_Halt(pauseGame)
        cycle.isHalted = true
        PauseTimer(timers.MASTER)
        if config.INTERPOLATION_INTERVAL then
            PauseTimer(timers.INTERPOLATION)
        end
        if pauseGame then
            ALICE_ForAllObjectsDo(PauseUnit, "unit", nil, true)
        end
        debug.gameIsPaused = pauseGame
    end

    ---Go to the next step in the cycle.
    function ALICE_NextStep()
        Main(true)
    end

    ---Resume the entire cycle.
    function ALICE_Resume()
        cycle.isHalted = false
        TimerStart(timers.MASTER, config.MIN_INTERVAL, true, Main)
        if config.INTERPOLATION_INTERVAL then
            TimerStart(timers.INTERPOLATION, config.INTERPOLATION_INTERVAL, true, Interpolate)
        end
        if debug.gameIsPaused then
            ALICE_ForAllObjectsDo(PauseUnit, "unit", nil, false)
            debug.gameIsPaused = false
        end
    end

    ---Prints out statistics showing which functions are occupying which percentage of the calculations.
    function ALICE_Statistics()
        local countActivePairs = 0
        local functionCount = {}

        --Every Step Cycle
        local thisPair = firstEveryStepPair
        for __ = 1, numEveryStepPairs do
            thisPair = thisPair[0x5]
            if not thisPair.destructionQueued then
                functionCount[thisPair[0x8]] = (functionCount[thisPair[0x8]] or 0) + 1
                countActivePairs = countActivePairs + 1
            end
        end

        local currentCounter = cycle.counter + 1
        --Variable Step Cycle
        local pairsThisStep = whichPairs[currentCounter]
        for i = 1, numPairs[currentCounter] do
            thisPair = pairsThisStep[i]
            if not thisPair.destructionQueued then
                functionCount[thisPair[0x8]] = (functionCount[thisPair[0x8]] or 0) + 1
                countActivePairs = countActivePairs + 1
            end
        end

        if countActivePairs == 0 then
            return "\nThere are no functions currently being evaluated."
        end

        local statistic = "Here is a breakdown of the functions currently being evaluated:"

        local sortedKeys = {}
        local count = 0
        for key, __ in pairs(functionCount) do
            count = count + 1
            sortedKeys[count] = key
        end
        sort(sortedKeys, function(a, b) return functionCount[a] > functionCount[b] end)

        for __, functionType in ipairs(sortedKeys) do
            if (100*functionCount[functionType]/countActivePairs) > 0.1 then
                statistic = statistic .. "\n" .. string.format("\x25.2f", 100*functionCount[functionType]/countActivePairs) .. "\x25 |cffffcc00" .. Function2String(functionType) .. "|r |cffaaaaaa(" .. functionCount[functionType] .. ")|r"
            end
        end

        print(statistic)
    end

    ---Continuously prints the cycle evaluation time and the number of actors, pair interactions, and cell checks until disabled.
    function ALICE_Benchmark()
        debug.benchmark = not debug.benchmark
    end

    ---Attempts to find the pair of the specified objects and prints the state of that pair. Pass integers to select by unique numbers. Possible return values are "active", "outofrange", "paused", "disabled", and "uninitialized".  Optional keyword parameters to specify actor with the keyword in its identifier for objects with multiple actors.
    ---@param objectA Object | integer
    ---@param objectB Object | integer
    ---@param keywordA? string
    ---@param keywordB? string
    ---@return string
    function ALICE_GetPairState(objectA, objectB, keywordA, keywordB)
        local actorA, actorB
        if type(objectA) == "number" then
            for __, actor in ipairs(actorList) do
                if actor.unique == objectA then
                    actorA = actor
                    break
                end
            end
            if actorA == nil then
                Warning("\nNo actor exists with unique number " .. objectA .. ".")
            end
        else
            actorA = GetActor(objectA, keywordA)
            if actorA == nil then
                Warning("\nNo actor exists for the specified object.")
            end
        end

        if type(objectB) == "number" then
            for __, actor in ipairs(actorList) do
                if actor.unique == objectB then
                    actorB = actor
                    break
                end
            end
            if actorB == nil then
                Warning("\nNo actor exists with unique number " .. objectB .. ".")
            end
        else
            actorB = GetActor(objectB, keywordB)
            if actorB == nil then
                Warning("\nNo actor exists for the specified object.")
            end
        end

        local thisPair = pairList[actorA][actorB] or pairList[actorB][actorA]
        if thisPair then
            if thisPair.paused then
                return "paused"
            elseif (thisPair[0x7] and thisPair[0x6]) or (not thisPair[0x7] and thisPair[0x5] ~= DO_NOT_EVALUATE) then
                return "active"
            else
                return "outofrange"
            end
        elseif pairingExcluded[actorA][actorB] then
            return "disabled"
        else
            return "uninitialized"
        end
    end

    ---Create lightning effects around all cells.
    function ALICE_VisualizeAllCells()
        debug.visualizeAllCells = not debug.visualizeAllCells

        if debug.visualizeAllCells then
            for X = 1, NUM_CELLS_X do
                for Y = 1, NUM_CELLS_Y do
                    local minx = MAP_MIN_X + (X-1)/NUM_CELLS_X*MAP_SIZE_X
                    local miny = MAP_MIN_Y + (Y-1)/NUM_CELLS_Y*MAP_SIZE_Y
                    local maxx = MAP_MIN_X + X/NUM_CELLS_X*MAP_SIZE_X
                    local maxy = MAP_MIN_Y + Y/NUM_CELLS_Y*MAP_SIZE_Y
                    CELL_LIST[X][Y].horizontalLightning = AddLightning("DRAM", false, minx, miny, maxx, miny)
                    SetLightningColor(CELL_LIST[X][Y].horizontalLightning, 1, 1, 1, 0.35)
                    CELL_LIST[X][Y].verticalLightning = AddLightning("DRAM", false, maxx, miny, maxx, maxy)
                    SetLightningColor(CELL_LIST[X][Y].verticalLightning, 1, 1, 1, 0.35)
                end
            end
        else
            for X = 1, NUM_CELLS_X do
                for Y = 1, NUM_CELLS_Y do
                    DestroyLightning(CELL_LIST[X][Y].horizontalLightning)
                    DestroyLightning(CELL_LIST[X][Y].verticalLightning)
                end
            end
        end
    end

    ---Creates arrows above all non-global actors.
    function ALICE_VisualizeAllActors()
        debug.visualizeAllActors = not debug.visualizeAllActors

        if debug.visualizeAllActors then
            for __, actor in ipairs(actorList) do
                if not actor.isGlobal and actor ~= debug.selectedActor then
                    CreateVisualizer(actor)
                end
            end
        else
            for __, actor in ipairs(actorList) do
                if not actor.isGlobal and actor ~= debug.selectedActor then
                    DestroyEffect(actor.visualizer)
                end
            end
        end
    end

    --Pair Utility API
    --===========================================================================================================================================================

    ---Returns true if the owners of the objects in the current pair are allies.
    ---@return boolean
    function ALICE_PairIsFriend()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]
        local ownerA = actorA.getOwner(actorA.host)
        local ownerB = actorB.getOwner(actorB.host)

        return IsPlayerAlly(ownerA, ownerB)
    end

    ---Returns true if the owners of the objects in the current pair are enemies.
    ---@return boolean
    function ALICE_PairIsEnemy()
        local actorA = currentPair[0x1]
        local actorB = currentPair[0x2]
        local ownerA = actorA.getOwner(actorA.host)
        local ownerB = actorB.getOwner(actorB.host)

        return IsPlayerEnemy(ownerA, ownerB)
    end

    ---Changes the interactionFunc of the pair currently being evaluated. You cannot replace a function without a return value with one that has a return value.
    ---@param whichFunc function
    function ALICE_PairSetInteractionFunc(whichFunc)
        if currentPair[0x2] == SELF_INTERACTION_ACTOR then
            currentPair[0x1].selfInteractions[currentPair[0x8]] = nil
            currentPair[0x1].selfInteractions[whichFunc] = currentPair
        end

        currentPair[0x8] = whichFunc
    end

    ---Disables interactions between the actors of the current pair after this one.
    function ALICE_PairDisable()
        if not functionIsUnbreakable[currentPair[0x8]] and currentPair[0x2] ~= SELF_INTERACTION_ACTOR then
            pairingExcluded[currentPair[0x1]][currentPair[0x2]] = true
            pairingExcluded[currentPair[0x2]][currentPair[0x1]] = true
        end

        if currentPair.destructionQueued then
            return
        end

        if currentPair[0x2] == SELF_INTERACTION_ACTOR then
            currentPair[0x1].selfInteractions[currentPair[0x8]] = nil
        end

        currentPair.destructionQueued = true
        AddDelayedCallback(DestroyPair, currentPair)
    end

    ---Modifies the return value of an interactionFunc so that, on average, the interval is the specified value, even if it isn't an integer multiple of the minimum interval.
    ---@param value number
    ---@return number
    function ALICE_PairPreciseInterval(value)
        local ALICE_MIN_INTERVAL = config.MIN_INTERVAL
        local data = ALICE_PairLoadData()
        local numSteps = (value*INV_MIN_INTERVAL + 1) // 1
        local newDelta = (data.returnDelta or 0) + value - ALICE_MIN_INTERVAL*numSteps
        if newDelta > 0.5*ALICE_MIN_INTERVAL then
            newDelta = newDelta - ALICE_MIN_INTERVAL
            numSteps = numSteps + 1
            data.returnDelta = newDelta
        elseif newDelta < -0.5*ALICE_MIN_INTERVAL then
            newDelta = newDelta + ALICE_MIN_INTERVAL
            numSteps = numSteps - 1
            data.returnDelta = newDelta
            if numSteps == 0 and not currentPair.destructionQueued then
                currentPair[0x8](currentPair[0x3], currentPair[0x4])
            end
        else
            data.returnDelta = newDelta
        end
        return ALICE_MIN_INTERVAL*numSteps
    end

    ---Returns false if this function was invoked for another pair that has the same interactionFunc and the same receiving actor. Otherwise, returns true. In other words, only one pair can execute the code within an ALICE_PairIsUnoccupied() block.
    function ALICE_PairIsUnoccupied()
        if currentPair[0x2][currentPair[0x8]] and currentPair[0x2][currentPair[0x8]] ~= currentPair then
            return false
        else
            --Store for the female actor at the key of the interaction func the current pair as occupying that slot, blocking other pairs.
            currentPair[0x2][currentPair[0x8]] = currentPair
            return true
        end
    end

    ---Returns the remaining cooldown for this pair, then invokes a cooldown of the specified duration. Optional cooldownType parameter to create and differentiate between multiple separate cooldowns.
    ---@param duration number
    ---@param cooldownType? string
    ---@return number
    function ALICE_PairCooldown(duration, cooldownType)
        currentPair.cooldown = currentPair.cooldown or GetTable()
        local key = cooldownType or "default"
        local cooldownExpiresStep = currentPair.cooldown[key]

        if cooldownExpiresStep == nil or cooldownExpiresStep <= cycle.unboundCounter then
            currentPair.cooldown[key] = cycle.unboundCounter + (duration*INV_MIN_INTERVAL + 1) // 1
            return 0
        else
            return (cooldownExpiresStep - cycle.unboundCounter)*config.MIN_INTERVAL
        end
    end

    ---Returns a table unique to the pair currently being evaluated, which can be used to read and write data. Optional argument to set a metatable for the data table.
    ---@param whichMetatable? table
    ---@return table
    function ALICE_PairLoadData(whichMetatable)
        if currentPair.userData == nil then
            currentPair.userData = GetTable()
            setmetatable(currentPair.userData, whichMetatable)
        end
        return currentPair.userData
    end

    ---Returns true if this is the first time this function was invoked for the current pair, otherwise false. Resets when the objects in the pair leave the interaction range.
    ---@return boolean
    function ALICE_PairIsFirstContact()
        if currentPair.hadContact == nil then
            currentPair.hadContact = true
            return true
        else
            return false
        end
    end

    ---Calls the initFunc with the hosts as arguments whenever a pair is created with the specified interactions.
    ---@param whichFunc function
    ---@param initFunc function
    function ALICE_FuncSetInit(whichFunc, initFunc)
        functionInitializer[whichFunc] = initFunc
    end

    ---Executes the function onDestroyFunc(objectA, objectB, pairData) when a pair using the specified function is destroyed or a callback using that function expires or is disabled. Only one callback per function.
    ---@param whichFunc function
    ---@param onDestroyFunc function
    function ALICE_FuncSetOnDestroy(whichFunc, onDestroyFunc)
        functionOnDestroy[whichFunc] = onDestroyFunc
    end

    ---Executes the function onBreakFunc(objectA, objectB, pairData, wasDestroyed) when a pair using the specified function is destroyed or the actors leave interaction range. Only one callback per function.
    ---@param whichFunc function
    ---@param onBreakFunc function
    function ALICE_FuncSetOnBreak(whichFunc, onBreakFunc)
        functionOnBreak[whichFunc] = onBreakFunc
    end

    ---Executes the function onResetFunc(objectA, objectB, pairData, wasDestroyed) when a pair using the specified function is destroyed, the actors leave interaction range, or the ALICE_PairReset function is called, but only if ALICE_PairIsFirstContact has been called previously. Only one callback per function.
    ---@param whichFunc function
    ---@param onResetFunc function
    function ALICE_FuncSetOnReset(whichFunc, onResetFunc)
        functionOnReset[whichFunc] = onResetFunc
    end

    ---Purge pair data, call onDestroy method and reset ALICE_PairIsFirstContact and ALICE_PairIsUnoccupied functions.
    function ALICE_PairReset()
        if currentPair.hadContact then
            if functionOnReset[currentPair[0x8]] and not cycle.isCrash then
                functionOnReset[currentPair[0x8]](currentPair[0x3], currentPair[0x4], currentPair.userData, false)
            end
            currentPair.hadContact = nil
        end

        if currentPair[0x2][currentPair[0x8]] == currentPair then
            currentPair[0x2][currentPair[0x8]] = nil
        end
    end

    --Repeatedly calls the interaction function of the current pair at a rate of the ALICE_Config.INTERPOLATION_INTERVAL until the next main step. A true is passed into the interaction function as the third parameter if it is called from within the interpolation loop.
    function ALICE_PairInterpolate()
        if not isInterpolated then
            interpolatedPairs[#interpolatedPairs + 1] = currentPair
        end
    end

    --Widget API
    --===========================================================================================================================================================

    ---Widgets with the specified fourCC codes will always receive actors, indepedent of the config or whether they have the Locust ability.
    ---@vararg string | integer
    function ALICE_IncludeTypes(...)
        for i = 1, select("#", ...) do
            local whichType = select(i, ...)
            if type(whichType) == "string" then
                widgets.idInclusions[FourCC(whichType)] = true
            else
                widgets.idInclusions[whichType] = true
            end
        end
    end

    ---Widgets with the specified fourCC codes will not receive actors, indepedent of the config.
    ---@vararg string | integer
    function ALICE_ExcludeTypes(...)
        for i = 1, select("#", ...) do
            local whichType = select(i, ...)
            if type(whichType) == "string" then
                widgets.idExclusions[FourCC(whichType)] = true
            else
                widgets.idExclusions[whichType] = true
            end
        end
    end

    ---Injects the functions listed in the hookTable into the hooks created by ALICE. The hookTable can have the keys: onUnitEnter - The listed function is called for all preplaced units and whenever a unit enters the map or a hero is revived. onUnitDeath - The listed function is called when a unit dies. onUnitRevive - The listed function is called when a nonhero unit is revived. onUnitRemove - The listed function is called when a unit is removed from the game or its corpse decays fully. onUnitChangeOwner - The listed function is called when a unit changes owner. onDestructableEnter - The listed function is called for all preplaced destructables and whenever a destructable is created. onDestructableDestroy - The listed function is called when a destructable dies or is removed. onItemEnter - The listed function is called for all preplaced items and whenever an item is dropped or created. onItemDestroy - The listed function is called when an item is destroyed, removed, or picked up.
    ---@param hookTable table
    function ALICE_OnWidgetEvent(hookTable)
        insert(eventHooks.onUnitEnter, hookTable.onUnitEnter)
        insert(eventHooks.onUnitDeath, hookTable.onUnitDeath)
        insert(eventHooks.onUnitRevive, hookTable.onUnitRevive)
        insert(eventHooks.onUnitRemove, hookTable.onUnitRemove)
        insert(eventHooks.onUnitChangeOwner, hookTable.onUnitChangeOwner)
        insert(eventHooks.onDestructableEnter, hookTable.onDestructableEnter)
        insert(eventHooks.onDestructableDestroy, hookTable.onDestructableDestroy)
        insert(eventHooks.onItemEnter, hookTable.onItemEnter)
        insert(eventHooks.onItemDestroy, hookTable.onItemDestroy)

        for key, __ in pairs(hookTable) do
            if not eventHooks[key] then
                Warning("|cffff0000Warning:|r Unrecognized key " .. key .. " in hookTable passed to ALICE_OnWidgetEvent.")
            end
        end

        if hookTable.onDeath and not config.UNITS_LEAVE_BEHIND_CORPSES then
            Warning("|cffff0000Warning:|r Attempted to create onDeath unit event hook, but ALICE_UNITS_LEAVE_BEHIND_CORPSES is not enabled. Use onRemove instead.")
        end
    end

    --Identifier API
    --===========================================================================================================================================================

    ---Add identifier(s) to an object and pair it with all other objects it is now eligible to be paired with. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param newIdentifier string | string[]
    ---@param keyword? string
    function ALICE_AddIdentifier(object, newIdentifier, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil or newIdentifier == nil then
            return
        end

        if type(newIdentifier) == "string" then
            actor.identifier[newIdentifier] = true
        else
            for __, word in ipairs(newIdentifier) do
                actor.identifier[word] = true
            end
        end

        AssignActorClass(actor, true, false)
        DestroyObsoletePairs(actor)
        AddDelayedCallback(Flicker, actor)
    end

    ---Remove identifier(s) from an object and remove all pairings with objects it is no longer eligible to be paired with. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param toRemove string | string[]
    ---@param keyword? string
    function ALICE_RemoveIdentifier(object, toRemove, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil or toRemove == nil then
            return
        end

        if type(toRemove) == "string" then
            if actor.identifier[toRemove] == nil then
                return
            end
            actor.identifier[toRemove] = nil
        else
            local removedSomething = false
            for __, word in ipairs(toRemove) do
                if actor.identifier[word] then
                    removedSomething = true
                    actor.identifier[word] = nil
                end
            end
            if not removedSomething then
                return
            end
        end

        AssignActorClass(actor, true, false)
        DestroyObsoletePairs(actor)
        AddDelayedCallback(Flicker, actor)
    end

    ---Exchanges one of the object's identifier with another. If the old identifier is not found, the new one won't be added. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param oldIdentifier string
    ---@param newIdentifier string
    ---@param keyword? string
    function ALICE_SwapIdentifier(object, oldIdentifier, newIdentifier, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil or oldIdentifier == nil or newIdentifier == nil then
            return
        end

        if actor.identifier[oldIdentifier] == nil then
            return
        end

        actor.identifier[oldIdentifier] = nil
        actor.identifier[newIdentifier] = true

        AssignActorClass(actor, true, false)
        DestroyObsoletePairs(actor)
        AddDelayedCallback(Flicker, actor)
    end

    ---Sets the object's identifier to a string or string sequence.
    ---@param object Object
    ---@param newIdentifier string | string[]
    ---@param keyword? string
    function ALICE_SetIdentifier(object, newIdentifier, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil or newIdentifier == nil then
            return
        end

        for word, __ in pairs(actor.identifier) do
            actor.identifier[word] = nil
        end
        if type(newIdentifier) == "string" then
            actor.identifier[newIdentifier] = true
        else
            for __, word in ipairs(newIdentifier) do
                actor.identifier[word] = true
            end
        end

        AssignActorClass(actor, true, false)
        DestroyObsoletePairs(actor)
        AddDelayedCallback(Flicker, actor)
    end

    ---Checks if the object has the specified identifiers. Identifier can be a string or a table. If it is a table, the last entry must be MATCHING_TYPE_ANY or MATCHING_TYPE_ALL. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param identifier string | table
    ---@param keyword? string
    ---@return boolean
    function ALICE_HasIdentifier(object, identifier, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil or identifier == nil then
            return false
        end

        if type(identifier) == "string" then
            return actor.identifier[identifier] == true
        else
            return HasIdentifierFromTable(actor, identifier)
        end
    end

    ---Compiles the identifiers of an object into the provided table or a new table. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param keyword? string
    ---@param table? table
    function ALICE_GetIdentifier(object, keyword, table)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end
        local returnTable = table or {}
        for key, __ in pairs(actor.identifier) do
            insert(returnTable, key)
        end
        sort(returnTable)
        return returnTable
    end

    ---Returns the first entry in the given list of identifiers for which an actor exists for the specified object.
    ---@param object Object
    ---@vararg ... string
    ---@return string | nil
    function ALICE_FindIdentifier(object, ...)
        local identifier
        local actorOf = actorOf[object]
        if actorOf == nil then
            return nil
        end

        if actorOf.isActor then
            for i = 1, select("#", ...) do
                identifier = select(i, ...)
                if identifier and actorOf.identifier[identifier] then
                    return identifier
                end
            end
        else
            for __, actor in ipairs(actorOf) do
                for i = 1, select("#", ...) do
                    identifier = select(i, ...)
                    if actor.identifier[identifier] then
                        return identifier
                    end
                end
            end
        end
        return nil
    end

    ---If table is a table with identifier keys, returns the field that matches with the specified object's identifier. If no match is found, returns table.other. If table is not a table, returns the variable itself. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param table any
    ---@param object Object
    ---@param keyword? string
    ---@return any
    function ALICE_FindField(table, object, keyword)
        if type(table) ~= "table" then
            return table
        end

        local actor = GetActor(object, keyword)
        if actor == nil then
            return nil
        end

        local identifier = actor.identifier
        local entry
        local level = 0
        local conflict = false

        for key, value in pairs(table) do
            if type(key) == "string" then
                if identifier[key] then
                    if level < 1 then
                        entry = value
                        level = 1
                    elseif level == 1 then
                        conflict = true
                    end
                end
            else
                local match = true
                for __, tableKey in ipairs(key) do
                    if not identifier[tableKey] then
                        match = false
                        break
                    end
                end
                if match then
                    if #key > level then
                        entry = value
                        level = #key
                        conflict = false
                    elseif #key == level then
                        conflict = true
                    end
                end
            end
        end

        if entry == nil and table.other then
            return table.other
        end

        if conflict then
            Warning("Return value ambiguous in ALICE_FindField for " .. Identifier2String(object.identifier) .. ".")
            return nil
        end
        return entry
    end

    --Interaction API
    --===========================================================================================================================================================

    ---Changes the interaction function of the specified object towards the target identifier to the specified function or removes it. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param target string | string[]
    ---@param newFunc function | nil
    ---@param keyword? string
    function ALICE_SetInteractionFunc(object, target, newFunc, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        local oldFunc = actor.interactions[target]
        if oldFunc ~= newFunc then
            actor.interactions[target] = newFunc
            AssignActorClass(actor, false, true)
            if newFunc == nil then
                DestroyObsoletePairs(actor)
            elseif oldFunc == nil then
                AddDelayedCallback(Flicker, actor)
            else
                local next = actor.nextPair
                local pair = next[actor.firstPair]
                while pair do
                    if pair[0x8] == oldFunc then
                        pair[0x8] = newFunc
                    end
                    pair = next[pair]
                end
            end
        end
    end

    ---Adds a self-interaction with the specified function to the object. If a self-interaction with that function already exists, nothing happens. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors. Optional data parameter to initialize a data table that can be accessed with ALICE_PairLoadData.
    ---@param object Object
    ---@param whichFunc function
    ---@param keyword? string
    ---@param data? table
    function ALICE_AddSelfInteraction(object, whichFunc, keyword, data)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        if actor.selfInteractions[whichFunc] then
            return
        end

        actor.selfInteractions[whichFunc] = CreatePair(actor, SELF_INTERACTION_ACTOR, whichFunc)

        if data then
            local pairData = GetTable()
            for key, value in pairs(data) do
                pairData[key] = value
            end
            actor.selfInteractions[whichFunc].userData = pairData
        end
    end

    ---Removes the self-interaction with the specified function from the object. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param whichFunc function
    ---@param keyword? string
    function ALICE_RemoveSelfInteraction(object, whichFunc, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        if actor.selfInteractions[whichFunc] == nil then
            return
        end

        local pair = actor.selfInteractions[whichFunc]
        actor.selfInteractions[whichFunc] = nil

        pair.destructionQueued = true
        AddDelayedCallback(DestroyPair, pair)
    end

    ---Checks if the object has a self-interaction with the specified function. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param whichFunc function
    ---@param keyword? string
    ---@return boolean
    function ALICE_HasSelfInteraction(object, whichFunc, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return false
        end

        return actor.selfInteractions[whichFunc] ~= nil
    end

    --Misc API
    --===========================================================================================================================================================

    ---The first interaction of all pairs using this function will be delayed by the specified number.
    ---@param whichFunc function
    ---@param delay number
    function ALICE_FuncSetDelay(whichFunc, delay)
        if delay > config.MAX_INTERVAL then
            Warning("|cffff0000Warning:|r Delay specified in ALICE_FuncSetDelay is greater than ALICE_MAX_INTERVAL.")
        end
        functionDelay[whichFunc] = min(config.MAX_INTERVAL, delay)
    end

    ---Changes the behavior of pairs using the specified function so that the interactions continue to be evaluated when the two objects leave their interaction range. Also changes the behavior of ALICE_PairDisable to not prevent the two object from pairing again.
    ---@param whichFunc function
    function ALICE_FuncSetUnbreakable(whichFunc)
        functionIsUnbreakable[whichFunc] = true
    end

    ---Changes the behavior of the specified function such that pairs using this function will persist if a unit is loaded into a transport or an item is picked up by a unit.
    ---@param whichFunc function
    function ALICE_FuncSetUnsuspendable(whichFunc)
        functionIsUnsuspendable[whichFunc] = true
    end

    ---Automatically pauses and unpauses all pairs using the specified function whenever the initiating (male) actor is set to stationary/not stationary.
    ---@param whichFunc function
    function ALICE_FuncPauseOnStationary(whichFunc)
        functionPauseOnStationary[whichFunc] = true
    end

    ---Checks if an actor exists with the specified identifier for the specified object. Optional strict flag to exclude actors that are anchored to that object.
    ---@param object Object
    ---@param identifier string
    ---@param strict? boolean
    ---@return boolean
    function ALICE_HasActor(object, identifier, strict)
        local actor = GetActor(object, identifier)
        if actor == nil then
            return false
        end
        return not strict or actor.host == object
    end

    ---Returns the object the specified object is anchored to or itself if there is no anchor.
    ---@param object Object
    ---@return Object | nil
    function ALICE_GetAnchor(object)
        local actor = GetActor(object)
        if actor == nil then
            return object
        end

        return actor.originalAnchor
    end

    ---Accesses all objects anchored to the specified object and returns the one with the specified identifier.
    ---@param object Object
    ---@param identifier string
    ---@return Object | nil
    function ALICE_GetAnchoredObject(object, identifier)
        local actor = GetActor(object, identifier)
        if actor == nil then
            return nil
        end

        return actor.host
    end

    ---Sets the value of a flag for the actor of an object to the specified value. To change the isStationary flag, use ALICE_SetStationary instead. Cannot change hasInfiniteRange flag. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param whichFlag string
    ---@param value any
    ---@param keyword? string
    function ALICE_SetFlag(object, whichFlag, value, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        assert(RECOGNIZED_FLAGS[whichFlag], "Flag " .. whichFlag .. " is not recognized.")
        assert(SetFlag[whichFlag], "Flag " .. whichFlag .. " cannot be changed with ALICE_SetFlag.")

        SetFlag[whichFlag](actor, value)
    end

    ---Returns the value stored for the specified flag of the specified actor. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param whichFlag string
    ---@param keyword? string
    ---@return any
    function ALICE_GetFlag(object, whichFlag, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        assert(RECOGNIZED_FLAGS[whichFlag], "Flag " .. whichFlag .. " is not recognized.")

        if whichFlag == "radius" then
            return actor.halfWidth
        elseif whichFlag == "width" then
            return 2*actor.halfWidth
        elseif whichFlag == "height" then
            return 2*actor.halfHeight
        elseif whichFlag == "cellCheckInterval" then
            if actor.cellCheckInterval then
                return actor.cellCheckInterval*config.MIN_INTERVAL
            else
                return nil
            end
        elseif whichFlag == "anchor" then
            return actor.originalAnchor
        else
            return actor[whichFlag]
        end
    end

    ---Returns the owner of the specified object. Faster than GetOwningPlayer. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param keyword? string
    ---@return player?
    function ALICE_GetOwner(object, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return HandleType[object] == "unit" and GetOwningPlayer(object) or nil
        end

        return actor.getOwner(actor.host)
    end

    ---Instantly moves a unit, item, or gizmo to the specified coordinates and instantly updates that object's coordinate lookup tables and cells. If the z-coordinate is not specified and the object is a table, z is set to the terrain height of the target point. Works on stationary objects.
    ---@param object Object
    ---@param x number
    ---@param y number
    ---@param z? number
    function ALICE_Teleport(object, x, y, z)
        if type(object) == "table" then
            if object.anchor and object.anchor ~= object then
                error("Attempted to teleport object that is anchored to another object.")
            end

            object.x = x
            object.y = y
            if object.z then
                object.z = z or GetTerrainZ(x, y)
            end

            if object.visual then
                if HandleType[object.visual] == "effect" then
                    BlzSetSpecialEffectPosition(object.visual, x, y, object.z or GetTerrainZ(x, y))
                elseif HandleType[object.visual] == "unit" then
                    SetUnitX(object.visual, x)
                    SetUnitY(object.visual, y)
                elseif HandleType[object.visual] == "image" then
                    SetImagePosition(object.visual, x, y, object.z or GetTerrainZ(x, y))
                end
            end
        elseif HandleType[object] == "unit" then
            SetUnitX(object, x)
            SetUnitY(object, y)
        elseif HandleType[object] == "item" then
            SetItemPosition(object, x, y)
        else
            return
        end

        local anchor
        if actorOf[object].isActor then
            local actor = actorOf[object]
            anchor = actor.anchor
            actor.x[anchor], actor.y[anchor], actor.z[actor] = x, y, nil
            AddDelayedCallback(Flicker, actor)
        else
            for __, actor in ipairs(actorOf[object]) do
                anchor = actor.anchor
                actor.x[anchor], actor.y[anchor], actor.z[actor] = x, y, nil
                AddDelayedCallback(Flicker, actor)
            end
        end
    end

    --Pair Access API
    --===========================================================================================================================================================

    ---Restore a pair that has been previously destroyed with ALICE_PairDisable. Returns two booleans. The first denotes whether a pair now exists and the second if it was just created.
    ---@param objectA Object
    ---@param objectB Object
    ---@param keywordA? string
    ---@param keywordB? string
    ---@return boolean, boolean
    function ALICE_Enable(objectA, objectB, keywordA, keywordB)
        local actorA = GetActor(objectA, keywordA)
        local actorB = GetActor(objectB, keywordB)
        if actorA == nil or actorB == nil then
            return false, false
        end

        if pairingExcluded[actorA][actorB] == nil then
            if pairList[actorA][actorB] or pairList[actorB][actorA] then
                return true, false
            else
                return false, false
            end
        end

        pairingExcluded[actorA][actorB] = nil
        pairingExcluded[actorB][actorA] = nil

        if (not actorA.usesCells or not actorB.usesCells or SharesCellWith(actorA, actorB)) then
            local actorAFunc = GetInteractionFunc(actorA, actorB)
            local actorBFunc = GetInteractionFunc(actorB, actorA)
            if actorAFunc and actorBFunc then
                if actorA.priority < actorB.priority then
                    CreatePair(actorB, actorA, actorBFunc)
                    return true, true
                else
                    CreatePair(actorA, actorB, actorAFunc)
                    return true, true
                end
            elseif actorAFunc then
                CreatePair(actorA, actorB, actorAFunc)
                return true, true
            elseif actorBFunc then
                CreatePair(actorB, actorA, actorBFunc)
                return true, true
            end
        end

        return false, false
    end

    ---Access the pair for objects A and B and, if it exists, return the data table stored for that pair. If objectB is a function, returns the data of the self-interaction of objectA using the specified function.
    ---@param objectA Object
    ---@param objectB Object | function
    ---@param keywordA? string
    ---@param keywordB? string
    ---@return table | nil
    function ALICE_AccessData(objectA, objectB, keywordA, keywordB)
        local actorA = GetActor(objectA, keywordA)
        local actorB
        local whichPair

        if type(objectB) == "function" then
            whichPair = actorA.selfInteractions[objectB]
        else
            actorB = GetActor(objectB, keywordB)
            if actorA == nil or actorB == nil then
                return nil
            end
            whichPair = pairList[actorA][actorB] or pairList[actorB][actorA]
        end

        if whichPair then
            if whichPair.userData then
                return whichPair.userData
            else
                whichPair.userData = GetTable()
                return whichPair.userData
            end
        end
        return nil
    end

    ---Access the pair for objects A and B and, if it is paused, unpause it. If objectB is a function, unpauses the self-interaction of objectA using the specified function.
    ---@param objectA Object
    ---@param objectB Object | function
    ---@param keywordA? string
    ---@param keywordB? string
    function ALICE_UnpausePair(objectA, objectB, keywordA, keywordB)
        local actorA = GetActor(objectA, keywordA)
        local actorB
        local whichPair

        if type(objectB) == "function" then
            whichPair = actorA.selfInteractions[objectB]
        else
            actorB = GetActor(objectB, keywordB)
            if actorA == nil or actorB == nil then
                return nil
            end
            whichPair = pairList[actorA][actorB] or pairList[actorB][actorA]
        end

        if whichPair then
            AddDelayedCallback(UnpausePair, whichPair)
        end
    end

    ---Access the pair for objects A and B and, if it exists, perform the specified action. Returns the return value of the action function. The hosts of the pair as well as any additional parameters are passed into the action function. If objectB is a function, access the pair of the self-inteaction of objectA using the specified function.
    ---@param action function
    ---@param objectA Object
    ---@param objectB Object | function
    ---@param keywordA? string
    ---@param keywordB? string
    ---@vararg any
    ---@return any
    function ALICE_GetPairAndDo(action, objectA, objectB, keywordA, keywordB, ...)
        local actorA = GetActor(objectA, keywordA)
        local actorB
        local whichPair

        if type(objectB) == "function" then
            whichPair = actorA.selfInteractions[objectB]
        else
            actorB = GetActor(objectB, keywordB)
            if actorA == nil or actorB == nil then
                return nil
            end
            whichPair = pairList[actorA][actorB] or pairList[actorB][actorA]
        end

        if whichPair then
            local tempPair = currentPair
            currentPair = whichPair
            local returnValue = action(whichPair[0x3], whichPair[0x4], ...)
            currentPair = tempPair
            return returnValue
        end
    end

    ---Access all pairs for the object using the specified interactionFunc and perform the specified action. The hosts of the pairs as well as any additional parameters are passed into the action function. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param action function
    ---@param object Object
    ---@param whichFunc function
    ---@param includeInactive? boolean
    ---@param keyword? string
    ---@vararg any
    function ALICE_ForAllPairsDo(action, object, whichFunc, includeInactive, keyword, ...)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        local DO_NOT_EVALUATE = DO_NOT_EVALUATE

        local next = actor.nextPair
        local thisPair = next[actor.firstPair]
        local tempPair = currentPair
        while thisPair do
            if thisPair[0x8] == whichFunc and (includeInactive or (thisPair[0x7] and thisPair[0x6] ~= nil) or (not thisPair[0x7] and thisPair[0x5] ~= DO_NOT_EVALUATE)) then
                currentPair = thisPair
                action(thisPair[0x3], thisPair[0x4], ...)
            end
            thisPair = next[thisPair]
        end
        currentPair = tempPair
    end

    --Optimization API
    --===========================================================================================================================================================

    ---Pauses interactions of the current pair after this one. Resume with an unpause function.
    function ALICE_PairPause()
        AddDelayedCallback(PausePair, currentPair)
    end

    ---Unpauses all paused interactions of the object. Optional whichFunctions argument, which can be a function or a function sequence, to limit unpausing to pairs using those functions. Optional keyword parameter to specify actor with the keyword in its identifier for an object with multiple actors.
    ---@param object Object
    ---@param whichFunctions? function | table
    ---@param keyword? string
    function ALICE_Unpause(object, whichFunctions, keyword)
        local actor = GetActor(object, keyword)
        if actor == nil then
            return
        end

        if type(whichFunctions) == "table" then
            for key, value in ipairs(whichFunctions) do
                whichFunctions[value] = true
                whichFunctions[key] = nil
            end
        elseif whichFunctions then
            local functionsTable = GetTable()
            functionsTable[whichFunctions] = true
            whichFunctions = functionsTable
        end

        AddDelayedCallback(Unpause, actor, whichFunctions)
    end

    ---Sets an object to stationary/not stationary. Will affect all actors attached to the object.
    ---@param object Object
    ---@param enable? boolean
    function ALICE_SetStationary(object, enable)
        objectIsStationary[object] = enable ~= false
        if actorOf[object] == nil then
            return
        end
        if actorOf[object].isActor then
            if actorOf[object].usesCells then
                SetStationary(actorOf[object], enable ~= false)
            end
        else
            for __, actor in ipairs(actorOf[object]) do
                if actor.usesCells then
                    SetStationary(actor, enable ~= false)
                end
            end
        end
    end

    ---Returns whether the specified object is set to stationary.
    ---@param object Object
    function ALICE_IsStationary(object)
        return objectIsStationary[object]
    end

    ---The first interaction of all pairs using this function will be delayed by up to the specified number, distributing individual calls over the interval to prevent computation spikes.
    ---@param whichFunc function
    ---@param interval number
    function ALICE_FuncDistribute(whichFunc, interval)
        if interval > config.MAX_INTERVAL then
            Warning("|cffff0000Warning:|r Delay specified in ALICE_FuncDistribute is greater than ALICE_MAX_INTERVAL.")
        end
        functionDelay[whichFunc] = interval
        functionDelayIsDistributed[whichFunc] = true
        functionDelayCurrent[whichFunc] = 0
    end

    --Modular API
    --===========================================================================================================================================================

    ---Executes the specified function before an object with the specified identifier is created. The function is called with the host as the parameter.
    ---@param matchingIdentifier string
    ---@param whichFunc function
    function ALICE_OnCreation(matchingIdentifier, whichFunc)
        onCreation.funcs[matchingIdentifier] = onCreation.funcs[matchingIdentifier] or {}
        insert(onCreation.funcs[matchingIdentifier], whichFunc)
    end

    ---Add a flag with the specified value to objects with matchingIdentifier when they are created. If a function is provided for value, the returned value of the function will be added.
    ---@param matchingIdentifier string
    ---@param flag string
    ---@param value any
    function ALICE_OnCreationAddFlag(matchingIdentifier, flag, value)
        if not OVERWRITEABLE_FLAGS[flag] then
            error("Flag " .. flag .. " cannot be overwritten with ALICE_OnCreationAddFlag.")
        end
        onCreation.flags[matchingIdentifier] = onCreation.flags[matchingIdentifier] or {}
        onCreation.flags[matchingIdentifier][flag] = value
    end

    ---Adds an additional identifier to objects with matchingIdentifier when they are created. If a function is provided for value, the returned string of the function will be added.
    ---@param matchingIdentifier string
    ---@param value string | function
    function ALICE_OnCreationAddIdentifier(matchingIdentifier, value)
        onCreation.identifiers[matchingIdentifier] = onCreation.identifiers[matchingIdentifier] or {}
        insert(onCreation.identifiers[matchingIdentifier], value)
    end

    ---Adds an interaction to all objects with matchingIdentifier when they are created towards objects with the specified keyword in their identifier. To add a self-interaction, use ALICE_OnCreationAddSelfInteraction instead.
    ---@param matchingIdentifier string
    ---@param keyword string | string[]
    ---@param interactionFunc function
    function ALICE_OnCreationAddInteraction(matchingIdentifier, keyword, interactionFunc)
        onCreation.interactions[matchingIdentifier] = onCreation.interactions[matchingIdentifier] or {}
        if onCreation.interactions[matchingIdentifier][keyword] then
            Warning("|cffff0000Warning:|r Multiple interactionsFuncs added on creation to " .. matchingIdentifier .. " and " .. keyword .. ". Previous entry was overwritten.")
        end
        onCreation.interactions[matchingIdentifier][keyword] = interactionFunc
    end

    ---Adds a self-interaction to all objects with matchingIdentifier when they are created.
    ---@param matchingIdentifier string
    ---@param selfinteractions function
    function ALICE_OnCreationAddSelfInteraction(matchingIdentifier, selfinteractions)
        onCreation.selfInteractions[matchingIdentifier] = onCreation.selfInteractions[matchingIdentifier] or {}
        insert(onCreation.selfInteractions[matchingIdentifier], selfinteractions)
    end
    --#endregion
end
