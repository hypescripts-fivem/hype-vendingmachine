local Config <const> = require "config.config"
local nuiLoaded = false

--- @return nil
local function checkNui()
    while not nuiLoaded do
        Wait(100)
    end
end

--- @param action string The action to be sent to the NUI.
--- @param payload table The payload data to be sent with the action.
--- @return nil
function NuiMessage(action, payload)
    checkNui()
    SendNUIMessage({
        action = action,
        payload = payload
    })
end

--- Sent to the menu in setConfig, and to the machine screen when it asks
--- @return UiConfig
function UiConfig()
    return {
        inventoryImagePath = exports['hype-core']:GetImagePath(),
        currency = Config.Currency,
        locale = Config.NumberAndDateFormat,
        debug = Config.Debug,
    }
end

--- @return nil
local function fetchNui()
    CreateThread(function()
        NuiMessage("setConfig", UiConfig())
    end)

    while not nuiLoaded do
        if NetworkIsSessionStarted() then
            SendNUIMessage({
                action = "nuiReady",
            })
        end
        Wait(2000)
    end
end

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        fetchNui()
    end
end)

RegisterNetEvent("hype-core:client:player-loaded", function(data)
    fetchNui()
end)

RegisterNUICallback("nui-ready", function(data, cb)
    nuiLoaded = true
    Debug("success", "nui is ready")
    cb("ok")
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    Debug("info", "nui closed")
    TriggerEvent("hype-vendingmachine:client:ui-closed")
    cb({})
end)