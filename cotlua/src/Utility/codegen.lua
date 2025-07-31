--[[
    codegen.lua

    Credits: Original JASS by TriggerHappy

    This module provides functions to encode a table of integers into one string of characters that may be decoded and loaded in future games.
    Used for save / load functionality in playerdata.lua
]]

OnInit.global("CodeGen", function()
    local ALPHABET  = "!#$\x25&'()*+,-.0123456789:;=<>?[]^_{}|`@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" ---@type string 
    local MAX_SPACE = 6
    local BASE      = ALPHABET:len() - MAX_SPACE - 1
    local CHAR      = ALPHABET:sub(2, MAX_SPACE + 1)

    ---@param str string
    ---@param seed integer
    ---@return string
    local function pseudoRandomPermutation(str, seed)
        local oldSeed = math.random(0, 2147483647)
        math.randomseed(seed)

        local chars = {}
        for i = 1, #str do
            table.insert(chars, str:sub(i, i))
        end

        for i = #chars, 2, -1 do
            local j = math.random(i)
            chars[i], chars[j] = chars[j], chars[i]
        end

        math.randomseed(oldSeed)

        return table.concat(chars)
    end

    -- string scrambling init
    local scrambled = pseudoRandomPermutation(ALPHABET, SAVE_LOAD_VERSION)
    local SCRAMBLED = {}
    local UNSCRAMBLED = {}
    for i = 1, ALPHABET:len() do
        SCRAMBLED[ALPHABET:sub(i, i)] = scrambled:sub(i, i)
        UNSCRAMBLED[scrambled:sub(i, i)] = ALPHABET:sub(i, i)
    end

    -- remove delimiters
    ALPHABET = ALPHABET:sub(1, 1) .. ALPHABET:sub(MAX_SPACE + 2)

    local function scrambleString(whichString)
        local scrambledString = ""
        for i = 1, whichString:len() do
            scrambledString = scrambledString .. (SCRAMBLED[whichString:sub(i, i)] or whichString:sub(i, i))
        end
        return scrambledString
    end

    local function unscrambleString(whichString)
        local unscrambledString = ""
        for i = 1, whichString:len() do
            unscrambledString = unscrambledString .. (UNSCRAMBLED[whichString:sub(i, i)] or whichString:sub(i, i))
        end
        return unscrambledString
    end

    ---@param str string
    local function compress(str)
        local compressed = ""
        local i = 1

        while i <= #str do
            local sequence = str:sub(i, i)
            local count = 1

            while sequence == str:sub(i + count, i + count) do
                count = count + 1
            end

            if count > 2 and count < ALPHABET:len() + 2 then
                local char = ALPHABET:sub(count - 2, count - 2)
                compressed = compressed .. " " .. char .. sequence -- use a space to indicate compression
                i = i + (count - 1)
            else
                compressed = compressed .. sequence
            end

            i = i + 1
        end

        return compressed
    end

    ---@param str string
    local function decompress(str)
        str = str:gsub(" (\x25S)(\x25S)", function(symbol, sequence)
            local count = string.find(ALPHABET, symbol, nil, true) + 2

            return string.rep(sequence, count)
        end)

        return str
    end
    ---@param i integer
    ---@return string
    local function encode(i)
        local s = ""

        if i < BASE then
            return ALPHABET:sub(i + 1, i + 1)
        end

        while i > 0 do
            local b = i - (i // BASE) * BASE
            s = ALPHABET:sub(b + 1, b + 1) .. s
            i = i // BASE
        end

        return s
    end

    ---@param s string
    ---@return integer
    local function StrPos(s)
        local pos = ALPHABET:find(s, 1, true)

        if pos then
            return pos - 1
        end

        return -1
    end

    ---@param s string
    ---@return integer
    local function decode(s)
        local a = 0 ---@type integer 

        while s:len() ~= 1 do
            a = a * BASE + BASE * StrPos(s:sub(1, 1))
            s = s:sub(2)
        end

        return a + StrPos(s)
    end

    ---@param in_ string
    ---@return integer
    function StringChecksum(in_)
        local o = 0 ---@type integer 

        for i = 1, in_:len() do
            o = o + decode(in_:sub(i, i))
        end

        return o
    end

    ---@type fun(str: string, p: player): table?, string?
    function Decompile(str, p)
        local VALID = false
        str = decompress(unscrambleString(str))

        for i = 1, 3 do
            if decode(str:sub(1, i)) == StringChecksum(str:sub(i + 1)) then
                VALID = true
                str = str:sub(i + 1)
                break
            end
        end

        local checksum = encode(StringChecksum(GetPlayerName(p)))
        local checksum_len = checksum:len()

        if (not VALID) or checksum ~= str:sub(-checksum_len) then
            return nil, "|cffff0000Error: Invalid code|r"
        end

        str = str:sub(1, -checksum_len - 1)
        local data = {}
        i = 1

        while i <= #str do
            local tmp = str:sub(i, i)
            local token_length = (CHAR:find(tmp, 1, true) or 0) + 1

            -- ignore space indicator
            if token_length > 1 then
                i = i + 1
            end

            local token = str:sub(i, i + token_length - 1)
            data[#data + 1] = decode(token)
            i = i + token_length
        end

        return data
    end

    ---@type fun(pid: integer, data: table): string
    function Compile(pid, data)
        local out = "" ---@type string 
        local p   = Player(pid - 1)

        for _, v in ipairs(data) do
            local x = encode(v)
            local j = x:len()

            if (j > 1) then
                out = out .. CHAR:sub(j - 1, j - 1)
            end

            out = out .. x
        end

        -- appends player name checksum to end of string
        out = out .. encode(StringChecksum(GetPlayerName(p)))

        -- appends total checksum to beginning of string
        local cs = StringChecksum(out)
        out = encode(cs) .. out

        if DEV_ENABLED then
            print("Checksum: " .. cs .. " Encoded: " .. encode(cs))
        end

        return scrambleString(compress(out))
    end

end, Debug and Debug.getLine())
