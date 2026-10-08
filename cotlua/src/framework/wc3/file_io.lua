OnInit.global("FileIO", function()
--[[
    FileIO v1a

    Provides functionality to read and write files, optimized with lua functionality in mind.

    API:

        FileIO.Save(filename, data)
            - Write string data to a file

        FileIO.Load(filename) -> string?
            - Read string data from a file. Returns nil if file doesn't exist.

        FileIO.SaveAsserted(filename, data, onFail?) -> bool
            - Saves the file and checks that it was saved successfully.
              If it fails, passes (filename, data, loadResult) to onFail.

        FileIO.enabled : bool
            - field that indicates that files can be accessed correctly.

    Optional requirements:
        DebugUtils by Eikonium                          @ https://www.hiveworkshop.com/threads/330758/
        Total Initialization by Bribe                   @ https://www.hiveworkshop.com/threads/317099/

    Inspired by:
        - TriggerHappy's Codeless Save and Load         @ https://www.hiveworkshop.com/threads/278664/
        - ScrewTheTrees's Codeless Save/Sync concept    @ https://www.hiveworkshop.com/threads/325749/
        - Luashine's LUA variant of TH's FileIO         @ https://www.hiveworkshop.com/threads/307568/post-3519040
        - HerlySQR's LUA variant of TH's Save/Load      @ https://www.hiveworkshop.com/threads/331536/post-3565884

    Updated: 8 Mar 2023
--]]
    local RAW_PREFIX = ']]i([['
    local RAW_SUFFIX = ']])--[['
    local RAW_SIZE = 256 - #RAW_PREFIX - #RAW_SUFFIX
    local LOAD_ABILITY = FourCC('ANdc')
    local LOAD_EMPTY_KEY = '!@#$, empty data'

    local function open(filename)
        name = filename
        PreloadGenClear()
        Preload('")\nendfunction\n//!beginusercode\nlocal p={} local i=function(s) table.insert(p,s) end--[[')
    end

    local function write(s)
        for i = 1, #s, RAW_SIZE do
            Preload(RAW_PREFIX .. s:sub(i, i + RAW_SIZE - 1) .. RAW_SUFFIX)
        end
    end

    local function close()
        Preload(']]BlzSetAbilityTooltip(' .. LOAD_ABILITY .. ', table.concat(p), 0)\n//!endusercode\nfunction a takes nothing returns nothing\n//')
        PreloadGenEnd(name)
        name = nil
    end

    ---
    ---@param filename string
    ---@param data string
    local function savefile(filename, data)
        open(filename)
        write(data)
        close()
    end

    ---@param filename string
    ---@return string?
    local function loadfile(filename)
        local s = BlzGetAbilityTooltip(LOAD_ABILITY, 0)
        BlzSetAbilityTooltip(LOAD_ABILITY, LOAD_EMPTY_KEY, 0)
        Preloader(filename)
        local loaded = BlzGetAbilityTooltip(LOAD_ABILITY, 0)
        BlzSetAbilityTooltip(LOAD_ABILITY, s, 0)
        if loaded == LOAD_EMPTY_KEY then
            return nil
        end
        return loaded
    end

    ---@param filename string
    ---@param data string
    ---@param onFail function?
    ---@return boolean
    local function saveAsserted(filename, data, onFail)
        savefile(filename, data)
        local res = loadfile(filename)
        if res == data then
            return true
        end
        if onFail then
            onFail(filename, data, res)
        end
        return false
    end

    local fileIO_enabled = saveAsserted('TestFileIO.pld', 'FileIO is Enabled')

    FileIO = {
        Save = savefile,
        Load = loadfile,
        SaveAsserted = saveAsserted,
        enabled = fileIO_enabled,
    }
end, Debug and Debug.getLine())
