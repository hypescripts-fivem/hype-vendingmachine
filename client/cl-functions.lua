local Config <const> = require "config.config"

local nuiLoaded = false
local waitingForNui = false

--- Spawns a local (non-networked) prop.
---@param model string|number
---@param coords vector4|vector3 The heading is used when coords has a `w`.
---@param freeze boolean? Frozen unless false.
---@return number? entity nil when the model can't be loaded.
function CreateLocalProp(model, coords, freeze)
    local ok, modelHash = pcall(lib.requestModel, model)
    if not ok then return nil end

    local object = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    if coords.w then SetEntityHeading(object, coords.w) end
    FreezeEntityPosition(object, freeze ~= false)
    SetModelAsNoLongerNeeded(modelHash)

    return object
end

--- Deletes an entity when it exists.
---@param entity number?
---@return nil
function RemoveEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

function NuiMessage(action, payload)
    while not nuiLoaded do Wait(100) end

    SendNUIMessage({
        action = action,
        payload = payload
    })
end

local uiLocales

local function getUiLocales()
    if not uiLocales then
        local raw = LoadResourceFile(GetCurrentResourceName(), ("locales/%s.json"):format(GetConvar("ox:locale", "en")))
        local data = raw and json.decode(raw)
        uiLocales = data and data.ui or {}
    end

    return uiLocales
end

function UiConfig()
    return {
        inventoryImagePath = Modules.Client.Inventory.GetImagePath(),
        currency = Config.Currency,
        locale = Config.NumberAndDateFormat,
        locales = getUiLocales(),
        debug = Config.Debug,
    }
end

local function initNui()
    if nuiLoaded then
        SendNUIMessage({ action = "setConfig", payload = UiConfig() })
        return
    end

    if waitingForNui then return end
    waitingForNui = true

    while not nuiLoaded do
        if NetworkIsSessionStarted() then
            SendNUIMessage({ action = "nuiReady" })
        end
        Wait(2000)
    end

    waitingForNui = false
    SendNUIMessage({ action = "setConfig", payload = UiConfig() })
end

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        initNui()
    end
end)

AddEventHandler("hype-vendingmachine:client:player-loaded", initNui)

RegisterNUICallback("nui-ready", function(_, cb)
    nuiLoaded = true
    cb("ok")
end)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    TriggerEvent("hype-vendingmachine:client:ui-closed")
    cb({})
end)
