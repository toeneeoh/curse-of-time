OnInit.global("Audio", function()
    ---@type fun(path: string, is3D: boolean, p: player|nil, u: unit|nil)
    function SoundHandler(path, is3D, p, u)
        local sound_path = ((p and GetLocalPlayer() ~= p) and "") or path
        local sound = CreateSound(sound_path, false, is3D, is3D, 12700, 12700, "")

        if u ~= nil then
            AttachSoundToUnit(sound, u)
        end

        StartSound(sound)
        KillSoundWhenDone(sound)
    end
end)
