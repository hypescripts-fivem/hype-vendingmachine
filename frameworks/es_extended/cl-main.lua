if Framework.Name ~= "es_extended" then return end

RegisterNetEvent("esx:playerLoaded", function()
    Wait(1500)
    TriggerEvent("hype-vendingmachine:client:player-loaded")
end)
