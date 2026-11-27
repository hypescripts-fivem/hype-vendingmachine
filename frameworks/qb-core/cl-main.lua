if Framework.Name ~= "qb-core" then return end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(1500)
    TriggerEvent("hype-vendingmachine:client:player-loaded")
end)
