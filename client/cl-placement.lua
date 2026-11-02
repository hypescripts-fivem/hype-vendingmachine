local Config <const> = require 'config.config'

-- Admin panel, "Set machine position": a see-through ghost of the machine, moved with the gizmo the page draws over the game

local TOGGLE_CURSOR <const> = 19 -- Left Alt
local SNAP <const> = 47          -- G
local CANCEL <const> = 200       -- Escape
-- Looking around and attacking, off while the cursor works the gizmo
local CURSOR_BLOCKED <const> = { 1, 2, 24, 25, 140, 141, 142, 257, 263, 264 }
local GHOST_ALPHA <const> = 160
-- A new machine starts this far in front of the admin
local START_DISTANCE <const> = 2.0

--- @type PlacementState?
local placing

--- Other menus stay shut while placing: opening one would unmount the admin page and lose the form
--- @return boolean
function IsPlacing()
    return placing ~= nil
end

--- Where a camera with this rotation looks
--- @param rotation vector3 Degrees, rotation order 2
--- @return vector3
local function forwardOf(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

--- With the cursor the gizmo takes the mouse and the admin can still walk; without it the game has the mouse to look around
--- @param state PlacementState
--- @param cursor boolean
--- @return nil
local function setCursor(state, cursor)
    state.cursor = cursor
    SetNuiFocus(cursor, cursor)
    SetNuiFocusKeepInput(cursor)
end

--- Ends the placement: the ghost goes, the machine being moved comes back and the admin page shows again
--- @param location? MachineLocation The confirmed position, nil when cancelled
--- @return nil
local function finish(location)
    local state = placing
    if not state then return end
    placing = nil

    DeleteObject(state.ghost)

    if state.machineId then
        SetMachineHidden(state.machineId, false)
    end

    SetNuiFocusKeepInput(false)
    SetNuiFocus(true, true)
    NuiMessage("placement:finish", { location = location })

    Debug("info", "placement %s", location and "confirmed" or "cancelled")
end

--- Sends the rendered camera and the ghost to the page every frame, and reads the placement keys
--- @param state PlacementState
--- @return nil
local function placementLoop(state)
    CreateThread(function()
        while placing == state do
            -- Escape cancels, it must not open the pause menu
            DisableControlAction(0, CANCEL, true)

            if state.cursor then
                for _, control in ipairs(CURSOR_BLOCKED) do
                    DisableControlAction(0, control, true)
                end
            end

            local camera, rotation = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
            local forward = forwardOf(rotation)
            local coords = GetEntityCoords(state.ghost)

            NuiMessage("placement:frame", {
                camera = {
                    x = camera.x,
                    y = camera.y,
                    z = camera.z,
                    forward = { x = forward.x, y = forward.y, z = forward.z },
                    fov = GetFinalRenderedCamFov(),
                },
                entity = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(state.ghost) },
                cursor = state.cursor,
            })

            if IsDisabledControlJustPressed(0, CANCEL) or IsEntityDead(cache.ped) then
                finish(nil)
            elseif IsControlJustPressed(0, TOGGLE_CURSOR) then
                setCursor(state, not state.cursor)
            elseif IsControlJustPressed(0, SNAP) then
                PlaceObjectOnGroundProperly(state.ghost)
            end

            Wait(0)
        end
    end)
end

--- Where the ghost starts: on the machine being moved (only when the admin is next to it) or in front of the admin
--- @param machineId? integer
--- @return vector4? start
--- @return string? error
local function startPosition(machineId)
    if not machineId then
        local front = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, START_DISTANCE, 0.0)
        return vec4(front.x, front.y, front.z, (GetEntityHeading(cache.ped) + 180.0) % 360.0)
    end

    local machine = GetMachine(machineId)
    if not machine then return nil, "Go to the machine to move it." end

    local data = machine.data
    local coords = machine.entity and GetEntityCoords(machine.entity) or vec3(data.x, data.y, data.z)

    if #(GetEntityCoords(cache.ped) - coords) > Config.Placement.editDistance then
        return nil, "Go to the machine to move it."
    end

    return vec4(coords.x, coords.y, coords.z, machine.entity and GetEntityHeading(machine.entity) or data.heading)
end

RegisterNuiCallback("placement:start", function(data, cb)
    if placing then
        cb({ success = false, error = "A machine is already being placed." })
        return
    end

    local machineId = tonumber(data.machineId)
    local start, err = startPosition(machineId)

    if not start then
        cb({ success = false, error = err })
        return
    end

    local ok, model = pcall(lib.requestModel, data.model)
    if not ok then
        Debug("error", "could not load %s for placement: %s", data.model, model)
        cb({ success = false, error = "The machine model could not be loaded." })
        return
    end

    local ghost = CreateObjectNoOffset(model, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(ghost, start.w)
    SetEntityAlpha(ghost, GHOST_ALPHA, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    -- A moved machine is taken away so only its ghost shows; a new one starts on the ground
    if machineId then
        SetMachineHidden(machineId, true)
    else
        PlaceObjectOnGroundProperly(ghost)
    end

    local state = { ghost = ghost, machineId = machineId, cursor = true }
    placing = state
    setCursor(state, true)
    placementLoop(state)

    local coords = GetEntityCoords(ghost)
    Debug("info", "placing %s%s", data.model, machineId and (" for machine %s"):format(machineId) or "")
    cb({ success = true, data = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ghost) } })
end)

RegisterNuiCallback("placement:move", function(data, cb)
    if placing then
        SetEntityCoordsNoOffset(placing.ghost, data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false)
        SetEntityHeading(placing.ghost, data.heading + 0.0)
    end

    cb({ success = true })
end)

RegisterNuiCallback("placement:snap", function(data, cb)
    if placing then
        PlaceObjectOnGroundProperly(placing.ghost)
    end

    cb({ success = true })
end)

RegisterNuiCallback("placement:confirm", function(data, cb)
    cb({ success = true })

    local state = placing
    if not state then return end

    -- The machine spawns on the ground, so the saved spot is the ghost's on the ground
    PlaceObjectOnGroundProperly(state.ghost)
    local coords = GetEntityCoords(state.ghost)
    finish({
        label = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z)),
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(state.ghost),
    })
end)

RegisterNuiCallback("placement:cancel", function(data, cb)
    cb({ success = true })
    finish(nil)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() or not placing then return end

    DeleteObject(placing.ghost)
end)
