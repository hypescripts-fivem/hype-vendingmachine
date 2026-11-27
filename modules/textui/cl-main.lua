local Config <const> = require "config.config"

local PROVIDERS <const> = {
    {
        name = "jg-textui",
        show = function(text) exports["jg-textui"]:DrawText(text) end,
        hide = function() exports["jg-textui"]:HideText() end,
    },
    {
        name = "okokTextUI",
        show = function(text) exports["okokTextUI"]:Open(text, "lightblue", "left") end,
        hide = function() exports["okokTextUI"]:Close() end,
    },
    {
        name = "ps-ui",
        show = function(text) exports["ps-ui"]:DisplayText(text, "primary") end,
        hide = function() exports["ps-ui"]:HideText() end,
    },
    {
        name = "ox_lib",
        show = function(text) lib.showTextUI(text, { position = "left-center" }) end,
        hide = function() lib.hideTextUI() end,
    },
    {
        name = "qb-core",
        show = function(text) exports["qb-core"]:DrawText(text) end,
        hide = function() exports["qb-core"]:HideText() end,
    },
}

local fallback <const> = PROVIDERS[4] -- ox_lib, always running as a dependency

--- Returns the text UI to use, honouring Config.TextUI.
---@return { name: string, show: fun(text: string), hide: fun() } provider
local function provider()
    for _, entry in ipairs(PROVIDERS) do
        if Config.TextUI == entry.name or (Config.TextUI == "auto" and GetResourceState(entry.name) == "started") then
            return entry
        end
    end

    return fallback
end

--- Shows the text UI prompt.
---@param text string
---@return nil
function Modules.Client.TextUI.ShowTextUI(text)
    provider().show(text)
end

--- Hides the text UI prompt.
---@return nil
function Modules.Client.TextUI.HideTextUI()
    provider().hide()
end
