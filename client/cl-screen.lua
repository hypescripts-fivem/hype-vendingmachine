local Config <const> = require 'config.config'
local Screen <const> = Config.Screen

local URL <const> = ("nui://%s/web/dist/index.html?view=screen&dui=1"):format(GetCurrentResourceName())
local IDLE_URL <const> = ("nui://%s/web/dist/index.html?view=idle&dui=1"):format(GetCurrentResourceName())
local TXD <const> = "hype_vending_screen"
local TXN <const> = "screen"

local CURSOR_X <const> = 239
local CURSOR_Y <const> = 240
local CLICKS <const> = { 24, 237 }
local SCROLL_UP <const> = 241
local SCROLL_DOWN <const> = 242
local ESCAPE <const> = 200
local BACKSPACE <const> = 177
local SCROLL_STEP <const> = 100

local dui
local started = false
local starting = false
local screen

local function getDui()
    if dui then return dui end

    local created = CreateDui("about:blank", Screen.width, Screen.height)

    local timeout = GetGameTimer() + 5000
    while not IsDuiAvailable(created) do
        if GetGameTimer() > timeout then
            DestroyDui(created)
            Debug("error", "the machine screen DUI did not load")
            return nil
        end
        Wait(0)
    end

    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(TXD), TXN, GetDuiHandle(created))
    dui = created

    return dui
end

local function replaceTextures()
    for model in pairs(ArmModels) do
        RemoveReplaceTexture(model, Screen.texture)
        AddReplaceTexture(model, Screen.texture, TXD, TXN)
    end
end

local function startScreens()
    if started then return true end
    if not getDui() then return false end

    SetDuiUrl(dui, IDLE_URL)
    replaceTextures()

    started = true
    return true
end

function ShowIdleScreens()
    if starting then return end

    if started then
        replaceTextures()
        return
    end

    starting = true

    CreateThread(function()
        startScreens()
        starting = false
    end)
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

local function cursorToDui(state)
    local x, y = GetDisabledControlNormal(0, CURSOR_X), GetDisabledControlNormal(0, CURSOR_Y)
    local ray = state.forward + state.right * ((x * 2 - 1) * state.halfWidth) + state.up * ((1 - y * 2) * state.halfHeight)

    local facing = dot(ray, state.normal)
    if math.abs(facing) < 1e-6 then return nil end

    local distance = dot(state.topLeft - state.position, state.normal) / facing
    if distance <= 0 then return nil end

    local hit = state.position + ray * distance - state.topLeft
    local u, v = dot(hit, state.across) / state.acrossLength, dot(hit, state.down) / state.downLength
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil end

    return u * Screen.width, v * Screen.height
end

local function clickControl(check)
    for _, control in ipairs(CLICKS) do
        if check(0, control) then return true end
    end

    return false
end

local function handleMouse(state)
    local x, y = cursorToDui(state)
    local clicked = clickControl(IsDisabledControlJustPressed)

    if clicked then
        Debug("info", "screen click at %s", x and ("%d, %d"):format(math.floor(x), math.floor(y)) or "nothing (off the screen)")
    end

    if x then
        SendDuiMouseMove(dui, math.floor(x), math.floor(y))

        if clicked then
            SendDuiMouseDown(dui, "left")
            state.pressed = true
        end

        if IsDisabledControlJustPressed(0, SCROLL_UP) then
            SendDuiMouseWheel(dui, SCROLL_STEP, 0)
        elseif IsDisabledControlJustPressed(0, SCROLL_DOWN) then
            SendDuiMouseWheel(dui, -SCROLL_STEP, 0)
        end
    end

    if state.pressed and clickControl(IsDisabledControlJustReleased) then
        SendDuiMouseUp(dui, "left")
        state.pressed = false
    end
end

local function inputLoop(state)
    CreateThread(function()
        while screen == state do
            DisableAllControlActions(0)
            SetMouseCursorActiveThisFrame()
            handleMouse(state)

            local tooFar = #(GetEntityCoords(cache.ped) - state.coords) > Config.Interaction.maxDistance

            if IsDisabledControlJustPressed(0, ESCAPE) or IsDisabledControlJustPressed(0, BACKSPACE) or IsEntityDead(cache.ped) or tooFar then
                CloseScreen()

                while IsDisabledControlPressed(0, ESCAPE) do
                    DisableControlAction(0, ESCAPE, true)
                    Wait(0)
                end
            end

            Wait(0)
        end
    end)
end

function OpenScreen(machine)
    local entity = machine.entity
    if screen or not entity then return false end

    while starting do Wait(0) end
    if not startScreens() then return false end

    SetDuiUrl(dui, URL)

    local function world(offset)
        return GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    end

    local position = world(Screen.camera.offset)
    local topLeft, topRight, bottomLeft = world(Screen.corners.topLeft), world(Screen.corners.topRight), world(Screen.corners.bottomLeft)
    local target = (topRight + bottomLeft) / 2

    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", position.x, position.y, position.z, 0.0, 0.0, 0.0, Screen.camera.fov, false, 2)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    local forward = norm(target - position)
    local right = norm(cross(forward, vec3(0.0, 0.0, 1.0)))
    local across, down = topRight - topLeft, bottomLeft - topLeft
    local halfHeight = math.tan(math.rad(Screen.camera.fov / 2))

    screen = {
        machineId = machine.data.id,
        coords = GetEntityCoords(entity),
        cam = cam,
        pressed = false,
        position = position,
        forward = forward,
        right = right,
        up = cross(right, forward),
        topLeft = topLeft,
        across = across,
        down = down,
        acrossLength = dot(across, across),
        downLength = dot(down, down),
        normal = cross(across, down),
        halfHeight = halfHeight,
        halfWidth = halfHeight * GetAspectRatio(false),
    }
    inputLoop(screen)

    return true
end

function CloseScreen()
    local state = screen
    if not state then return end
    screen = nil

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(state.cam, false)
    SetDuiUrl(dui, IDLE_URL)

    TriggerEvent("hype-vendingmachine:client:ui-closed")
end

function IsScreenOpen(machineId)
    return screen ~= nil and (machineId == nil or screen.machineId == machineId)
end

RegisterNuiCallback("screen:ready", function(_, cb)
    cb({ success = true, data = UiConfig() })
end)

local idleImages = {}
for _, product in ipairs(Config.Products) do
    if product.image then idleImages[#idleImages + 1] = product.image end
end

RegisterNuiCallback("screen:idle", function(_, cb)
    cb({ success = true, data = idleImages })
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CloseScreen()

    if started then
        for model in pairs(ArmModels) do
            RemoveReplaceTexture(model, Screen.texture)
        end
    end

    if dui then
        DestroyDui(dui)
    end
end)
