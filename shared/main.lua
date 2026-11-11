lib.locale()

local Config <const> = require "config.config"

ArmModels = {}
for _, model in ipairs(Config.Machines) do
    if model.arm then ArmModels[model.value] = true end
end
