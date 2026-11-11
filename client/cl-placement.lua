local Config <const> = require 'config.config'

local TOGGLE_CURSOR <const> = 19
local SNAP <const> = 47
local CANCEL <const> = 200
local CURSOR_BLOCKED <const> = { 1, 2, 24, 25, 140, 141, 142, 257, 263, 264 }
local GHOST_ALPHA <const> = 160
local START_DISTANCE <const> = 2.0

local placing

function IsPlacing()
    return placing ~= nil
end

local function forwardOf(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

local function setCursor(state, cursor)
    state.cursor = cursor
    SetNuiFocus(cursor, cursor)
    SetNuiFocusKeepInput(cursor)
end

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
end

local function sendFrame(state)
    local camera, rotation, fov = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2), GetFinalRenderedCamFov()
    local coords, heading = GetEntityCoords(state.ghost), GetEntityHeading(state.ghost)
    local sent = state.sent

    if camera == sent.camera and rotation == sent.rotation and fov == sent.fov and coords == sent.coords
        and heading == sent.heading and state.cursor == sent.cursor then
        return
    end

    sent.camera, sent.rotation, sent.fov, sent.coords, sent.heading, sent.cursor = camera, rotation, fov, coords, heading, state.cursor

    local forward = forwardOf(rotation)
    NuiMessage("placement:frame", {
        camera = {
            x = camera.x,
            y = camera.y,
            z = camera.z,
            forward = { x = forward.x, y = forward.y, z = forward.z },
            fov = fov,
        },
        entity = { x = coords.x, y = coords.y, z = coords.z, heading = heading },
        cursor = state.cursor,
    })
end

local function placementLoop(state)
    CreateThread(function()
        while placing == state do
            DisableControlAction(0, CANCEL, true)

            if state.cursor then
                for _, control in ipairs(CURSOR_BLOCKED) do
                    DisableControlAction(0, control, true)
                end
            end

            sendFrame(state)

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
        cb({ success = false, error = "The machine model could not be loaded." })
        return
    end

    local ghost = CreateObjectNoOffset(model, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(ghost, start.w)
    SetEntityAlpha(ghost, GHOST_ALPHA, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    if machineId then
        SetMachineHidden(machineId, true)
    else
        PlaceObjectOnGroundProperly(ghost)
    end

    local state = { ghost = ghost, machineId = machineId, cursor = true, sent = {} }
    placing = state
    setCursor(state, true)
    placementLoop(state)

    local coords = GetEntityCoords(ghost)
    cb({ success = true, data = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ghost) } })
end)

RegisterNuiCallback("placement:move", function(data, cb)
    if placing then
        SetEntityCoordsNoOffset(placing.ghost, data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false)
        SetEntityHeading(placing.ghost, data.heading + 0.0)
    end

    cb({ success = true })
end)

RegisterNuiCallback("placement:snap", function(_, cb)
    if placing then
        PlaceObjectOnGroundProperly(placing.ghost)
    end

    cb({ success = true })
end)

RegisterNuiCallback("placement:confirm", function(_, cb)
    cb({ success = true })

    local state = placing
    if not state then return end

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

RegisterNuiCallback("placement:cancel", function(_, cb)
    cb({ success = true })
    finish(nil)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() or not placing then return end

    DeleteObject(placing.ghost)
    SetNuiFocusKeepInput(false)
end)
