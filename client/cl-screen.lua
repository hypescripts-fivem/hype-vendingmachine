local Config <const> = require 'config.config'

-- Arm machines show the shop on their own screen: the web build runs as a DUI drawn over the model's screen texture
local URL <const> = ("nui://%s/web/dist/index.html?view=screen&dui=1"):format(GetCurrentResourceName())
-- What every arm machine's screen shows while nobody is using it
local IDLE_URL <const> = ("nui://%s/web/dist/index.html?view=idle&dui=1"):format(GetCurrentResourceName())
local TXD <const> = "hype_vending_screen"
local TXN <const> = "screen"

-- Cursor and mouse controls, read while every control is disabled
local CURSOR_X <const> = 239
local CURSOR_Y <const> = 240
-- Left click comes in as attack, or as cursor accept while the cursor is on
local CLICKS <const> = { 24, 237 }
local SCROLL_UP <const> = 241
local SCROLL_DOWN <const> = 242
local ESCAPE <const> = 200
local BACKSPACE <const> = 177
local SCROLL_STEP <const> = 100

-- Made when the first arm machine spawns and kept: the page is reloaded on every open, so each visit starts fresh
--- @type integer?
local dui
-- The idle page is up and every arm model's screen texture shows the DUI
local started = false
local starting = false

--- @type ScreenState?
local screen

--- @return integer? dui
local function getDui()
    if dui then return dui end

    local width, height = Config.Screen.width, Config.Screen.height
    local created = CreateDui("about:blank", width, height)

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

--- Points every arm model's screen texture at the DUI. A model the game unloads and loads again comes back
--- with its own texture, so this is redone on every spawn; removed first so the swaps don't pile up
--- @return nil
local function replaceTextures()
    for model in pairs(ArmModels) do
        RemoveReplaceTexture(model, Config.Screen.texture)
        AddReplaceTexture(model, Config.Screen.texture, TXD, TXN)
    end
end

--- Puts the DUI on every arm model's screen, showing the idle page. Waits for the DUI, so it runs in a thread or a callback
--- @return boolean
local function startScreens()
    if started then return true end
    if not getDui() then return false end

    SetDuiUrl(dui, IDLE_URL)
    replaceTextures()

    started = true
    Debug("info", "machine screens show the idle page")
    return true
end

--- Called when an arm machine spawns. The DUI loads in the background, so the caller isn't held up
--- @return nil
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

--- @param a vector3
--- @param b vector3
--- @return number
local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

--- @param a vector3
--- @param b vector3
--- @return vector3
local function cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

--- The DUI pixel under the cursor, nil when the cursor is off the machine's screen.
--- The cursor is turned into a ray from the camera and hit against the screen's plane, so the corners
--- don't have to be in view and the camera's perspective doesn't skew the clicks
--- @param state ScreenState
--- @return number? x
--- @return number? y
local function cursorToDui(state)
    local halfHeight = math.tan(math.rad(Config.Screen.camera.fov / 2))
    local halfWidth = halfHeight * GetAspectRatio(false)
    local x, y = GetDisabledControlNormal(0, CURSOR_X), GetDisabledControlNormal(0, CURSOR_Y)
    local ray = state.forward + state.right * ((x * 2 - 1) * halfWidth) + state.up * ((1 - y * 2) * halfHeight)

    local across, down = state.topRight - state.topLeft, state.bottomLeft - state.topLeft
    local normal = cross(across, down)
    local facing = dot(ray, normal)
    if math.abs(facing) < 1e-6 then return nil end

    local distance = dot(state.topLeft - state.position, normal) / facing
    if distance <= 0 then return nil end

    local hit = state.position + ray * distance - state.topLeft
    local u, v = dot(hit, across) / dot(across, across), dot(hit, down) / dot(down, down)
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil end

    return u * Config.Screen.width, v * Config.Screen.height
end

--- @param check fun(padIndex: integer, control: integer): boolean
--- @return boolean
local function clickControl(check)
    for _, control in ipairs(CLICKS) do
        if check(0, control) then return true end
    end

    return false
end

--- Sends the cursor, clicks and the wheel to the DUI. A click that started on the screen is always released
--- @param state ScreenState
--- @return nil
local function handleMouse(state)
    local x, y = cursorToDui(state)
    local clicked = clickControl(IsDisabledControlJustPressed)

    -- Shows where a click lands on the DUI, for tuning Config.Screen.corners
    if clicked then
        Debug("info", "screen click at %s", x and ("%d, %d"):format(math.floor(x), math.floor(y)) or "nothing (off the screen)")
    end

    if x and y then
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

--- Runs every frame while the screen is open: the game gets no input, the cursor goes to the DUI
--- @param state ScreenState
--- @return nil
local function inputLoop(state)
    CreateThread(function()
        while screen == state do
            DisableAllControlActions(0)
            SetMouseCursorActiveThisFrame()
            handleMouse(state)

            local tooFar = #(GetEntityCoords(cache.ped) - GetEntityCoords(state.entity)) > Config.Interaction.maxDistance

            if IsDisabledControlJustPressed(0, ESCAPE) or IsDisabledControlJustPressed(0, BACKSPACE) or IsEntityDead(cache.ped) or tooFar then
                CloseScreen()

                -- The pause menu would open as soon as Escape stops being disabled, while it's still held
                while IsDisabledControlPressed(0, ESCAPE) do
                    DisableControlAction(0, ESCAPE, true)
                    Wait(0)
                end
            end

            Wait(0)
        end
    end)
end

--- Shows the shop on the machine's screen and points the camera at it.
--- The page asks for its products with vending:get-data, so that view's data must be in before this runs
--- @param machine MachineEntry
--- @return boolean opened
function OpenScreen(machine)
    local entity = machine.entity
    if screen or not entity then return false end

    -- The arm machine spawned moments ago and its idle page is still loading
    while starting do Wait(0) end
    if not startScreens() then return false end

    local cfg = Config.Screen
    SetDuiUrl(dui, URL)

    --- @param offset vector3
    --- @return vector3
    local function world(offset)
        return GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    end

    local position = world(cfg.camera.offset)
    local topLeft, topRight, bottomLeft = world(cfg.corners.topLeft), world(cfg.corners.topRight), world(cfg.corners.bottomLeft)
    -- The screen is a parallelogram, its middle is halfway between two opposite corners
    local target = (topRight + bottomLeft) / 2

    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", position.x, position.y, position.z, 0.0, 0.0, 0.0, cfg.camera.fov, false, 2)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    -- The camera's axes, for turning the cursor into a ray. It never rolls, so right is level
    local forward = norm(target - position)
    local right = norm(cross(forward, vec3(0.0, 0.0, 1.0)))

    screen = {
        machineId = machine.data.id,
        entity = entity,
        cam = cam,
        pressed = false,
        position = position,
        forward = forward,
        right = right,
        up = cross(right, forward),
        topLeft = topLeft,
        topRight = topRight,
        bottomLeft = bottomLeft,
    }
    inputLoop(screen)

    Debug("info", "opened the screen of machine %s", machine.data.id)
    return true
end

--- Gives the camera back and puts the idle page back on the screen
--- @return nil
function CloseScreen()
    local state = screen
    if not state then return end
    screen = nil

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(state.cam, false)
    SetDuiUrl(dui, IDLE_URL)

    Debug("info", "closed the screen of machine %s", state.machineId)
    TriggerEvent("hype-vendingmachine:client:ui-closed")
end

--- @param machineId? integer Only that machine's screen counts
--- @return boolean
function IsScreenOpen(machineId)
    return screen ~= nil and (machineId == nil or screen.machineId == machineId)
end

-- The page has no setConfig message, it asks for the config once it's loaded
RegisterNuiCallback("screen:ready", function(data, cb)
    cb({ success = true, data = UiConfig() })
end)

-- The idle page cycles through every product's image
RegisterNuiCallback("screen:idle", function(data, cb)
    local images = {}

    for _, product in ipairs(Config.Products) do
        if product.image then images[#images + 1] = product.image end
    end

    cb({ success = true, data = images })
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CloseScreen()

    if started then
        for model in pairs(ArmModels) do
            RemoveReplaceTexture(model, Config.Screen.texture)
        end
    end

    if dui then
        DestroyDui(dui)
    end
end)
