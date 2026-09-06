OnInit.global("PlayerCamera", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local custom_lighting = __jarray(0)

    local function update_lighting(pid, x, y)
        local daynight_model = DEFAULT_LIGHTING
        custom_lighting[pid] = 1

        if RectContainsCoords(gg_rct_Naga_Dungeon, x, y)
            and not RectContainsCoords(gg_rct_Naga_Dungeon_Reward, x, y) then
            custom_lighting[pid] = 2
        elseif RectContainsCoords(gg_rct_Naga_Dungeon_Boss, x, y) then
            custom_lighting[pid] = 2
        elseif RectContainsCoords(gg_rct_Cave, x, y) then
            custom_lighting[pid] = 3
        elseif RectContainsCoords(gg_rct_Crypt, x, y)
            or RectContainsCoords(gg_rct_Church, x, y) then
            custom_lighting[pid] = 4
        end

        if custom_lighting[pid] ~= 1 then daynight_model = "blacklight.mdx" end

        if custom_lighting[pid] == 1 then
            UnitRemoveAbility(Hero[pid], FourCC('A059'))
            UnitRemoveAbility(Hero[pid], FourCC('A0AN'))
            UnitRemoveAbility(Hero[pid], FourCC('A0B8'))
        elseif custom_lighting[pid] == 2 and GetUnitAbilityLevel(Hero[pid], FourCC('A0AN')) == 0 then
            UnitAddAbility(Hero[pid], FourCC('A0AN'))
            UnitRemoveAbility(Hero[pid], FourCC('A0B8'))
            UnitRemoveAbility(Hero[pid], FourCC('A059'))
        elseif custom_lighting[pid] == 3 and GetUnitAbilityLevel(Hero[pid], FourCC('A0B8')) == 0 then
            UnitAddAbility(Hero[pid], FourCC('A0B8'))
            UnitRemoveAbility(Hero[pid], FourCC('A0AN'))
            UnitRemoveAbility(Hero[pid], FourCC('A059'))
        elseif custom_lighting[pid] == 4 and GetUnitAbilityLevel(Hero[pid], FourCC('A059')) == 0 then
            UnitAddAbility(Hero[pid], FourCC('A059'))
            UnitRemoveAbility(Hero[pid], FourCC('A0AN'))
            UnitRemoveAbility(Hero[pid], FourCC('A0B8'))
        end

        if GetLocalPlayer() == Player(pid - 1) then
            SetDayNightModels(daynight_model, daynight_model)
        end
    end

    local function set_bounds(player, rect)
        local pid = GetPlayerId(player) + 1
        update_lighting(pid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))

        if GetLocalPlayer() == player then
            SetCameraField(CAMERA_FIELD_ROTATION, 90., 0)
            SetCameraBounds(GetRectMinX(rect), GetRectMinY(rect), GetRectMinX(rect),
                GetRectMaxY(rect), GetRectMaxX(rect), GetRectMaxY(rect),
                GetRectMaxX(rect), GetRectMinY(rect))
        end
    end

    ---@param pid integer
    function ResetPlayerLighting(pid)
        custom_lighting[pid] = 1
    end

    ---@type fun(pid: integer, texture: string)
    function SetMinimapTexture(pid, texture)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzChangeMinimapTerrainTex(texture)
        end
    end

    function SetCamera(pid, region)
        local data = REGION_DATA[region]
        if data.vision then set_bounds(Player(pid - 1), data.vision) end
        if Hero[pid] then
            PanCameraToTimedForPlayer(Player(pid - 1), GetUnitX(Hero[pid]), GetUnitY(Hero[pid]), 0.)
        end
        if data.minimap then SetMinimapTexture(pid, data.minimap) end
    end

    local function apply_black_mask(players, duration, fade)
        for _, pid in ipairs(players) do
            pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
            if GetLocalPlayer() == Player(pid - 1) then
                SetCineFilterTexture("ReplaceableTextures\\CameraMasks\\Black_mask.blp")
                if fade then
                    SetCineFilterStartColor(0, 0, 0, 0)
                    SetCineFilterEndColor(0, 0, 0, 255)
                else
                    SetCineFilterStartColor(0, 0, 0, 255)
                    SetCineFilterEndColor(0, 0, 0, 0)
                end
                SetCineFilterDuration(duration)
                DisplayCineFilter(true)
            end
        end
    end

    ---@type fun(tbl: table, fadein: number, fadeout: number)
    function BlackMask(tbl, fadein, fadeout)
        apply_black_mask(tbl, fadein, true)
        TimerQueue:callDelayed(fadein, apply_black_mask, tbl, fadeout, false)
    end
end)
