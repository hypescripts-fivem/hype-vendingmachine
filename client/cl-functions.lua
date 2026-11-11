local Config <const> = require "config.config"

local nuiLoaded = false
local waitingForNui = false

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
        inventoryImagePath = exports['hype-core']:GetImagePath(),
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

RegisterNetEvent("hype-core:client:player-loaded", initNui)

RegisterNUICallback("nui-ready", function(_, cb)
    nuiLoaded = true
    cb("ok")
end)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    TriggerEvent("hype-vendingmachine:client:ui-closed")
    cb({})
end)
