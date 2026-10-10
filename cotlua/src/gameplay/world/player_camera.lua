OnInit.global("PlayerCamera", function(Require)
    Require('Variables')
    Require('TimerQueue')

    local custom_lighting = __jarray(0)
    local is_camera_locked = {}
    local preview_camera = {}
    local minimap_texture
    local lighting_override = {}

    ---@param pid integer
    local function apply_camera_lock(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            SetCameraFieldControlledByInput(CAMERA_FIELD_TARGET_DISTANCE, not is_camera_locked[pid])
            if is_camera_locked[pid] then
                SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, ZOOM[pid], 0.)
            end
        end
    end

    ---@param pid integer
    ---@param locked boolean
    function SetCameraLocked(pid, locked)
        is_camera_locked[pid] = locked
        apply_camera_lock(pid)
    end

    function SetCameraZoom(pid, zoom)
        ZOOM[pid] = zoom
        if is_camera_locked[pid] then
            apply_camera_lock(pid)
        end
    end

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

        if lighting_override[pid] then
            custom_lighting[pid] = 1 -- No automatic coloured hero light.
            daynight_model = lighting_override[pid]
        elseif custom_lighting[pid] ~= 1 then daynight_model = "blacklight.mdx" end

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

    -- Overrides ambient lighting only; lamp effects are owned by the dungeon.
    function SetPlayerLightingOverride(pid, model)
        lighting_override[pid] = model
        if Hero[pid] then update_lighting(pid, GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
        elseif GetLocalPlayer() == Player(pid - 1) then SetDayNightModels(model or DEFAULT_LIGHTING, model or DEFAULT_LIGHTING) end
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
            minimap_texture = texture
            BlzChangeMinimapTerrainTex(texture)
        end
    end

    -- Local presentation only; unlike SetCamera this does not touch a hero's
    -- lighting abilities and therefore also works before a hero is selected.
    function PreviewPlayerCamera(pid, region, x, y)
        local saved, generation
        if GetLocalPlayer() == Player(pid - 1) then
            if not preview_camera[pid] then
                preview_camera[pid] = {
                    min_x = GetCameraBoundMinX(), min_y = GetCameraBoundMinY(),
                    max_x = GetCameraBoundMaxX(), max_y = GetCameraBoundMaxY(),
                    x = GetCameraTargetPositionX(), y = GetCameraTargetPositionY(),
                    minimap = minimap_texture,
                }
            end
            saved = preview_camera[pid]
            saved.generation = (saved.generation or 0) + 1
            generation = saved.generation
            local data = REGION_DATA[region]
            local rect = data.vision
            if data.hide_minimap then
                local frame = BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP, 0)
                if saved.minimap_visible == nil then saved.minimap_visible = BlzFrameIsVisible(frame) end
                BlzFrameSetVisible(frame, false)
            end
            SetCameraBounds(GetRectMinX(rect), GetRectMinY(rect), GetRectMinX(rect),
                GetRectMaxY(rect), GetRectMaxX(rect), GetRectMaxY(rect), GetRectMaxX(rect), GetRectMinY(rect))
            if data.minimap then SetMinimapTexture(pid, data.minimap) end
        end
        -- Bounds changes can clamp the old tavern position on the next update.
        -- Start the timed pan afterwards so it uses that updated origin. Queue
        -- this on every client; only the camera mutation itself is local.
        TimerQueue:callDelayed(0.03, function()
            if GetLocalPlayer() == Player(pid - 1) and preview_camera[pid] == saved
                and saved and saved.generation == generation then
                PanCameraToTimed(x, y, 0.35)
            end
        end)
    end

    function RestorePlayerCameraPreview(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local saved = preview_camera[pid]
        if not saved then return end
        preview_camera[pid] = nil
        SetCameraBounds(saved.min_x, saved.min_y, saved.min_x, saved.max_y,
            saved.max_x, saved.max_y, saved.max_x, saved.min_y)
        if saved.minimap then SetMinimapTexture(pid, saved.minimap) end
        if saved.minimap_visible ~= nil then
            BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP, 0), saved.minimap_visible)
        end
        PanCameraToTimed(saved.x, saved.y, 0.)
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

OnInit.final("PlayerCameraRuntime", function(Require)
    Require('PlayerCamera')
    Require('MapSetup')
    Require('TimerQueue')

    TimerQueue:callPeriodically(1., nil, function()
        SetCameraQuickPosition(TOWN_CENTER_X, TOWN_CENTER_Y)
    end)
end, Debug and Debug.getLine())
